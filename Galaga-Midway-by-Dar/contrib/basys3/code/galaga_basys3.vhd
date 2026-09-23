---------------------------------------------------------------------------------
-- Basys3 Top level for Galaga (Namco/Midway, 1981) by Dar (darfpga@aol.fr) (06/11/2017)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from galaga_de10_lite.vhd (DE10-lite rev 06/11/2017):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives 36 MHz
--  - Atari-style joystick on JA, OR-merged with PS/2 keyboard (JB)
--  - Mono PWM audio on PmodAMP2 (JC); sw14 = shutdown, sw15 = gain select
--  - 31 kHz VGA on the Basys3 VGA connector via the imported MiST scandoubler;
--    sw(13) switches to 15 kHz TV (native RGB + composite sync on HS)
--  - btnC = reset
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

entity galaga_basys3 is
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
end galaga_basys3;

architecture struct of galaga_basys3 is

 signal clock_36 : std_logic;
 signal clock_18 : std_logic;
 signal clock_9  : std_logic;
 signal clock_6  : std_logic;
 signal clock_12 : std_logic;
 signal slot     : std_logic_vector(2 downto 0);
 signal reset    : std_logic;
 signal mmcm_reset : std_logic := '0';

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
 signal kbd_joy      : std_logic_vector(7 downto 0);
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

begin

reset <= btnC;

-- Clock 36MHz for the core clock chain and the scan doubler's clock divider.
clocks : entity work.clk_wiz_0
port map(
 clk_in1  => clk,
 clk_out1 => clock_36,
 reset    => mmcm_reset,  -- MMCM reset unused (btnC resets the core only)
 locked   => open
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

 b_test       => '1',
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
-- mod-6 counter clocked by clock_36 (see PORTING_SPEC 12.3.3).
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

-- get scancode from keyboard
process (reset, clock_18)
begin
	if reset='1' then
		clock_9  <= '0';
	else
		if rising_edge(clock_18) then
				clock_9  <= not clock_9;
		end if;
	end if;
end process;

keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clock_9, -- synchronous clock with core
  kbd_clk   => ps2_clk,
  kbd_dat   => ps2_dat,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- translate scancode to joystick
joystick : entity work.kbd_joystick
port map (
  clk           => clock_9, -- synchronous clock with core
  kbdint        => kbd_intr,
  kbdscancode   => std_logic_vector(kbd_scancode),
  joyPCFRLDU    => kbd_joy
);

-- OR-merge the Atari-style joystick on JA with the PS/2 keyboard joystick.
-- JA physical map: JA1=right, JA2=left, JA3=down, JA4=up, JA7=fire,
-- i.e. JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up, JA(4)=fire.
-- JA is active-low (pressed shorts to ground); invert so a press reads active-high,
-- matching the core's active-high input boundary and the keyboard path.
-- Galaga core takes left/right/fire only (bits 2/3/4); coin=7, start1=5, start2=6.
-- Coin/start reachable from the joystick via fire+direction combos.
joyPCFRLDU(0) <= '0';
joyPCFRLDU(1) <= '0';
joyPCFRLDU(2) <= kbd_joy(2) or not JA(1);                 -- left  (JA2)
joyPCFRLDU(3) <= kbd_joy(3) or not JA(0);                 -- right (JA1)
joyPCFRLDU(4) <= kbd_joy(4) or not JA(4);                 -- fire  (JA7)
joyPCFRLDU(5) <= kbd_joy(5) or (not JA(4) and not JA(1)); -- start1 = fire+left
joyPCFRLDU(6) <= kbd_joy(6) or (not JA(4) and not JA(0)); -- start2 = fire+right
joyPCFRLDU(7) <= kbd_joy(7) or (not JA(4) and not JA(3)); -- coin   = fire+up

-- pwm sound output
process(clock_18)  -- same clock as the DE10 top drove the PWM accumulator
begin
  if rising_edge(clock_18) then
    pwm_accumulator  <=  std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned(audio & "000"));
  end if;
end process;

O_PMODAMP2_AIN   <= pwm_accumulator(12);
O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
