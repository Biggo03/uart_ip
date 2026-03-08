# UART External Loopback (Zybo + Pmod USBUART 410-212)

This folder contains a Zybo-targeted external loopback implementation built from the internal-loopback structure.

## Files

- `extlpbk_fsm.sv`
  - APB master FSM that configures the UART and runs an RX->TX echo loop.
- `uart_extlpbk_harness.sv`
  - Connects `extlpbk_fsm` to `uart_top`.
- `uart_extlpbk_synth_top.sv`
  - Synthesis top for board bring-up with switch/button/UART/LED ports.
- `uart_extlpbk_constr.xdc`
  - Zybo constraints for clock, controls, LEDs, and PMOD UART pins.

## Functional Behavior

When `extlpbk_enable_i` is asserted:

1. FSM writes `BAUD_CFG` (`BAUDDIV = BAUDDIV_CFG`, default `68`).
2. FSM writes `UART_CFG` with TX and RX enabled.
3. FSM continuously:
   - polls `UART_STATUS` until `RX_VALID=1`,
   - reads one byte from `RX_DATA`,
   - waits for TX FIFO space (`TX_LVL < 16`),
   - writes that byte to `TX_DATA`.

Net effect: each byte received from the external PC is echoed back over UART.

## Zybo + Pmod USBUART Wiring Expectations

This implementation assumes a Digilent **Pmod USBUART (410-212)** connected on **JA** with Type-4 UART convention:

- `uart_ext_tx_o` -> JA2 (PMOD pin 2, USBUART `RXD`)
- `uart_ext_rx_i` <- JA3 (PMOD pin 3, USBUART `TXD`)

The PMOD connector provides power/ground through the header.

## Expected Board Indicators

- `led[0]` (`extlpbk_busy_o`): high when loopback engine is enabled/running.
- `led[1]` (`extlpbk_error_seen_o`): latched high if APB transaction errors occur.
- `led[2]` (`extlpbk_activity_o`): toggles with each echoed byte (echo counter LSB).

## UART Host Settings

- Default target: **115200, 8 data bits, no parity, 1 stop bit (8N1), no flow control**.
- `BAUDDIV_CFG=68` assumes `clk_i = 125 MHz`.
- If your build uses `clk_i = 100 MHz`, set `BAUDDIV_CFG` to about `54` for ~115200 baud.

## Quick Bring-Up Steps

1. Set synthesis top to `uart_extlpbk_synth_top`.
2. Add:
   - RTL from `rtl/` + `rtl/generated/`
   - This folder's three `.sv` files
   - `uart_extlpbk_constr.xdc`
3. Program the Zybo and assert `sw0` (`extlpbk_enable_i`).
4. Open serial terminal on the USBUART COM port using settings above.
5. Send bytes from the PC; each byte should be echoed by hardware.
