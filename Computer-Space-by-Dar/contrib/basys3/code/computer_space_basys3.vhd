---------------------------------------------------------------------------------
-- Basys3 Top level for Computer Space (Nutting Associates, 1971)
-- by Dar (darfpga@aol.fr) (22/11/2017 v1.1)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from computer_space_de10_lite.vhd (DE10-lite rev 22/11/2017 v1.1):
--  - 100 MHz board oscillator; clk_wiz_0 MMCM derives three clocks from
--    100 MHz (replaces the MAX10 PLL). The MMCM is forced to VCO 600 MHz
--    (via make_clk_wiz_0.sh's deterministic constant rewrite) so every output
--    is an exact integer divide:
--       clk_out1 = 50.000  MHz -> core clock_50 / super_clk (timers, noise,
--                                sound-ROM sample clock; MUST stay ~50 MHz,
--                                see below -- sound.vhd clocks its ROMs on
--                                clock_50)
--       clk_out2 = 6.000   MHz -> core game_clk (video pixel clock)
--       clk_out3 = 12.000  MHz -> scandoubler clk_sys = EXACTLY 2x game_clk
--  - The MMCM cannot derive 5.84 MHz from 100 MHz with a valid VCO
--    (Artix-7 MMCM VCO must be 600-1200 MHz), so game_clk = 6 MHz (2.7% above
--    Dar's 5.842 MHz). All game-timing counters run in the 50 MHz clock_50
--    domain and are exact; only the scan_counter video timing scales by
--    6/5.842 ~ 1.027 (within a 15 kHz RGB monitor's horizontal tolerance).
--  - Scandoubler wiring follows the proven Phoenix port (same MiST
--    scandoubler): ce_x1 = game_clk directly (a genuine clock, not a divided
--    strobe), ce_x2 = '1', clk_sys = 12 MHz = exactly 2x game_clk. The MiST
--    scandoubler REQUIRES clk_sys = exactly 2x the ce_x1 (pixel) rate for its
--    line-buffer read/write pointers to stay aligned; any other ratio shows a
--    black screen with only occasional misaligned flashes. With a non-exact 2x
--    the earlier build (clk_sys = 11.9048 MHz from auto VCO 750) produced
--    exactly that symptom on hardware.
--  - Keyboard input is the Basys 3's onboard USB-A "USB HID" host port
--    (C17/B17): the onboard PIC24 USB-HID host presents a plugged-in USB
--    keyboard to the FPGA fabric over the same PS/2 protocol/pins a direct
--    PS/2 device uses, so io_ps2_keyboard.vhd / kbd_joystick.vhd are
--    unchanged -- a pin remap in Basys-3-Master.xdc, not a logic change
--    (same approach as vhdl_congo_bongo and Arcade-Zaxxon).
--  - Keyboard clock = game_clk (6 MHz), the exact rate proven on
--    Congo Bongo / Zaxxon for the onboard USB HID host (the DE10 original
--    drove the keyboard with its 5.84 MHz game clock).
--  - Mono (left-channel) PWM audio on PmodAMP2 (JC); sw14 = shutdown,
--    sw15 = gain select. audio_out/wav_out from the core are unused (the
--    sound ROMs and the computer_space_sound simulator both feed the same
--    internal audio bus; only `audio` is driven by the top).
--  - Display mode via sw(13): 0 = 31 kHz progressive VGA (external MiST
--    scandoubler), 1 = 15 kHz TV (native rate, composite sync on HS, VS
--    high). Scandoubler clk_sys = clk_out3 (12.000 MHz), ce_x1 = game_clk
--    (6 MHz, wired directly), ce_x2 = '1' -- the proven Phoenix convention
--    for this scandoubler module (clk_sys = exactly 2x the ce_x1 pixel rate,
--    required for the line-buffer pointers to stay aligned).
--  - Video: the core outputs 4-bit video[normal/inverse, objects, scores,
--    stars]; the DE10 top maps the 3 object bits through a normal/inverse
--    monochrome level lookup (video(3) picks normal vs reverse-video). This
--    is reproduced here; all three RGB channels are driven from the same
--    level so the picture is white-on-black, matching the original. Blanking
--    forced to black while blank.
--  - Composite sync via the core's composite_sync entity (as the DE10 top).
--  - btnC = reset (active-high; also resets MMCM; core held until lock).
--  - Controls: rotate left/right, thrust, fire, start. Keyboard: left / right
--    arrows, up arrow (thrust), space (fire), F2 (start) -- decoded by the
--    unmodified kbd_joystick joyPCFRLDU bits 2/3/0/4/6.
--  - JA header doubles as a joystick, OR-merged with the keyboard (same
--    active-high core boundary). Physical map (Congo Bongo convention):
--    JA1=right/CW, JA2=left/CCW, JA4=up/thrust, JA7=fire, i.e. JA(0)=right,
--    JA(1)=left, JA(2)=spare, JA(3)=up, JA(4)=fire. JA is active-low (press
--    shorts to ground; XDC PULLUP true); invert 'not' so a press reads
--    active-high like the keyboard/buttons. There is no core "down" input, so
--    JA3 is unconnected/spare.
--  - Pushbuttons btnU/btnD/btnL/btnR are active-high (board pull-down) and are
--    OR'd into start, so any of the four starts a round alongside F2.
--  - No ROMs / no PROM generation: Computer Space is a discrete TTL game.
--    Sound waveforms live in .hex files in rtl/ and are loaded at BRAM-init
--    by the six Xilinx ROM replacements (rom_*.vhd, same entities as the
--    excluded Altera altsyncram ROMs). The Altera PLL file
--    (de10_lite/max10_pll_6M_5p84M.vhd) is unused.
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

entity computer_space_basys3 is
port(
 clk             : in  std_logic;          -- 100 MHz oscillator
 sw              : in  std_logic_vector(15 downto 0);
 btnC            : in  std_logic;          -- reset (active-high)
 btnU            : in  std_logic;          -- pushbutton up   (also start)
 btnD            : in  std_logic;          -- pushbutton down (also start)
 btnL            : in  std_logic;          -- pushbutton left (also start)
 btnR            : in  std_logic;          -- pushbutton right (also start)

 JA              : in  std_logic_vector(4 downto 0);   -- optional joystick
 ps2_dat         : in  std_logic;          -- USB HID data  (B17)
 ps2_clk         : in  std_logic;          -- USB HID clock (C17)

 O_PMODAMP2_AIN   : out std_logic;         -- PWM audio
 O_PMODAMP2_GAIN  : out std_logic;         -- AMP gain  (sw15)
 O_PMODAMP2_SHUTD : out std_logic;         -- AMP shutdown (sw14)

 vgaRed   : out std_logic_vector(3 downto 0);
 vgaGreen : out std_logic_vector(3 downto 0);
 vgaBlue  : out std_logic_vector(3 downto 0);
 vgaHsync : out std_logic;
 vgaVsync : out std_logic
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

 signal clock_50    : std_logic;   -- ~50 MHz (super_clk / sound clock)
 signal game_clk    : std_logic;   -- 6 MHz   (video pixel clock, keyboard)
  signal clk_sys     : std_logic;   -- 12.000 MHz (scandoubler sampling clock, 2x game_clk)
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

 signal kbd_intr     : std_logic;
 signal kbd_scancode : std_logic_vector(7 downto 0);
 signal joyPCFRLDU   : std_logic_vector(7 downto 0);

begin

 -- btnC is active-high: resets MMCM and, with !locked, holds core in reset.
 reset <= btnC or not mmcm_locked;

 -- 100 MHz -> 50 / 6 / 12 MHz, see header.
 clocks : entity work.clk_wiz_0
 port map(
  clk_in1  => clk,
  clk_out1 => clock_50,
  clk_out2 => game_clk,
  clk_out3 => clk_sys,
  reset    => btnC,
  locked   => mmcm_locked
 );

 -- get scancode from keyboard (USB HID -> PS/2 via onboard PIC24).
 -- Keyboard clock = game_clk (6 MHz, the proven USB-HID host rate).
 keyboard : entity work.io_ps2_keyboard
 port map (
  clk       => game_clk,
  kbd_clk   => ps2_clk,
  kbd_dat   => ps2_dat,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
 );

 -- translate scancode to joystick
 joystick : entity work.kbd_joystick
 port map (
  clk           => game_clk,
  kbdint        => kbd_intr,
  kbdscancode   => std_logic_vector(kbd_scancode),
  joyPCFRLDU    => joyPCFRLDU
 );

 -----------------------------------------------------------------------
 -- Computer Space core
 -----------------------------------------------------------------------
 computer_space_top : entity work.computer_space_top
 port map(
  reset         => reset,
  clock_50      => clock_50,     -- ~50 MHz (timers/noise/sound clock)
  game_clk      => game_clk,     -- 6 MHz video pixel clock

  signal_ccw    => joyPCFRLDU(2) or not JA(1), -- left arrow / JA2 = rotate CCW
  signal_cw     => joyPCFRLDU(3) or not JA(0), -- right arrow / JA1 = rotate CW
  signal_thrust => joyPCFRLDU(0) or not JA(3), -- up arrow / JA4 = thrust
  signal_fire   => joyPCFRLDU(4) or not JA(4), -- space / JA7 = fire
  signal_start  => joyPCFRLDU(6) or btnU or btnD or btnL or btnR, -- F2 or any pushbutton

  hsync         => hsync,
  vsync         => vsync,
  blank         => blank,
  video         => video,

  wav_out       => open,
  audio         => audio
 );

 -----------------------------------------------------------------------
 -- Composite sync (reused verbatim from the DE10-lite top)
 -----------------------------------------------------------------------
 composite_sync : entity work.composite_sync
 port map(
  clk   => game_clk,
  hsync => hsync,
  vsync => vsync,
  csync => csync,
  blank => open
 );

 -----------------------------------------------------------------------
 -- Video adaptation (reused verbatim from the DE10-lite top).
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
  clk_sys   => clk_sys,
  scanlines => "00",
  ce_x1     => game_clk,   -- 6 MHz pixel clock, wired directly (Phoenix convention)
  ce_x2     => '1',        -- enabled every clk_sys (12 MHz) edge
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
 vgaHsync <= hsync_o    when sw(13) = '0' else csync;
 vgaVsync <= vsync_o    when sw(13) = '0' else '1';
 vgaRed   <= vga_r_o(5 downto 2) when sw(13) = '0' else muxed_video;
 vgaGreen <= vga_g_o(5 downto 2) when sw(13) = '0' else muxed_video;
 vgaBlue  <= vga_b_o(5 downto 2) when sw(13) = '0' else muxed_video;

 -----------------------------------------------------------------------
 -- PWM audio output (reproduces the DE10-lite top's exact accumulator,
 -- left channel only)
 -----------------------------------------------------------------------
 audio_us <= '0' & to_unsigned(audio + 32767, 16);

 process(game_clk)
 begin
  if rising_edge(game_clk) then
   pwm_accumulator <= std_logic_vector(unsigned('0' & pwm_accumulator(15 downto 0)) + audio_us);
  end if;
 end process;

 O_PMODAMP2_AIN   <= pwm_accumulator(16);
 O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
 O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
