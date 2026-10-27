---------------------------------------------------------------------------------
-- Basys 3 top level for Xevious
-- Source: xevious_de10_lite.vhd by Dar (darfpga@aol.fr,
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
--   bomb          left alt       down; up + fire
--   coin          5, 6                          btnU, btnD
--   start1/2      1, 2                          btnL, btnR
--   reset                                       btnC
--  Switches: sw15 audio off, sw14 gain, sw13 15 kHz RGB, sw12 test mode
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity xevious_basys3 is
port(
  clk  : in  std_logic;
  sw   : in  std_logic_vector(15 downto 0);
  btnC : in  std_logic;
  btnU : in  std_logic;
  btnD : in  std_logic;
  btnL : in  std_logic;
  btnR : in  std_logic;

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
end xevious_basys3;

architecture struct of xevious_basys3 is

  signal clock_18    : std_logic;
  signal reset       : std_logic;
  signal mmcm_locked : std_logic;

  signal r      : std_logic_vector(3 downto 0);
  signal g      : std_logic_vector(3 downto 0);
  signal b      : std_logic_vector(3 downto 0);
  signal csync  : std_logic;
  signal blankn : std_logic;
  signal hsync  : std_logic;
  signal vsync  : std_logic;

  signal audio           : std_logic_vector(10 downto 0);
  signal pwm_accumulator : std_logic_vector(12 downto 0);

  signal vga_r_i : std_logic_vector(5 downto 0);
  signal vga_g_i : std_logic_vector(5 downto 0);
  signal vga_b_i : std_logic_vector(5 downto 0);
  signal vga_r_o : std_logic_vector(5 downto 0);
  signal vga_g_o : std_logic_vector(5 downto 0);
  signal vga_b_o : std_logic_vector(5 downto 0);
  signal hsync_o : std_logic;
  signal vsync_o : std_logic;

  signal ce_x1, ce_x2 : std_logic;
  signal slot         : std_logic_vector(2 downto 0);

  signal rom_addr  : std_logic_vector(16 downto 0);
  signal rom_do    : std_logic_vector( 7 downto 0);
  signal clock_18n : std_logic;

  signal kbd_intr     : std_logic;
  signal kbd_scancode : std_logic_vector(7 downto 0);
  signal kbd_rel      : std_logic := '0';
  signal kbd_joy      : std_logic_vector(8 downto 0) := (others => '0');
  signal joyBCPPFRLDU : std_logic_vector(8 downto 0);

  signal ps2_clk_meta, ps2_clk_s : std_logic := '1';
  signal ps2_dat_meta, ps2_dat_s : std_logic := '1';
  signal stick_meta, stick_s     : std_logic_vector(4 downto 0) := (others => '1');
  signal btn_meta, btn_s         : std_logic_vector(3 downto 0) := (others => '0');  -- D, U, L, R
  signal btn_db                  : std_logic_vector(3 downto 0) := (others => '0');
  type btn_cnt_t is array (0 to 3) of unsigned(17 downto 0);
  signal btn_cnt : btn_cnt_t := (others => (others => '0'));
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
  attribute ASYNC_REG of stick_meta, stick_s, btn_meta, btn_s : signal is "TRUE";

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

-- DIP switch: b_test on sw12 (default '1' = off).
constant B_TEST_DEFAULT : std_logic := '1';
signal b_test_in        : std_logic;
begin

-- DIP switch
b_test_in <= B_TEST_DEFAULT xor sw(12);  -- test/service mode on sw12

-- core reset: btnC or MMCM not locked
reset <= btnC or not mmcm_locked;

-- Clock 18.432 MHz (signal name clock_18 kept) for the xevious core, the
-- scandoubler's clock chain and the PS/2 keyboard decoder (single domain).
clocks : entity work.clk_wiz_0
port map(
  clk_in1  => clk,
  clk_out1 => clock_18,
  reset    => btnC,
  locked   => mmcm_locked
);

-- Xevious core
xevious : entity work.xevious
port map(
  clock_18     => clock_18,
  reset        => reset,

  video_r      => r,
  video_g      => g,
  video_b      => b,
  video_csync  => csync,
  video_blankn => blankn,
  video_hs     => hsync,
  video_vs     => vsync,
  audio        => audio,

  rom_bus_addr_o => rom_addr,
  rom_bus_do     => rom_do,

  b_test       => b_test_in,  -- sw12 (up = test/service mode)
  b_svce       => '1',

  coin         => joyBCPPFRLDU(7),
  start2       => joyBCPPFRLDU(6),
  start1       => joyBCPPFRLDU(5),
  up           => joyBCPPFRLDU(0),
  down         => joyBCPPFRLDU(1),
  left         => joyBCPPFRLDU(2),
  right        => joyBCPPFRLDU(3),
  fire         => joyBCPPFRLDU(4),
  bomb         => joyBCPPFRLDU(8)
);

-- character/graphics ROM on the inverted core clock (asserting edge mid-slot)
clock_18n <= not clock_18;  -- signal, not an expression actual (HDL 9-3240)

rom : entity work.xevious_cpu_gfx_8bits
port map(
  clk  => clock_18n,
  addr => rom_addr,
  data => rom_do
);

-- 31 kHz VGA via the imported MiST scandoubler.
-- Pad the core's 4/4/4-bit RGB to 6 bits by MSB replication; force black during blank.
vga_r_i <= r & r(3 downto 2) when blankn = '1' else "000000";
vga_g_i <= g & g(3 downto 2) when blankn = '1' else "000000";
vga_b_i <= b & b(3 downto 2) when blankn = '1' else "000000";

-- Derive the scandoubler enable signals. The core's pixel clock is 6 MHz
-- (ena_vidgen). From the 18.432 MHz clk_sys a mod-3 counter yields:
--   cycle 0: ce_x1='1' (capture pixel) and ce_x2='1' (output 1st copy)
--   cycle 1: ce_x2='1' (output 2nd copy)
--   cycle 2: both '0'
-- giving ce_x1 = 6 MHz (input pixel rate) and ce_x2 = 12 MHz average (2x
-- input), i.e. line doubling for the scan doubler.
process (clock_18)
begin
  if rising_edge(clock_18) then
    ce_x1 <= '0';
    ce_x2 <= '0';
    if slot = "010" then
      slot <= (others => '0');
    else
      slot <= std_logic_vector(unsigned(slot) + 1);
    end if;
    if slot = "000" then
      ce_x1 <= '1';
      ce_x2 <= '1';
    elsif slot = "001" then
      ce_x2 <= '1';
    end if;
  end if;
end process;

-- scandoubler: 15 kHz video to 31 kHz VGA
scandoubler_inst : scandoubler
port map(
  clk_sys   => clock_18,
  scanlines => "00",
  ce_x1     => ce_x1,
  ce_x2     => ce_x2,
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
vga_r <= r             when sw(13) = '1' and blankn = '1' else
  vga_r_o(5 downto 2) when sw(13) = '0' else
  "0000";
vga_g <= g             when sw(13) = '1' and blankn = '1' else
  vga_g_o(5 downto 2) when sw(13) = '0' else
  "0000";
vga_b <= b             when sw(13) = '1' and blankn = '1' else
  vga_b_o(5 downto 2) when sw(13) = '0' else
  "0000";
vga_hs <= csync   when sw(13) = '1' else hsync_o;
vga_vs <= '1'     when sw(13) = '1' else vsync_o;

-- input synchronizers and button debounce
process(clock_18)
begin
  if rising_edge(clock_18) then
    ps2_clk_meta <= ps2_clk;
    ps2_clk_s    <= ps2_clk_meta;
    ps2_dat_meta <= ps2_dat;
    ps2_dat_s    <= ps2_dat_meta;
    stick_meta   <= JXADC;
    stick_s      <= stick_meta;
    btn_meta     <= btnD & btnU & btnL & btnR;
    btn_s        <= btn_meta;
    -- debounce: btn_db follows btn_s after 2**18 stable clock_18 cycles (14.2 ms);
    -- the core edge-detects coin, so release bounce would add coins
    for i in 0 to 3 loop
      if btn_s(i) = btn_db(i) then
        btn_cnt(i) <= (others => '0');
      elsif btn_cnt(i) = (btn_cnt(i)'range => '1') then
        btn_db(i)  <= btn_s(i);
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
  clk       => clock_18,
  kbd_clk   => ps2_clk_s,
  kbd_dat   => ps2_dat_s,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- key decoder: scancode to kbd_joy (bit order matches joyBCPPFRLDU below)
process (clock_18)
begin
  if rising_edge(clock_18) then
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
          when x"11" => kbd_joy(8) <= not kbd_rel;          -- left alt: bomb
          when others => null;
        end case;
      end if;
    end if;
  end if;
end process;

-- player inputs: keyboard OR stick OR buttons
-- stick down = down and bomb; up + fire also gives bomb (up and fire pass through).
-- The synchronized stick inputs (stick_s) and debounced buttons (btn_db) are used below.
joyBCPPFRLDU(0) <= kbd_joy(0) or not stick_s(3);          -- up: up arrow / stick up
joyBCPPFRLDU(1) <= kbd_joy(1) or not stick_s(2);          -- down: down arrow / stick down
joyBCPPFRLDU(2) <= kbd_joy(2) or not stick_s(1);          -- left: left arrow / stick left
joyBCPPFRLDU(3) <= kbd_joy(3) or not stick_s(0);          -- right: right arrow / stick right
joyBCPPFRLDU(4) <= kbd_joy(4) or not stick_s(4);          -- fire: left ctrl / stick fire
joyBCPPFRLDU(5) <= kbd_joy(5) or btn_db(1);               -- start1: 1 / btnL
joyBCPPFRLDU(6) <= kbd_joy(6) or btn_db(0);               -- start2: 2 / btnR
joyBCPPFRLDU(7) <= kbd_joy(7) or btn_db(2) or btn_db(3);  -- coin: 5, 6 / btnU, btnD
joyBCPPFRLDU(8) <= kbd_joy(8) or not stick_s(2)
  or (not stick_s(3) and not stick_s(4));  -- bomb: left alt / stick down, stick up + fire

-- pwm sound output
process(clock_18)
begin
  if rising_edge(clock_18) then
    pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned('0' & audio));
  end if;
end process;

-- PmodAMP2: PWM audio, shutdown and gain
O_PMODAMP2_AIN   <= pwm_accumulator(12);
O_PMODAMP2_SHUTD <= not sw(15);
O_PMODAMP2_GAIN  <= not sw(14);

end struct;
