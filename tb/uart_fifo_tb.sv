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

    wire [ADDR_W:0]      lvl_o;
    wire                 ovrn_o;
    wire                 valid_o;

    wire                 almost_empty_o;
    wire                 empty_o;

    wire                 almost_full_o;
    wire                 full_o;

    // ------------------------------------------------------------
    // TB signals
    // ------------------------------------------------------------
    logic [ADDR_W:0] running_lvl;
    logic [ADDR_W-1:0] running_write_ptr;
    logic [ADDR_W-1:0] running_read_ptr;
    logic [WIDTH-1:0]  expected_data [DEPTH-1:0];

    // ------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------
    initial clk_i = 0;
    always #5 clk_i = ~clk_i;   // 100 MHz equivalent

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

        .lvl_o          (lvl_o),
        .ovrn_o         (ovrn_o),
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

        // Last valid read should be 15 (from pevious fill)
        for (int i=0; i < DEPTH; i++) begin
            read();
        end

        // Finish simulation
        #100;
        $finish;
    end

task automatic setup_write(
    input logic [WIDTH-1:0] write_data
);
begin
    @(negedge clk_i);
    wen_i = 1'b1;
    wdata_i = write_data;

    if (running_lvl != DEPTH) begin
        expected_data[running_write_ptr] = write_data;

        if (running_write_ptr != DEPTH - 1) running_write_ptr = running_write_ptr + 1;
        else                                running_write_ptr = 0;

        running_lvl = running_lvl + 1;
    end
end
endtask;

task automatic setup_read(
    input logic              empty_write,
    output logic [WIDTH-1:0] expected_read_data,
    output logic             expected_valid
);
begin
    @(negedge clk_i);
    ren_i = 1'b1;

    if (running_lvl != 0 && ~empty_write) begin
        expected_read_data = expected_data[running_read_ptr];
        expected_valid = 1;

        if (running_read_ptr != DEPTH - 1) running_read_ptr = running_read_ptr + 1;
        else                               running_read_ptr = 0;

        running_lvl = running_lvl - 1;
    end else begin
        expected_read_data = 0;
        expected_valid = 0;
    end
end
endtask;

task automatic write(
    input logic [WIDTH-1:0] write_data
);
begin
    setup_write(write_data);
    @(posedge clk_i);
    #1;
    wen_i = 0;
    assert_flags();
end
endtask

task automatic read();
    logic [WIDTH-1:0] expected_read_data;
    logic             expected_valid;
begin
    setup_read(1'b0, expected_read_data, expected_valid);
    @(posedge clk_i);
    #1;
    ren_i = 0;

    if (expected_valid == 1) begin
        assert (expected_read_data == rdata_o && valid_o == 1'b1) else $error ("read error");
    end else begin
        assert (valid_o == 1'b0) else $error("read incorrectly valid");
    end
    assert_flags();
end
endtask

task automatic read_and_write(
    input logic [WIDTH-1:0] write_data
);
    logic [WIDTH-1:0] expected_read_data;
    logic             expected_valid;
    logic             empty_write;
begin
    if (running_lvl == 0) empty_write = 1;
    else                  empty_write = 0;

    fork
        begin
            setup_write(write_data);
        end

        begin
            setup_read(empty_write, expected_read_data, expected_valid);
        end
    join
    @(posedge clk_i);
    #1;
    ren_i = 0;
    wen_i = 0;

    if (expected_valid == 1) begin
        assert (expected_read_data == rdata_o && valid_o == 1'b1) else $error ("read error");
    end else begin
        assert (valid_o == 1'b0) else $error("read incorrectly valid");
    end
    assert_flags();
end
endtask;

task automatic assert_flags();
    string error_string;

    logic full_exp;
    logic empty_exp;
    logic almost_full_exp;
    logic almost_empty_exp;
begin
    if (running_lvl == DEPTH) begin
        full_exp         = 1'b1;
        empty_exp        = 1'b0;
        almost_full_exp  = 1'b0;
        almost_empty_exp = 1'b0;
        error_string = "FULL";
    end else if (running_lvl == DEPTH-1) begin
        full_exp         = 1'b0;
        empty_exp        = 1'b0;
        almost_full_exp  = 1'b1;
        almost_empty_exp = 1'b0;
        error_string = "ALMOST FULL";
    end else if (running_lvl == 0) begin
        full_exp         = 1'b0;
        empty_exp        = 1'b1;
        almost_full_exp  = 1'b0;
        almost_empty_exp = 1'b0;
        error_string = "EMPTY";
    end else if (running_lvl == 1) begin
        full_exp         = 1'b0;
        empty_exp        = 1'b0;
        almost_full_exp  = 1'b0;
        almost_empty_exp = 1'b1;
        error_string = "ALMOST EMPTY";
    end else begin
        full_exp         = 1'b0;
        empty_exp        = 1'b0;
        almost_full_exp  = 1'b0;
        almost_empty_exp = 1'b0;
        error_string = "NONE";
    end

    assert (full_exp == full_o &&
            empty_exp == empty_o &&
            almost_full_exp == almost_full_o &&
            almost_empty_exp == almost_empty_exp)
    else begin
        $error("[%t] flag error detected. Expected %s", $realtime() * 1e3, error_string);
    end
end
endtask;

endmodule

