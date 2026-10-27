---------------------------------------------------------------------------------
-- Basys 3 top level for Time Pilot
-- Source: time_pilot_de10_lite.vhd by Dar (darfpga@aol.fr,
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
--  Switches: sw15 audio off, sw14 gain, sw13 15 kHz RGB,
--   sw11-8 coinage A (DIP 1 bits 3-0), sw7-0 DIP 2
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;

entity time_pilot_basys3 is
port(
  clk  : in  std_logic;
  sw   : in  std_logic_vector(15 downto 0);
  btnC : in  std_logic;
  btnU : in  std_logic;  -- coin
  btnD : in  std_logic;  -- coin
  btnL : in  std_logic;  -- start1
  btnR : in  std_logic;  -- start2

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
end time_pilot_basys3;

architecture struct of time_pilot_basys3 is

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

signal clk_core    : std_logic;  -- 24.573991 MHz, the only clock
signal mmcm_locked : std_logic;
signal reset_s     : std_logic_vector(1 downto 0) := "11";
signal reset       : std_logic;
attribute ASYNC_REG : string;
attribute ASYNC_REG of reset_s : signal is "TRUE";

signal ph       : std_logic_vector(1 downto 0) := "00";
signal ce6      : std_logic;  -- e0
signal ce6n     : std_logic;  -- e2
signal ce12     : std_logic;  -- e0, e2
signal ce12n    : std_logic;  -- e1, e3
signal clk6_lvl : std_logic;  -- clock_6 equivalent level: '1' from e0 to e2

constant CE14_INC : unsigned(20 downto 0) := to_unsigned(610959, 21);
signal ce14_acc   : unsigned(20 downto 0) := (others => '0');
signal ce14       : std_logic;

signal r      : std_logic_vector(4 downto 0);
signal g      : std_logic_vector(4 downto 0);
signal b      : std_logic_vector(4 downto 0);
signal csync  : std_logic;
signal blankn : std_logic;
signal hsync  : std_logic;
signal vsync  : std_logic;

signal audio           : std_logic_vector(10 downto 0);
signal pwm_accumulator : std_logic_vector(12 downto 0);
signal pwm_prev        : std_logic_vector(12 downto 0);  -- '0' & accumulator(11:0)
signal audio_x4        : std_logic_vector(12 downto 0);  -- audio & "00"

signal vga_ro   : std_logic_vector(5 downto 0);
signal vga_go   : std_logic_vector(5 downto 0);
signal vga_bo   : std_logic_vector(5 downto 0);
signal vga_hs_o : std_logic;
signal vga_vs_o : std_logic;

signal video_ri : std_logic_vector(5 downto 0);
signal video_gi : std_logic_vector(5 downto 0);
signal video_bi : std_logic_vector(5 downto 0);

signal ps2_clk_s, ps2_dat_s : std_logic_vector(1 downto 0) := "11";
type in_sync_t is array (1 downto 0) of std_logic_vector(8 downto 0);
signal in_s : in_sync_t := (others => (others => '1'));
attribute ASYNC_REG of ps2_clk_s, ps2_dat_s, in_s : signal is "TRUE";
signal stick_s                        : std_logic_vector(4 downto 0);
signal btnU_s, btnL_s, btnR_s, btnD_s : std_logic;

signal kbd_intr     : std_logic;
signal kbd_scancode : std_logic_vector(7 downto 0);
signal kbd_rel      : std_logic := '0';
signal kbd_joy      : std_logic_vector(7 downto 0) := (others => '0');
signal joyPCFRLDU   : std_logic_vector(7 downto 0);

signal dbg_cpu_addr : std_logic_vector(15 downto 0);

-- dip_switch_1: Coinage_A (bits 3-0) on sw11-8; Coinage_B (bits 7-4) fixed.
constant DIP1_DEFAULT : std_logic_vector(7 downto 0) := X"FF";
signal dip1           : std_logic_vector(7 downto 0);
begin

-- DIP switch 1 from sw11-8
dip1 <= DIP1_DEFAULT xor (x"0" & sw(11 downto 8));  -- Coinage_A on sw11-8

-- MMCM: 100 MHz to clk_core
clocks : entity work.clk_wiz_0
port map(
  clk_in1  => clk,
  clk_out1 => clk_core,
  reset    => btnC,
  locked   => mmcm_locked
);

-- Reset asserted asynchronously, released synchronously to clk_core.
process (clk_core, btnC, mmcm_locked)
begin
  if btnC = '1' or mmcm_locked = '0' then
    reset_s <= "11";
  elsif rising_edge(clk_core) then
    reset_s <= reset_s(0) & '0';
  end if;
end process;
reset <= reset_s(1);

-- Clock enables
-- Phase counter: 4 clk_core edges per 6 MHz period.
--   e0 = clock_6 rising (end of ph="11"), e1 = clock_12 falling (ph="00"),
--   e2 = clock_6 falling (ph="01"),       e3 = clock_12 falling (ph="10").
-- 14.318181 MHz sound enable: 20-bit phase accumulator,
-- 610959 / 2^20 x 24.573991 MHz = 14.318181 MHz (-0.06 ppm vs 315/22 MHz).
process (clk_core)
begin
  if rising_edge(clk_core) then
    if reset = '1' then
      ph <= "00";
    else
      ph <= ph + '1';
    end if;
    ce14_acc <= ('0' & ce14_acc(19 downto 0)) + CE14_INC;
  end if;
end process;

-- clock enables from the phase counter and the sound accumulator
ce6      <= '1' when ph = "11" else '0';
ce6n     <= '1' when ph = "01" else '0';
ce12     <= ph(0);
ce12n    <= not ph(0);
clk6_lvl <= not ph(1);
ce14     <= ce14_acc(20);

-- Time pilot
time_pilot : entity work.time_pilot
port map(
  clk_core   => clk_core,
  ce6        => ce6,
  ce6n       => ce6n,
  ce12       => ce12,
  ce12n      => ce12n,
  clk6_lvl   => clk6_lvl,
  ce14       => ce14,
  reset      => reset,

  video_r      => r,
  video_g      => g,
  video_b      => b,
  video_csync  => csync,
  video_blankn => blankn,
  video_hs     => hsync,
  video_vs     => vsync,
  audio_out    => audio,

  dip_switch_1 => dip1,            -- Coinage_B (fixed) / Coinage_A (sw11-8)
  dip_switch_2 => sw(7 downto 0),  -- Sound(8)/Difficulty(7-5)/Bonus(4)/Cocktail(3)/lives(2-1)

  start2      => joyPCFRLDU(7),
  start1      => joyPCFRLDU(6),
  coin1       => joyPCFRLDU(5),

  fire1       => joyPCFRLDU(4),
  right1      => joyPCFRLDU(3),
  left1       => joyPCFRLDU(2),
  down1       => joyPCFRLDU(1),
  up1         => joyPCFRLDU(0),

  fire2       => joyPCFRLDU(4),
  right2      => joyPCFRLDU(3),
  left2       => joyPCFRLDU(2),
  down2       => joyPCFRLDU(1),
  up2         => joyPCFRLDU(0),

  dbg_cpu_addr => dbg_cpu_addr
);

-- 31 kHz VGA via the MiST scandoubler; RGB gated on blankn (black during blank).
-- Core outputs 5 bits/color; pad 1 bit.
video_ri <= (r & "0") when blankn = '1' else "000000";
video_gi <= (g & "0") when blankn = '1' else "000000";
video_bi <= (b & "0") when blankn = '1' else "000000";

scandoubler_inst : scandoubler
port map(
  clk_sys   => clk_core,
  scanlines => "00",
  ce_x1     => ce6,   -- 6.1435 MHz pixel enable
  ce_x2     => ce12,  -- exactly 2 x ce_x1
  hs_in     => hsync,
  vs_in     => vsync,
  r_in      => video_ri,
  g_in      => video_gi,
  b_in      => video_bi,
  hs_out    => vga_hs_o,
  vs_out    => vga_vs_o,
  r_out     => vga_ro,
  g_out     => vga_go,
  b_out     => vga_bo
);

-- video output: scandoubler or 15 kHz RGB (sw13)
vga_r  <= vga_ro(5 downto 2) when sw(13) = '0' else video_ri(5 downto 2);
vga_g  <= vga_go(5 downto 2) when sw(13) = '0' else video_gi(5 downto 2);
vga_b  <= vga_bo(5 downto 2) when sw(13) = '0' else video_bi(5 downto 2);
vga_hs <= vga_hs_o           when sw(13) = '0' else csync;
vga_vs <= vga_vs_o           when sw(13) = '0' else '1';

-- input synchronizers
process (clk_core)
begin
  if rising_edge(clk_core) then
    ps2_clk_s <= ps2_clk_s(0) & ps2_clk;
    ps2_dat_s <= ps2_dat_s(0) & ps2_dat;
    in_s(0)   <= btnD & btnR & btnL & btnU & JXADC;
    in_s(1)   <= in_s(0);
  end if;
end process;

-- synchronized stick and buttons
stick_s <= in_s(1)(4 downto 0);
btnU_s  <= in_s(1)(5);
btnL_s  <= in_s(1)(6);
btnR_s  <= in_s(1)(7);
btnD_s  <= in_s(1)(8);

-- get scancode from keyboard
keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clk_core,  -- synchronous clock with core
  kbd_clk   => ps2_clk_s(1),
  kbd_dat   => ps2_dat_s(1),
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- key decoder: scancode to kbd_joy
-- kbd_joy bit order matches joyPCFRLDU below: 5 = coin, 6 = start1, 7 = start2.
process (clk_core)
begin
  if rising_edge(clk_core) then
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
          when x"2E" | x"36" => kbd_joy(5) <= not kbd_rel;  -- 5 / 6: coin
          when x"16" => kbd_joy(6) <= not kbd_rel;          -- 1: start1
          when x"1E" => kbd_joy(7) <= not kbd_rel;          -- 2: start2
          when others => null;
        end case;
      end if;
    end if;
  end if;
end process;

-- player inputs: keyboard OR stick OR buttons
joyPCFRLDU(0) <= kbd_joy(0) or not stick_s(3);    -- up: up arrow / stick up
joyPCFRLDU(1) <= kbd_joy(1) or not stick_s(2);    -- down: down arrow / stick down
joyPCFRLDU(2) <= kbd_joy(2) or not stick_s(1);    -- left: left arrow / stick left
joyPCFRLDU(3) <= kbd_joy(3) or not stick_s(0);    -- right: right arrow / stick right
joyPCFRLDU(4) <= kbd_joy(4) or not stick_s(4);    -- fire: left ctrl / stick fire
joyPCFRLDU(5) <= kbd_joy(5) or btnU_s or btnD_s;  -- coin: 5, 6 / btnU, btnD
joyPCFRLDU(6) <= kbd_joy(6) or btnL_s;            -- start1: 1 / btnL
joyPCFRLDU(7) <= kbd_joy(7) or btnR_s;            -- start2: 2 / btnR

-- pwm sound output
-- (concatenations assigned to typed signals first: inside a type conversion the
--  result type of '&' is ambiguous with numeric_std and std_logic_unsigned visible)
pwm_prev <= '0' & pwm_accumulator(11 downto 0);
audio_x4 <= audio & "00";

-- PWM accumulator on the sound enable
process(clk_core)  -- use same clock as time_pilot_sound_board
begin
  if rising_edge(clk_core) and ce14 = '1' then
    pwm_accumulator <= std_logic_vector(unsigned(pwm_prev) + unsigned(audio_x4));
  end if;
end process;

-- PmodAMP2: PWM audio, shutdown and gain
O_PMODAMP2_AIN   <= pwm_accumulator(12);
O_PMODAMP2_SHUTD <= not sw(15);
O_PMODAMP2_GAIN  <= not sw(14);

end struct;
