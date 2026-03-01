//==============================================================//
//  Module:       tx_engine
//  File:         tx_engine.sv
//  Description:  UART transmit engine (8N1).
//
//                 Key behaviors:
//                   - Pulls bytes from TX FIFO and serializes data
//                   - Generates start, data, and stop bits on baud ticks
//                   - Reports busy status and FIFO read handshake
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

module tx_engine #(
    parameter int OSR = 16 // Needs to be known for internal counter
) (
    // -- clk and reset --
    input wire       clk_i,
    input wire       reset_i,

    // -- Baud --
    input wire       osr_tick_i,

    // -- FIFO --
    input wire       tx_fifo_valid_i,
    input wire [7:0] tx_fifo_data_i,

    output reg       tx_fifo_ren_o,

    // -- Tx status and data --
    input wire       tx_en_i,

    output reg       tx_busy_o,
    output reg       transmit_bit_o
);

    typedef enum logic [3:0] {
        IDLE    = 4'b0001,
        FETCH   = 4'b0010,
        SEND    = 4'b0100,
        STOP    = 4'b1000
    } tx_state_t;

    // tx fsm signals
    tx_state_t tx_state_r;
    reg [7:0] transmit_byte_r;
    reg       transmit_en_r;
    reg       start_bit_sent_r;
    reg       stop_bit_sent_r;
    reg [3:0] transmit_cntr_r;

    // baud counter signals
    reg       baud_tick_r;

    always_ff @(posedge clk_i) begin : tx_fsm
        if (reset_i) begin
            tx_state_r       <= IDLE;
            transmit_byte_r  <= 0;
            transmit_en_r    <= 1'b0;
            start_bit_sent_r <= 1'b0;
            stop_bit_sent_r  <= 1'b0;
            transmit_cntr_r  <= 0;

            tx_fifo_ren_o    <= 1'b0;
            tx_busy_o        <= 1'b0;
            transmit_bit_o   <= 1'b1;
        end else begin
            unique case (tx_state_r)
                IDLE:
                begin
                    if (tx_en_i && tx_fifo_valid_i) begin
                        tx_state_r    <= FETCH;
                        tx_busy_o     <= 1'b1;
                        tx_fifo_ren_o <= 1'b1;
                    end
                end

                FETCH:
                begin
                    tx_fifo_ren_o <= 1'b0;
                    transmit_byte_r <= tx_fifo_data_i;
                    tx_state_r      <= SEND;
                    transmit_en_r   <= 1'b1;
                end

                SEND:
                begin
                    if (baud_tick_r) begin
                        if (~start_bit_sent_r) begin
                            transmit_bit_o   <= 1'b0;
                            start_bit_sent_r <= 1'b1;
                        end else begin
                            if (transmit_cntr_r == 7) begin
                                tx_state_r       <= STOP;
                                transmit_bit_o   <= transmit_byte_r[0];
                            end else begin
                                transmit_bit_o  <= transmit_byte_r[0];
                                transmit_cntr_r <= transmit_cntr_r + 1;
                            end

                            // Last shift will set transmit_byte_r to 0
                            transmit_byte_r <= transmit_byte_r >> 1;
                        end
                    end
                end

                STOP:
                begin
                    if (baud_tick_r) begin
                        if (stop_bit_sent_r) begin
                            tx_state_r       <= IDLE;
                            transmit_cntr_r  <= 0;
                            transmit_en_r    <= 1'b0;
                            stop_bit_sent_r  <= 1'b0;
                            start_bit_sent_r <= 1'b0;

                            tx_busy_o        <= 1'b0;
                        end else begin
                            stop_bit_sent_r <= 1'b1;

                            transmit_bit_o  <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end

    baud_from_osr #(
        .OSR            (OSR)
    ) u_baud_from_osr (
        .clk_i          (clk_i),
        .reset_i        (reset_i),

        .enable_i       (transmit_en_r),
        .osr_tick_i     (osr_tick_i),

        .baud_tick_o    (baud_tick_r)
    );

endmodule
