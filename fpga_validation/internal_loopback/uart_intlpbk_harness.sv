//==============================================================//
//  Module:       uart_intlpbk_harness
//  File:         uart_intlpbk_harness.sv
//  Description:  UART wrapper dedicated to internal loopback.
//
//                 Key behaviors:
//                   - Instantiates uart_top and intlpbk_fsm
//                   - Drives uart_top APB solely from loopback FSM
//                   - Hardwires UART TX back to UART RX internally
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

module uart_intlpbk_harness (
    // -- clk and reset --
    input wire        clk_i,
    input wire        reset_i,

    // -- Internal loopback control --
    input wire        intlpbk_enable_i,
    input wire [15:0] intlpbk_read_cmd_i,
    input wire [15:0] intlpbk_write_cmd_i,

    // -- Internal loopback status --
    output wire       intlpbk_busy_o,
    output wire [15:0] intlpbk_pass_count_o,
    output wire [15:0] intlpbk_fail_count_o,
    output wire [3:0]  intlpbk_tx_ptr_o,
    output wire [3:0]  intlpbk_rx_ptr_o,
    output wire [15:0] intlpbk_read_cmd_active_o,
    output wire [15:0] intlpbk_write_cmd_active_o
);

    wire        lb_psel;
    wire        lb_penable;
    wire        lb_pwrite;
    wire [4:0]  lb_paddr;
    wire [31:0] lb_pwdata;

    wire [31:0] uart_prdata;
    wire        uart_pready;
    wire        uart_pslverr;

    wire        uart_tx_data;
    wire        uart_rx_data;

    assign uart_rx_data = uart_tx_data;

    intlpbk_fsm u_intlpbk_fsm (
        // -- clk and reset --
        .clk_i              (clk_i),
        .reset_i            (reset_i),

        // -- Control --
        .enable_i           (intlpbk_enable_i),
        .read_cmd_i         (intlpbk_read_cmd_i),
        .write_cmd_i        (intlpbk_write_cmd_i),

        // -- Status --
        .busy_o             (intlpbk_busy_o),
        .pass_count_o       (intlpbk_pass_count_o),
        .fail_count_o       (intlpbk_fail_count_o),
        .tx_ptr_o           (intlpbk_tx_ptr_o),
        .rx_ptr_o           (intlpbk_rx_ptr_o),
        .read_cmd_active_o  (intlpbk_read_cmd_active_o),
        .write_cmd_active_o (intlpbk_write_cmd_active_o),

        // -- APB master interface --
        .psel_o             (lb_psel),
        .penable_o          (lb_penable),
        .pwrite_o           (lb_pwrite),
        .paddr_o            (lb_paddr),
        .pwdata_o           (lb_pwdata),
        .prdata_i           (uart_prdata),
        .pready_i           (uart_pready),
        .pslverr_i          (uart_pslverr)
    );

    uart_top u_uart_top (
        // -- clk and reset --
        .clk_i              (clk_i),
        .reset_i            (reset_i),

        // -- UART pins --
        .rx_data_i          (uart_rx_data),
        .tx_data_o          (uart_tx_data),

        // -- APB signals --
        .psel_i             (lb_psel),
        .penable_i          (lb_penable),
        .pwrite_i           (lb_pwrite),
        .paddr_i            (lb_paddr),
        .pwdata_i           (lb_pwdata),
        .prdata_o           (uart_prdata),
        .pready_o           (uart_pready),
        .pslverr_o          (uart_pslverr)
    );

endmodule
