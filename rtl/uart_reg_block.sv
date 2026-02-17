`timescale 1ns/1ps

module uart_reg_block (
    // clk and reset
    input  wire        clk_i,
    input  wire        reset_i,

    // Write Signals
    input  wire        wen_i,
    input  wire [4:0]  waddr_i,
    input  wire [31:0] wdata_i,

    // Read Signals
    input  wire [4:0]  raddr_i,
    output wire [31:0] rdata_o
);



endmodule
