---------------------------------------------------------------------------------
-- Basys 3 top level for Galaga by Red~Bote, derived from galaga_de10_lite.vhd by
-- Dar (darfpga@aol.fr, http://darfpga.blogspot.fr); see that file for its history.
---------------------------------------------------------------------------------
--
-- v0.1 (10/26/2026) : initial Basys 3 release
--
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthesized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
--
-- Main features:
--  clk_wiz_0 derives clock_36 = 36.864 MHz from 100 MHz; core clock_18 = clock_36/2
--  Joystick on JXADC, OR-merged with the PS/2 keyboard (onboard USB-HID)
--  Inputs synchronized on clock_18; buttons and JXADC fire debounced (14 ms)
--  Mono PWM audio on PmodAMP2 (JA pins 1/2/4); sw15 up = audio off, sw14 up = gain
--  31 kHz VGA via the MiST scandoubler; sw13 = 15 kHz TV (csync on HS)
--  Keyboard: MAME default keys (left/right arrows, Left Ctrl = fire, 1/2 = start,
--  5/6 = coin)
--  btnC = reset, btnU/btnD = coin, btnL/btnR = start
--  DIP: sw12 = b_test (up = test/service mode)
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity galaga_basys3 is
port(
 clk            : in  std_logic;
 sw             : in  std_logic_vector(15 downto 0);
 btnC           : in  std_logic;
 btnU           : in  std_logic;  -- coin
 btnD           : in  std_logic;  -- coin
 btnL           : in  std_logic;  -- 1P start
 btnR           : in  std_logic;  -- 2P start

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
end galaga_basys3;

architecture struct of galaga_basys3 is

 signal clock_36 : std_logic;
 signal clock_18 : std_logic;
 signal clock_6  : std_logic;
 signal clock_12 : std_logic;
 signal slot     : std_logic_vector(2 downto 0);
 signal reset    : std_logic;
 signal mmcm_locked : std_logic;

 signal r         : std_logic_vector(2 downto 0);
 signal g         : std_logic_vector(2 downto 0);
 signal b         : std_logic_vector(1 downto 0);
 signal csync     : std_logic;
 signal blankn    : std_logic;
 signal hsync     : std_logic;
 signal vsync     : std_logic;

 signal audio           : std_logic_vector(9 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);

 signal vga_r_i  : std_logic_vector(5 downto 0);
 signal vga_g_i  : std_logic_vector(5 downto 0);
 signal vga_b_i  : std_logic_vector(5 downto 0);
 signal vga_r_o  : std_logic_vector(5 downto 0);
 signal vga_g_o  : std_logic_vector(5 downto 0);
 signal vga_b_o  : std_logic_vector(5 downto 0);
 signal hsync_o  : std_logic;
 signal vsync_o  : std_logic;

 signal kbd_intr     : std_logic;
 signal kbd_scancode : std_logic_vector(7 downto 0);
 signal kbd_rel      : std_logic := '0';
 signal kbd_joy      : std_logic_vector(7 downto 0) := (others => '0');
 signal joyPCFRLDU   : std_logic_vector(7 downto 0);

 component scandoubler
     port (
         clk_sys   : in  std_logic;
         scanlines : in  std_logic_vector (1 downto 0);
         ce_x1     : in  std_logic;
         ce_x2     : in  std_logic;
         hs_in     : in  std_logic;
         vs_in     : in  std_logic;
         r_in      : in  std_logic_vector (5 downto 0);
         g_in      : in  std_logic_vector (5 downto 0);
         b_in      : in  std_logic_vector (5 downto 0);
         hs_out    : out std_logic;
         vs_out    : out std_logic;
         r_out     : out std_logic_vector (5 downto 0);
         g_out     : out std_logic_vector (5 downto 0);
         b_out     : out std_logic_vector (5 downto 0)
     );
 end component;

 -- 2-FF synchronizers on clock_18 for PS/2, JXADC and buttons.
 signal ps2_clk_meta, ps2_clk_s : std_logic := '1';
 signal ps2_dat_meta, ps2_dat_s : std_logic := '1';
 signal jxadc_meta, jxadc_s     : std_logic_vector(4 downto 0) := (others => '1');
 signal btn_meta, btn_s         : std_logic_vector(3 downto 0) := (others => '0');  -- U, D, L, R
 attribute ASYNC_REG : string;
 attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
 attribute ASYNC_REG of jxadc_meta, jxadc_s, btn_meta, btn_s : signal is "TRUE";

 signal db_in   : std_logic_vector(4 downto 0);
 signal btn_db  : std_logic_vector(4 downto 0) := (others => '0');
 type btn_cnt_t is array (0 to 4) of unsigned(17 downto 0);
 signal btn_cnt : btn_cnt_t := (others => (others => '0'));
 -- DIP switch on spare board switches (PORTING_SPEC.md 3.2): switch down = DE10
 -- default, switch up inverts the bit.
 -- b_test on sw12 (DE10 default '1' = off).
 constant B_TEST_DEFAULT : std_logic := '1';
 signal b_test_in : std_logic;
begin

b_test_in <= B_TEST_DEFAULT xor sw(12);  -- test/service mode on sw12

reset <= btnC or not mmcm_locked;  -- core held in reset until the MMCM locks (CLOCKING_SPEC.md 6)

-- Clock 36.864 MHz (signal clock_36) for the core clock chain and the scan
-- doubler's clock divider.
clocks : entity work.clk_wiz_0
port map(
 clk_in1  => clk,
 clk_out1 => clock_36,
 reset    => btnC,
 locked   => mmcm_locked
);

-- Halve clock_36 to clock_18 for the galaga core (36/2).
process (reset, clock_36)
begin
	if reset='1' then
		clock_18  <= '0';
	else
		if rising_edge(clock_36) then
				clock_18  <= not clock_18;
		end if;
	end if;
end process;

-- Galaga
galaga : entity work.galaga
port map(
 clock_18     => clock_18,
 reset        => reset,

 video_r      => r,
 video_g      => g,
 video_b      => b,
 video_csync  => csync,
 video_blankn => blankn,
 video_hs     => hsync,
 video_vs     => vsync,
 audio        => audio,

 b_test       => b_test_in,  -- sw12 (up = test/service mode)
 b_svce       => '1',

 coin         => joyPCFRLDU(7),
 start1       => joyPCFRLDU(5),
 left1        => joyPCFRLDU(2),
 right1       => joyPCFRLDU(3),
 fire1        => joyPCFRLDU(4),
 start2       => joyPCFRLDU(6),
 left2        => joyPCFRLDU(2),
 right2       => joyPCFRLDU(3),
 fire2        => joyPCFRLDU(4)
);

-- 31 kHz VGA via the imported MiST scandoubler.
-- Pad the core's 3/3/2-bit RGB to 6 bits by MSB replication; force black during blank.
vga_r_i <= r & r     when blankn = '1' else "000000";
vga_g_i <= g & g     when blankn = '1' else "000000";
vga_b_i <= b & b & b when blankn = '1' else "000000";

-- Derive the scandoubler clocks: clock_12 (clk_sys) and clock_6 (ce_x1) from a
-- mod-6 counter clocked by clock_36 (see PORTING_SPEC 5.1).
process (clock_36)
begin
    if rising_edge(clock_36) then
        clock_12 <= '0';
        if slot = "101" then
            slot <= (others => '0');
        else
            slot <= std_logic_vector(unsigned(slot) + 1);
        end if;
        if slot = "100" or slot = "001" then
            clock_6 <= not clock_6;
        end if;
        if slot = "100" or slot = "001" then
            clock_12 <= '1';
        end if;
    end if;
end process;

scandoubler_inst : scandoubler
port map(
 clk_sys   => clock_12,
 scanlines => "00",
 ce_x1     => clock_6,
 ce_x2     => '1',
 hs_in     => hsync,
 vs_in     => vsync,
 r_in      => vga_r_i,
 g_in      => vga_g_i,
 b_in      => vga_b_i,
 hs_out    => hsync_o,
 vs_out    => vsync_o,
 r_out     => vga_r_o,
 g_out     => vga_g_o,
 b_out     => vga_b_o
);

-- Display mode switch via sw(13):
--   0 = 31 kHz VGA (scan-doubled 6-bit RGB adapted to 4bits/color)
--   1 = 15 kHz TV  (native core RGB padded to 4bits, composite sync on HS,
--       VS held high -- requires a 15 kHz RGB monitor or RGB->composite converter)
vga_r <= r & '0'             when sw(13) = '1' and blankn = '1' else
         vga_r_o(5 downto 2) when sw(13) = '0'                  else
         "0000";
vga_g <= g & '0'             when sw(13) = '1' and blankn = '1' else
         vga_g_o(5 downto 2) when sw(13) = '0'                  else
         "0000";
vga_b <= b & "00"            when sw(13) = '1' and blankn = '1' else
         vga_b_o(5 downto 2) when sw(13) = '0'                  else
         "0000";
vga_hs <= csync   when sw(13) = '1' else hsync_o;
vga_vs <= '1'     when sw(13) = '1' else vsync_o;

-- Input synchronizers (2-FF) into clock_18
process (clock_18)
begin
	if rising_edge(clock_18) then
		ps2_clk_meta <= ps2_clk;  ps2_clk_s <= ps2_clk_meta;
		ps2_dat_meta <= ps2_dat;  ps2_dat_s <= ps2_dat_meta;
		jxadc_meta   <= JXADC;    jxadc_s   <= jxadc_meta;
		btn_meta     <= btnU & btnD & btnL & btnR;
		btn_s        <= btn_meta;
	end if;
end process;

-- get scancode from keyboard (on clock_18, the core clock)
keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clock_18,
  kbd_clk   => ps2_clk_s,
  kbd_dat   => ps2_dat_s,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- translate scancode to joystick (MAME default keys, PS/2 set 2 codes), replaces
-- kbd_joystick. F0 marks a release; E0 is ignored (keypad 4/6 alias the arrows,
-- Right Ctrl aliases Left Ctrl), PORTING_SPEC.md 3.1.
-- kbd_joy bit order matches joyPCFRLDU below: 5 = start 1, 6 = start 2, 7 = coin.
process (clock_18)
begin
	if rising_edge(clock_18) then
		if kbd_intr = '1' then
			if kbd_scancode = x"F0" then
				kbd_rel <= '1';
			elsif kbd_scancode /= x"E0" then
				kbd_rel <= '0';
				if kbd_scancode = x"6B" then kbd_joy(2) <= not kbd_rel; end if; -- left arrow
				if kbd_scancode = x"74" then kbd_joy(3) <= not kbd_rel; end if; -- right arrow
				if kbd_scancode = x"14" then kbd_joy(4) <= not kbd_rel; end if; -- left ctrl: fire
				if kbd_scancode = x"16" then kbd_joy(5) <= not kbd_rel; end if; -- 1: start 1
				if kbd_scancode = x"1E" then kbd_joy(6) <= not kbd_rel; end if; -- 2: start 2
				if kbd_scancode = x"2E" or kbd_scancode = x"36" then kbd_joy(7) <= not kbd_rel; end if; -- 5 / 6: coin
			end if;
		end if;
	end if;
end process;

-- OR-merge the Atari-style joystick on JXADC with the PS/2 keyboard joystick.
-- JXADC physical map: JXADC1=right, JXADC2=left, JXADC3=down, JXADC4=up, JXADC7=fire,
-- i.e. JXADC(0)=right, JXADC(1)=left, JXADC(2)=down, JXADC(3)=up, JXADC(4)=fire.
-- JXADC is active-low (pressed shorts to ground); invert so a press reads active-high,
-- matching the core's active-high input boundary and the keyboard path.
-- Debounce: btn_db follows its input after 2**18 stable clock_18 cycles (14.2 ms).
-- The core edge-detects coin, so bounce counted extra coins; fire bounced on release.
-- Clocked on clock_18, the core clock. Index 4 = JXADC fire, 3..0 = btnU/D/L/R.
db_in <= (not jxadc_s(4)) & btn_s;
process(clock_18)
begin
  if rising_edge(clock_18) then
    for i in 0 to 4 loop
      if db_in(i) = btn_db(i) then
        btn_cnt(i) <= (others => '0');
      elsif btn_cnt(i) = (btn_cnt(i)'range => '1') then
        btn_db(i)  <= db_in(i);
        btn_cnt(i) <= (others => '0');
      else
        btn_cnt(i) <= btn_cnt(i) + 1;
      end if;
    end loop;
  end if;
end process;

-- Galaga core takes left/right/fire only (bits 2/3/4); coin=7, start1=5, start2=6.
-- Coin/start come from the keyboard and btnU/btnD/btnL/btnR.
joyPCFRLDU(0) <= '0';
joyPCFRLDU(1) <= '0';
joyPCFRLDU(2) <= kbd_joy(2) or not jxadc_s(1);               -- left  (JXADC2)
joyPCFRLDU(3) <= kbd_joy(3) or not jxadc_s(0);               -- right (JXADC1)
joyPCFRLDU(4) <= kbd_joy(4) or btn_db(4);                    -- fire  (JXADC7, debounced)
joyPCFRLDU(5) <= kbd_joy(5) or btn_db(1);                    -- start1 = btnL
joyPCFRLDU(6) <= kbd_joy(6) or btn_db(0);                    -- start2 = btnR
joyPCFRLDU(7) <= kbd_joy(7) or btn_db(3) or btn_db(2);       -- coin   = btnU / btnD

-- pwm sound output
process(clock_18)
begin
  if rising_edge(clock_18) then
    pwm_accumulator  <=  std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned(audio & "000"));
  end if;
end process;

O_PMODAMP2_AIN   <= pwm_accumulator(12);
O_PMODAMP2_SHUTD <= not sw(15); -- sw15 up = amp shut down (audio disabled)
O_PMODAMP2_GAIN  <= not sw(14); -- sw14 up = gain active (GAIN active low)

end struct;
