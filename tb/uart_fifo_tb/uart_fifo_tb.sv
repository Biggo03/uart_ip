`timescale 1ns/1ps
`include "common.sv"

module uart_fifo_tb;

    // ------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------
    localparam int WIDTH = 8;
    localparam int DEPTH = 16;
    localparam int ADDR_W = $clog2(DEPTH);

    // ------------------------------------------------------------
    // DUT Signals
    // ------------------------------------------------------------
    reg                  clk_i;
    reg                  reset_i;

    reg  [WIDTH-1:0]     wdata_i;
    reg                  wen_i;

    reg                  ren_i;
    wire [WIDTH-1:0]     rdata_o;

    logic                clr_ovrn_i;
    wire                 ovrn_o;

    wire [ADDR_W:0]      lvl_o;
    wire                 valid_o;

    wire                 almost_empty_o;
    wire                 empty_o;

    wire                 almost_full_o;
    wire                 full_o;

    // ------------------------------------------------------------
    // TB signals
    // ------------------------------------------------------------
    logic [ADDR_W:0]    running_lvl;
    logic [ADDR_W-1:0]  running_write_ptr;
    logic [ADDR_W-1:0]  running_read_ptr;
    logic [WIDTH-1:0]   expected_data [DEPTH-1:0];
    logic               expected_ovrn;

    // ------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------
    initial clk_i = 0;
    always #5 clk_i = ~clk_i;

    // ------------------------------------------------------------
    // DUT Instantiation
    // ------------------------------------------------------------
    uart_fifo #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk_i          (clk_i),
        .reset_i        (reset_i),

        .wdata_i        (wdata_i),
        .wen_i          (wen_i),

        .ren_i          (ren_i),
        .rdata_o        (rdata_o),

        .clr_ovrn_i     (clr_ovrn_i),
        .ovrn_o         (ovrn_o),

        .lvl_o          (lvl_o),
        .valid_o        (valid_o),

        .almost_empty_o (almost_empty_o),
        .empty_o        (empty_o),

        .almost_full_o  (almost_full_o),
        .full_o         (full_o)
    );

    // ------------------------------------------------------------
    // Test Stimulus Outline
    // ------------------------------------------------------------
    initial begin
        dump_setup();
        for (int i=0; i < DEPTH; i++) begin
            $dumpvars(0, dut.fifo_data_r[i]);
        end
        //Initialize tb signals
        running_lvl       = 0;
        running_write_ptr = 0;
        running_read_ptr  = 0;

        for (int i=0; i < DEPTH; i++) begin
            expected_data[i] = 0;
        end


        // Initialize inputs
        reset_i = 1'b1;
        wen_i   = 1'b0;
        ren_i   = 1'b0;
        wdata_i = '0;

        // Reset pulse
        repeat (3) @(posedge clk_i);
        reset_i = 1'b0;


        // Write all entries, plus one to check overflow
        for (int i=0; i < DEPTH+1; i++) begin
            write(i);
        end

        check_ovrn_clr();

        // Read all entries
        for (int i=0; i < DEPTH+1; i++) begin
            read();
        end
        // Should now be empty

        // write 4, shouldn't read anything
        read_and_write(1);

        // write 2, should read 1
        read_and_write(2);

        // Make sure is empty
        for (int i=0; i < DEPTH; i++) begin
            read();
        end

        // Make sure is full
        for (int i=0; i < DEPTH; i++) begin
            write(i);
        end

        // Should read 0, and not write anything
        read_and_write(18);

        check_ovrn_clr();

        // Last valid read should be 15 (from pevious fill)
        for (int i=0; i < DEPTH; i++) begin
            read();
        end

        for (int i=0; i < DEPTH; i++) begin
            write(i);
        end

        clr_ovrn_i = 1'b1;
        write(24);
        clr_ovrn_i = 1'b0;

        assert (ovrn_o == 1'b1) else $error("overrun cleared on write cycle");

        // Finish simulation
        #100;
        $finish;
    end

    `include "uart_fifo_tb_tasks.sv"

endmodule

