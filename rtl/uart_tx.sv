//==============================================================//
//  Module:       uart_tx
//  File:         uart_tx.sv
//  Description:  TX path wrapper around TX FIFO and tx_engine.
//
//                 Key behaviors:
//                   - Accepts TX writes from reg interface into TX FIFO
//                   - Feeds tx_engine with FIFO data and valid status
//                   - Exposes TX FIFO status and TX busy flag
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
module uart_tx (
    input wire        clk_i,
    input wire        reset_i,

    input wire        osr_tick_i,

    input wire        tx_en_i,
    input wire        tx_clr_ovrn_i,

    input wire        reg_we_i,
    input wire [4:0]  reg_waddr_i,
    input wire [31:0] reg_wdata_i,

    output wire       tx_busy_o,
    output wire       tx_ovrn_o,
    output wire [4:0] tx_lvl_o,
    output wire       tx_data_o
);

    // TX FIFO signals
    wire [7:0] tx_fifo_wdata;
    wire       tx_fifo_wen;
    wire       tx_fifo_ren;
    wire [7:0] tx_fifo_rdata;
    wire       tx_fifo_valid;

    assign tx_fifo_wen   = reg_we_i && (reg_waddr_i == `UART_TX_DATA_ADDR);
    assign tx_fifo_wdata = reg_wdata_i[7:0];

    tx_engine u_tx_engine (
        .clk_i           (clk_i),
        .reset_i         (reset_i),
        .osr_tick_i      (osr_tick_i),
        .tx_fifo_valid_i (tx_fifo_valid),
        .tx_fifo_data_i  (tx_fifo_rdata),
        .tx_fifo_ren_o   (tx_fifo_ren),
        .tx_en_i         (tx_en_i),
        .tx_busy_o       (tx_busy_o),
        .transmit_bit_o  (tx_data_o)
    );

    uart_fifo #(
        .WIDTH  (8),
        .DEPTH  (16)
    ) u_tx_fifo (
        .clk_i           (clk_i),
        .reset_i         (reset_i),
        .wdata_i         (tx_fifo_wdata),
        .wen_i           (tx_fifo_wen),
        .ren_i           (tx_fifo_ren),
        .rdata_o         (tx_fifo_rdata),
        .clr_ovrn_i      (tx_clr_ovrn_i),
        .ovrn_o          (tx_ovrn_o),
        .lvl_o           (tx_lvl_o),
        .valid_o         (tx_fifo_valid),
        .almost_empty_o  (),
        .empty_o         (),
        .almost_full_o   (),
        .full_o          ()
    );

endmodule
