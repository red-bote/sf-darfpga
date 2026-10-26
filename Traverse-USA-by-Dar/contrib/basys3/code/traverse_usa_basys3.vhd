---------------------------------------------------------------------------------
-- Basys 3 top level for Traverse USA by Red~Bote, derived from
-- traverse_usa_de10_lite.vhd by Dar (darfpga@aol.fr, http://darfpga.blogspot.fr);
-- see that file for its history.
---------------------------------------------------------------------------------
--
-- v0.1 (10/26/2026) : initial Basys 3 release
--
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthesized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
--
-- Main features:
--  clk_wiz_0 derives clock_36 (36.86 MHz, core) and clock_7p16 from 100 MHz; the
--  sound board clock_3p58 = clock_7p16 / 2 in fabric (MMCM cannot give 3.58 MHz)
--  Core inputs are steer, accelerate and brake (no fire): joystick on JXADC, fire =
--  accelerate, down = brake, up unused; OR-merged with the PS/2 keyboard (USB-HID)
--  Mono PWM audio on PmodAMP2 (JA pins 1/2/4); sw15 up = audio off, sw14 up = gain
--  31 kHz VGA via the MiST scandoubler; sw13 = 15 kHz TV (csync on HS)
--  video_hs/video_vs driven by a core patch (undriven in the source core)
--  Keyboard on clock_36: MAME default keys (left/right arrows, Left Ctrl =
--  accelerate, Left Alt = brake, 1/2 = start, 5/6 = coin)
--  btnC = reset (MMCM and core), btnU/btnD = coin, btnL/btnR = start
--  PS/2, JXADC and buttons pass 2-FF synchronizers on clock_36
--  DIP switches on sw7-0 (bank 2) and sw11-8 (bank 1 bits 3-0)
--  7-segment debug display not ported
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

 JXADC              : in  std_logic_vector(4 downto 0);  -- joystick (steer/brake/accel)
 ps2_dat         : in  std_logic;
 ps2_clk         : in  std_logic;

 O_PMODAMP2_AIN  : out std_logic;
 O_PMODAMP2_GAIN : out std_logic;
 O_PMODAMP2_SHUTD: out std_logic;

 vga_r  : out std_logic_vector(3 downto 0);
 vga_g  : out std_logic_vector(3 downto 0);
 vga_b  : out std_logic_vector(3 downto 0);
 vga_hs : out std_logic;
 vga_vs : out std_logic
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

 -- scandoubler clk_sys (12 MHz) / ce_x1 (6 MHz), ce_x2 = '1', derived by a
 -- mod-6 counter on clock_36.
 signal scandoubler_slot : std_logic_vector(2 downto 0);
 signal sd_clock_12      : std_logic;
 signal sd_clock_6       : std_logic;

 signal audio           : std_logic_vector(10 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);

 signal kbd_intr     : std_logic;
 signal kbd_scancode : std_logic_vector(7 downto 0);
 signal kbd_rel      : std_logic := '0';
 -- decoded keys: 2 left, 3 right, 4 accel, 5 coin, 6 start1, 7 start2, 8 brake
 signal kbd_joy      : std_logic_vector(8 downto 0) := (others => '0');

 -- 2-FF synchronizers on clock_36: PS/2, JXADC and btnU/btnD/btnL/btnR.
 signal ps2_clk_meta, ps2_clk_s : std_logic := '1';
 signal ps2_dat_meta, ps2_dat_s : std_logic := '1';
 signal jxadc_meta, jxadc_s     : std_logic_vector(4 downto 0) := (others => '1');
 signal btn_meta, btn_s         : std_logic_vector(3 downto 0) := (others => '0');  -- U, D, L, R
 attribute ASYNC_REG : string;
 attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
 attribute ASYNC_REG of jxadc_meta, jxadc_s, btn_meta, btn_s : signal is "TRUE";

 signal core_accel, core_brake, core_left, core_right    : std_logic;

 -- DIP switches on spare board switches (PORTING_SPEC.md 3.2): switch down = DE10
 -- default, switch up inverts the bit.
 --   dip2 = sw(7:0):  Diag(7) / Demo(6) / Zippy(5) / Freeze(4) / M-Km(3) /
 --                    Coin mode(2) / Cocktail(1) / Flip(0), default x"FE"
 --   dip1 = sw(11:8) on bits 3-0: Cont. play(3) / Fuel consumption(2) /
 --                    Fuel lost when collision(1-0), default x"FF"; Coinage_B
 --                    (7-4) fixed at its default (sw12 spare).
 constant DIP1_DEFAULT : std_logic_vector(7 downto 0) := x"FF";
 constant DIP2_DEFAULT : std_logic_vector(7 downto 0) := x"FE";
 signal dip1, dip2 : std_logic_vector(7 downto 0);
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
 -- (exact 3.58 MHz cannot come directly off the MMCM).
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

  dip_switch_1 => dip1,
  dip_switch_2 => dip2,

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

 -- clk_sys/ce_x1 for the scandoubler, 2x / 1x the core pixel rate, derived
 -- by a mod-6 counter on clock_36.
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

 -- input synchronizers (2-FF)
 process (clock_36)
 begin
   if rising_edge(clock_36) then
     ps2_clk_meta <= ps2_clk;  ps2_clk_s <= ps2_clk_meta;
     ps2_dat_meta <= ps2_dat;  ps2_dat_s <= ps2_dat_meta;
     jxadc_meta <= JXADC;                     jxadc_s <= jxadc_meta;
     btn_meta   <= btnU & btnD & btnL & btnR; btn_s   <= btn_meta;
   end if;
 end process;

 -- get scancode from keyboard
 keyboard : entity work.io_ps2_keyboard
 port map (
   clk       => clock_36, -- core clock, single domain
   kbd_clk   => ps2_clk_s,
   kbd_dat   => ps2_dat_s,
   interrupt => kbd_intr,
   scancode  => kbd_scancode
 );

 -- translate scancode to keys (MAME default keys, PS/2 set 2 codes), replaces
 -- kbd_joystick. F0 marks a release; E0 is ignored (keypad 4/6 alias the arrows,
 -- Right Ctrl/Alt alias Left Ctrl/Alt), PORTING_SPEC.md 3.1.
 process (clock_36)
 begin
   if rising_edge(clock_36) then
     if kbd_intr = '1' then
       if kbd_scancode = x"F0" then
         kbd_rel <= '1';
       elsif kbd_scancode /= x"E0" then
         kbd_rel <= '0';
         if kbd_scancode = x"6B" then kbd_joy(2) <= not kbd_rel; end if; -- left arrow
         if kbd_scancode = x"74" then kbd_joy(3) <= not kbd_rel; end if; -- right arrow
         if kbd_scancode = x"14" then kbd_joy(4) <= not kbd_rel; end if; -- left ctrl: accelerate
         if kbd_scancode = x"2E" or kbd_scancode = x"36" then kbd_joy(5) <= not kbd_rel; end if; -- 5 / 6: coin
         if kbd_scancode = x"16" then kbd_joy(6) <= not kbd_rel; end if; -- 1: start 1
         if kbd_scancode = x"1E" then kbd_joy(7) <= not kbd_rel; end if; -- 2: start 2
         if kbd_scancode = x"11" then kbd_joy(8) <= not kbd_rel; end if; -- left alt: brake
       end if;
     end if;
   end if;
 end process;

 -- OR-merge the joystick on JXADC with the PS/2 keyboard joystick. JXADC physical
 -- map: JXADC1=right, JXADC2=left, JXADC3=down/brake, JXADC4=up, JXADC7=fire/accel, i.e.
 -- JXADC(0)=right, JXADC(1)=left, JXADC(2)=down, JXADC(3)=up, JXADC(4)=fire. JXADC is
 -- active-low (pressed shorts to ground); invert so a press reads
 -- active-high, matching the core's active-high input boundary and the
 -- keyboard path. There is no fire input on the core: fire (JXADC7)
 -- accelerates, down (JXADC3) brakes; down+fire asserts both, as fire passes
 -- through. Up (JXADC4) is unused.
 core_accel <= kbd_joy(4) or not jxadc_s(4);                   -- left ctrl / JXADC7
 dip1 <= DIP1_DEFAULT xor (x"0" & sw(11 downto 8));
 dip2 <= DIP2_DEFAULT xor sw(7 downto 0);

 core_brake <= kbd_joy(8) or not jxadc_s(2);                   -- left alt / JXADC3
 core_left  <= kbd_joy(2) or not jxadc_s(1);                   -- left arrow / JXADC2
 core_right <= kbd_joy(3) or not jxadc_s(0);                   -- right arrow / JXADC1

 -- Coin/start: keyboard (5/6, 1, 2) OR-merged with dedicated buttons.
 -- Buttons are active-high (Basys3 board pull-down, same convention as
 -- btnC). This core has a single coin input; btnU and btnD both trigger it.
 core_coin1  <= kbd_joy(5) or btn_s(3) or btn_s(2);  -- coin   = 5 / 6, btnU, btnD
 core_start1 <= kbd_joy(6) or btn_s(1);              -- start1 = 1 or btnL
 core_start2 <= kbd_joy(7) or btn_s(0);              -- start2 = 2 or btnR

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
 vga_hs <= hsync_o             when sw(13) = '0' else csync;
 vga_vs <= vsync_o             when sw(13) = '0' else '1';
 vga_r  <= vga_r_o(5 downto 2) when sw(13) = '0' else r & "00";
 vga_g  <= vga_g_o(5 downto 2) when sw(13) = '0' else g & '0';
 vga_b  <= vga_b_o(5 downto 2) when sw(13) = '0' else b & '0';

 -- pwm sound output (mono, left channel)
 process(clock_3p58)
 begin
   if rising_edge(clock_3p58) then
     pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned(audio & "00"));
   end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator(12);
 O_PMODAMP2_SHUTD <= not sw(15); -- sw15 up = amp shut down (audio disabled)
 O_PMODAMP2_GAIN  <= not sw(14); -- sw14 up = gain active (GAIN active low)

end struct;
