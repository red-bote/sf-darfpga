---------------------------------------------------------------------------------
-- Basys3 Top level for Phoenix (Amstar, 1980) by Dar (darfpga@aol.fr) (30/01/2025)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from phoenix_de10_lite.vhd (DE10-lite rev 30/01/2025):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives 11 MHz (clock_11, core
--    + pixel clock) and 50 MHz (clock_50, fed straight to the core's sound
--    effect/music blocks exactly like the pristine top's board oscillator)
--  - The pristine phoenix core (rtl_dar/phoenix.vhd) exposed ONLY composite
--    sync (video_csync) -- no separate hsync/vsync existed anywhere in the
--    upstream design (see contrib/basys3/PORTING_SPEC.md). A first
--    implementation attempt worked around this with a duration-threshold
--    sync separator inferring hs/vs from video_csync in this wrapper;
--    hardware bring-up confirmed sound and PS/2 keyboard working (core,
--    clocking, reset all correct) but produced no VGA display. This wrapper
--    now instead uses contrib/code/phoenix_expose_hsync_vsync.patch, which
--    exposes real, separately-generated video_hs/video_vs from the core
--    (derived from its already-internal pulse_a/vblank_n signals -- no
--    threshold-guessing),
--    fed directly into the MiST scandoubler for 31 kHz VGA, exactly like
--    Burnin-Rubber/Galaga's native hs/vs wiring. Hardware bring-up confirmed
--    this works (VGA display now appears).
--  - Display mode via sw(13): 0 = 31 kHz progressive VGA (scandoubler,
--    fed by the core's real hs/vs above), 1 = 15 kHz TV (video_csync
--    straight onto vgaHsync, vgaVsync held high, native RGB passed through)
--    -- this branch exactly reproduces the pristine DE10-lite top's own
--    output path.
--  - JA joystick and btnU/btnD/btnL/btnR (2026-10-02, third attempt): the
--    core gains an active-high ext_joy input (contrib/code/
--    phoenix_external_inputs.patch) OR-merged with the keyboard's JoyPCFRLDU
--    BEFORE the core's single inversion to the active-low CPU inputs, so the
--    external path uses exactly the keyboard's bits. JA1 = right, JA2 = left,
--    JA4 = up (protection), JA7 = fire; btnU/btnD = coin, btnL = 1P start,
--    btnR = 2P start. JA is 2-FF synchronized, buttons synchronized and
--    debounced (~12 ms) on clock_11. Two earlier attempts (2026-09-22/25,
--    reverted; root KNOWN_ISSUES.md) registered no input. Hardware-confirmed
--    2026-10-02.
--  - audio_select is 3 bits on the core (100/101/110/111 solo effect1/
--    effect2/effect3/melody, else mixed); wired to sw(10 downto 8) here
--    (the pristine DE10-lite top hardcodes it to "000", i.e. always mixed).
--  - Mono PWM audio on PmodAMP2 (JC); sw14 = shutdown, sw15 = gain select
--    (reproduces the pristine top's 13-bit accumulator verbatim).
--  - btnC = reset (also resets the MMCM; core held in reset until MMCM
--    lock).
--  - ps2_dat/ps2_clk are wired to the onboard USB-HID host (C17/B17), the
--    project default since 2026-09 (root PORTING_SPEC.md §3) -- pure XDC
--    pin choice, no VHDL change; the core's PS/2 decode already ran fine at
--    its native clock rate on the legacy JB1/JB3 path, and that same rate is
--    unchanged here (no clock-divider work was needed for this machine).
--    Hardware-confirmed working 2026-09-23.
--  - No led port: the pristine top's ledr debug pattern is not ported (a
--    led(7:0) ext_joy diagnostic was used during the 2026-10-02 bring-up).
--  - The DE10-lite 7-segment debug hex display is not ported, matching
--    every other machine (no Basys3 board in this repo carries 7-segment
--    wiring).
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

entity phoenix_basys3 is
port(
 clk             : in  std_logic;
 sw              : in  std_logic_vector(15 downto 0);
 btnC            : in  std_logic;  -- reset
 btnU            : in  std_logic;  -- coin
 btnD            : in  std_logic;  -- coin
 btnL            : in  std_logic;  -- 1P start
 btnR            : in  std_logic;  -- 2P start
 JA              : in  std_logic_vector(4 downto 0);  -- active-low: right, left, down(n.u.), up, fire

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
end phoenix_basys3;

architecture struct of phoenix_basys3 is

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

 signal clock_11    : std_logic;
 signal clock_50    : std_logic;
 signal mmcm_locked : std_logic;
 signal reset       : std_logic;

 signal r         : std_logic_vector(1 downto 0);
 signal g         : std_logic_vector(1 downto 0);
 signal b         : std_logic_vector(1 downto 0);
 signal video_clk : std_logic;
 signal csync     : std_logic;

 -- Real hsync/vsync from the core (contrib/code/phoenix_expose_hsync_vsync.patch)
 -- -- direct connections, no separator needed.
 signal hs, vs : std_logic;

 signal vga_r_i, vga_g_i, vga_b_i : std_logic_vector(5 downto 0);
 signal vga_r_o, vga_g_o, vga_b_o : std_logic_vector(5 downto 0);
 signal hsync_o, vsync_o          : std_logic;

 signal audio           : std_logic_vector(11 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);

 -- External player inputs (see header). JA is synchronized; buttons are
 -- synchronized and debounced: output follows only after 2**17 stable
 -- clock_11 cycles (11 MHz: 11.9 ms).
 signal ja_meta, ja_sync    : std_logic_vector(4 downto 0) := (others => '1');
 signal btn_meta, btn_sync  : std_logic_vector(3 downto 0) := (others => '0');  -- U, D, L, R
 signal btn_db              : std_logic_vector(3 downto 0) := (others => '0');
 type btn_cnt_t is array (0 to 3) of unsigned(16 downto 0);
 signal btn_cnt             : btn_cnt_t := (others => (others => '0'));
 attribute ASYNC_REG : string;
 attribute ASYNC_REG of ja_meta, ja_sync, btn_meta, btn_sync : signal is "TRUE";
 signal ext_joy             : std_logic_vector(7 downto 0);
begin

 -- btnC is active-high: it resets the MMCM and, together with !locked,
 -- holds the core in reset until the clock is stable.
 reset <= btnC or not mmcm_locked;

 clocks : entity work.clk_wiz_0
 port map(
  clk_in1  => clk,
  clk_out1 => clock_11,
  clk_out2 => clock_50,
  reset    => btnC,
  locked   => mmcm_locked
 );

 -- Phoenix
 process(clock_11)
 begin
   if rising_edge(clock_11) then
     ja_meta  <= JA;                          ja_sync  <= ja_meta;
     btn_meta <= btnU & btnD & btnL & btnR;   btn_sync <= btn_meta;
     for i in 0 to 3 loop
       if btn_sync(i) = btn_db(i) then
         btn_cnt(i) <= (others => '0');
       elsif btn_cnt(i) = (btn_cnt(i)'range => '1') then
         btn_db(i)  <= btn_sync(i);
         btn_cnt(i) <= (others => '0');
       else
         btn_cnt(i) <= btn_cnt(i) + 1;
       end if;
     end loop;
   end if;
 end process;

 -- ext_joy, active-high, core JoyPCFRLDU bit order.
 ext_joy(0) <= not ja_sync(3);             -- up: protection (JA4)
 ext_joy(1) <= '0';                        -- down: no core input
 ext_joy(2) <= not ja_sync(1);             -- left  (JA2)
 ext_joy(3) <= not ja_sync(0);             -- right (JA1)
 ext_joy(4) <= not ja_sync(4);             -- fire  (JA7)
 ext_joy(5) <= btn_db(1);                  -- 1P start (btnL)
 ext_joy(6) <= btn_db(0);                  -- 2P start (btnR)
 ext_joy(7) <= btn_db(3) or btn_db(2);     -- coin (btnU / btnD)

 phoenix_inst : entity work.phoenix
 port map(
  clock_50     => clock_50,
  clock_11     => clock_11,
  reset        => reset,
  dip_switch   => sw(7 downto 0),
  ext_joy      => ext_joy,
  ps2_clk      => ps2_clk,
  ps2_dat      => ps2_dat,
  video_r      => r,
  video_g      => g,
  video_b      => b,
  video_clk    => video_clk,
  video_csync  => csync,
  video_hs     => hs,
  video_vs     => vs,
  audio_select => sw(10 downto 8),
  audio        => audio
 );

 -- Pad native 2-bit/channel RGB to the scan doubler's 6-bit/channel input
 -- by triple replication. No external blanking gate is needed: the core
 -- already forces video_r/g/b to "00" internally during hblank/vblank (see
 -- PORTING_SPEC.md) -- the pristine DE10-lite top relies on the same thing
 -- (its blankn is tied constant true).
 vga_r_i <= r & r & r;
 vga_g_i <= g & g & g;
 vga_b_i <= b & b & b;

 scandoubler_inst : scandoubler
 port map (
   clk_sys   => clock_11,
   scanlines => "00",
   ce_x1     => video_clk,
   ce_x2     => '1',
   hs_in     => hs,
   vs_in     => vs,
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
 --       -- requires a 15 kHz RGB monitor or RGB->composite converter;
 --       reproduces the pristine DE10-lite top's own output exactly)
 vgaHsync <= hsync_o             when sw(13) = '0' else csync;
 vgaVsync <= vsync_o             when sw(13) = '0' else '1';
 vgaRed   <= vga_r_o(5 downto 2) when sw(13) = '0' else r & "00";
 vgaGreen <= vga_g_o(5 downto 2) when sw(13) = '0' else g & "00";
 vgaBlue  <= vga_b_o(5 downto 2) when sw(13) = '0' else b & "00";

 -- pwm sound output (reproduces the pristine top's exact accumulator,
 -- clocked on clock_11 -- "use same clock as pooyan_sound_board").
 process(clock_11)
 begin
   if rising_edge(clock_11) then
     pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned(audio & '0'));
   end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator(12);
 O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
 O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
