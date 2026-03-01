//==============================================================//
//  Module:       rx_engine_tb
//  File:         rx_engine_tb.sv
//  Description:  Testbench for rx_engine.
//
//                 This testbench verifies:
//                   - Start-bit detection and false-start rejection
//                   - Data sampling and bit assembly across OSR ticks
//                   - Stop-bit validation and FIFO write enable
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:   OSR
//
//  Notes:        - Uses common.sv dump_setup for VCD generation.
//==============================================================//
`timescale 1ns/1ps
`include "common.sv"

module rx_engine_tb;
    // ------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------
    localparam int OSR = 16;
    // ------------------------------------------------------------
    // TB signals
    // ------------------------------------------------------------
    int osr_cntr;
    int baud_cntr;

    // ------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------
    logic        clk_i;
    logic        reset_i;

    logic        osr_tick_i;

    logic [7:0]  rx_fifo_data_o;
    logic        rx_fifo_wen_o;

    logic        recieve_bit_i;
    logic        rx_en_i;

    logic        rx_busy_o;

    // ------------------------------------------------------------
    // DUT instantiation
    // ------------------------------------------------------------
    rx_engine #(
        .OSR(OSR)
    ) u_dut (
        .clk_i           (clk_i),
        .reset_i         (reset_i),
        .osr_tick_i      (osr_tick_i),

        .rx_fifo_data_o  (rx_fifo_data_o),
        .rx_fifo_wen_o   (rx_fifo_wen_o),

        .recieve_bit_i   (recieve_bit_i),
        .rx_en_i         (rx_en_i),

        .rx_busy_o       (rx_busy_o)
    );

    // ------------------------------------------------------------
    // Clock generation
    // ------------------------------------------------------------
    initial clk_i = 1'b0;
    always #5 clk_i = ~clk_i;  // 100 MHz clock

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
    // ------------------------------------------------------------
    // Basic initial block
    // ------------------------------------------------------------
    initial begin
        dump_setup();

        osr_cntr       = 0;

        // Default values
        reset_i        = 1'b1;
        osr_tick_i     = 1'b0;
        recieve_bit_i  = 1'b1; // idle line high
        rx_en_i        = 1'b0;

        $display("signals_initialized");

        // Hold reset
        repeat (5) @(posedge clk_i);
        reset_i = 1'b0;

        $display("reset complete");

        test_rx();
        tb_report();
        $finish();
    end

task automatic start_frame();
begin
    rx_en_i = 1'b1;

    repeat(5)@(posedge clk_i);

    recieve_bit_i = 1'b0;

    // Wait for synchronization
    repeat(2)@(posedge clk_i);
    #1;
    if (rx_busy_o) begin
        $display("Frame started");
    end else begin
        $display("Frame unsuccesfully started");
    end
end
endtask;

task automatic sample_start_bit(
    input logic start_bit_val
);
begin
    recieve_bit_i = start_bit_val;
    wait_for_osr_ticks(OSR);

    // start valid when start_bit_val == 0, therefore can just compare against
    // busy siganl
    unique case ({start_bit_val, rx_busy_o})
        2'b11: $display("False start verification");
        2'b10: $display("Succesful start rejection");
        2'b01: $display("Succesful start verification");
        2'b00: $display("False start rejection");
    endcase
end
endtask;

task automatic recieve_frame(
    input logic [7:0] exp_rx_data
);
begin
    for (int i=0; i < 8; i++) begin
        recieve_bit_i = exp_rx_data[i];
        wait_for_osr_ticks(OSR);
        assert (rx_fifo_data_o[i] == exp_rx_data[i]) else tb_error($sformatf("recieved data error on bit %0d\nExpected: %0b\nActual: %0b", i, exp_rx_data[i], rx_fifo_data_o[i]));
    end
    $display("Frame recieved");
end
endtask

task automatic sample_stop_bit(
    input logic stop_bit
);
begin
    recieve_bit_i = stop_bit;
    wait(~rx_busy_o);

    if (rx_fifo_wen_o == stop_bit) $display("Stop bit check succesful");
    else                           $display("Stop bit error");
end
endtask;

task automatic test_rx();
begin
    // Standard operation
    start_frame();
    sample_start_bit(1'b0);
    recieve_frame(8'b10101010);
    sample_stop_bit(1'b1);

    // start bit rejection
    start_frame();
    sample_start_bit(1'b1);

    // stop bit rejection
    start_frame();
    sample_start_bit(1'b0);
    recieve_frame(8'b10101010);
    sample_stop_bit(1'b0);
end
endtask;

task automatic wait_for_osr_ticks(
    input int osr_ticks
);
begin
    for (int i=0; i < osr_ticks; i++) begin
        wait(osr_tick_i);
        wait(~osr_tick_i);
    end
end
endtask;

endmodule
