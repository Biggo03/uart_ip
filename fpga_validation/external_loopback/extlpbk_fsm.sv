//==============================================================//
//  Module:       extlpbk_fsm
//  File:         extlpbk_fsm.sv
//  Description:  External UART loopback sequencer with APB master.
//
//                 Key behaviors:
//                   - Configures UART baud + TX/RX enable over APB
//                   - Polls RX_VALID and reads bytes from RX_DATA
//                   - Echoes received bytes back through TX_DATA
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:
//    BAUDDIV_CFG   - UART BAUDDIV register value
//    TX_FIFO_DEPTH - TX FIFO depth used for room checks
//
//  Notes:
//    - Expected clk_i for default settings: 125 MHz.
//    - Default BAUDDIV_CFG=68 targets ~115200 baud (8N1 framing handled by UART core).
//    - If clk_i differs, BAUDDIV_CFG should be adjusted to maintain target baud.
//    - Assumes UART_STATUS[0] is RX_VALID.
//    - Assumes UART_STATUS[13:9] is TX_LVL.
//==============================================================//
`timescale 1ns/1ps
`include "uart_reg_macros.sv"

module extlpbk_fsm #(
    parameter int BAUDDIV_CFG = 16'd68,
    parameter int TX_FIFO_DEPTH = 16
) (
    // -- clk and reset --
    input wire        clk_i,
    input wire        reset_i,

    // -- Control --
    input wire        enable_i,

    // -- Status --
    output reg        busy_o,
    output reg [15:0] echo_count_o,
    output reg [15:0] error_count_o,
    output reg [7:0]  last_rx_byte_o,
    output reg [7:0]  last_tx_byte_o,

    // -- APB master interface --
    output reg        psel_o,
    output reg        penable_o,
    output reg        pwrite_o,
    output reg [4:0]  paddr_o,
    output reg [31:0] pwdata_o,
    input wire [31:0] prdata_i,
    input wire        pready_i,
    input wire        pslverr_i
);

    typedef enum logic [2:0] {
        M_IDLE         = 3'd0,
        M_CFG_BAUD     = 3'd1,
        M_CFG_UART     = 3'd2,
        M_POLL_STATUS  = 3'd3,
        M_READ_RX      = 3'd4,
        M_WAIT_TX_ROOM = 3'd5,
        M_WRITE_TX     = 3'd6
    } main_state_t;

    typedef enum logic [1:0] {
        A_IDLE   = 2'd0,
        A_SETUP  = 2'd1,
        A_ACCESS = 2'd2
    } apb_state_t;

    main_state_t main_state_r;
    apb_state_t  apb_state_r;

    reg enable_r;
    reg req_inflight_r;

    reg [7:0] rx_byte_r;

    // Main -> APB request bus (latched by APB FSM)
    reg        apb_start_r;
    reg        apb_req_write_r;
    reg [4:0]  apb_req_addr_r;
    reg [31:0] apb_req_wdata_r;

    // APB -> Main response bus
    reg        apb_done_pulse_r;
    reg        apb_err_pulse_r;
    reg [31:0] apb_rdata_r;
    reg        apb_done_pending_r;
    reg        apb_err_pending_r;

    // ------------------------------------------------------------
    // APB FSM
    // ------------------------------------------------------------
    always_ff @(posedge clk_i) begin : apb_fsm
        if (reset_i) begin
            apb_state_r         <= A_IDLE;
            apb_done_pulse_r    <= 1'b0;
            apb_err_pulse_r     <= 1'b0;
            apb_rdata_r         <= 32'h0;
            apb_done_pending_r  <= 1'b0;
            apb_err_pending_r   <= 1'b0;

            psel_o              <= 1'b0;
            penable_o           <= 1'b0;
            pwrite_o            <= 1'b0;
            paddr_o             <= 5'h0;
            pwdata_o            <= 32'h0;
        end else begin
            // One-cycle response pulses generated from pending flags.
            apb_done_pulse_r    <= apb_done_pending_r;
            apb_err_pulse_r     <= apb_err_pending_r;
            apb_done_pending_r  <= 1'b0;
            apb_err_pending_r   <= 1'b0;

            unique case (apb_state_r)
                A_IDLE:
                begin
                    psel_o       <= 1'b0;
                    penable_o    <= 1'b0;
                    pwrite_o     <= 1'b0;
                    paddr_o      <= 5'h0;
                    pwdata_o     <= 32'h0;

                    if (apb_start_r) begin
                        pwrite_o     <= apb_req_write_r;
                        paddr_o      <= apb_req_addr_r;
                        pwdata_o     <= apb_req_wdata_r;
                        apb_state_r  <= A_SETUP;
                    end
                end

                A_SETUP:
                begin
                    psel_o       <= 1'b1;
                    penable_o    <= 1'b1;
                    apb_state_r  <= A_ACCESS;
                end

                A_ACCESS:
                begin
                    psel_o       <= 1'b1;

                    if (pready_i) begin
                        apb_rdata_r        <= prdata_i;
                        apb_done_pending_r <= 1'b1;
                        apb_err_pending_r  <= pslverr_i;

                        psel_o             <= 1'b0;
                        penable_o          <= 1'b0;
                        pwrite_o           <= 1'b0;
                        paddr_o            <= 5'h0;
                        pwdata_o           <= 32'h0;

                        apb_state_r        <= A_IDLE;
                    end
                end

                default: apb_state_r <= A_IDLE;
            endcase
        end
    end

    // ------------------------------------------------------------
    // Main FSM
    // ------------------------------------------------------------
    always_ff @(posedge clk_i) begin : main_fsm
        if (reset_i) begin
            main_state_r        <= M_IDLE;
            enable_r            <= 1'b0;
            req_inflight_r      <= 1'b0;
            rx_byte_r           <= 8'h00;

            apb_start_r         <= 1'b0;
            apb_req_write_r     <= 1'b0;
            apb_req_addr_r      <= 5'h0;
            apb_req_wdata_r     <= 32'h0;

            busy_o              <= 1'b0;
            echo_count_o        <= 16'h0;
            error_count_o       <= 16'h0;
            last_rx_byte_o      <= 8'h00;
            last_tx_byte_o      <= 8'h00;
        end else begin
            enable_r <= enable_i;

            // Default: only pulse when launching APB request.
            apb_start_r <= 1'b0;

            if (!enable_i) begin
                main_state_r   <= M_IDLE;
                req_inflight_r <= 1'b0;
                busy_o         <= 1'b0;
            end else begin
                unique case (main_state_r)
                    M_IDLE:
                    begin
                        busy_o         <= 1'b0;
                        req_inflight_r <= 1'b0;

                        if (enable_i && !enable_r) begin
                            echo_count_o   <= 16'h0;
                            error_count_o  <= 16'h0;
                            last_rx_byte_o <= 8'h00;
                            last_tx_byte_o <= 8'h00;
                            busy_o         <= 1'b1;
                            main_state_r   <= M_CFG_BAUD;
                        end
                    end

                    M_CFG_BAUD:
                    begin
                        busy_o <= 1'b1;

                        if (!req_inflight_r) begin
                            apb_req_write_r <= 1'b1;
                            apb_req_addr_r  <= `UART_BAUD_CFG_ADDR;
                            apb_req_wdata_r <= {16'h0, BAUDDIV_CFG[15:0]};
                            apb_start_r     <= 1'b1;
                            req_inflight_r  <= 1'b1;
                        end else if (apb_done_pulse_r) begin
                            req_inflight_r <= 1'b0;

                            if (apb_err_pulse_r) begin
                                error_count_o <= error_count_o + 1'b1;
                                busy_o        <= 1'b0;
                                main_state_r  <= M_IDLE;
                            end else begin
                                main_state_r <= M_CFG_UART;
                            end
                        end
                    end

                    M_CFG_UART:
                    begin
                        busy_o <= 1'b1;

                        if (!req_inflight_r) begin
                            // TX_EN=1 and RX_EN=1.
                            apb_req_write_r <= 1'b1;
                            apb_req_addr_r  <= `UART_UART_CFG_ADDR;
                            apb_req_wdata_r <= 32'h0000_0005;
                            apb_start_r     <= 1'b1;
                            req_inflight_r  <= 1'b1;
                        end else if (apb_done_pulse_r) begin
                            req_inflight_r <= 1'b0;

                            if (apb_err_pulse_r) begin
                                error_count_o <= error_count_o + 1'b1;
                                busy_o        <= 1'b0;
                                main_state_r  <= M_IDLE;
                            end else begin
                                main_state_r <= M_POLL_STATUS;
                            end
                        end
                    end

                    M_POLL_STATUS:
                    begin
                        busy_o <= 1'b1;

                        if (!req_inflight_r) begin
                            apb_req_write_r <= 1'b0;
                            apb_req_addr_r  <= `UART_UART_STATUS_ADDR;
                            apb_req_wdata_r <= 32'h0;
                            apb_start_r     <= 1'b1;
                            req_inflight_r  <= 1'b1;
                        end else if (apb_done_pulse_r) begin
                            req_inflight_r <= 1'b0;

                            if (apb_err_pulse_r) begin
                                error_count_o <= error_count_o + 1'b1;
                                busy_o        <= 1'b0;
                                main_state_r  <= M_IDLE;
                            end else if (apb_rdata_r[0]) begin
                                main_state_r <= M_READ_RX;
                            end
                        end
                    end

                    M_READ_RX:
                    begin
                        busy_o <= 1'b1;

                        if (!req_inflight_r) begin
                            apb_req_write_r <= 1'b0;
                            apb_req_addr_r  <= `UART_RX_DATA_ADDR;
                            apb_req_wdata_r <= 32'h0;
                            apb_start_r     <= 1'b1;
                            req_inflight_r  <= 1'b1;
                        end else if (apb_done_pulse_r) begin
                            req_inflight_r <= 1'b0;

                            if (apb_err_pulse_r) begin
                                error_count_o <= error_count_o + 1'b1;
                                busy_o        <= 1'b0;
                                main_state_r  <= M_IDLE;
                            end else begin
                                rx_byte_r      <= apb_rdata_r[7:0];
                                last_rx_byte_o <= apb_rdata_r[7:0];
                                main_state_r   <= M_WAIT_TX_ROOM;
                            end
                        end
                    end

                    M_WAIT_TX_ROOM:
                    begin
                        busy_o <= 1'b1;

                        if (!req_inflight_r) begin
                            apb_req_write_r <= 1'b0;
                            apb_req_addr_r  <= `UART_UART_STATUS_ADDR;
                            apb_req_wdata_r <= 32'h0;
                            apb_start_r     <= 1'b1;
                            req_inflight_r  <= 1'b1;
                        end else if (apb_done_pulse_r) begin
                            req_inflight_r <= 1'b0;

                            if (apb_err_pulse_r) begin
                                error_count_o <= error_count_o + 1'b1;
                                busy_o        <= 1'b0;
                                main_state_r  <= M_IDLE;
                            end else if (apb_rdata_r[13:9] < TX_FIFO_DEPTH[4:0]) begin
                                main_state_r <= M_WRITE_TX;
                            end
                        end
                    end

                    M_WRITE_TX:
                    begin
                        busy_o <= 1'b1;

                        if (!req_inflight_r) begin
                            apb_req_write_r <= 1'b1;
                            apb_req_addr_r  <= `UART_TX_DATA_ADDR;
                            apb_req_wdata_r <= {24'h0, rx_byte_r};
                            apb_start_r     <= 1'b1;
                            req_inflight_r  <= 1'b1;
                        end else if (apb_done_pulse_r) begin
                            req_inflight_r <= 1'b0;

                            if (apb_err_pulse_r) begin
                                error_count_o <= error_count_o + 1'b1;
                                busy_o        <= 1'b0;
                                main_state_r  <= M_IDLE;
                            end else begin
                                echo_count_o   <= echo_count_o + 1'b1;
                                last_tx_byte_o <= rx_byte_r;
                                main_state_r   <= M_POLL_STATUS;
                            end
                        end
                    end

                    default: main_state_r <= M_IDLE;
                endcase
            end
        end
    end

endmodule
