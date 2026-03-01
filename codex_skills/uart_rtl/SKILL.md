---
name: uart-rtl
description: Make RTL changes in this UART IP repo. Use when modifying UART core modules, adding RTL blocks, or adjusting interfaces/behavior in `rtl/`.
---

# UART RTL Changes (Barebones)

Use this guidance when editing or adding RTL in `rtl/`.

**Scope**
- Hand-written RTL is in `rtl/`.
- Generated RTL is in `rtl/generated/`; do not edit by hand.
- Register macros are generated in `includes/`; do not edit by hand.

**Core RTL Files**
- Top: `rtl/uart_top.sv`
- TX: `rtl/tx_engine.sv`
- RX: `rtl/rx_engine.sv`
- FIFOs: `rtl/uart_fifo.sv`
- Baud: `rtl/baud_gen.sv`, `rtl/baud_from_osr.sv`

**Coding Style**
- SystemVerilog (`.sv`) with `wire` for combinational signals and `reg` for flops/state.
- Synchronous active-high reset named `reset_i`.
- Inputs `*_i`, outputs `*_o`, registered signals `*_r`, no `_w` suffix for wires.
- Use `always_ff` / `always_comb` and `typedef enum logic` + `unique case` for FSMs.
- Assign constants with width-safe literals: use `<= 'd0` for vectors/regs that should zero with their declared width, and `<= 1'b0` for single-bit signals.
- Keep derived constants as `localparam` inside the module body (not in the parameter list). Do not override `localparam` values in instantiations.

**Integration**
- If you add/rename RTL, update `filelists/*.f` (especially `filelists/uart_top.f`).
- If interfaces or hierarchy change, update `docs/` as needed.
- If a module’s ports change, update every RTL module that instantiates it to match the new port list.
- For status/reg structs, prefer wiring module outputs directly to struct fields at the port connection instead of adding glue logic.
- Wrapper modules like `uart_rx`/`uart_tx` should not import `uart_reg_pkg`; pass required control/status signals from `uart_top.sv` as plain ports.

**File Header Format**
- Add a header to the top of each hand-written RTL file.
- Header `Module` should match the RTL module name (e.g., `tx_engine`).
- Header `File` should match the filename (e.g., `tx_engine.sv`).
- Header `Project` should be `uart_ip`.
- Header `Repository` should be `https://github.com/Biggo03/uart_ip`.
- Header `Description` should be custom per RTL file and include a short list of key behaviors.
- Include `Parameters` when the module defines parameters/localparams; otherwise set it to `None`.
- Include a `Notes` section only when there is uncommon or non-standard behavior worth calling out; otherwise leave it blank.
- Use this exact format and separators:

```text
//==============================================================//
//  Module:       <module_name>
//  File:         <filename>.sv
//  Description:  <short description>.
//
//                 Key behaviors:
//                   - <behavior 1>
//                   - <behavior 2>
//                   - <behavior 3>
//
//  Author:       Viggo Wozniak
//  Project:      uart_ip
//  Repository:   https://github.com/Biggo03/uart_ip
//
//  Parameters:   <comma-separated parameter names or None>
//
//  Notes:        <only if needed>
//==============================================================//
```

**Tests**
- Tests run on Icarus Verilog via `scripts/run_test.sh`.
- Update or add testbenches in `tb/` when behavior changes.
