module baud_gen #(
    parameter int OSR   = 16,
    parameter int DIV_W = 16
) (
    input wire             clk_i,
    input wire             reset_i,

    input wire             en_i,

    input wire [DIV_W-1:0] div_i,
    input wire             div_we_i,

    output reg             osr_tick_o
);

    reg [DIV_W-1:0] div_r;
    reg [DIV_W-1:0] div_cntr_r;

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            div_r      <= 0;
            div_cntr_r <= 0;
            osr_tick_o <= 0;
        end else if (div_we_i) begin
            div_r      <= div_i;
            div_cntr_r <= 0;
            osr_tick_o <= 1'b0;
        end else if (en_i) begin
             if (div_cntr_r == div_r-1) begin
                div_cntr_r <= 0;
                osr_tick_o <= 1'b1;
            end else begin
                div_cntr_r <= div_cntr_r + 1;
                osr_tick_o <= 1'b0;
            end
        end else begin
            div_cntr_r <= 0;
            osr_tick_o <= 0;
        end
    end

endmodule;
