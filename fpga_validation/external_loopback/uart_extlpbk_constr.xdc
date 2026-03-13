## uart_extlpbk_synth_top constraints (Zybo Z7)
##
## Active ports constrained in this file:
##   - clk_i, reset_i, extlpbk_enable_i
##   - extlpbk_busy_o, extlpbk_error_seen_o, extlpbk_activity_o, debug_led
##   - uart_ext_tx_o, uart_ext_rx_i
##
## UART PMOD wiring (kept unchanged):
##   - uart_ext_tx_o -> JC1N (PACKAGE_PIN W15)
##   - uart_ext_rx_i -> JC2P (PACKAGE_PIN T11)

## Clock (Zybo Z7 125 MHz oscillator)
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports clk_i]
create_clock -period 8.000 -name sys_clk_pin -waveform {0.000 4.000} -add [get_ports clk_i]

## Controls
set_property -dict { PACKAGE_PIN G15 IOSTANDARD LVCMOS33 } [get_ports extlpbk_enable_i] ; # sw[0]
set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports reset_i]          ; # btn[0]

## Status LEDs
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports extlpbk_busy_o]       ; # led[0]
set_property -dict { PACKAGE_PIN M15 IOSTANDARD LVCMOS33 } [get_ports extlpbk_error_seen_o] ; # led[1]
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports extlpbk_activity_o]   ; # led[2]

## UART pins on PMOD JC
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports uart_ext_tx_o] ; # JC1N
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports uart_ext_rx_i] ; # JC2P
