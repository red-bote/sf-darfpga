# FPGA ports to the Digilent Basys 3

Ports of Dar's FPGA arcade cores (darfpga@aol.fr, <http://darfpga.blogspot.fr>) to the
Digilent Basys 3 (Artix-7 `xc7a35tcpg236-1`), by Red~Bote. Each machine is an independent
project in its own `<Machine>-by-Dar/` directory, built with Vivado 2020.2. Each machine
README gives its controls, switches and clocks; its `contrib/basys3/PORTING_SPEC.md` the
design detail. Porting procedure: `PORTING_SPEC.md`.

## Machines

All 20 are fully scripted and hardware-verified on the Basys 3.

| Machine                                      | Romset(s)                     |
|----------------------------------------------|-------------------------------|
| [Bagman][] (Valadon / Stern 1982)            | `bagman.zip`                  |
| [Berzerk][] (Stern 1980)                     | `berzerk.zip`                 |
| [BurgerTime][] (Data East 1982)              | `btime.zip`                   |
| [Burnin' Rubber][] (Data East 1982)          | `brubber.zip`                 |
| [Computer Space][] (Nutting Associates 1971) | none (discrete logic)         |
| [Crazy Kong][] (Kyoei / Falcon 1981)         | `ckong.zip`                   |
| [Defender][] (Williams 1981)                 | `defender.zip`                |
| [Galaga][] (Namco / Midway 1981)             | `galaga.zip` + `galagamw.zip` |
| [Kick][] (Midway MCR 1981)                   | `kick.zip`                    |
| [Phoenix][] (Amstar 1980)                    | `phoenix.zip`                 |
| [Pooyan][] (Konami 1982)                     | `pooyan.zip`                  |
| [Popeye][] (Nintendo 1982)                   | `popeye.zip` + `popeyeu.zip`  |
| [Satan's Hollow][] (Bally Midway MCR 1981)   | `shollow.zip`                 |
| [Sky Skipper][] (Nintendo 1981)              | `skyskipr.zip`                |
| [Solar Fox][] (Bally Midway 1981)            | `solarfox.zip`                |
| [Time Pilot][] (Konami 1982)                 | `timeplt.zip`                 |
| [Traverse USA][] (Irem 1983)                 | `travrusa.zip`                |
| [Tron][] (Midway MCR 1982)                   | `tron.zip` + `midssio.zip`    |
| [Xevious][] (Namco 1982)                     | `xevious.zip`                 |
| [Zaxxon][] (Gremlin / Sega 1980)             | `zaxxon.zip`                  |

[Bagman]: Bagman-FPGA-Dar/README.md
[Berzerk]: Berzerk-FPGA-by-Dar/README.md
[BurgerTime]: Burger-Time-by-Dar/README.md
[Burnin' Rubber]: Burnin-Rubber-by-Dar/README.md
[Computer Space]: Computer-Space-by-Dar/README.md
[Crazy Kong]: Crazy-Kong-by-Dar/README.md
[Defender]: Defender-by-Dar/README.md
[Galaga]: Galaga-Midway-by-Dar/README.md
[Kick]: Kick-Midway-MCR-by-Dar/README.md
[Phoenix]: Phoenix-by-Dar/README.md
[Pooyan]: Pooyan-by-Dar/README.md
[Popeye]: Popeye-by-Dar/README.md
[Satan's Hollow]: Satans-Hollow-by-Dar/README.md
[Sky Skipper]: Sky-skipper-by-Dar/README.md
[Solar Fox]: Solar-Fox-by-Dar/README.md
[Time Pilot]: Time-Pilot-by-Dar/README.md
[Traverse USA]: Traverse-USA-by-Dar/README.md
[Tron]: Tron-by-Dar/README.md
[Xevious]: Xevious-by-Dar/README.md
[Zaxxon]: Zaxxon-by-Dar/README.md

## What to connect

- VGA monitor on the VGA port. With sw13 up the output is 15 kHz RGB (csync on HS), for
  a 15 kHz RGB monitor or an RGB-to-composite converter.
- USB keyboard on the USB-HID host connector.
- Atari-type joystick (switches to GND) on Pmod JXADC: pins 1/2/3/4/7 = right / left /
  down / up / fire.
- PmodAMP2 with a speaker on Pmod JA (top row). Mono audio.

## Common controls

- Keyboard: MAME default keys (arrows, Left Ctrl, Left Alt, 1/2 = start, 5/6 = coin);
  each machine README lists its full map.
- Buttons: btnC = reset, btnU/btnD = coin, btnL/btnR = start 1/2.
- Switches: sw15 up = audio off, sw14 up = amplifier gain, sw13 up = 15 kHz RGB; spare
  switches carry the machine's DIP settings (switch down = original default).

## Building

Each machine builds on its own; see the Building section of its README. Romsets go in
`~/roms/`, or set `ROMZIP`.

From this directory:

- `make bitstream`: build every machine that has no bitstream yet.
- `make bitstream-<machine>`: build one machine, e.g. `make bitstream-pooyan`.
- `make clean`: remove the extracted sources and build output of every machine. The
  archives in `dloads/` are kept.
- `make help`: list all targets.

Procedure details: `PORTING_SPEC.md` sections 1 and 2, and `AGENTS.md`.

## Shared tools

`tools/vhdl_formatter.py`, the VHDL formatter for the Basys 3 top levels:

- one statement per line, with a fixed indent (`--indent`, default 2);
- aligned declarations, assignments and trailing comments;
- `--check` verifies without rewriting;
- Python standard library only; running it twice gives the same result.

## Copyright

Roms and the generated PROM VHDL are copyrighted content and are never committed or
distributed. The `.patch` files are the tracked record of changes to Dar's sources.

