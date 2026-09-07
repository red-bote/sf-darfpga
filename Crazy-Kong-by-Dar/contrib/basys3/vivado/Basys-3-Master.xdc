## Basys-3 XDC constraints for Crazy Kong (Basys3 port)
## Adapted from the Traverse USA Basys3 XDC (Red~Bote, 2026-09-04). Pin mapping
## matches ckong_basys3.vhd entity ports.
##   Keyboard: Onboard USB HID host (C17/B17)
##   Switch 13: display mode (0 = 31 kHz VGA, 1 = 15 kHz TV)
##   Switch 14: AMP shutdown | Switch 15: AMP gain
##   Buttons: btnC reset, btnU/btnD coin, btnL P1 start, btnR P2 start
##   JA joystick: JA1=right, JA2=left, JA3=down, JA4=up, JA7=fire (jump)

## Clock signal
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Switches
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN W16  IOSTANDARD LVCMOS33 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN W17  IOSTANDARD LVCMOS33 } [get_ports {sw[3]}]
set_property -dict { PACKAGE_PIN W15  IOSTANDARD LVCMOS33 } [get_ports {sw[4]}]
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports {sw[5]}]
set_property -dict { PACKAGE_PIN W14  IOSTANDARD LVCMOS33 } [get_ports {sw[6]}]
set_property -dict { PACKAGE_PIN W13  IOSTANDARD LVCMOS33 } [get_ports {sw[7]}]
set_property -dict { PACKAGE_PIN V2   IOSTANDARD LVCMOS33 } [get_ports {sw[8]}]
set_property -dict { PACKAGE_PIN T3   IOSTANDARD LVCMOS33 } [get_ports {sw[9]}]
set_property -dict { PACKAGE_PIN T2   IOSTANDARD LVCMOS33 } [get_ports {sw[10]}]
set_property -dict { PACKAGE_PIN R3   IOSTANDARD LVCMOS33 } [get_ports {sw[11]}]
set_property -dict { PACKAGE_PIN W2   IOSTANDARD LVCMOS33 } [get_ports {sw[12]}]
set_property -dict { PACKAGE_PIN U1   IOSTANDARD LVCMOS33 } [get_ports {sw[13]}]
set_property -dict { PACKAGE_PIN T1   IOSTANDARD LVCMOS33 } [get_ports {sw[14]}]
set_property -dict { PACKAGE_PIN R2   IOSTANDARD LVCMOS33 } [get_ports {sw[15]}]

## Buttons
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports btnC]
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports btnU]
set_property -dict { PACKAGE_PIN W19  IOSTANDARD LVCMOS33 } [get_ports btnL]
set_property -dict { PACKAGE_PIN T17  IOSTANDARD LVCMOS33 } [get_ports btnR]
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports btnD]

## Pmod Header JA  (active-low joystick on active bank)
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33   PULLUP true } [get_ports {JA[0]}];#Sch name = JA1 = right
set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33   PULLUP true } [get_ports {JA[1]}];#Sch name = JA2 = left
set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS33   PULLUP true } [get_ports {JA[2]}];#Sch name = JA3 = down
set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33   PULLUP true } [get_ports {JA[3]}];#Sch name = JA4 = up
set_property -dict { PACKAGE_PIN H1   IOSTANDARD LVCMOS33   PULLUP true } [get_ports {JA[4]}];#Sch name = JA7 = fire (jump)

## Pmod Header JC  (PmodAMP2 audio)
set_property -dict { PACKAGE_PIN K17  IOSTANDARD LVCMOS33 } [get_ports O_PMODAMP2_AIN]
set_property -dict { PACKAGE_PIN M18  IOSTANDARD LVCMOS33 } [get_ports O_PMODAMP2_GAIN]
set_property -dict { PACKAGE_PIN P18  IOSTANDARD LVCMOS33 } [get_ports O_PMODAMP2_SHUTD]

## VGA Connector
set_property -dict { PACKAGE_PIN G19  IOSTANDARD LVCMOS33 } [get_ports {vgaRed[0]}]
set_property -dict { PACKAGE_PIN H19  IOSTANDARD LVCMOS33 } [get_ports {vgaRed[1]}]
set_property -dict { PACKAGE_PIN J19  IOSTANDARD LVCMOS33 } [get_ports {vgaRed[2]}]
set_property -dict { PACKAGE_PIN N19  IOSTANDARD LVCMOS33 } [get_ports {vgaRed[3]}]
set_property -dict { PACKAGE_PIN N18  IOSTANDARD LVCMOS33 } [get_ports {vgaBlue[0]}]
set_property -dict { PACKAGE_PIN L18  IOSTANDARD LVCMOS33 } [get_ports {vgaBlue[1]}]
set_property -dict { PACKAGE_PIN K18  IOSTANDARD LVCMOS33 } [get_ports {vgaBlue[2]}]
set_property -dict { PACKAGE_PIN J18  IOSTANDARD LVCMOS33 } [get_ports {vgaBlue[3]}]
set_property -dict { PACKAGE_PIN J17  IOSTANDARD LVCMOS33 } [get_ports {vgaGreen[0]}]
set_property -dict { PACKAGE_PIN H17  IOSTANDARD LVCMOS33 } [get_ports {vgaGreen[1]}]
set_property -dict { PACKAGE_PIN G17  IOSTANDARD LVCMOS33 } [get_ports {vgaGreen[2]}]
set_property -dict { PACKAGE_PIN D17  IOSTANDARD LVCMOS33 } [get_ports {vgaGreen[3]}]
set_property -dict { PACKAGE_PIN P19  IOSTANDARD LVCMOS33 } [get_ports vgaHsync]
set_property -dict { PACKAGE_PIN R19  IOSTANDARD LVCMOS33 } [get_ports vgaVsync]

## USB HID (PS/2) — onboard USB-A connector
set_property -dict { PACKAGE_PIN C17  IOSTANDARD LVCMOS33  PULLUP true } [get_ports ps2_clk]
set_property -dict { PACKAGE_PIN B17  IOSTANDARD LVCMOS33  PULLUP true } [get_ports ps2_dat]

## Configuration properties (same as Congo Bongo / Burnin Rubber / Zaxxon)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]