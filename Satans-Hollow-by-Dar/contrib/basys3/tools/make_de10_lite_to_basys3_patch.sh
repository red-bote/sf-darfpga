#!/bin/bash
# Generate the patch that adapts the upstream DE10-lite top level
# (rtl_dar/satans_hollow_de10_lite.vhd) into the Basys3 top level
# (satans_hollow_basys3.vhd).
#
# The target satans_hollow_basys3.vhd is authored here (it is a full rewrite
# of the top-level wrapper). The script:
#   1. Writes the target VHDL to a scratch dir.
#   2. Diffs it against the pristine upstream source to produce the git-style
#      patch at contrib/basys3/code/satans_hollow_de10_lite_to_basys3.patch
#      (matching the Kick/Solar-Fox/Crazy-Cong/Popeye convention; the fix
#      patches stay flat in contrib/code/).
#   3. Places the target where satans_hollow_basys3.xpr expects it
#      (basys3/satans_hollow_basys3.srcs/sources_1/new/satans_hollow_basys3.vhd).
#
# Requires the pristine tree (run `make setup` first).
# Per project rules this script runs from /tmp so scratch stays outside the repo.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC="$ROOT/vhdl_satans_hollow_rev_0_2_2019_11_22/rtl_dar/satans_hollow_de10_lite.vhd"
PROJ_DIR="$ROOT/vhdl_satans_hollow_rev_0_2_2019_11_22/basys3"
TARGET_SRC="$PROJ_DIR/satans_hollow_basys3.srcs/sources_1/new"
PATCH="$ROOT/contrib/basys3/code/satans_hollow_de10_lite_to_basys3.patch"

WORK=/tmp/satans_hollow_de10_to_basys3
TARGET="$WORK/satans_hollow_basys3.vhd"

if [ ! -f "$SRC" ]; then
    echo "error: pristine source not found: $SRC" >&2
    echo "Run 'make setup' first to populate vhdl_satans_hollow_rev_0_2_2019_11_22/." >&2
    exit 1
fi

rm -rf "$WORK"
mkdir -p "$WORK"

cat > "$TARGET" <<'EOF'
-------------------------------------------------------------------------------
-- Basys3 Top level for Satan's Hollow (Bally Midway MCR, 1981) by Dar
-- (darfpga@aol.fr) (22/11/2019)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from satans_hollow_de10_lite.vhd (DE10-lite rev 02 22/11/2019):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives a single clock_40
--    (40 MHz) used for everything: the core, the sound YM2149, the PWM audio
--    accumulators and the keyboard -- exactly as the pristine top's
--    max10_pll_40M (50 -> 40 MHz) did on the DE10-lite. reset comes from btnC
--    (active high, ORed with !mmcm_locked).
--  - Video path reproduced from the pristine top: the core drives the real
--    video_hs/video_vs and selects the timing natively (no line_doubler, no
--    external scandoubler). Display mode is selected by sw(13) (0 = 31 kHz
--    progressive VGA, 1 = 15 kHz interlaced TV) and toggled by F8
--    (fn_toggle(7) XORed with sw(13)); default (sw(13)=0) is 31 kHz VGA:
--      0 = 31 kHz progressive VGA (pixel data at the core's native rate)
--      1 = 15 kHz interlaced TV (native composite sync on HS, VS held high)
--    HS/VS are muxed exactly as the pristine assignments. RGB is padded
--    3/3/3 -> 4/4/4 (r&'0', g&'0', b&'0') the same way in both modes.
--  - Keyboard on the Basys3 onboard USB-HID connector (ps2_clk = C17,
--    ps2_dat = B17), NOT on the JB Pmod, using Dar's io_ps2_keyboard +
--    kbd_joystick clocked directly on clock_40 (40 MHz, comfortably above the
--    >= 6 MHz the onboard USB-HID host needs). The pristine clock_kbd divider
--    was dropped from the keyboard path; clock_div is kept only to gate the
--    PWM audio accumulators.
--  - Keyboard map (kbd_joystick -> joy_BBBBFRLDU, 9 bits):
--      bit0 = Up arrow (0x75)      -> up (shield, fire2)
--      bit1 = Down arrow (0x72)    -> down (unused)
--      bit2 = Left arrow (0x6B)    -> left
--      bit3 = Right arrow (0x74)   -> right
--      bit4 = Space (0x29)         -> fire1 (fire)
--  - Function keys (kbd_joystick):
--      F1 (fn_pulse 0) = coin      F2 (fn_pulse 1) = start1
--      F3 (fn_pulse 2) = start2    F8 (fn_toggle 7) = tv15Khz_mode toggle
--      F5 (fn_toggle 4) = service / separate_audio (pristine shares F5 for both)
--  - JA joystick OR-merged with the keyboard (JA is active-low; a press is
--    inverted to active-high like the keyboard path):
--      JA1 = left  JA2 = right  JA3 = shield (fire2)  JA7 = fire
--    Fire drives fire1; shield drives fire2 (OR-merged with keyboard Up).
--  - Pushbuttons: btnU = coin, btnD = coin2 (convenience; the pristine top
--    tied coin2 to '0'), btnL = start1, btnR = start2 (btnC = reset). These
--    replace the dedicated-key requirements so the port is playable with a
--    joystick + buttons only.
--  - Mono PWM audio on PmodAMP2 (JC): reproduces the pristine left-channel
--    18-bit accumulator exactly, gated on clock_div = "0000" (effective 4 MHz
--    update) on clock_40, adding ('0'&audio_l&'0') i.e. audio doubled; output
--    is bit 17. The right-channel accumulator is kept in lockstep but is not
--    wired to the mono amp. sw14 = shutdown, sw15 = gain select.
--  - DE10-lite's 7-segment debug hex display (decodeur_7_seg on
--    dbg_cpu_addr) and unused peripheral shims (usb_host_max3421e,
--    sgtl5000_dac) are not ported; dbg_cpu_addr is left open.
-------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity satans_hollow_basys3 is
port(
  clk             : in  std_logic;
  sw              : in  std_logic_vector(15 downto 0);
  btnC            : in  std_logic;  -- reset
  btnL            : in  std_logic;  -- start1
  btnR            : in  std_logic;  -- start2
  btnU            : in  std_logic;  -- coin1
  btnD            : in  std_logic;  -- coin2

  JA              : in  std_logic_vector(4 downto 0);  -- JA2=left, JA1=right, JA7=fire, JA3=shield
  ps2_dat         : in  std_logic;
  ps2_clk         : in  std_logic;

  O_PMODAMP2_AIN  : out std_logic;
  O_PMODAMP2_GAIN : out std_logic;
  O_PMODAMP2_SHUTD: out std_logic;

  vga_r   : out std_logic_vector(3 downto 0);
  vga_g   : out std_logic_vector(3 downto 0);
  vga_b   : out std_logic_vector(3 downto 0);
  vga_hs  : out std_logic;
  vga_vs  : out std_logic
);
end satans_hollow_basys3;

architecture struct of satans_hollow_basys3 is

  signal clock_40    : std_logic;
  signal mmcm_locked : std_logic;
  signal reset       : std_logic;

  signal tv15Khz_mode : std_logic;

  signal r      : std_logic_vector(2 downto 0);
  signal g      : std_logic_vector(2 downto 0);
  signal b      : std_logic_vector(2 downto 0);
  signal csync  : std_logic;
  signal blankn : std_logic;
  signal hsync  : std_logic;
  signal vsync  : std_logic;

  signal audio_l          : std_logic_vector(15 downto 0);
  signal audio_r          : std_logic_vector(15 downto 0);
  signal pwm_accumulator_l: std_logic_vector(17 downto 0);
  signal pwm_accumulator_r: std_logic_vector(17 downto 0);

  -- clock_div gate for the PWM accumulators (pristine clock_kbd divider,
  -- clock_40 / 20; clock_kbd itself is no longer used by the keyboard, which
  -- now runs on clock_40 for the onboard USB-HID host)
  signal clock_div : std_logic_vector(3 downto 0);

  signal kbd_intr     : std_logic;
  signal kbd_scancode : std_logic_vector(7 downto 0);
  signal joy_BBBBFRLDU: std_logic_vector(8 downto 0);
  signal fn_pulse     : std_logic_vector(7 downto 0);
  signal fn_toggle    : std_logic_vector(7 downto 0);

  signal ja_left  : std_logic;
  signal ja_right : std_logic;
  signal ja_fire  : std_logic;
  signal ja_up    : std_logic;

begin

  reset <= btnC or not mmcm_locked;

  clocks : entity work.clk_wiz_0
  port map(
    clk_in1  => clk,
    clk_out1 => clock_40,
    reset    => btnC,
    locked   => mmcm_locked
  );

  -- display mode: sw(13) selects the base mode (0 = 31 kHz VGA, 1 = 15 kHz TV),
  -- XOR the F8 keyboard toggle (fn_toggle(7)) so F8 inverts it in either switch
  -- position. Default (sw(13)=0, F8 not pressed) = 31 kHz progressive VGA.
  -- (pristine: tv15Khz_mode <= not fn_toggle(7), which defaulted to 15 kHz)
  tv15Khz_mode <= sw(13) xor fn_toggle(7);

  -- Satans hollow
  satans_hollow_inst : entity work.satans_hollow
  port map(
    clock_40   => clock_40,
    reset      => reset,

    tv15Khz_mode => tv15Khz_mode,
    video_r      => r,
    video_g      => g,
    video_b      => b,
    video_csync  => csync,
    video_blankn => blankn,
    video_hs     => hsync,
    video_vs     => vsync,

    separate_audio => fn_toggle(4),  -- F5
    audio_out_l    => audio_l,
    audio_out_r    => audio_r,

    coin1          => fn_pulse(0) or btnU,  -- F1 or btnU
    coin2          => btnD,                 -- btnD convenience (pristine tied low)
    start1         => fn_pulse(1) or btnL,  -- F2 or btnL
    start2         => fn_pulse(2) or btnR,  -- F3 or btnR

    left           => joy_BBBBFRLDU(2) or ja_left,
    right          => joy_BBBBFRLDU(3) or ja_right,
    fire1          => joy_BBBBFRLDU(4) or ja_fire,  -- spacer / JA7
    fire2          => joy_BBBBFRLDU(0) or ja_up,  -- up (shield)

    left_c         => joy_BBBBFRLDU(2) or ja_left,
    right_c        => joy_BBBBFRLDU(3) or ja_right,
    fire1_c        => joy_BBBBFRLDU(4) or ja_fire,
    fire2_c        => joy_BBBBFRLDU(0) or ja_up,

    coin_meters    => '0',
    cocktail       => '0',  -- pristine hard-coded '0' (F7 toggle "KO atm")

    service        => fn_toggle(4),  -- F5 (allow machine settings access)

    dbg_cpu_addr   => open
  );

  -- pristine clock_div divider (same process as the DE10 top; clock_kbd no
  -- longer produced, clock_div counts for the PWM accumulator gate only)
  process(reset, clock_40)
  begin
    if reset = '1' then
      clock_div <= (others => '0');
    else
      if rising_edge(clock_40) then
        if clock_div = "1001" then
          clock_div <= (others => '0');
        else
          clock_div <= std_logic_vector(unsigned(clock_div) + 1);
        end if;
      end if;
    end if;
  end process;

  -- get scancode from keyboard (onboard USB HID host on C17/B17, clock_40)
  keyboard : entity work.io_ps2_keyboard
  port map (
    clk       => clock_40,
    kbd_clk   => ps2_clk,
    kbd_dat   => ps2_dat,
    interrupt => kbd_intr,
    scancode  => kbd_scancode
  );

  -- translate scancode to joystick / function keys
  joystick : entity work.kbd_joystick
  port map (
    clk            => clock_40,
    kbdint         => kbd_intr,
    kbdscancode    => kbd_scancode,
    joy_BBBBFRLDU  => joy_BBBBFRLDU,
    fn_pulse       => fn_pulse,
    fn_toggle      => fn_toggle
  );

  -- JA physical map: JA1=left, JA2=right, JA7=fire. JA is active-low (pressed
  -- shorts to ground); invert so a press reads active-high, matching the
  -- core's active-high input boundary and the keyboard path.
  ja_left  <= not JA(1);   -- JA2
  ja_right <= not JA(0);   -- JA1
  ja_fire  <= not JA(4);   -- JA7
  ja_up    <= not JA(2);   -- JA3 (shield)

  -- Pad native 3/3/3-bit RGB to the VGA connector's 4-bit/channel input by
  -- MSB replication (identical to the pristine vga_r/vga_g/vga_b).
  vga_r <= r & '0' when blankn = '1' else "0000";
  vga_g <= g & '0' when blankn = '1' else "0000";
  vga_b <= b & '0' when blankn = '1' else "0000";

  -- Display mode select: sw(13) = 0 -> 31 kHz VGA, sw(13) = 1 -> 15 kHz TV,
  -- XORed with the F8 keyboard toggle (fn_toggle(7)):
  --   0 = 31 kHz VGA (real hsync/vsync)
  --   1 = 15 kHz TV  (native rate, composite sync on HS, VS held high)
  vga_hs <= csync when tv15Khz_mode = '1' else hsync;
  vga_vs <= '1'   when tv15Khz_mode = '1' else vsync;

  -- pwm sound output (reproduces the pristine top's exact left/right
  -- accumulators, gated on clock_div = "0000"). Only the left channel is
  -- wired to the mono PmodAMP2.
  process(clock_40)
  begin
    if rising_edge(clock_40) then
      if clock_div = "0000" then
        pwm_accumulator_l   <= std_logic_vector(unsigned('0' & pwm_accumulator_l(16 downto 0)) + unsigned('0' & audio_l & '0'));
        pwm_accumulator_r   <= std_logic_vector(unsigned('0' & pwm_accumulator_r(16 downto 0)) + unsigned('0' & audio_r & '0'));
      end if;
    end if;
  end process;

  O_PMODAMP2_AIN   <= pwm_accumulator_l(17);
  O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
  O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;

EOF

# Emit git-style patch (matches the *_de10_lite_to_basys3.patch convention).
mkdir -p "$(dirname "$PATCH")"
{
  printf 'diff --git a/vhdl_satans_hollow_rev_0_2_2019_11_22/rtl_dar/satans_hollow_de10_lite.vhd b/vhdl_satans_hollow_rev_0_2_2019_11_22/rtl_dar/satans_hollow_de10_lite.vhd\n'
  diff -u --label "a/vhdl_satans_hollow_rev_0_2_2019_11_22/rtl_dar/satans_hollow_de10_lite.vhd" \
            --label "b/vhdl_satans_hollow_rev_0_2_2019_11_22/rtl_dar/satans_hollow_de10_lite.vhd" \
            "$SRC" "$TARGET" || [ $? -eq 1 ]   # diff returns 1 when files differ (expected)
} > "$PATCH"

mkdir -p "$TARGET_SRC"
cp -f "$TARGET" "$TARGET_SRC/satans_hollow_basys3.vhd"

rm -rf "$WORK"