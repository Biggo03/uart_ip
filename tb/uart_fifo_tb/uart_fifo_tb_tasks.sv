task automatic setup_write(
    input logic [WIDTH-1:0] write_data
);
begin
    @(negedge clk_i);
    wen_i = 1'b1;
    wdata_i = write_data;

    if (running_lvl != DEPTH) begin
        expected_ovrn = 1'b0;

        expected_data[running_write_ptr] = write_data;

        if (running_write_ptr != DEPTH - 1) running_write_ptr = running_write_ptr + 1;
        else                                running_write_ptr = 0;

        running_lvl = running_lvl + 1;
    end else begin
        expected_ovrn = 1'b1;
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

    assert (ovrn_o == expected_ovrn) else tb_error("ovrn error");
end
endtask

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


task automatic read();
    logic [WIDTH-1:0] expected_read_data;
    logic             expected_valid;
begin
    setup_read(1'b0, expected_read_data, expected_valid);
    #1;
    if (expected_valid == 1) begin
        assert (expected_read_data == rdata_o) else tb_error("read error");
    end
    @(posedge clk_i);
    #1;
    ren_i = 0;

    assert (valid_o == (running_lvl != 0)) else tb_error("read incorrectly valid");
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
    #1;
    if (expected_valid == 1) begin
        assert (expected_read_data == rdata_o) else tb_error("read error");
    end
    @(posedge clk_i);
    #1;
    ren_i = 0;
    wen_i = 0;

    assert (valid_o == (running_lvl != 0)) else tb_error("read incorrectly valid");
    assert_flags();

    assert (ovrn_o == expected_ovrn) else tb_error("ovrn error");
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
        tb_error($sformatf("[%t] flag error detected. Expected %s", $realtime() * 1e3, error_string));
    end
end
endtask;

task automatic check_ovrn_clr();
begin
    clr_ovrn_i = 1'b1;
    @(posedge clk_i);
    #1;
    clr_ovrn_i = 1'b0;

    // check clear
    expected_ovrn = 1'b0;
    assert (expected_ovrn == ovrn_o) else tb_error($sformatf("[%0t] overrun error", $realtime()));
end
endtask;
