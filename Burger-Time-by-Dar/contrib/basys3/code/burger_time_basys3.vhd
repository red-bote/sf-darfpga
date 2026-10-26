---------------------------------------------------------------------------------
-- Basys3 Top level for Burger Time (Data East, 1982) by Dar (darfpga@aol.fr) (27/12/2017)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from burger_time_de10_lite.vhd (DE10-lite rev 27/12/2017):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives 12 MHz (clock_12); the
--    6 MHz scandoubler ce_x1 (clock_6) is a clock_12 toggle enable
--  - Joystick on JXADC (movement + pepper fire), OR-merged with the PS/2 keyboard
--    (onboard USB-HID, C17/B17) and dedicated buttons; Player 2 mirrors Player 1
--  - Mono PWM audio on PmodAMP2 (JA pins 1/2/4); sw15 up = audio disabled, sw14 up = gain
--  - Display mode via sw(13): 0 = 31 kHz progressive VGA (external MiST
--    scandoubler), 1 = 15 kHz TV (native rate, composite sync on HS, VS high)
--  - Keyboard decoded in this wrapper, MAME default keys (2026-10-20, F0 = release,
--    E0 ignored): arrows, Left Ctrl = pepper, 1/2 = start, 5/6 = coin
--  - PS/2, JXADC and buttons pass 2-FF synchronizers on clock_12
--  - btnC = reset (also resets the MMCM; core held in reset until MMCM lock)
--  - btnU/btnD = coin-in, btnL = P1 start, btnR = P2 start (OR-merged with the
--    keyboard 5/6, 1, 2). No fire+direction combos for coin/start, per
--    root PORTING_SPEC.md.
--  - DE10-lite's 7-segment debug hex display (dbg_cpu_addr, cpu address
--    trace) is not ported; the core's debug output is left open.
--  - No led port: the pristine top's ledr assignment is dead code (commented
--    out, never driven), matching the other ports' convention of leaving led
--    unconstrained when the core doesn't drive it.
--  - The core's video_hs/video_vs outputs are left open ("not tested") in
--    the pristine top, which derives sync only from video_csync. This port
--    wires video_hs/video_vs into the scandoubler instead (see
--    contrib/basys3/PORTING_SPEC.md), an unverified-until-synthesis choice,
--    matching the Burnin-Rubber port of the same core family.
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

entity burger_time_basys3 is
port(
 clk             : in  std_logic;
 sw              : in  std_logic_vector(15 downto 0);
 btnC            : in  std_logic;  -- reset
 btnL            : in  std_logic;  -- P1 start
 btnR            : in  std_logic;  -- P2 start
 btnU            : in  std_logic;  -- coin-in
 btnD            : in  std_logic;  -- coin-in

 JXADC              : in  std_logic_vector(4 downto 0);  -- joystick (movement + pepper)
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
end burger_time_basys3;

architecture struct of burger_time_basys3 is

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
 signal clock_6     : std_logic := '0';  -- ce_x1 enable (clock_12 / 2), not a clock
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
 signal kbd_rel       : std_logic := '0';
 signal kbd_joy       : std_logic_vector(7 downto 0) := (others => '0');

 -- PS/2, JXADC and buttons, 2-FF synchronized on the keyboard clock
 signal ps2_clk_meta, ps2_clk_s : std_logic := '1';
 signal ps2_dat_meta, ps2_dat_s : std_logic := '1';
 signal jxadc_meta, jxadc_s     : std_logic_vector(4 downto 0) := (others => '1');
 signal btn_meta, btn_s         : std_logic_vector(3 downto 0) := (others => '0'); -- U, D, L, R
 attribute ASYNC_REG : string;
 attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
 attribute ASYNC_REG of jxadc_meta, jxadc_s, btn_meta, btn_s : signal is "TRUE";

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

 -- Scandoubler ce_x1: 6 MHz pixel-rate enable made by toggling on clock_12
 -- (single clock domain; was MMCM clk_out2, which failed hold timing as a
 -- data enable in the clock_12 domain). Pattern as defender_basys3.vhd.
 process(clock_12)
 begin
   if rising_edge(clock_12) then
     clock_6 <= not clock_6;
   end if;
 end process;

 clocks : entity work.clk_wiz_0
 port map(
  clk_in1  => clk,
  clk_out1 => clock_12,
  reset    => btnC,
  locked   => mmcm_locked
 );

 -- Burger Time
 burger_time_inst : entity work.burger_time
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
   kbd_clk   => ps2_clk_s,
   kbd_dat   => ps2_dat_s,
   interrupt => kbd_intr,
   scancode  => kbd_scancode
 );

 -- Input synchronizers (2-FF) into clock_12
 process (clock_12)
 begin
   if rising_edge(clock_12) then
     ps2_clk_meta <= ps2_clk;                  ps2_clk_s <= ps2_clk_meta;
     ps2_dat_meta <= ps2_dat;                  ps2_dat_s <= ps2_dat_meta;
     jxadc_meta   <= JXADC;                    jxadc_s   <= jxadc_meta;
     btn_meta     <= btnU & btnD & btnL & btnR; btn_s     <= btn_meta;
   end if;
 end process;

 -- translate scancode to joystick (MAME default keys, PS/2 set 2 codes), replaces
 -- kbd_joystick. F0 marks a release; E0 is ignored (keypad 8/2/4/6 alias the arrows,
 -- Right Ctrl aliases Left Ctrl), sf-darfpga PORTING_SPEC.md section 3.1.
 -- kbd_joy keeps the joyHBCPPFRLDU bit order: 5 = start 1, 6 = start 2, 7 = coin.
 process (clock_12)
 begin
   if rising_edge(clock_12) then
     if kbd_intr = '1' then
       if kbd_scancode = x"F0" then
         kbd_rel <= '1';
       elsif kbd_scancode /= x"E0" then
         kbd_rel <= '0';
         if kbd_scancode = x"75" then kbd_joy(0) <= not kbd_rel; end if; -- up arrow
         if kbd_scancode = x"72" then kbd_joy(1) <= not kbd_rel; end if; -- down arrow
         if kbd_scancode = x"6B" then kbd_joy(2) <= not kbd_rel; end if; -- left arrow
         if kbd_scancode = x"74" then kbd_joy(3) <= not kbd_rel; end if; -- right arrow
         if kbd_scancode = x"14" then kbd_joy(4) <= not kbd_rel; end if; -- left ctrl : pepper
         if kbd_scancode = x"16" then kbd_joy(5) <= not kbd_rel; end if; -- 1 : start 1
         if kbd_scancode = x"1E" then kbd_joy(6) <= not kbd_rel; end if; -- 2 : start 2
         if kbd_scancode = x"2E" or kbd_scancode = x"36" then kbd_joy(7) <= not kbd_rel; end if; -- 5 / 6 : coin
       end if;
     end if;
   end if;
 end process;

 -- OR-merge the joystick on JXADC with the PS/2 keyboard joystick. JXADC physical
 -- map: JXADC1=right, JXADC2=left, JXADC3=down, JXADC4=up, JXADC7=fire(pepper), i.e.
 -- JXADC(0)=right, JXADC(1)=left, JXADC(2)=down, JXADC(3)=up, JXADC(4)=fire. JXADC is
 -- active-low (pressed shorts to ground); invert so a press reads
 -- active-high, matching the core's active-high input boundary and the
 -- keyboard path. Player 2 mirrors player 1 inputs.
 joy_up     <= kbd_joy(0) or not jxadc_s(3);                                -- up    (JXADC4)
 joy_down   <= kbd_joy(1) or not jxadc_s(2);                                -- down  (JXADC3)
 joy_left   <= kbd_joy(2) or not jxadc_s(1);                                -- left  (JXADC2)
 joy_right  <= kbd_joy(3) or not jxadc_s(0);                                -- right (JXADC1)
 joy_fire   <= kbd_joy(4) or not jxadc_s(4);                                -- fire  (JXADC7, pepper)

 -- Coin/start: keyboard (5/6, 1, 2) and dedicated buttons are OR-merged.
 -- Buttons are active-high (Basys3 board pull-down, same convention as
 -- btnC). No fire+direction combos for coin/start, per root PORTING_SPEC.md.
 joy_coin   <= kbd_joy(7) or btn_s(3) or btn_s(2);                                     -- coin   = 5 / 6 or btnU / btnD
 joy_start1 <= kbd_joy(5) or btn_s(1);                                     -- start1 = 1 or btnL
 joy_start2 <= kbd_joy(6) or btn_s(0);                                     -- start2 = 2 or btnR

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
 O_PMODAMP2_SHUTD <= not sw(15); -- sw15 up = amp shut down (audio disabled)
 O_PMODAMP2_GAIN  <= not sw(14); -- sw14 up = gain active (GAIN active low)

end struct;
