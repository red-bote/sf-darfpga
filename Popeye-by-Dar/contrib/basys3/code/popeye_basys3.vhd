---------------------------------------------------------------------------------
-- Basys 3 top level for Popeye by Red~Bote, derived from popeye_de10_lite.vhd by
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
--  clk_wiz_0 derives clock_40 = 40.32 MHz from 100 MHz
--  Joystick on JXADC, OR-merged with the PS/2 keyboard (onboard USB-HID); player 2
--  mirrors player 1
--  Mono PWM audio on PmodAMP2 (JA pins 1/2/4); sw15 up = audio off, sw14 up = gain
--  Native 31 kHz VGA; sw13 = 15 kHz TV (csync on HS)
--  Keyboard: MAME default keys (arrows, Left Ctrl = punch, 1/2 = start, 5/6 = coin,
--  9 = service, held)
--  btnC = reset, btnU/btnD = coin, btnL/btnR = start
--  DIP switches: sw2 on sw7-0 (inverted), sw1 coinage on sw11-8
--  No LEDs / 7-segment
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
 btnU           : in  std_logic;  -- coin
 btnD           : in  std_logic;  -- coin
 btnL           : in  std_logic;  -- 1P start
 btnR           : in  std_logic;  -- 2P start

 JXADC             : in  std_logic_vector(4 downto 0);  -- joystick
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

 -- 2-FF synchronizers (clock_40) for the asynchronous inputs
 signal ps2_clk_meta, ps2_clk_s : std_logic := '1';
 signal ps2_dat_meta, ps2_dat_s : std_logic := '1';
 signal jxadc_meta, jxadc_s     : std_logic_vector(4 downto 0) := (others => '1');
 signal btn_meta, btn_s         : std_logic_vector(3 downto 0) := (others => '0'); -- U, D, L, R
 attribute ASYNC_REG : string;
 attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
 attribute ASYNC_REG of jxadc_meta, jxadc_s, btn_meta, btn_s : signal is "TRUE";

 signal kbd_intr      : std_logic;
 signal kbd_scancode  : std_logic_vector(7 downto 0);
 signal kbd_rel       : std_logic := '0';
 -- kbd_key: 0 up, 1 down, 2 left, 3 right, 4 left ctrl, 5 left alt,
 --           6 '1', 7 '2', 8 '5', 9 '6', 10 '9'
 signal kbd_key       : std_logic_vector(10 downto 0) := (others => '0');

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
 signal sw1_in        : std_logic_vector(6 downto 0); -- dip switch 1 (active low)
 -- DIP switches on spare board switches (PORTING_SPEC.md 3.2): switch down = DE10
 -- default, switch up inverts the bit.
 -- sw1: coinage (bits 3-0) on sw11-8; copyright (6-5) and N.U. (4) fixed.
 constant SW1_DEFAULT : std_logic_vector(6 downto 0) := not ("10" & '1' & "1111");  -- DE10 default
 signal sw2_in        : std_logic_vector(7 downto 0); -- dip switch 2 (active low)

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

  sw1            => sw1_in, -- DE10: "10" & '1' & "1111" Copyright (2b) / N.U.(1b) / coinage (4b)
  sw2            => sw2_in, -- sw7-0 (DE10: "00111101") Cocktail(1b) / Music(1b) / Bonus(2b) / diff(2b) / life(2b)

  service        => joy_service,

  dbg_cpu_addr   => open
 );

-- adapt video to 4bits/color only and blank
 vga_r <= r & '0' when blankn = '1' else "0000";
 vga_g <= g & '0' when blankn = '1' else "0000";
 vga_b <= b & "00" when blankn = '1' else "0000";

 -- Display mode switch via sw(13):
 --   0 = 31 kHz VGA (native progressive, separate H/V sync)
 --   1 = 15 kHz TV  (composite sync on HS, VS held high -- requires a 15 kHz
 --       RGB monitor or RGB->composite converter)
 vga_hs <= csync when sw(13) = '1' else hsync;
 vga_vs <= '1'   when sw(13) = '1' else vsync;

 process (reset, clock_40)
 begin
  if reset = '1' then
   clock_div <= (others => '0');
  else
   if rising_edge(clock_40) then
    if clock_div = "1001" then
     clock_div <= (others => '0');
    else
     clock_div <= clock_div + '1';
    end if;
   end if;
  end if;
 end process;

 -- synchronize asynchronous inputs to the core clock
 process (clock_40)
 begin
  if rising_edge(clock_40) then
   ps2_clk_meta <= ps2_clk;      ps2_clk_s <= ps2_clk_meta;
   ps2_dat_meta <= ps2_dat;      ps2_dat_s <= ps2_dat_meta;
   jxadc_meta   <= JXADC;        jxadc_s   <= jxadc_meta;
   btn_meta     <= btnU & btnD & btnL & btnR;
   btn_s        <= btn_meta;
  end if;
 end process;

 -- get scancode from keyboard
 keyboard : entity work.io_ps2_keyboard
 port map (
  clk       => clock_40,
  kbd_clk   => ps2_clk_s,
  kbd_dat   => ps2_dat_s,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
 );

 -- translate scancode to keys (MAME default keys, PS/2 set 2 codes), replaces
 -- kbd_joystick. F0 marks a release; E0 is ignored (keypad 8/2/4/6 alias the
 -- arrows, Right Ctrl/Alt alias Left Ctrl/Alt).
 process (clock_40)
 begin
  if rising_edge(clock_40) then
   if kbd_intr = '1' then
    if kbd_scancode = x"F0" then
     kbd_rel <= '1';
    elsif kbd_scancode /= x"E0" then
     kbd_rel <= '0';
     if kbd_scancode = x"75" then kbd_key(0)  <= not kbd_rel; end if; -- up arrow
     if kbd_scancode = x"72" then kbd_key(1)  <= not kbd_rel; end if; -- down arrow
     if kbd_scancode = x"6B" then kbd_key(2)  <= not kbd_rel; end if; -- left arrow
     if kbd_scancode = x"74" then kbd_key(3)  <= not kbd_rel; end if; -- right arrow
     if kbd_scancode = x"14" then kbd_key(4)  <= not kbd_rel; end if; -- left ctrl
     if kbd_scancode = x"11" then kbd_key(5)  <= not kbd_rel; end if; -- left alt
     if kbd_scancode = x"16" then kbd_key(6)  <= not kbd_rel; end if; -- 1
     if kbd_scancode = x"1E" then kbd_key(7)  <= not kbd_rel; end if; -- 2
     if kbd_scancode = x"2E" then kbd_key(8)  <= not kbd_rel; end if; -- 5
     if kbd_scancode = x"36" then kbd_key(9)  <= not kbd_rel; end if; -- 6
     if kbd_scancode = x"46" then kbd_key(10) <= not kbd_rel; end if; -- 9
    end if;
   end if;
  end if;
 end process;

 -- merge keyboard, buttons and JXADC joystick (active low, inverted).
 -- JXADC(0)=right (JXADC1), JXADC(1)=left (JXADC2), JXADC(2)=down (JXADC3),
 -- JXADC(3)=up (JXADC4), JXADC(4)=punch (JXADC7). Player 2 mirrors player 1.
 joy_up      <= kbd_key(0) or not jxadc_s(3);  -- up    (JXADC4)
 joy_down    <= kbd_key(1) or not jxadc_s(2);  -- down  (JXADC3)
 joy_left    <= kbd_key(2) or not jxadc_s(1);  -- left  (JXADC2)
 joy_right   <= kbd_key(3) or not jxadc_s(0);  -- right (JXADC1)
 joy_fire    <= kbd_key(4) or not jxadc_s(4);  -- punch: left ctrl (JXADC7)
 joy_coin    <= kbd_key(8) or kbd_key(9) or btn_s(3) or btn_s(2); -- 5, 6, btnU, btnD
 joy_start1  <= kbd_key(6) or btn_s(1);        -- 1 or btnL
 joy_start2  <= kbd_key(7) or btn_s(0);        -- 2 or btnR
 joy_service <= kbd_key(10);                   -- 9 (MAME service 1)
 sw1_in      <= SW1_DEFAULT xor ("000" & sw(11 downto 8));  -- coinage (bits 3-0) on sw11-8
 sw2_in      <= not sw(7 downto 0);            -- dip switch 2 from sw7-0

-- pwm sound output
 process(clock_40)
 begin
  if rising_edge(clock_40) then
   if clock_div = "0000" then
    pwm_accumulator <= ('0' & pwm_accumulator(16 downto 0)) + ('0' & audio & '0');
   end if;
  end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator(17);
 O_PMODAMP2_SHUTD <= not sw(15); -- sw15 up = amp shut down (audio disabled)
 O_PMODAMP2_GAIN  <= not sw(14); -- sw14 up = gain active (GAIN active low)

end struct;
