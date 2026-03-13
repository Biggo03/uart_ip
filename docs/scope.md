# UART IP Core Scope Document

## 1. Project Overview

This project implements a modular UART IP core in SystemVerilog for integration into a larger SoC or for standalone FPGA use.

The current repo state should be treated as the V1 baseline:

- a working APB-facing UART top level
- separate TX and RX datapaths
- shared baud / oversample timing generation
- generated register collateral
- simulation testbenches
- FPGA loopback validation paths, including external loopback bring-up

The design continues to emphasize:

- clean layering
- clear register ownership
- reusable building blocks
- documentation that matches the RTL
- a practical roadmap for future UART features

## 2. Current V1 State

V1 is no longer just a planned feature set. It is the current implemented architecture in this repository.

### V1 Summary

The present UART supports:

- 8N1 transmit and receive
- integer baud divisor configuration through `BAUDDIV`
- shared oversample tick generation
- 16x RX oversampling
- separate 16-entry TX and RX FIFOs
- FIFO occupancy and overrun reporting
- APB register access through a generated regfile

V1 is intended to cover the core UART use case:

- software writes bytes to TX
- software reads bytes from RX
- software observes busy / valid / level / overrun status
- the same top-level core works in simulation and FPGA validation harnesses

### Implemented Top-Level Structure

Current top-level module: `rtl/uart_top.sv`

Integrated blocks:

1. `uart_reg_interface`
   Bridges APB accesses into the generated register file and converts RX/TX data register accesses into FIFO handshakes.
2. `baud_gen`
   Generates the shared `osr_tick` from `BAUDDIV` whenever TX or RX is enabled.
3. `uart_rx`
   Wraps `rx_engine` plus the RX FIFO and exposes RX-visible status.
4. `uart_tx`
   Wraps the TX FIFO plus `tx_engine` and exposes TX-visible status.

### Current V1 Register Model

The generated register interface currently exposes:

- `UART_CFG`
  - `TX_EN`
  - `TX_CLR_OVRN`
  - `RX_EN`
  - `RX_CLR_OVRN`
- `UART_STATUS`
  - `RX_VALID`
  - `RX_OVRN`
  - `RX_LVL`
  - `RX_BUSY`
  - `TX_OVRN`
  - `TX_LVL`
  - `TX_BUSY`
- `TX_DATA`
- `RX_DATA`
- `BAUD_CFG`

This is the software-visible V1 programming model that the current RTL and validation harnesses depend on.

### Current V1 Datapath Behavior

#### TX path

- software writes `TX_DATA`
- `uart_reg_interface` generates a TX FIFO write pulse
- `uart_tx` stores the byte in the TX FIFO
- `tx_engine` pulls FIFO data and serializes start, data, and stop bits

#### RX path

- `rx_engine` monitors the asynchronous serial input
- the input is synchronized internally
- samples are taken using 16x oversample timing
- a majority vote is used around the bit midpoint
- valid bytes are pushed into the RX FIFO
- software reads `RX_DATA` to pop bytes from the FIFO

### Single Clock Domain

The current V1 implementation remains single-clock:

- all logic runs from the system clock
- baud timing is derived internally from counters
- RX serial input is synchronized before use by the receive state machine

### Validation State of V1

The repository already contains V1 validation collateral:

- block-level testbenches for FIFO, baud generation, RX engine, and TX engine
- top-level UART testbench
- internal loopback harnesses
- external loopback harnesses

External loopback working in the repo is an important milestone because it validates the integrated V1 design beyond isolated simulation.

## 3. V1 Scope Boundaries

The following items are intentionally outside the current V1 scope:

- parity support
- selectable stop-bit count
- selectable data width
- hardware flow control
- watermark interrupts
- fractional baud generation
- autobaud detection

V1 also does not currently expose a dedicated interrupt output interface. The implemented interface is register- and status-driven.

## 4. V2 Roadmap

V2 is the next feature tier and should remain separate from the V1 baseline described above.

### 4.1 Configurable Frame Format

- parity: none / odd / even
- stop bits: 1 or 2
- data bits: 7 / 8 / 9 (optional)

### 4.2 Hardware Flow Control

- `RTS` output based on RX FIFO fullness
- `CTS` input controlling TX engine
- configurable enable / disable bits

### 4.3 FIFO Watermark Interrupts

- RX FIFO almost-full interrupt
- TX FIFO almost-empty interrupt
- programmable thresholds

### 4.4 Extended Error Detection

- parity error
- framing error
- break detection
- sticky error flags requiring software clear

### 4.5 Fractional Baud Rate Generator

- higher-precision baud timing
- fractional accumulator or M/N-based divisor
- improved compatibility with arbitrary system clock frequencies

### 4.6 Autobaud Detection

- detect baud rate from RX transitions
- determine baud divisor automatically
- autobaud lock status
- timeout and error handling
- manual override via control register

