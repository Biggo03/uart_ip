# UART IP Repository Agent Guide

This file is the local guidance for assistants working in this repo. Keep it current when structure or RTL changes.

**Directory Structure**
- `rtl/` RTL sources (SystemVerilog). Core hand-written blocks live here.
- `rtl/generated/` Auto-generated register package and regfile. Do not edit by hand.
- `includes/` Generated C/RTL register macros (`uart_reg_macros.h`). Do not edit by hand.
- `filelists/` Compilation filelists for top-level and sub-blocks.
- `tb/` Testbenches (per-block and top). `tb/generated/` contains generated TBs.
- `scripts/` Helper scripts for tests and register generation.
- `docs/` Design docs, scope, and block diagrams.
- `tools/Peripheral-Register-File-Generator/` External regfile generator and templates.
- `codex_skills/` Local skills for Codex.

**Skills**
- `codex_skills/verilog-testbench/SKILL.md`
- `codex_skills/uart_rtl/SKILL.md`

**RTL Hierarchy (V1)**
Top-level: `rtl/uart_top.sv`

Instantiated blocks and connections:
- `uart_regfile` (`rtl/generated/uart_regfile.sv`)
  - Register group types are defined in `rtl/generated/uart_reg_package.sv`.
  - Address macros in `includes/uart_reg_macros.h` (generated).
- `baud_gen` (`rtl/baud_gen.sv`)
  - Generates `osr_tick` from `BAUDDIV` and enable (`TX_EN || RX_EN`).
- RX path
  - `rx_engine` (`rtl/rx_engine.sv`)
    - Consumes `osr_tick` and `rx_data_i`.
    - Generates `rx_fifo_wdata` and `rx_fifo_wen` and sets `status_grp.RX_BUSY`.
    - Internally instantiates `baud_from_osr` (`rtl/baud_from_osr.sv`).
  - `uart_fifo` (`rtl/uart_fifo.sv`) as RX FIFO
    - Connected between `rx_engine` and register/status path.
    - Drives `status_grp.RX_DATA`, `RX_LVL`, `RX_OVRN`, `RX_VALID`
- TX path
  - `uart_fifo` as TX FIFO
    - Connected between register/config path and `tx_engine`.
    - Drives `status_grp.TX_LVL`, `TX_OVRN`
  - `tx_engine` (`rtl/tx_engine.sv`)
    - Consumes `osr_tick`, `tx_fifo_*` signals, `TX_EN`.
    - Drives `tx_data_o` and `status_grp.TX_BUSY`.
    - Internally instantiates `baud_from_osr`.

**Filelists**
- `filelists/uart_top.f` is the full build order.
- Per-block filelists exist in `filelists/` for targeted sims.
- Update filelists when adding or renaming RTL.

**Register Generation**
- Generated RTL lives in `rtl/generated/` and `includes/`.
- Sources/configs:
  - `scripts/reg_gen/reg_generation_config.yml`
  - `scripts/reg_gen/gen_regs.sh`
  - `docs/reg_map.xlsx`
- Do not edit generated files directly; update config or spreadsheet and re-run generation.

**Verilog / SystemVerilog Coding Style**
- Use SystemVerilog (`.sv`) with `wire` for combinational signals and `reg` for flops/state.
- Clock/reset: synchronous active-high reset named `reset_i`.
- Signal naming:
  - Inputs `*_i`, outputs `*_o`.
  - Registered signals end with `_r`.
  - Wires are plain.
- Modules are lower_snake_case and parameterized via `parameter` / `localparam`.
- FSMs use `typedef enum logic` and `unique case`.
- Keep reset behavior explicit inside sequential blocks.
- Avoid latches: assign all outputs in every branch or use `always_comb` defaults.
- Prefer one purpose per always block (FSM, counters, sync, etc.).
- Keep generated files untouched and clearly separated from hand-written RTL.

**Tests**
- Block-level TBs in `tb/*_tb/` and shared helpers in `tb/common.sv`.
- Generated TBs in `tb/generated/`.
- Script entry point: `scripts/run_test.sh`.
- All tests run on Icarus Verilog.

**If You Change RTL**
- Update `filelists/*.f` if file ordering or membership changes.
- Update docs in `docs/` if hierarchy or behavior changes.
- Keep register map + generator outputs in sync.
