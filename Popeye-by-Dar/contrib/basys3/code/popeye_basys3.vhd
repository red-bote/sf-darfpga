---------------------------------------------------------------------------------
-- Basys3 Top level for Popeye (Nintendo, 1982) by Dar (darfpga@aol.fr) (26/12/2019)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from popeye_de10_lite.vhd (DE10-lite rev 03 27/01/2020):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives 40.32 MHz
--  - Joystick on JA, OR-merged with PS/2 keyboard (JB)
--  - Mono PWM audio on PmodAMP2 (JC); sw14 = shutdown, sw15 = gain select
--  - Display mode via sw(13): 0 = 31 kHz progressive VGA (native core rate),
--    1 = 15 kHz TV (native rate, composite sync on HS, VS high)
--  - btnC = reset (also resets the MMCM; core held in reset until MMCM lock)
--  - No LEDs / 7-segment: the shared Basys-3-Master.xdc leaves them commented.
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

entity popeye_basys3 is
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
end popeye_basys3;

architecture struct of popeye_basys3 is

 signal clock_40 : std_logic;
 signal mmcm_locked : std_logic;
 signal reset    : std_logic;

 signal r         : std_logic_vector(2 downto 0);
 signal g         : std_logic_vector(2 downto 0);
 signal b         : std_logic_vector(1 downto 0);
 signal csync     : std_logic;
 signal blankn    : std_logic;
 signal hsync     : std_logic;
 signal vsync     : std_logic;

 signal audio           : std_logic_vector(15 downto 0);
 signal pwm_accumulator : std_logic_vector(17 downto 0);

 signal kbd_intr      : std_logic;
 signal kbd_scancode  : std_logic_vector(7 downto 0);
 signal kbd_joy       : std_logic_vector(8 downto 0);
 signal fn_pulse      : std_logic_vector(7 downto 0);
 signal fn_toggle     : std_logic_vector(7 downto 0);

 signal clock_kbd  : std_logic;
 signal clock_div  : std_logic_vector(3 downto 0);

 signal joy_up        : std_logic;
 signal joy_down      : std_logic;
 signal joy_left      : std_logic;
 signal joy_right     : std_logic;
 signal joy_fire      : std_logic;
 signal joy_start1    : std_logic;
 signal joy_start2    : std_logic;
 signal joy_coin      : std_logic;
 signal joy_service   : std_logic;

begin

 -- btnC is active-high: it resets the MMCM and, together with !locked,
 -- holds the core in reset until the clock is stable.
 reset <= btnC or not mmcm_locked;

 clocks : entity work.clk_wiz_0
 port map(
  clk_in1  => clk,
  clk_out1 => clock_40,
  reset    => btnC,
  locked   => mmcm_locked
 );

 -- Popeye
 popeye : entity work.popeye
 port map(
  clock_40   => clock_40,
  reset      => reset,

  tv15Khz_mode => sw(13),  -- 0 = VGA (31 kHz progressive), 1 = TV (15 kHz native)
  video_r      => r,
  video_g      => g,
  video_b      => b,
  video_csync  => csync,
  video_blankn => blankn,
  video_hs     => hsync,
  video_vs     => vsync,

  audio_out    => audio,

  coin          => joy_coin,
  start1        => joy_start1,
  start2        => joy_start2,

  right1         => joy_right,
  left1          => joy_left,
  up1            => joy_up,
  down1          => joy_down,
  fire1          => joy_fire,

  right2         => joy_right,
  left2          => joy_left,
  up2            => joy_up,
  down2          => joy_down,
  fire2          => joy_fire,

  sw1            => not ( "10"  & '1' & "1111"), -- Copyright (2b) / N.U.(1b) / coinage (4b)
  sw2            => not ( "00111101"),            -- Cocktail(1b) / Music(1b) / Bonus(2b) / diff(2b) / life(2b)

  service        => joy_service,

  dbg_cpu_addr   => open
 );

 -- Adapt the core's 3/3/2-bit RGB to 4 bits/color, blanking on blankn
 -- (faithful to the DE10 wrapper).
 vga_r <= r & '0' when blankn = '1' else "0000";
 vga_g <= g & '0' when blankn = '1' else "0000";
 vga_b <= b & "00" when blankn = '1' else "0000";

 -- Display mode switch via sw(13):
 --   0 = 31 kHz VGA (native progressive, separate H/V sync)
 --   1 = 15 kHz TV  (composite sync on HS, VS held high -- requires a 15 kHz
 --       RGB monitor or RGB->composite converter)
 vga_hs <= csync when sw(13) = '1' else hsync;
 vga_vs <= '1'   when sw(13) = '1' else vsync;

 -- divide 40.32 MHz down to a ~2 MHz clock for the PS/2 keyboard and
 -- scancode->joystick decoding (same scheme as the DE10 top).
 process (reset, clock_40)
 begin
  if reset = '1' then
   clock_div <= (others => '0');
   clock_kbd  <= '0';
  else
   if rising_edge(clock_40) then
    if clock_div = "1001" then
     clock_div <= (others => '0');
     clock_kbd <= not clock_kbd;
    else
     clock_div <= clock_div + '1';
    end if;
   end if;
  end if;
 end process;

 -- get scancode from keyboard
 keyboard : entity work.io_ps2_keyboard
 port map (
  clk       => clock_kbd,
  kbd_clk   => ps2_clk,
  kbd_dat   => ps2_dat,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
 );

 -- translate scancode to joystick + function keys
 joystick : entity work.kbd_joystick
 port map (
  Clk           => clock_kbd,
  KbdInt        => kbd_intr,
  KbdScanCode   => kbd_scancode,
  joy_BBBBFRLDU => kbd_joy,
  fn_pulse      => fn_pulse,
  fn_toggle     => fn_toggle
 );

 -- OR-merge the joystick on JA with the PS/2 keyboard joystick.
 -- JA physical map: JA1=right, JA2=left, JA3=down, JA4=up, JA7=punch/fire,
 -- i.e. JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up, JA(4)=fire.
 -- JA is active-low (pressed shorts to ground); invert so a press reads
 -- active-high, matching the core's active-high input boundary and the
 -- keyboard path. Player 2 mirrors player 1 inputs. Coin/start reachable
 -- from the joystick via fire+direction combos.
 joy_up     <= kbd_joy(0) or not JA(3);    -- up    (JA4)
 joy_down   <= kbd_joy(1) or not JA(2);    -- down  (JA3)
 joy_left   <= kbd_joy(2) or not JA(1);    -- left  (JA2)
 joy_right  <= kbd_joy(3) or not JA(0);    -- right (JA1)
 joy_fire   <= kbd_joy(4) or not JA(4);    -- punch (JA7)
 joy_coin   <= fn_pulse(0) or (not JA(4) and not JA(3));   -- coin   = F1 / fire+up
 joy_start1 <= fn_pulse(1) or (not JA(4) and not JA(1));   -- start1 = F2 / fire+left
 joy_start2 <= fn_pulse(2);                                -- start2 = F3
 joy_service<= fn_toggle(6);                               -- service = F7 toggle

 -- pwm sound output (18-bit accumulator, updating once per clock_div cycle,
 -- same as the DE10 top)
 process(clock_40)
 begin
  if rising_edge(clock_40) then
   if clock_div = "0000" then
    pwm_accumulator <= ('0' & pwm_accumulator(16 downto 0)) + ('0' & audio & '0');
   end if;
  end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator(17);
 O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
 O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
