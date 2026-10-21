# Williams/Midway Y Unit for [MiSTer](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

> **AI disclosure:** this core was developed with the help of an AI assistant
> (Claude, by Anthropic).

An FPGA implementation of the Williams/Midway Y Unit arcade board (1990-1992),
the TMS34010-based platform behind Smash T.V., Trog, High Impact Football,
Mortal Kombat and Terminator 2.

## Table of Contents

- [Hardware](#hardware)
- [Games](#games)
- [Testing setup](#testing-setup)
- [Timing and resources](#timing-and-resources)
- [Features](#features)
- [OSD](#osd)
- [Controls](#controls)
- [ROMs](#roms)
- [Credits and references](#credits-and-references)
- [License](#license)
- [Extra content](docs/ExtraContent.md)
- [Test plan](docs/TestPlan.md)

## Hardware

| | |
|---|---|
| Main CPU | TMS34010 graphics system processor, 40 / 48 / 50 MHz master clock depending on the game (5 / 6 / 6.25 MHz instruction clock) |
| Video | 512 x 512 x 16-bit frame store, DMA blitter with zero/non-zero/colour modes, X flip and clipping, scanline autoerase |
| Palette | 256 (4 bpp boards) or 4096 (6 bpp boards) colours from 15-bit RGB |
| Display | 8 MHz pixel clock, about 400 x 256 visible, 54.7 Hz |
| Sound (CVSD board) | MC6809E @ 2 MHz, YM2151, HC-55516 CVSD speech, 8-bit DAC, 6821 PIA |
| Sound (ADPCM board) | MC6809E @ 2 MHz, YM2151, OKI M6295, 8-bit DAC |
| Protection | 34010-side PAL sequences and sound-CPU hidden RAM, as in MAME |

## Games

Each game has its own page in [`docs`](docs) with its revisions, controls and
game-specific features. Everything the core adds, core-wide and per game, is
listed in [Extra content](docs/ExtraContent.md).

| Game | Main set | Status | Title Screen | Gameplay |
|---|---|---|---|---|
| [High Impact Football](docs/HighImpactFootball.md) | hiimpact (rev LA5) | Verified | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/High_Impact_Football.png" width="300" alt="High Impact Football title screen"> | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/High_Impact_Football2.png" width="300" alt="High Impact Football gameplay"> |
| [Mortal Kombat](docs/MortalKombat.md) | mkla4 (rev 4.0) | Verified | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Mortal_Kombat.png" width="300" alt="Mortal Kombat title screen"> | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Mortal_Kombat_2.png" width="300" alt="Mortal Kombat gameplay"> |
| [Smash T.V.](docs/SmashTV.md) | smashtv (rev 8.00) | Verified | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Smash_TV.png" width="300" alt="Smash T.V. title screen"> | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Smash_TV_2.png" width="300" alt="Smash T.V. gameplay"> |
| [Strike Force](docs/StrikeForce.md) | strkforc (rev 1) | Verified | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Strikeforce.png" width="300" alt="Strike Force title screen"> | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Strikeforce_2.png" width="300" alt="Strike Force gameplay"> |
| [Super High Impact](docs/SuperHighImpact.md) | shimpact (rev LA2) | Verified | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Super_High_Impact_Football.png" width="300" alt="Super High Impact title screen"> | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Super_High_Impact_Football_2.png" width="300" alt="Super High Impact gameplay"> |
| [Terminator 2 - Judgment Day](docs/Terminator2.md) | term2 (rev LA4) | Verified | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Terminator_2_Judgement_Day.png" width="300" alt="Terminator 2 - Judgment Day title screen"> | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Terminator_2_Judgement_Day_2.png" width="300" alt="Terminator 2 - Judgment Day gameplay"> |
| [Total Carnage](docs/TotalCarnage.md) | totcarn (rev LA1) | Verified | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Total_Carnage.png" width="300" alt="Total Carnage title screen"> | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Total_Carnage_2.png" width="300" alt="Total Carnage gameplay"> |
| [Trog](docs/Trog.md) | trog (rev LA5), prototype rev 4.00 | Verified | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Trog.png" width="300" alt="Trog title screen"> | <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Trog_2.png" width="300" alt="Trog gameplay"> |

Verified on hardware: `[████████████████████]` 8 / 8

A game is verified when it passes every test of the
[test plan](docs/TestPlan.md), which tracks the progress.

Also included: Midway's board diagnostic, the
[Y-Unit Test ROM](docs/YUnitTestROM.md). Other revisions, prototypes and
hacks are in the `_alternatives` folder of the MRAs.

## Testing setup

The hardware tests behind the status above are run on:

| | |
|---|---|
| MiSTer | DE10-Nano with the Analog I/O Board and 128 MB SDRAM |
| Analog connection | Component (YPbPr) |
| Digital connection | HDMI |
| Consumer NTSC CRT | Sony KV-27FS120 |
| Broadcast PVM | Sony PVM-14L5 |
| Controllers | DualShock 4 (Bluetooth), Xbox 360 (USB) |

> **Not tested:** consumer PAL TVs, and analog connections other than
> component (YPbPr).

## Timing and resources

Timing is from the Quartus Prime 17.0.2 Lite compilation of Build 71
(2026-10-21), resource use from that of Build 68 (Builds 69 to 71 only add a
few pipeline registers), for the DE10-Nano's Cyclone V 5CSEBA6U23I7. The
project runs one timing model, Slow 1100 mV 100 C. All 135 hardware tests pass
(see the [test plan](docs/TestPlan.md)).

**Timing is met on every clock**, and so is every hold, recovery, removal and
minimum pulse width check. The 96 MHz system clock has 0.530 ns to spare (the
clock's Fmax is 101.15 MHz); the closest clock is the HDMI PLL's, with
0.212 ns, in the MiSTer framework's scaler, shadow mask and OSD (`sys/`). The
margins move with every change to the design and from one compilation to the
next. On the 96 MHz clock the closest paths run from the game-ID register into
the CRT V-Size line memory.

| Clock | Frequency | Setup slack | Hold slack |
|---|---|---|---|
| System (core PLL) | 96 MHz | 0.530 ns | 0.247 ns |
| HDMI PLL | 148.54 MHz | 0.212 ns | 0.164 ns |
| HPS user clock | 100 MHz | 3.682 ns | 0.360 ns |
| SPI | 100 MHz | 5.294 ns | 0.296 ns |
| FPGA_CLK1_50 | 50 MHz | 8.738 ns | 0.414 ns |
| FPGA_CLK2_50 | 50 MHz | 11.379 ns | 0.374 ns |
| Audio PLL | 24.58 MHz | 13.991 ns | 0.245 ns |

Worst recovery slack 2.210 ns, removal 0.679 ns, minimum pulse width 1.041 ns.

| Resource | Used |
|---|---|
| Logic (ALMs) | 28,536 / 41,910 (68 %) |
| Registers | 29,374 |
| Block RAM (M10K blocks) | 403 / 553 (73 %) |
| Block memory bits | 3,074,807 / 5,662,720 (54 %) |
| DSP blocks | 68 / 112 (61 %) |
| PLLs | 3 / 6 (50 %) |
| Pins | 145 / 314 (46 %) |

## Features

- CRT V-Size (experimental), part of CRT Adjust: makes the picture taller
  ("+") or shorter ("-"), up to 7 steps of 3 lines (about 1 % each), in one
  of two modes:
  - PVM: changes the number of lines per frame, so every line stays sharp
    and unique, but the line rate moves about 1 % per step. For monitors
    that hold a wide range of line rates (PVM/BVM and similar)
  - Cabinet: keeps the exact native timing and blends neighbouring lines
    (a slight, even vertical softness). For arcade monitors and TVs that
    will not follow a change of line rate

  The middle of the picture moves as it resizes; recentre it with V-Shift.
  Changes are applied a line per frame. With the 57 Hz Video Timing there is
  little room around the picture, so "+" goes only as far as the whole
  picture still fits. On HDMI,
  PVM leaves the picture untouched and Cabinet shows the resized picture
- Video Timing: the board's own 54.7 Hz, or 57 Hz frames for TVs that do
  not hold 54.7 Hz. Only blank lines are dropped, so the whole picture is
  still sent; games run about 4 % faster, while music and voices keep their
  normal pitch and tempo. The loading screen has the same timing
- CMOS saved as NVRAM: settings, audits and high scores survive power-off.
  It is saved when the OSD is opened, if the game has changed it
- DIP switches in the OSD, taken from MAME; changes apply after a reset
- Service Mode, Service Credit and Tilt in the OSD; pause from a button or
  while the OSD is open
- Shortcuts to the hidden developer menus of the games that have one (see
  their pages), with a message saying whether the menu opened or when the
  code works
- Mortal Kombat: a Move List (each fighter's moves, fatality and the
  distance it needs, on a page over the game; close the OSD and press Left
  or Right to turn the page) and Finishing Moves (the core enters the
  winner's fatality at FINISH HIM), with messages when
  a move cannot be played; Reptile on demand: his fight next, the moon
  silhouettes and his hints every time (see the
  [Mortal Kombat page](docs/MortalKombat.md))
- Total Carnage: a Passwords page, every warp code and where it takes you,
  over the game (see the [Total Carnage page](docs/TotalCarnage.md))

## OSD

| Item | |
|---|---|
| Video Settings | Aspect ratio, scandoubler, scale, Video Timing, CRT Adjust (H-Size, H-Position, V-Shift, V-Size, V-Size Mode) |
| Move List | Mortal Kombat: Off, On; shows the move list (four fighters, then three: special moves, fatality and the distance it needs, The Pit's uppercut) over the game, which waits until it is Off; with the OSD closed, Left or Right turns the page |
| Finishing Moves | Mortal Kombat: each fighter's fatality, entered for you at the next FINISH HIM |
| Passwords | Total Carnage: Off, On; shows the warp codes (how to enter one, where each takes you, the two warp bonuses) over the game, which waits until it is Off |
| DIP Switches | The game's DIP switches with Service Credit and Tilt (select "Press" to drop a service credit or close the slam switch; the switch stays closed for about half a second once the game runs again) and any game-specific entries; the switches and each one's settings in alphabetical order |
| Hidden Items | Hidden developer menus, only for the games that have one; Mortal Kombat rev 3.0, 4.0 and Turbo also Reptile Fight Next, Moon Silhouettes Always and Reptile Hints Always |
| Service Mode | The cabinet's test switch |
| Pause when OSD is open | On by default |
| Reset / Reset and close OSD | Reset keeps the OSD open |

## Controls

Every game has Start, Coin, Test (service mode) and Pause on each controller,
plus its own buttons, named in the controller setup and listed on its page.
Coins 3 and 4 are on the third and fourth controllers' Coin buttons where
the game has them.

## ROMs

ROMs are **not** included in this repository; you need your own dumps of the
games.

Use **merged** ROM sets from MAME 0.289 (recommended): one zip per game holds
every revision, so all of that game's MRAs, main and alternatives, find
their files. Mortal Kombat's merged set is `mk.zip`; the other zip names are
on each game's page. Files are found by CRC, and split sets (each revision
next to its parent zip) also work.

Put the zips in `games/mame`, the MRA files in `_Arcade` and the core in
`_Arcade/cores`.

## Credits and references

- MAME Y Unit driver: Alex Pasadyn, Zsolt Vasvari, Ernesto Corvi, Aaron Giles
  (thanks to Kurt Mahan); MAME TMS34010 core, Williams sound boards, 6821 PIA
  and HC-55516 model (Jonathan Gevaryahu) - the reference for this core's
  behaviour
- Texas Instruments TMS34010 User's Guide
- mc6809 core: Greg Miller (synchronous version by Sorgelig)
- jt51 (YM2151) and jt6295 (OKI M6295): Jose Tejada (jotego)
- SDRAM controller and MiSTer framework: Sorgelig and the MiSTer-devel team
- CRT Adjust and CRT V-Size: Umberto Parisi (rmonic79), with Andrea Bogazzi
  (@asturur)
- [Template_MiSTer](https://github.com/MiSTer-devel/Template_MiSTer),
  [MiSTer-CRT-Adjust](https://github.com/rmonic79/MiSTer-CRT-Adjust)
- ppriest: [MiSTer-CoreSkill](https://github.com/ppriest/MiSTer-CoreSkill),
  the arcade core guidance used while developing and checking this core

## License

GPL-3.0-or-later. Third-party modules keep their own licenses (see `rtl/mc6809`,
`rtl/jt51`, `rtl/jt6295`, `rtl/crt_adjust`).
