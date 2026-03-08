//==============================================================//
//  Module:       uart_extlpbk_harness
//  File:         uart_extlpbk_harness.sv
//  Description:  UART wrapper dedicated to external loopback echo.
//
//                 Key behaviors:
//                   - Instantiates uart_top and extlpbk_fsm
//                   - Drives uart_top APB solely from external-loopback FSM
//                   - Uses external UART RX/TX pins (no internal tie-off)
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

module uart_extlpbk_harness #(
    parameter int BAUDDIV_CFG = 16'd68
) (
    // -- clk and reset --
    input wire        clk_i,
    input wire        reset_i,

    // -- External loopback control --
    input wire        extlpbk_enable_i,

    // -- External UART pins --
    input wire        uart_rx_data_i,
    output wire       uart_tx_data_o,

    // -- External loopback status --
    output wire       extlpbk_busy_o,
    output wire [15:0] extlpbk_echo_count_o,
    output wire [15:0] extlpbk_error_count_o,
    output wire [7:0]  extlpbk_last_rx_byte_o,
    output wire [7:0]  extlpbk_last_tx_byte_o
);

    wire        lb_psel;
    wire        lb_penable;
    wire        lb_pwrite;
    wire [4:0]  lb_paddr;
    wire [31:0] lb_pwdata;

    wire [31:0] uart_prdata;
    wire        uart_pready;
    wire        uart_pslverr;

    extlpbk_fsm #(
        .BAUDDIV_CFG(BAUDDIV_CFG)
    ) u_extlpbk_fsm (
        // -- clk and reset --
        .clk_i          (clk_i),
        .reset_i        (reset_i),

        // -- Control --
        .enable_i       (extlpbk_enable_i),

        // -- Status --
        .busy_o         (extlpbk_busy_o),
        .echo_count_o   (extlpbk_echo_count_o),
        .error_count_o  (extlpbk_error_count_o),
        .last_rx_byte_o (extlpbk_last_rx_byte_o),
        .last_tx_byte_o (extlpbk_last_tx_byte_o),

        // -- APB master interface --
        .psel_o         (lb_psel),
        .penable_o      (lb_penable),
        .pwrite_o       (lb_pwrite),
        .paddr_o        (lb_paddr),
        .pwdata_o       (lb_pwdata),
        .prdata_i       (uart_prdata),
        .pready_i       (uart_pready),
        .pslverr_i      (uart_pslverr)
    );

    uart_top u_uart_top (
        // -- clk and reset --
        .clk_i          (clk_i),
        .reset_i        (reset_i),

        // -- UART pins --
        .rx_data_i      (uart_rx_data_i),
        .tx_data_o      (uart_tx_data_o),

        // -- APB signals --
        .psel_i         (lb_psel),
        .penable_i      (lb_penable),
        .pwrite_i       (lb_pwrite),
        .paddr_i        (lb_paddr),
        .pwdata_i       (lb_pwdata),
        .prdata_o       (uart_prdata),
        .pready_o       (uart_pready),
        .pslverr_o      (uart_pslverr)
    );

endmodule
