`timescale 1ns/1ps
`include "common.sv"

module tx_engine_tb;

    // ------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------
    localparam int OSR = 16;

    // ------------------------------------------------------------------
    // TB signals
    // ------------------------------------------------------------------
    int baud_cntr;
    logic [7:0] exp_tx_fifo_data;

    // ------------------------------------------------------------------
    // Clock / Reset
    // ------------------------------------------------------------------
    logic clk_i;
    logic reset_i;

    // ------------------------------------------------------------------
    // Baud / OSR
    // ------------------------------------------------------------------
    logic osr_tick_i;

    // ------------------------------------------------------------------
    // FIFO interface
    // ------------------------------------------------------------------
    logic        tx_fifo_empty_i;
    logic        tx_fifo_valid_i;
    logic [7:0]  tx_fifo_data_i;
    logic        tx_fifo_ren_o;

    // ------------------------------------------------------------------
    // Control
    // ------------------------------------------------------------------
    logic tx_en_i;

    // ------------------------------------------------------------------
    // Outputs
    // ------------------------------------------------------------------
    logic tx_busy_o;
    logic transmit_bit_o;

    // ------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------
    tx_engine #(
        .OSR(OSR)
    ) u_dut (
        .clk_i             (clk_i),
        .reset_i           (reset_i),
        .osr_tick_i        (osr_tick_i),
        .tx_fifo_empty_i   (tx_fifo_empty_i),
        .tx_fifo_valid_i   (tx_fifo_valid_i),
        .tx_fifo_data_i    (tx_fifo_data_i),
        .tx_fifo_ren_o     (tx_fifo_ren_o),
        .tx_en_i           (tx_en_i),
        .tx_busy_o         (tx_busy_o),
        .transmit_bit_o    (transmit_bit_o)
    );

    // ------------------------------------------------------------------
    // Clock and baud generation
    // ------------------------------------------------------------------
    initial clk_i = 1'b0;
    always #5 clk_i = ~clk_i;   // 100 MHz clock

    always @(posedge clk_i) begin : baud_gen
        if (reset_i) begin
            osr_tick_i <= 0;
            baud_cntr  <= 0;
        end else if (baud_cntr == 10) begin
            osr_tick_i <= 1'b1;
            baud_cntr  <= 0;
        end else begin
            baud_cntr  <= baud_cntr + 1;
            osr_tick_i <= 1'b0;
        end
    end
    // ------------------------------------------------------------------
    // Initial block
    // ------------------------------------------------------------------
    initial begin
        dump_setup();
        // Testbench initialization
        baud_cntr = 0;
        // Default values
        reset_i           = 1'b1;
        tx_fifo_empty_i   = 1'b1;
        tx_fifo_valid_i   = 1'b0;
        tx_fifo_data_i    = '0;
        tx_en_i           = 1'b0;

        // Reset pulse
        repeat (5) @(posedge clk_i);
        reset_i = 1'b0;

        test_tx(8'b10101010);
        test_tx(8'b01010101);

        repeat (100) @(posedge clk_i);
        $finish;
    end

task automatic test_tx(
    input logic [7:0] exp_tx_fifo_data
);
    int osr_cntr;
begin
    tx_fifo_data_i = exp_tx_fifo_data;

    tx_en_i = 1'b1;

    @(posedge clk_i);
    #1;
    assert (~tx_busy_o) else $error("[%t] busy asserted in IDLE", $realtime());

    tx_fifo_empty_i = 1'b0;
    @(posedge clk_i);
    #1;
    assert(tx_busy_o && tx_fifo_ren_o) else $error("[%t] transition to FETCH failed", $realtime());
    tx_fifo_valid_i = 1'b1;

    @(posedge clk_i);
    #1;
    assert(~tx_fifo_ren_o) else $error("[%t] Transition to SEND failed", $realtime());

    wait_for_baud_tick();
    @(posedge clk_i);
    #1;
    assert (~transmit_bit_o) else $error("[%t] Start bit not low", $realtime());

    for (int i = 0; i < 8; i++) begin
        wait_for_baud_tick();
        @(posedge clk_i);
        #1;
        assert (transmit_bit_o == exp_tx_fifo_data[i]) else $error("[%t] Transmit error on bit %d", $realtime(), i);
    end

    wait_for_baud_tick();
    @(posedge clk_i);
    #1;
    assert (transmit_bit_o == 1'b1) else $error("[%t] Stop bit error", $realtime());

    wait(~tx_busy_o);

    tx_fifo_empty_i = 1'b1;
end
endtask;

task automatic wait_for_baud_tick();
begin
    for (int i=0; i < OSR; i++) begin
        wait(osr_tick_i);
        @(posedge clk_i);
        #1;
    end
    assert(u_dut.baud_tick_r) else $error("[%t] baud tick not high as expected", $realtime());
end
endtask;

endmodule
