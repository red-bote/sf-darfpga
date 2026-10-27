---------------------------------------------------------------------------------
-- Basys 3 top level for Burger Time
-- Source: burger_time_de10_lite.vhd by Dar (darfpga@aol.fr,
--   http://darfpga.blogspot.fr); see that file for its history.
---------------------------------------------------------------------------------
--
-- 10/26/2026: initial Basys 3 release by Red~Bote
--
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthesized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
--
-- Main features:
--  Connections:
--   VGA monitor (15 kHz RGB monitor with sw13 up)
--   USB keyboard on the USB-HID host connector
--   Atari-type joystick on Pmod JXADC
--   PmodAMP2 with speaker on Pmod JA
--  Controls       keyboard       stick          button
--   up / down     arrows         up / down
--   left / right  arrows         left / right
--   pepper        left ctrl      fire
--   coin          5, 6                          btnU, btnD
--   start1/2      1, 2                          btnL, btnR
--   reset                                       btnC
--  Switches: sw15 audio off, sw14 gain, sw13 15 kHz RGB
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity burger_time_basys3 is
port(
  clk  : in  std_logic;
  sw   : in  std_logic_vector(15 downto 0);
  btnC : in  std_logic;  -- reset
  btnL : in  std_logic;  -- start1
  btnR : in  std_logic;  -- start2
  btnU : in  std_logic;  -- coin
  btnD : in  std_logic;  -- coin

  JXADC   : in  std_logic_vector(4 downto 0);  -- joystick (movement + pepper)
  ps2_dat : in  std_logic;
  ps2_clk : in  std_logic;

  O_PMODAMP2_AIN   : out std_logic;
  O_PMODAMP2_GAIN  : out std_logic;
  O_PMODAMP2_SHUTD : out std_logic;

  vga_r  : out std_logic_vector(3 downto 0);
  vga_g  : out std_logic_vector(3 downto 0);
  vga_b  : out std_logic_vector(3 downto 0);
  vga_hs : out std_logic;
  vga_vs : out std_logic
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

signal kbd_intr     : std_logic;
signal kbd_scancode : std_logic_vector(7 downto 0);
signal kbd_rel      : std_logic := '0';
signal kbd_joy      : std_logic_vector(7 downto 0) := (others => '0');

signal ps2_clk_meta, ps2_clk_s : std_logic := '1';
signal ps2_dat_meta, ps2_dat_s : std_logic := '1';
signal stick_meta, stick_s     : std_logic_vector(4 downto 0) := (others => '1');
signal btn_meta, btn_s         : std_logic_vector(3 downto 0) := (others => '0');  -- U, D, L, R
attribute ASYNC_REG : string;
attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
attribute ASYNC_REG of stick_meta, stick_s, btn_meta, btn_s : signal is "TRUE";

signal joy_up     : std_logic;
signal joy_down   : std_logic;
signal joy_left   : std_logic;
signal joy_right  : std_logic;
signal joy_fire   : std_logic;
signal joy_start1 : std_logic;
signal joy_start2 : std_logic;
signal joy_coin   : std_logic;

begin

-- core reset: btnC or MMCM not locked
reset <= btnC or not mmcm_locked;

-- Scandoubler ce_x1: 6 MHz pixel-rate enable made by toggling on clock_12
-- (single clock domain; a separate MMCM output used as this enable fails hold
-- timing in the clock_12 domain).
process(clock_12)
begin
  if rising_edge(clock_12) then
    clock_6 <= not clock_6;
  end if;
end process;

-- MMCM: 100 MHz to clock_12
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
  clk       => clock_12,  -- use same clock as main core
  kbd_clk   => ps2_clk_s,
  kbd_dat   => ps2_dat_s,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- input synchronizers
process (clock_12)
begin
  if rising_edge(clock_12) then
    ps2_clk_meta <= ps2_clk;
    ps2_clk_s    <= ps2_clk_meta;
    ps2_dat_meta <= ps2_dat;
    ps2_dat_s    <= ps2_dat_meta;
    stick_meta   <= JXADC;
    stick_s      <= stick_meta;
    btn_meta     <= btnU & btnD & btnL & btnR;
    btn_s        <= btn_meta;
  end if;
end process;

-- translate scancode to joystick
-- kbd_joy keeps the joyHBCPPFRLDU bit order: 5 = start1, 6 = start2, 7 = coin.
process (clock_12)
begin
  if rising_edge(clock_12) then
    if kbd_intr = '1' then
      if kbd_scancode = x"F0" then
        kbd_rel <= '1';
      elsif kbd_scancode /= x"E0" then
        kbd_rel <= '0';
        case kbd_scancode is
          when x"75" => kbd_joy(0) <= not kbd_rel;          -- up arrow
          when x"72" => kbd_joy(1) <= not kbd_rel;          -- down arrow
          when x"6B" => kbd_joy(2) <= not kbd_rel;          -- left arrow
          when x"74" => kbd_joy(3) <= not kbd_rel;          -- right arrow
          when x"14" => kbd_joy(4) <= not kbd_rel;          -- left ctrl: pepper
          when x"16" => kbd_joy(5) <= not kbd_rel;          -- 1: start1
          when x"1E" => kbd_joy(6) <= not kbd_rel;          -- 2: start2
          when x"2E" | x"36" => kbd_joy(7) <= not kbd_rel;  -- 5 / 6: coin
          when others => null;
        end case;
      end if;
    end if;
  end if;
end process;

-- player inputs: keyboard OR stick
joy_up    <= kbd_joy(0) or not stick_s(3);  -- up: up arrow / stick up
joy_down  <= kbd_joy(1) or not stick_s(2);  -- down: down arrow / stick down
joy_left  <= kbd_joy(2) or not stick_s(1);  -- left: left arrow / stick left
joy_right <= kbd_joy(3) or not stick_s(0);  -- right: right arrow / stick right
joy_fire  <= kbd_joy(4) or not stick_s(4);  -- pepper: left ctrl / stick fire

-- coin and start: keyboard OR buttons
joy_coin   <= kbd_joy(7) or btn_s(3) or btn_s(2);  -- coin: 5, 6 / btnU, btnD
joy_start1 <= kbd_joy(5) or btn_s(1);              -- start1: 1 / btnL
joy_start2 <= kbd_joy(6) or btn_s(0);              -- start2: 2 / btnR

-- Pad native 3/3/2-bit RGB to the scan doubler's 6-bit/channel input by
-- MSB replication, forced to black while blanked.
vga_r_i <= r & r     when blankn = '1' else "000000";
vga_g_i <= g & g     when blankn = '1' else "000000";
vga_b_i <= b & b & b when blankn = '1' else "000000";

-- scandoubler: 15 kHz video to 31 kHz VGA
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

-- video output: scandoubler or 15 kHz RGB (sw13)
vga_hs <= hsync_o             when sw(13) = '0' else csync;
vga_vs <= vsync_o             when sw(13) = '0' else '1';
vga_r  <= vga_r_o(5 downto 2) when sw(13) = '0' else r & '0';
vga_g  <= vga_g_o(5 downto 2) when sw(13) = '0' else g & '0';
vga_b  <= vga_b_o(5 downto 2) when sw(13) = '0' else b & "00";

-- pwm sound output
process(clock_12)  -- use same clock as pooyan_sound_board
begin
  if rising_edge(clock_12) then
    pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned(audio & "00"));
  end if;
end process;

-- PmodAMP2: PWM audio, shutdown and gain
O_PMODAMP2_AIN   <= pwm_accumulator(12);
O_PMODAMP2_SHUTD <= not sw(15);
O_PMODAMP2_GAIN  <= not sw(14);

end struct;
