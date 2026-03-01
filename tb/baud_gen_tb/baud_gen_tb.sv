//==============================================================//
//  Module:       baud_gen_tb
//  File:         baud_gen_tb.sv
//  Description:  Testbench for baud_gen.
//
//                 This testbench verifies:
//                   - Tick generation when enabled at the divisor rate
//                   - No tick while disabled or after div_i changes
//                   - Reset behavior of the divider and tick output
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:   DIV_W
//
//  Notes:        - Uses common.sv dump_setup for VCD generation.
//==============================================================//
`timescale 1ns/1ps
`include "common.sv"

module baud_gen_tb;

    // --------------------------------------------------
    // Parameters
    // --------------------------------------------------
    localparam int DIV_W = 8;

    // --------------------------------------------------
    // DUT interface signals
    // --------------------------------------------------
    logic             clk_i;
    logic             reset_i;
    logic             en_i;
    logic [DIV_W-1:0] div_i;
    logic             osr_tick_o;

    // --------------------------------------------------
    // DUT instantiation
    // --------------------------------------------------
    baud_gen #(
        .DIV_W (DIV_W)
    ) dut (
        .clk_i      (clk_i),
        .reset_i    (reset_i),
        .en_i       (en_i),
        .div_i      (div_i),
        .osr_tick_o (osr_tick_o)
    );

    // --------------------------------------------------
    // Clock generation
    // --------------------------------------------------
    initial clk_i = 0;
    always #5 clk_i = ~clk_i;

    // --------------------------------------------------
    // Stimulus
    // --------------------------------------------------
    initial begin
        dump_setup();
        $display("beginning test");
        en_i = 1'b0;
        div_i = 1'b0;
        reset_i = 1'b1;
        repeat(2)@(posedge clk_i);
        reset_i = 1'b0;

        full_test(4, 2);

        tb_report();
        $finish();
    end


task automatic full_test(
    input int div,
    input int repetitions
);
begin
    div_i = div;
    @(posedge clk_i);
    #1;

    repeat(div)@(posedge clk_i);
    #1;
    assert (osr_tick_o == 1'b0) else tb_error($sformatf("[%0t] tick high when disabled", $realtime()));

    en_i = 1'b1;

    for (int i=0; i < repetitions; i++) begin
        repeat(div)@(posedge clk_i);
        #1;
        assert (osr_tick_o == 1'b1) else tb_error($sformatf("[%0t] tick unexpectedly low", $realtime()));
    end

    repeat(div-1)@(posedge clk_i);
    en_i = 1'b0;

    @(posedge clk_i);
    #1;
    assert (osr_tick_o == 1'b0) else tb_error($sformatf("[%0t] tick high on disable transition", $realtime()));

    en_i = 1'b1;
    repeat(div-1)@(posedge clk_i);
    div_i = div + 1;
    @(posedge clk_i);
    #1;
    assert (osr_tick_o == 1'b0) else tb_error($sformatf("[%0t] tick high on div_i change", $realtime()));

    reset_i = 1'b1;
    @(posedge clk_i);
    reset_i = 1'b0;
end
endtask

endmodule
