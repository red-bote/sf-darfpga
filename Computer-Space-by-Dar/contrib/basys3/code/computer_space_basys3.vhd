---------------------------------------------------------------------------------
-- Basys 3 top level for Computer Space
-- Source: computer_space_de10_lite.vhd by Dar (darfpga@aol.fr,
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
--   rotate CCW    left arrow     left
--   rotate CW     right arrow    right
--   thrust        up arrow       up
--   fire          left ctrl      fire
--   start         1, 2                          btnU, btnD, btnL, btnR
--   reset                                       btnC
--  Switches: sw15 audio off, sw14 gain, sw13 15 kHz RGB
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity computer_space_basys3 is
port(
  clk  : in  std_logic;  -- 100 MHz oscillator
  sw   : in  std_logic_vector(15 downto 0);
  btnC : in  std_logic;  -- reset
  btnU : in  std_logic;  -- pushbutton up (also start)
  btnD : in  std_logic;  -- pushbutton down (also start)
  btnL : in  std_logic;  -- pushbutton left (also start)
  btnR : in  std_logic;  -- pushbutton right (also start)

  JXADC   : in  std_logic_vector(4 downto 0);  -- optional joystick
  ps2_dat : in  std_logic;
  ps2_clk : in  std_logic;

  O_PMODAMP2_AIN   : out std_logic;  -- PWM audio
  O_PMODAMP2_GAIN  : out std_logic;
  O_PMODAMP2_SHUTD : out std_logic;

  vga_r  : out std_logic_vector(3 downto 0);
  vga_g  : out std_logic_vector(3 downto 0);
  vga_b  : out std_logic_vector(3 downto 0);
  vga_hs : out std_logic;
  vga_vs : out std_logic
);
end computer_space_basys3;

architecture struct of computer_space_basys3 is

  component scandoubler
  port (
    clk_sys   : in  std_logic;
    scanlines : in  std_logic_vector(1 downto 0);
    ce_x1     : in  std_logic;
    ce_x2     : in  std_logic;
    hs_in     : in  std_logic;
    vs_in     : in  std_logic;
    r_in      : in  std_logic_vector(5 downto 0);
    g_in      : in  std_logic_vector(5 downto 0);
    b_in      : in  std_logic_vector(5 downto 0);
    hs_out    : out std_logic;
    vs_out    : out std_logic;
    r_out     : out std_logic_vector(5 downto 0);
    g_out     : out std_logic_vector(5 downto 0);
    b_out     : out std_logic_vector(5 downto 0)
  );
end component;

signal clk_core    : std_logic;  -- 48.000 MHz, the only clock
signal ce_cnt      : unsigned(2 downto 0) := (others => '0');
signal game_ce     : std_logic := '0';  -- 6 MHz enable
signal game_ce_n   : std_logic := '0';  -- 6 MHz enable, half-pixel offset
signal ce_pix2     : std_logic := '0';  -- 12 MHz enable (scandoubler ce_x2)
signal mmcm_locked : std_logic;
signal reset       : std_logic;

signal hsync : std_logic;
signal vsync : std_logic;
signal csync : std_logic;
signal blank : std_logic;
signal video : std_logic_vector(3 downto 0);

signal normal_video  : std_logic_vector(3 downto 0);
signal inverse_video : std_logic_vector(3 downto 0);
signal muxed_video   : std_logic_vector(3 downto 0);

signal vga_r_i, vga_g_i, vga_b_i : std_logic_vector(5 downto 0);
signal vga_r_o, vga_g_o, vga_b_o : std_logic_vector(5 downto 0);
signal hsync_o, vsync_o          : std_logic;

signal audio           : integer range -32768 to 32767;
signal audio_us        : unsigned(16 downto 0);
signal pwm_accumulator : std_logic_vector(16 downto 0);

signal ps2_clk_s, ps2_dat_s : std_logic_vector(1 downto 0) := "11";
type sync_t is array (1 downto 0) of std_logic_vector(8 downto 0);
signal in_s : sync_t := (others => (others => '0'));
attribute ASYNC_REG : string;
attribute ASYNC_REG of ps2_clk_s, ps2_dat_s, in_s : signal is "TRUE";
signal ctl_ccw, ctl_cw, ctl_thrust, ctl_fire, ctl_start : std_logic;

signal kbd_intr     : std_logic;
signal kbd_scancode : std_logic_vector(7 downto 0);
signal kbd_rel      : std_logic := '0';
signal joyPCFRLDU   : std_logic_vector(7 downto 0) := (others => '0');

begin

-- core reset: btnC or MMCM not locked
reset <= btnC or not mmcm_locked;

-- MMCM: 100 MHz to clk_core
clocks : entity work.clk_wiz_0
port map(
  clk_in1  => clk,
  clk_out1 => clk_core,
  reset    => btnC,
  locked   => mmcm_locked
);

-- Clock enables: game_ce / game_ce_n 6 MHz (4 cycles apart), ce_pix2 12 MHz.
process(clk_core)
begin
  if rising_edge(clk_core) then
    ce_cnt    <= ce_cnt + 1;
    game_ce   <= '0';
    game_ce_n <= '0';
    ce_pix2   <= '0';
    if ce_cnt = 6 then
      game_ce <= '1';
    end if;
    if ce_cnt = 2 then
      game_ce_n <= '1';
    end if;
    if ce_cnt(1 downto 0) = "10" then
      ce_pix2 <= '1';
    end if;
  end if;
end process;

-- input synchronizers
process(clk_core)
begin
  if rising_edge(clk_core) then
    ps2_clk_s <= ps2_clk_s(0) & ps2_clk;
    ps2_dat_s <= ps2_dat_s(0) & ps2_dat;
    in_s(0)   <= btnR & btnL & btnD & btnU & JXADC;
    in_s(1)   <= in_s(0);
  end if;
end process;

-- player inputs: keyboard OR stick OR buttons; in_s(1)(4 downto 0) = stick
ctl_ccw    <= joyPCFRLDU(2) or not in_s(1)(1);  -- rotate CCW: left arrow / stick left
ctl_cw     <= joyPCFRLDU(3) or not in_s(1)(0);  -- rotate CW: right arrow / stick right
ctl_thrust <= joyPCFRLDU(0) or not in_s(1)(3);  -- thrust: up arrow / stick up
ctl_fire   <= joyPCFRLDU(4) or not in_s(1)(4);  -- fire: left ctrl / stick fire
ctl_start  <= joyPCFRLDU(6) or in_s(1)(5) or in_s(1)(6) or in_s(1)(7) or in_s(1)(8);  -- start: 1, 2 / btnU, btnD, btnL, btnR

-- get scancode from keyboard
keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clk_core,  -- synchronous clock with core
  kbd_clk   => ps2_clk_s(1),
  kbd_dat   => ps2_dat_s(1),
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- translate scancode to joystick
process(clk_core)
begin
  if rising_edge(clk_core) then
    if kbd_intr = '1' then
      if kbd_scancode = x"F0" then
        kbd_rel <= '1';
      elsif kbd_scancode /= x"E0" then
        kbd_rel <= '0';
        case kbd_scancode is
          when x"75" => joyPCFRLDU(0) <= not kbd_rel;          -- up arrow: thrust
          when x"6B" => joyPCFRLDU(2) <= not kbd_rel;          -- left arrow: CCW
          when x"74" => joyPCFRLDU(3) <= not kbd_rel;          -- right arrow: CW
          when x"14" => joyPCFRLDU(4) <= not kbd_rel;          -- left ctrl: fire
          when x"16" | x"1E" => joyPCFRLDU(6) <= not kbd_rel;  -- 1 / 2: start
          when others => null;
        end case;
      end if;
    end if;
  end if;
end process;

-----------------------------------------------------------------------
-- Computer Space core
-----------------------------------------------------------------------
computer_space_top : entity work.computer_space_top
port map(
  reset         => reset,
  clock_50      => clk_core,   -- 48 MHz (constants rescaled by patch)
  game_ce       => game_ce,    -- 6 MHz pixel enable
  game_ce_n     => game_ce_n,  -- 6 MHz enable, half-pixel offset

  signal_ccw    => ctl_ccw,
  signal_cw     => ctl_cw,
  signal_thrust => ctl_thrust,
  signal_fire   => ctl_fire,
  signal_start  => ctl_start,

  hsync         => hsync,
  vsync         => vsync,
  blank         => blank,
  video         => video,

  wav_out       => open,
  audio         => audio
);

-----------------------------------------------------------------------
-- Composite sync
-----------------------------------------------------------------------
composite_sync : entity work.composite_sync
port map(
  clk   => clk_core,
  ce    => game_ce,
  hsync => hsync,
  vsync => vsync,
  csync => csync,
  blank => open
);

-- adapt video to 4bits/color only
--   video bits layout [normal/inverse, saucer+rocket+missile, scores, stars]

with video(2 downto 0) select
  normal_video <= "0000" when "000",
  "0101" when "001",
  "1000" when "010",
  "1000" when "011",
  "1111" when others;

with video(2 downto 0) select
  inverse_video <= "0111" when "000",
  "0000" when "001",
  "0000" when "010",
  "0000" when "011",
  "0000" when others;

-- normal or inverse video (video(3))
muxed_video <= normal_video when video(3) = '0' else inverse_video;

-- Pad to 6-bit/channel for the scandoubler; forced black while blanked.
vga_r_i <= muxed_video & muxed_video(3 downto 2) when blank = '0' else "000000";
vga_g_i <= muxed_video & muxed_video(3 downto 2) when blank = '0' else "000000";
vga_b_i <= muxed_video & muxed_video(3 downto 2) when blank = '0' else "000000";

-- scandoubler: 15 kHz video to 31 kHz VGA
scandoubler_inst : scandoubler
port map (
  clk_sys   => clk_core,
  scanlines => "00",
  ce_x1     => game_ce,  -- 6 MHz pixel enable
  ce_x2     => ce_pix2,  -- 12 MHz output enable (exactly 2x ce_x1)
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
vga_hs <= hsync_o    when sw(13) = '0' else csync;
vga_vs <= vsync_o    when sw(13) = '0' else '1';
vga_r  <= vga_r_o(5 downto 2) when sw(13) = '0' else muxed_video;
vga_g  <= vga_g_o(5 downto 2) when sw(13) = '0' else muxed_video;
vga_b  <= vga_b_o(5 downto 2) when sw(13) = '0' else muxed_video;

-----------------------------------------------------------------------
-- PWM audio output
-----------------------------------------------------------------------
audio_us <= '0' & to_unsigned(audio + 32767, 16);

-- Accumulates at the 6 MHz enable rate (carrier unchanged).
process(clk_core)  -- use same clock as time_pilot_sound_board
begin
  if rising_edge(clk_core) and game_ce = '1' then
    pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(15 downto 0)) + audio_us);
  end if;
end process;

-- PmodAMP2: PWM audio, shutdown and gain
O_PMODAMP2_AIN   <= pwm_accumulator(16);
O_PMODAMP2_SHUTD <= not sw(15);
O_PMODAMP2_GAIN  <= not sw(14);

end struct;
