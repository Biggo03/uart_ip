//==============================================================//
//  Module:       uart_intlpbk_synth_top
//  File:         uart_intlpbk_synth_top.sv
//  Description:  Minimal synthesis top for uart_intlpbk_harness.
//
//                 Key behaviors:
//                   - Instantiates uart_intlpbk_harness for synthesis bring-up
//                   - Drives internal loopback enable and command patterns
//                   - Exposes functional status outputs for board indicators
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:   None
//
//  Notes:
//==============================================================//
`timescale 1ns/1ps

module uart_intlpbk_synth_top (
    // -- clk and reset --
    input wire clk_i,
    input wire reset_i,
    input wire intlpbk_enable_i,

    output wire intlpbk_busy_o,
    output wire intlpbk_fail_seen_o,
    output wire intlpbk_pass_threshold_o
);

    logic [15:0] pass_cnt;
    logic [15:0] fail_cnt;

    uart_intlpbk_harness u_uart_intlpbk_harness (
        // -- clk and reset --
        .clk_i                    (clk_i),
        .reset_i                  (reset_i),

        // -- Internal loopback control --
        .intlpbk_enable_i         (intlpbk_enable_i),
        .intlpbk_read_cmd_i       (16'hF1F0),
        .intlpbk_write_cmd_i      (16'h0F1F),

        // -- Internal loopback status --
        .intlpbk_busy_o           (intlpbk_busy_o),
        .intlpbk_pass_count_o     (pass_cnt),
        .intlpbk_fail_count_o     (fail_cnt),
        .intlpbk_tx_ptr_o         (),
        .intlpbk_rx_ptr_o         (),
        .intlpbk_read_cmd_active_o(),
        .intlpbk_write_cmd_active_o()
    );

    assign intlpbk_fail_seen_o      = fail_cnt > 0;
    assign intlpbk_pass_threshold_o = pass_cnt > 1;

endmodule
