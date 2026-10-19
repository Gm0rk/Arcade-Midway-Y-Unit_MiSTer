# Changelog

What changed in the Arcade-Midway-Y-Unit core, newest build first. Each build's changes are grouped by type: **Added**, **Changed**, **Fixed**, **Removed**, **Docs & tools**. Hardware test results are tracked in [docs/TestPlan.md](docs/TestPlan.md).

Build numbers count the core's development builds in order. Released RBF files are named by date. Builds 1 to 12 were named Arcade-MidwayY.

## Build 45 (2026-10-19)

**Docs & tools**
- TestPlan: Terminator 2 passes its last test (mouse aiming, T2-05), all 13 pass, and it is **Verified** (README status and progress bar: 3 / 8). 79 of 135 tests pass overall, none failed.

## Build 44 (2026-10-19)

**Docs & tools**
- TestPlan: hardware results for 30 more tests (78 of 135 passed, none failed). Mortal Kombat passes all 29 tests and is **Verified** (README status and progress bar: 2 / 8). Terminator 2 is at 12 of 13; only the mouse aiming test (T2-05) is still open.

## Build 43 (2026-10-19)

**Fixed**
- Strike Force and Total Carnage: the power-up RAM test ran about 4 % slower than the real board (it lost cycles in a loop that reads video memory, for about 200 frames in Strike Force and 300 or more in Total Carnage), so the boot screens finished a little late. The CPU's read of video memory now fetches the next 64-bit beat as well and keeps it, so the second read of the pair no longer waits for DDR3. Nothing is lost any more (0 cycles over 300 frames in both games). The other six games were already keeping up; their frames and audio are unchanged.

## Build 42 (2026-10-19)

**Docs & tools**
- Y-Unit Test ROM page: a picture at the top of the page.

## Build 41 (2026-10-19)

**Docs & tools**
- TestPlan: the Y-Unit Test ROM passes all 3 tests (picking tests with the DIP switches, and the Octopus Bookkeeping message). 48 of 135 tests pass overall, none failed.

## Build 40 (2026-10-19)

**Docs & tools**
- TestPlan: Mortal Kombat hardware results for 8 more tests (10 of 29 passed): controls, coins, picture, sound, Kano's Heart Rip, the Move List waiting behind its page, and Reptile Fight Next set and cleared. 46 of 135 tests pass overall, none failed.

## Build 39 (2026-10-19)

**Docs & tools**
- TestPlan: hardware results for 23 more tests (38 of 135 passed, none failed). Trog passes all 11 tests and is **Verified** (README status and progress bar: 1 / 8). Core-wide 8 / 19; Smash T.V. 8 / 10.

## Build 38 (2026-10-19)

**Docs & tools**
- Game pages: a title-screen and a gameplay picture at the top of each page (Y-Unit Test ROM excepted).

## Build 37 (2026-10-19)

**Changed**
- README Games table: Game, Main set, Status, Title Screen and Gameplay columns, with a title-screen and a gameplay picture for each game, in alphabetical order. The Players and Sound columns are gone (each game's page still lists them).

## Build 36 (2026-10-18)

**Docs & tools**
- `docs/ExtraContent.md`: everything the core adds to the original games, core-wide and per game, linked from the README.
- Every game page has an **Extra content** section with that game's extras. Kept up to date with every build, together with the README, the game pages, the test plan and this changelog.

## Build 35 (2026-10-18)

**Docs & tools**
- This changelog, back to Build 1. Kept up to date with every build.

## Build 34 (2026-10-16)

**Fixed**
- Sound: FM music no longer drones on after the music stops or changes. The YM2151 writes were too short for the chip's busy flag to ever show, so the sound programs' key-off loop ran faster than the chip could follow and about half the FM operators stayed on. Both sound boards.
- CRT V-Size: "+" (taller) goes only as far as the frame has room for, in PVM and Cabinet mode. At 57 Hz and 60 Hz Video Timing it cut the bottom of the picture (60 Hz at +7: 21 lines).
- CRT V-Size, PVM: switching it on keeps HSync running (it stopped for about 1.6 ms), switching back to 0 hands over at a frame boundary, and each output frame keeps the timing it started with (every frame used to end with a short line).
- Mortal Kombat: Start 1 and 2 are held released while the EJB Menu code plays. A Start press could start a game and spoil the code.
- Total Carnage: the Passwords page is centred on the 256-line picture (it was a line high, and its last two lines repeated the background's last row).
- TMS34010: display column address from DPYADR bits 6:2 as MAME does, and a window-violation interrupt no longer clears a display interrupt raised in the same clock. No game uses either.

**Docs & tools**
- README: CRT V-Size at 57 Hz and 60 Hz. TestPlan: C-05 (sync while V-Size changes), C-18 (V-Size at 57 Hz and 60 Hz), C-19 (FM notes stop with the music).

## Build 33 (2026-10-16)

**Fixed**
- Total Carnage: the high score table's wave effect drew with graphical glitches; it now waves in and out as in MAME. The game writes HEBLNK on every line during the picture, so each line now takes its own HEBLNK / HSBLNK, and the screen window changes only when the new values are valid and have stayed put for 3 frames, as MAME does. A line with HEBLNK equal to HSBLNK (nothing shown, how the wave starts) no longer sends the whole raster to the default timing.

**Docs & tools**
- TestPlan: TC-13 (the high score wave).

## Build 32 (2026-10-16)

**Added**
- Total Carnage: a **Passwords** page in the OSD (Off, On), drawn over the game with Total Carnage's title screen behind it: how to enter a code at the warp disc, the 16 warp codes by mission with where each takes you, and the Weasel and Orcus warp bonuses. The game waits while it shows.

**Docs & tools**
- `tools/yunit_window.py` writes the Passwords page and the second background; every code is checked in MAME and against the list in the program ROM.
- README, Total Carnage page: Passwords. TestPlan: C-01, TC-11, TC-12.

## Build 31 (2026-10-15)

MRAs and docs only: no new RBF.

**Fixed**
- DIP Switches: High Impact Football and Super High Impact Coinage showed 16 settings that shared 6 values, and the DIP menu, which steps on from the first setting with the current value, reached only two of the 16 (Free Play and the 2-coin settings never). The menu now lists the USA settings, which are the defaults, and all 6 can be reached.
- DIP Switches: the value could be pushed off the menu line when a switch's name and setting were long. Two-step coin settings are written short ("1C/1C - 2C/3C", "2C/1C - 4C/3C") and Strike Force's "Points for Extra Ship" is "Extra Ship Points".

**Docs & tools**
- `tools/mra_gen.py` stops on a switch that breaks the menu's limits.
- High Impact Football, Super High Impact and Strike Force pages follow the new settings. TestPlan: C-17 (every value shows), HI-13, SH-13, SF-11.

## Build 30 (2026-10-13)

**Added**
- Mortal Kombat rev 3.0, rev 4.0 and Turbo (Hidden Items): **Reptile Fight Next** (one time, used up when his fight starts), **Moon Silhouettes Always** and **Reptile Hints Always**, with messages when the fight is set or cleared. The core patches the game's program as it reads it; the ROM itself is untouched.

**Docs & tools**
- Mortal Kombat page: Reptile section. TestPlan: MK-25 to MK-29.

## Build 29 (2026-10-13)

**Changed**
- Mortal Kombat Move List option is **Off, Page 1, Page 2** (it was Off and the fighters).

## Build 28 (2026-10-12)

**Changed**
- Mortal Kombat Move List is on two pages, as in the T-Unit core: 1/2 (Johnny Cage, Kano, Sub-Zero, Sonya) and 2/2 (Raiden, Liu Kang, Scorpion), with MOVE / COMMAND / DISTANCE columns and The Pit in the footer. It was a page per fighter.
- DIP Switches: each switch's settings are in alphabetical order too (numbers by value). Every setting keeps its value.

## Build 27 (2026-10-12)

**Added**
- Mortal Kombat Move List as a window drawn over the game's dimmed title screen (the T-Unit core's information window), with the game paused while it shows.

**Changed**
- OSD order: Video Settings, Move List, Finishing Moves, DIP Switches, Hidden Items, Service Mode, Pause when OSD is open, Reset, Reset and close OSD. The Secrets page is now called Hidden Items.
- DIP Switches in alphabetical order in every game, with Service Credit, Tilt and Terminator 2's Gun Control and Crosshair among them.

**Removed**
- The Move List text page.

**Docs & tools**
- `tools/yunit_window.py` writes the window's pages and background. Game pages follow the new OSD names. TestPlan: MK-24, C-17.

## Build 26 (2026-10-09)

**Docs & tools**
- TestPlan: first hardware results. Every game boots to attract mode and its alternative MRAs play (Terminator 2's Boot and Strike Force's alternatives not filled in yet); the Y-Unit Test ROM boots.

## Build 25 (2026-10-09)

**Fixed**
- The picture stayed locked and black during a ROM or NVRAM download and the boot hold. The 34010's CRT counters stopped while the board was in reset, so the core sent no sync at all: the HDMI scaler showed its own frame buffer behind the loading box and an analog screen lost sync. The counters now run on the default 506 x 289 raster.

## Build 24 (2026-10-09)

**Fixed**
- Loading a second game in the same session showed the previous game's frame store and palette as stripes behind the loading box. The picture is now black while the board is held in reset. (Build 25 completed the fix: with no sync, the scaler still showed its own buffer.)

**Docs & tools**
- TestPlan: C-16 (loading another game keeps the screen black).

## Build 23 (2026-10-09)

**Docs & tools**
- README: status notice below the introduction (under testing, bugs expected, issues and pull requests not accepted for now).

## Build 22 (2026-10-09)

**Docs & tools**
- `docs/TestPlan.md`: the hardware test plan (core-wide and per-game tests, Pass / Fail), linked from the README. A game is verified when it passes every test.

## Build 21 (2026-10-09)

**Added**
- Mortal Kombat Finishing Moves in the OSD: pick a fighter's fatality or The Pit and the core enters it on the round winner's controls at FINISH HIM, with the distance measured the way the game does (from the fighters' centres). Messages say when it cannot (another fighter, The Pit on another stage, too far or too close, FINISH HIM over, not taken, cleared). Checked in MAME on all 11 Mortal Kombat sets.
- Mortal Kombat Move List (a text page at this build; a window from Build 27).
- OSD messages for the hidden-menu codes: code entered, not now, not taken, not in this revision.

**Changed**
- A hidden-menu code is played only when the game can take it (Super High Impact: only on HIGHEST PAID SUPERSTARS), and a message says when it works.

**Docs & tools**
- Mortal Kombat page: Finishing Moves and Move List. High Impact Football and Super High Impact pages: Octopus Bookkeeping messages. `tools/yunit_fmoves.py` finds the per-set addresses in the program ROMs.

## Build 20 (2026-10-09)

**Docs & tools**
- README split into a short overview plus one page per game in `docs/` (sets, ROM zip, players, controls, hidden menus, Terminator 2's gun options).

## Build 19 (2026-10-08)

**Docs & tools**
- README: AI disclosure below the title.

## Build 18 (2026-10-08)

**Added**
- Coins 3 and 4 from the third and fourth controllers on the 2-player boards, as in MAME: Smash T.V. and Total Carnage (coin 3), Strike Force and Terminator 2 (coins 3 and 4), Mortal Kombat (coin 3).

**Changed**
- Mortal Kombat buttons in the order High Punch, Low Punch, High Kick, Low Kick, Block. The board's second Block input stays open: the cabinet has one block button per player.
- Total Carnage's Start button is named Start/Bomb.

**Fixed**
- MRA folder `_alternatives/_Smash T.V.` is now `_Smash T.V_` (Windows drops the trailing dot).

**Docs & tools**
- Every game's controls checked against MAME's input ports: each of the 14 joystick bits on each of the 4 controllers, for every game id (784 cases, all match).

## Build 17 (2026-10-07)

**Added**
- CRT V-Size (experimental): vertical size for analog CRTs, in Video Settings with CRT Adjust on, up to 7 steps of 3 lines either way, in two modes. PVM changes the number of lines per frame; Cabinet keeps the native timing and blends neighbouring lines. Core-side; `sys/` untouched.

**Fixed**
- In the vendored CRT V-Size: PVM lost the first picture line and added a black one at the bottom; PVM showed the next frame's top under the picture from about 4 steps of "+".

**Docs & tools**
- README: feature, OSD table, credits (CRT V-Size by Umberto Parisi, rmonic79).

## Build 16 (2026-10-06)

**Changed**
- OSD main page: Video Settings, DIP Switches, Service Mode, Secrets, Pause when OSD is open, Reset, Reset and close OSD. Reset keeps the OSD open.
- Service Credit, Tilt and Terminator 2's Gun Control and Crosshair are entries in the DIP Switches menu. Service Credit and Tilt act as buttons: changing the entry is one press.

**Fixed**
- NVRAM is saved only when the OSD opens (if the game changed it). It used to save after every change in the OSD.
- Changing a DIP switch in the menu no longer resets the game.

**Removed**
- The Controls page.

## Build 15 (2026-10-05)

**Changed**
- The hidden-menu items moved to their own OSD page, **Secrets**, listed only for the games that have a hidden menu (Mortal Kombat, High Impact Football, Super High Impact).

## Build 14 (2026-10-05)

**Added**
- OSD shortcuts for the hidden developer menus, found by searching every game's program ROM: **EJB Menu** (Mortal Kombat) and **Octopus Bookkeeping** (High Impact Football, Super High Impact). The core plays the button code for you. The other games have none.

## Build 13 (2026-10-05)

**Changed**
- Project, Quartus revision, core and release names are now Arcade-Midway-Y-Unit (was Arcade-MidwayY). The OSD core name stays A.MIDWAYY. No logic change. MRAs regenerated with the new RBF name.

## Build 12 (2026-10-05)

**Added**
- Video Timing (Video Settings): the board's own 54.7 Hz, or 57 Hz / 60 Hz frames for TVs that do not hold 54.7 Hz. Only blank lines are dropped, so the whole picture is still sent and every display interrupt keeps firing. Games run about 4 % (57 Hz) or 10 % (60 Hz) faster; music and voices keep their normal pitch and tempo.

**Fixed**
- CRT V-Shift moved the wrong way with shorter frames; it now uses the measured frame length. A V-Shift that puts VSync on the picture blanks the smaller part instead of wrapping it to the other edge.

## Build 11 (2026-10-04)

**Fixed**
- Timing: the sound mixer works in registered steps (same output, one clock later), removing Build 10's worst path (-0.663 ns).
- Centred analog VSync no longer stops after about two frames when the board blanks whole frames, and a raster change no longer flicks the output back to the centred pulses for a few lines.

## Build 10 (2026-10-04)

**Fixed**
- Timing: Build 9 failed clk_sys setup by 1.24 ns. The board decodes a registered copy of the CPU's bus request, the blitter's zero flags are worked out when a source line is cached, and the centred-sync and CRT stage values are computed in registered steps. Same output, no cost on fast accesses. Games boot on hardware (the stop on the first screen seen with Builds 9 and 10 went away with a hard reboot of the MiSTer).

**Docs & tools**
- `release.tcl` moves the finished core to `releases/Arcade-MidwayY_YYYYMMDD.rbf` and the timing report lists the worst paths of each clock. `tools/timing_paths.tcl` lists the 100 worst setup paths without recompiling.

## Build 9 (2026-10-04)

**Fixed**
- Terminator 2 and Total Carnage: no sound. Their 128 KB sound ROM was not mirrored into the top of the sound area (the MRA generator did not recognise `ROM_RELOAD (`), so the sound CPU had no reset vector. The 9 MRAs were rebuilt.
- ADPCM boards: the OKI M6295 output now has MAME's full scale. It was 12 dB low against the YM2151 and DAC, so voices and sampled effects were quiet.

**Docs & tools**
- Every MRA checked byte for byte against the ROM regions MAME itself loads.

## Build 8 (2026-10-04)

MRAs only: the core is Build 7's.

**Added**
- Y-Unit Test ROM (v1.40) MRA, run with the Super High Impact settings.
- MD5 in all 45 MRAs, each checked against the merged MAME 0.289 sets.

## Build 7 (2026-10-04)

**Added**
- Centred analog sync: the core measures where the picture is and makes new HSync / VSync at the broadcast position around it, for a standard 15 kHz screen.
- CRT Auto-Width (Video Settings), with H-Size about the middle of the screen.

**Fixed**
- CRT Adjust: a negative H-Position blanked the analog picture.

## Build 6 (2026-10-04)

MRAs only: the core is Build 5's.

**Fixed**
- MRA md5 is computed the way Main_MiSTer's loader does it (over the ROM files in read order, before interleaving). Every checked MRA failed with "md5 mismatch for rom 0" and the ROM was not sent.

## Build 5 (2026-10-04)

**Added**
- Service Credit and Tilt as one-shot items on the OSD Controls page. Each holds its switch closed for 8 running frames, so it acts when the OSD closes.

**Removed**
- Service Credit and Tilt as controller buttons (Build 4).

## Build 4 (2026-10-04)

**Added**
- Service Credit and Tilt as mappable controller buttons, wired to every game's service credit and slam tilt inputs. Replaced by Build 5.

## Build 3 (2026-10-04)

**Fixed**
- Synthesis (Quartus error 276003): CMOS RAM is now an explicit true dual-port block RAM instance, with the same timing.
- Sound mixer clip value written as `16'sh8000` (warning 10259, same value).

## Build 2 (2026-10-04)

**Fixed**
- Synthesis (Quartus error 276003): CMOS RAM written in Intel's true dual-port template so it maps to block RAM instead of registers.

**Changed**
- TMS34010: register file writes go through two shared write ports instead of one multiplexer per register, about a third less CPU logic.

## Build 1 (2026-10-04)

**Added**
- First build of the Y Unit core, on Template_MiSTer (`sys/` unmodified).
- TMS34010 CPU from scratch following MAME's core, with PIXBLT / FILL engine and iterative multiply / divide, and the CRT controller.
- Y Unit board: address decode, main RAM, CMOS with NVRAM, palette RAM, program ROM cache in SDRAM, graphics ROM read-back, protection, control register, 96 MHz system clock with the CPU, VCLK and pixel clock enables from one phase counter.
- DMA blitter with MAME's clipping, flip and timing rules; 512 KB frame store in DDR3.
- CVSD and ADPCM sound boards: MC6809E, YM2151, OKI M6295, HC-55516, 6821 PIA, mixer.
- OSD with video settings, CRT Adjust, controls and DIP switches; game, DIP and NVRAM downloads; Terminator 2 guns and crosshairs.
- MRAs for every supported set (main sets at the top, clones in `_alternatives`) and the ROM layout and MRA generator.
