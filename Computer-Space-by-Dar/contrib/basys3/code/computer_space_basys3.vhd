---------------------------------------------------------------------------------
-- Basys 3 top level for Computer Space by Red~Bote, derived from
-- computer_space_de10_lite.vhd by Dar (darfpga@aol.fr,
-- http://darfpga.blogspot.fr); see that file for its history.
---------------------------------------------------------------------------------
--
-- v0.1 (10/26/2026) : initial Basys 3 release
--
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthesized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
--
-- Main features:
--  Single clock domain: clk_wiz_0 derives clk_core = 48.000 MHz from 100 MHz; it
--  clocks the core (clock_50 / super_clk), scandoubler, keyboard and PWM. A 3-bit
--  counter derives the enables:
--     game_ce   (count = 7)       6 MHz, replaces rising_edge(game_clk)
--     game_ce_n (count = 3)       6 MHz, replaces the star counter's
--                                 rising_edge(not game_clk)
--     ce_pix2   (count(1:0) = 3)  12 MHz scandoubler ce_x2 (exactly 2 x ce_x1)
--  Core 50 MHz timer/sound constants rescaled x0.96 and game_clk logic moved to
--  game_ce by core patches
--  6 MHz pixel rate, 2.7% above the DE10 5.842 MHz (not derivable from 100 MHz)
--  Joystick on JXADC (JXADC1 = CW, JXADC2 = CCW, JXADC4 = thrust, JXADC7 = fire;
--  JXADC3 spare), OR-merged with the PS/2 keyboard (onboard USB-HID)
--  Mono (left-channel) PWM audio on PmodAMP2 (JA pins 1/2/4); sw15 up = audio
--  off, sw14 up = gain; core audio_out/wav_out unused
--  31 kHz VGA via the MiST scandoubler (ce_x1 = game_ce, ce_x2 = ce_pix2);
--  sw13 = 15 kHz TV (csync on HS)
--  Keyboard: MAME-style keys (left/right arrows = rotate, up arrow = thrust,
--  Left Ctrl = fire, 1/2 = start)
--  PS/2, JXADC and buttons 2-FF synchronized on clk_core
--  btnC = reset (also resets the MMCM); btnU/btnD/btnL/btnR = start
--  No ROM generation: sound waveforms are .hex files loaded at BRAM init by the
--  Xilinx ROM replacements (rom_*.vhd); the Altera PLL is unused
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity computer_space_basys3 is
port(
 clk             : in  std_logic;          -- 100 MHz oscillator
 sw              : in  std_logic_vector(15 downto 0);
 btnC            : in  std_logic;          -- reset (active-high)
 btnU            : in  std_logic;          -- pushbutton up   (also start)
 btnD            : in  std_logic;          -- pushbutton down (also start)
 btnL            : in  std_logic;          -- pushbutton left (also start)
 btnR            : in  std_logic;          -- pushbutton right (also start)

 JXADC              : in  std_logic_vector(4 downto 0);   -- optional joystick
 ps2_dat         : in  std_logic;          -- USB HID data  (B17)
 ps2_clk         : in  std_logic;          -- USB HID clock (C17)

 O_PMODAMP2_AIN   : out std_logic;         -- PWM audio
 O_PMODAMP2_GAIN  : out std_logic;         -- AMP gain  (sw14)
 O_PMODAMP2_SHUTD : out std_logic;         -- AMP shutdown (sw15)

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

 signal clk_core    : std_logic;   -- 48.000 MHz, the only clock
 signal ce_cnt      : unsigned(2 downto 0) := (others => '0');
 signal game_ce     : std_logic := '0';  -- 6 MHz enable
 signal game_ce_n   : std_logic := '0';  -- 6 MHz enable, half-pixel offset
 signal ce_pix2     : std_logic := '0';  -- 12 MHz enable (scandoubler ce_x2)
 signal mmcm_locked : std_logic;
 signal reset       : std_logic;

 signal hsync       : std_logic;
 signal vsync       : std_logic;
 signal csync       : std_logic;
 signal blank       : std_logic;
 signal video       : std_logic_vector(3 downto 0);

 signal normal_video  : std_logic_vector(3 downto 0);
 signal inverse_video : std_logic_vector(3 downto 0);
 signal muxed_video   : std_logic_vector(3 downto 0);

 signal vga_r_i, vga_g_i, vga_b_i : std_logic_vector(5 downto 0);
 signal vga_r_o, vga_g_o, vga_b_o : std_logic_vector(5 downto 0);
 signal hsync_o, vsync_o          : std_logic;

 signal audio        : integer range -32768 to 32767;
 signal audio_us     : unsigned(16 downto 0);
 signal pwm_accumulator : std_logic_vector(16 downto 0);

 signal ps2_clk_s, ps2_dat_s : std_logic_vector(1 downto 0) := "11";
 -- JXADC(4 downto 0) & btnU/D/L/R, 2-FF synchronized (index 1 = output).
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

 -- btnC is active-high: resets MMCM and, with !locked, holds core in reset.
 reset <= btnC or not mmcm_locked;

 -- 100 MHz -> 48 MHz, see header.
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
   if ce_cnt = 6 then game_ce   <= '1'; end if;
   if ce_cnt = 2 then game_ce_n <= '1'; end if;
   if ce_cnt(1 downto 0) = "10" then ce_pix2 <= '1'; end if;
  end if;
 end process;

 -- PS/2 (USB HID), JXADC and pushbutton inputs: 2-FF synchronizer into clk_core.
 process(clk_core)
 begin
  if rising_edge(clk_core) then
   ps2_clk_s <= ps2_clk_s(0) & ps2_clk;
   ps2_dat_s <= ps2_dat_s(0) & ps2_dat;
   in_s(0)   <= btnR & btnL & btnD & btnU & JXADC;
   in_s(1)   <= in_s(0);
  end if;
 end process;

 -- Keyboard OR JXADC (active-low) OR buttons; in_s(1)(4 downto 0) = JXADC.
 ctl_ccw    <= joyPCFRLDU(2) or not in_s(1)(1);  -- left arrow / JXADC2 = rotate CCW
 ctl_cw     <= joyPCFRLDU(3) or not in_s(1)(0);  -- right arrow / JXADC1 = rotate CW
 ctl_thrust <= joyPCFRLDU(0) or not in_s(1)(3);  -- up arrow / JXADC4 = thrust
 ctl_fire   <= joyPCFRLDU(4) or not in_s(1)(4);  -- left ctrl / JXADC7 = fire
 ctl_start  <= joyPCFRLDU(6) or in_s(1)(5) or in_s(1)(6) or in_s(1)(7) or in_s(1)(8); -- 1 / 2 or any pushbutton

 -- get scancode from keyboard (USB HID -> PS/2 via onboard PIC24).
 keyboard : entity work.io_ps2_keyboard
 port map (
  clk       => clk_core,
  kbd_clk   => ps2_clk_s(1),
  kbd_dat   => ps2_dat_s(1),
  interrupt => kbd_intr,
  scancode  => kbd_scancode
 );

 -- translate scancode to joystick (PS/2 set 2 codes), replaces kbd_joystick.
 -- F0 marks a release; E0 is ignored (keypad 8/4/6 alias the arrows, Right Ctrl
 -- aliases Left Ctrl), PORTING_SPEC.md 3.1.
 process(clk_core)
 begin
  if rising_edge(clk_core) then
   if kbd_intr = '1' then
    if kbd_scancode = x"F0" then
     kbd_rel <= '1';
    elsif kbd_scancode /= x"E0" then
     kbd_rel <= '0';
     if kbd_scancode = x"75" then joyPCFRLDU(0) <= not kbd_rel; end if; -- up arrow: thrust
     if kbd_scancode = x"6B" then joyPCFRLDU(2) <= not kbd_rel; end if; -- left arrow: CCW
     if kbd_scancode = x"74" then joyPCFRLDU(3) <= not kbd_rel; end if; -- right arrow: CW
     if kbd_scancode = x"14" then joyPCFRLDU(4) <= not kbd_rel; end if; -- left ctrl: fire
     if kbd_scancode = x"16" or kbd_scancode = x"1E" then joyPCFRLDU(6) <= not kbd_rel; end if; -- 1 / 2: start
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
  clock_50      => clk_core,     -- 48 MHz (constants rescaled by patch)
  game_ce       => game_ce,      -- 6 MHz pixel enable
  game_ce_n     => game_ce_n,    -- 6 MHz enable, half-pixel offset

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

 -----------------------------------------------------------------------
 -- Video adaptation.
 --   video bits layout [normal/inverse, saucer+rocket+missile, scores, stars]
 -- Maps the 3 object bits to monochrome video levels; video(3) selects
 -- normal (0) vs inverse (1) video. All three RGB channels are driven from
 -- the same level so the picture is white-on-black, matching the original.
 -----------------------------------------------------------------------
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

 muxed_video <= normal_video when video(3) = '0' else inverse_video;

 -- Pad to 6-bit/channel for the scandoubler; forced black while blanked.
 vga_r_i <= muxed_video & muxed_video(3 downto 2) when blank = '0' else "000000";
 vga_g_i <= muxed_video & muxed_video(3 downto 2) when blank = '0' else "000000";
 vga_b_i <= muxed_video & muxed_video(3 downto 2) when blank = '0' else "000000";

 scandoubler_inst : scandoubler
 port map (
  clk_sys   => clk_core,
  scanlines => "00",
  ce_x1     => game_ce,    -- 6 MHz pixel enable
  ce_x2     => ce_pix2,    -- 12 MHz output enable (exactly 2x ce_x1)
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
 --   0 = 31 kHz VGA (scan-doubled)
 --   1 = 15 kHz TV  (composite sync on HS, VS high, native rate)
 vga_hs <= hsync_o    when sw(13) = '0' else csync;
 vga_vs <= vsync_o    when sw(13) = '0' else '1';
 vga_r  <= vga_r_o(5 downto 2) when sw(13) = '0' else muxed_video;
 vga_g  <= vga_g_o(5 downto 2) when sw(13) = '0' else muxed_video;
 vga_b  <= vga_b_o(5 downto 2) when sw(13) = '0' else muxed_video;

 -----------------------------------------------------------------------
 -- PWM audio output (left channel only)
 -----------------------------------------------------------------------
 audio_us <= '0' & to_unsigned(audio + 32767, 16);

 -- Accumulates at the 6 MHz enable rate (carrier unchanged).
 process(clk_core)
 begin
  if rising_edge(clk_core) and game_ce = '1' then
   pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(15 downto 0)) + audio_us);
  end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator(16);
 O_PMODAMP2_SHUTD <= not sw(15); -- sw15 up = amp shut down (audio disabled)
 O_PMODAMP2_GAIN  <= not sw(14); -- sw14 up = gain active (GAIN active low)

end struct;
