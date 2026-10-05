---------------------------------------------------------------------------------
-- Basys3 Top level for Time Pilot by Dar (darfpga@aol.fr) (29/10/2017)
-- http://darfpga.blogspot.fr
--
-- Basys3 port by Red~Bote.
--
-- Ported from time_pilot_de10_lite.vhd (DE10-lite rev 00 29/10/2017):
--  - Single clock domain (2026-10-05, contrib/basys3/PORTING_SPEC.md section 2):
--    clk_wiz_0 derives clk_core = 24.573991 MHz (2 x 12.287 MHz) from the
--    100 MHz oscillator. The former clock_12 / clock_6 / clock_6n / clock_12n
--    edges are clock enables from a 2-bit phase counter; the former 14.318 MHz
--    sound clock is a phase-accumulator enable (ce14). Core and sound board are
--    patched to use them (contrib/code/time_pilot_single_domain.patch).
--  - Atari-style joystick on JA, OR-merged with the PS/2 keyboard (onboard USB-HID)
--  - Mono PWM audio on PmodAMP2 (JC); sw14 = shutdown, sw15 = gain select
--  - dip_switch_2 (sound/difficulty/bonus/cocktail/lives) mapped to sw(7:0)
--  - 31 kHz VGA via the MiST scandoubler (clk_sys = clk_core, ce_x1 = ce6,
--    ce_x2 = ce12); sw(13) = 1 selects 15 kHz TV (native RGB, csync on HS,
--    VS high)
--  - PS/2, JA and pushbuttons pass a 2-FF synchronizer into clk_core (PS/2
--    synchronizer re-instated 2026-10-05 after a raw-input evaluation, PORTING_SPEC
--    section 7)
--  - btnC = reset
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;

entity time_pilot_basys3 is
port(
 clk            : in  std_logic;
 sw             : in  std_logic_vector(15 downto 0);
 btnC           : in  std_logic;
 btnU           : in  std_logic;  -- coin
 btnL           : in  std_logic;  -- 1P start
 btnR           : in  std_logic;  -- 2P start

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

 -- Phase counter: 4 clk_core edges per former 6 MHz period.
 --   e0 = clock_6 rising (end of ph="11"), e1 = clock_12 falling (ph="00"),
 --   e2 = clock_6 falling (ph="01"),       e3 = clock_12 falling (ph="10").
 signal ph       : std_logic_vector(1 downto 0) := "00";
 signal ce6      : std_logic;  -- e0
 signal ce6n     : std_logic;  -- e2
 signal ce12     : std_logic;  -- e0, e2
 signal ce12n    : std_logic;  -- e1, e3
 signal clk6_lvl : std_logic;  -- former clock_6 level: '1' from e0 to e2

 -- 14.318181 MHz sound enable: 20-bit phase accumulator,
 -- 610959 / 2^20 x 24.573991 MHz = 14.318181 MHz (-0.06 ppm vs 315/22 MHz).
 constant CE14_INC : unsigned(20 downto 0) := to_unsigned(610959, 21);
 signal ce14_acc  : unsigned(20 downto 0) := (others => '0');
 signal ce14      : std_logic;

 signal r         : std_logic_vector(4 downto 0);
 signal g         : std_logic_vector(4 downto 0);
 signal b         : std_logic_vector(4 downto 0);
 signal csync     : std_logic;
 signal blankn    : std_logic;
 signal hsync     : std_logic;
 signal vsync     : std_logic;

 signal audio           : std_logic_vector(10 downto 0);
 signal pwm_accumulator : std_logic_vector(12 downto 0);
 signal pwm_prev        : std_logic_vector(12 downto 0);  -- '0' & accumulator(11:0)
 signal audio_x4        : std_logic_vector(12 downto 0);  -- audio & "00"

 signal vga_ro    : std_logic_vector(5 downto 0);
 signal vga_go    : std_logic_vector(5 downto 0);
 signal vga_bo    : std_logic_vector(5 downto 0);
 signal vga_hs_o  : std_logic;
 signal vga_vs_o  : std_logic;

 signal video_ri  : std_logic_vector(5 downto 0);
 signal video_gi  : std_logic_vector(5 downto 0);
 signal video_bi  : std_logic_vector(5 downto 0);

 -- PS/2, JA(4 downto 0) and btnR/btnL/btnU, 2-FF synchronized (index 1 = output).
 signal ps2_clk_s, ps2_dat_s : std_logic_vector(1 downto 0) := "11";
 type in_sync_t is array (1 downto 0) of std_logic_vector(7 downto 0);
 signal in_s : in_sync_t := (others => (others => '1'));
 attribute ASYNC_REG of ps2_clk_s, ps2_dat_s, in_s : signal is "TRUE";
 signal ja_s      : std_logic_vector(4 downto 0);
 signal btnU_s, btnL_s, btnR_s : std_logic;

 signal kbd_intr      : std_logic;
 signal kbd_scancode  : std_logic_vector(7 downto 0);
 signal kbd_joy       : std_logic_vector(7 downto 0);
 signal joyPCFRLDU    : std_logic_vector(7 downto 0);

 signal dbg_cpu_addr : std_logic_vector(15 downto 0);

begin

-- 100 MHz -> clk_core 24.573991 MHz (single output)
clocks : entity work.clk_wiz_0
port map(
 clk_in1  => clk,
 clk_out1 => clk_core,
 reset    => btnC,
 locked   => mmcm_locked
);

-- Core held in reset until the MMCM locks (sf-darfpga/CLOCKING_SPEC.md section 6);
-- asserted asynchronously, released synchronously to clk_core.
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

 dip_switch_1 => X"FF", -- Coinage_B / Coinage_A
 dip_switch_2 => sw(7 downto 0), -- Sound(8)/Difficulty(7-5)/Bonus(4)/Cocktail(3)/lives(2-1)

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
-- Core outputs 5 bits/color (Pooyan: 3+3+2); pad 1 bit.
video_ri <= (r & "0") when blankn = '1' else "000000";
video_gi <= (g & "0") when blankn = '1' else "000000";
video_bi <= (b & "0") when blankn = '1' else "000000";

scandoubler_inst : scandoubler
port map(
 clk_sys   => clk_core,
 scanlines => "00",
 ce_x1     => ce6,    -- 6.1435 MHz pixel enable
 ce_x2     => ce12,   -- exactly 2 x ce_x1
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

-- Display mode via sw(13): 0 = 31 kHz VGA (scandoubler), 1 = 15 kHz TV
-- (native RGB gated on blankn, csync on HS, VS high).
vga_r  <= vga_ro(5 downto 2) when sw(13) = '0' else video_ri(5 downto 2);
vga_g  <= vga_go(5 downto 2) when sw(13) = '0' else video_gi(5 downto 2);
vga_b  <= vga_bo(5 downto 2) when sw(13) = '0' else video_bi(5 downto 2);
vga_hs <= vga_hs_o           when sw(13) = '0' else csync;
vga_vs <= vga_vs_o           when sw(13) = '0' else '1';

-- Input synchronizers (2-FF) into clk_core
process (clk_core)
begin
	if rising_edge(clk_core) then
		ps2_clk_s <= ps2_clk_s(0) & ps2_clk;
		ps2_dat_s <= ps2_dat_s(0) & ps2_dat;
		in_s(0)   <= btnR & btnL & btnU & JA;
		in_s(1)   <= in_s(0);
	end if;
end process;

ja_s   <= in_s(1)(4 downto 0);
btnU_s <= in_s(1)(5);
btnL_s <= in_s(1)(6);
btnR_s <= in_s(1)(7);

-- get scancode from keyboard
keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clk_core,
  kbd_clk   => ps2_clk_s(1),
  kbd_dat   => ps2_dat_s(1),
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- translate scancode to joystick
joystick : entity work.kbd_joystick
port map (
  clk           => clk_core,
  kbdint        => kbd_intr,
  kbdscancode   => std_logic_vector(kbd_scancode),
  joyPCFRLDU    => kbd_joy
);

-- OR-merge the Atari-style joystick on JA with the PS/2 keyboard joystick.
-- JA physical map (matches the sibling port): JA1=right, JA2=left, JA3=down, JA4=up, JA7=fire,
-- i.e. JA(0)=right, JA(1)=left, JA(2)=down, JA(3)=up, JA(4)=fire.
-- JA is active-low (pressed shorts to ground); invert so a press reads active-high, matching the
-- core's active-high input boundary and the keyboard path.
-- Coin/start come from the keyboard and btnU/btnL/btnR
-- (JA fire+direction coin/start combos removed 2026-10-02; dedicated buttons cover them).
joyPCFRLDU(0) <= kbd_joy(0) or not ja_s(3);               -- up    (JA4)
joyPCFRLDU(1) <= kbd_joy(1) or not ja_s(2);               -- down  (JA3)
joyPCFRLDU(2) <= kbd_joy(2) or not ja_s(1);               -- left  (JA2)
joyPCFRLDU(3) <= kbd_joy(3) or not ja_s(0);               -- right (JA1)
joyPCFRLDU(4) <= kbd_joy(4) or not ja_s(4);               -- fire  (JA7)
joyPCFRLDU(5) <= kbd_joy(5) or btnU_s; -- coin   = btnU
joyPCFRLDU(6) <= kbd_joy(6) or btnL_s; -- start1 = btnL
joyPCFRLDU(7) <= kbd_joy(7) or btnR_s; -- start2 = btnR

-- pwm sound output (accumulates at the former clock_14 rate)
-- (concatenations assigned to typed signals first: inside a type conversion the
--  result type of '&' is ambiguous with numeric_std and std_logic_unsigned visible)
pwm_prev <= '0' & pwm_accumulator(11 downto 0);
audio_x4 <= audio & "00";

process(clk_core)
begin
  if rising_edge(clk_core) and ce14 = '1' then
    pwm_accumulator  <=  std_logic_vector(unsigned(pwm_prev) + unsigned(audio_x4));
  end if;
end process;

O_PMODAMP2_AIN   <= pwm_accumulator(12);
O_PMODAMP2_SHUTD <= sw(14);  -- shutdown: 0 = off, 1 = on
O_PMODAMP2_GAIN  <= sw(15);  -- gain: 0 = 12 dB, 1 = 6 dB

end struct;
