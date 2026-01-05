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
