//==============================================================//
//  Module:       baud_gen
//  File:         baud_gen.sv
//  Description:  Baud oversample tick generator.
//
//                 Key behaviors:
//                   - Generates osr_tick_o at a rate set by div_i when enabled
//                   - Resets and clears divider state on reset or div_i change
//                   - Holds osr_tick_o low when disabled
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:   DIV_W
//
//  Notes:        
//==============================================================//
module baud_gen #(
    parameter int DIV_W = 16
) (
    input wire             clk_i,
    input wire             reset_i,

    input wire             en_i,

    input wire [DIV_W-1:0] div_i,

    output reg             osr_tick_o
);

    reg [DIV_W-1:0] div_r;
    reg [DIV_W-1:0] div_cntr_r;

    reg             baud_clear_r;

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            div_r        <= 'd0;
            baud_clear_r <= 1'b0;
        end else if (div_i != div_r) begin
            div_r        <= div_i;
            baud_clear_r <= 1'b1;
        end else begin
            baud_clear_r <= 1'b0;
        end
    end

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            div_cntr_r <= 'd0;
            osr_tick_o <= 1'b0;
        end else if (baud_clear_r) begin
            div_cntr_r <= 'd0;
            osr_tick_o <= 1'b0;
        end else if (en_i) begin
             if (div_cntr_r == div_r-1) begin
                div_cntr_r <= 'd0;
                osr_tick_o <= 1'b1;
            end else begin
                div_cntr_r <= div_cntr_r + 1;
                osr_tick_o <= 1'b0;
            end
        end else begin
            div_cntr_r <= 'd0;
            osr_tick_o <= 1'b0;
        end
    end

endmodule;
