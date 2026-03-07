//==============================================================//
//  Module:       uart_test_wrapper_tb
//  File:         uart_test_wrapper_tb.sv
//  Description:  Testbench for uart_test_wrapper.
//
//                 This testbench verifies:
//                   - External APB pass-through to UART when loopback FSM is idle
//                   - Internal loopback FSM can own APB and execute command vectors
//                   - External APB accesses are blocked while internal loopback is active
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

module uart_test_wrapper_tb;

    // ------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------
    localparam real CLK_PERIOD_NS = 13.333; // 75 MHz
    localparam int  BAUD_DIV      = 8;

    // ------------------------------------------------------------
    // DUT/TB signals
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

    logic        intlpbk_enable_i;
    logic [15:0] intlpbk_read_cmd_i;
    logic [15:0] intlpbk_write_cmd_i;

    logic        intlpbk_busy_o;
    logic [15:0] intlpbk_pass_count_o;
    logic [15:0] intlpbk_fail_count_o;
    logic [3:0]  intlpbk_tx_ptr_o;
    logic [3:0]  intlpbk_rx_ptr_o;
    logic [15:0] intlpbk_read_cmd_active_o;
    logic [15:0] intlpbk_write_cmd_active_o;

    logic [7:0] loopback_byte;
    logic [31:0] rd_word;

    // ------------------------------------------------------------
    // Loopback connection
    // ------------------------------------------------------------
    assign rx_data_i = tx_data_o;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    uart_test_wrapper dut (
        // -- clk and reset --
        .clk_i                    (clk_i),
        .reset_i                  (reset_i),

        // -- UART pins --
        .rx_data_i                (rx_data_i),
        .tx_data_o                (tx_data_o),

        // -- External APB signals --
        .psel_i                   (psel_i),
        .penable_i                (penable_i),
        .pwrite_i                 (pwrite_i),
        .paddr_i                  (paddr_i),
        .pwdata_i                 (pwdata_i),
        .prdata_o                 (prdata_o),
        .pready_o                 (pready_o),
        .pslverr_o                (pslverr_o),

        // -- Internal loopback control --
        .intlpbk_enable_i         (intlpbk_enable_i),
        .intlpbk_read_cmd_i       (intlpbk_read_cmd_i),
        .intlpbk_write_cmd_i      (intlpbk_write_cmd_i),

        // -- Internal loopback status --
        .intlpbk_busy_o           (intlpbk_busy_o),
        .intlpbk_pass_count_o     (intlpbk_pass_count_o),
        .intlpbk_fail_count_o     (intlpbk_fail_count_o),
        .intlpbk_tx_ptr_o         (intlpbk_tx_ptr_o),
        .intlpbk_rx_ptr_o         (intlpbk_rx_ptr_o),
        .intlpbk_read_cmd_active_o(intlpbk_read_cmd_active_o),
        .intlpbk_write_cmd_active_o(intlpbk_write_cmd_active_o)
    );

    // ------------------------------------------------------------
    // Clock generation
    // ------------------------------------------------------------
    initial clk_i = 1'b0;
    always #(CLK_PERIOD_NS/2.0) clk_i = ~clk_i;

    // ------------------------------------------------------------
    // Test stimulus
    // ------------------------------------------------------------
    initial begin
        dump_setup();

        // Default DUT values
        reset_i               = 1'b1;
        psel_i                = 1'b0;
        penable_i             = 1'b0;
        pwrite_i              = 1'b0;
        paddr_i               = '0;
        pwdata_i              = '0;
        intlpbk_enable_i      = 1'b0;
        intlpbk_read_cmd_i    = 16'h0000;
        intlpbk_write_cmd_i   = 16'h0000;
        loopback_byte         = 8'hA5;

        // Reset pulse
        repeat (5) @(posedge clk_i);
        reset_i = 1'b0;

        // External APB should work while loopback FSM is idle.
        reg_write_ok(`UART_BAUD_CFG_ADDR, BAUD_DIV);
        reg_write_ok(`UART_UART_CFG_ADDR, 32'h0000_0005);
        reg_write_ok(`UART_TX_DATA_ADDR, {24'h0, loopback_byte});

        wait_rx_valid_external();
        reg_read_ok(`UART_RX_DATA_ADDR, rd_word);
        assert (rd_word[7:0] == loopback_byte)
            else tb_error($sformatf("External APB loopback mismatch: exp=0x%0h got=0x%0h", loopback_byte, rd_word[7:0]));

        // Start internal loopback FSM with 4 TRANSMIT commands and 4 READ
    // commands.
        intlpbk_read_cmd_i  = 16'h00F0;
        intlpbk_write_cmd_i = 16'h000F;
        intlpbk_enable_i    = 1'b1;

        // Give FSM time to take APB ownership, then verify external APB is blocked.
        repeat (20) @(posedge clk_i);
        reg_read_expect_blocked(`UART_UART_STATUS_ADDR);

        wait_internal_loopback_done(500000);

        assert (intlpbk_fail_count_o == 16'h0000)
            else tb_error($sformatf("Internal loopback reported failures: %0d", intlpbk_fail_count_o));
        assert (intlpbk_tx_ptr_o == 4'd4)
            else tb_error($sformatf("Internal loopback TX pointer mismatch: exp=4 got=%0d", intlpbk_tx_ptr_o));

        // Deassert enable so FSM can return to edge-sensitive idle behavior.
        intlpbk_enable_i = 1'b0;
        repeat (20) @(posedge clk_i);

        tb_report();
        $finish;
    end

    // ------------------------------------------------------------
    // Tasks
    // ------------------------------------------------------------
    task automatic reg_write_ok(
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

        // Complete transfer
        @(posedge clk_i);
        if (pready_o !== 1'b1) begin
            tb_error("APB write expected pready_o=1");
        end
        if (pslverr_o !== 1'b0) begin
            tb_error($sformatf("Unexpected PSLVERR on write addr 0x%0h", addr));
        end

        psel_i    <= 1'b0;
        penable_i <= 1'b0;
        pwrite_i  <= 1'b0;
        paddr_i   <= '0;
        pwdata_i  <= '0;
    end
    endtask

    task automatic reg_read_ok(
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

        // Complete transfer
        @(posedge clk_i);
        if (pready_o !== 1'b1) begin
            tb_error("APB read expected pready_o=1");
        end
        if (pslverr_o !== 1'b0) begin
            tb_error($sformatf("Unexpected PSLVERR on read addr 0x%0h", addr));
        end
        data = prdata_o;

        psel_i    <= 1'b0;
        penable_i <= 1'b0;
        pwrite_i  <= 1'b0;
        paddr_i   <= '0;
    end
    endtask

    task automatic reg_read_expect_blocked(
        input logic [4:0] addr
    );
        logic [31:0] data;
    begin
        data = '0;

        // APB setup phase
        @(posedge clk_i);
        psel_i    <= 1'b1;
        penable_i <= 1'b0;
        pwrite_i  <= 1'b0;
        paddr_i   <= addr;

        // APB access phase
        @(posedge clk_i);
        penable_i <= 1'b1;

        // Complete transfer
        @(posedge clk_i);
        if (pready_o !== 1'b1) begin
            tb_error("Blocked read expected pready_o=1");
        end
        if (pslverr_o !== 1'b1) begin
            tb_error("Blocked read expected pslverr_o=1");
        end

        data = prdata_o;
        if (data !== 32'h0000_0000) begin
            tb_error($sformatf("Blocked read expected zero data, got 0x%08h", data));
        end

        psel_i    <= 1'b0;
        penable_i <= 1'b0;
        pwrite_i  <= 1'b0;
        paddr_i   <= '0;
    end
    endtask

    task automatic wait_rx_valid_external;
        logic [31:0] status;
        int timeout_cntr;
    begin
        status = '0;
        timeout_cntr = 0;
        while (status[0] == 1'b0) begin
            reg_read_ok(`UART_UART_STATUS_ADDR, status);
            timeout_cntr++;
            if (timeout_cntr > 5000) begin
                tb_error("Timeout waiting for external RX_VALID");
                disable wait_rx_valid_external;
            end
            repeat (10) @(posedge clk_i);
        end
    end
    endtask

    task automatic wait_internal_loopback_done(
        input int unsigned timeout_cycles
    );
        int unsigned timeout_cntr;
    begin
        timeout_cntr = timeout_cycles;
        while (intlpbk_busy_o) begin
            @(posedge clk_i);
            if (timeout_cntr == 0) begin
                tb_error("Timeout waiting for internal loopback completion");
                disable wait_internal_loopback_done;
            end
            timeout_cntr--;
        end
    end
    endtask

endmodule
