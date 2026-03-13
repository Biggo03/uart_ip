//==============================================================//
//  Module:       uart_extlpbk_synth_top
//  File:         uart_extlpbk_synth_top.sv
//  Description:  Minimal synthesis top for uart_extlpbk_harness.
//
//                 Key behaviors:
//                   - Instantiates external-loopback UART harness
//                   - Exposes external UART RX/TX pins for PC traffic
//                   - Exposes status outputs for board indicators
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:   BAUDDIV_CFG
//
//  Notes:
//==============================================================//
`timescale 1ns/1ps

module uart_extlpbk_synth_top #(
    parameter int BAUDDIV_CFG = 16'd68
) (
    // -- clk and reset --
    input wire clk_i,
    input wire reset_i,
    input wire extlpbk_enable_i,

    // -- External UART pins --
    input wire uart_ext_rx_i,
    output wire uart_ext_tx_o,

    // -- Status outputs --
    output wire extlpbk_busy_o,
    output wire extlpbk_error_seen_o,
    output wire extlpbk_activity_o,

    output reg debug_led
);

    wire [15:0] echo_count;
    wire [15:0] error_count;
    wire [7:0]  last_rx_byte;
    wire [7:0]  last_tx_byte;

    uart_extlpbk_harness #(
        .BAUDDIV_CFG(BAUDDIV_CFG)
    ) u_uart_extlpbk_harness (
        // -- clk and reset --
        .clk_i               (clk_i),
        .reset_i             (reset_i),

        // -- External loopback control --
        .extlpbk_enable_i    (extlpbk_enable_i),

        // -- External UART pins --
        .uart_rx_data_i      (uart_ext_rx_i),
        .uart_tx_data_o      (uart_ext_tx_o),

        // -- External loopback status --
        .extlpbk_busy_o      (extlpbk_busy_o),
        .extlpbk_echo_count_o(echo_count),
        .extlpbk_error_count_o(error_count),
        .extlpbk_last_rx_byte_o(last_rx_byte),
        .extlpbk_last_tx_byte_o(last_tx_byte)
    );

    assign extlpbk_error_seen_o = (error_count != 16'h0);
    assign extlpbk_activity_o   = echo_count[0];

endmodule
