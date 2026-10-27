---------------------------------------------------------------------------------
-- Basys 3 top level for Berzerk
-- Source: berzerk_de10_lite.vhd by Dar (darfpga@aol.fr,
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
--   fire          left ctrl      fire
--   coin          5, 6                          btnU, btnD
--   start1/2      1, 2                          btnL, btnR
--   reset                                       btnC
--  Switches: sw15 audio off, sw14 gain, sw13 15 kHz RGB, sw12 cocktail
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity berzerk_basys3 is
port(
  clk  : in  std_logic;
  sw   : in  std_logic_vector(15 downto 0);
  btnC : in  std_logic;  -- reset
  btnL : in  std_logic;  -- start1
  btnR : in  std_logic;  -- start2
  btnU : in  std_logic;  -- coin
  btnD : in  std_logic;  -- coin

  JXADC   : in  std_logic_vector(4 downto 0);  -- joystick (movement + fire)
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
end berzerk_basys3;

architecture struct of berzerk_basys3 is

  signal clock_10    : std_logic;
  signal mmcm_locked : std_logic;
  signal reset       : std_logic;

  signal r     : std_logic;
  signal g     : std_logic;
  signal b     : std_logic;
  signal hi    : std_logic;
  signal csync : std_logic;
  signal hsync : std_logic;
  signal vsync : std_logic;

  signal audio           : std_logic_vector(15 downto 0);
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

  -- cocktail on sw12 (DE10 default '1').
  constant COCKTAIL_DEFAULT : std_logic := '1';
  signal cocktail_in        : std_logic;
begin

  cocktail_in <= COCKTAIL_DEFAULT xor sw(12);  -- cocktail on sw12

  -- core reset: btnC or MMCM not locked
  reset <= btnC or not mmcm_locked;

  -- MMCM: 100 MHz to clock_10
  clocks : entity work.clk_wiz_0
  port map(
    clk_in1  => clk,
    clk_out1 => clock_10,
    reset    => btnC,
    locked   => mmcm_locked
  );

  -- Berzerk
  berzerk : entity work.berzerk
  port map(
    clock_10     => clock_10,
    reset        => reset,

    tv15Khz_mode => sw(13),
    video_r      => r,
    video_g      => g,
    video_b      => b,
    video_hi     => hi,
    video_clk    => open,
    video_csync  => csync,
    video_hs     => hsync,
    video_vs     => vsync,
    audio_out    => audio,

    start2       => joy_start2,
    start1       => joy_start1,
    coin1        => joy_coin,
    cocktail     => cocktail_in,  -- sw12

    right1       => joy_right,
    left1        => joy_left,
    down1        => joy_down,
    up1          => joy_up,
    fire1        => joy_fire,

    right2       => joy_right,
    left2        => joy_left,
    down2        => joy_down,
    up2          => joy_up,
    fire2        => joy_fire,

    sw                 => (others => '0'),
    ledr               => open,
    dbg_cpu_di         => open,
    dbg_cpu_addr       => open,
    dbg_cpu_addr_latch => open
  );

  -- Expand the core's 1-bit r/g/b + intensity (hi) to 4 bits/color.
  vga_r <= "1100" when r = '1' and hi = '1' else "0100" when r = '1' and hi = '0' else "0000";
  vga_g <= "1100" when g = '1' and hi = '1' else "0100" when g = '1' and hi = '0' else "0000";
  vga_b <= "1100" when b = '1' and hi = '1' else "0100" when b = '1' and hi = '0' else "0000";

  -- video sync: csync on HS in 15 kHz mode (sw13)
  vga_hs <= csync when sw(13) = '1' else hsync;
  vga_vs <= '1'   when sw(13) = '1' else vsync;

  -- get scancode from keyboard
  keyboard : entity work.io_ps2_keyboard
  port map (
    clk       => clock_10,  -- use same clock as main core
    kbd_clk   => ps2_clk_s,
    kbd_dat   => ps2_dat_s,
    interrupt => kbd_intr,
    scancode  => kbd_scancode
  );

  -- input synchronizers
  process (clock_10)
  begin
    if rising_edge(clock_10) then
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
  process (clock_10)
  begin
    if rising_edge(clock_10) then
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
            when x"14" => kbd_joy(4) <= not kbd_rel;          -- left ctrl: fire
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
  joy_fire  <= kbd_joy(4) or not stick_s(4);  -- fire: left ctrl / stick fire

  -- coin and start: keyboard OR buttons
  joy_start1 <= kbd_joy(5) or btn_s(1);              -- start1: 1 / btnL
  joy_start2 <= kbd_joy(6) or btn_s(0);              -- start2: 2 / btnR
  joy_coin   <= kbd_joy(7) or btn_s(3) or btn_s(2);  -- coin: 5, 6 / btnU, btnD

  -- pwm sound output
  process(clock_10)  -- use same clock as sound_board
  begin
    if rising_edge(clock_10) then
      pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned('0' & audio(15 downto 4)));
    end if;
  end process;

  -- PmodAMP2: PWM audio, shutdown and gain
  O_PMODAMP2_AIN   <= pwm_accumulator(12);
  O_PMODAMP2_SHUTD <= not sw(15);
  O_PMODAMP2_GAIN  <= not sw(14);

end struct;
