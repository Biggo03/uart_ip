# UART External Loopback

This directory contains the FPGA-oriented external loopback path for the UART IP. It instantiates the normal `uart_top` core, drives its APB interface from a small control FSM, and echoes received UART bytes back to the host.

This is the repo's board-bring-up path for validating the full stack:

- external UART pins
- `uart_top`
- APB register interface
- generated regfile
- RX and TX FIFOs
- RX-to-TX echo control

## Directory Contents

- `extlpbk_fsm.sv`
  APB master FSM that configures the UART and performs the echo loop.
- `uart_extlpbk_harness.sv`
  Wrapper that connects `extlpbk_fsm` to `uart_top`.
- `uart_extlpbk_synth_top.sv`
  Minimal synthesis top for board bring-up.
- `uart_extlpbk_constr.xdc`
  Zybo Z7 constraints for clock, reset, enable switch, LEDs, and PMOD UART pins.

Related repo files:

- `filelists/uart_extlpbk_harness.f`
  Compile-order filelist for the external loopback harness simulation.
- `tb/uart_extlpbk_harness_tb/uart_extlpbk_harness_tb.sv`
  Testbench that sends bytes into the harness and checks for echoed responses.

## Architecture

```text
Host UART <-> uart_extlpbk_synth_top
                  |
                  v
          uart_extlpbk_harness
             |            |
             |            +--> extlpbk_fsm
             |                 - writes BAUD_CFG
             |                 - writes UART_CFG
             |                 - polls UART_STATUS
             |                 - reads RX_DATA
             |                 - writes TX_DATA
             |
             +--> uart_top
                   - uart_reg_interface
                   - baud_gen
                   - uart_rx
                   - uart_tx
```

The harness does not create a special UART datapath. It exercises the same top-level UART core used elsewhere in the repo and only replaces the normal software driver with an on-chip APB master FSM.

## Functional Behavior

When `extlpbk_enable_i` is asserted:

1. `extlpbk_fsm` writes `UART_BAUD_CFG_ADDR` with `BAUDDIV_CFG`.
2. It writes `UART_UART_CFG_ADDR` with TX and RX enabled.
3. It repeatedly reads `UART_UART_STATUS_ADDR` until `RX_VALID` is set.
4. It reads one byte from `UART_RX_DATA_ADDR`.
5. It polls `UART_UART_STATUS_ADDR` until there is TX FIFO room.
6. It writes the received byte to `UART_TX_DATA_ADDR`.

Net effect: each byte received on the external UART RX pin is echoed back on the external UART TX pin.

The FSM also exposes debug/status counters:

- `extlpbk_busy_o`
  High while the loopback sequencer is enabled and active.
- `extlpbk_echo_count_o`
  Increments for each echoed byte.
- `extlpbk_error_count_o`
  Increments on APB transaction errors.
- `extlpbk_last_rx_byte_o`
  Captures the most recently received byte.
- `extlpbk_last_tx_byte_o`
  Captures the most recently echoed byte.

## Register Assumptions

The loopback FSM depends on the current generated UART register map:

- `UART_UART_CFG_ADDR` = `0x00`
- `UART_UART_STATUS_ADDR` = `0x04`
- `UART_TX_DATA_ADDR` = `0x08`
- `UART_RX_DATA_ADDR` = `0x0C`
- `UART_BAUD_CFG_ADDR` = `0x10`

Status field assumptions used by `extlpbk_fsm.sv`:

- `RX_VALID` is `UART_STATUS[0]`
- `TX_LVL` is `UART_STATUS[13:9]`

If the register generator changes these fields, `extlpbk_fsm.sv` must be updated to match.

## Simulation

Use the dedicated filelist and testbench:

```bash
./scripts/run_test.sh \
  filelists/uart_extlpbk_harness.f \
  tb/uart_extlpbk_harness_tb/uart_extlpbk_harness_tb.sv \
  outputs/uart_extlpbk_harness_tb
```

The testbench:

- instantiates `uart_extlpbk_harness`
- models a host UART transmitter that sends bytes into the DUT
- models a monitor UART receiver that checks echoed bytes
- verifies `echo_count`, `error_count`, `last_rx_byte`, and `last_tx_byte`

For simulation, the testbench overrides `BAUDDIV_CFG` with a small divisor (`8`) so the run completes quickly.

## FPGA Bring-Up

### Synthesis Top

Use `uart_extlpbk_synth_top.sv` as the FPGA top module.

It exposes:

- `clk_i`
- `reset_i`
- `extlpbk_enable_i`
- `uart_ext_rx_i`
- `uart_ext_tx_o`
- `extlpbk_busy_o`
- `extlpbk_error_seen_o`
- `extlpbk_activity_o`

### Constraints

The provided XDC targets a Zybo Z7 and currently maps:

- `clk_i` to the 125 MHz board clock
- `extlpbk_enable_i` to `sw[0]`
- `reset_i` to `btn[0]`
- `extlpbk_busy_o` to `led[0]`
- `extlpbk_error_seen_o` to `led[1]`
- `extlpbk_activity_o` to `led[2]`

### UART PMOD Wiring

The current constraint file uses PMOD `JC`:

- `uart_ext_tx_o` -> `JC1N` (`PACKAGE_PIN W15`)
- `uart_ext_rx_i` <- `JC2P` (`PACKAGE_PIN T11`)

This should match the external USB-UART adapter wiring used for bring-up. If you move the interface to another PMOD header or board, update `uart_extlpbk_constr.xdc`.

## UART Settings

Default hardware assumptions:

- UART framing: 8N1
- no flow control
- `BAUDDIV_CFG = 68`
- input clock: `125 MHz`

That divisor produces an oversample tick for approximately 115200 baud operation with the current UART core.

If you use a different FPGA clock, update `BAUDDIV_CFG` in:

- `uart_extlpbk_synth_top.sv` instantiation path, or
- the overridden parameter in your project constraints / sources

Example:

- for `100 MHz`, a divisor near `54` targets roughly 115200 baud

## Vivado Source Set Guidance

For a board build, include:

- hand-written UART RTL from `rtl/`
- generated register RTL from `rtl/generated/`
- `fpga_validation/external_loopback/extlpbk_fsm.sv`
- `fpga_validation/external_loopback/uart_extlpbk_harness.sv`
- `fpga_validation/external_loopback/uart_extlpbk_synth_top.sv`
- `fpga_validation/external_loopback/uart_extlpbk_constr.xdc`

You do not need the simulation testbench files for synthesis.

## Quick Bring-Up Steps

1. Set top module to `uart_extlpbk_synth_top`.
2. Add the RTL and XDC listed above to the Vivado project.
3. Build and program the FPGA.
4. Connect a USB-UART adapter to the constrained PMOD pins.
5. Assert `sw[0]` to enable the loopback FSM.
6. Open a serial terminal at `115200 8N1`.
7. Send bytes from the host and confirm they are echoed back.
8. Check LEDs:
   - `led[0]`: loopback active
   - `led[1]`: APB error seen
   - `led[2]`: toggles with echo activity

## Notes

- This harness is intended for functional validation, not as a production integration wrapper.
- The APB master FSM assumes the UART register interface is always-ready, which matches the current `uart_reg_interface.sv` behavior.
- If the top-level UART register map or status layout changes, update this loopback path alongside the generated register outputs.
