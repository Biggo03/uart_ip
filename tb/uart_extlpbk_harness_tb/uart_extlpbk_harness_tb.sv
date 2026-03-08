//==============================================================//
//  Module:       uart_extlpbk_harness_tb
//  File:         uart_extlpbk_harness_tb.sv
//  Description:  Testbench for uart_extlpbk_harness.
//
//                 This testbench verifies:
//                   - External UART stimulus is accepted by loopback harness
//                   - Echo data is returned byte-for-byte on UART TX
//                   - External loopback status counters/last-byte fields update correctly
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

module uart_extlpbk_harness_tb;

    // ------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------
    localparam real CLK_PERIOD_NS = 13.333; // 75 MHz
    localparam int  BAUD_DIV      = 8;      // speed-up divisor for simulation

    // ------------------------------------------------------------
    // DUT/TB signals
    // ------------------------------------------------------------
    logic        clk_i;
    logic        reset_i;
    logic        extlpbk_enable_i;

    wire         uart_rx_data_i;
    wire         uart_tx_data_o;

    logic        extlpbk_busy_o;
    logic [15:0] extlpbk_echo_count_o;
    logic [15:0] extlpbk_error_count_o;
    logic [7:0]  extlpbk_last_rx_byte_o;
    logic [7:0]  extlpbk_last_tx_byte_o;

    logic [7:0]  exp_bytes [0:2];
    logic [7:0]  echo_byte;

    // ------------------------------------------------------------
    // Host UART TX model (external PC stimulus)
    // ------------------------------------------------------------
    logic        host_osr_tick;
    logic        host_tx_en_i;
    logic        host_tx_clr_ovrn_i;
    logic        host_tx_fifo_wen_i;
    logic [7:0]  host_tx_fifo_wdata_i;
    logic        host_tx_busy_o;
    logic        host_tx_ovrn_o;
    logic [4:0]  host_tx_lvl_o;
    logic        host_tx_data_o;

    // ------------------------------------------------------------
    // Echo monitor UART RX model
    // ------------------------------------------------------------
    logic        mon_osr_tick;
    logic        mon_rx_en_i;
    logic        mon_rx_clr_ovrn_i;
    logic        mon_rx_fifo_ren_i;
    logic        mon_rx_busy_o;
    logic        mon_rx_ovrn_o;
    logic [4:0]  mon_rx_lvl_o;
    logic        mon_rx_valid_o;
    logic [7:0]  mon_rx_data_o;

    // ------------------------------------------------------------
    // Serial wiring
    // ------------------------------------------------------------
    assign uart_rx_data_i = host_tx_data_o;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    uart_extlpbk_harness #(
        .BAUDDIV_CFG(BAUD_DIV)
    ) dut (
        // -- clk and reset --
        .clk_i                 (clk_i),
        .reset_i               (reset_i),

        // -- External loopback control --
        .extlpbk_enable_i      (extlpbk_enable_i),

        // -- External UART pins --
        .uart_rx_data_i        (uart_rx_data_i),
        .uart_tx_data_o        (uart_tx_data_o),

        // -- External loopback status --
        .extlpbk_busy_o        (extlpbk_busy_o),
        .extlpbk_echo_count_o  (extlpbk_echo_count_o),
        .extlpbk_error_count_o (extlpbk_error_count_o),
        .extlpbk_last_rx_byte_o(extlpbk_last_rx_byte_o),
        .extlpbk_last_tx_byte_o(extlpbk_last_tx_byte_o)
    );

    // ------------------------------------------------------------
    // Host transmitter model
    // ------------------------------------------------------------
    baud_gen u_host_baud_gen (
        .clk_i      (clk_i),
        .reset_i    (reset_i),
        .en_i       (1'b1),
        .div_i      (BAUD_DIV[15:0]),
        .osr_tick_o (host_osr_tick)
    );

    uart_tx u_host_uart_tx (
        // -- clk and reset --
        .clk_i          (clk_i),
        .reset_i        (reset_i),

        // -- Baud --
        .osr_tick_i     (host_osr_tick),

        // -- TX control and FIFO write input --
        .tx_en_i        (host_tx_en_i),
        .tx_clr_ovrn_i  (host_tx_clr_ovrn_i),
        .tx_fifo_wen_i  (host_tx_fifo_wen_i),
        .tx_fifo_wdata_i(host_tx_fifo_wdata_i),

        // -- TX status and serial output --
        .tx_busy_o      (host_tx_busy_o),
        .tx_ovrn_o      (host_tx_ovrn_o),
        .tx_lvl_o       (host_tx_lvl_o),
        .tx_data_o      (host_tx_data_o)
    );

    // ------------------------------------------------------------
    // Echo monitor model
    // ------------------------------------------------------------
    baud_gen u_mon_baud_gen (
        .clk_i      (clk_i),
        .reset_i    (reset_i),
        .en_i       (1'b1),
        .div_i      (BAUD_DIV[15:0]),
        .osr_tick_o (mon_osr_tick)
    );

    uart_rx u_mon_uart_rx (
        // -- clk and reset --
        .clk_i         (clk_i),
        .reset_i       (reset_i),

        // -- Baud and serial input --
        .osr_tick_i    (mon_osr_tick),
        .rx_data_i     (uart_tx_data_o),

        // -- RX control --
        .rx_en_i       (mon_rx_en_i),
        .rx_clr_ovrn_i (mon_rx_clr_ovrn_i),
        .rx_fifo_ren_i (mon_rx_fifo_ren_i),

        // -- RX status and data --
        .rx_busy_o     (mon_rx_busy_o),
        .rx_ovrn_o     (mon_rx_ovrn_o),
        .rx_lvl_o      (mon_rx_lvl_o),
        .rx_valid_o    (mon_rx_valid_o),
        .rx_data_o     (mon_rx_data_o)
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

        // Default values
        reset_i               = 1'b1;
        extlpbk_enable_i      = 1'b0;

        host_tx_en_i          = 1'b0;
        host_tx_clr_ovrn_i    = 1'b0;
        host_tx_fifo_wen_i    = 1'b0;
        host_tx_fifo_wdata_i  = 8'h00;

        mon_rx_en_i           = 1'b1;
        mon_rx_clr_ovrn_i     = 1'b0;
        mon_rx_fifo_ren_i     = 1'b0;

        exp_bytes[0]          = 8'hA5;
        exp_bytes[1]          = 8'h3C;
        exp_bytes[2]          = 8'h7E;

        // Reset pulse
        repeat (5) @(posedge clk_i);
        reset_i = 1'b0;

        // Enable host TX model and external loopback.
        host_tx_en_i     = 1'b1;
        extlpbk_enable_i = 1'b1;
        wait_extlpbk_active(100000);
        repeat (5000) @(posedge clk_i);

        // Send three bytes and confirm echoed data.
        for (int i = 0; i < 3; i++) begin
            host_send_byte(exp_bytes[i]);
            wait_echo_byte(echo_byte, 500000);
            assert (echo_byte == exp_bytes[i])
                else tb_error($sformatf("Echo mismatch at idx %0d: exp=0x%0h got=0x%0h", i, exp_bytes[i], echo_byte));
        end

        // Allow status outputs to settle and verify.
        repeat (2000) @(posedge clk_i);
        assert (extlpbk_error_count_o == 16'h0000)
            else tb_error($sformatf("Unexpected external loopback errors: %0d", extlpbk_error_count_o));
        assert (extlpbk_echo_count_o == 16'd3)
            else tb_error($sformatf("Echo count mismatch: exp=3 got=%0d", extlpbk_echo_count_o));
        assert (extlpbk_last_rx_byte_o == exp_bytes[2])
            else tb_error($sformatf("Last RX byte mismatch: exp=0x%0h got=0x%0h", exp_bytes[2], extlpbk_last_rx_byte_o));
        assert (extlpbk_last_tx_byte_o == exp_bytes[2])
            else tb_error($sformatf("Last TX byte mismatch: exp=0x%0h got=0x%0h", exp_bytes[2], extlpbk_last_tx_byte_o));

        extlpbk_enable_i = 1'b0;
        host_tx_en_i     = 1'b0;
        repeat (20) @(posedge clk_i);

        tb_report();
        $finish;
    end

    // ------------------------------------------------------------
    // Tasks
    // ------------------------------------------------------------
    task automatic wait_extlpbk_active(
        input int unsigned timeout_cycles
    );
        int unsigned timeout_cntr;
    begin
        timeout_cntr = timeout_cycles;
        while (!extlpbk_busy_o) begin
            @(posedge clk_i);
            if (timeout_cntr == 0) begin
                tb_error("Timeout waiting for external loopback to become active");
                disable wait_extlpbk_active;
            end
            timeout_cntr--;
        end
    end
    endtask

    task automatic host_send_byte(
        input logic [7:0] tx_byte
    );
    begin
        @(posedge clk_i);
        host_tx_fifo_wdata_i <= tx_byte;
        host_tx_fifo_wen_i   <= 1'b1;

        @(posedge clk_i);
        host_tx_fifo_wen_i   <= 1'b0;

        assert (!host_tx_ovrn_o)
            else tb_error("Host TX FIFO overrun during stimulus");
    end
    endtask

    task automatic wait_echo_byte(
        output logic [7:0] rx_byte,
        input int unsigned timeout_cycles
    );
        int unsigned timeout_cntr;
    begin
        timeout_cntr = timeout_cycles;
        while (!mon_rx_valid_o) begin
            @(posedge clk_i);
            if (timeout_cntr == 0) begin
                tb_error("Timeout waiting for echoed byte in monitor RX FIFO");
                disable wait_echo_byte;
            end
            timeout_cntr--;
        end

        rx_byte = mon_rx_data_o;

        // Pop monitor RX FIFO entry.
        @(posedge clk_i);
        mon_rx_fifo_ren_i <= 1'b1;
        @(posedge clk_i);
        mon_rx_fifo_ren_i <= 1'b0;
    end
    endtask

endmodule
