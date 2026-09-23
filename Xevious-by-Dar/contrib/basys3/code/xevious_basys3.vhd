---------------------------------------------------------------------------------
-- Basys3 Top level for Xevious (Namco, 1982) by Dar (darfpga@aol.fr) (05/01/2017)
-- http://darfpga.blogspot.fr
--
-- Basys3 port.
--
-- Ported from xevious_de10_lite.vhd (DE10-lite 2017/05/01):
--  - 100 MHz board oscillator; clk_wiz_0 MMCM derives 18 MHz core + 11 MHz PS/2
--  - Atari-style joystick on JA, OR-merged with PS/2 keyboard (JB)
--  - Mono PWM audio on PmodAMP2 (JC); sw(14) = shutdown, sw(15) = gain select
--  - 31 kHz VGA on the Basys3 VGA connector via the imported MiST scandoubler;
--    sw(13) switches to 15 kHz TV (native RGB + composite sync on HS)
--  - btnC = reset; btnU = coin, btnL = start1, btnR = start2
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity xevious_basys3 is
port(
 clk            : in  std_logic;
 sw             : in  std_logic_vector(15 downto 0);
 btnC           : in  std_logic;
 btnU           : in  std_logic;
 btnL           : in  std_logic;
 btnR           : in  std_logic;

 JA             : in  std_logic_vector(4 downto 0);  -- joystick

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
end xevious_basys3;

architecture struct of xevious_basys3 is

 signal clock_18 : std_logic;
 signal clock_11 : std_logic;
 signal reset    : std_logic;
 signal mmcm_reset : std_logic := '0';

 signal r         : std_logic_vector(3 downto 0);
 signal g         : std_logic_vector(3 downto 0);
 signal b         : std_logic_vector(3 downto 0);
 signal csync     : std_logic;
 signal blankn    : std_logic;
 signal hsync     : std_logic;
 signal vsync     : std_logic;

 signal audio           : std_logic_vector(10 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);

 signal vga_r_i  : std_logic_vector(5 downto 0);
 signal vga_g_i  : std_logic_vector(5 downto 0);
 signal vga_b_i  : std_logic_vector(5 downto 0);
 signal vga_r_o  : std_logic_vector(5 downto 0);
 signal vga_g_o  : std_logic_vector(5 downto 0);
 signal vga_b_o  : std_logic_vector(5 downto 0);
 signal hsync_o  : std_logic;
 signal vsync_o  : std_logic;

 signal ce_x1, ce_x2 : std_logic;
 signal slot         : std_logic_vector(2 downto 0);

 signal rom_addr : std_logic_vector(16 downto 0);
 signal rom_do   : std_logic_vector( 7 downto 0);

 signal kbd_intr     : std_logic;
 signal kbd_scancode : std_logic_vector(7 downto 0);
 signal kbd_joy      : std_logic_vector(8 downto 0);
 signal joyBCPPFRLDU : std_logic_vector(8 downto 0);

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

begin

reset <= btnC;

-- Clock 18MHz for the xevious core and the scandoubler's clock chain,
-- 11MHz for the PS/2 keyboard decoder.
clocks : entity work.clk_wiz_0
port map(
 clk_in1  => clk,
 clk_out1 => clock_18,
 clk_out2 => clock_11,
 reset    => mmcm_reset,  -- MMCM reset unused (btnC resets the core only)
 locked   => open
);

-- Xevious core + character/graphics ROM.
-- ROM clocked on the inverted core clock (asserting edge mid-slot), matching
-- the DE10 reference.
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

 b_test       => '1',
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

rom : entity work.xevious_cpu_gfx_8bits
port map(
 clk  => (not clock_18),
 addr => rom_addr,
 data => rom_do
);

-- 31 kHz VGA via the imported MiST scandoubler.
-- Pad the core's 4/4/4-bit RGB to 6 bits by MSB replication; force black during blank.
vga_r_i <= r & r(3 downto 2) when blankn = '1' else "000000";
vga_g_i <= g & g(3 downto 2) when blankn = '1' else "000000";
vga_b_i <= b & b(3 downto 2) when blankn = '1' else "000000";

-- Derive the scandoubler enable signals. The core's pixel clock is 6 MHz
-- (ena_vidgen). From the 18 MHz clk_sys a mod-3 counter yields:
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

-- Display mode switch via sw(13):
--   0 = 31 kHz VGA (scan-doubled 6-bit RGB adapted to 4bits/color)
--   1 = 15 kHz TV  (native core RGB, composite sync on HS, VS held high --
--       requires a 15 kHz RGB monitor or RGB->composite converter)
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

-- get scancode from keyboard
keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clock_11, -- synchronous clock with USB HID path
  kbd_clk   => ps2_clk,
  kbd_dat   => ps2_dat,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- translate scancode to joystick
joystick : entity work.kbd_joystick
port map (
  clk           => clock_11, -- synchronous clock with USB HID path
  kbdint        => kbd_intr,
  kbdscancode   => kbd_scancode,
  joyBCPPFRLDU  => kbd_joy
);

-- OR-merge the Atari-style joystick on JA with the PS/2 keyboard joystick.
-- JA physical map (JA[0]=JA1, JA[1]=JA2, JA[2]=JA3, JA[3]=JA4, JA[4]=JA7):
--   JA[0]=right, JA[1]=left, JA[2]=bomb, JA[3]=up, JA[4]=fire; down unused
--   (the game has no down control; down is keyboard-only).
-- JA is active-low (pressed shorts to ground); invert so a press reads
-- active-high, matching the core's active-high input boundary and the
-- keyboard path.
joyBCPPFRLDU(0) <= kbd_joy(0) or not JA(3);                 -- up      (JA4)
joyBCPPFRLDU(1) <= kbd_joy(1);                              -- down    (keyboard only)
joyBCPPFRLDU(2) <= kbd_joy(2) or not JA(1);                 -- left    (JA2)
joyBCPPFRLDU(3) <= kbd_joy(3) or not JA(0);                 -- right   (JA1)
joyBCPPFRLDU(4) <= kbd_joy(4) or not JA(4);                 -- fire    (JA7)
joyBCPPFRLDU(5) <= kbd_joy(5) or btnL;                      -- start1  (btnL / F1)
joyBCPPFRLDU(6) <= kbd_joy(6) or btnR;                      -- start2  (btnR / F2)
joyBCPPFRLDU(7) <= kbd_joy(7) or btnU;                      -- coin    (btnU / F3)
joyBCPPFRLDU(8) <= kbd_joy(8) or not JA(2);                 -- bomb    (JA3 / CTRL)

-- pwm sound output
process(clock_18)  -- same clock as the DE10 top drove the PWM accumulator
begin
  if rising_edge(clock_18) then
    pwm_accumulator  <=  std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned('0' & audio));
  end if;
end process;

O_PMODAMP2_AIN   <= pwm_accumulator(12);
O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
