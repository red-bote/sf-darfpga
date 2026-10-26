---------------------------------------------------------------------------------
-- Basys 3 top level for Defender by Red~Bote, derived from defender_de10_lite.vhd by
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
--  clk_wiz_0 derives clock_12 = 12 MHz (core) and clock_7p16 = 7.16 MHz from 100 MHz;
--  clock_7p16 / 2 in fabric = 3.58 MHz sound board clock (below the MMCM range)
--  Joystick on JXADC (right = thrust, left = reverse), OR-merged with the PS/2
--  keyboard (onboard USB-HID); JXADC fire debounced
--  JXADC down+fire = smart bomb, up+fire = hyperspace (fire suppressed in a combo)
--  Mono PWM audio on PmodAMP2 (JA pins 1/2/4); sw15 up = audio off, sw14 up = gain
--  31 kHz VGA via the MiST scandoubler, fed from video_hs/video_vs (unused in the
--  DE10 top); sw13 = 15 kHz TV (csync on HS)
--  Keyboard: MAME default keys (up/down arrows, Left Ctrl = fire, Left Alt = thrust,
--  Z = reverse, Space = smart bomb, Left Shift = hyperspace, 1/2 = start, 5/6 = coin,
--  9 = auto-up toggle, F2 = advance, F1 = high-score reset)
--  btnC = reset, btnU/btnD = coin, btnL/btnR = start
--  DIP: sw12 = sw_coktail_table (down = upright)
--  The DE10 7-segment debug display is not ported
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
 btnD            : in  std_logic;  -- coin-in

 JXADC              : in  std_logic_vector(4 downto 0);  -- joystick (move/fire)
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
 signal pwm_prev        : std_logic_vector(12 downto 0);  -- '0' & accumulator(11:0)
 signal audio_x4        : std_logic_vector(12 downto 0);  -- '0' & audio & "00"

 -- PS/2, JXADC(4 downto 0) and btnD/btnR/btnL/btnU, 2-FF synchronized on clock_12
 -- (index 1 = output).
 signal ps2_clk_s, ps2_dat_s : std_logic_vector(1 downto 0) := "11";
 type in_sync_t is array (1 downto 0) of std_logic_vector(8 downto 0);
 signal in_s : in_sync_t := (others => (others => '1'));
 attribute ASYNC_REG : string;
 attribute ASYNC_REG of ps2_clk_s, ps2_dat_s, in_s : signal is "TRUE";
 signal ja_s   : std_logic_vector(4 downto 0);
 signal btnU_s, btnL_s, btnR_s, btnD_s : std_logic;

 signal fire_db  : std_logic := '0';
 signal fire_cnt : unsigned(16 downto 0) := (others => '0');

 signal kbd_intr       : std_logic;
 signal kbd_scancode   : std_logic_vector(7 downto 0);
 signal kbd_rel        : std_logic := '0';
 -- kbd_joy: 0 up, 1 down, 2 reverse, 3 thrust, 4 fire, 5 start1, 6 start2,
 --          7 coin, 8 smart bomb, 9 hyperspace, 10 advance, 11 high-score reset
 signal kbd_joy        : std_logic_vector(11 downto 0) := (others => '0');
 signal kbd_9_held     : std_logic := '0';
 signal auto_up        : std_logic := '0';  -- toggled by key 9

 signal joy_up      : std_logic;
 signal joy_down    : std_logic;
 signal joy_reverse : std_logic;
 signal joy_thrust  : std_logic;
 signal joy_fire    : std_logic;
 signal joy_start1  : std_logic;
 signal joy_start2  : std_logic;
 signal joy_coin    : std_logic;
 signal joy_smart_bomb : std_logic;
 signal joy_hyperspace : std_logic;

 -- DIP switch on spare board switches (PORTING_SPEC.md 3.2): switch down = DE10
 -- default, switch up inverts the bit.
 -- sw_coktail_table on sw12 (DE10 default '1' = upright).
 constant COCKTAIL_DEFAULT : std_logic := '1';
 signal cocktail_in : std_logic;
begin

cocktail_in <= COCKTAIL_DEFAULT xor sw(12);  -- cocktail on sw12

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

  btn_auto_up          => auto_up,
  btn_advance          => kbd_joy(10),
  btn_high_score_reset => kbd_joy(11),

  btn_left_coin  => joy_coin,
  btn_one_player => joy_start1,
  btn_two_players=> joy_start2,

  btn_fire       => joy_fire,
  btn_thrust     => joy_thrust,
  btn_smart_bomb => joy_smart_bomb,
  btn_hyperSpace => joy_hyperspace,
  btn_reverse    => joy_reverse,
  btn_down       => joy_down,
  btn_up         => joy_up,

  sw_coktail_table => cocktail_in, -- sw12 (down = '1', upright cabinet)
  cmd_select_players_btn => open,

  dbg_cpu_addr => open
 );

 -- Input synchronizers (2-FF) into clock_12
 process (clock_12)
 begin
   if rising_edge(clock_12) then
     ps2_clk_s <= ps2_clk_s(0) & ps2_clk;
     ps2_dat_s <= ps2_dat_s(0) & ps2_dat;
     in_s(0)   <= btnD & btnR & btnL & btnU & JXADC;
     in_s(1)   <= in_s(0);
   end if;
 end process;

 ja_s   <= in_s(1)(4 downto 0);

 -- JXADC fire debounce: fire_db follows the inverted JXADC7 after 2**17 stable
 -- clock_12 cycles (10.9 ms); the CX40-type joystick's fire contact bounces.
 process (clock_12)
 begin
   if rising_edge(clock_12) then
     if (not ja_s(4)) = fire_db then
       fire_cnt <= (others => '0');
     elsif fire_cnt = (fire_cnt'range => '1') then
       fire_db  <= not ja_s(4);
       fire_cnt <= (others => '0');
     else
       fire_cnt <= fire_cnt + 1;
     end if;
   end if;
 end process;
 btnU_s <= in_s(1)(5);
 btnL_s <= in_s(1)(6);
 btnR_s <= in_s(1)(7);
 btnD_s <= in_s(1)(8);

 -- get scancode from keyboard
 keyboard : entity work.io_ps2_keyboard
 port map (
   clk       => clock_12, -- synchronous clock with core
   kbd_clk   => ps2_clk_s(1),
   kbd_dat   => ps2_dat_s(1),
   interrupt => kbd_intr,
   scancode  => kbd_scancode
 );

 -- translate scancode to joystick (MAME default keys, PS/2 set 2 codes), replaces
 -- kbd_joystick. F0 marks a release; E0 is ignored (keypad 8/2 alias the arrows,
 -- Right Ctrl/Alt alias Left Ctrl/Alt), PORTING_SPEC.md 3.1.
 -- Key 9 toggles auto-up on its make code only (typematic repeats ignored).
 process (clock_12)
 begin
   if rising_edge(clock_12) then
     if kbd_intr = '1' then
       if kbd_scancode = x"F0" then
         kbd_rel <= '1';
       elsif kbd_scancode /= x"E0" then
         kbd_rel <= '0';
         if kbd_scancode = x"75" then kbd_joy(0)  <= not kbd_rel; end if; -- up arrow
         if kbd_scancode = x"72" then kbd_joy(1)  <= not kbd_rel; end if; -- down arrow
         if kbd_scancode = x"1A" then kbd_joy(2)  <= not kbd_rel; end if; -- Z: reverse
         if kbd_scancode = x"11" then kbd_joy(3)  <= not kbd_rel; end if; -- left alt: thrust
         if kbd_scancode = x"14" then kbd_joy(4)  <= not kbd_rel; end if; -- left ctrl: fire
         if kbd_scancode = x"16" then kbd_joy(5)  <= not kbd_rel; end if; -- 1: start 1
         if kbd_scancode = x"1E" then kbd_joy(6)  <= not kbd_rel; end if; -- 2: start 2
         if kbd_scancode = x"2E" or kbd_scancode = x"36" then kbd_joy(7) <= not kbd_rel; end if; -- 5 / 6: coin
         if kbd_scancode = x"29" then kbd_joy(8)  <= not kbd_rel; end if; -- space: smart bomb
         if kbd_scancode = x"12" then kbd_joy(9)  <= not kbd_rel; end if; -- left shift: hyperspace
         if kbd_scancode = x"06" then kbd_joy(10) <= not kbd_rel; end if; -- F2: advance
         if kbd_scancode = x"05" then kbd_joy(11) <= not kbd_rel; end if; -- F1: high-score reset
         if kbd_scancode = x"46" then                                     -- 9: auto-up toggle
           kbd_9_held <= not kbd_rel;
           if kbd_rel = '0' and kbd_9_held = '0' then auto_up <= not auto_up; end if;
         end if;
       end if;
     end if;
   end if;
 end process;

 -- OR-merge the joystick on JXADC with the PS/2 keyboard joystick. JXADC physical
 -- map: JXADC1=right(Thrust), JXADC2=left(Reverse), JXADC3=down, JXADC4=up,
 -- JXADC7=fire, i.e. JXADC(0)=right, JXADC(1)=left, JXADC(2)=down, JXADC(3)=up,
 -- JXADC(4)=fire. JXADC is
 -- active-low (pressed shorts to ground); invert so a press reads
 -- active-high, matching the core's active-high input boundary and the
 -- keyboard path.
 joy_up      <= kbd_joy(0) or not ja_s(3);   -- up      (JXADC4)
 joy_down    <= kbd_joy(1) or not ja_s(2);   -- down    (JXADC3)
 joy_reverse <= kbd_joy(2) or not ja_s(1);   -- reverse (JXADC2, left)
 joy_thrust  <= kbd_joy(3) or not ja_s(0);   -- thrust  (JXADC1, right)
 -- JXADC fire with up or down held is a combo: it drives smart bomb / hyperspace
 -- only, not fire (fire rising with the combo masks it in the game). Up/down pass
 -- through.
 joy_fire    <= kbd_joy(4) or (fire_db and ja_s(2) and ja_s(3));  -- fire (JXADC7, debounced, not in a combo)
 joy_smart_bomb <= kbd_joy(8) or (not ja_s(2) and fire_db);  -- Space / JXADC down+fire
 joy_hyperspace <= kbd_joy(9) or (not ja_s(3) and fire_db);  -- Left Shift / JXADC up+fire

 -- Coin/start: keyboard (5/6, 1, 2) and dedicated buttons are OR-merged.
 -- Buttons are active-high (Basys3 board pull-down, same convention as
 -- btnC). No fire+direction combos for coin/start.
 joy_coin   <= kbd_joy(7) or btnU_s or btnD_s;  -- coin1  = 5 / 6 or btnU / btnD
 joy_start1 <= kbd_joy(5) or btnL_s;            -- start1 = 1 or btnL
 joy_start2 <= kbd_joy(6) or btnR_s;            -- start2 = 2 or btnR

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
 vga_hs <= hsync_o             when sw(13) = '0' else csync;
 vga_vs <= vsync_o             when sw(13) = '0' else '1';
 vga_r  <= vga_r_o(5 downto 2) when sw(13) = '0' else r & '0';
 vga_g  <= vga_g_o(5 downto 2) when sw(13) = '0' else g & '0';
 vga_b  <= vga_b_o(5 downto 2) when sw(13) = '0' else b & "00";

 -- pwm sound output (audio_out is 8 bits)
 -- (concatenations assigned to typed signals first: inside a type conversion the
 --  result type of '&' is ambiguous with in_sync_t visible)
 pwm_prev <= '0' & pwm_accumulator(11 downto 0);
 audio_x4 <= "000" & audio & "00";

 process(clock_3p58)
 begin
   if rising_edge(clock_3p58) then
     pwm_accumulator <= std_logic_vector(unsigned(pwm_prev) + unsigned(audio_x4));
   end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator(12);
 O_PMODAMP2_SHUTD <= not sw(15); -- sw15 up = amp shut down (audio disabled)
 O_PMODAMP2_GAIN  <= not sw(14); -- sw14 up = gain active (GAIN active low)

end struct;
