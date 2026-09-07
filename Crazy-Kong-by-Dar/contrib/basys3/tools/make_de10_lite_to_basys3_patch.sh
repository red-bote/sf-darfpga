#!/bin/bash
# Generate the patch that adapts the upstream DE10-lite top level
# (rtl_dar/ckong_de10_lite.vhd) into the Basys3 top level
# (ckong_basys3.vhd).
#
# The target ckong_basys3.vhd is authored here (it is a full rewrite of the
# top-level wrapper). The script:
#   1. Writes the target VHDL to a scratch dir.
#   2. Diffs it against the pristine upstream source to produce the git-style
#      patch at contrib/basys3/code/ckong_de10_lite_to_basys3.patch
#      (matching the Pooyan/Time-Pilot/Bagman/Berzerk/Zaxxon/Traverse-USA
#      convention; the fix patches stay flat in contrib/code/).
#   3. Places the target where ckong_basys3.xpr expects it
#      (basys3/ckong_basys3.srcs/sources_1/new/ckong_basys3.vhd).
#
# Requires the pristine tree (run `make setup` first).
# Per project rules this script runs from /tmp so scratch stays outside the repo.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC="$ROOT/vhdl_ckong_rev_0_1_2018_06_06/rtl_dar/ckong_de10_lite.vhd"
PROJ_DIR="$ROOT/vhdl_ckong_rev_0_1_2018_06_06/basys3"
TARGET_SRC="$PROJ_DIR/ckong_basys3.srcs/sources_1/new"
PATCH="$ROOT/contrib/basys3/code/ckong_de10_lite_to_basys3.patch"

WORK=/tmp/ckong_de10_to_basys3
TARGET="$WORK/ckong_basys3.vhd"

if [ ! -f "$SRC" ]; then
    echo "error: pristine source not found: $SRC" >&2
    echo "Run 'make setup' first to populate vhdl_ckong_rev_0_1_2018_06_06/." >&2
    exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK"

cat > "$TARGET" <<'EOF'
---------------------------------------------------------------------------------
-- Basys3 Top level for Crazy Kong (Irem M-52, 1981 bootleg of Donkey Kong;
-- per Dar's README the core plays Crazy Kong Part II / Falcon) by Dar
-- (darfpga@aol.fr) (06/06/2018)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from ckong_de10_lite.vhd (DE10-lite rev 06/06/2018):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives a single clock_12
--    (12 MHz) used for everything: the core, the sound, the PWM audio
--    accumulator and the keyboard -- exactly as the pristine top's
--    max10_pll_12M (50 -> 12 MHz) did on the DE10-lite.
--  - Joystick on JA (four directions + fire/jump), OR-merged with the
--    PS/2/USB keyboard and, for coin/start, dedicated buttons (btnU/btnD =
--    coin, btnL = P1 start, btnR = P2 start). Core inputs are active-high;
--    JA is active-low, so a press is inverted to active-high like the
--    keyboard path.
--  - Mono PWM audio on PmodAMP2 (JC); sw14 = shutdown, sw15 = gain select.
--    Reproduces the pristine process exactly: 13-bit accumulator on
--    clock_12, adding audio(15 downto 4), output is bit 12.
--  - Display mode via sw(13), replacing the DE10's sw(0):
--      0 = 31 kHz progressive VGA: the core's internal line_doubler
--          (tv15Khz_mode = '0') drives the real video_hs/video_vs -- no
--          external scandoubler is needed for this core.
--      1 = 15 kHz TV: native composite sync on HS (video_csync), VS held
--          high (needs a 15 kHz RGB monitor or RGB->composite converter).
--    RGB is padded 3/3/2 -> 4/4/4 the same way in both modes (r&'0', g&'0',
--    b&"00"), exactly as the pristine vga_r/vga_g/vga_b assignments.
--  - Keyboard on the Basys3 onboard USB-HID connector (ps2_clk = C17,
--    ps2_dat = B17), NOT on a Pmod. io_ps2_keyboard / kbd_joystick run at
--    clock_12 = 12 MHz, which is comfortably above the >= 6 MHz this onboard
--    host needs (Congo Bongo / Arcade_Zaxxon / Pooyan data) -- no divider is
--    required (unlike Traverse-USA, whose shared pristine divider was ~3 MHz).
--  - Keyboard map (kbd_joystick -> joyHBCPPFRLDU, 10 bits):
--      bit0 = Up arrow (0x75)  -> up
--      bit1 = Down arrow (0x72)-> down
--      bit2 = Left arrow (0x6B)-> left
--      bit3 = Right arrow(0x74)-> right
--      bit4 = Space (0x29)     -> fire/jump (no key for it on US keyboards)
--      bit5 = F1 (0x05)        -> start 1          bit8 = Ctrl (0x14)
--      bit6 = F2 (0x06)        -> start 2          bit9 = W (0x1D)
--      bit7 = F3 (0x04)        -> coin
--  - Player 2 mirrors player 1 (kbd_joystick only tracks one set; the core
--    has no independent P2 controls, only cocktail-mode duplicates).
--  - DE10-lite's 7-segment debug hex display (dbg_cpu_addr) is not ported;
--    the core's debug output is left open.
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity ckong_basys3 is
port(
 clk             : in  std_logic;
 sw              : in  std_logic_vector(15 downto 0);
 btnC            : in  std_logic;  -- reset
 btnL            : in  std_logic;  -- P1 start
 btnR            : in  std_logic;  -- P2 start
 btnU            : in  std_logic;  -- coin-in
 btnD            : in  std_logic;  -- coin-in

 JA              : in  std_logic_vector(4 downto 0);  -- joystick (right/left/down/up/fire)
 ps2_dat         : in  std_logic;
 ps2_clk         : in  std_logic;

 O_PMODAMP2_AIN  : out std_logic;
 O_PMODAMP2_GAIN : out std_logic;
 O_PMODAMP2_SHUTD: out std_logic;

 vgaRed   : out std_logic_vector(3 downto 0);
 vgaGreen : out std_logic_vector(3 downto 0);
 vgaBlue  : out std_logic_vector(3 downto 0);
 vgaHsync : out std_logic;
 vgaVsync : out std_logic
);
end ckong_basys3;

architecture struct of ckong_basys3 is

 signal clock_12    : std_logic;
 signal mmcm_locked : std_logic;
 signal reset       : std_logic;

 signal r         : std_logic_vector(2 downto 0);
 signal g         : std_logic_vector(2 downto 0);
 signal b         : std_logic_vector(1 downto 0);
 signal csync     : std_logic;
 signal hsync     : std_logic;
 signal vsync     : std_logic;

 signal audio           : std_logic_vector(15 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);

 signal kbd_intr      : std_logic;
 signal kbd_scancode  : std_logic_vector(7 downto 0);
 signal joyHBCPPFRLDU : std_logic_vector(9 downto 0);

 signal core_up, core_down, core_left, core_right, core_fire    : std_logic;
 signal core_coin1, core_start1, core_start2                    : std_logic;

begin

 -- btnC is active-high: it resets the MMCM and, together with !locked,
 -- holds the core in reset until the clock is stable.
 reset <= btnC or not mmcm_locked;

 clocks : entity work.clk_wiz_0
 port map(
  clk_in1  => clk,
  clk_out1 => clock_12,
  reset    => btnC,
  locked   => mmcm_locked
 );

 -- Crazy Kong (video_clk is unused, matching the pristine DE10 top)
 ckong_inst : entity work.ckong
 port map(
  clock_12   => clock_12,
  reset      => reset,

  tv15Khz_mode => sw(13),
  video_r      => r,
  video_g      => g,
  video_b      => b,
  video_csync  => csync,
  video_hs     => hsync,
  video_vs     => vsync,
  audio_out    => audio,

  start2  => core_start2,
  start1  => core_start1,
  coin1   => core_coin1,

  fire1   => core_fire,
  right1  => core_right,
  left1   => core_left,
  down1   => core_down,
  up1     => core_up,

  fire2   => core_fire,
  right2  => core_right,
  left2   => core_left,
  down2   => core_down,
  up2     => core_up
 );

 -- get scancode from keyboard
 keyboard : entity work.io_ps2_keyboard
 port map (
  clk       => clock_12, -- 12 MHz: >= 6 MHz required by the onboard USB-HID host
  kbd_clk   => ps2_clk,
  kbd_dat   => ps2_dat,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
 );

 -- translate scancode to joystick / function keys
 joystick : entity work.kbd_joystick
 port map (
  clk          => clock_12,
  kbdint       => kbd_intr,
  kbdscancode  => kbd_scancode,
  joyHBCPPFRLDU => joyHBCPPFRLDU,
  keys_HUA     => open
 );

 -- OR-merge the joystick on JA with the PS/2 keyboard joystick. JA physical
 -- map: JA1=right, JA2=left, JA3=down, JA4=up, JA7=fire/jump, i.e.
 -- JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up, JA(4)=fire. JA is
 -- active-low (pressed shorts to ground); invert so a press reads
 -- active-high, matching the core's active-high input boundary and the
 -- keyboard path.
 core_up    <= joyHBCPPFRLDU(0) or not JA(3);
 core_down  <= joyHBCPPFRLDU(1) or not JA(2);
 core_left  <= joyHBCPPFRLDU(2) or not JA(1);
 core_right <= joyHBCPPFRLDU(3) or not JA(0);
 core_fire  <= joyHBCPPFRLDU(4) or not JA(4);

 -- Coin/start: keyboard (F1/F2/F3) OR-merged with dedicated buttons.
 -- Buttons are active-high (Basys3 board pull-down, same convention as
 -- btnC). This core has a single coin input; btnU and btnD both trigger it.
 core_coin1  <= joyHBCPPFRLDU(7) or btnU or btnD;  -- coin   = F3 or btnU or btnD
 core_start1 <= joyHBCPPFRLDU(5) or btnL;          -- start1 = F1 or btnL
 core_start2 <= joyHBCPPFRLDU(6) or btnR;          -- start2 = F2 or btnR

 -- Pad native 3/3/2-bit RGB to the VGA connector's 4-bit/channel input by
 -- MSB replication (identical to the pristine vga_r/vga_g/vga_b).
 vgaRed   <= r & '0';
 vgaGreen <= g & '0';
 vgaBlue  <= b & "00";

 -- Display mode switch via sw(13):
 --   0 = 31 kHz VGA (internal line doubler, real hsync/vsync)
 --   1 = 15 kHz TV  (native rate, composite sync on HS, VS held high)
 vgaHsync <= csync when sw(13) = '1' else hsync;
 vgaVsync <= '1'   when sw(13) = '1' else vsync;

 -- pwm sound output (reproduces the pristine top's exact accumulator).
 process(clock_12)
 begin
  if rising_edge(clock_12) then
   pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned('0' & audio(15 downto 4)));
  end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator(12);
 O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
 O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
EOF

# Emit git-style patch (matches the *_de10_lite_to_basys3.patch convention).
mkdir -p "$(dirname "$PATCH")"
{
  printf 'diff --git a/vhdl_ckong_rev_0_1_2018_06_06/rtl_dar/ckong_de10_lite.vhd b/vhdl_ckong_rev_0_1_2018_06_06/rtl_dar/ckong_de10_lite.vhd\n'
  diff -u --label "a/vhdl_ckong_rev_0_1_2018_06_06/rtl_dar/ckong_de10_lite.vhd" \
            --label "b/vhdl_ckong_rev_0_1_2018_06_06/rtl_dar/ckong_de10_lite.vhd" \
            "$SRC" "$TARGET" || [ $? -eq 1 ]   # diff returns 1 when files differ (expected)
} > "$PATCH"

mkdir -p "$TARGET_SRC"
cp -f "$TARGET" "$TARGET_SRC/ckong_basys3.vhd"

rm -rf "$WORK"

echo "Generated patch:  $PATCH"
echo "Placed target:    $TARGET_SRC/ckong_basys3.vhd"
echo "Verify with:      patch -p1 --dry-run < contrib/basys3/code/ckong_de10_lite_to_basys3.patch"