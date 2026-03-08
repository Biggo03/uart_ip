//==============================================================//
//  Module:       uart_test_wrapper_tb
//  File:         uart_test_wrapper_tb.sv
//  Description:  Testbench for uart_intlpbk_harness.
//
//                 This testbench verifies:
//                   - Internal loopback FSM can execute command vectors
//                   - Internal loopback reports expected pass/fail counts
//                   - Internal loopback status outputs are coherent
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:   CLK_PERIOD_NS
//
//  Notes:        - Uses common.sv dump_setup for VCD generation.
//==============================================================//
`timescale 1ns/1ps
`include "common.sv"

module uart_test_wrapper_tb;

    // ------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------
    localparam real CLK_PERIOD_NS = 13.333; // 75 MHz

    // ------------------------------------------------------------
    // DUT/TB signals
    // ------------------------------------------------------------
    logic        clk_i;
    logic        reset_i;

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

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    uart_intlpbk_harness dut (
        // -- clk and reset --
        .clk_i                    (clk_i),
        .reset_i                  (reset_i),

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
        reset_i             = 1'b1;
        intlpbk_enable_i    = 1'b0;
        intlpbk_read_cmd_i  = 16'h0000;
        intlpbk_write_cmd_i = 16'h0000;

        // Reset pulse
        repeat (5) @(posedge clk_i);
        reset_i = 1'b0;

        // Start internal loopback FSM with 4 TRANSMIT commands then 4 READs.
        intlpbk_read_cmd_i  = 16'h00F0;
        intlpbk_write_cmd_i = 16'h000F;
        intlpbk_enable_i    = 1'b1;

        // Wait for loopback run start and completion.
        wait_internal_loopback_start(50000);
        wait_internal_loopback_done(500000);

        // Validate results.
        assert (intlpbk_fail_count_o == 16'h0000)
            else tb_error($sformatf("Internal loopback reported failures: %0d", intlpbk_fail_count_o));
        assert (intlpbk_pass_count_o == 16'h0004)
            else tb_error($sformatf("Internal loopback pass count mismatch: exp=4 got=%0d", intlpbk_pass_count_o));
        assert (intlpbk_tx_ptr_o == 4'd4)
            else tb_error($sformatf("Internal loopback TX pointer mismatch: exp=4 got=%0d", intlpbk_tx_ptr_o));
        assert (intlpbk_rx_ptr_o == 4'd4)
            else tb_error($sformatf("Internal loopback RX pointer mismatch: exp=4 got=%0d", intlpbk_rx_ptr_o));

        // Deassert enable so FSM returns to edge-sensitive idle behavior.
        intlpbk_enable_i = 1'b0;
        repeat (20) @(posedge clk_i);

        tb_report();
        $finish;
    end

    // ------------------------------------------------------------
    // Tasks
    // ------------------------------------------------------------
    task automatic wait_internal_loopback_start(
        input int unsigned timeout_cycles
    );
        int unsigned timeout_cntr;
    begin
        timeout_cntr = timeout_cycles;
        while (!intlpbk_busy_o) begin
            @(posedge clk_i);
            if (timeout_cntr == 0) begin
                tb_error("Timeout waiting for internal loopback start");
                disable wait_internal_loopback_start;
            end
            timeout_cntr--;
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
