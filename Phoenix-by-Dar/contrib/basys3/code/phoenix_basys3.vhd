---------------------------------------------------------------------------------
-- Basys 3 top level for Phoenix
-- Source: phoenix_de10_lite.vhd by Dar (darfpga@aol.fr,
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
--   left / right  arrows         left / right
--   fire          left ctrl      fire
--   shield        left alt       up; down + fire
--   coin          5, 6                          btnU, btnD
--   start1/2      1, 2                          btnL, btnR
--   reset                                       btnC
--  Switches: sw15 audio off, sw14 gain, sw13 15 kHz RGB, sw10-8 audio select
--   (100/101/110/111 = effect1/effect2/effect3/melody solo, else mixed), sw7-0 DIP
--   switches
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity phoenix_basys3 is
port(
  clk   : in  std_logic;
  sw    : in  std_logic_vector(15 downto 0);
  btnC  : in  std_logic;                     -- reset
  btnU  : in  std_logic;                     -- coin
  btnD  : in  std_logic;                     -- coin
  btnL  : in  std_logic;                     -- start1
  btnR  : in  std_logic;                     -- start2
  JXADC : in  std_logic_vector(4 downto 0);  -- joystick

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
end phoenix_basys3;

architecture struct of phoenix_basys3 is

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

signal clock_11    : std_logic;
signal clock_50    : std_logic;
signal mmcm_locked : std_logic;
signal reset       : std_logic;

signal r         : std_logic_vector(1 downto 0);
signal g         : std_logic_vector(1 downto 0);
signal b         : std_logic_vector(1 downto 0);
signal video_clk : std_logic;
signal csync     : std_logic;

-- Real hsync/vsync from the core (exposed by a core patch)
signal hs, vs : std_logic;

signal vga_r_i, vga_g_i, vga_b_i : std_logic_vector(5 downto 0);
signal vga_r_o, vga_g_o, vga_b_o : std_logic_vector(5 downto 0);
signal hsync_o, vsync_o          : std_logic;

signal audio           : std_logic_vector(11 downto 0);
signal pwm_accumulator : std_logic_vector(12 downto 0);

signal stick_meta, stick_sync : std_logic_vector(4 downto 0) := (others => '1');
signal btn_meta, btn_sync     : std_logic_vector(3 downto 0) := (others => '0');  -- U, D, L, R
signal btn_db                 : std_logic_vector(3 downto 0) := (others => '0');
type btn_cnt_t is array (0 to 3) of unsigned(16 downto 0);
signal btn_cnt : btn_cnt_t := (others => (others => '0'));
attribute ASYNC_REG : string;
attribute ASYNC_REG of stick_meta, stick_sync, btn_meta, btn_sync : signal is "TRUE";
signal ext_joy : std_logic_vector(7 downto 0);

signal ps2_clk_meta, ps2_clk_s : std_logic := '1';
signal ps2_dat_meta, ps2_dat_s : std_logic := '1';
attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
signal kbd_intr     : std_logic;
signal kbd_scancode : std_logic_vector(7 downto 0);
signal kbd_rel      : std_logic := '0';
-- decoded keys, ext_joy bit order: 0 shield, 2 left, 3 right, 4 fire,
-- 5 start1, 6 start2, 7 coin
signal kbd_joy   : std_logic_vector(7 downto 0) := (others => '0');
signal jx_shield : std_logic;
begin

-- core reset: btnC or MMCM not locked
reset <= btnC or not mmcm_locked;

-- MMCM: 100 MHz to clock_11 and clock_50
clocks : entity work.clk_wiz_0
port map(
  clk_in1  => clk,
  clk_out1 => clock_11,
  clk_out2 => clock_50,
  reset    => btnC,
  locked   => mmcm_locked
);

-- input synchronizers and button debounce
process(clock_11)
begin
  if rising_edge(clock_11) then
    ps2_clk_meta <= ps2_clk;
    ps2_clk_s    <= ps2_clk_meta;
    ps2_dat_meta <= ps2_dat;
    ps2_dat_s    <= ps2_dat_meta;
    stick_meta   <= JXADC;
    stick_sync   <= stick_meta;
    btn_meta     <= btnU & btnD & btnL & btnR;
    btn_sync     <= btn_meta;
    -- debounce: btn_db follows btn_sync after 2**17 stable clock_11 cycles (11.9 ms)
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

-- get scancode from keyboard
keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clock_11,
  kbd_clk   => ps2_clk_s,
  kbd_dat   => ps2_dat_s,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- key decoder: scancode to kbd_joy
process(clock_11)
begin
  if rising_edge(clock_11) then
    if kbd_intr = '1' then
      if kbd_scancode = x"F0" then
        kbd_rel <= '1';
      elsif kbd_scancode /= x"E0" then
        kbd_rel <= '0';
        case kbd_scancode is
          when x"11" => kbd_joy(0) <= not kbd_rel;          -- left alt: shield
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

-- shield: stick up, up + fire or down + fire; fire passes through.
jx_shield <= (not stick_sync(3)) or ((not stick_sync(2)) and (not stick_sync(4)));

-- ext_joy, active-high, core JoyPCFRLDU bit order.
ext_joy(0) <= kbd_joy(0) or jx_shield;               -- shield: left alt / stick up, stick down + fire
ext_joy(1) <= '0';                                   -- down: no core input
ext_joy(2) <= kbd_joy(2) or not stick_sync(1);       -- left: left arrow / stick left
ext_joy(3) <= kbd_joy(3) or not stick_sync(0);       -- right: right arrow / stick right
ext_joy(4) <= kbd_joy(4) or not stick_sync(4);       -- fire: left ctrl / stick fire
ext_joy(5) <= kbd_joy(5) or btn_db(1);               -- start1: 1 / btnL
ext_joy(6) <= kbd_joy(6) or btn_db(0);               -- start2: 2 / btnR
ext_joy(7) <= kbd_joy(7) or btn_db(3) or btn_db(2);  -- coin: 5, 6 / btnU, btnD

-- Phoenix core
phoenix_inst : entity work.phoenix
port map(
  clock_50     => clock_50,
  clock_11     => clock_11,
  reset        => reset,
  dip_switch   => sw(7 downto 0),
  ext_joy      => ext_joy,
  ps2_clk      => '1',  -- idle: keyboard decoded in this wrapper
  ps2_dat      => '1',
  video_r      => r,
  video_g      => g,
  video_b      => b,
  video_clk    => video_clk,
  video_csync  => csync,
  video_hs     => hs,
  video_vs     => vs,
  audio_select => sw(10 downto 8),
  audio        => audio
);

-- Pad native 2-bit/channel RGB to the scan doubler's 6-bit/channel input
-- by triple replication. No external blanking gate is needed: the core
-- already forces video_r/g/b to "00" internally during hblank/vblank.
vga_r_i <= r & r & r;
vga_g_i <= g & g & g;
vga_b_i <= b & b & b;

-- scandoubler: 15 kHz video to 31 kHz VGA
scandoubler_inst : scandoubler
port map (
  clk_sys   => clock_11,
  scanlines => "00",
  ce_x1     => video_clk,
  ce_x2     => '1',
  hs_in     => hs,
  vs_in     => vs,
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
vga_r  <= vga_r_o(5 downto 2) when sw(13) = '0' else r & "00";
vga_g  <= vga_g_o(5 downto 2) when sw(13) = '0' else g & "00";
vga_b  <= vga_b_o(5 downto 2) when sw(13) = '0' else b & "00";

-- pwm sound output
process(clock_11)  -- use same clock as pooyan_sound_board
begin
  if rising_edge(clock_11) then
    pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned(audio & '0'));
  end if;
end process;

-- PmodAMP2: PWM audio, shutdown and gain
O_PMODAMP2_AIN   <= pwm_accumulator(12);
O_PMODAMP2_SHUTD <= not sw(15);
O_PMODAMP2_GAIN  <= not sw(14);

end struct;
