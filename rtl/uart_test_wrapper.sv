//==============================================================//
//  Module:       uart_test_wrapper
//  File:         uart_test_wrapper.sv
//  Description:  UART wrapper with optional internal loopback APB master.
//
//                 Key behaviors:
//                   - Instantiates uart_top and intlpbk_fsm
//                   - Muxes UART APB control between external host and loopback FSM
//                   - Blocks external APB accesses while loopback FSM owns the bus
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

module uart_test_wrapper (
    // -- clk and reset --
    input wire        clk_i,
    input wire        reset_i,

    // -- UART pins --
    input wire        rx_data_i,
    output wire       tx_data_o,

    // -- External APB signals --
    input wire        psel_i,
    input wire        penable_i,
    input wire        pwrite_i,
    input wire [4:0]  paddr_i,
    input wire [31:0] pwdata_i,
    output wire [31:0] prdata_o,
    output wire       pready_o,
    output wire       pslverr_o,

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

    wire        uart_rx_data;

    wire        use_intlbk_apb;

    wire        uart_psel;
    wire        uart_penable;
    wire        uart_pwrite;
    wire [4:0]  uart_paddr;
    wire [31:0] uart_pwdata;

    assign use_intlbk_apb = intlpbk_enable_i || intlpbk_busy_o;

    assign uart_psel    = use_intlbk_apb ? lb_psel    : psel_i;
    assign uart_penable = use_intlbk_apb ? lb_penable : penable_i;
    assign uart_pwrite  = use_intlbk_apb ? lb_pwrite  : pwrite_i;
    assign uart_paddr   = use_intlbk_apb ? lb_paddr   : paddr_i;
    assign uart_pwdata  = use_intlbk_apb ? lb_pwdata  : pwdata_i;

    assign uart_rx_data = use_intlbk_apb ? tx_data_o : rx_data_i;

    // External APB response is blocked while internal loopback owns APB.
    assign prdata_o  = use_intlbk_apb ? 32'h0000_0000 : uart_prdata;
    assign pready_o  = use_intlbk_apb ? 1'b1          : uart_pready;
    assign pslverr_o = use_intlbk_apb ? psel_i        : uart_pslverr;

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
        .tx_data_o          (tx_data_o),

        // -- APB signals --
        .psel_i             (uart_psel),
        .penable_i          (uart_penable),
        .pwrite_i           (uart_pwrite),
        .paddr_i            (uart_paddr),
        .pwdata_i           (uart_pwdata),
        .prdata_o           (uart_prdata),
        .pready_o           (uart_pready),
        .pslverr_o          (uart_pslverr)
    );

endmodule
