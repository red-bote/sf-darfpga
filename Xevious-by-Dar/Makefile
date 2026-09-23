GAME         := xevious
SRC_DIR      := vhdl_xevious_de2_de10_lite_2017_05_01
TOP_ENTITY   := xevious_basys3
DISPLAY_NAME := Xevious
IO_SUMMARY   := PS/2 keyboard (JB) + JA joystick (active-low: right, left, up, down unused -- game has no down control, fire, bomb=JA3) OR-merged; btnC=reset; btnU=coin, btnL=start1, btnR=start2; JC PmodAMP2 PWM audio; sw(14)=sound enable, sw(15)=AMP gain, sw(13)=display mode; VGA 4-4-4 RGB; dip switches hardcoded in the core (no sw mapping)
DISPLAY_HINT := sw(13): 0 = 31 kHz VGA, 1 = 15 kHz TV

include ../tools/mk/machine.mk
