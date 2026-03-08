## Zybo Z7 external UART loopback constraints
## Top module: uart_extlpbk_synth_top
##
## PMOD mapping targets Digilent Pmod USBUART (410-212), Type-4 UART:
##   - PMOD Pin 2 = USBUART RXD  <- FPGA TX
##   - PMOD Pin 3 = USBUART TXD  -> FPGA RX
## This file maps:
##   - JA2 (ja[1]) to uart_ext_tx_o
##   - JA3 (ja[2]) to uart_ext_rx_i

## Clock signal (Zybo Z7 125 MHz oscillator on K17)
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports clk_i]
create_clock -period 8.000 -name sys_clk_pin -waveform {0.000 4.000} -add [get_ports clk_i]

## Switches
set_property -dict { PACKAGE_PIN G15 IOSTANDARD LVCMOS33 } [get_ports { extlpbk_enable_i }]; # sw[0]

## Buttons
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports reset_i]; # btn[0]

## LEDs
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { extlpbk_busy_o }]; # led[0]
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports { extlpbk_error_seen_o }]; # led[1]
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports { extlpbk_activity_o }]; # led[2]

## PMOD Header JA
set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 } [get_ports { uart_ext_tx_o }]; # JA2 / PMOD pin 2 / USBUART RXD
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports { uart_ext_rx_i }]; # JA3 / PMOD pin 3 / USBUART TXD
