---------------------------------------------------------------------------------
-- Basys3 Top level for Burnin' Rubber (Data East, 1982) by Dar (darfpga@aol.fr) (05/12/2017)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from burnin_rubber_de10_lite.vhd (DE10-lite rev 05/12/2017):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives 12 MHz (clock_12) and
--    6 MHz (clock_6)
--  - Joystick on JA (movement + fire, plus fire+up=coin and fire+left=start1
--    combos), OR-merged with PS/2 keyboard (JB) and dedicated buttons
--  - Mono PWM audio on PmodAMP2 (JC); sw14 = shutdown, sw15 = gain select
--  - Display mode via sw(13): 0 = 31 kHz progressive VGA (external MiST
--    scandoubler), 1 = 15 kHz TV (native rate, composite sync on HS, VS high)
--  - btnC = reset (also resets the MMCM; core held in reset until MMCM lock)
--  - btnU/btnD = coin-in, btnL = P1 start, btnR = P2 start (OR-merged with
--    the keyboard/JA-combo paths above)
--  - DE10-lite's 7-segment debug hex display (dbg_cpu_addr, cpu address
--    trace) is not ported; the core's debug output is left open.
--  - No led port: the pristine top's ledr assignment is dead code (commented
--    out, never driven), matching Bagman/Pooyan/Time-Pilot/Berzerk's
--    convention of leaving led unconstrained when the core doesn't drive it.
--  - The core's video_hs/video_vs outputs are left open ("not tested") in
--    the pristine top, which derives sync only from video_csync. This port
--    wires video_hs/video_vs into the scandoubler instead (see
--    contrib/basys3/PORTING_SPEC.md), an unverified-until-synthesis choice.
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

entity burnin_rubber_basys3 is
port(
 clk             : in  std_logic;
 sw              : in  std_logic_vector(15 downto 0);
 btnC            : in  std_logic;  -- reset
 btnL            : in  std_logic;  -- P1 start
 btnR            : in  std_logic;  -- P2 start
 btnU            : in  std_logic;  -- coin-in
 btnD            : in  std_logic;  -- coin-in

 JA              : in  std_logic_vector(4 downto 0);  -- joystick (movement + fire)
 ps2_dat         : in  std_logic;
 ps2_clk         : in  std_logic;

 O_PMODAMP2_AIN  : out std_logic;
 O_PMODAMP2_GAIN : out std_logic;
 O_PMODAMP2_SHUTD: out std_logic;

 vgaRed   : out std_logic_vector(3 downto 0);
 vgaGreen : out std_logic_vector(3 downto 0);
 vgaBlue  : out std_logic_vector(3 downto 0);
 vgaHsync : out std_logic;
 vgaVsync : out std_logic
);
end burnin_rubber_basys3;

architecture struct of burnin_rubber_basys3 is

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

 signal clock_12    : std_logic;
 signal clock_6     : std_logic;
 signal mmcm_locked : std_logic;
 signal reset       : std_logic;

 signal r      : std_logic_vector(2 downto 0);
 signal g      : std_logic_vector(2 downto 0);
 signal b      : std_logic_vector(1 downto 0);
 signal blankn : std_logic;
 signal csync  : std_logic;
 signal hsync  : std_logic;
 signal vsync  : std_logic;

 signal vga_r_i, vga_g_i, vga_b_i : std_logic_vector(5 downto 0);
 signal vga_r_o, vga_g_o, vga_b_o : std_logic_vector(5 downto 0);
 signal hsync_o, vsync_o          : std_logic;

 signal audio           : std_logic_vector(10 downto 0);
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
  clk_out2 => clock_6,
  reset    => btnC,
  locked   => mmcm_locked
 );

 -- Burnin' Rubber
 burnin_rubber_inst : entity work.burnin_rubber
 port map(
  clock_12     => clock_12,
  reset        => reset,

  video_r      => r,
  video_g      => g,
  video_b      => b,
  video_blankn => blankn,
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
  up2          => joy_up,

  dbg_cpu_addr => open
 );

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

 -- OR-merge the joystick on JA with the PS/2 keyboard joystick and the
 -- dedicated buttons. JA physical map: JA1=right, JA2=left, JA3=down,
 -- JA4=up, JA7=fire, i.e. JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up,
 -- JA(4)=fire. JA is active-low (pressed shorts to ground); invert so a
 -- press reads active-high, matching the core's active-high input
 -- boundary and the keyboard path. Player 2 mirrors player 1 inputs.
 joy_up     <= kbd_joy(0) or not JA(3);                                -- up    (JA4)
 joy_down   <= kbd_joy(1) or not JA(2);                                -- down  (JA3)
 joy_left   <= kbd_joy(2) or not JA(1);                                -- left  (JA2)
 joy_right  <= kbd_joy(3) or not JA(0);                                -- right (JA1)
 joy_fire   <= kbd_joy(4) or not JA(4);                                -- fire  (JA7)

 -- Coin/start: keyboard (F1/F2/F3), the JA fire+up (coin) / fire+left
 -- (start1) combos, and dedicated buttons are all OR-merged. Buttons are
 -- active-high (Basys3 board pull-down, same convention as btnC). No JA
 -- combo exists for start2.
 joy_coin   <= kbd_joy(7) or (not JA(4) and not JA(3)) or btnU or btnD; -- coin   = F3 or (fire+up) or btnU or btnD
 joy_start1 <= kbd_joy(5) or (not JA(4) and not JA(1)) or btnL;        -- start1 = F1 or (fire+left) or btnL
 joy_start2 <= kbd_joy(6) or btnR;                                     -- start2 = F2 or btnR

 -- Pad native 3/3/2-bit RGB to the scan doubler's 6-bit/channel input by
 -- MSB replication, forced to black while blanked.
 vga_r_i <= r & r     when blankn = '1' else "000000";
 vga_g_i <= g & g     when blankn = '1' else "000000";
 vga_b_i <= b & b & b when blankn = '1' else "000000";

 scandoubler_inst : scandoubler
 port map (
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
 --   0 = 31 kHz VGA (scan-doubled, top 4 bits of each 6-bit channel)
 --   1 = 15 kHz TV  (native core rate, composite sync on HS, VS held high
 --       -- requires a 15 kHz RGB monitor or RGB->composite converter)
 vgaHsync <= hsync_o             when sw(13) = '0' else csync;
 vgaVsync <= vsync_o             when sw(13) = '0' else '1';
 vgaRed   <= vga_r_o(5 downto 2) when sw(13) = '0' else r & '0';
 vgaGreen <= vga_g_o(5 downto 2) when sw(13) = '0' else g & '0';
 vgaBlue  <= vga_b_o(5 downto 2) when sw(13) = '0' else b & "00";

 -- pwm sound output (reproduces the pristine top's exact accumulator).
 process(clock_12)
 begin
   if rising_edge(clock_12) then
     pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned(audio & "00"));
   end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator(12);
 O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
 O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
