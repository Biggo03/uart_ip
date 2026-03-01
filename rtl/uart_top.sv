//==============================================================//
//  Module:       uart_top
//  File:         uart_top.sv
//  Description:  Top-level UART integration with regfile and FIFOs.
//
//                 Key behaviors:
//                   - Wires register interface to TX/RX engines and FIFOs
//                   - Generates osr_tick via baud_gen from BAUDDIV
//                   - Exposes TX/RX status and data through regfile
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
    // clk and reset
    input wire        clk_i,
    input wire        reset_i,

    // UART pins
    input wire        rx_data_i,
    output wire       tx_data_o,

    // regfile signals
    input wire        reg_we_i,
    input wire [4:0]  reg_waddr_i,
    input wire [31:0] reg_wdata_i,

    input wire  [4:0]  reg_raddr_i,
    output wire [31:0] reg_rdata_o
);

    // Register groups
    config_reg_t config_grp;
    wire status_reg_t status_grp;

    // Baud generator
    wire         osr_tick;

    uart_regfile u_uart_regfile (
        // clock and reset
        .clk_i       (clk_i),
        .reset_i     (reset_i),

        // register groups
        .config_grp  (config_grp),
        .status_grp  (status_grp),

        // Write signals
        .reg_we_i    (reg_we_i),
        .reg_waddr_i (reg_waddr_i),
        .reg_wdata_i (reg_wdata_i),

        // Read signals
        .reg_raddr_i (reg_raddr_i),
        .reg_rdata_o (reg_rdata_o)
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
        .clk_i       (clk_i),
        .reset_i     (reset_i),
        .osr_tick_i  (osr_tick),
        .rx_data_i   (rx_data_i),
        .rx_en_i     (config_grp.RX_EN),
        .rx_clr_ovrn_i(config_grp.RX_CLR_OVRN),
        .reg_raddr_i (reg_raddr_i),
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
        .clk_i       (clk_i),
        .reset_i     (reset_i),
        .osr_tick_i  (osr_tick),
        .tx_en_i     (config_grp.TX_EN),
        .tx_clr_ovrn_i(config_grp.TX_CLR_OVRN),
        .reg_we_i    (reg_we_i),
        .reg_waddr_i (reg_waddr_i),
        .reg_wdata_i (reg_wdata_i),
        .tx_busy_o   (status_grp.TX_BUSY),
        .tx_ovrn_o   (status_grp.TX_OVRN),
        .tx_lvl_o    (status_grp.TX_LVL),
        .tx_data_o   (tx_data_o)
    );

endmodule
