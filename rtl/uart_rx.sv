//==============================================================//
//  Module:       uart_rx
//  File:         uart_rx.sv
//  Description:  RX path wrapper around rx_engine and RX FIFO.
//
//                 Key behaviors:
//                   - Runs rx_engine and writes received bytes into RX FIFO
//                   - Exposes RX FIFO status and data to the reg interface
//                   - Updates RX_VALID/RX_DATA on RX data reads
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
module uart_rx (
    // -- clk and reset --
    input wire        clk_i,
    input wire        reset_i,

    // -- Baud and serial input --
    input wire        osr_tick_i,
    input wire        rx_data_i,

    // -- RX control --
    input wire        rx_en_i,
    input wire        rx_clr_ovrn_i,
    input wire        rx_fifo_ren_i,

    // -- RX status and data --
    output wire       rx_busy_o,
    output wire       rx_ovrn_o,
    output wire [4:0] rx_lvl_o,
    output wire       rx_valid_o,
    output wire [7:0] rx_data_o
);

    // RX FIFO signals
    wire [7:0] rx_fifo_wdata;
    wire       rx_fifo_wen;

    rx_engine u_rx_engine (
        // -- clk and reset --
        .clk_i          (clk_i),
        .reset_i        (reset_i),

        // -- Baud --
        .osr_tick_i     (osr_tick_i),

        // -- FIFO --
        .rx_fifo_data_o (rx_fifo_wdata),
        .rx_fifo_wen_o  (rx_fifo_wen),

        // -- Rx status and data --
        .recieve_bit_i  (rx_data_i),
        .rx_en_i        (rx_en_i),
        .rx_busy_o      (rx_busy_o)
    );

    uart_fifo #(
        .WIDTH  (8),
        .DEPTH  (16)
    ) u_rx_fifo (
        .clk_i           (clk_i),
        .reset_i         (reset_i),
        .wdata_i         (rx_fifo_wdata),
        .wen_i           (rx_fifo_wen),
        .ren_i           (rx_fifo_ren_i),
        .rdata_o         (rx_data_o),
        .clr_ovrn_i      (rx_clr_ovrn_i),
        .ovrn_o          (rx_ovrn_o),
        .lvl_o           (rx_lvl_o),
        .valid_o         (rx_valid_o),
        .almost_empty_o  (),
        .empty_o         (),
        .almost_full_o   (),
        .full_o          ()
    );

endmodule
