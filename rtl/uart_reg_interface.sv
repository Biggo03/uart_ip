//==============================================================//
//  Module:       uart_reg_interface
//  File:         uart_reg_interface.sv
//  Description:  APB wrapper around the generated UART regfile.
//
//                 Key behaviors:
//                   - Converts APB read/write transfers to regfile controls
//                   - Always responds in a single cycle (no wait states)
//                   - Raises PSLVERR on selected out-of-range addresses
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

module uart_reg_interface (
    // -- APB clock and reset --
    input wire pclk_i,
    input wire reset_i,

    // -- APB interface --
    input wire        psel_i,
    input wire        penable_i,
    input wire        pwrite_i,
    input wire [4:0] paddr_i,
    input wire [31:0] pwdata_i,
    output wire [31:0] prdata_o,
    output wire       pready_o,
    output wire       pslverr_o,

    // -- RX and TX derivesd signals --
    output wire       rx_fifo_ren_o,
    output wire       tx_fifo_wen_o,
    output wire [7:0] tx_fifo_wdata_o,

    // -- Register groups --
    output config_reg_t config_grp,
    input wire status_reg_t status_grp
);

    wire        reg_we;
    wire [31:0] reg_rdata;

    // APB access phase write strobe.
    assign reg_we    = psel_i && penable_i && pwrite_i;

    // Read access to RX_DATA pops one byte from RX FIFO.
    assign rx_fifo_ren_o = psel_i && penable_i && !pwrite_i &&
                           (paddr_i == `UART_RX_DATA_ADDR);

    // Write access to TX_DATA pushes one byte into TX FIFO.
    assign tx_fifo_wen_o   = reg_we && (paddr_i == `UART_TX_DATA_ADDR);
    assign tx_fifo_wdata_o = pwdata_i[7:0];

    // No wait-state support: always ready when selected.
    assign pready_o  = 1'b1;

    // Error on addresses above the highest UART register offset.
    assign pslverr_o = psel_i && (paddr_i > 5'h10);

    assign prdata_o  = reg_rdata;

    uart_regfile u_uart_regfile (
        // -- Clk and Reset --
        .clk_i       (pclk_i),
        .reset_i     (reset_i),

        // -- Register Groups --
        .config_grp  (config_grp),
        .status_grp  (status_grp),

        // -- Write Signals --
        .reg_we_i    (reg_we),
        .reg_waddr_i (paddr_i),
        .reg_wdata_i (pwdata_i),

        // -- Read Signals --
        .reg_raddr_i (paddr_i),
        .reg_rdata_o (reg_rdata)
    );

endmodule
