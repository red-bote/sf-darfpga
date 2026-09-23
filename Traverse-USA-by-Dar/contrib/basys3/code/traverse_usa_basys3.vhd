---------------------------------------------------------------------------------
-- Basys3 Top level for Traverse USA / Zippy Race (Irem M-52, 1983) by Dar
-- (darfpga@aol.fr) (16/03/2019)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from traverse_usa_de10_lite.vhd (DE10-lite rev 16/03/2019):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives clock_36 (36.86 MHz,
--    core) and clock_7p16 (7.16 MHz). The sound board wants the pristine
--    3.58 MHz; an exact 3.58 MHz cannot come directly off the MMCM (VCO
--    floor vs max output divide), so clock_7p16 is divided by 2 in fabric to
--    ~3.58 MHz (clock_3p58) for the sound board -- the same approach as the
--    Defender port.
--  - Joystick on JA (four directions + fire/accel), OR-merged with the
--    PS/2/USB keyboard and, for coin/start, dedicated buttons (btnU/btnD =
--    coin, btnL = P1 start, btnR = P2 start).
--  - Mono (left-channel) PWM audio on PmodAMP2 (JC); sw14 = shutdown,
--    sw15 = gain select.
--  - Display mode via sw(13): 0 = 31 kHz progressive VGA (external MiST
--    scandoubler), 1 = 15 kHz TV (native rate, composite sync on HS, VS high).
--    Scandoubler clk_sys/ce_x1 are derived locally at 2x / 1x the core pixel
--    rate (a mod-6 counter on clock_36), matching Galaga's proven pattern:
--    wiring a faster clock directly to clk_sys does not work -- clk_sys must
--    itself be a derived signal at 2x ce_x1's rate, with ce_x2 tied to '1'.
--  - btnC = reset (also resets the MMCM; core held in reset until MMCM lock).
 --  - Keyboard clock divider (clock_div/clock_kbd) drives io_ps2_keyboard /
 --    kbd_joystick on clock_36 at ~6 MHz (mod-3 toggle, keyboard-only); the
 --    PWM accumulator runs on clock_3p58. The pristine top's shared mod-6
 --    divider (~3 MHz) is too slow for the Basys 3 onboard USB-HID host
 --    (needs >= 6 MHz), per Congo Bongo / Zaxxon / Pooyan hardware data.
--  - DE10-lite's 7-segment debug hex display (dbg_cpu_addr) is not ported;
--    the core's debug output is left open.
--  - The pristine core declares video_hs/video_vs but does not drive them
--    (dead ports; only video_csync is real, verified in traverse_usa.vhd).
--    contrib/code/traverse_usa_expose_video_timing.patch adds real
--    hsync/vsync (video_hs <= hsync0, a simple video_vs pulse from
--    vsync_cnt) so this port can wire them into the scandoubler; see
--    contrib/basys3/PORTING_SPEC.md.
--  - This core has no genuine fire/coin-multiplex inputs separate from
--    movement/accelerate (see PORTING_SPEC.md): JA4 (JA7) and JA3 (JA4) both
--    accelerate, JA2 (JA3) brakes, JA1 (JA2)/JA0 (JA1) steer. Space on the
--    keyboard also accelerates.
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

entity traverse_usa_basys3 is
port(
 clk             : in  std_logic;
 sw              : in  std_logic_vector(15 downto 0);
 btnC            : in  std_logic;  -- reset
 btnL            : in  std_logic;  -- P1 start
 btnR            : in  std_logic;  -- P2 start
 btnU            : in  std_logic;  -- coin-in
 btnD            : in  std_logic;  -- coin-in

 JA              : in  std_logic_vector(4 downto 0);  -- joystick (steer/brake/accel)
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
end traverse_usa_basys3;

architecture struct of traverse_usa_basys3 is

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

 signal clock_36    : std_logic;
 signal clock_3p58  : std_logic;
 signal clock_7p16  : std_logic;
 signal mmcm_locked : std_logic;
 signal reset       : std_logic;

 signal r      : std_logic_vector(1 downto 0);
 signal g      : std_logic_vector(2 downto 0);
 signal b      : std_logic_vector(2 downto 0);
 signal blankn : std_logic;
 signal csync  : std_logic;
 signal hsync  : std_logic;
 signal vsync  : std_logic;

 signal vga_r_i, vga_g_i, vga_b_i : std_logic_vector(5 downto 0);
 signal vga_r_o, vga_g_o, vga_b_o : std_logic_vector(5 downto 0);
 signal hsync_o, vsync_o          : std_logic;

 -- scandoubler clk_sys (12 MHz) / ce_x1 (6 MHz), derived by a mod-6 counter
 -- on clock_36 (matching Galaga's proven pattern; a bare fast clock wired to
 -- clk_sys does not work -- see the header note).
 signal scandoubler_slot : std_logic_vector(2 downto 0);
 signal sd_clock_12      : std_logic;
 signal sd_clock_6       : std_logic;

 signal audio           : std_logic_vector(10 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);

 -- keyboard clock divider (keyboard-only; ~6 MHz -- see the divider process)
 signal clock_div : std_logic_vector(2 downto 0);
 signal clock_kbd : std_logic;

 signal kbd_intr     : std_logic;
 signal kbd_scancode : std_logic_vector(7 downto 0);
 signal joyPCFRLDU   : std_logic_vector(7 downto 0);

 signal core_accel, core_brake, core_left, core_right    : std_logic;
 signal core_coin1, core_start1, core_start2             : std_logic;

begin

 -- btnC is active-high: it resets the MMCM and, together with !locked,
 -- holds the core in reset until the clock is stable.
 reset <= btnC or not mmcm_locked;

 clocks : entity work.clk_wiz_0
 port map(
  clk_in1  => clk,
  clk_out1 => clock_36,
  clk_out2 => clock_7p16,
  reset    => btnC,
  locked   => mmcm_locked
 );

 -- Sound board clock: ~3.58 MHz = clk_out2 (7.16 MHz) / 2 in fabric
 -- (Defender pattern; exact 3.58 MHz cannot come directly off the MMCM).
 process(clock_7p16)
 begin
   if rising_edge(clock_7p16) then
     clock_3p58 <= not clock_3p58;
   end if;
 end process;

 -- Traverse USA
 traverse_usa_inst : entity work.traverse_usa
 port map(
  clock_36   => clock_36,
  clock_3p58 => clock_3p58,
  reset      => reset,

  video_r      => r,
  video_g      => g,
  video_b      => b,
  video_csync  => csync,
  video_blankn => blankn,
  video_hs     => hsync,
  video_vs     => vsync,
  audio_out    => audio,

  dip_switch_1 => x"FF",
  dip_switch_2 => x"FE",

  start2   => core_start2,
  start1   => core_start1,
  coin1    => core_coin1,
  right1   => core_right,
  left1    => core_left,
  brake1   => core_brake,
  accel1   => core_accel,
  right2   => core_right,
  left2    => core_left,
  brake2   => core_brake,
  accel2   => core_accel,

  dbg_cpu_addr => open
 );

 -- keyboard clock divider: divides clock_36 down for io_ps2_keyboard /
 -- kbd_joystick (keyboard-only -- no PWM gate shares clock_div here, so
 -- changing its period has no audio side effect). Toggle every 3 clocks
 -- (mod-3) -> clock_36/6 ~= 6.14 MHz: the pristine mod-6 toggle (~3 MHz)
 -- is too slow for the Basys 3 onboard USB-HID host, which needs >= 6 MHz
 -- (see Congo Bongo / Arcade_Zaxxon / Pooyan hardware data).
 process (reset, clock_36)
 begin
   if reset = '1' then
     clock_div <= "000";
     clock_kbd <= '0';
   elsif rising_edge(clock_36) then
     if clock_div = "010" then
       clock_div <= "000";
       clock_kbd <= not clock_kbd;
     else
       clock_div <= clock_div + 1;
     end if;
   end if;
 end process;

 -- clk_sys/ce_x1 for the scandoubler, 2x / 1x the core pixel rate, derived
 -- by a mod-6 counter on clock_36 (Galaga's proven pattern).
 process (clock_36)
 begin
   if rising_edge(clock_36) then
     sd_clock_12 <= '0';
     if scandoubler_slot = "101" then
       scandoubler_slot <= (others => '0');
     else
       scandoubler_slot <= std_logic_vector(unsigned(scandoubler_slot) + 1);
     end if;
     if scandoubler_slot = "100" or scandoubler_slot = "001" then
       sd_clock_6  <= not sd_clock_6;
       sd_clock_12 <= '1';
     end if;
   end if;
 end process;

 -- get scancode from keyboard
 keyboard : entity work.io_ps2_keyboard
 port map (
   clk       => clock_kbd, -- synchronous with core (pristine divider)
   kbd_clk   => ps2_clk,
   kbd_dat   => ps2_dat,
   interrupt => kbd_intr,
   scancode  => kbd_scancode
 );

 -- translate scancode to joystick / function keys
 joystick : entity work.kbd_joystick
 port map (
   clk          => clock_kbd,
   kbdint       => kbd_intr,
   kbdscancode  => std_logic_vector(kbd_scancode),
   joyPCFRLDU   => joyPCFRLDU
 );

 -- OR-merge the joystick on JA with the PS/2 keyboard joystick. JA physical
 -- map: JA1=right, JA2=left, JA3=down/brake, JA4=up, JA7=fire/accel, i.e.
 -- JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up, JA(4)=fire. JA is
 -- active-low (pressed shorts to ground); invert so a press reads
 -- active-high, matching the core's active-high input boundary and the
 -- keyboard path. There is no fire input on the core: up (JA3, or arrow-UP
 -- bit0 of joyPCFRLDU) and fire (JA4, or SPACE bit4) both accelerate, and
 -- down (JA2, or arrow-DOWN bit1) brakes.
 core_accel <= joyPCFRLDU(0) or joyPCFRLDU(4) or not JA(3) or not JA(4);
 core_brake <= joyPCFRLDU(1) or not JA(2);
 core_left  <= joyPCFRLDU(2) or not JA(1);
 core_right <= joyPCFRLDU(3) or not JA(0);

 -- Coin/start: keyboard (F1/F2/F3) OR-merged with dedicated buttons.
 -- Buttons are active-high (Basys3 board pull-down, same convention as
 -- btnC). This core has a single coin input; btnU and btnD both trigger it.
 core_coin1  <= joyPCFRLDU(5) or btnU or btnD;  -- coin   = F1 or btnU or btnD
 core_start1 <= joyPCFRLDU(6) or btnL;          -- start1 = F2 or btnL
 core_start2 <= joyPCFRLDU(7) or btnR;          -- start2 = F3 or btnR

 -- Pad native 2/3/3-bit RGB to the scan doubler's 6-bit/channel input by
 -- MSB replication, forced to black while blanked.
 vga_r_i <= r & r & r      when blankn = '1' else "000000";
 vga_g_i <= g & g           when blankn = '1' else "000000";
 vga_b_i <= b & b           when blankn = '1' else "000000";

 scandoubler_inst : scandoubler
 port map (
   clk_sys   => sd_clock_12, -- derived 12 MHz (not clock_36 directly -- see above)
   scanlines => "00",
   ce_x1     => sd_clock_6,  -- derived 6 MHz, exactly 2x below clk_sys
   ce_x2     => '1',         -- enabled every clk_sys (sd_clock_12) edge
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
 vgaRed   <= vga_r_o(5 downto 2) when sw(13) = '0' else r & "00";
 vgaGreen <= vga_g_o(5 downto 2) when sw(13) = '0' else g & '0';
 vgaBlue  <= vga_b_o(5 downto 2) when sw(13) = '0' else b & '0';

 -- pwm sound output (reproduces the pristine top's exact accumulator,
 -- mono/left channel on clock_3p58).
 process(clock_3p58)
 begin
   if rising_edge(clock_3p58) then
     pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned(audio & "00"));
   end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator(12);
 O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
 O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
