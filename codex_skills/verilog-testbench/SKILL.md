---
name: verilog-testbench
description: Create or update SystemVerilog testbenches in this repo, using the local TB patterns and Icarus Verilog flow. Use when asked to add a new TB, extend an existing TB, or adjust TB style/structure.
---

# Testbench Creation (Barebones)

Use this guidance when creating or updating SystemVerilog testbenches for this repo.

**Scope and Simulator**
- Simulator: Icarus Verilog only.
- Prefer straightforward directed tests; avoid complex class-based or constrained-random frameworks.
- Run via `scripts/run_test.sh`.
- Run tests from the repo root using:
  `PROJ_ROOT=$(pwd) scripts/run_test.sh <filelist> <tb_file> ./outputs`
- Always dump test outputs to `./outputs` (do not use other output directories).
- Do not edit `tb/generated/` files; apply this guidance only to hand-written TBs (typically `tb/*_tb/`).

**Reference Testbenches**
- Use the existing TBs for structure and style.
- Reference: `tb/uart_top_tb/uart_top_tb.sv`.
- Reference: `tb/tx_engine_tb/tx_engine_tb.sv`.
- Reference: `tb/rx_engine_tb/rx_engine_tb.sv`.
- Reference: `tb/uart_fifo_tb/uart_fifo_tb.sv`.
- Reference: `tb/baud_gen_tb/baud_gen_tb.sv`.
- Reference: `tb/uart_fifo_tb/uart_fifo_tb_tasks.sv`.

**Structure and Organization**
- Organize the TB with clear section headers in this order: Parameters → TB/DUT signals → DUT instantiation → Clock/reset gen → Stimulus (initial) → Tasks.
- Localparams should group protocol or timing constants (e.g., `OSR`, `DIV_W`, `CLK_PERIOD_NS`, `BAUD_DIV`) near the top.
- Group signals by function with short comment banners (clock/reset, FIFO, control, outputs, etc.).

**Clock, Reset, and Dumping**
- Include `common.sv` first, then any TB-specific includes (e.g., `uart_reg_macros.sv`).
- Call `dump_setup()` once at the start of the main `initial` block; add extra `$dumpvars` only when needed.
- Provide clock generation with `initial clk = 0; always #5 clk = ~clk;` as a default, or use a localparam period when required by the DUT.
- Apply a short reset pulse (at least 2 cycles) at the start of sim and set all inputs to known defaults.

**Stimulus and Checks**
- Use simple `task automatic` blocks for stimulus and reuse (reg read/write, wait helpers, etc.).
- Use `assert` with `tb_error()` for checks; keep checks close to stimulus. Plain `if (...) tb_error(...)` is acceptable for simple cases.
- Top-level TBs that access MMIO should include `uart_reg_macros.sv` and implement `reg_write`/`reg_read` tasks.
- All tests must end with a terminal message: print `TEST PASSED` on success and `TEST FAILED` on any error.
- Use `tb_error()` to record failures and call `tb_report()` right before `$finish`.

**Naming and File Layout**
- Keep file naming consistent: `tb/<block>_tb/<block>_tb.sv` and optional `tb/<block>_tb/<block>_tb_tasks.sv`.

**File Header Format**
- Add a header to the top of each hand-written testbench file.
- Header `Module` should match the TB module name (e.g., `tx_engine_tb`).
- Header `File` should match the filename (e.g., `tx_engine_tb.sv`).
- Header `Project` should be `uart_ip`.
- Header `Repository` should be `https://github.com/Biggo03/uart_ip`.
- Header `Description` should be custom per TB and include a short list of checks.
- Include `Parameters` when the TB defines localparams; otherwise set it to `None`.
- Use this exact format and separators:

```text
//==============================================================//
//  Module:       <tb_module_name>
//  File:         <tb_filename>.sv
//  Description:  Testbench for <dut_name>.
//
//                 This testbench verifies:
//                   - <check 1>
//                   - <check 2>
//                   - <check 3>
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:   <comma-separated parameter names or None>
//
//  Notes:        - Uses common.sv dump_setup for VCD generation.
//==============================================================//
```
