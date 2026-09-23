---------------------------------------------------------------------------------
-- Basys3 Top level for Bagman (Stern, 1982) by Dar (darfpga@aol.fr) (04/06/2018)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from bagman_de10_lite.vhd (DE10-lite rev 04/06/2018):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives 12 MHz
--  - Joystick on JA, OR-merged with PS/2 keyboard (JB)
--  - Mono PWM audio on PmodAMP2 (JC); sw14 = shutdown, sw15 = gain select
--  - Display mode via sw(13): 0 = 31 kHz progressive VGA (internal line
--    doubler), 1 = 15 kHz TV (native rate, composite sync on HS, VS high)
--  - btnC = reset (also resets the MMCM; core held in reset until MMCM lock)
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

entity bagman_basys3 is
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
end bagman_basys3;

architecture struct of bagman_basys3 is

 signal clock_12 : std_logic;
 signal mmcm_locked : std_logic;
 signal reset    : std_logic;

 signal r         : std_logic_vector(2 downto 0);
 signal g         : std_logic_vector(2 downto 0);
 signal b         : std_logic_vector(1 downto 0);
 signal csync     : std_logic;
 signal hsync     : std_logic;
 signal vsync     : std_logic;

 signal audio           : std_logic_vector(12 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);

 signal kbd_intr      : std_logic;
 signal kbd_scancode  : std_logic_vector(7 downto 0);
 signal kbd_joy       : std_logic_vector(9 downto 0);

 signal joy_up        : std_logic;
 signal joy_down      : std_logic;
 signal joy_left      : std_logic;
 signal joy_right     : std_logic;
 signal joy_fire      : std_logic;
 signal joy_start1    : std_logic;
 signal joy_start2    : std_logic;
 signal joy_coin      : std_logic;

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

 -- Bagman
 bagman : entity work.bagman
 port map(
  clock_12     => clock_12,
  reset        => reset,

  tv15Khz_mode => sw(13),  -- 0 = VGA (31 kHz doubled), 1 = TV (15 kHz native)
  video_r      => r,
  video_g      => g,
  video_b      => b,
  video_csync  => csync,
  video_hs     => hsync,
  video_vs     => vsync,
  audio_out    => audio,

  start2       => joy_start2,
  start1       => joy_start1,
  coin1        => joy_coin,

  fire1        => joy_fire,
  right1       => joy_right,
  left1        => joy_left,
  down1        => joy_down,
  up1          => joy_up,

  fire2        => joy_fire,
  right2       => joy_right,
  left2        => joy_left,
  down2        => joy_down,
  up2          => joy_up
 );

 -- Adapt the core's 3/3/2-bit RGB to 4 bits/color (both modes).
 -- (The DE10 wrapper gated RGB with blankn forced to '1'; dropped here.)
 vga_r <= r & '0';
 vga_g <= g & '0';
 vga_b <= b & "00";

 -- Display mode switch via sw(13):
 --   0 = 31 kHz VGA (line-doubled progressive, separate H/V sync)
 --   1 = 15 kHz TV  (native core rate, composite sync on HS, VS held high
 --       -- requires a 15 kHz RGB monitor or RGB->composite converter)
 vga_hs <= csync when sw(13) = '1' else hsync;
 vga_vs <= '1'   when sw(13) = '1' else vsync;

 -- get scancode from keyboard
 keyboard : entity work.io_ps2_keyboard
 port map (
   clk       => clock_12, -- synchronous clock with core
   kbd_clk   => ps2_clk,
   kbd_dat   => ps2_dat,
   interrupt => kbd_intr,
   scancode  => kbd_scancode
 );

 -- translate scancode to joystick
 joystick : entity work.kbd_joystick
 port map (
   clk           => clock_12, -- synchronous clock with core
   kbdint        => kbd_intr,
   kbdscancode   => std_logic_vector(kbd_scancode),
   joyHBCPPFRLDU => kbd_joy,
   keys_HUA      => open
 );

 -- OR-merge the joystick on JA with the PS/2 keyboard joystick.
 -- JA physical map: JA1=right, JA2=left, JA3=down, JA4=up, JA7=jump/fire,
 -- i.e. JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up, JA(4)=fire.
 -- JA is active-low (pressed shorts to ground); invert so a press reads
 -- active-high, matching the core's active-high input boundary and the
 -- keyboard path. Player 2 mirrors player 1 inputs. Coin/start reachable
 -- from the joystick via fire+direction combos.
 joy_up     <= kbd_joy(0) or not JA(3);                        -- up    (JA4)
 joy_down   <= kbd_joy(1) or not JA(2);                        -- down  (JA3)
 joy_left   <= kbd_joy(2) or not JA(1);                        -- left  (JA2)
 joy_right  <= kbd_joy(3) or not JA(0);                        -- right (JA1)
 joy_fire   <= kbd_joy(4) or not JA(4);                        -- jump  (JA7)
 joy_start1 <= kbd_joy(5) or (not JA(4) and not JA(1));        -- start1 = fire+left
 joy_start2 <= kbd_joy(6);
 joy_coin   <= kbd_joy(7) or (not JA(4) and not JA(3));        -- coin   = fire+up

 -- pwm sound output
 process(clock_12)  -- same clock as the DE10 top drove the PWM accumulator
 begin
   if rising_edge(clock_12) then
     pwm_accumulator  <=  std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned('0' & audio(12 downto 1)));
   end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator(12);
 O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
 O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
