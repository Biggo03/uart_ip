task automatic dump_setup;
begin
    $display("Dumping VCD to: %s", `WAVE_PATH);
    $dumpfile(`WAVE_PATH);
    $dumpvars;
end
endtask
