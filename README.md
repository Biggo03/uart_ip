# UART IP

Modular UART IP core in SystemVerilog, built around a simple APB-facing register interface and intended for both simulation-driven development and FPGA bring-up.

The repository includes both simulation testbenches and board-level loopback harnesses, including an external loopback path validated with a Zybo and Digilent Pmod USBUART.

## Overview

This project is a layered UART design rather than a single monolithic block:

- `uart_top` is the integration point exposed to the rest of the system.
- `uart_reg_interface` connects an APB-style bus to the generated register file.
- `baud_gen` creates the oversample tick used by both TX and RX logic.
- `uart_tx` combines a TX FIFO with the `tx_engine` serializer.
- `uart_rx` combines the `rx_engine` receiver with an RX FIFO.

Current design focus is a clean V1 UART with:

- APB register access
- 8N1 transmit and receive
- 16x oversampling on RX
- Separate TX and RX FIFOs
- Generated register package / regfile collateral
- Simulation testbenches plus FPGA loopback harnesses

## Architecture

At the top level, software writes configuration and TX data through the APB interface, while received bytes and status are read back through the same register path.

```text
                  APB
                   |
                   v
        +-----------------------+
        |  uart_reg_interface   |
        |  + generated regfile  |
        +-----------+-----------+
                    |
          config / status / FIFO ctrl
                    |
        +-----------+-----------+
        |       uart_top        |
        +-----+-----------+-----+
              |           |
              |           +-------------------+
              |                               |
              v                               v
         +-----------+                   +-----------+
rx_data_i|  uart_rx  |                   |  uart_tx  | tx_data_o
-------->| rx_engine |                   | tx_engine |-------->
         | + rx_fifo |                   | + tx_fifo |
         +-----------+                   +-----------+
              ^                               ^
              |            osr_tick           |
              +---------------+---------------+
                              |
                         +----------+
                         | baud_gen |
                         +----------+
```

### Dataflow

#### TX path

1. Software writes a byte to the TX data register over APB.
2. `uart_reg_interface` converts that access into a FIFO write pulse.
3. `uart_tx` stores the byte in the TX FIFO.
4. `tx_engine` pulls bytes from the FIFO and emits start, data, and stop bits.
5. `tx_engine` uses a baud tick derived from the shared oversample tick.

#### RX path

1. `rx_engine` monitors `rx_data_i` for a start bit.
2. It synchronizes the incoming serial pin and samples each bit at 16x oversample timing.
3. A 3-sample majority vote is used around the bit midpoint.
4. Completed bytes are written into the RX FIFO.
5. Software reads RX data and status back through the APB register interface.

### Timing structure

- `baud_gen` generates a shared `osr_tick` from `BAUDDIV`.
- RX and TX each derive their own baud-rate timing from that oversample tick with `baud_from_osr`.
- TX and RX can be independently enabled, but they share the same baud generator configuration.

### Register interface

The register block is generated and wrapped by [`rtl/uart_reg_interface.sv`](rtl/uart_reg_interface.sv):

- APB reads and writes are translated into regfile accesses
- reads from `RX_DATA` pop the RX FIFO
- writes to `TX_DATA` push the TX FIFO
- status and configuration are exchanged through generated packed structs

Generated collateral lives in:

- `rtl/generated/`
- `includes/`
- `scripts/reg_gen/outputs/`

Do not hand-edit those files. Update the generation inputs and re-run the register generator instead.

## Repository Structure

### Design RTL

- `rtl/`
  Hand-written UART RTL, including `uart_top`, wrappers, engines, FIFO, and baud logic.
- `rtl/generated/`
  Auto-generated register package and regfile RTL.
- `includes/`
  Generated register macros for software / RTL integration.

### Verification

- `tb/`
  Block- and top-level testbenches for Icarus Verilog.
- `tb/generated/`
  Generated testbench collateral for the register file.
- `filelists/`
  Compile-order filelists for focused simulations and top-level builds.

### Scripts and Generation

- `scripts/run_test.sh`
  Main simulation entrypoint used to compile and run a testbench with a selected filelist.
- `scripts/reg_gen/`
  Register generation config, outputs, and helper scripts.
- `tools/Peripheral-Register-File-Generator/`
  External generator source used to produce the register collateral.

### Documentation and Validation

- `docs/`
  Scope notes, block-diagram source, and register-map source spreadsheet.
- `fpga_validation/internal_loopback/`
  FPGA harness for self-contained internal loopback validation.
- `fpga_validation/external_loopback/`
  FPGA harness for PC-to-board external UART echo testing.

## Important Files

- [`rtl/uart_top.sv`](rtl/uart_top.sv): top-level UART IP integration
- [`rtl/uart_reg_interface.sv`](rtl/uart_reg_interface.sv): APB wrapper around the generated regfile
- [`rtl/uart_tx.sv`](rtl/uart_tx.sv): TX wrapper with FIFO and serializer
- [`rtl/uart_rx.sv`](rtl/uart_rx.sv): RX wrapper with receiver and FIFO
- [`rtl/tx_engine.sv`](rtl/tx_engine.sv): 8N1 transmit state machine
- [`rtl/rx_engine.sv`](rtl/rx_engine.sv): oversampling receive state machine
- [`rtl/baud_gen.sv`](rtl/baud_gen.sv): oversample tick generator
- [`rtl/uart_fifo.sv`](rtl/uart_fifo.sv): generic synchronous FIFO

## Running Simulation

Simulations are run with Icarus Verilog through `scripts/run_test.sh`:

```bash
./scripts/run_test.sh <filelist> <testbench> <outdir>
```

Example:

```bash
./scripts/run_test.sh filelists/uart_top.f tb/uart_top_tb/uart_top_tb.sv outputs/uart_top_tb
```

Useful testbench targets include:

- `tb/baud_gen_tb/baud_gen_tb.sv`
- `tb/uart_fifo_tb/uart_fifo_tb.sv`
- `tb/rx_engine_tb/rx_engine_tb.sv`
- `tb/tx_engine_tb/tx_engine_tb.sv`
- `tb/uart_top_tb/uart_top_tb.sv`
- `tb/uart_extlpbk_harness_tb/uart_extlpbk_harness_tb.sv`

## FPGA Validation

The repo contains dedicated harnesses for moving beyond simulation:

- `fpga_validation/internal_loopback/`
  Enables a closed-loop validation path inside the FPGA fabric.
- `fpga_validation/external_loopback/`
  Connects `uart_top` to an APB-driving FSM and echoes bytes received from an external host UART.

The external loopback path is intended for Zybo bring-up with a Digilent Pmod USBUART. See [`fpga_validation/external_loopback/README.md`](fpga_validation/external_loopback/README.md) for board wiring and baud assumptions.

## Register Generation Flow

Register definitions are maintained outside the generated RTL:

- config: `scripts/reg_gen/reg_generation_config.yml`
- source spreadsheet: `docs/reg_map.xlsx`
- generation helper: `scripts/reg_gen/gen_regs.sh`

If the register map changes, regenerate the outputs rather than editing:

- `rtl/generated/*`
- `includes/*`
- `tb/generated/*`

## Development Notes

- Hand-written RTL lives in `rtl/`
- Generated RTL and macros should remain untouched
- Update `filelists/` when adding or renaming design files
- Update `docs/` when the hierarchy or externally visible behavior changes
