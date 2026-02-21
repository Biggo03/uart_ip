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
    status_reg_t status_grp;

    // Baud generator
    wire         osr_tick;
    wire [15:0]  baud_div_i;
    wire         baud_div_we;

    // RX FIFO signals
    wire [7:0]   rx_fifo_wdata;
    wire         rx_fifo_wen;
    wire         rx_fifo_ren;
    wire [7:0]   rx_fifo_rdata;
    wire         rx_fifo_empty;
    wire         rx_fifo_full;

    // TX FIFO signals
    wire [7:0]   tx_fifo_wdata;
    wire         tx_fifo_wen;
    wire         tx_fifo_ren;
    wire [7:0]   tx_fifo_rdata;
    wire         tx_fifo_valid;
    wire         tx_fifo_empty;
    wire         tx_fifo_full;

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

    assign baud_div_we = reg_we_i && (reg_waddr_i == `UART_BAUD_CFG_ADDR);
    assign baud_div_i  = baud_div_we ? reg_wdata_i[15:0] : config_grp.BAUDDIV;

    baud_gen u_baud_gen (
        .clk_i      (clk_i),
        .reset_i    (reset_i),
        .en_i       (config_grp.TX_EN || config_grp.RX_EN),
        .div_i      (baud_div_i),
        .div_we_i   (baud_div_we),
        .osr_tick_o (osr_tick)
    );

/////////////////////////////
//            RX           //
/////////////////////////////

    assign rx_fifo_ren  = (reg_raddr_i == `UART_RX_DATA_ADDR);

    rx_engine u_rx_engine (
        .clk_i          (clk_i),
        .reset_i        (reset_i),
        .osr_tick_i     (osr_tick),
        .rx_fifo_data_o (rx_fifo_wdata),
        .rx_fifo_wen_o  (rx_fifo_wen),
        .recieve_bit_i  (rx_i),
        .rx_en_i        (config_grp.RX_EN),
        .rx_busy_o      (status_grp.RX_BUSY)
    );

    uart_fifo #(
        .WIDTH  (8),
        .DEPTH  (16),
        .ADDR_W (4)
    ) u_rx_fifo (
        .clk_i           (clk_i),
        .reset_i         (reset_i),
        .wdata_i         (rx_fifo_wdata),
        .wen_i           (rx_fifo_wen),
        .ren_i           (rx_fifo_ren),
        .rdata_o         (status_grp.RX_DATA),
        .clr_ovrn_i      (config_grp.RX_CLR_OVRN),
        .ovrn_o          (status_grp.RX_OVRN),
        .lvl_o           (status_grp.RX_LVL),
        .valid_o         (status_grp.RX_VALID),
        .almost_empty_o  (),
        .empty_o         (rx_fifo_empty),
        .almost_full_o   (),
        .full_o          (rx_fifo_full)
    );

/////////////////////////////
//            TX           //
/////////////////////////////

    assign tx_fifo_wen  = reg_we_i && (reg_waddr_i == `UART_TX_DATA_ADDR);
    assign tx_fifo_wdata = reg_wdata_i[7:0];

    tx_engine u_tx_engine (
        .clk_i           (clk_i),
        .reset_i         (reset_i),
        .osr_tick_i      (osr_tick),
        .tx_fifo_empty_i (tx_fifo_empty),
        .tx_fifo_valid_i (tx_fifo_valid),
        .tx_fifo_data_i  (tx_fifo_rdata),
        .tx_fifo_ren_o   (tx_fifo_ren),
        .tx_en_i         (config_grp.TX_EN),
        .tx_busy_o       (status_grp.TX_BUSY),
        .transmit_bit_o  (tx_o)
    );

    uart_fifo #(
        .WIDTH  (8),
        .DEPTH  (16),
        .ADDR_W (4)
    ) u_tx_fifo (
        .clk_i           (clk_i),
        .reset_i         (reset_i),
        .wdata_i         (tx_fifo_wdata),
        .wen_i           (tx_fifo_wen),
        .ren_i           (tx_fifo_ren),
        .rdata_o         (tx_fifo_rdata),
        .clr_ovrn_i      (config_grp.TX_CLR_OVRN),
        .ovrn_o          (status_grp.TX_OVRN),
        .lvl_o           (status_grp.TX_LVL),
        .valid_o         (tx_fifo_valid),
        .almost_empty_o  (),
        .empty_o         (tx_fifo_empty),
        .almost_full_o   (),
        .full_o          (tx_fifo_full)
    );

endmodule
