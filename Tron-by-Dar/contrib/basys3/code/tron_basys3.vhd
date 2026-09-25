---------------------------------------------------------------------------------
-- Basys3 Top level for Tron (Midway MCR) by Dar (darfpga@aol.fr) (19/10/2019)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from tron_de10_lite.vhd (DE10-lite rev 03 22/11/2019):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives a single 40 MHz clock
--    (core + sound board), matching the sibling Kick-Midway-MCR-by-Dar port
--  - Core generates progressive 31 kHz video natively (tv15Khz_mode); no
--    external scandoubler is imported. F8 toggles 31 kHz VGA / 15 kHz TV.
--  - Atari-style joystick on JA, OR-merged with PS/2 keyboard (JB) for
--    movement/fire and coin/start (fire+direction combos); the spinner
--    (f/g/t keys: spin left/right/fast) stays keyboard-only, same as the
--    pristine DE10-lite top -- no JA equivalent for the analog "angle" input.
--  - Stereo PWM audio in the core; PmodAMP2 (JC) is mono, so O_PMODAMP2_AIN
--    is driven from the left channel only (same choice as Kick).
--  - sw14 = PmodAMP2 shutdown, sw15 = PmodAMP2 gain select. No dip switches
--    are exposed by the core (none on the DE10-lite top either).
--  - ps2_dat/ps2_clk are wired to the onboard USB-HID host (C17/B17), the
--    project default since 2026-09 (root PORTING_SPEC.md §3). The original
--    keyboard clock (clock_kbd, clock_40/10 via clock_div) was ~2 MHz and
--    shared with the PWM audio gate (clock_div = "0000") -- below the
--    onboard USB-HID port's >= 6 MHz floor, and retargeting clock_div's
--    threshold would also change the audio rate. Added a new, independent
--    clock_div_kbd counter (clock_40/6 = 6.667 MHz) dedicated to clock_kbd
--    only; clock_div and the PWM gate it drives are unchanged (same fix as
--    the sibling Kick-Midway-MCR/Solar-Fox ports).
--  - btnC = reset
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

entity tron_basys3 is
port(
 clk            : in  std_logic;
 sw             : in  std_logic_vector(15 downto 0);
 btnC           : in  std_logic;

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
end tron_basys3;

architecture struct of tron_basys3 is

 signal clock_40  : std_logic;
 signal clock_kbd : std_logic;
 signal reset     : std_logic;

 signal clock_div : std_logic_vector(3 downto 0);
 signal clock_div_kbd : std_logic_vector(1 downto 0);

 signal r         : std_logic_vector(2 downto 0);
 signal g         : std_logic_vector(2 downto 0);
 signal b         : std_logic_vector(2 downto 0);
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

 signal vsync_r        : std_logic;
 signal spin_count     : std_logic_vector(9 downto 0);

 signal dbg_cpu_addr : std_logic_vector(15 downto 0);

begin

reset <= btnC;

tv15Khz_mode <= not fn_toggle(7); -- F8

-- Clock 40MHz for Tron core and sound board (from 100 MHz)
clocks : entity work.clk_wiz_0
port map(
 clk_in1  => clk,
 clk_out1 => clock_40,
 locked   => open
);

-- Tron
tron_inst : entity work.tron
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

 separate_audio => fn_toggle(4), -- F5
 audio_out_l    => audio_l,
 audio_out_r    => audio_r,

 coin1          => fn_pulse(0), -- F1 or JA fire+up
 coin2          => '0',
 start1         => fn_pulse(1), -- F2 or JA fire+left
 start2         => fn_pulse(2), -- F3 or JA fire+right

 left           => joy_BBBBFRLDU(2), -- left
 right          => joy_BBBBFRLDU(3), -- right
 up             => joy_BBBBFRLDU(0), -- up
 down           => joy_BBBBFRLDU(1), -- down
 fire           => joy_BBBBFRLDU(4), -- space
 angle          => spin_count(9 downto 3),

 left_c         => '0',
 right_c        => '0',
 up_c           => '0',
 down_c         => '0',
 fire_c         => '0',
 angle_c        => "0000000",

 coin_meters    => '1',
 cocktail       => '0', -- cocktail mode not supported (matches the DE10-lite top)
 continue       => fn_toggle(5), -- F6 -- allow continue
 service        => fn_toggle(4), -- F5 -- (allow machine settings access)

 dbg_cpu_addr => dbg_cpu_addr
);

-- OR-merge the Atari-style joystick on JA with the PS/2 keyboard joystick.
-- JA physical map (matches the sibling ports): JA1=right, JA2=left, JA3=down, JA4=up, JA7=fire,
-- i.e. JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up, JA(4)=fire.
-- JA is active-low (pressed shorts to ground); invert so a press reads active-high, matching the
-- core's active-high input boundary and the keyboard path. The spinner bits (5..8: g/f/t spin
-- left/right/fast) have no JA equivalent and stay keyboard-only, same as the DE10-lite top.
joy_BBBBFRLDU(0) <= kbd_joy(0) or not JA(3);                 -- up    (JA4)
joy_BBBBFRLDU(1) <= kbd_joy(1) or not JA(2);                 -- down  (JA3)
joy_BBBBFRLDU(2) <= kbd_joy(2) or not JA(1);                 -- left  (JA2)
joy_BBBBFRLDU(3) <= kbd_joy(3) or not JA(0);                 -- right (JA1)
joy_BBBBFRLDU(4) <= kbd_joy(4) or not JA(4);                 -- fire  (JA7)
joy_BBBBFRLDU(8 downto 5) <= kbd_joy(8 downto 5);             -- spin: keyboard-only

-- Coin/start reachable from the joystick via fire+direction combos, OR-merged with the
-- keyboard's F1/F2/F3 (fn_pulse_kbd), same convention as the sibling Pooyan/Time-Pilot ports.
fn_pulse(0) <= fn_pulse_kbd(0) or (not JA(4) and not JA(3)); -- coin   = fire+up
fn_pulse(1) <= fn_pulse_kbd(1) or (not JA(4) and not JA(1)); -- start1 = fire+left
fn_pulse(2) <= fn_pulse_kbd(2) or (not JA(4) and not JA(0)); -- start2 = fire+right
fn_pulse(7 downto 3) <= fn_pulse_kbd(7 downto 3);

-- spin angle decoder simulation (verbatim from the DE10-lite top; keyboard-only, unaffected by
-- the JA merge above since bits 5..8 pass through unmodified)
process (clock_40)
begin
	if rising_edge(clock_40) then
		vsync_r <= vsync;

		if vsync_r ='0' and vsync = '1' then
			if joy_BBBBFRLDU(7) = '0' then  -- 't' -- speed up spinner
				if joy_BBBBFRLDU(6) = '1' then spin_count <= spin_count - 25; end if; -- 'f'
				if joy_BBBBFRLDU(5) = '1' then spin_count <= spin_count + 25; end if; -- 'g'
			else
				if joy_BBBBFRLDU(6) = '1' then spin_count <= spin_count - 35; end if;
				if joy_BBBBFRLDU(5) = '1' then spin_count <= spin_count + 35; end if;
			end if;

		end if;

	end if;
end process;

-- adapt video to 4bits/color only and blank (core generates progressive 31 kHz / interlaced
-- 15 kHz timing natively via tv15Khz_mode; no external scandoubler)
vga_r <= r & '0' when blankn = '1' else "0000";
vga_g <= g & '0' when blankn = '1' else "0000";
vga_b <= b & '0' when blankn = '1' else "0000";

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
  clk       => clock_kbd, -- synchrounous clock with core
  kbd_clk   => ps2_clk,
  kbd_dat   => ps2_dat,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- translate scancode to joystick
joystick : entity work.kbd_joystick
port map (
  clk           => clock_kbd, -- synchrounous clock with core
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
