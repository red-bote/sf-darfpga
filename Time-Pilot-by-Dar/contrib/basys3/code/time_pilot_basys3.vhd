---------------------------------------------------------------------------------
-- Basys3 Top level for Time Pilot by Dar (darfpga@aol.fr) (29/10/2017)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from time_pilot_de10_lite.vhd (DE10-lite rev 00 29/10/2017):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives 12.288 MHz / 14.318 MHz
--  - Atari-style joystick on JA, OR-merged with PS/2 keyboard (JB)
--  - Mono PWM audio on PmodAMP2 (JC); sw14 = shutdown, sw15 = gain select
--  - dip_switch_2 (sound/difficulty/bonus/cocktail/lives) mapped to sw(7:0)
--  - 31 kHz VGA on the Basys3 VGA connector via vga_scandoubler
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

entity time_pilot_basys3 is
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
end time_pilot_basys3;

architecture struct of time_pilot_basys3 is

 signal clock_12  : std_logic;
 signal clock_14  : std_logic;
 signal reset     : std_logic;
 signal clock_6   : std_logic;

 signal r         : std_logic_vector(4 downto 0);
 signal g         : std_logic_vector(4 downto 0);
 signal b         : std_logic_vector(4 downto 0);
 signal csync     : std_logic;
 signal blankn    : std_logic;
 signal hsync     : std_logic;
 signal vsync     : std_logic;

 signal audio           : std_logic_vector(10 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);

 signal vga_ro    : std_logic_vector(5 downto 0);
 signal vga_go    : std_logic_vector(5 downto 0);
 signal vga_bo    : std_logic_vector(5 downto 0);
 signal vga_hs_o  : std_logic;
 signal vga_vs_o  : std_logic;

 signal video_ri  : std_logic_vector(5 downto 0);
 signal video_gi  : std_logic_vector(5 downto 0);
 signal video_bi  : std_logic_vector(5 downto 0);

 signal enable_scandoubling : std_logic;
 signal disable_scaneffect  : std_logic;

 signal kbd_intr      : std_logic;
 signal kbd_scancode  : std_logic_vector(7 downto 0);
 signal kbd_joy       : std_logic_vector(7 downto 0);
 signal joyPCFRLDU    : std_logic_vector(7 downto 0);

 signal dbg_cpu_addr : std_logic_vector(15 downto 0);

begin

reset <= btnC;

-- Clock 12.288MHz for time_pilot core, 14.318MHz for sound_board (from 100 MHz)
clocks : entity work.clk_wiz_0
port map(
 clk_in1  => clk,
 clk_out1 => clock_12,
 clk_out2 => clock_14,
 locked   => open
);

-- Time pilot
time_pilot : entity work.time_pilot
port map(
 clock_12   => clock_12,
 clock_14   => clock_14,
 reset      => reset,

 video_r      => r,
 video_g      => g,
 video_b      => b,
 video_csync  => csync,
 video_blankn => blankn,
 video_hs     => hsync,
 video_vs     => vsync,
 audio_out    => audio,

 dip_switch_1 => X"FF", -- Coinage_B / Coinage_A
 dip_switch_2 => sw(7 downto 0), -- Sound(8)/Difficulty(7-5)/Bonus(4)/Cocktail(3)/lives(2-1)

 start2      => joyPCFRLDU(7),
 start1      => joyPCFRLDU(6),
 coin1       => joyPCFRLDU(5),

 fire1       => joyPCFRLDU(4),
 right1      => joyPCFRLDU(3),
 left1       => joyPCFRLDU(2),
 down1       => joyPCFRLDU(1),
 up1         => joyPCFRLDU(0),

 fire2       => joyPCFRLDU(4),
 right2      => joyPCFRLDU(3),
 left2       => joyPCFRLDU(2),
 down2       => joyPCFRLDU(1),
 up2         => joyPCFRLDU(0),

 dbg_cpu_addr => dbg_cpu_addr
);

-- 31 kHz VGA via scan doubler (canonical import, never modify)
-- clkvideo = clock_6 (halved core clock), clkvga = clock_12 -> ~2x read ratio
-- RGB gated on blankn to keep black during blank (as the DE10 top did)
-- Time Pilot's core outputs 5 bits/color (unlike Pooyan's 3+3+2); pad 1 bit to
-- reach the scandoubler's 6-bit ri/gi/bi.
video_ri <= (r & "0") when blankn = '1' else "000000";
video_gi <= (g & "0") when blankn = '1' else "000000";
video_bi <= (b & "0") when blankn = '1' else "000000";

enable_scandoubling <= '1';
disable_scaneffect  <= '1';

scandoubler : entity work.vga_scandoubler
port map(
 clkvideo            => clock_6,
 clkvga              => clock_12,
 enable_scandoubling => enable_scandoubling,
 disable_scaneffect  => disable_scaneffect,
 ri                  => video_ri,
 gi                  => video_gi,
 bi                  => video_bi,
 hsync_ext_n         => hsync,
 vsync_ext_n         => vsync,
 csync_ext_n         => csync,
 ro                  => vga_ro,
 go                  => vga_go,
 bo                  => vga_bo,
 hsync               => vga_hs_o,
 vsync               => vga_vs_o
);

-- adapt 6-bit scan-doubled output to 4bits/color
vga_r <= vga_ro(5 downto 2);
vga_g <= vga_go(5 downto 2);
vga_b <= vga_bo(5 downto 2);
vga_hs <= vga_hs_o;
vga_vs <= vga_vs_o;

-- get scancode from keyboard
process (reset, clock_12)
begin
	if reset='1' then
		clock_6  <= '0';
	else
		if rising_edge(clock_12) then
				clock_6  <= not clock_6;
		end if;
	end if;
end process;

keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clock_6, -- synchrounous clock with core
  kbd_clk   => ps2_clk,
  kbd_dat   => ps2_dat,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- translate scancode to joystick
joystick : entity work.kbd_joystick
port map (
  clk           => clock_6, -- synchrounous clock with core
  kbdint        => kbd_intr,
  kbdscancode   => std_logic_vector(kbd_scancode),
  joyPCFRLDU    => kbd_joy
);

-- OR-merge the Atari-style joystick on JA with the PS/2 keyboard joystick.
-- JA physical map (matches the sibling port): JA1=right, JA2=left, JA3=down, JA4=up, JA7=fire,
-- i.e. JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up, JA(4)=fire.
-- JA is active-low (pressed shorts to ground); invert so a press reads active-high, matching the
-- core's active-high input boundary and the keyboard path.
-- Coin/start are reachable from the joystick via fire+direction combos, OR-merged with keyboard.
joyPCFRLDU(0) <= kbd_joy(0) or not JA(3);                 -- up    (JA4)
joyPCFRLDU(1) <= kbd_joy(1) or not JA(2);                 -- down  (JA3)
joyPCFRLDU(2) <= kbd_joy(2) or not JA(1);                 -- left  (JA2)
joyPCFRLDU(3) <= kbd_joy(3) or not JA(0);                 -- right (JA1)
joyPCFRLDU(4) <= kbd_joy(4) or not JA(4);                 -- fire  (JA7)
joyPCFRLDU(5) <= kbd_joy(5) or (not JA(4) and not JA(3)); -- coin   = fire+up
joyPCFRLDU(6) <= kbd_joy(6) or (not JA(4) and not JA(1)); -- start1 = fire+left
joyPCFRLDU(7) <= kbd_joy(7) or (not JA(4) and not JA(0)); -- start2 = fire+right

-- pwm sound output
process(clock_14)  -- use same clock as time_pilot_sound_board
begin
  if rising_edge(clock_14) then
    pwm_accumulator  <=  std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned(audio & "00"));
  end if;
end process;

O_PMODAMP2_AIN   <= pwm_accumulator(12);
O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
