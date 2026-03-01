//==============================================================//
//  Module:       rx_engine
//  File:         rx_engine.sv
//  Description:  UART receive engine with oversampling.
//
//                 Key behaviors:
//                   - Detects start bit and samples data at OSR midpoints
//                   - Performs majority vote and assembles received byte
//                   - Validates stop bit and asserts FIFO write enable
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:   OSR
//
//  Notes:        
//==============================================================//
`timescale 1ns/1ps

module rx_engine #(
    parameter int OSR=16
) (
    // clk and reset
    input wire        clk_i,
    input wire        reset_i,

    // Baud
    input wire        osr_tick_i,

    // FIFO
    output reg  [7:0] rx_fifo_data_o,
    output reg        rx_fifo_wen_o,

    // Rx status and data
    input wire        recieve_bit_i,
    input wire        rx_en_i,

    output reg        rx_busy_o
);

    typedef enum logic [3:0] {
        MONITOR       = 4'b0001,
        START_VERIFY  = 4'b0010,
        RECIEVE       = 4'b0100,
        STOP          = 4'b1000
    } rx_state_t;

    // rx fsm signals
    rx_state_t            rx_state_r;
    reg                   recieve_en_r;
    reg [$clog2(OSR)-1:0] osr_cntr_r;
    reg [2:0]             recieve_cntr_r;

    // majority logic signals
    wire                  majority;
    reg                   sample_valid;
    reg                   sample_en_r;
    reg                   sample_0;
    reg                   sample_1;
    reg                   sample_2;

    // synchronization signals
    reg                   recieve_bit_s1r;
    reg                   recieve_bit_s2r;

    always_ff @(posedge clk_i) begin : recive_bit_sync
        if (reset_i) begin
            recieve_bit_s1r <= 1'b1;
            recieve_bit_s2r <= 1'b1;
        end else begin
            recieve_bit_s1r <= recieve_bit_i;
            recieve_bit_s2r <= recieve_bit_s1r;
        end
    end

    always_ff @(posedge clk_i) begin : rx_fsm
        if (reset_i) begin
            rx_state_r     <= MONITOR;
            recieve_en_r   <= 1'b0;
            recieve_cntr_r <= 0;

            rx_fifo_data_o <= 0;
            rx_fifo_wen_o  <= 1'b0;
            rx_busy_o      <= 1'b0;
        end else begin
            unique case (rx_state_r)
                MONITOR:
                begin
                    rx_fifo_wen_o <= 1'b0;

                    if (~recieve_bit_s2r && rx_en_i) begin
                        rx_state_r   <= START_VERIFY;
                        recieve_en_r <= 1'b1;
                        rx_busy_o    <= 1'b1;
                        sample_en_r  <= 1'b1;
                    end else begin
                        recieve_en_r <= 1'b0;
                        rx_busy_o    <= 1'b0;
                        sample_en_r  <= 1'b0;
                    end
                end

                START_VERIFY:
                begin
                    if (sample_valid) begin
                        if (~majority) rx_state_r <= RECIEVE;
                        else           rx_state_r <= MONITOR;
                    end
                end

                RECIEVE:
                begin
                    if (sample_valid) begin
                        if (recieve_cntr_r == 7) begin
                            rx_state_r     <= STOP;
                            recieve_cntr_r <= 0;
                        end else begin
                            recieve_cntr_r <= recieve_cntr_r + 1;
                        end

                        rx_fifo_data_o[recieve_cntr_r] <= majority;
                    end
                end

                STOP:
                begin
                    if (sample_valid) begin
                        rx_state_r   <= MONITOR;
                        recieve_en_r <= 1'b0;
                        rx_busy_o    <= 1'b0;
                        sample_en_r  <= 1'b0;

                        if (majority) rx_fifo_wen_o <= 1'b1;
                    end
                end
            endcase
        end
    end

    always_ff @(posedge clk_i) begin : sample_logic
        if (reset_i) begin
            sample_0     <= 1'b0;
            sample_1     <= 1'b0;
            sample_2     <= 1'b0;
            sample_valid <= 1'b0;
        end else if (osr_tick_i && sample_en_r) begin
            // OSR cntr is updated on cycle following osr_tick
            // So osr_cntr_r is effectively one higher than current value
            if (osr_cntr_r == (OSR/2 - 2)) begin
                sample_0 <= recieve_bit_s2r;
            end else if (osr_cntr_r == (OSR/2 - 1)) begin
                sample_1 <= recieve_bit_s2r;
            end else if (osr_cntr_r == (OSR/2)) begin
                sample_2     <= recieve_bit_s2r;
                sample_valid <= 1'b1;
            end
        end else begin
            sample_valid <= 1'b0;
        end
    end

    assign majority = (sample_0 && sample_1) ||
                      (sample_0 && sample_2) ||
                      (sample_1 && sample_2);

    baud_from_osr #(
        .OSR            (OSR)
    ) u_baud_from_osr (
        .clk_i          (clk_i),
        .reset_i        (reset_i),

        .enable_i       (recieve_en_r),
        .osr_tick_i     (osr_tick_i),

        .baud_tick_o    (),
        .osr_cntr_o     (osr_cntr_r)
    );

endmodule
