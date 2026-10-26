---------------------------------------------------------------------------------
-- Basys3 Top level for Computer Space (Nutting Associates, 1971)
-- by Dar (darfpga@aol.fr) (22/11/2017 v1.1)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from computer_space_de10_lite.vhd (DE10-lite rev 22/11/2017 v1.1):
--  - Single clock domain (2026-10-02, PORTING_SPEC §Clocking): one MMCM
--    output clk_out1 = 48.000 MHz (100 MHz in) clocks the core (clock_50 /
--    super_clk nets, names kept from upstream), scandoubler clk_sys,
--    keyboard and PWM. A 3-bit counter derives the clock enables:
--       game_ce   (count = 7)       6 MHz, replaces rising_edge(game_clk)
--       game_ce_n (count = 3)       6 MHz, replaces the star counter's
--                                   rising_edge(not game_clk)
--       ce_pix2   (count(1:0) = 3)  12 MHz scandoubler ce_x2
--    The scandoubler's exactly-2x requirement holds as ce_x2 = 2x ce_x1.
--    The core's 50 MHz-sized timer/sound constants are rescaled x0.96 by
--    contrib/code/computer_space_single_domain.patch; game_clk-clocked
--    logic uses game_ce via that patch and
--    computer_space_motion_single_domain.patch. Replaces the former
--    50 / 6 / 12 MHz three-output scheme, which failed setup and hold on
--    its clock-domain crossings.
--  - 6 MHz pixel rate (2.7% above Dar's 5.842 MHz): the MMCM cannot derive
--    5.842 MHz from 100 MHz; video timing scales by 6/5.842 ~ 1.027.
--  - Keyboard input is the Basys 3's onboard USB-A "USB HID" host port
--    (C17/B17): the onboard PIC24 USB-HID host presents a plugged-in USB
--    keyboard to the FPGA fabric over the same PS/2 protocol/pins a direct
--    PS/2 device uses, so io_ps2_keyboard.vhd is unchanged -- a pin remap
--    in Basys-3-Master.xdc, not a logic change (same approach as
--    vhdl_congo_bongo and Arcade-Zaxxon).
--  - Keyboard clock = clk_core (48 MHz); ps2_clk/ps2_dat pass a 2-FF
--    synchronizer first (was game_clk 6 MHz, unsynchronized).
--  - Mono (left-channel) PWM audio on PmodAMP2 (JA pins 1/2/4); sw15 up = audio disabled,
--    sw14 up = gain. audio_out/wav_out from the core are unused (the
--    sound ROMs and the computer_space_sound simulator both feed the same
--    internal audio bus; only `audio` is driven by the top).
--  - Display mode via sw(13): 0 = 31 kHz progressive VGA (external MiST
--    scandoubler), 1 = 15 kHz TV (native rate, composite sync on HS, VS
--    high). Scandoubler clk_sys = clk_core, ce_x1 = game_ce, ce_x2 = ce_pix2.
--  - Video: the core outputs 4-bit video[normal/inverse, objects, scores,
--    stars]; the DE10 top maps the 3 object bits through a normal/inverse
--    monochrome level lookup (video(3) picks normal vs reverse-video). This
--    is reproduced here; all three RGB channels are driven from the same
--    level so the picture is white-on-black, matching the original. Blanking
--    forced to black while blank.
--  - Composite sync via the core's composite_sync entity (as the DE10 top).
--  - btnC = reset (active-high; also resets MMCM; core held until lock).
--  - Controls: rotate left/right, thrust, fire, start. Keyboard (decoded in
--    this wrapper, MAME-style keys, 2026-10-20; F0 = release, E0 ignored): left /
--    right arrows, up arrow (thrust), Left Ctrl (fire), 1 / 2 (start); replaces
--    kbd_joystick (space / F2).
--  - JXADC header doubles as a joystick, OR-merged with the keyboard (same
--    active-high core boundary). Physical map (Congo Bongo convention):
--    JXADC1=right/CW, JXADC2=left/CCW, JXADC4=up/thrust, JXADC7=fire, i.e. JXADC(0)=right,
--    JXADC(1)=left, JXADC(2)=spare, JXADC(3)=up, JXADC(4)=fire. JXADC is active-low (press
--    shorts to ground; XDC PULLUP true); invert 'not' so a press reads
--    active-high like the keyboard/buttons. There is no core "down" input, so
--    JXADC3 is unconnected/spare.
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

 JXADC              : in  std_logic_vector(4 downto 0);   -- optional joystick
 ps2_dat         : in  std_logic;          -- USB HID data  (B17)
 ps2_clk         : in  std_logic;          -- USB HID clock (C17)

 O_PMODAMP2_AIN   : out std_logic;         -- PWM audio
 O_PMODAMP2_GAIN  : out std_logic;         -- AMP gain  (sw14)
 O_PMODAMP2_SHUTD : out std_logic;         -- AMP shutdown (sw15)

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
 -- aliases Left Ctrl), sf-darfpga PORTING_SPEC.md section 3.1.
 process(clk_core)
 begin
  if rising_edge(clk_core) then
   if kbd_intr = '1' then
    if kbd_scancode = x"F0" then
     kbd_rel <= '1';
    elsif kbd_scancode /= x"E0" then
     kbd_rel <= '0';
     if kbd_scancode = x"75" then joyPCFRLDU(0) <= not kbd_rel; end if; -- up arrow : thrust
     if kbd_scancode = x"6B" then joyPCFRLDU(2) <= not kbd_rel; end if; -- left arrow : CCW
     if kbd_scancode = x"74" then joyPCFRLDU(3) <= not kbd_rel; end if; -- right arrow : CW
     if kbd_scancode = x"14" then joyPCFRLDU(4) <= not kbd_rel; end if; -- left ctrl : fire
     if kbd_scancode = x"16" or kbd_scancode = x"1E" then joyPCFRLDU(6) <= not kbd_rel; end if; -- 1 / 2 : start
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
 -- Composite sync (reused verbatim from the DE10-lite top)
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
