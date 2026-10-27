---------------------------------------------------------------------------------
-- Basys 3 top level for Crazy Kong
-- Source: ckong_de10_lite.vhd by Dar (darfpga@aol.fr,
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
--   jump          left ctrl      fire
--   coin          5, 6                          btnU, btnD
--   start1/2      1, 2                          btnL, btnR
--   reset                                       btnC
--  Switches: sw15 audio off, sw14 gain, sw13 15 kHz RGB
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity ckong_basys3 is
port(
  clk  : in  std_logic;
  sw   : in  std_logic_vector(15 downto 0);
  btnC : in  std_logic;  -- reset
  btnL : in  std_logic;  -- start1
  btnR : in  std_logic;  -- start2
  btnU : in  std_logic;  -- coin
  btnD : in  std_logic;  -- coin

  JXADC   : in  std_logic_vector(4 downto 0);  -- joystick
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
end ckong_basys3;

architecture struct of ckong_basys3 is

  signal clock_12    : std_logic;
  signal mmcm_locked : std_logic;
  signal reset       : std_logic;

  signal r     : std_logic_vector(2 downto 0);
  signal g     : std_logic_vector(2 downto 0);
  signal b     : std_logic_vector(1 downto 0);
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

  signal core_up, core_down, core_left, core_right, core_fire : std_logic;
  signal core_coin1, core_start1, core_start2                 : std_logic;

begin

  -- core reset: btnC or MMCM not locked
  reset <= btnC or not mmcm_locked;

  -- MMCM: 100 MHz to clock_12
  clocks : entity work.clk_wiz_0
  port map(
    clk_in1  => clk,
    clk_out1 => clock_12,
    reset    => btnC,
    locked   => mmcm_locked
  );

  -- Crazy Kong core
  ckong_inst : entity work.ckong
  port map(
    clock_12   => clock_12,
    reset      => reset,

    tv15Khz_mode => sw(13),
    video_r      => r,
    video_g      => g,
    video_b      => b,
    video_csync  => csync,
    video_hs     => hsync,
    video_vs     => vsync,
    audio_out    => audio,

    start2  => core_start2,
    start1  => core_start1,
    coin1   => core_coin1,

    fire1   => core_fire,
    right1  => core_right,
    left1   => core_left,
    down1   => core_down,
    up1     => core_up,

    fire2   => core_fire,
    right2  => core_right,
    left2   => core_left,
    down2   => core_down,
    up2     => core_up
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

  -- key decoder: scancode to kbd_joy
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
            when x"14" => kbd_joy(4) <= not kbd_rel;          -- left ctrl: jump
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
  core_up    <= kbd_joy(0) or not stick_s(3);
  core_down  <= kbd_joy(1) or not stick_s(2);
  core_left  <= kbd_joy(2) or not stick_s(1);
  core_right <= kbd_joy(3) or not stick_s(0);
  core_fire  <= kbd_joy(4) or not stick_s(4);

  -- coin and start: keyboard OR buttons
  -- This core has a single coin input; btnU and btnD both trigger it.
  core_coin1  <= kbd_joy(7) or btn_s(3) or btn_s(2);  -- coin: 5, 6 / btnU, btnD
  core_start1 <= kbd_joy(5) or btn_s(1);              -- start1: 1 / btnL
  core_start2 <= kbd_joy(6) or btn_s(0);              -- start2: 2 / btnR

  -- video output: core RGB padded to 4 bits/color
  vga_r <= r & '0';
  vga_g <= g & '0';
  vga_b <= b & "00";

  -- video sync: csync on HS in 15 kHz mode (sw13)
  vga_hs <= csync when sw(13) = '1' else hsync;
  vga_vs <= '1'   when sw(13) = '1' else vsync;

  -- pwm sound output
  process(clock_12)  -- use same clock as sound_board
  begin
    if rising_edge(clock_12) then
      pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned('0' & audio(15 downto 4)));
    end if;
  end process;

  -- PmodAMP2: PWM audio, shutdown and gain
  O_PMODAMP2_AIN   <= pwm_accumulator(12);
  O_PMODAMP2_SHUTD <= not sw(15);
  O_PMODAMP2_GAIN  <= not sw(14);

end struct;
