# Changelog

What changed in the Arcade-Midway-Y-Unit core, newest build first. Each build's changes are grouped by type: **Added**, **Changed**, **Fixed**, **Removed**, **Docs & tools**. Hardware test results are tracked in [docs/TestPlan.md](docs/TestPlan.md).

Build numbers count the core's development builds in order. Released RBF files are named by date. Builds 1 to 12 were named Arcade-MidwayY.

## Build 72 (2026-10-21)

**Docs & tools**
- README: Timing and resources from the Build 71 compilation (the RTL of Build 70, with the SDRAM controller as it was): **timing is met on every clock**. Setup on the 96 MHz system clock has 0.530 ns to spare (total negative slack 0, Fmax 101.15 MHz; Build 70: 0.207 ns); the HDMI PLL clock is now the closest, 0.212 ns, in the framework's scaler, shadow mask and OSD (`sys/`); hold, recovery, removal and minimum pulse width are met (hold >= 0.164 ns, recovery 2.210 ns, removal 0.679 ns, minimum pulse width 1.041 ns). On the 96 MHz clock the closest paths run from the game-ID register into the CRT V-Size line memory. Resource use is still from the Build 68 compilation.

## Build 71 (2026-10-21)

**Docs & tools**
- README: Timing and resources from the Build 70 compilation: **timing is met on every clock**. Setup on the 96 MHz system clock has 0.207 ns to spare (total negative slack 0, Fmax 97.95 MHz; Build 69: -0.109 ns); the HDMI PLL clock 0.454 ns; hold, recovery, removal and minimum pulse width are met. The closest paths are now the reset (the boot-hold counter's "not zero") into the TMS34010's function-unit data and multiplier registers, no longer the CRT V-Size stage. The margin is thin and moves from one compilation to the next. Resource use is from the Build 68 compilation.

## Build 70 (2026-10-21)

**Changed**
- Timing: the Build 69 compilation missed setup on the 96 MHz system clock by 0.109 ns (total negative slack 0.211 ns, two endpoints); the squaring paths of Build 68 no longer fail. CRT V-Size's "room for +" calculation (rtl/crt_adjust/crt_vsize.sv) is worked out in three registered steps instead of one long adder chain: the same answer three clocks later, used once a frame. No change to what the core does: the analog output is the same on every clock as in Build 69, in Cabinet and PVM, for 289 / 277 / 270 / 266-line frames (checked in simulation).

## Build 69 (2026-10-21)

**Changed**
- CRT V-Size, Cabinet mode: the blend squares the line memory's output one clock later, through one more register, and its remaining per-dot steps (mix, square root, output) move one clock later with it (rtl/crt_adjust/crt_vsize.sv). The Build 68 compilation missed setup on the 96 MHz system clock by 0.186 ns (total negative slack 0.374 ns, four endpoints, all in this stage): the line memory, its block-select mux and the squaring multiplier were all in one clock. The picture is the same: the analog output matches Build 68 on every clock (checked in simulation, Cabinet and PVM, for several H-Size, H-Position, V-Shift and V-Size settings). The README's timing report is still that of Build 65 until the next compilation.

## Build 68 (2026-10-20)

**Removed**
- Removed 60 Hz option from the OSD because games run too fast with it enabled.

## Build 67 (2026-10-20)

**Removed**
- CRT Adjust: **CRT Auto-Width** (Video Settings). It is not part of the official CRT Adjust; the OSD entry and the circuit behind it (the divider that worked out the H-Size from the picture width) are gone. It was Off unless turned on, and nothing else changes: H-Size, H-Position, V-Shift, V-Size and V-Size Mode work as before, and H-Size is the OSD's -16..+15 only. A saved setting from before is ignored. Checked in simulation with Auto-Width Off: the analog output (RGB, HSync, VSync, picture window, read clock) is identical clock for clock to the old circuit's, for 7 combinations of H-Size, H-Position, V-Shift and V-Size.

**Docs & tools**
- README, Extra content, TestPlan (C-04: CRT Adjust without Auto-Width; still Pass, 135 tests), the CSV and the release notes no longer mention it.

## Build 66 (2026-10-20)

**Docs & tools**
- README: Timing and resources from the Build 65 compilation (the RTL of Build 64): **timing is met on every clock**. Setup on the 96 MHz system clock has 0.067 ns to spare (total negative slack 0, Fmax 96.63 MHz; Build 63: -0.763 ns); the next clock, the HDMI PLL, 0.680 ns; hold, recovery, removal and minimum pulse width are met. The closest paths are now in `crt_vsize` (the line memory and the line-count arithmetic of CRT V-Size), no longer in the crosshair or the HQ2x filter. The paths file `output_files/Arcade-Midway-Y-Unit.paths.txt` was written by the build itself (Build 65), the first time.

## Build 65 (2026-10-20)

**Docs & tools**
- Every compilation now lists its worst timing paths by itself: after the build, `output_files/Arcade-Midway-Y-Unit.paths.txt` is written (the 100 worst setup paths of every clock, then the 10 worst in full), the file that used to need `quartus_sta -t tools/timing_paths.tcl` by hand. Quartus runs one post-flow script per project, so the project's now runs the new `post_flow.tcl`, which runs `release.tcl` (files the core in `releases/`, as before) and then `tools/timing_paths.tcl`. It takes a minute or two after the build and runs whether timing is met or not; a build that failed before the timing analysis leaves the last paths file alone. A problem is a warning in the Messages window, never a failed build. The script was tested with a stand-in for quartus_sta, not with Quartus itself.

## Build 64 (2026-10-20)

**Changed**
- Terminator 2 crosshair: the two "sight is here" flags are now registered (one 96 MHz clock late) before they are mixed into the picture. The Build 63 compilation met timing on every clock except the 96 MHz system clock, which failed by 0.763 ns (total negative slack 92.591 ns) on one path: the crosshair's position multiplier, the compare with the beam position and the colour mix, all in one clock, into the CRT V-Size line memory. Split in two, each half has about 4 ns to spare. The beam position changes only on the 8 MHz dot enable and the picture is read only on it, so the sight is drawn on exactly the same pixels as before (checked in simulation: no difference over 400 frames of random sight positions). The README's timing report is still that of Build 61 until the next compilation.

## Build 63 (2026-10-20)

**Changed**
- Timing constraints (Arcade-Midway-Y-Unit.sdc): a two-cycle exception (setup 2, hold 1) for paths between the registers of the HQ2x scandoubler filter's Blend stage (sys/hq2x.sv). They change only on the scandoubler's clock enable, which comes at least every 3 clocks while pixels flow (once more at each HSync edge, in the blanking), so they have more than one 96 MHz clock. This is the path that failed setup on the 96 MHz system clock by 0.538 ns in the Build 61 compilation. No RTL change; the next compilation's reports show whether setup now closes and what the next worst path is. The README's timing report is still that of Build 61.

## Build 62 (2026-10-20)

**Docs & tools**
- TestPlan: the last three tests pass (C-20 loading screen at 57 / 60 Hz, MK-19 Move List, MK-23 Move List during a fight). All 135 tests pass, none failed (core-wide 20 / 20, Mortal Kombat 28 / 28). Mortal Kombat is **Verified** again: all 8 games are verified (README status and progress bar: 8 / 8).
- README: new Timing and resources section from the Build 61 compilation (Quartus Prime 17.0.2 Lite, Cyclone V 5CSEBA6U23I7): setup slack and hold slack of every clock, the other checks' worst slacks, and the resource use. Setup on the 96 MHz system clock is not met (-0.538 ns, total negative slack 10.583 ns); the worst path is in the framework's HQ2x scandoubler filter (sys/hq2x.sv).

## Build 61 (2026-10-20)

**Fixed**
- Video Timing 57 Hz / 60 Hz: the ROM loading screen (the board held in reset while the ROMs load, and for half a second after) was always the board's own 54.7 Hz, so a TV that needs 57 or 60 Hz to hold the picture, as a Sony KV-27FS120 does, bounced on it until the game started. The default raster that keeps the display locked in reset now drops its blank lines like the running board, so it is 277 lines (57.08 Hz) or 263 lines (60.12 Hz) as selected, and the frame length no longer changes when the game starts. The game itself is unchanged.

**Docs & tools**
- README and Extra content: the loading screen has the Video Timing too.
- TestPlan: new core-wide test C-20 (loading screen at 57 / 60 Hz on analog), not run yet: core-wide 19 / 20, 135 tests overall (132 passed). The CSV has the same row.

## Build 60 (2026-10-20)

**Docs & tools**
- README: Testing setup lists a Consumer NTSC CRT (Sony KV-27FS120), a Broadcast PVM (Sony PVM-14L5) and the controllers (DualShock 4 over Bluetooth, Xbox 360 over USB), and says that consumer PAL TVs and analog connections other than component (YPbPr) are not tested. The Features list no longer opens with the analog sync and CRT Adjust bullets (both are still described in Extra content and the OSD table).

## Build 59 (2026-10-20)

**Docs & tools**
- README: new Testing setup section (DE10-Nano with the Analog I/O Board and 128 MB SDRAM; component (YPbPr) and HDMI connections; Sony KV-27FS120 NTSC CRT and Sony PVM-14L5).

## Build 58 (2026-10-20)

**Removed**
- Mortal Kombat Finishing Moves: **The Pit**. It is an ordinary uppercut (D+HP, up close, on The Pit stage), so the core no longer enters it: Finishing Moves lists the seven fatalities only, and the message "Stage move: The Pit only" is gone. The Move List's footer still says how to do it.

**Changed**
- Move List: now **Off / On** (it was Off, Page 1, Page 2). Close the OSD to see the list in full screen and press **Left or Right** on either controller to turn to the other page; with the OSD open the d-pad steers the OSD, so the page stays. The list starts on page 1 each time it is switched On, and the page's second line says how to turn the page and switch it off. A Move List saved by an earlier build as Page 1 comes back On, Page 2 comes back Off.
- The fatality player (rtl/yunit_fmoves.sv) no longer has the stage check or The Pit's own sequence; each move's record is one bit smaller. The fatalities themselves are played exactly as before (checked in simulation, 28 moves).

**Docs & tools**
- README, Mortal Kombat page and Extra content: the new Move List, no The Pit move.
- TestPlan: MK-15 (The Pit) is removed and the later Mortal Kombat tests are renumbered (28 tests); the Move List test (MK-19) and the one that sets it during a fight (MK-23) are rewritten and wait for a hardware test, so Mortal Kombat is 26 / 28 and back to **Awaiting hardware test** (README progress bar: 7 / 8). 134 tests overall, 132 passed. The CSV has the same rows.
- tools/yunit_fmoves.py, tools/yunit_window.py: no The Pit move; the window pages have the hint line.

## Build 57 (2026-10-20)

**Docs & tools**
- TestPlan: hardware results for the 11 remaining core-wide tests (C-03, C-04, C-05, C-11, C-12 and C-14 to C-19): all pass. Every section of the test plan now passes: 135 of 135 tests, none failed (core-wide 19 / 19).

## Build 56 (2026-10-20)

**Removed**
- Video Timing **480i** (added in Build 55). The list is Native 54.7 Hz, 57 Hz, 60 Hz again, and the analog output is as it was in Build 54. A TV that expects NTSC lines (15.7 kHz) did not lock to the 480i signal, whose lines are about 14.36 kHz; the 480i work is kept in a separate fork and is on hold. A Video Timing saved by Build 55 comes back one step along the list (480i as 57 Hz, 57 Hz as 60 Hz, 60 Hz as Native 54.7 Hz): select it again.

**Docs & tools**
- README, Extra content and TestPlan: the 480i text and test C-20 are taken out; core-wide is 19 tests (8 / 19 passed), 135 tests overall (124 passed), as before Build 55.

## Build 55 (2026-10-20)

**Added**
- Video Timing: new choice **480i** for the analog output: a 525-line interlaced signal with the board's 54.70684 Hz as the field rate (two fields are one 27.35 Hz frame) on lines of about 14.36 kHz (557 or 558 dots of 8 MHz). Each board frame is shown as one field: the picture lines go through a 32-line buffer onto the new line grid, so every picture line and dot is kept (254 lines, Smash T.V. 256) and the game, its speed and its sound are untouched (only the analog output changes). The fields are 263 and 262 lines, and VSync comes half a line later in the first one, which makes them interlace. The picture starts as many dots after HSync as before, so CRT Auto-Width, H-Size and H-Position act as at 54.7 Hz, with more room on the right (the line is 51 dots longer). It works with CRT Adjust on or off (off: no adjustments); CRT V-Size is not used. It needs the 15 kHz analog output (Scandoubler Fx None). About 6 to 8 of a field's 262.5 lines are left for VSync and blanking, so V-Shift has little room, as at 60 Hz. HDMI shows the same picture. While the raster is not measured (a game reprogramming it) the board's own timing is sent, and 480i starts again when it is.

**Changed**
- Video Timing list: Native 54.7 Hz, 480i, 57 Hz, 60 Hz. A 57 Hz or 60 Hz saved by an earlier build comes back as 480i or 57 Hz: select it again.

**Docs & tools**
- README and Extra content: Video Timing and the 480i option.
- TestPlan: new core-wide test C-20 (480i); core-wide now has 20 tests (8 / 20 passed), 136 tests overall (124 passed). The CSV has the same row.

## Build 53 (2026-10-20)

**Docs & tools**
- TestPlan: the "Core tested (rbf date)" line is removed (the tester's edited file). No test result changes.

## Build 52 (2026-10-20)

**Docs & tools**
- TestPlan: hardware results for 22 more tests. Strike Force (11 / 11) and Total Carnage (13 / 13) pass every test and are **Verified**: all 8 games are verified (README status and progress bar: 8 / 8). 124 of 135 tests pass overall, none failed; the 11 left are core-wide tests (8 / 19 passed). Total Carnage's switch test (TC-08) passes with the Build 51 press length. Strike Force and Terminator 2 notes (SF-06, T2-10): their daily score table is not kept either, like Smash T.V.'s TODAY (planned: an OSD option to save it).

## Build 51 (2026-10-20)

**Changed**
- Service Credit and Tilt (OSD DIP Switches, "Press"): the switch now stays closed for about half a second (30 frames; it was 8, about 0.15 s). Reported on Total Carnage, whose switch test showed no response: the lamp for a press lit for only the 0.15 s after the OSD closed, easy to miss. The game's wiring was checked against MAME (Tilt, Test and Service Credit are IN1 bits 3, 4 and 6 in both) and every game still takes exactly one credit or one slam from a press, however long it is held.

**Docs & tools**
- Total Carnage page: new Test menu section: how to light each lamp of the switch test. The Test Switch DIP (DS2:8) opens the game's test menu but never lights the TEST lamp (the same in MAME); the lamp follows Service Mode or the Test button.
- README and Extra content: the DIP Switches text says a press closes the switch for about half a second.
- TestPlan: TC-08 says what the switch test shows (the CSV has the same wording).

## Build 50 (2026-10-19)

**Docs & tools**
- TestPlan: typo in the Super High Impact notes (SH-08, SH-10) fixed.

## Build 49 (2026-10-19)

**Docs & tools**
- TestPlan: the Smash T.V. high score test (ST-07) passes with a score in the ALL TIME table; Smash T.V. passes all 10 tests and is **Verified** (README status and progress bar: 6 / 8). 103 of 135 tests pass overall, none failed.

## Build 48 (2026-10-19)

**Docs & tools**
- TestPlan: hardware results for 23 more tests (102 of 135 passed, 1 failed). High Impact Football and Super High Impact pass all 13 tests each and are **Verified** (README status and progress bar: 5 / 8). Smash T.V. is at 9 of 10; its high score test (ST-07) is marked failed and is being re-run (see below).
- Trog and Smash T.V. high scores: not a bug. Each game has two tables, and the second (Trog's DAILY DINOS, Smash T.V.'s TODAY) is reset by the game itself every time it starts, as on the board; only TOP TROGS / ALL TIME is kept. A score that makes only the second table is gone after a reload. Checked against MAME, which does the same, and against a saved Smash T.V. NVRAM file (the ALL TIME and TODAY tables hold the defaults; the audit counters were saved). TR-07 and ST-07 now say which table to make. Trog writes the table about 8 seconds after the initials, so wait for it to show before opening the OSD (Trog and Smash T.V. pages).

## Build 47 (2026-10-19)

**Docs & tools**
- Mortal Kombat page: the Move List text no longer refers to the Midway T-Unit core.

## Build 46 (2026-10-19)

**Docs & tools**
- README credits: the line crediting the Midway T-Unit core for the finishing-move player and the information window is removed; ppriest's MiSTer-CoreSkill is credited.

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
