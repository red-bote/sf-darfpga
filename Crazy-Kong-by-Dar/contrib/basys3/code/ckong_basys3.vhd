---------------------------------------------------------------------------------
-- Basys3 Top level for Crazy Kong (Crazy-Climber-derived hardware,
-- Kyoei/Falcon, 1981; per MAME's cclimber.cpp driver and Dar's README the
-- core plays Crazy Kong Part II / Falcon) by Dar
-- (darfpga@aol.fr) (06/06/2018)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from ckong_de10_lite.vhd (DE10-lite rev 06/06/2018):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives a single clock_12
--    (12.288 MHz, CPU 3.072 MHz as the original; sf-darfpga/CLOCKING_SPEC.md)
--    used for everything: the core, the sound, the PWM audio accumulator
--    and the keyboard (pristine DE10-lite max10_pll_12M gave 12 MHz).
--  - Joystick on JXADC (four directions + fire/jump), OR-merged with the
--    PS/2/USB keyboard and, for coin/start, dedicated buttons (btnU/btnD =
--    coin, btnL = P1 start, btnR = P2 start). Core inputs are active-high;
--    JXADC is active-low, so a press is inverted to active-high like the
--    keyboard path.
--  - Mono PWM audio on PmodAMP2 (JA pins 1/2/4); sw15 up = audio disabled, sw14 up = gain.
--    Reproduces the pristine process exactly: 13-bit accumulator on
--    clock_12, adding audio(15 downto 4), output is bit 12.
--  - Display mode via sw(13), replacing the DE10's sw(0):
--      0 = 31 kHz progressive VGA: the core's internal line_doubler
--          (tv15Khz_mode = '0') drives the real video_hs/video_vs -- no
--          external scandoubler is needed for this core.
--      1 = 15 kHz TV: native composite sync on HS (video_csync), VS held
--          high (needs a 15 kHz RGB monitor or RGB->composite converter).
--    RGB is padded 3/3/2 -> 4/4/4 the same way in both modes (r&'0', g&'0',
--    b&"00"), exactly as the pristine vga_r/vga_g/vga_b assignments.
--  - Keyboard on the Basys3 onboard USB-HID connector (ps2_clk = C17,
--    ps2_dat = B17), NOT on a Pmod. io_ps2_keyboard and the decoder run at
--    clock_12 = 12 MHz, which is comfortably above the >= 6 MHz this onboard
--    host needs (Congo Bongo / Arcade_Zaxxon / Pooyan data) -- no divider is
--    required (unlike Traverse-USA, whose shared pristine divider was ~3 MHz).
--  - Keyboard map (wrapper decoder, MAME defaults, 2026-10-20; replaces
--    kbd_joystick; F0 = release, E0 ignored; kbd_joy keeps the joyHBCPPFRLDU
--    bit order):
--      bit0 = Up arrow (0x75)  -> up
--      bit1 = Down arrow (0x72)-> down
--      bit2 = Left arrow (0x6B)-> left
--      bit3 = Right arrow(0x74)-> right
--      bit4 = Left Ctrl (0x14) -> jump
--      bit5 = 1 (0x16)         -> start 1
--      bit6 = 2 (0x1E)         -> start 2
--      bit7 = 5 / 6 (0x2E/0x36)-> coin
--  - PS/2, JXADC and buttons pass 2-FF synchronizers on clock_12.
--  - Player 2 mirrors player 1 (one keyboard set is decoded; the core
--    has no independent P2 controls, only cocktail-mode duplicates).
--  - DE10-lite's 7-segment debug hex display (dbg_cpu_addr) is not ported;
--    the core's debug output is left open.
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

entity ckong_basys3 is
port(
 clk             : in  std_logic;
 sw              : in  std_logic_vector(15 downto 0);
 btnC            : in  std_logic;  -- reset
 btnL            : in  std_logic;  -- P1 start
 btnR            : in  std_logic;  -- P2 start
 btnU            : in  std_logic;  -- coin-in
 btnD            : in  std_logic;  -- coin-in

 JXADC              : in  std_logic_vector(4 downto 0);  -- joystick (right/left/down/up/fire)
 ps2_dat         : in  std_logic;
 ps2_clk         : in  std_logic;

 O_PMODAMP2_AIN  : out std_logic;
 O_PMODAMP2_GAIN : out std_logic;
 O_PMODAMP2_SHUTD: out std_logic;

 vgaRed   : out std_logic_vector(3 downto 0);
 vgaGreen : out std_logic_vector(3 downto 0);
 vgaBlue  : out std_logic_vector(3 downto 0);
 vgaHsync : out std_logic;
 vgaVsync : out std_logic
);
end ckong_basys3;

architecture struct of ckong_basys3 is

 signal clock_12    : std_logic;
 signal mmcm_locked : std_logic;
 signal reset       : std_logic;

 signal r         : std_logic_vector(2 downto 0);
 signal g         : std_logic_vector(2 downto 0);
 signal b         : std_logic_vector(1 downto 0);
 signal csync     : std_logic;
 signal hsync     : std_logic;
 signal vsync     : std_logic;

 signal audio           : std_logic_vector(15 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);

 signal kbd_intr      : std_logic;
 signal kbd_scancode  : std_logic_vector(7 downto 0);
 signal kbd_rel       : std_logic := '0';
 signal kbd_joy       : std_logic_vector(7 downto 0) := (others => '0');

 -- PS/2, JXADC and buttons, 2-FF synchronized on the keyboard clock
 signal ps2_clk_meta, ps2_clk_s : std_logic := '1';
 signal ps2_dat_meta, ps2_dat_s : std_logic := '1';
 signal jxadc_meta, jxadc_s     : std_logic_vector(4 downto 0) := (others => '1');
 signal btn_meta, btn_s         : std_logic_vector(3 downto 0) := (others => '0'); -- U, D, L, R
 attribute ASYNC_REG : string;
 attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
 attribute ASYNC_REG of jxadc_meta, jxadc_s, btn_meta, btn_s : signal is "TRUE";

 signal core_up, core_down, core_left, core_right, core_fire    : std_logic;
 signal core_coin1, core_start1, core_start2                    : std_logic;

begin

 -- btnC is active-high: it resets the MMCM and, together with !locked,
 -- holds the core in reset until the clock is stable.
 reset <= btnC or not mmcm_locked;

 clocks : entity work.clk_wiz_0
 port map(
  clk_in1  => clk,
  clk_out1 => clock_12,
  reset    => btnC,
  locked   => mmcm_locked
 );

 -- Crazy Kong (video_clk is unused, matching the pristine DE10 top)
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
  clk       => clock_12, -- 12.288 MHz: >= 6 MHz required by the onboard USB-HID host
  kbd_clk   => ps2_clk_s,
  kbd_dat   => ps2_dat_s,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
 );

 -- Input synchronizers (2-FF) into clock_12
 process (clock_12)
 begin
   if rising_edge(clock_12) then
     ps2_clk_meta <= ps2_clk;                  ps2_clk_s <= ps2_clk_meta;
     ps2_dat_meta <= ps2_dat;                  ps2_dat_s <= ps2_dat_meta;
     jxadc_meta   <= JXADC;                    jxadc_s   <= jxadc_meta;
     btn_meta     <= btnU & btnD & btnL & btnR; btn_s     <= btn_meta;
   end if;
 end process;

 -- translate scancode to joystick (MAME default keys, PS/2 set 2 codes), replaces
 -- kbd_joystick. F0 marks a release; E0 is ignored (keypad 8/2/4/6 alias the arrows,
 -- Right Ctrl aliases Left Ctrl), sf-darfpga PORTING_SPEC.md section 3.1.
 -- kbd_joy keeps the joyHBCPPFRLDU bit order: 5 = start 1, 6 = start 2, 7 = coin.
 process (clock_12)
 begin
   if rising_edge(clock_12) then
     if kbd_intr = '1' then
       if kbd_scancode = x"F0" then
         kbd_rel <= '1';
       elsif kbd_scancode /= x"E0" then
         kbd_rel <= '0';
         if kbd_scancode = x"75" then kbd_joy(0) <= not kbd_rel; end if; -- up arrow
         if kbd_scancode = x"72" then kbd_joy(1) <= not kbd_rel; end if; -- down arrow
         if kbd_scancode = x"6B" then kbd_joy(2) <= not kbd_rel; end if; -- left arrow
         if kbd_scancode = x"74" then kbd_joy(3) <= not kbd_rel; end if; -- right arrow
         if kbd_scancode = x"14" then kbd_joy(4) <= not kbd_rel; end if; -- left ctrl : jump
         if kbd_scancode = x"16" then kbd_joy(5) <= not kbd_rel; end if; -- 1 : start 1
         if kbd_scancode = x"1E" then kbd_joy(6) <= not kbd_rel; end if; -- 2 : start 2
         if kbd_scancode = x"2E" or kbd_scancode = x"36" then kbd_joy(7) <= not kbd_rel; end if; -- 5 / 6 : coin
       end if;
     end if;
   end if;
 end process;

 -- OR-merge the joystick on JXADC with the PS/2 keyboard joystick. JXADC physical
 -- map: JXADC1=right, JXADC2=left, JXADC3=down, JXADC4=up, JXADC7=fire/jump, i.e.
 -- JXADC(0)=right, JXADC(1)=left, JXADC(2)=down, JXADC(3)=up, JXADC(4)=fire. JXADC is
 -- active-low (pressed shorts to ground); invert so a press reads
 -- active-high, matching the core's active-high input boundary and the
 -- keyboard path.
 core_up    <= kbd_joy(0) or not jxadc_s(3);
 core_down  <= kbd_joy(1) or not jxadc_s(2);
 core_left  <= kbd_joy(2) or not jxadc_s(1);
 core_right <= kbd_joy(3) or not jxadc_s(0);
 core_fire  <= kbd_joy(4) or not jxadc_s(4);

 -- Coin/start: keyboard (1/2, 5/6) OR-merged with dedicated buttons.
 -- Buttons are active-high (Basys3 board pull-down, same convention as
 -- btnC). This core has a single coin input; btnU and btnD both trigger it.
 core_coin1  <= kbd_joy(7) or btn_s(3) or btn_s(2);  -- coin   = 5 / 6 or btnU / btnD
 core_start1 <= kbd_joy(5) or btn_s(1);          -- start1 = 1 or btnL
 core_start2 <= kbd_joy(6) or btn_s(0);          -- start2 = 2 or btnR

 -- Pad native 3/3/2-bit RGB to the VGA connector's 4-bit/channel input by
 -- MSB replication (identical to the pristine vga_r/vga_g/vga_b).
 vgaRed   <= r & '0';
 vgaGreen <= g & '0';
 vgaBlue  <= b & "00";

 -- Display mode switch via sw(13):
 --   0 = 31 kHz VGA (internal line doubler, real hsync/vsync)
 --   1 = 15 kHz TV  (native rate, composite sync on HS, VS held high)
 vgaHsync <= csync when sw(13) = '1' else hsync;
 vgaVsync <= '1'   when sw(13) = '1' else vsync;

 -- pwm sound output (reproduces the pristine top's exact accumulator).
 process(clock_12)
 begin
  if rising_edge(clock_12) then
   pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned('0' & audio(15 downto 4)));
  end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator(12);
 O_PMODAMP2_SHUTD <= not sw(15); -- sw15 up = amp shut down (audio disabled)
 O_PMODAMP2_GAIN  <= not sw(14); -- sw14 up = gain active (GAIN active low)

end struct;
