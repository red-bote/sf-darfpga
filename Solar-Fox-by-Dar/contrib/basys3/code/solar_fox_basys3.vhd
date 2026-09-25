---------------------------------------------------------------------------------
-- Basys3 Top level for Solar Fox (Bally Midway, 1981) by Dar (darfpga@aol.fr) (19/10/2019)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from solarfox_de10_lite.vhd (DE10-lite rev 01 2019/11/22):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives a single 40 MHz clock
--    (core + sound board), matching the sibling Kick-Midway-MCR port (same
--    Midway-family DE10-lite generation, same solved MMCM values).
--  - Core generates progressive 31 kHz video natively (tv15Khz_mode); no
--    external scandoubler is imported. F8 toggles 31 kHz VGA / 15 kHz TV.
--  - JA joystick (movement + fire), OR-merged with PS/2 keyboard (JB).
--    coin1/fast1 are OR-merged from keyboard (F1/F2), the JA fire+up (coin)
--    / fire+left (fast) combos, AND btnU/btnL -- the root PORTING_SPEC.md's
--    generic default IO mapping (coin-in = btnU, 1P start = btnL) applies
--    here since the core has real coin1/fast1 inputs for them to drive.
--  - btnD/btnR are declared on the entity but left unconnected (reserved):
--    the core ties coin2/fast2 (and all P2 inputs) to '0' with no genuine
--    second-coin or second-start facility (DE10-lite header: "Cocktail mode
--    : NO"), so the generic default's carve-out ("second coin-in: only if
--    the core has 2 coin inputs") means there is nothing for them to drive.
--  - Single player only: up2/down2/left2/right2/fire2/fast2/coin2 are tied
--    to '0', matching the pristine top exactly. The core has no cocktail
--    support (DE10-lite header: "Cocktail mode : NO").
--  - Stereo PWM audio in the core; PmodAMP2 (JC) is mono, so O_PMODAMP2_AIN
--    is driven from the left channel only (same choice as Kick).
--    separate_audio <= F5 (stereo/mono toggle), service <= F7, both
--    keyboard-only, no dedicated Basys3 IO.
--  - sw14 = PmodAMP2 shutdown, sw15 = PmodAMP2 gain select. No dip switches
--    are exposed by the core.
--  - ps2_dat/ps2_clk are wired to the onboard USB-HID host (C17/B17), the
--    project default since 2026-09 (root PORTING_SPEC.md §3). The original
--    keyboard clock (clock_kbd, clock_40/10 via clock_div) was ~2 MHz and
--    shared with the PWM audio gate (clock_div = "0000") -- below the
--    onboard USB-HID port's >= 6 MHz floor, and retargeting clock_div's
--    threshold would also change the audio rate. Added a new, independent
--    clock_div_kbd counter (clock_40/6 = 6.667 MHz) dedicated to clock_kbd
--    only; clock_div and the PWM gate it drives are unchanged (same fix as
--    the sibling Kick-Midway-MCR port).
--  - btnC = reset.
--  - No led port: the pristine top's ledr assignment is dead code (commented
--    out, references an undefined signal, never actually driven), matching
--    every other machine's convention of leaving led unconstrained when the
--    core doesn't drive it.
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;

entity solar_fox_basys3 is
port(
 clk            : in  std_logic;
 sw             : in  std_logic_vector(15 downto 0);
 btnC           : in  std_logic;  -- reset
 btnU           : in  std_logic;  -- coin-in (coin1)
 btnD           : in  std_logic;  -- reserved, unused
 btnL           : in  std_logic;  -- start/fast (fast1)
 btnR           : in  std_logic;  -- reserved, unused

 JA             : in  std_logic_vector(4 downto 0);  -- joystick
 ps2_dat        : in  std_logic;
 ps2_clk        : in  std_logic;

 O_PMODAMP2_AIN : out std_logic;
 O_PMODAMP2_GAIN: out std_logic;
 O_PMODAMP2_SHUTD: out std_logic;

 vga_r : out std_logic_vector(3 downto 0);
 vga_g : out std_logic_vector(3 downto 0);
 vga_b : out std_logic_vector(3 downto 0);
 vga_hs: out std_logic;
 vga_vs: out std_logic
);
end solar_fox_basys3;

architecture struct of solar_fox_basys3 is

 signal clock_40  : std_logic;
 signal clock_kbd : std_logic;
 signal reset     : std_logic;

 signal clock_div : std_logic_vector(3 downto 0);
 signal clock_div_kbd : std_logic_vector(1 downto 0);

 signal r         : std_logic_vector(3 downto 0);
 signal g         : std_logic_vector(3 downto 0);
 signal b         : std_logic_vector(3 downto 0);
 signal hsync     : std_logic;
 signal vsync     : std_logic;
 signal csync     : std_logic;
 signal blankn    : std_logic;
 signal tv15Khz_mode : std_logic;

 signal audio_l           : std_logic_vector(15 downto 0);
 signal audio_r           : std_logic_vector(15 downto 0);
 signal pwm_accumulator_l : std_logic_vector(17 downto 0);
 signal pwm_accumulator_r : std_logic_vector(17 downto 0);

 signal kbd_intr      : std_logic;
 signal kbd_scancode  : std_logic_vector(7 downto 0);
 signal kbd_joy        : std_logic_vector(8 downto 0);
 signal joy_BBBBFRLDU  : std_logic_vector(8 downto 0);
 signal fn_pulse_kbd   : std_logic_vector(7 downto 0);
 signal fn_pulse       : std_logic_vector(7 downto 0);
 signal fn_toggle      : std_logic_vector(7 downto 0);

begin

reset <= btnC;

tv15Khz_mode <= not fn_toggle(7); -- F8

-- Clock 40MHz for Solar Fox core and sound board (from 100 MHz)
clocks : entity work.clk_wiz_0
port map(
 clk_in1  => clk,
 clk_out1 => clock_40,
 locked   => open
);

-- Solar Fox
solarfox_inst : entity work.solarfox
port map(
 clock_40     => clock_40,
 reset        => reset,

 tv15Khz_mode => tv15Khz_mode,
 video_r      => r,
 video_g      => g,
 video_b      => b,
 video_csync  => csync,
 video_blankn => blankn,
 video_hs     => hsync,
 video_vs     => vsync,

 separate_audio => fn_toggle(4), -- F5
 audio_out_l    => audio_l,
 audio_out_r    => audio_r,

 coin1          => fn_pulse(0), -- F1 or JA fire+up or btnU
 coin2          => '0',
 fast1          => fn_pulse(1), -- F2 or JA fire+left or btnL
 fast2          => '0',

 fire1          => joy_BBBBFRLDU(4), -- space or JA7
 fire2          => '0',

 up1            => joy_BBBBFRLDU(0), -- up
 down1          => joy_BBBBFRLDU(1), -- down
 left1          => joy_BBBBFRLDU(2), -- left
 right1         => joy_BBBBFRLDU(3), -- right

 up2            => '0',
 down2          => '0',
 left2          => '0',
 right2         => '0',

 service        => fn_toggle(6), -- F7 (allow machine settings access)

 dbg_cpu_addr => open
);

-- OR-merge the joystick on JA with the PS/2 keyboard joystick, and the JA
-- fire+up (coin) / fire+left (fast) combos and btnU/btnL (root
-- PORTING_SPEC.md's generic default: coin-in = btnU, 1P start = btnL) with
-- the keyboard's F1/F2. JA physical map: JA1=right, JA2=left, JA3=down,
-- JA4=up, JA7=fire, i.e. JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up,
-- JA(4)=fire. JA is active-low (pressed shorts to ground); invert so a
-- press reads active-high, matching the core's active-high input boundary
-- and the keyboard path. btnU/btnL are active-high (Basys3 board
-- pull-down, same convention as btnC).
joy_BBBBFRLDU(0) <= kbd_joy(0) or not JA(3);  -- up    (JA4)
joy_BBBBFRLDU(1) <= kbd_joy(1) or not JA(2);  -- down  (JA3)
joy_BBBBFRLDU(2) <= kbd_joy(2) or not JA(1);  -- left  (JA2)
joy_BBBBFRLDU(3) <= kbd_joy(3) or not JA(0);  -- right (JA1)
joy_BBBBFRLDU(4) <= kbd_joy(4) or not JA(4);  -- fire  (JA7)
joy_BBBBFRLDU(8 downto 5) <= kbd_joy(8 downto 5);

fn_pulse(0) <= fn_pulse_kbd(0) or (not JA(4) and not JA(3)) or btnU; -- coin = F1 or fire+up or btnU
fn_pulse(1) <= fn_pulse_kbd(1) or (not JA(4) and not JA(1)) or btnL; -- fast = F2 or fire+left or btnL
fn_pulse(7 downto 2) <= fn_pulse_kbd(7 downto 2);

-- adapt video to 4bits/color only and blank (core generates progressive
-- 31 kHz / interlaced 15 kHz timing natively via tv15Khz_mode; no external
-- scandoubler)
vga_r <= r when blankn = '1' else "0000";
vga_g <= g when blankn = '1' else "0000";
vga_b <= b when blankn = '1' else "0000";

vga_hs <= csync when tv15Khz_mode = '1' else hsync;
vga_vs <= '1'   when tv15Khz_mode = '1' else vsync;

-- clock_div: unchanged, still gates the PWM accumulator below (clock_div = "0000").
process (reset, clock_40)
begin
	if reset='1' then
		clock_div <= (others => '0');
	else
		if rising_edge(clock_40) then
			if clock_div = "1001" then
				clock_div <= (others => '0');
			else
				clock_div <= clock_div + '1';
			end if;
		end if;
	end if;
end process;

-- Independent keyboard clock divider (clock_40 / 6 = 6.667 MHz), dedicated
-- to clock_kbd only -- see header comment above.
process (reset, clock_40)
begin
	if reset='1' then
		clock_div_kbd <= (others => '0');
		clock_kbd     <= '0';
	else
		if rising_edge(clock_40) then
			if clock_div_kbd = "10" then
				clock_div_kbd <= (others => '0');
				clock_kbd     <= not clock_kbd;
			else
				clock_div_kbd <= clock_div_kbd + '1';
			end if;
		end if;
	end if;
end process;

keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clock_kbd, -- synchronous clock with core
  kbd_clk   => ps2_clk,
  kbd_dat   => ps2_dat,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- translate scancode to joystick / function keys
joystick : entity work.kbd_joystick
port map (
  clk           => clock_kbd, -- synchronous clock with core
  kbdint        => kbd_intr,
  kbdscancode   => std_logic_vector(kbd_scancode),
  joy_BBBBFRLDU => kbd_joy,
  fn_pulse      => fn_pulse_kbd,
  fn_toggle     => fn_toggle
);

-- pwm sound output (stereo in the core; PmodAMP2 is mono, so only the left
-- channel is output -- same choice as the sibling Kick port)
process(clock_40)
begin
  if rising_edge(clock_40) then

		if clock_div = "0000" then
			pwm_accumulator_l  <=  ('0'&pwm_accumulator_l(16 downto 0)) + ('0'&audio_l&'0');
			pwm_accumulator_r  <=  ('0'&pwm_accumulator_r(16 downto 0)) + ('0'&audio_r&'0');
		end if;

  end if;
end process;

O_PMODAMP2_AIN   <= pwm_accumulator_l(17);
O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
