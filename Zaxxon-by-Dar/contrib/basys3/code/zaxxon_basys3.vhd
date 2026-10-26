---------------------------------------------------------------------------------
-- Basys 3 top level for Zaxxon by Red~Bote, derived from zaxxon_de10_lite.vhd by
-- Dar (darfpga@aol.fr, http://darfpga.blogspot.fr); see that file for its history.
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
--  clk_wiz_0 derives clock_24 (24.329 MHz) from 100 MHz, the only clock domain
--  Joystick on JXADC, OR-merged with the PS/2 keyboard (onboard USB-HID); no
--  joystick coin/start combos (dedicated buttons); player 2 controls mirror player 1
--  Mono PWM audio on PmodAMP2 (JA pins 1/2/4), audio_out_r open; sw15 up = audio
--  off, sw14 up = gain
--  31 kHz VGA via the MiST scandoubler; sw13 = 15 kHz TV (csync on HS)
--  A core patch drives video_hs/video_vs (undriven in the source core) and exports
--  pix_clk_div, the core's 12/6 MHz bits, for the scandoubler
--  Keyboard on clock_24: MAME default keys (arrows, Left Ctrl = fire, 1/2 = start,
--  5/6 = coin 1/2, F2 = service toggle); F4 flip and F7 cocktail toggles kept
--  Flip screen = F4 toggle xor not sw12
--  btnC = reset (MMCM and core), btnU/btnD = coin 1, btnL/btnR = start
--  PS/2 and JXADC pass 2-FF synchronizers on clock_24; buttons debounced (~10 ms)
--  7-segment debug display and led output not ported
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

 JXADC              : in  std_logic_vector(4 downto 0);  -- joystick (movement + fire)
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

 -- clk_sys (12 MHz) / ce_x1 (6 MHz) for the scandoubler, ce_x2 = '1'.
 -- pix_clk_div (exported by a core patch) is the
 -- core's own real clock_cnt(1:0): bit 0 is a clean 12 MHz square wave,
 -- bit 1 a clean 6 MHz square wave -- the exact bits pix_ena is built
 -- from, so no separate mirrored counter is needed.
 signal pix_clk_div : std_logic_vector(1 downto 0);
 signal sd_clock_12 : std_logic;
 signal sd_clock_6  : std_logic;

 signal audio_l           : std_logic_vector(15 downto 0);
 signal pwm_accumulator_l : std_logic_vector(17 downto 0);

 signal clock_div : unsigned(3 downto 0);

 -- PS/2 and JXADC(4 downto 0), 2-FF synchronized on clock_24 (index 1 = output).
 signal ps2_clk_s, ps2_dat_s : std_logic_vector(1 downto 0) := "11";
 signal ja_meta, ja_s        : std_logic_vector(4 downto 0) := (others => '1');

 signal kbd_intr      : std_logic;
 signal kbd_scancode  : std_logic_vector(7 downto 0);
 signal kbd_rel       : std_logic := '0';
 -- kbd_joy: 0 up, 1 down, 2 left, 3 right, 4 fire, 5 coin1, 6 coin2, 7 start1, 8 start2
 signal kbd_joy       : std_logic_vector(8 downto 0) := (others => '0');
 -- key held (typematic filter) and toggles: 0 = F2 service, 1 = F4 flip, 2 = F7 cocktail
 signal fn_held       : std_logic_vector(2 downto 0) := (others => '0');
 signal fn_toggle     : std_logic_vector(2 downto 0) := (others => '0');

 signal core_up, core_down, core_left, core_right, core_fire : std_logic;
 signal core_coin1, core_coin2, core_start1, core_start2     : std_logic;

 -- Button debounce: 2-FF synchronizer, then the output follows
 -- the input only after it has been stable for 2**18 clock_24 cycles
 -- (24.33 MHz: 10.8 ms). This core edge-detects coin on press,
 -- so release bounce counted extra coins.
 signal flip_sel : std_logic;  -- display flip: F4 toggle xor not sw(12)
 signal btn_raw, btn_meta, btn_sync, btn_db : std_logic_vector(3 downto 0) := (others => '0');  -- U, D, L, R
 type btn_cnt_t is array (0 to 3) of unsigned(17 downto 0);
 signal btn_cnt : btn_cnt_t := (others => (others => '0'));
 attribute ASYNC_REG : string;
 attribute ASYNC_REG of btn_meta, btn_sync : signal is "TRUE";
 attribute ASYNC_REG of ps2_clk_s, ps2_dat_s, ja_meta, ja_s : signal is "TRUE";
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
  coin2        => core_coin2,
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

  cocktail     => fn_toggle(2), -- F7
  service      => fn_toggle(0), -- F2
  flip_screen  => flip_sel,     -- F4 toggle xor not sw(12)

  dbg_cpu_addr => open
 );

 -- clock_div gates the PWM accumulator update below; the keyboard runs on clock_24.
 process (reset, clock_24)
 begin
   if reset = '1' then
     clock_div <= (others => '0');
   elsif rising_edge(clock_24) then
     if clock_div = "0010" then
       clock_div <= (others => '0');
     else
       clock_div <= clock_div + 1;
     end if;
   end if;
 end process;

 -- clk_sys/ce_x1 for the scandoubler, straight from the core's real
 -- pix_clk_div (see the signal declaration comment above).
 sd_clock_12 <= pix_clk_div(0);
 sd_clock_6  <= pix_clk_div(1);

 -- PS/2 and JXADC input synchronizers (2-FF) into clock_24
 process (clock_24)
 begin
   if rising_edge(clock_24) then
     ps2_clk_s <= ps2_clk_s(0) & ps2_clk;
     ps2_dat_s <= ps2_dat_s(0) & ps2_dat;
     ja_meta   <= JXADC;
     ja_s      <= ja_meta;
   end if;
 end process;

 -- get scancode from keyboard
 keyboard : entity work.io_ps2_keyboard
 port map (
   clk       => clock_24, -- core clock, single domain
   kbd_clk   => ps2_clk_s(1),
   kbd_dat   => ps2_dat_s(1),
   interrupt => kbd_intr,
   scancode  => kbd_scancode
 );

 -- translate scancode to joystick (MAME default keys, PS/2 set 2 codes), replaces
 -- kbd_joystick. F0 marks a release; E0 is ignored (keypad 8/2/4/6 alias the arrows,
 -- Right Ctrl aliases Left Ctrl), PORTING_SPEC.md 3.1.
 -- F2/F4/F7 toggle on the make code only (typematic repeats ignored).
 process (clock_24)
 begin
   if rising_edge(clock_24) then
     if kbd_intr = '1' then
       if kbd_scancode = x"F0" then
         kbd_rel <= '1';
       elsif kbd_scancode /= x"E0" then
         kbd_rel <= '0';
         if kbd_scancode = x"75" then kbd_joy(0) <= not kbd_rel; end if; -- up arrow
         if kbd_scancode = x"72" then kbd_joy(1) <= not kbd_rel; end if; -- down arrow
         if kbd_scancode = x"6B" then kbd_joy(2) <= not kbd_rel; end if; -- left arrow
         if kbd_scancode = x"74" then kbd_joy(3) <= not kbd_rel; end if; -- right arrow
         if kbd_scancode = x"14" then kbd_joy(4) <= not kbd_rel; end if; -- left ctrl: fire
         if kbd_scancode = x"2E" then kbd_joy(5) <= not kbd_rel; end if; -- 5: coin 1
         if kbd_scancode = x"36" then kbd_joy(6) <= not kbd_rel; end if; -- 6: coin 2
         if kbd_scancode = x"16" then kbd_joy(7) <= not kbd_rel; end if; -- 1: start 1
         if kbd_scancode = x"1E" then kbd_joy(8) <= not kbd_rel; end if; -- 2: start 2
         if kbd_scancode = x"06" then                                    -- F2: service toggle
           fn_held(0) <= not kbd_rel;
           if kbd_rel = '0' and fn_held(0) = '0' then fn_toggle(0) <= not fn_toggle(0); end if;
         end if;
         if kbd_scancode = x"0C" then                                    -- F4: flip toggle
           fn_held(1) <= not kbd_rel;
           if kbd_rel = '0' and fn_held(1) = '0' then fn_toggle(1) <= not fn_toggle(1); end if;
         end if;
         if kbd_scancode = x"83" then                                    -- F7: cocktail toggle
           fn_held(2) <= not kbd_rel;
           if kbd_rel = '0' and fn_held(2) = '0' then fn_toggle(2) <= not fn_toggle(2); end if;
         end if;
       end if;
     end if;
   end if;
 end process;

 -- OR-merge the joystick on JXADC with the PS/2 keyboard joystick. JXADC physical
 -- map: JXADC1=right, JXADC2=left, JXADC3=down, JXADC4=up, JXADC7=fire, i.e.
 -- JXADC(0)=right, JXADC(1)=left, JXADC(2)=down, JXADC(3)=up, JXADC(4)=fire. JXADC is
 -- active-low (pressed shorts to ground); invert so a press reads active-high,
 -- matching the core's active-high input boundary and the keyboard path.
 core_up    <= kbd_joy(0) or not ja_s(3);  -- up    (JXADC4)
 core_down  <= kbd_joy(1) or not ja_s(2);  -- down  (JXADC3)
 core_left  <= kbd_joy(2) or not ja_s(1);  -- left  (JXADC2)
 core_right <= kbd_joy(3) or not ja_s(0);  -- right (JXADC1)
 core_fire  <= kbd_joy(4) or not ja_s(4);  -- fire  (JXADC7)

 -- Coin/start: keyboard (5/6, 1/2) OR-merged with dedicated buttons.
 -- Buttons are active-high (Basys3 board pull-down, same convention as
 -- btnC). btnU and btnD both trigger coin 1; key 6 = coin 2.
-- Button debounce (see declarations).
flip_sel <= fn_toggle(1) xor not sw(12);  -- F4 toggle xor not sw(12)
btn_raw <= btnU & btnD & btnL & btnR;
process(clock_24)
begin
  if rising_edge(clock_24) then
    btn_meta <= btn_raw;
    btn_sync <= btn_meta;
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

 core_coin1  <= kbd_joy(5) or btn_db(3) or btn_db(2);  -- coin 1 = 5 or btnU or btnD
 core_coin2  <= kbd_joy(6);                            -- coin 2 = 6
 core_start1 <= kbd_joy(7) or btn_db(1);     -- start1 = 1 or btnL
 core_start2 <= kbd_joy(8) or btn_db(0);     -- start2 = 2 or btnR

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
 vga_hs <= hsync_o             when sw(13) = '0' else csync;
 vga_vs <= vsync_o             when sw(13) = '0' else '1';
 vga_r  <= vga_r_o(5 downto 2) when sw(13) = '0' else r & '0';
 vga_g  <= vga_g_o(5 downto 2) when sw(13) = '0' else g & '0';
 vga_b  <= vga_b_o(5 downto 2) when sw(13) = '0' else b & "00";

 -- pwm sound output (left channel only; gated by clock_div)
 process(clock_24)
 begin
   if rising_edge(clock_24) then
     if clock_div = "0000" then
       pwm_accumulator_l <= std_logic_vector(unsigned('0' & pwm_accumulator_l(16 downto 0)) + unsigned('0' & audio_l & '0'));
     end if;
   end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator_l(17);
 O_PMODAMP2_SHUTD <= not sw(15); -- sw15 up = amp shut down (audio disabled)
 O_PMODAMP2_GAIN  <= not sw(14); -- sw14 up = gain active (GAIN active low)

end struct;
