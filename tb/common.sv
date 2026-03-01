task automatic dump_setup;
begin
    $display("Dumping VCD to: %s", `WAVE_PATH);
    $dumpfile(`WAVE_PATH);
    $dumpvars;
end
endtask

integer tb_error_count = 0;

task automatic tb_error(
    input string msg
);
begin
    tb_error_count++;
    $error("%s", msg);
end
endtask

task automatic tb_report;
begin
    if (tb_error_count == 0) $display("TEST PASSED");
    else                    $display("TEST FAILED");
end
endtask
