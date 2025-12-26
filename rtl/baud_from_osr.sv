module baud_from_osr #(
    parameter int OSR = 16
) (
    input wire clk_i,
    input wire reset_i,

    input wire enable_i,
    input wire osr_tick_i,

    output reg baud_tick_o
);

    reg [$clog2(OSR)-1:0] baud_cntr_r;

    always_ff @(posedge clk_i) begin : baud_cntr
        if (reset_i) begin
            baud_tick_o <= 1'b0;
            baud_cntr_r <= 0;
        end else if (enable_i) begin
            if (baud_cntr_r == OSR-1 && osr_tick_i) begin
                baud_tick_o <= 1'b1;
                baud_cntr_r <= 0;
            end else if (osr_tick_i) begin
                baud_tick_o <= 1'b0;
                baud_cntr_r <= baud_cntr_r + 1;
            end else begin
                baud_tick_o <= 1'b0;
            end
        end else begin
            baud_tick_o <= 1'b0;
            baud_cntr_r <= 0;
        end
    end
endmodule
