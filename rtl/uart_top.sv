//==============================================================//
//  Module:       uart_top
//  File:         uart_top.sv
//  Description:  Top-level UART integration with APB register interface.
//
//                 Key behaviors:
//                   - Wires APB register interface to TX/RX engines and FIFOs
//                   - Generates osr_tick via baud_gen from BAUDDIV
//                   - Exposes TX/RX status and data through APB register map
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
`include "uart_reg_macros.sv"
import uart_reg_pkg::*;

module uart_top (
    // -- clk and reset --
    input wire         clk_i,
    input wire         reset_i,

    // -- UART pins --
    input wire         rx_data_i,
    output wire        tx_data_o,

    // -- APB signals --
    input wire         psel_i,
    input wire         penable_i,
    input wire         pwrite_i,
    input wire  [4:0]  paddr_i,
    input wire  [31:0] pwdata_i,
    output wire [31:0] prdata_o,
    output wire        pready_o,
    output wire        pslverr_o
);

    // -- Register groups --
    config_reg_t config_grp;
    wire status_reg_t status_grp;
    wire        rx_fifo_ren;
    wire        tx_fifo_wen;
    wire [7:0]  tx_fifo_wdata;

    // -- Baud generator --
    wire         osr_tick;

    uart_reg_interface u_uart_reg_interface (
        // -- APB clock and reset --
        .pclk_i      (clk_i),
        .reset_i     (reset_i),

        // -- APB interface --
        .psel_i      (psel_i),
        .penable_i   (penable_i),
        .pwrite_i    (pwrite_i),
        .paddr_i     (paddr_i),
        .pwdata_i    (pwdata_i),
        .prdata_o    (prdata_o),
        .pready_o    (pready_o),
        .pslverr_o   (pslverr_o),

        // -- RX and TX derived signals --
        .rx_fifo_ren_o(rx_fifo_ren),
        .tx_fifo_wen_o(tx_fifo_wen),
        .tx_fifo_wdata_o(tx_fifo_wdata),

        // -- Register groups --
        .config_grp  (config_grp),
        .status_grp  (status_grp)
    );

/////////////////////////////
//          BAUD           //
/////////////////////////////

    baud_gen u_baud_gen (
        .clk_i      (clk_i),
        .reset_i    (reset_i),
        .en_i       (config_grp.TX_EN || config_grp.RX_EN),
        .div_i      (config_grp.BAUDDIV),
        .osr_tick_o (osr_tick)
    );

/////////////////////////////
//            RX           //
/////////////////////////////

    uart_rx u_uart_rx (
        // -- clk and reset --
        .clk_i       (clk_i),
        .reset_i     (reset_i),

        // -- Baud and serial input --
        .osr_tick_i  (osr_tick),
        .rx_data_i   (rx_data_i),

        // -- RX control --
        .rx_en_i     (config_grp.RX_EN),
        .rx_clr_ovrn_i(config_grp.RX_CLR_OVRN),
        .rx_fifo_ren_i(rx_fifo_ren),

        // -- RX status and data --
        .rx_busy_o   (status_grp.RX_BUSY),
        .rx_ovrn_o   (status_grp.RX_OVRN),
        .rx_lvl_o    (status_grp.RX_LVL),
        .rx_valid_o  (status_grp.RX_VALID),
        .rx_data_o   (status_grp.RX_DATA)
    );

/////////////////////////////
//            TX           //
/////////////////////////////

    uart_tx u_uart_tx (
        // -- clk and reset --
        .clk_i       (clk_i),
        .reset_i     (reset_i),

        // -- Baud --
        .osr_tick_i  (osr_tick),

        // -- TX control and FIFO write input --
        .tx_en_i     (config_grp.TX_EN),
        .tx_clr_ovrn_i(config_grp.TX_CLR_OVRN),
        .tx_fifo_wen_i(tx_fifo_wen),
        .tx_fifo_wdata_i(tx_fifo_wdata),

        // -- TX status and serial output --
        .tx_busy_o   (status_grp.TX_BUSY),
        .tx_ovrn_o   (status_grp.TX_OVRN),
        .tx_lvl_o    (status_grp.TX_LVL),
        .tx_data_o   (tx_data_o)
    );

endmodule
