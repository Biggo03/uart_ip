//==============================================================//
//  Module:       baud_from_osr
//  File:         baud_from_osr.sv
//  Description:  Baud tick generator derived from OSR tick input.
//
//                 Key behaviors:
//                   - Counts OSR ticks and asserts baud_tick_o at OSR-1
//                   - Resets counter and tick on reset or when disabled
//                   - Exposes OSR counter value for sampling alignment
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:   OSR
//
//  Notes:        
//==============================================================//
module baud_from_osr #(
    parameter int OSR = 16
) (
    input wire clk_i,
    input wire reset_i,

    input wire enable_i,
    input wire osr_tick_i,

    output reg baud_tick_o,
    output reg [$clog2(OSR)-1:0] osr_cntr_o
);

    always_ff @(posedge clk_i) begin : baud_cntr
        if (reset_i) begin
            baud_tick_o <= 1'b0;
            osr_cntr_o  <= 0;
        end else if (enable_i) begin
            if (osr_cntr_o == OSR-1 && osr_tick_i) begin
                baud_tick_o <= 1'b1;
                osr_cntr_o <= 0;
            end else if (osr_tick_i) begin
                baud_tick_o <= 1'b0;
                osr_cntr_o <= osr_cntr_o + 1;
            end else begin
                baud_tick_o <= 1'b0;
            end
        end else begin
            baud_tick_o <= 1'b0;
            osr_cntr_o <= 0;
        end
    end
endmodule
