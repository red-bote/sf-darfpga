---------------------------------------------------------------------------------
-- Basys3 Top level for Zaxxon (Gremlin/Sega, 1980) by Dar (darfpga@aol.fr) (23/11/2019)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from zaxxon_de10_lite.vhd (DE10-lite rev 23/11/2019):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives 24 MHz (clock_24) --
--    the core's only clock domain (unlike Burnin-Rubber/BurgerTime's 12+6 MHz
--    pairs).
--  - Joystick on JA (movement + fire), OR-merged with PS/2 keyboard (JB) and,
--    for coin/start, dedicated buttons (btnU/btnD = coin, btnL = P1 start,
--    btnR = P2 start). No JA fire+direction coin/start combos: unlike Bagman
--    (no coin/start buttons available), this port has dedicated buttons, so
--    the combo layer is redundant and skipped (see PORTING_SPEC.md).
--  - Mono (left-channel) PWM audio on PmodAMP2 (JC); sw14 = shutdown,
--    sw15 = gain select. audio_out_r is left open (project convention is
--    mono/left-channel only).
--  - Display mode via sw(13): 0 = 31 kHz progressive VGA (external MiST
--    scandoubler), 1 = 15 kHz TV (native rate, composite sync on HS, VS high).
--    Scandoubler clk_sys/ce_x1 are NOT clock_24 (24 MHz) with fast enables --
--    Galaga's own porting record (contrib/basys3/PORTING_SPEC.md #12.3.3)
--    documents that wiring a faster clock directly to clk_sys "no funciona"
--    (does not work); clk_sys must itself be a derived signal at 2x ce_x1's
--    rate, with ce_x2 tied to '1'. contrib/code/zaxxon_expose_video_timing.patch
--    exposes the core's own real 12/6 MHz clock bits (pix_clk_div, the same
--    clock_cnt(1:0) bits pix_ena is built from) so this port wires clk_sys/
--    ce_x1 straight from the core instead of re-deriving them locally.
--  - btnC = reset (also resets the MMCM; core held in reset until MMCM lock)
--  - Cocktail (F7), service (F5), and flip-screen (F4) stay keyboard-only,
--    decoded by the unmodified kbd_joystick fn_toggle outputs -- no
--    dedicated Basys3 IO, matching every other machine's convention.
--    left_c/right_c/up_c/down_c/fire_c mirror player 1, matching the
--    pristine top (this core has no genuine second control set).
--  - The keyboard clock divider (clock_div/clock_kbd) and the PWM
--    accumulator's clock_div-gated update are reused verbatim from the
--    pristine top (see PORTING_SPEC.md).
--  - DE10-lite's 7-segment debug hex display (dbg_cpu_addr, cpu address
--    trace) is not ported; the core's debug output is left open.
--  - No led port: the pristine top's ledr assignment is dead code (never
--    driven), matching Bagman/Pooyan/Time-Pilot/Berzerk/Burnin-Rubber's
--    convention of leaving led unconstrained when the core doesn't drive it.
--  - The pristine core declares video_hs/video_vs but never drives them
--    (dead ports; only video_csync is real) -- confirmed by grepping
--    zaxxon.vhd for assignments. contrib/code/zaxxon_expose_video_timing.patch
--    adds real hsync/vsync (video_hs <= hsync0, a new simple video_vs pulse
--    from vcnt) plus the pix_clk_div port (see above) so this port can wire
--    hsync/vsync/clocks into the scandoubler; see contrib/basys3/PORTING_SPEC.md.
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

entity zaxxon_basys3 is
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
end zaxxon_basys3;

architecture struct of zaxxon_basys3 is

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

 signal clock_24    : std_logic;
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

 -- clk_sys (12 MHz) / ce_x1 (6 MHz) for the scandoubler, matching Galaga's
 -- proven pattern (contrib/basys3/PORTING_SPEC.md #12.3.3: Galaga's own
 -- porting record documents that wiring a faster clock -- clock_18 or
 -- clock_36 -- directly to clk_sys "no funciona" (does not work); a
 -- derived clk_sys = 2x ce_x1, ce_x2 tied to '1', is the value actually
 -- used). pix_clk_div (from zaxxon_expose_video_timing.patch) is the
 -- core's own real clock_cnt(1:0): bit 0 is a clean 12 MHz square wave,
 -- bit 1 a clean 6 MHz square wave -- the exact bits pix_ena is built
 -- from, so no separate mirrored counter is needed.
 signal pix_clk_div : std_logic_vector(1 downto 0);
 signal sd_clock_12 : std_logic;
 signal sd_clock_6  : std_logic;

 signal audio_l           : std_logic_vector(15 downto 0);
 signal pwm_accumulator_l : std_logic_vector(17 downto 0);

 signal clock_div : unsigned(3 downto 0);
 signal clock_kbd : std_logic;

 signal kbd_intr      : std_logic;
 signal kbd_scancode  : std_logic_vector(7 downto 0);
 signal joy_BBBBFRLDU : std_logic_vector(8 downto 0);
 signal fn_pulse      : std_logic_vector(7 downto 0);
 signal fn_toggle     : std_logic_vector(7 downto 0);

 signal core_up, core_down, core_left, core_right, core_fire : std_logic;
 signal core_coin1, core_start1, core_start2                 : std_logic;

begin

 -- btnC is active-high: it resets the MMCM and, together with !locked,
 -- holds the core in reset until the clock is stable.
 reset <= btnC or not mmcm_locked;

 clocks : entity work.clk_wiz_0
 port map(
  clk_in1  => clk,
  clk_out1 => clock_24,
  reset    => btnC,
  locked   => mmcm_locked
 );

 -- Zaxxon
 zaxxon_inst : entity work.zaxxon
 port map(
  clock_24     => clock_24,
  reset        => reset,

  video_r      => r,
  video_g      => g,
  video_b      => b,
  video_csync  => csync,
  video_blankn => blankn,
  video_hs     => hsync,
  video_vs     => vsync,
  pix_clk_div  => pix_clk_div,

  audio_out_l  => audio_l,
  audio_out_r  => open,

  coin1        => core_coin1,
  coin2        => '0',
  start1       => core_start1,
  start2       => core_start2,

  left         => core_left,
  right        => core_right,
  up           => core_up,
  down         => core_down,
  fire         => core_fire,

  left_c       => core_left,
  right_c      => core_right,
  up_c         => core_up,
  down_c       => core_down,
  fire_c       => core_fire,

  cocktail     => fn_toggle(6), -- F7
  service      => fn_toggle(4), -- F5
  flip_screen  => fn_toggle(3), -- F4

  dbg_cpu_addr => open
 );

 -- keyboard clock divider (reused verbatim from the pristine top): divides
 -- clock_24 down for io_ps2_keyboard and gates the PWM accumulator update.
 process (reset, clock_24)
 begin
   if reset = '1' then
     clock_div <= (others => '0');
     clock_kbd <= '0';
   elsif rising_edge(clock_24) then
     if clock_div = "0010" then
       clock_div <= (others => '0');
       clock_kbd <= not clock_kbd;
     else
       clock_div <= clock_div + 1;
     end if;
   end if;
 end process;

 -- clk_sys/ce_x1 for the scandoubler, straight from the core's real
 -- pix_clk_div (see the signal declaration comment above).
 sd_clock_12 <= pix_clk_div(0);
 sd_clock_6  <= pix_clk_div(1);

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
   clk           => clock_kbd,
   kbdint        => kbd_intr,
   kbdscancode   => std_logic_vector(kbd_scancode),
   joy_BBBBFRLDU => joy_BBBBFRLDU,
   fn_pulse      => fn_pulse,
   fn_toggle     => fn_toggle
 );

 -- OR-merge the joystick on JA with the PS/2 keyboard joystick. JA physical
 -- map: JA1=right, JA2=left, JA3=down, JA4=up, JA7=fire, i.e. JA(0)=right,
 -- JA(1)=left, JA(2)=down, JA(3)=up, JA(4)=fire. JA is active-low (pressed
 -- shorts to ground); invert so a press reads active-high, matching the
 -- core's active-high input boundary and the keyboard path.
 core_up    <= joy_BBBBFRLDU(0) or not JA(3);  -- up    (JA4)
 core_down  <= joy_BBBBFRLDU(1) or not JA(2);  -- down  (JA3)
 core_left  <= joy_BBBBFRLDU(2) or not JA(1);  -- left  (JA2)
 core_right <= joy_BBBBFRLDU(3) or not JA(0);  -- right (JA1)
 core_fire  <= joy_BBBBFRLDU(4) or not JA(4);  -- fire  (JA7)

 -- Coin/start: keyboard (F1/F2/F3) OR-merged with dedicated buttons.
 -- Buttons are active-high (Basys3 board pull-down, same convention as
 -- btnC). This core has a single coin input; btnU and btnD both trigger it.
 core_coin1  <= fn_pulse(0) or btnU or btnD;  -- coin   = F1 or btnU or btnD
 core_start1 <= fn_pulse(1) or btnL;          -- start1 = F2 or btnL
 core_start2 <= fn_pulse(2) or btnR;          -- start2 = F3 or btnR

 -- Pad native 3/3/2-bit RGB to the scan doubler's 6-bit/channel input by
 -- MSB replication, forced to black while blanked.
 vga_r_i <= r & r     when blankn = '1' else "000000";
 vga_g_i <= g & g     when blankn = '1' else "000000";
 vga_b_i <= b & b & b when blankn = '1' else "000000";

 scandoubler_inst : scandoubler
 port map (
   clk_sys   => sd_clock_12, -- derived 12 MHz (not clock_24 directly -- see above)
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
 vgaRed   <= vga_r_o(5 downto 2) when sw(13) = '0' else r & '0';
 vgaGreen <= vga_g_o(5 downto 2) when sw(13) = '0' else g & '0';
 vgaBlue  <= vga_b_o(5 downto 2) when sw(13) = '0' else b & "00";

 -- pwm sound output (reproduces the pristine top's exact accumulator,
 -- left channel only; gated by the keyboard clock divider like the
 -- pristine top).
 process(clock_24)
 begin
   if rising_edge(clock_24) then
     if clock_div = "0000" then
       pwm_accumulator_l <= std_logic_vector(unsigned('0' & pwm_accumulator_l(16 downto 0)) + unsigned('0' & audio_l & '0'));
     end if;
   end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator_l(17);
 O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
 O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
