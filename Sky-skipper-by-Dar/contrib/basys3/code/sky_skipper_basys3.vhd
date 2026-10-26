-------------------------------------------------------------------------------
-- Basys3 Top level for Sky Skipper (Nintendo, 1981) by Dar
-- (darfpga@aol.fr) (28/01/2020)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from sky_skipper_de10_lite.vhd (DE10-lite rev 28/01/2020):
--  - 100 MHz board oscillator, clk_wiz_0 MMCM derives a single clock_40
--    (40 MHz) used for everything: the core, the sound YM2149, the PWM audio
--    accumulator and the keyboard -- exactly as the pristine top's
--    max10_pll_40M (50 -> 40 MHz) did on the DE10-lite. reset comes from btnC
--    (active high, ORed with !mmcm_locked).
--  - Video path reproduced from the pristine top: the core drives the real
--    video_hs/video_vs and selects the timing natively (no line_doubler, no
--    external scandoubler). Display mode is selected by sw(13) alone (0 = 31
--    kHz progressive VGA, 1 = 15 kHz interlaced TV) -- changed 2026-09-29 to
--    drop the F8 keyboard XOR and match this repo's plain sw(13) convention:
--      0 = 31 kHz progressive VGA (pixel data on a 20 MHz clock)
--      1 = 15 kHz interlaced TV (native composite sync on HS, VS held high)
--    HS/VS are muxed exactly as the pristine assignments. RGB is padded
--    3/3/2 -> 4/4/4 (r&'0', g&'0', b&"00") the same way in both modes. The
--    core outputs inverted video (video_r/g/b <= not palette_do), which is
--    passed through unchanged.
--  - Keyboard on the Basys3 onboard USB-HID connector (ps2_clk = C17,
--    ps2_dat = B17), io_ps2_keyboard on clock_40. Scancodes decoded in this
--    wrapper, MAME default keys (2026-10-20, replaces kbd_joystick; F0 =
--    release, E0 ignored, sf-darfpga PORTING_SPEC.md 3.1), mapping as the
--    hardware-verified rb-fpga/rework Sky Skipper port:
--      arrows = move, Left Ctrl = speed up (fire10/fire20),
--      Left Alt = bomb (fire11/fire21), 1/2 = start, 5/6 = coin 1/2,
--      9 = service1 (held)
--  - JXADC joystick (active-low, inverted): JXADC1/2/3/4 = right/left/down/up,
--    any JXADC direction also = speed up, JXADC7 = bomb. Player 2 mirrors
--    player 1 (the core has no independent P2 controls).
--  - Pushbuttons: btnU = coin1, btnD = coin2, btnL = start1, btnR = start2
--    (btnC = reset).
--  - PS/2, JXADC and buttons pass 2-FF synchronizers on clock_40.
--  - DIP switches: sw1 = "0000000" (Dar's not("1111111"), normal coinage);
--    sw2 = sw(7 downto 0), not inverted (as rework, hardware 2026-10-19).
--  - Mono PWM audio on PmodAMP2 (JA pins 1/2/4): reproduces the pristine 18-bit
--    accumulator exactly, gated on clock_div = "0000" (effective 4 MHz
--    update) on clock_40, adding ('0'&audio&'0') i.e. audio doubled; output is
--    bit 17. sw15 up = audio disabled, sw14 up = gain.
--  - DE10-lite's 7-segment debug hex display (decodeur_7_seg on
--    dbg_cpu_addr) and unused peripheral shims (usb_host_max3421e,
--    sgtl5000_dac) are not ported; dbg_cpu_addr is left open.
-------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity sky_skipper_basys3 is
port(
  clk             : in  std_logic;
  sw              : in  std_logic_vector(15 downto 0);
  btnC            : in  std_logic;  -- reset
  btnL            : in  std_logic;  -- start1
  btnR            : in  std_logic;  -- start2
  btnU            : in  std_logic;  -- coin1
  btnD            : in  std_logic;  -- coin2

  JXADC              : in  std_logic_vector(4 downto 0);  -- joystick (right/left/down/up/fire)
  ps2_dat         : in  std_logic;
  ps2_clk         : in  std_logic;

  O_PMODAMP2_AIN  : out std_logic;
  O_PMODAMP2_GAIN : out std_logic;
  O_PMODAMP2_SHUTD: out std_logic;

  vga_r   : out std_logic_vector(3 downto 0);
  vga_g   : out std_logic_vector(3 downto 0);
  vga_b   : out std_logic_vector(3 downto 0);
  vga_hs  : out std_logic;
  vga_vs  : out std_logic
);
end sky_skipper_basys3;

architecture struct of sky_skipper_basys3 is

  signal clock_40    : std_logic;
  signal mmcm_locked : std_logic;
  signal reset       : std_logic;

  signal tv15Khz_mode : std_logic;

  signal r      : std_logic_vector(2 downto 0);
  signal g      : std_logic_vector(2 downto 0);
  signal b      : std_logic_vector(1 downto 0);
  signal csync  : std_logic;
  signal blankn : std_logic;
  signal hsync  : std_logic;
  signal vsync  : std_logic;

  signal audio           : std_logic_vector(15 downto 0);
  signal pwm_accumulator : std_logic_vector(17 downto 0);

  -- clock_div gate for the PWM accumulator (pristine clock_kbd divider,
  -- clock_40 / 20; clock_kbd itself is no longer used by the keyboard, which
  -- now runs on clock_40 for the onboard USB-HID host)
  signal clock_div : std_logic_vector(3 downto 0);

  -- 2-FF synchronizers (clock_40) for the asynchronous inputs
  signal ps2_clk_meta, ps2_clk_s : std_logic := '1';
  signal ps2_dat_meta, ps2_dat_s : std_logic := '1';
  signal jxadc_meta, jxadc_s     : std_logic_vector(4 downto 0) := (others => '1');
  signal btn_meta, btn_s         : std_logic_vector(3 downto 0) := (others => '0'); -- U, D, L, R
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of ps2_clk_meta, ps2_clk_s, ps2_dat_meta, ps2_dat_s : signal is "TRUE";
  attribute ASYNC_REG of jxadc_meta, jxadc_s, btn_meta, btn_s : signal is "TRUE";

  signal kbd_intr     : std_logic;
  signal kbd_scancode : std_logic_vector(7 downto 0);
  signal kbd_rel      : std_logic := '0';
  -- kbd_key : 0 up, 1 down, 2 left, 3 right, 4 left ctrl, 5 left alt,
  --           6 '1', 7 '2', 8 '5', 9 '6', 10 '9'
  signal kbd_key      : std_logic_vector(10 downto 0) := (others => '0');
  signal joy_BBBBFRLDU: std_logic_vector(5 downto 0);
  signal coin1_in     : std_logic;
  signal coin2_in     : std_logic;
  signal start1_in    : std_logic;
  signal start2_in    : std_logic;
  signal sw2_in       : std_logic_vector(7 downto 0); -- dip switch 2

 -- DIP switch on spare board switches (2026-10-20, sf-darfpga PORTING_SPEC.md
 -- section 3.2): switch down = Dar's DE10 value, switch up inverts the bit.
 -- sw1: coinage DCBA (bits 3-0) on sw11-8; n.u. bits (6-4) fixed.
 constant SW1_DEFAULT : std_logic_vector(6 downto 0) := "0000000";
 signal sw1_in : std_logic_vector(6 downto 0);
begin

sw1_in <= SW1_DEFAULT xor ("000" & sw(11 downto 8));  -- coinage on sw11-8

  reset <= btnC or not mmcm_locked;

  clocks : entity work.clk_wiz_0
  port map(
    clk_in1  => clk,
    clk_out1 => clock_40,
    reset    => btnC,
    locked   => mmcm_locked
  );

  -- display mode: sw(13) alone selects the mode (0 = 31 kHz VGA, 1 = 15 kHz
  -- TV) -- changed 2026-09-29 to drop the F8 keyboard XOR.
  -- (pristine: tv15Khz_mode <= not fn_toggle(7), which defaulted to 15 kHz)
  tv15Khz_mode <= sw(13);

  -- Sky Skipper
  sky_skipper_inst : entity work.sky_skipper
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

    audio_out    => audio,

    coin1         => coin1_in,  -- 5 or btnU
    coin2         => coin2_in,  -- 6 or btnD
    start1        => start1_in, -- 1 or btnL
    start2        => start2_in, -- 2 or btnR

    right1         => joy_BBBBFRLDU(3),
    left1          => joy_BBBBFRLDU(2),
    up1            => joy_BBBBFRLDU(0),
    down1          => joy_BBBBFRLDU(1),
    fire10         => joy_BBBBFRLDU(4), -- speed up
    fire11         => joy_BBBBFRLDU(5), -- bomb

    right2         => joy_BBBBFRLDU(3),
    left2          => joy_BBBBFRLDU(2),
    up2            => joy_BBBBFRLDU(0),
    down2          => joy_BBBBFRLDU(1),
    fire20         => joy_BBBBFRLDU(4),
    fire21         => joy_BBBBFRLDU(5),

  --      ...DCBA
    sw1            => sw1_in,     --  Dar: not("1111111") n.u.(3b hard wired)  / coinage(DCBA) on sw11-8

  --      PONMLKJI
    sw2            => sw2_in,  -- sw7-0 (Dar: not("11111101")) cocktail(P) / service2(O) / bonus(N) / difficulty(MLK) / lives(IJ)

    service1       => kbd_key(10),  -- 9 (MAME service 1)

    dbg_cpu_addr   => open
  );

  -- pristine clock_div divider (same process as the DE10 top; clock_kbd no
  -- longer produced, clock_div counts for the PWM accumulator gate only)
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

  -- synchronize asynchronous inputs to the core clock
  process(clock_40)
  begin
    if rising_edge(clock_40) then
      ps2_clk_meta <= ps2_clk;      ps2_clk_s <= ps2_clk_meta;
      ps2_dat_meta <= ps2_dat;      ps2_dat_s <= ps2_dat_meta;
      jxadc_meta   <= JXADC;        jxadc_s   <= jxadc_meta;
      btn_meta     <= btnU & btnD & btnL & btnR;
      btn_s        <= btn_meta;
    end if;
  end process;

  -- get scancode from keyboard (onboard USB HID host on C17/B17, clock_40)
  keyboard : entity work.io_ps2_keyboard
  port map (
    clk       => clock_40,
    kbd_clk   => ps2_clk_s,
    kbd_dat   => ps2_dat_s,
    interrupt => kbd_intr,
    scancode  => kbd_scancode
  );

  -- translate scancode to keys (MAME default keys, PS/2 set 2 codes), replaces
  -- kbd_joystick. F0 marks a release; E0 is ignored (keypad 8/2/4/6 alias the
  -- arrows, Right Ctrl/Alt alias Left Ctrl/Alt).
  process(clock_40)
  begin
    if rising_edge(clock_40) then
      if kbd_intr = '1' then
        if kbd_scancode = x"F0" then
          kbd_rel <= '1';
        elsif kbd_scancode /= x"E0" then
          kbd_rel <= '0';
          if kbd_scancode = x"75" then kbd_key(0)  <= not kbd_rel; end if; -- up arrow
          if kbd_scancode = x"72" then kbd_key(1)  <= not kbd_rel; end if; -- down arrow
          if kbd_scancode = x"6B" then kbd_key(2)  <= not kbd_rel; end if; -- left arrow
          if kbd_scancode = x"74" then kbd_key(3)  <= not kbd_rel; end if; -- right arrow
          if kbd_scancode = x"14" then kbd_key(4)  <= not kbd_rel; end if; -- left ctrl
          if kbd_scancode = x"11" then kbd_key(5)  <= not kbd_rel; end if; -- left alt
          if kbd_scancode = x"16" then kbd_key(6)  <= not kbd_rel; end if; -- 1
          if kbd_scancode = x"1E" then kbd_key(7)  <= not kbd_rel; end if; -- 2
          if kbd_scancode = x"2E" then kbd_key(8)  <= not kbd_rel; end if; -- 5
          if kbd_scancode = x"36" then kbd_key(9)  <= not kbd_rel; end if; -- 6
          if kbd_scancode = x"46" then kbd_key(10) <= not kbd_rel; end if; -- 9
        end if;
      end if;
    end if;
  end process;

  -- merge keyboard, buttons and JXADC joystick. JXADC is active-low (pressed
  -- shorts to ground); invert so a press reads active-high, matching the
  -- core's active-high input boundary and the keyboard path.
  coin1_in  <= kbd_key(8) or btn_s(3); -- 5 or btnU
  coin2_in  <= kbd_key(9) or btn_s(2); -- 6 or btnD
  start1_in <= kbd_key(6) or btn_s(1); -- 1 or btnL
  start2_in <= kbd_key(7) or btn_s(0); -- 2 or btnR
  sw2_in    <= sw(7 downto 0);         -- dip switch 2 from sw7-0 (not inverted, rework hardware 2026-10-19)
  joy_BBBBFRLDU(0) <= kbd_key(0) or not jxadc_s(3); -- up    (JXADC4)
  joy_BBBBFRLDU(1) <= kbd_key(1) or not jxadc_s(2); -- down  (JXADC3)
  joy_BBBBFRLDU(2) <= kbd_key(2) or not jxadc_s(1); -- left  (JXADC2)
  joy_BBBBFRLDU(3) <= kbd_key(3) or not jxadc_s(0); -- right (JXADC1)
  -- fire10 (speed up) : left ctrl, or any JXADC direction
  joy_BBBBFRLDU(4) <= kbd_key(4) or not (jxadc_s(3) and jxadc_s(2) and jxadc_s(1) and jxadc_s(0));
  joy_BBBBFRLDU(5) <= kbd_key(5) or not jxadc_s(4); -- fire11 (bomb) : left alt (JXADC7)

  -- Pad native 3/3/2-bit RGB to the VGA connector's 4-bit/channel input by
  -- MSB replication (identical to the pristine vga_r/vga_g/vga_b).
  vga_r <= r & '0'  when blankn = '1' else "0000";
  vga_g <= g & '0'  when blankn = '1' else "0000";
  vga_b <= b & "00" when blankn = '1' else "0000";

  -- Display mode select: sw(13) = 0 -> 31 kHz VGA, sw(13) = 1 -> 15 kHz TV:
  --   0 = 31 kHz VGA (real hsync/vsync)
  --   1 = 15 kHz TV  (native rate, composite sync on HS, VS held high)
  vga_hs <= csync when tv15Khz_mode = '1' else hsync;
  vga_vs <= '1'   when tv15Khz_mode = '1' else vsync;

  -- pwm sound output (reproduces the pristine top's exact accumulator, gated
  -- on clock_div = "0000").
  process(clock_40)
  begin
    if rising_edge(clock_40) then
      if clock_div = "0000" then
        pwm_accumulator  <= std_logic_vector(unsigned('0' & pwm_accumulator(16 downto 0)) + unsigned('0' & audio & '0'));
      end if;
    end if;
  end process;

  O_PMODAMP2_AIN   <= pwm_accumulator(17);
  O_PMODAMP2_SHUTD <= not sw(15); -- sw15 up = amp shut down (audio disabled)
  O_PMODAMP2_GAIN  <= not sw(14); -- sw14 up = gain active (GAIN active low)

end struct;

