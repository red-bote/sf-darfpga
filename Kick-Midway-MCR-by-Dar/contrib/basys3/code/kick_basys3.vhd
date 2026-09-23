---------------------------------------------------------------------------------
-- Basys3 Top level for Kick (Midway MCR) by Dar (darfpga@aol.fr) (22/11/2019)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from kick_de10_lite.vhd (DE10-lite rev 02 22/11/2019):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives a single 40 MHz clock
--    (core + sound board), matching the sibling Tron-by-Dar port
--  - Core generates progressive 31 kHz video natively (tv15Khz_mode); no
--    external scandoubler is imported. F8 toggles 31 kHz VGA / 15 kHz TV.
--  - Atari-style joystick on JA, OR-merged with PS/2 keyboard (JB) for
--    kick/movement. Kick has no directional fire -- the player D pad is a
--    spinner, so LEFT/RIGHT (and SPACE to go faster) drive the on-screen
--    spinner, and UP is the kick button. Note: the upstream DE10-lite header
--    legend says "DOWN = kick" but the code maps the up arrow (kbd_joy bit 0)
--    to the kick input; this port keeps the code behaviour (up = kick).
--  - btnU = coin-in (coin1), btnD = second coin-in (coin2), btnL = P1 start,
--    btnR = P2 start (root PORTING_SPEC.md default mapping); active-high, no
--    board pull-up needed, same convention as btnC. Coin/start come only from
--    these buttons and/or their PS/2 keyboard keys (F1/F2/F3) -- no
--    fire+direction joystick combos. coin2 (tied to '0' upstream) is driven
--    only by btnD, the core exposes no other coin2 source.
--  - Stereo PWM audio in the core; PmodAMP2 (JC) is mono, so O_PMODAMP2_AIN
--    is driven from the left channel only (same choice as Tron).
--  - sw14 = PmodAMP2 shutdown, sw15 = PmodAMP2 gain select. No dip switches
--    are exposed by the core.
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

entity kick_basys3 is
port(
 clk            : in  std_logic;
 sw             : in  std_logic_vector(15 downto 0);
 btnC           : in  std_logic;
 btnU           : in  std_logic;  -- coin-in (coin1)
 btnD           : in  std_logic;  -- second coin-in (coin2)
 btnL           : in  std_logic;  -- P1 start
 btnR           : in  std_logic;  -- P2 start

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
end kick_basys3;

architecture struct of kick_basys3 is

 signal clock_40  : std_logic;
 signal clock_kbd : std_logic;
 signal reset     : std_logic;
 signal coin2_in  : std_logic;

 signal clock_div : std_logic_vector(3 downto 0);

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

 signal ctc_zc_to_2   : std_logic;   -- every ~100 scanlines from kick core
 signal ctc_zc_to_2_r : std_logic;
 signal spin_count    : std_logic_vector(9 downto 0);

 signal dbg_cpu_addr : std_logic_vector(15 downto 0);

begin

reset <= btnC;

tv15Khz_mode <= not fn_toggle(7); -- F8

-- Clock 40MHz for Kick core and sound board (from 100 MHz)
clocks : entity work.clk_wiz_0
port map(
 clk_in1  => clk,
 clk_out1 => clock_40,
 locked   => open
);

-- Kick
kick_inst : entity work.kick
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

 coin1          => fn_pulse(0), -- F1 or btnU
 coin2          => coin2_in,    -- btnD only
 start1         => fn_pulse(1), -- F2 or btnL
 start2         => fn_pulse(2), -- F3 or btnR
 kick           => joy_BBBBFRLDU(0), -- up arrow or JA up
 service        => fn_toggle(6), -- F7 (allow machine settings access)

 ctc_zc_to_2    => ctc_zc_to_2,
 spin_angle     => spin_count(9 downto 6),

 dbg_cpu_addr => dbg_cpu_addr
);

-- OR-merge the Atari-style joystick on JA with the PS/2 keyboard joystick.
-- JA physical map (matches the sibling ports): JA1=right, JA2=left, JA3=down, JA4=up, JA7=fire,
-- i.e. JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up, JA(4)=fire.
-- JA is active-low (pressed shorts to ground); invert so a press reads active-high, matching the
-- core's active-high input boundary and the keyboard path.
joy_BBBBFRLDU(0) <= kbd_joy(0) or not JA(3);                 -- up / kick  (JA4)
joy_BBBBFRLDU(1) <= kbd_joy(1) or not JA(2);                 -- down (JA3, unused by core)
joy_BBBBFRLDU(2) <= kbd_joy(2) or not JA(1);                 -- left -> spin left  (JA2)
joy_BBBBFRLDU(3) <= kbd_joy(3) or not JA(0);                 -- right -> spin right (JA1)
joy_BBBBFRLDU(4) <= kbd_joy(4) or not JA(4);                 -- fire / SPACE (speed up) (JA7)
joy_BBBBFRLDU(8 downto 5) <= kbd_joy(8 downto 5);            -- unused by the kick core

-- Coin/start come only from the default buttons (btnU/L/R) OR-merged with the
-- keyboard's F1/F2/F3 (fn_pulse_kbd). No fire+direction joystick combos.
fn_pulse(0) <= fn_pulse_kbd(0) or btnU; -- coin1 = F1 or btnU
fn_pulse(1) <= fn_pulse_kbd(1) or btnL; -- start1 = F2 or btnL
fn_pulse(2) <= fn_pulse_kbd(2) or btnR; -- start2 = F3 or btnR
fn_pulse(7 downto 3) <= fn_pulse_kbd(7 downto 3);

-- coin2: no keyboard or JA path maps to a second coin input, so btnD is the only source
coin2_in <= btnD;

-- spin angle decoder simulation (verbatim from the DE10-lite top; LEFT/RIGHT spin the
-- spinner between the core's ctc_zc_to_2 strokes, SPACE = joy_BBBBFRLDU(4) goes faster)
process (clock_40)
begin
	if rising_edge(clock_40) then
		ctc_zc_to_2_r <= ctc_zc_to_2;

		if ctc_zc_to_2_r ='0' and ctc_zc_to_2 = '1' then
			if joy_BBBBFRLDU(4) = '0' then  -- normal speed
				if joy_BBBBFRLDU(2) = '1' then spin_count <= spin_count - 40; end if; -- left
				if joy_BBBBFRLDU(3) = '1' then spin_count <= spin_count + 40; end if; -- right
			else
				if joy_BBBBFRLDU(2) = '1' then spin_count <= spin_count - 55; end if;
				if joy_BBBBFRLDU(3) = '1' then spin_count <= spin_count + 55; end if;
			end if;
		end if;

	end if;
end process;

-- adapt video to 4bits/color only and blank (core generates progressive 31 kHz / interlaced
-- 15 kHz timing natively via tv15Khz_mode; no external scandoubler)
vga_r <= r when blankn = '1' else "0000";
vga_g <= g when blankn = '1' else "0000";
vga_b <= b when blankn = '1' else "0000";

vga_hs <= csync when tv15Khz_mode = '1' else hsync;
vga_vs <= '1'   when tv15Khz_mode = '1' else vsync;

-- get scancode from keyboard
process (reset, clock_40)
begin
	if reset='1' then
		clock_div <= (others => '0');
		clock_kbd  <= '0';
	else
		if rising_edge(clock_40) then
			if clock_div = "1001" then
				clock_div <= (others => '0');
				clock_kbd  <= not clock_kbd;
			else
				clock_div <= clock_div + '1';
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

-- translate scancode to joystick
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
-- channel is output -- same choice as the sibling Tron port)
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
