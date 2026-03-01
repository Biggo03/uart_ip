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

    logic        reg_we_i;
    logic [4:0]  reg_waddr_i;
    logic [31:0] reg_wdata_i;

    logic [4:0]  reg_raddr_i;
    logic [31:0] reg_rdata_o;

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
        .reg_we_i    (reg_we_i),
        .reg_waddr_i (reg_waddr_i),
        .reg_wdata_i (reg_wdata_i),
        .reg_raddr_i (reg_raddr_i),
        .reg_rdata_o (reg_rdata_o)
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

        // Default values
        reset_i     = 1'b1;
        reg_we_i    = 1'b0;
        reg_waddr_i = '0;
        reg_wdata_i = '0;
        reg_raddr_i = '0;

        // Hold reset
        repeat (5) @(posedge clk_i);
        reset_i = 1'b0;

        // Program baud divisor (required because baud_gen div_r resets to 0)
        reg_write(`UART_BAUD_CFG_ADDR, BAUD_DIV);

        // Enable TX and RX
        reg_write(`UART_UART_CFG_ADDR, 32'h5); // TX_EN=1, RX_EN=1

        // Loopback a few bytes
        loopback_byte(8'hA5);
        loopback_byte(8'h3C);
        loopback_byte(8'h5A);

        repeat (50) @(posedge clk_i);
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
        @(negedge clk_i);
        reg_waddr_i = addr;
        reg_wdata_i = data;
        reg_we_i    = 1'b1;
        @(posedge clk_i);
        #1;
        reg_we_i    = 1'b0;
    end
    endtask

    task automatic reg_read(
        input  logic [4:0]  addr,
        output logic [31:0] data
    );
    begin
        @(negedge clk_i);
        reg_raddr_i = addr;
        @(posedge clk_i);
        #1;
        data = reg_rdata_o;
    end
    endtask

    task automatic wait_rx_valid;
        logic [31:0] status;
    begin
        status = '0;
        while (status[0] == 1'b0) begin
            reg_read(`UART_UART_STATUS_ADDR, status);
        end
    end
    endtask

    task automatic loopback_byte(
        input logic [7:0] tx_byte
    );
        logic [31:0] rx_word;
    begin
        // Write TX data
        reg_write(`UART_TX_DATA_ADDR, {24'h0, tx_byte});

        // Wait for RX FIFO to have data
        wait_rx_valid();

        // Read RX data (also pops FIFO)
        reg_read(`UART_RX_DATA_ADDR, rx_word);
        assert (rx_word[7:0] == tx_byte)
            else $error("Loopback mismatch. Expected 0x%0h, got 0x%0h", tx_byte, rx_word[7:0]);
    end
    endtask

endmodule
