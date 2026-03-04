//==============================================================//
//  Module:       uart_test_synth_top
//  File:         uart_test_synth_top.sv
//  Description:  Minimal synthesis top for uart_test_wrapper.
//
//                 Key behaviors:
//                   - Instantiates uart_test_wrapper for synthesis bring-up
//                   - Connects only clk/reset inputs
//                   - Leaves all other wrapper inputs unconnected as requested
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

module uart_test_synth_top (
    // -- clk and reset --
    input wire clk_i,
    input wire reset_i,
    input wire sw,

    output wire [2:0] led
);

    logic [15:0] pass_cnt;
    logic [15:0] fail_cnt;

    uart_test_wrapper u_uart_test_wrapper (
        // -- clk and reset --
        .clk_i                    (clk_i),
        .reset_i                  (reset_i),

        // -- UART pins --
        .rx_data_i                (),
        .tx_data_o                (),

        // -- External APB signals --
        .psel_i                   (1'b0),
        .penable_i                (),
        .pwrite_i                 (),
        .paddr_i                  (),
        .pwdata_i                 (),
        .prdata_o                 (),
        .pready_o                 (),
        .pslverr_o                (),

        // -- Internal loopback control --
        .intlpbk_enable_i         (sw),
        .intlpbk_read_cmd_i       (16'hF1F0),
        .intlpbk_write_cmd_i      (16'h0F1F),

        // -- Internal loopback status --
        .intlpbk_busy_o           (led[0]),
        .intlpbk_pass_count_o     (pass_cnt),
        .intlpbk_fail_count_o     (fail_cnt),
        .intlpbk_tx_ptr_o         (),
        .intlpbk_rx_ptr_o         (),
        .intlpbk_read_cmd_active_o(),
        .intlpbk_write_cmd_active_o()
    );

    assign led[1] = fail_cnt > 0;
    assign led[2] = pass_cnt > 1;

endmodule
