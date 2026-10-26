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
--    external scandoubler is imported. sw(13) selects 31 kHz VGA (0) /
--    15 kHz TV (1) -- changed 2026-09-29 from the pristine core's F8
--    keyboard toggle to match this repo's sw(13) convention used by
--    Bagman/Berzerk/Defender/etc (no F8 toggle needed).
--  - Keyboard decoded in this wrapper, MAME default keys (2026-10-20, replaces
--    kbd_joystick; F0 = release, E0 ignored, sf-darfpga PORTING_SPEC.md 3.1),
--    mapping as the hardware-verified rb-fpga/rework Kick port:
--    Left/Right = spin, Left Alt = spin faster, Left Ctrl = kick,
--    1/2 = start, 5/6 = coin 1/2, F2 = service toggle.
--  - Atari-style joystick on JXADC (active low): JXADC1/2 = spin right/left,
--    JXADC4 = spin faster, JXADC7 = kick.
--  - btnU = coin 1, btnD = coin 2, btnL = P1 start, btnR = P2 start, btnC = reset.
--  - PS/2, JXADC and buttons pass 2-FF synchronizers on clock_40; keyboard on
--    clock_40 (2026-10-20, as rework; the former clock_40/6 clock_kbd is removed).
--  - Stereo PWM audio in the core; PmodAMP2 (JA pins 1/2/4) is mono, so O_PMODAMP2_AIN
--    is driven from the left channel only, separate_audio = '0' (mixed).
--  - sw15 up = audio disabled, sw14 up = PmodAMP2 gain. No dip switches
--    are exposed by the core.
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

 JXADC             : in  std_logic_vector(4 downto 0);  -- joystick
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
 signal reset     : std_logic;
 signal mmcm_locked : std_logic;

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

 -- 2-FF synchronizers (clock_40) for the asynchronous inputs
 signal ps2_clk_meta, ps2_clk_s : std_logic := '1';
 signal ps2_dat_meta, ps2_dat_s : std_logic := '1';
 signal jxadc_meta, jxadc_s     : std_logic_vector(4 downto 0) := (others => '1');
 signal btn_meta, btn_s         : std_logic_vector(3 downto 0) := (others => '0'); -- U, D, L, R
 attribute ASYNC_REG : string;
 attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
 attribute ASYNC_REG of jxadc_meta, jxadc_s, btn_meta, btn_s : signal is "TRUE";

 signal kbd_intr      : std_logic;
 signal kbd_scancode  : std_logic_vector(7 downto 0);
 signal kbd_rel       : std_logic := '0';
 -- kbd_key : 0 up, 1 down, 2 left, 3 right, 4 left ctrl, 5 left alt,
 --           6 '1', 7 '2', 8 '5', 9 '6', 10 F2
 signal kbd_key       : std_logic_vector(10 downto 0) := (others => '0');
 signal kbd_f2_r      : std_logic := '0';
 signal service       : std_logic := '0'; -- toggled by F2
 signal joy_BBBBFRLDU : std_logic_vector(8 downto 0);
 signal coin1_in      : std_logic;
 signal coin2_in      : std_logic;
 signal start1_in     : std_logic;
 signal start2_in     : std_logic;
 signal kick_in       : std_logic;

 signal ctc_zc_to_2   : std_logic;   -- every ~100 scanlines from kick core
 signal ctc_zc_to_2_r : std_logic;
 signal spin_count    : std_logic_vector(9 downto 0);

 signal dbg_cpu_addr : std_logic_vector(15 downto 0);

begin

reset <= btnC or not mmcm_locked;  -- core held in reset until the MMCM locks (sf-darfpga/CLOCKING_SPEC.md section 6)

tv15Khz_mode <= sw(13); -- 0 = 31 kHz VGA, 1 = 15 kHz TV

-- Clock 40MHz for Kick core and sound board (from 100 MHz)
clocks : entity work.clk_wiz_0
port map(
 clk_in1  => clk,
 clk_out1 => clock_40,
 reset    => btnC,
 locked   => mmcm_locked
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

 separate_audio => '0', -- mixed : mono amp on the left channel
 audio_out_l    => audio_l,
 audio_out_r    => audio_r,

 coin1          => coin1_in,  -- 5 or btnU
 coin2          => coin2_in,  -- 6 or btnD
 start1         => start1_in, -- 1 or btnL
 start2         => start2_in, -- 2 or btnR
 kick           => kick_in,   -- left ctrl or JXADC7
 service        => service,   -- F2 toggle (allow machine settings access)

 ctc_zc_to_2    => ctc_zc_to_2,
 spin_angle     => spin_count(9 downto 6),

 dbg_cpu_addr => dbg_cpu_addr
);

-- merge keyboard, buttons and JXADC joystick (active low, inverted).
-- JXADC(0)=JXADC1, JXADC(1)=JXADC2, JXADC(3)=JXADC4, JXADC(4)=JXADC7.
coin1_in  <= kbd_key(8) or btn_s(3); -- 5 or btnU
coin2_in  <= kbd_key(9) or btn_s(2); -- 6 or btnD
start1_in <= kbd_key(6) or btn_s(1); -- 1 or btnL
start2_in <= kbd_key(7) or btn_s(0); -- 2 or btnR
kick_in   <= kbd_key(4) or not jxadc_s(4); -- left ctrl or JXADC7
joy_BBBBFRLDU(0) <= '0';
joy_BBBBFRLDU(1) <= '0';
joy_BBBBFRLDU(2) <= kbd_key(2) or not jxadc_s(1); -- spin left  (JXADC2)
joy_BBBBFRLDU(3) <= kbd_key(3) or not jxadc_s(0); -- spin right (JXADC1)
joy_BBBBFRLDU(4) <= kbd_key(5) or not jxadc_s(3); -- spin faster : left alt (JXADC4)
joy_BBBBFRLDU(8 downto 5) <= "0000";

-- spin angle decoder simulation (verbatim from the DE10-lite top; LEFT/RIGHT spin the
-- spinner between the core's ctc_zc_to_2 strokes, joy_BBBBFRLDU(4) goes faster)
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

-- synchronize asynchronous inputs to the core clock
process (clock_40)
begin
	if rising_edge(clock_40) then
		ps2_clk_meta <= ps2_clk;      ps2_clk_s <= ps2_clk_meta;
		ps2_dat_meta <= ps2_dat;      ps2_dat_s <= ps2_dat_meta;
		jxadc_meta   <= JXADC;        jxadc_s   <= jxadc_meta;
		btn_meta     <= btnU & btnD & btnL & btnR;
		btn_s        <= btn_meta;
	end if;
end process;

keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clock_40, -- synchronous clock with core
  kbd_clk   => ps2_clk_s,
  kbd_dat   => ps2_dat_s,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- translate scancode to keys (MAME default keys, PS/2 set 2 codes), replaces
-- kbd_joystick. F0 marks a release; E0 is ignored (keypad 8/2/4/6 alias the
-- arrows, Right Ctrl/Alt alias Left Ctrl/Alt).
process (clock_40)
begin
	if rising_edge(clock_40) then
		if kbd_intr = '1' then
			if kbd_scancode = x"F0" then
				kbd_rel <= '1';
			elsif kbd_scancode /= x"E0" then
				kbd_rel <= '0';
				if kbd_scancode = x"75" then kbd_key(0)  <= not kbd_rel; end if; -- up arrow
				if kbd_scancode = x"72" then kbd_key(1)  <= not kbd_rel; end if; -- down arrow
				if kbd_scancode = x"6B" then kbd_key(2)  <= not kbd_rel; end if; -- left arrow
				if kbd_scancode = x"74" then kbd_key(3)  <= not kbd_rel; end if; -- right arrow
				if kbd_scancode = x"14" then kbd_key(4)  <= not kbd_rel; end if; -- left ctrl
				if kbd_scancode = x"11" then kbd_key(5)  <= not kbd_rel; end if; -- left alt
				if kbd_scancode = x"16" then kbd_key(6)  <= not kbd_rel; end if; -- 1
				if kbd_scancode = x"1E" then kbd_key(7)  <= not kbd_rel; end if; -- 2
				if kbd_scancode = x"2E" then kbd_key(8)  <= not kbd_rel; end if; -- 5
				if kbd_scancode = x"36" then kbd_key(9)  <= not kbd_rel; end if; -- 6
				if kbd_scancode = x"06" then kbd_key(10) <= not kbd_rel; end if; -- F2
			end if;
		end if;
		-- F2 toggles service mode on press (typematic repeat ignored)
		kbd_f2_r <= kbd_key(10);
		if kbd_f2_r = '0' and kbd_key(10) = '1' then
			service <= not service;
		end if;
	end if;
end process;

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
O_PMODAMP2_SHUTD <= not sw(15); -- sw15 up = amp shut down (audio disabled)
O_PMODAMP2_GAIN  <= not sw(14); -- sw14 up = gain active (GAIN active low)

end struct;
