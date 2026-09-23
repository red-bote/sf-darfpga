---------------------------------------------------------------------------------
-- Basys3 Top level for Defender (Williams, 1980/1981?) by Dar (darfpga@aol.fr) (07/10/2017)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from defender_de10_lite.vhd (DE10-lite rev 07/10/2017):
--  - 100 MHz board oscillator; clk_wiz_0 MMCM derives 12 MHz (clock_12, core)
--    and 7.16 MHz (clock_7p16). The sound board wants the pristine 3.58 MHz;
--    an exact 3.58 MHz cannot come directly off the MMCM (VCO floor ~600 MHz
--    vs max output divide 128), so clock_7p16 is divided by 2 in fabric to
--    ~3.58 MHz (clock_3p58) for the sound board.
--  - Joystick on JA (thrust/reverse/down/up/fire), OR-merged with PS/2
--    keyboard (JB); coin/start on dedicated buttons only (btnU/btnL/btnR,
--    OR-merged with the keyboard F3/F1/F2). Per root PORTING_SPEC.md there are
--    NO joystick fire+direction combos for coin/start. Smart bomb (CTRL),
--    hyperspace (W) and service (A/U/H) are keyboard-only (the 5-pin JA header
--    cannot carry the full Defender button set).
--  - Mono PWM audio on PmodAMP2 (JC); sw14 = shutdown, sw15 = gain select
--  - Display mode via sw(13): 0 = 31 kHz progressive VGA (external MiST
--    scandoubler), 1 = 15 kHz TV (native rate, composite sync on HS, VS high)
--  - btnC = reset (also resets the MMCM; core held in reset until MMCM lock)
--  - DE10-lite's 7-segment debug hex display (dbg_cpu_addr, cpu address
--    trace) is not ported; the core's debug output is left open.
--  - The core's video_hs/video_vs outputs are left open ("not tested") in the
--    pristine top, which derives sync only from video_csync. This port wires
--    video_hs/video_vs into the scandoubler instead (see
--    contrib/basys3/PORTING_SPEC.md), an unverified-until-synthesis choice,
--    matching the Burnin-Rubber/BurgerTime ports of the same core family.
--  - sw_coktail_table is tied '1' (upright cabinet), like the pristine top.
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

entity defender_basys3 is
port(
 clk             : in  std_logic;
 sw              : in  std_logic_vector(15 downto 0);
 btnC            : in  std_logic;  -- reset
 btnL            : in  std_logic;  -- P1 start
 btnR            : in  std_logic;  -- P2 start
 btnU            : in  std_logic;  -- coin-in

 JA              : in  std_logic_vector(4 downto 0);  -- joystick (move/fire)
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
end defender_basys3;

architecture struct of defender_basys3 is

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

 signal clock_12    : std_logic;   -- core + scandoubler clk_sys
 signal clock_7p16  : std_logic;   -- MMCM clk_out2
 signal clock_3p58  : std_logic;   -- sound board (clock_7p16 / 2)
 signal ce1         : std_logic;   -- scandoubler ce_x1 = clock_12 / 2 (6 MHz)
 signal mmcm_locked : std_logic;
 signal reset       : std_logic;

 -- fabric divide of clk_out2 to the sound board's 3.58 MHz clock
 signal d2          : std_logic;

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

 signal audio           : std_logic_vector(7 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);

 signal kbd_intr       : std_logic;
 signal kbd_scancode   : std_logic_vector(7 downto 0);
 signal kbd_joy        : std_logic_vector(9 downto 0);
 signal keys_hua       : std_logic_vector(2 downto 0);

 signal joy_up      : std_logic;
 signal joy_down    : std_logic;
 signal joy_reverse : std_logic;
 signal joy_thrust  : std_logic;
 signal joy_fire    : std_logic;
 signal joy_start1  : std_logic;
 signal joy_start2  : std_logic;
 signal joy_coin    : std_logic;

begin

 -- btnC is active-high: it resets the MMCM and, together with !locked,
 -- holds the core in reset until the clock is stable.
 reset <= btnC or not mmcm_locked;

 clocks : entity work.clk_wiz_0
 port map(
  clk_in1  => clk,
  clk_out1 => clock_12,
  clk_out2 => clock_7p16,
  reset    => btnC,
  locked   => mmcm_locked
 );

 -- Sound board clock: ~3.58 MHz = clk_out2 (7.16 MHz) / 2 in fabric.
 process(clock_7p16)
 begin
   if rising_edge(clock_7p16) then
     d2 <= not d2;
   end if;
 end process;
 clock_3p58 <= d2;

 -- Scandoubler ce_x1: native 6 MHz pixel-enable = clock_12 / 2 in fabric.
 process(clock_12)
 begin
   if rising_edge(clock_12) then
     ce1 <= not ce1;
   end if;
 end process;

 -- Defender (Williams) main board
 defender_inst : entity work.defender
 port map(
  clock_12     => clock_12,
  clock_3p58   => clock_3p58,
  reset        => reset,

  video_r      => r,
  video_g      => g,
  video_b      => b,
  video_csync  => csync,
  video_blankn => blankn,
  video_hs     => hsync,
  video_vs     => vsync,
  audio_out    => audio,

  btn_auto_up          => keys_hua(1),
  btn_advance          => keys_hua(0),
  btn_high_score_reset => keys_hua(2),

  btn_left_coin  => joy_coin,
  btn_one_player => joy_start1,
  btn_two_players=> joy_start2,

  btn_fire       => joy_fire,
  btn_thrust     => joy_thrust,
  btn_smart_bomb => kbd_joy(8),    -- keyboard-only (CTRL)
  btn_hyperSpace => kbd_joy(9),    -- keyboard-only (W)
  btn_reverse    => joy_reverse,
  btn_down       => joy_down,
  btn_up         => joy_up,

  sw_coktail_table => '1',        -- upright cabinet
  cmd_select_players_btn => open,

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
   keys_HUA      => keys_hua
 );

 -- OR-merge the joystick on JA with the PS/2 keyboard joystick. JA physical
 -- map: JA1=right(Thrust), JA2=left(Reverse), JA3=down, JA4=up, JA7=fire, i.e.
 -- JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up, JA(4)=fire. JA is
 -- active-low (pressed shorts to ground); invert so a press reads
 -- active-high, matching the core's active-high input boundary and the
 -- keyboard path.
 joy_up      <= kbd_joy(0) or not JA(3);   -- up      (JA4)
 joy_down    <= kbd_joy(1) or not JA(2);   -- down    (JA3)
 joy_reverse <= kbd_joy(2) or not JA(1);   -- reverse (JA2, left)
 joy_thrust  <= kbd_joy(3) or not JA(0);   -- thrust  (JA1, right)
 joy_fire    <= kbd_joy(4) or not JA(4);   -- fire    (JA7)

 -- Coin/start: keyboard (F3/F1/F2) and dedicated buttons are OR-merged.
 -- Buttons are active-high (Basys3 board pull-down, same convention as
 -- btnC). No fire+direction combos for coin/start, per root PORTING_SPEC.md.
 joy_coin   <= kbd_joy(7) or btnU;         -- coin1   = F3 or btnU
 joy_start1 <= kbd_joy(5) or btnL;         -- start1  = F1 or btnL
 joy_start2 <= kbd_joy(6) or btnR;         -- start2  = F2 or btnR

 -- Pad native 3/3/2-bit RGB to the scan doubler's 6-bit/channel input by
 -- MSB replication, forced to black while blanked.
 vga_r_i <= r & r     when blankn = '1' else "000000";
 vga_g_i <= g & g     when blankn = '1' else "000000";
 vga_b_i <= b & b & b when blankn = '1' else "000000";

 scandoubler_inst : scandoubler
 port map (
   clk_sys   => clock_12,
   scanlines => "00",
   ce_x1     => ce1,
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

 -- pwm sound output (reproduces the pristine top's exact accumulator, run on
 -- the sound board clock). audio_out is 8 bits.
 process(clock_3p58)
 begin
   if rising_edge(clock_3p58) then
     pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned('0' & audio & "00"));
   end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator(12);
 O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
 O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
