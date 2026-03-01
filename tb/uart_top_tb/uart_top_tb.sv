//==============================================================//
//  Module:       uart_top_tb
//  File:         uart_top_tb.sv
//  Description:  Testbench for uart_top.
//
//                 This testbench verifies:
//                   - Register read/write access for config and data
//                   - TX-to-RX loopback of multiple bytes
//                   - Basic baud configuration and enable sequencing
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:   CLK_PERIOD_NS, BAUD_DIV
//
//  Notes:        - Uses common.sv dump_setup for VCD generation.
//==============================================================//
`timescale 1ns/1ps
`include "common.sv"
`include "uart_reg_macros.sv"

module uart_top_tb;

    // ------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------
    localparam real CLK_PERIOD_NS = 13.333; // 75 MHz
    localparam int  BAUD_DIV      = 8;      // small divisor for faster sim
    // ------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------
    logic        clk_i;
    logic        reset_i;

    logic        rx_data_i;
    logic        tx_data_o;

    logic        psel_i;
    logic        penable_i;
    logic        pwrite_i;
    logic [4:0]  paddr_i;
    logic [31:0] pwdata_i;
    logic [31:0] prdata_o;
    logic        pready_o;
    logic        pslverr_o;

    // ------------------------------------------------------------
    // Sequence
    // ------------------------------------------------------------
    logic [7:0] seq   [23:0];
    int         seq_read_ptr;
    int         seq_write_ptr;

    // ------------------------------------------------------------
    // Loopback
    // ------------------------------------------------------------
    assign rx_data_i = tx_data_o;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    uart_top dut (
        .clk_i       (clk_i),
        .reset_i     (reset_i),
        .rx_data_i   (rx_data_i),
        .tx_data_o   (tx_data_o),
        .psel_i      (psel_i),
        .penable_i   (penable_i),
        .pwrite_i    (pwrite_i),
        .paddr_i     (paddr_i),
        .pwdata_i    (pwdata_i),
        .prdata_o    (prdata_o),
        .pready_o    (pready_o),
        .pslverr_o   (pslverr_o)
    );

    // ------------------------------------------------------------
    // Clock generation (75 MHz)
    // ------------------------------------------------------------
    initial clk_i = 1'b0;
    always #(CLK_PERIOD_NS/2.0) clk_i = ~clk_i;

    // ------------------------------------------------------------
    // Test stimulus
    // ------------------------------------------------------------
    initial begin
        dump_setup();

        // Default DUT values
        reset_i     = 1'b1;
        psel_i      = 1'b0;
        penable_i   = 1'b0;
        pwrite_i    = 1'b0;
        paddr_i     = '0;
        pwdata_i    = '0;

        // Default TB signals
        seq_read_ptr = 0;
        seq_write_ptr = 0;

        // Sequence initialization
        for (int i=0; i < 24; i++) begin
            seq[i] = $urandom();
        end

        // Hold reset
        repeat (5) @(posedge clk_i);
        reset_i = 1'b0;

        // Program baud divisor (required because baud_gen div_r resets to 0)
        reg_write(`UART_BAUD_CFG_ADDR, BAUD_DIV);

        // Enable TX and RX
        reg_write(`UART_UART_CFG_ADDR, 32'h5); // TX_EN=1, RX_EN=1

        // Loopback a few bytes (write multiple before reading)
        loopback_bytes(3);

        // Interleaved write/read seq:
        // 4 writes, read 2, write 4 more, then read all remaining
        write_tx_bytes(4);
        repeat(10000)@(posedge clk_i);
        read_and_check_bytes(2);
        write_tx_bytes(4);
        read_and_check_bytes(2);
        read_and_check_bytes(4);

        repeat (50) @(posedge clk_i);
        tb_report();
        $finish;
    end

    // ------------------------------------------------------------
    // Tasks
    // ------------------------------------------------------------
    task automatic reg_write(
        input logic [4:0]  addr,
        input logic [31:0] data
    );
    begin
        // APB setup phase
        @(posedge clk_i);
        psel_i    <= 1'b1;
        penable_i <= 1'b0;
        pwrite_i  <= 1'b1;
        paddr_i   <= addr;
        pwdata_i  <= data;

        // APB access phase
        @(posedge clk_i);
        penable_i <= 1'b1;

        // Complete transfer (no wait states expected)
        @(posedge clk_i);
        if (pready_o !== 1'b1) begin
            tb_error("APB write expected pready_o=1");
        end
        if (pslverr_o !== 1'b0) begin
            tb_error($sformatf("Unexpected APB PSLVERR on write addr 0x%0h", addr));
        end
        $display("[%0t] APB WRITE complete: addr=0x%0h data=0x%08h", $time, addr, data);

        psel_i    <= 1'b0;
        penable_i <= 1'b0;
        pwrite_i  <= 1'b0;
        paddr_i   <= '0;
        pwdata_i  <= '0;
    end
    endtask

    task automatic reg_read(
        input  logic [4:0]  addr,
        output logic [31:0] data
    );
    begin
        // APB setup phase
        @(posedge clk_i);
        psel_i    <= 1'b1;
        penable_i <= 1'b0;
        pwrite_i  <= 1'b0;
        paddr_i   <= addr;

        // APB access phase
        @(posedge clk_i);
        penable_i <= 1'b1;

        // Capture read data
        @(posedge clk_i);
        if (pready_o !== 1'b1) begin
            tb_error("APB read expected pready_o=1");
        end
        if (pslverr_o !== 1'b0) begin
            tb_error($sformatf("Unexpected APB PSLVERR on read addr 0x%0h", addr));
        end
        data = prdata_o;
        $display("[%0t] APB READ complete: addr=0x%0h data=0x%08h", $time, addr, data);

        psel_i    <= 1'b0;
        penable_i <= 1'b0;
        pwrite_i  <= 1'b0;
        paddr_i   <= '0;
    end
    endtask

    task automatic wait_rx_valid;
        logic [31:0] status;
    begin
        status = '0;
        while (status[0] == 1'b0) begin
            reg_read(`UART_UART_STATUS_ADDR, status);
            $display("Polling RX_VALID: %0b", status[0]);
            repeat(10)@(posedge clk_i);
        end
    end
    endtask

    task automatic write_tx_bytes(
        input int unsigned count
    );
    begin
        for (int i = 0; i < count; i++) begin
            reg_write(`UART_TX_DATA_ADDR, {24'h0, seq[seq_write_ptr]});
            seq_write_ptr++;
        end
    end
    endtask

    task automatic read_and_check_bytes(
        input int unsigned count
    );
    begin
        for (int i = 0; i < count; i++) begin
            logic [31:0] rx_word;

            // Wait for RX FIFO to have data
            wait_rx_valid();

            // Read RX data (also pops FIFO)
            reg_read(`UART_RX_DATA_ADDR, rx_word);
            assert (rx_word[7:0] == seq[seq_read_ptr])
                else tb_error($sformatf("Loopback mismatch. Expected 0x%0h, got 0x%0h", seq[seq_read_ptr], rx_word[7:0]));

            seq_read_ptr++;
        end
    end
    endtask

    task automatic loopback_bytes(
        input int unsigned count
    );
    begin
        write_tx_bytes(count);
        read_and_check_bytes(count);
    end
    endtask

endmodule
