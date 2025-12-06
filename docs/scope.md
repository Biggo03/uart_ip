# UART IP Core Scope Document

## 1. Project Overview
The goal of this project is to define and implements a modular, reusable, and fully documented UART IP core, intended for integration with a custom RV32I processor as well as standalone FPGA designs.

The design will prioritize:
- Clean layering
- Clear register interface
- High configurability
- Solid documentation
- A realistic feature roadmap

The UART will evolve through incremental versions to maintain clarity and correctness.

---

## 2. Design Philosophy

### Layered Architecture:
1. **UART Core**:
- TX engine
- RX engine
- Oversampling logic
- Baud generator

2. **Register Block**:
- MMIO-accessible configuration
- Data registers
- status tracking

### Single Clock Domain
- Baud ticks generated internally using counters
- RX input treated as asynchronous and synchronized
- No multi-clock complexity (yet)

### Seperation of Concerns
- IP core handles protocol/state-machine behaviour
- Register block handles CPU-visible access patterns, control bits, FIFO'sm and interrupt conditions

### Documentation
- Clear descriptions of functions, register map, FSMs, timing, and configuration mechanisms
- Architecture to be readable without RTL

---

## 3. Version Roadmap

### V1 Features

Goal: Implement a stable, functional UART suitable for printf, serial output, and basic data reception.

#### TX Engine
- 8N1 format (8 data bits, no parity, 1 stop)
- Start/data/stop sequencing
- Byte-level shift register

#### RX Engine
- Fixed 16× oversampling
- Start-bit detection
- Mid-bit sampling
- Stop-bit validation
- Framing error detection

#### Baud Generation
- Integer baud divisor
- Single clock input (`clk`)
- Baud tick signal for TX/RX FSMs

#### FIFOs
- Generic and configurable
- full/empty flags
- overrun flag

#### Register Block
Registers accessible by CPU:
- **TXDATA** (write-only)
- **RXDATA** (read-only)
- **STATUS** (TX busy, FIFO status, error bits)
- **CONTROL** (enable TX/RX)
- **BAUDDIV** (integer divider)

#### Interrupts
- RX data available interrupt
- TX FIFO empty interrupt

#### V1 Deliverables
- UART core RTL
- Register block RTL
- Documentation:
  - Architecture overview
  - FSM descriptions
  - RX oversampling explanation
  - Register map
  - Timing narratives

---

### V2 Features

Goal: Implement features found in professional MCU/SoC UARTs.

#### 1. Configurable Frame Format
- Parity: none / odd / even
- Stop bits: 1 or 2
- Data bits: 7 / 8 / 9 (optional)

#### 2. Hardware Flow Control
- **RTS** output based on RX FIFO fullness
- **CTS** input controlling TX engine
- Configurable enable/disable bits

#### 3. FIFO Watermark Interrupts
- RX FIFO “almost full” interrupt
- TX FIFO “almost empty” interrupt
- Programmable thresholds

#### 4. Extended Error Detection
- Parity error
- Framing error
- Break detection
- Sticky error flags (software clear required)

#### 5. Fractional Baud Rate Generator
- Higher-precision baud timing
- Fractional accumulator or M/N-based divisor
- Improved compatibility with arbitrary system clock frequencies

#### 6. Autobaud Detection
- Detect baud rate from RX line transitions
- Determine baud divisor
- “Autobaud lock” status
- Timeout/error conditions
- Manual override via control register

---

## 4. Documentation Requirements

The following documents form part of the IP deliverable:

- High-level architecture overview
- TX and RX state machine descriptions
- Description of oversampling behavior
- Baud-generation algorithm and formulas
- UART register map (V1 & V2)
- Descriptions of parity, flow control, watermarks, and autobaud
- Integration notes for software interaction (MMIO usage)

---

## 5. Success Criteria

### V1.0 Complete When:
- UART reliably transmits and receives bytes under 8N1
- FIFOs operate correctly
- Error conditions detected
- Register map stable and documented
- All V1 features implemented in RTL
- All V1 documentation complete

### V2.0 Complete When:
- All parity/stop-bit configurations function correctly
- Flow control operates without deadlock
- Watermark interrupts behave per specification
- Autobaud reliably detects baud rates within tolerance
- Documentation updated to reflect all V2 features

