//==============================================================//
//  Module:       intlpbk_fsm
//  File:         intlpbk_fsm.sv
//  Description:  Internal UART loopback sequencer with two FSMs.
//
//                 Key behaviors:
//                   - Main FSM handles command decode and test flow
//                   - APB FSM performs APB setup/access handshakes
//                   - Stores/compares RX data and tracks pass/fail counts
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:   None
//
//  Notes:        LOOPBACK executes TRANSMIT then RECEIVE.
//==============================================================//
`timescale 1ns/1ps
`include "uart_reg_macros.sv"

module intlpbk_fsm (
    // -- clk and reset --
    input wire        clk_i,
    input wire        reset_i,

    // -- Control --
    input wire        enable_i,
    input wire [15:0] read_cmd_i,
    input wire [15:0] write_cmd_i,

    // -- Status --
    output reg        busy_o,
    output reg [15:0] pass_count_o,
    output reg [15:0] fail_count_o,
    output reg [3:0]  tx_ptr_o,
    output reg [3:0]  rx_ptr_o,
    output reg [15:0] read_cmd_active_o,
    output reg [15:0] write_cmd_active_o,

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

    typedef enum logic [1:0] {
        M_IDLE     = 2'd0,
        M_CONFIG   = 2'd1,
        M_RECEIVE  = 2'd2,
        M_TRANSMIT = 2'd3
    } main_state_t;

    typedef enum logic [1:0] {
        A_IDLE   = 2'd0,
        A_SETUP  = 2'd1,
        A_ACCESS = 2'd2
    } apb_state_t;

    main_state_t main_state_r;
    apb_state_t  apb_state_r;

    reg enable_r;
    reg cfg_done_r;

    reg [15:0] read_cmd_r;
    reg [15:0] write_cmd_r;

    reg [7:0] tx_data_mem_r [0:15];
    reg [7:0] rx_data_mem_r [0:15];

    // Main FSM interaction signals
    reg loopback_pending_r;
    reg recv_waiting_for_data_r;
    reg req_inflight_r;

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

    integer i;

    // ------------------------------------------------------------
    // APB FSM
    // ------------------------------------------------------------
    always_ff @(posedge clk_i) begin : apb_fsm
        if (reset_i) begin
            apb_state_r      <= A_IDLE;
            apb_done_pulse_r <= 1'b0;
            apb_err_pulse_r  <= 1'b0;
            apb_rdata_r      <= 32'h0;
            apb_done_pending_r <= 1'b0;
            apb_err_pending_r  <= 1'b0;

            psel_o           <= 1'b0;
            penable_o        <= 1'b0;
            pwrite_o         <= 1'b0;
            paddr_o          <= 5'h0;
            pwdata_o         <= 32'h0;
        end else begin
            // One-cycle response pulses generated from pending flags.
            apb_done_pulse_r <= apb_done_pending_r;
            apb_err_pulse_r  <= apb_err_pending_r;
            apb_done_pending_r <= 1'b0;
            apb_err_pending_r  <= 1'b0;

            unique case (apb_state_r)
                A_IDLE:
                begin
                    psel_o    <= 1'b0;
                    penable_o <= 1'b0;
                    pwrite_o  <= 1'b0;
                    paddr_o   <= 5'h0;
                    pwdata_o  <= 32'h0;

                    if (apb_start_r) begin
                        pwrite_o    <= apb_req_write_r;
                        paddr_o     <= apb_req_addr_r;
                        pwdata_o    <= apb_req_wdata_r;
                        apb_state_r <= A_SETUP;
                    end
                end

                A_SETUP:
                begin
                    psel_o    <= 1'b1;
                    penable_o <= 1'b1;
                    apb_state_r <= A_ACCESS;
                end

                A_ACCESS:
                begin
                    psel_o    <= 1'b1;

                    if (pready_i) begin
                        apb_rdata_r      <= prdata_i;
                        apb_done_pending_r <= 1'b1;
                        apb_err_pending_r  <= pslverr_i;

                        psel_o           <= 1'b0;
                        penable_o        <= 1'b0;
                        pwrite_o         <= 1'b0;
                        paddr_o          <= 5'h0;
                        pwdata_o         <= 32'h0;

                        apb_state_r      <= A_IDLE;
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
            main_state_r           <= M_IDLE;
            enable_r               <= 1'b0;
            cfg_done_r             <= 1'b0;

            read_cmd_r             <= 16'h0;
            write_cmd_r            <= 16'h0;

            loopback_pending_r     <= 1'b0;
            recv_waiting_for_data_r<= 1'b0;
            req_inflight_r         <= 1'b0;

            apb_start_r            <= 1'b0;
            apb_req_write_r        <= 1'b0;
            apb_req_addr_r         <= 5'h0;
            apb_req_wdata_r        <= 32'h0;

            busy_o                 <= 1'b0;
            pass_count_o           <= 16'h0;
            fail_count_o           <= 16'h0;
            tx_ptr_o               <= 4'h0;
            rx_ptr_o               <= 4'h0;
            read_cmd_active_o      <= 16'h0;
            write_cmd_active_o     <= 16'h0;

            tx_data_mem_r[0]       <= 8'h24;
            tx_data_mem_r[1]       <= 8'h81;
            tx_data_mem_r[2]       <= 8'h09;
            tx_data_mem_r[3]       <= 8'h63;
            tx_data_mem_r[4]       <= 8'h77;
            tx_data_mem_r[5]       <= 8'hAA;
            tx_data_mem_r[6]       <= 8'h55;
            tx_data_mem_r[7]       <= 8'hC3;
            tx_data_mem_r[8]       <= 8'h3C;
            tx_data_mem_r[9]       <= 8'h5A;
            tx_data_mem_r[10]      <= 8'hE1;
            tx_data_mem_r[11]      <= 8'h00;
            tx_data_mem_r[12]      <= 8'h00;
            tx_data_mem_r[13]      <= 8'h00;
            tx_data_mem_r[14]      <= 8'h00;
            tx_data_mem_r[15]      <= 8'h00;

            for (i = 0; i < 16; i = i + 1) begin
                rx_data_mem_r[i] <= 8'h00;
            end
        end else begin
            enable_r <= enable_i;

            // Default: only pulse when launching APB request.
            apb_start_r <= 1'b0;

            read_cmd_active_o  <= read_cmd_r;
            write_cmd_active_o <= write_cmd_r;

            unique case (main_state_r)
                M_IDLE:
                begin
                    req_inflight_r          <= 1'b0;
                    recv_waiting_for_data_r <= 1'b0;
                    loopback_pending_r      <= 1'b0;

                    if (enable_i && !enable_r) begin
                        read_cmd_r             <= read_cmd_i;
                        write_cmd_r            <= write_cmd_i;
                        read_cmd_active_o      <= read_cmd_i;
                        write_cmd_active_o     <= write_cmd_i;
                        busy_o                 <= 1'b1;
                        cfg_done_r             <= 1'b0;
                        main_state_r           <= M_CONFIG;
                    end else if (busy_o && cfg_done_r) begin
                        if ((read_cmd_r == 16'h0) && (write_cmd_r == 16'h0)) begin
                            busy_o <= 1'b0;
                        end else if (read_cmd_r[0] && !write_cmd_r[0]) begin
                            main_state_r <= M_RECEIVE;
                        end else if (!read_cmd_r[0] && write_cmd_r[0]) begin
                            main_state_r <= M_TRANSMIT;
                        end else if (read_cmd_r[0] && write_cmd_r[0]) begin
                            loopback_pending_r <= 1'b1;
                            main_state_r       <= M_TRANSMIT;
                        end else begin
                            // No-op slot: shift command vectors.
                            read_cmd_r  <= {1'b0, read_cmd_r[15:1]};
                            write_cmd_r <= {1'b0, write_cmd_r[15:1]};
                        end
                    end
                end

                M_CONFIG:
                begin
                    if (!req_inflight_r) begin
                        apb_req_write_r <= 1'b1;
                        apb_req_addr_r  <= `UART_UART_CFG_ADDR;
                        apb_req_wdata_r <= 32'h0000_0005;
                        apb_start_r     <= 1'b1;
                        req_inflight_r  <= 1'b1;
                    end else if (apb_done_pulse_r) begin
                        req_inflight_r <= 1'b0;

                        if (apb_err_pulse_r) begin
                            fail_count_o <= fail_count_o + 1'b1;
                            busy_o       <= 1'b0;
                            main_state_r <= M_IDLE;
                        end else begin
                            cfg_done_r   <= 1'b1;
                            main_state_r <= M_IDLE;
                        end
                    end
                end

                M_TRANSMIT:
                begin
                    if (!req_inflight_r) begin
                        apb_req_write_r <= 1'b1;
                        apb_req_addr_r  <= `UART_TX_DATA_ADDR;
                        apb_req_wdata_r <= {24'h0, tx_data_mem_r[tx_ptr_o]};
                        apb_start_r     <= 1'b1;
                        req_inflight_r  <= 1'b1;
                    end else if (apb_done_pulse_r) begin
                        req_inflight_r <= 1'b0;

                        if (apb_err_pulse_r) begin
                            fail_count_o <= fail_count_o + 1'b1;
                            // Consume one command slot even on failure.
                            read_cmd_r   <= {1'b0, read_cmd_r[15:1]};
                            write_cmd_r  <= {1'b0, write_cmd_r[15:1]};
                            main_state_r <= M_IDLE;
                        end else begin
                            tx_ptr_o <= tx_ptr_o + 1'b1;

                            if (loopback_pending_r) begin
                                main_state_r <= M_RECEIVE;
                            end else begin
                                read_cmd_r   <= {1'b0, read_cmd_r[15:1]};
                                write_cmd_r  <= {1'b0, write_cmd_r[15:1]};
                                main_state_r <= M_IDLE;
                            end
                        end
                    end
                end

                M_RECEIVE:
                begin
                    if (!req_inflight_r) begin
                        if (!recv_waiting_for_data_r) begin
                            // Poll UART_STATUS until RX_VALID is high.
                            apb_req_write_r <= 1'b0;
                            apb_req_addr_r  <= `UART_UART_STATUS_ADDR;
                            apb_req_wdata_r <= 32'h0;
                        end else begin
                            // Read RX data once valid.
                            apb_req_write_r <= 1'b0;
                            apb_req_addr_r  <= `UART_RX_DATA_ADDR;
                            apb_req_wdata_r <= 32'h0;
                        end

                        apb_start_r    <= 1'b1;
                        req_inflight_r <= 1'b1;
                    end else if (apb_done_pulse_r) begin
                        req_inflight_r <= 1'b0;

                        if (apb_err_pulse_r) begin
                            fail_count_o           <= fail_count_o + 1'b1;
                            recv_waiting_for_data_r<= 1'b0;
                            loopback_pending_r     <= 1'b0;
                            read_cmd_r             <= {1'b0, read_cmd_r[15:1]};
                            write_cmd_r            <= {1'b0, write_cmd_r[15:1]};
                            main_state_r           <= M_IDLE;
                        end else if (!recv_waiting_for_data_r) begin
                            if (apb_rdata_r[0]) begin
                                recv_waiting_for_data_r <= 1'b1;
                            end
                        end else begin
                            rx_data_mem_r[rx_ptr_o] <= apb_rdata_r[7:0];

                            if (apb_rdata_r[7:0] == tx_data_mem_r[rx_ptr_o]) begin
                                pass_count_o <= pass_count_o + 1'b1;
                            end else begin
                                fail_count_o <= fail_count_o + 1'b1;
                            end

                            rx_ptr_o <= rx_ptr_o + 1'b1;

                            // One command slot completed.
                            read_cmd_r  <= {1'b0, read_cmd_r[15:1]};
                            write_cmd_r <= {1'b0, write_cmd_r[15:1]};

                            recv_waiting_for_data_r <= 1'b0;
                            loopback_pending_r      <= 1'b0;
                            main_state_r            <= M_IDLE;
                        end
                    end
                end

                default: main_state_r <= M_IDLE;
            endcase
        end
    end

endmodule
