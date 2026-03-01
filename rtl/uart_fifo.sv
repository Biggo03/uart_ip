//==============================================================//
//  Module:       uart_fifo
//  File:         uart_fifo.sv
//  Description:  Generic synchronous FIFO with status flags.
//
//                 Key behaviors:
//                   - Supports independent read/write with level tracking
//                   - Provides empty/full and almost-empty/full flags
//                   - Tracks overrun when writes occur while full
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:   WIDTH, DEPTH, ADDR_W
//
//  Notes:
//==============================================================//
`timescale 1ns/1ps

module uart_fifo #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 16
) (
    input  wire             clk_i,
    input  wire             reset_i,

    input  wire [WIDTH-1:0] wdata_i,
    input  wire             wen_i,

    input  wire             ren_i,
    output wire [WIDTH-1:0] rdata_o,

    input wire              clr_ovrn_i,
    output reg              ovrn_o,

    output reg [$clog2(DEPTH):0]   lvl_o, // Needs to be able to reach DEPTH, not DEPTH-1
    output wire             valid_o,

    output wire             almost_empty_o,
    output wire             empty_o,

    output wire             almost_full_o,
    output wire             full_o
);

    localparam int ADDR_W = $clog2(DEPTH);

    reg [ADDR_W-1:0] write_ptr_r;
    reg [ADDR_W-1:0] read_ptr_r;

    reg [WIDTH-1:0] fifo_data_r [DEPTH-1:0];

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            write_ptr_r <= 0;
            read_ptr_r  <= 0;
            ovrn_o      <= 0;
            lvl_o       <= 0;

            for (int i=0; i < DEPTH; i++) begin
                fifo_data_r[i] <= 0;
            end
        end else begin
            // write logic
            if (wen_i && ~full_o) begin : write_logic
                fifo_data_r[write_ptr_r] <= wdata_i;

                if (write_ptr_r == DEPTH-1) write_ptr_r <= 0;
                else                        write_ptr_r <= write_ptr_r + 1;
            end

            // read logic
            if (ren_i && ~empty_o) begin : read_logic
                if (read_ptr_r == DEPTH-1) read_ptr_r <= 0;
                else                       read_ptr_r <= read_ptr_r + 1;
            end

            // overrun logic
            if (wen_i && full_o) ovrn_o <= 1'b1;
            else if (clr_ovrn_i) ovrn_o <= 1'b0;

            // level logic
            casez ({wen_i && ~full_o, ren_i && ~empty_o})
                2'b10: lvl_o <= lvl_o + 1;
                2'b01: lvl_o <= lvl_o - 1;
                default:;
            endcase
        end
    end

    // Boolean Flags
    assign valid_o        = ~empty_o;
    assign almost_empty_o = (lvl_o == 1);
    assign empty_o        = (lvl_o == 0);

    assign almost_full_o = (lvl_o == DEPTH-1);
    assign full_o        = (lvl_o == DEPTH);

    // read data
    assign rdata_o = fifo_data_r[read_ptr_r];

endmodule
