---------------------------------------------------------------------------------
-- Basys 3 top level for Satan's Hollow
-- Source: satans_hollow_de10_lite.vhd by Dar (darfpga@aol.fr,
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
--   VGA monitor (15 kHz interlaced RGB with sw13 up)
--   USB keyboard on the USB-HID host connector
--   Atari-type joystick on Pmod JXADC
--   PmodAMP2 with speaker on Pmod JA
--  Controls       keyboard       stick          button
--   left / right  arrows         left / right
--   fire          left ctrl      fire
--   shield        left alt       down
--   coin1         5                             btnU
--   coin2         6                             btnD
--   start1/2      1, 2                          btnL, btnR
--   service       F2 (toggle)
--   reset                                       btnC
--  Switches: sw15 audio off, sw14 gain, sw13 15 kHz RGB, sw12 cocktail, sw11 coin meters
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity satans_hollow_basys3 is
port(
  clk  : in  std_logic;
  sw   : in  std_logic_vector(15 downto 0);
  btnC : in  std_logic;  -- reset
  btnL : in  std_logic;  -- start1
  btnR : in  std_logic;  -- start2
  btnU : in  std_logic;  -- coin1
  btnD : in  std_logic;  -- coin2

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
end satans_hollow_basys3;

architecture struct of satans_hollow_basys3 is

  signal clock_40    : std_logic;
  signal mmcm_locked : std_logic;
  signal reset       : std_logic;

  signal tv15Khz_mode : std_logic;

  signal r      : std_logic_vector(2 downto 0);
  signal g      : std_logic_vector(2 downto 0);
  signal b      : std_logic_vector(2 downto 0);
  signal csync  : std_logic;
  signal blankn : std_logic;
  signal hsync  : std_logic;
  signal vsync  : std_logic;

  signal audio_l           : std_logic_vector(15 downto 0);
  signal audio_r           : std_logic_vector(15 downto 0);
  signal pwm_accumulator_l : std_logic_vector(17 downto 0);
  signal pwm_accumulator_r : std_logic_vector(17 downto 0);

  signal clock_div : std_logic_vector(3 downto 0);

  signal ps2_clk_meta, ps2_clk_s : std_logic := '1';
  signal ps2_dat_meta, ps2_dat_s : std_logic := '1';
  signal stick_meta, stick_s     : std_logic_vector(4 downto 0) := (others => '1');
  signal btn_meta, btn_s         : std_logic_vector(3 downto 0) := (others => '0');  -- U, D, L, R
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
  attribute ASYNC_REG of stick_meta, stick_s, btn_meta, btn_s : signal is "TRUE";

  signal kbd_intr     : std_logic;
  signal kbd_scancode : std_logic_vector(7 downto 0);
  signal kbd_rel      : std_logic := '0';
  -- kbd_key: 0-1 unused, 2 left, 3 right, 4 left ctrl, 5 left alt,
  --           6 '1', 7 '2', 8 '5', 9 '6', 10 F2
  signal kbd_key   : std_logic_vector(10 downto 0) := (others => '0');
  signal kbd_f2_r  : std_logic := '0';
  signal service   : std_logic := '0';  -- toggled by F2
  signal coin1_in  : std_logic;
  signal coin2_in  : std_logic;
  signal start1_in : std_logic;
  signal start2_in : std_logic;
  signal left_in   : std_logic;
  signal right_in  : std_logic;
  signal fire_in   : std_logic;
  signal shield_in : std_logic;

  -- cocktail on sw12, coin_meters on sw11 (DE10 '0' / '0').
  constant COCKTAIL_DEFAULT          : std_logic := '0';
  constant COIN_METERS_DEFAULT       : std_logic := '0';
  signal cocktail_in, coin_meters_in : std_logic;
begin

  -- DIP switches from sw12 and sw11
  cocktail_in    <= COCKTAIL_DEFAULT xor sw(12);     -- cocktail: sw12
  coin_meters_in <= COIN_METERS_DEFAULT xor sw(11);  -- coin meters: sw11

  -- core reset: btnC or MMCM not locked
  reset <= btnC or not mmcm_locked;

  -- MMCM: 100 MHz to clock_40
  clocks : entity work.clk_wiz_0
  port map(
    clk_in1  => clk,
    clk_out1 => clock_40,
    reset    => btnC,
    locked   => mmcm_locked
  );

  -- tv15Khz_mode from sw(13) (DE10 top: not fn_toggle(7), default 15 kHz)
  tv15Khz_mode <= sw(13);

  -- Satans hollow
  satans_hollow_inst : entity work.satans_hollow
  port map(
    clock_40   => clock_40,
    reset      => reset,

    tv15Khz_mode => tv15Khz_mode,
    video_r      => r,
    video_g      => g,
    video_b      => b,
    video_csync  => csync,
    video_blankn => blankn,
    video_hs     => hsync,
    video_vs     => vsync,

    separate_audio => '0',
    audio_out_l    => audio_l,
    audio_out_r    => audio_r,

    coin1          => coin1_in,   -- coin1: 5 / btnU
    coin2          => coin2_in,   -- coin2: 6 / btnD
    start1         => start1_in,  -- start1: 1 / btnL
    start2         => start2_in,  -- start2: 2 / btnR

    left           => left_in,
    right          => right_in,
    fire1          => fire_in,    -- fire: left ctrl / stick fire
    fire2          => shield_in,  -- shield: left alt / stick down

    left_c         => left_in,
    right_c        => right_in,
    fire1_c        => fire_in,
    fire2_c        => shield_in,

    coin_meters    => coin_meters_in,  -- coin meters: sw11
    cocktail       => cocktail_in,     -- cocktail: sw12 (DE10 top: '0', F7 toggle "KO atm")

    service        => service,  -- F2 toggle (allow machine settings access)

    dbg_cpu_addr   => open
  );

  -- clock_div: PWM update enable, clock_40 / 10
  process(reset, clock_40)
  begin
    if reset = '1' then
      clock_div <= (others => '0');
    else
      if rising_edge(clock_40) then
        if clock_div = "1001" then
          clock_div <= (others => '0');
        else
          clock_div <= std_logic_vector(unsigned(clock_div) + 1);
        end if;
      end if;
    end if;
  end process;

  -- input synchronizers
  process(clock_40)
  begin
    if rising_edge(clock_40) then
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

  -- get scancode from keyboard
  keyboard : entity work.io_ps2_keyboard
  port map (
    clk       => clock_40,  -- synchronous clock with core
    kbd_clk   => ps2_clk_s,
    kbd_dat   => ps2_dat_s,
    interrupt => kbd_intr,
    scancode  => kbd_scancode
  );

  -- key decoder: scancode to kbd_key; F2 service toggle
  process(clock_40)
  begin
    if rising_edge(clock_40) then
      if kbd_intr = '1' then
        if kbd_scancode = x"F0" then
          kbd_rel <= '1';
        elsif kbd_scancode /= x"E0" then
          kbd_rel <= '0';
          case kbd_scancode is
            when x"6B" => kbd_key(2) <= not kbd_rel;   -- left arrow
            when x"74" => kbd_key(3) <= not kbd_rel;   -- right arrow
            when x"14" => kbd_key(4) <= not kbd_rel;   -- left ctrl
            when x"11" => kbd_key(5) <= not kbd_rel;   -- left alt
            when x"16" => kbd_key(6) <= not kbd_rel;   -- 1
            when x"1E" => kbd_key(7) <= not kbd_rel;   -- 2
            when x"2E" => kbd_key(8) <= not kbd_rel;   -- 5
            when x"36" => kbd_key(9) <= not kbd_rel;   -- 6
            when x"06" => kbd_key(10) <= not kbd_rel;  -- F2
            when others => null;
          end case;
        end if;
      end if;
      -- F2 toggles service mode on press (typematic repeat ignored)
      kbd_f2_r <= kbd_key(10);
      if kbd_f2_r = '0' and kbd_key(10) = '1' then
        service <= not service;
      end if;
    end if;
  end process;

  -- player inputs: keyboard OR stick OR buttons
  coin1_in  <= kbd_key(8) or btn_s(3);        -- coin1: 5 / btnU
  coin2_in  <= kbd_key(9) or btn_s(2);        -- coin2: 6 / btnD
  start1_in <= kbd_key(6) or btn_s(1);        -- start1: 1 / btnL
  start2_in <= kbd_key(7) or btn_s(0);        -- start2: 2 / btnR
  left_in   <= kbd_key(2) or not stick_s(1);  -- left: left arrow / stick left
  right_in  <= kbd_key(3) or not stick_s(0);  -- right: right arrow / stick right
  fire_in   <= kbd_key(4) or not stick_s(4);  -- fire: left ctrl / stick fire
  shield_in <= kbd_key(5) or not stick_s(2);  -- shield: left alt / stick down

  -- adapt video to 4bits/color only and blank
  vga_r <= r & '0' when blankn = '1' else "0000";
  vga_g <= g & '0' when blankn = '1' else "0000";
  vga_b <= b & '0' when blankn = '1' else "0000";

  -- video sync: csync on HS in 15 kHz mode (sw13)
  vga_hs <= csync when tv15Khz_mode = '1' else hsync;
  vga_vs <= '1'   when tv15Khz_mode = '1' else vsync;

  -- pwm sound output
  process(clock_40)  -- use same clock as kick_sound_board
  begin
    if rising_edge(clock_40) then
      if clock_div = "0000" then
        pwm_accumulator_l <= std_logic_vector(unsigned('0' & pwm_accumulator_l(16 downto 0)) + unsigned('0' & audio_l & '0'));
        pwm_accumulator_r <= std_logic_vector(unsigned('0' & pwm_accumulator_r(16 downto 0)) + unsigned('0' & audio_r & '0'));
      end if;
    end if;
  end process;

  -- PmodAMP2: PWM audio, shutdown and gain
  O_PMODAMP2_AIN   <= pwm_accumulator_l(17);
  O_PMODAMP2_SHUTD <= not sw(15);
  O_PMODAMP2_GAIN  <= not sw(14);

end struct;

