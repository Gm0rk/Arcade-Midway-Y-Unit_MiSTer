# Changelog

What changed in the Arcade-Midway-Y-Unit core, newest build first. Each build's changes are grouped by type: **Added**, **Changed**, **Fixed**, **Removed**, **Docs & tools**.

Build numbers count the core's development builds in order. Released RBF files are named by date. Builds 1 to 12 were named Arcade-MidwayY.

## Build 95 (2026-10-29)

**Docs & tools**
- Mortal Kombat, Fixed AI Difficulty: the README, Extra content, the Mortal Kombat page and the release notes now say how the option treats the two bosses. Goro and Shang Tsung have no difficulty curve of their own; they read the same level word as every other fighter. Shang Tsung follows it like the normal fighters. Goro follows it much less: in MAME on mkla4, his fight replayed at level 0 and at level 9 with the same inputs stayed identical for the first four and a half seconds, and afterwards the game reads the level only in short bursts, where the other fighters read it all the time. Expect Goro to stay hard at a low setting and not to get much harder at a high one. How large the difference is was not measured, and the tests were run in MAME with one fighter, not on hardware.
- No change to the core: the program is Build 93's.

## Build 94 (2026-10-29)

**Docs & tools**
- Mortal Kombat, Fixed AI Difficulty: the README, Extra content, the Mortal Kombat page and the release notes now say exactly when the option takes effect. Set it in the OSD before you press Start to begin a game: the game sets the CPU level the moment Start is pressed, before the character select (checked in MAME on mkla4), and the core replaces it with yours, so the first fight is already at your level. Putting the coin in before or after makes no difference, and the attract mode's demo fights use the level too. Changed during a game, it takes effect when the current match ends; set back to Off during a game, the level stays where it is and the game's own curve carries on from there.
- No change to the core: the program is Build 93's.

## Build 93 (2026-10-28)

**Changed**
- Fitter seed 2 (was 1). The Build 92 program compiled with seed 1 met every timing check but one: the 96 MHz setup check by 0.129 ns (3 endpoints, 0.198 ns in total), in the framework's composite / S-Video encoder (`yc_out`, in `sys/`), a block this core does not change. With seed 2 every check is met. The program (the RTL) is Build 92's.

**Docs & tools**
- README: the timing and resource figures are those of this compilation: setup slack 0.477 ns (96 MHz) and 0.283 ns (HDMI PLL), at least 2.7 ns on every other clock; hold, recovery, removal and minimum pulse width met; 29,246 ALMs (70 %), 437 M10K blocks (79 %), 65 DSP blocks (58 %). The margins move a little with every compilation.

## Build 92 (2026-10-28)

**Added**
- **Opposite directions: the last press wins**, in every game. When Up and Down, or Left and Right, are held together, only the one pressed last reaches the game; letting it go hands control back to the one still held. If both are pressed in the same instant the axis reads neutral until one is let go; a single direction, and a diagonal, are as before. It applies to every player's stick (Trog's 4-way filter included) and to the fire directions of Smash T.V. and Total Carnage (B1-B4 and the right analog stick). A cabinet's stick cannot hold opposite directions, but a d-pad, a keyboard or buttons mapped to directions can, and Smash T.V. is reported to crash on it. It is always on; there is no OSD item.
  - Checked in simulation: the filter was run for 1 million clock cycles of random presses against a second, independent model (the one pressed last wins, by time of press) and gave the same output on every cycle, and the outputs never hold both directions of an axis, never add a direction that is not held and never change a lone direction. The core's top level, where it is wired in, is checked by the lint only. The reported crash itself was not reproduced in MAME (one run each, with the first player's stick forced: with Up+Down held the game played on; with Left+Right held the player was not in the arena and the score stayed at 0), so whether it is gone needs a hardware test. The recompile is still to do.

**Removed**
- The test plan is no longer part of the repository: `docs/TestPlan.md` is gone, and with it the README's Test plan and Testing setup sections, the status column and the verified progress bar. The maintainer still keeps the test plan and still tests the core on MiSTer hardware; it is now his own working document outside GitHub, so the hardware results are no longer published here. Older entries below that mention the test plan or its test numbers (MK-33, C-24 and so on) refer to that document.

**Docs & tools**
- README, Extra content, the Smash T.V. and Total Carnage pages and the release notes describe the filter. The README's timing report is still that of Build 86 until the next compilation (this build adds six small filters of 8 flip-flops each to the controls).
- Test plan CSV: four new rows, each waiting for a hardware test: C-24 (opposite directions in any game), ST-11 and TC-14 (move and fire sticks in Smash T.V. and Total Carnage) and TR-13 (Trog). 148 tests in all.

## Build 91 (2026-10-26)

**Added**
- Mortal Kombat: **Fixed AI Difficulty** (main page, below Finishing Moves; Off by default): Off, or 0 (easiest) to 9. The game keeps the CPU opponent's difficulty as a level from 0 to 9 and its fighting follows it; it starts a 1-player game at a level from the game's difficulty adjustment (0 on the default setting), raises it after every match you win, holds a minimum under it on a winning streak and lowers it after a match you lose. With a level chosen here the CPU stays at that level from the first fight to the last, as the Fixed AI Difficulty of Mortal Kombat: Legacy Kollection does with the same range; Off is the game's own curve.
  - Set it before pressing Start to hold the level from the first fight; changed during a game it takes effect when the game next sets the level, which is when the match ends. It is for 1-player games.
  - The core stores your level every time the game writes its level (a value from 0 to 9) to its level word, on the board; the program ROM is not changed and what the CPU does at each level is the game's own. The word is at 0104D6E0 in rev 1.0 to 4.0, the Turbo hacks, the Reptile Man hack, the Victor bootleg and the Yawdim bootlegs, at 0104D6C0 or 0104D6D0 in the prototypes and Nifty Kombo.
  - The option is off while the test menu is selected (Service Mode, a Test button or the Test Switch DIP): the test menu's CPU board test writes patterns over the whole RAM and reads them back, and writes of other values than a level always pass unchanged.
  - Checked in MAME 0.289 on mkla4 with write taps on the level word through a 1-player game won match after match (the level went from 0 to 7 over seven won matches): the game start, one adjust routine and two minimum rules are the only writers. With every write replaced by one level, as the core does, the word reads that level from the first fight on and the CPU fights to it: an idle player was beaten in about 500 frames at level 0 (what the game does on a new game without the option) and in 330 to 400 frames at levels 1 to 9. In simulation (mkla4, 330 frames of boot and attract mode) the word is the chosen level from the board's first RAM clear and stays there while the words next to it stay 0, and the video frames are identical with and without the option. The test menu's CPU board test was run in MAME to see what it writes (patterns, from one routine). All 17 Mortal Kombat sets have the same adjust routine, and the tool finds the word in each. The recompile and a hardware test are still to do.

**Changed**
- The 17 Mortal Kombat MRAs have one more word in their ROM index 1, the level word's address (the item is hidden with an older MRA). The other 36 MRAs are the same as before.

**Docs & tools**
- README, Mortal Kombat page, Extra content and the release notes describe the option. README: Mortal Kombat is **Awaiting hardware test** again (progress bar 7 / 8), 142 of the 144 tests pass, and the resource note lists the new compare and multiplexer. The README's timing report is still that of Build 86 until the next compilation (this build adds logic to the board's RAM write path).
- TestPlan: two new Mortal Kombat tests, each waiting for a hardware test: MK-33 (Fixed AI Difficulty: 0, 9 and Off in a 1-player game) and MK-34 (a level set, then the test menu's CPU board test); C-01's list of the main page has the new item. Mortal Kombat is 32 of 34, 144 tests in all. The CSV has the same rows.
- `tools/yunit_fmoves.py`: `level_scan` finds the level word from the routine that moves the level, and the MRA generator checks it against the stored addresses of the 17 sets.

## Build 90 (2026-10-25)

**Docs & tools**
- Test results: all 142 tests of the test plan now pass on MiSTer hardware, the last ones being the Maze bootleg (TR-12), the Reptile Man, Victor and Yawdim sets (MK-29 to MK-32) and the HDMI Top Row Pixel Fix (C-21 to C-23). Trog and Mortal Kombat are Verified: the README's progress bar is 8 / 8, and the test plan's summary says Pass for every section. MK-32 now reads "This bootleg is expected to have broken, missing, wrong audio".
- README: the maintainer's edits are in: the AI disclosure, the CRT Adjust credit in Features, the wording of the HDMI Top Row Pixel Fix and the CMOS paragraphs (the "Today's Best" scores do not survive a power cycle on the real board either), FINISH HIM/HER, Reptile's moon silhouettes on The Pit stage, and a shorter Hidden Items row. The CRT V-Size note, the line about coins 3 and 4, and the note that split sets work are no longer in the README.

## Build 89 (2026-10-25)

**Removed**
- Top Row Fix Scale (added in Build 88): the Video Settings item is gone, and the HDMI Top Row Pixel Fix works as it did in Build 86 (the program is the Build 86 one; Build 88 only added the item). With Scale on Normal the picture is enlarged by about 0.4 % to fill the space the missing line leaves; the Scale item's V-Integer avoids that.

**Docs & tools**
- Extra content, the test plan and the release notes keep the corrected statement that the picture is enlarged by about 0.4 % with Scale on Normal (Build 86 said the rest of the picture stays the same). Test plan: back to 142 tests, C-21 corrected, C-24 and C-25 removed.

## Build 88 (2026-10-25)

**Added**
- Top Row Fix Scale (Video Settings, below HDMI Top Row Pixel Fix, shown while that is On): *Use Scale* (default), *V-Integer*, *HV-Integer*. With the Top Row Pixel Fix the scaler gets one line less, and with Scale on Normal it fills the same space with it, so the whole picture is enlarged by about 0.4 % (one line in 254; seen on hardware with Build 86). V-Integer and HV-Integer give every picture line a whole number of screen lines instead, so nothing is enlarged: at 1080p each line is 4 screen lines and the picture is 1012 lines high (1016 without the fix). *Use Scale* is the Build 86 behaviour. While the fix is On the item takes the place of the Scale item; with the fix Off the Scale item works as before. Saved with the core's other settings.
  - Checked in simulation on Mortal Kombat's own video through the core's video output: with V-Integer the size the scaler gets is 1349 x 1012 at 1080p (a 253-line picture at 4 screen lines per line; Scale on V-Integer with the fix Off: 1354 x 1016), 674 x 506 at 720p and 2698 x 2024 at 4K, also with a Scandoubler Fx, CRT Adjust and a CRT V-Size change; the analog signals are identical in every case, and Use Scale gives the Build 86 result. HV-Integer was not simulated (the framework's HV code does not run in the simulator); its sizes follow from the framework's code. A hardware test is waiting.

**Docs & tools**
- The HDMI Top Row Pixel Fix text now says that with Scale on Normal the picture is enlarged by about 0.4 % (Build 86 said the rest of the picture stays the same); Extra content, README, Mortal Kombat page. Test plan: C-21 corrected, new C-24 (V-Integer) and C-25 (HV-Integer, menu, saved setting).

## Build 87 (2026-10-24)

**Docs & tools**
- README: Timing from the Build 86 compilation (the one with the HDMI Top Row Pixel Fix): **timing is met on every clock**. Setup on the 96 MHz system clock has 0.599 ns to spare (total negative slack 0, Fmax 101.86 MHz; Build 81: 0.544 ns); the HDMI PLL clock has 0.460 ns, in the framework's scaler (`sys/`); hold (>= 0.228 ns), recovery (1.538 ns), removal (1.181 ns) and minimum pulse width (1.041 ns) are met. The closest paths on the 96 MHz clock are inside the framework's scaler (its input line memory into its input pixel registers); the core's own closest paths run from the reset hold-off counter into the TMS34010 and from the SDRAM controller's read-delay counter into the SDRAM address pins. The new option's logic and the scaler's pixel-enable logic are not among the closest 100 paths (all within 0.91 ns), and no unconstrained path was added. Resource use is still from the Build 68 compilation. No RTL change.

## Build 86 (2026-10-24)

**Added**
- HDMI Top Row Pixel Fix (Video Settings, Off by default): hides the picture's first line on HDMI. Mortal Kombat draws a few stray pixels there (at the left of the title screen's top line, and a couple that blink during a fight); a cabinet's overscan hides them, HDMI shows the whole picture. With the option On the scaler gets a picture one line shorter (two lines with a Scandoubler Fx, which doubles every line), still 4:3. Only HDMI changes: the core takes the pixel enables of that line away, which the scaler needs to see a pixel and the analog output does not use, so the analog signal is the same with the option On or Off. Direct Video, which sends the analog signal over HDMI, shows the line too; an analog output that follows the scaler (`vga_scaler` in MiSTer.ini) loses it with the HDMI picture.
  - It works for every game; the option is saved with the core's other settings.
  - Checked in simulation on Mortal Kombat's own video through the core's video output (native, HQ2x and CRT scandoubler, forced scandoubler, CRT Adjust with size, shift and V-Size settings, and switching the option while the video runs): the scaler's picture is the plain picture without its first line (two with a scandoubler), the change comes between frames, and every analog signal is identical with the option On and Off. The recompile and a hardware test are still to do.

**Docs & tools**
- README, Extra content and the Mortal Kombat page describe the option.
- TestPlan: three new core-wide tests, each waiting for a hardware test: C-21 (Mortal Kombat on HDMI, also with a Scandoubler Fx), C-22 (the analog output does not change) and C-23 (switching it with a game running, and the saved setting).

## Build 85 (2026-10-24)

**Docs & tools**
- TestPlan: five new tests for the newest alternative sets, each waiting for a hardware test: TR-12 (the Maze bootleg of Trog LA4) and MK-29 to MK-32 (the Reptile Man hack, the Victor bootleg, the four Yawdim bootlegs, and the Yawdim sound). TR-11 and MK-22 now say which sets they do not cover; their results stay. Trog is 11 / 12 and Mortal Kombat 28 / 32, so both are back to **Awaiting hardware test** (README progress bar: 6 / 8). 139 tests overall, 134 passed. The CSV has the same rows.
- README: the status of Trog and Mortal Kombat, the progress bar and the test count follow the test plan.

## Build 84 (2026-10-24)

**Added**
- Trog: an MRA for the Maze bootleg of rev LA4 (mazebl) from MAME's merged `trog.zip`, in `_alternatives/_Trog`: "Maze (Trog rev LA4 3/11/91 bootleg)". It is Trog rev LA4 with the title logo changed to MAZE: the program is LA4's byte for byte, the sound ROM is LA4's three sound ROMs in one 256 KB chip (its fourth 64 KB bank is empty), and the graphics are LA4's with the logo changed (13,043 bytes differ) on larger chips. The core runs it like the other Trog sets: same board, sound board, DIP switches and controls.

**Docs & tools**
- Trog page: the Maze bootleg in the Sets row.
- `tools/yunit_roms.py` reads MAME's `ROM_COPY` (the bootleg's sound ROM is one file that MAME copies into four banks); `tools/mra_gen.py` writes the MRA. The 52 existing MRAs come out unchanged.
- Checked against MAME 0.289: the image the MRA delivers is byte for byte the program, graphics and sound CPU regions MAME has after starting the game. In simulation (empty CMOS, Start pressed as in MAME) the frames from 50 to 500, the MAZE title screens included, are pixel-identical to MAME's except frame 150, the CMOS message screen, where Trog LA5 differs the same way; frames 550 and 600 differ from MAME's by the same pixel counts as Trog LA5's (the colour-cycling phase after Start).

## Build 83 (2026-10-24)

**Docs & tools**
- README: Timing and resources from the Build 81 compilation (the one with the Yawdim sound board): **timing is met on every clock**. Setup on the 96 MHz system clock has 0.544 ns to spare (total negative slack 0, Fmax 101.3 MHz; Build 80: 0.361 ns); the HDMI PLL clock has 0.453 ns, in the framework's scaler (`sys/`); hold (>= 0.207 ns), recovery (2.262 ns), removal (0.891 ns) and minimum pulse width (1.041 ns) are met. The closest paths on the 96 MHz clock run from the reset hold-off counter into the TMS34010's graphics unit, from the sound boards' sample requests and the SDRAM controller's read-delay counter into the SDRAM address pins, and from the CRT V-Size controller's registers into its pixel counter. The Z80 sound board's own logic is not among the closest 100 paths (all within 0.88 ns), and the timing constraints for it were read without a warning. Resource use is still from the Build 68 compilation. No RTL change.

## Build 82 (2026-10-24)

**Docs & tools**
- README: Timing and resources from the Build 80 compilation: **timing is met on every clock**. Setup on the 96 MHz system clock has 0.361 ns to spare (total negative slack 0, Fmax 99.45 MHz; Build 75: 0.496 ns); the HDMI PLL clock has 0.661 ns, in the framework's scaler (`sys/`); hold (>= 0.224 ns), recovery (1.143 ns), removal (0.848 ns) and minimum pulse width (1.041 ns) are met. The closest paths on the 96 MHz clock are the CRT V-Size controller's registers into its blanking output, and the reset hold-off counter into the TMS34010's register file; the SDRAM controller's paths are not among the closest 100 (all within 0.62 ns). Resource use is still from the Build 68 compilation. Build 81 (the Yawdim sound board) is not in this compilation. No RTL change.

## Build 81 (2026-10-23)

**Added**
- Mortal Kombat: MRAs for the four Yawdim bootlegs of MAME's merged `mk.zip` (mkyawdim, mkyawdim2, mkyawdim3, mkyawdim4), in `_alternatives/_Mortal Kombat`: "Mortal Kombat (Yawdim bootleg, set 1)" to "set 4". They are rev 3.0 with about 330 bytes of the program changed for a bootleg board that has no protection and no Williams sound board.
- The bootleg sound board (new `rtl/sound/yawdim_sound.sv`): a Z80 at 4 MHz plays samples through an OKI M6295 at 1 MHz; the main board sends it a command byte. The Z80 is the open-source TV80 core (new `rtl/tv80`, with its licence), with a small change in its NMI handling: an interrupt edge that arrives while the Z80 is accepting the previous one is kept and taken after the first instruction of the handler, as on a real Z80 and in MAME (the original lost it). The core follows MAME's driver in the details that differ between the sets:
  - Sets 1, 3 and 4 interrupt the Z80 with every command; set 2 holds the interrupt until the Z80 has read the command.
  - The OKI plays from banks of 256 KB chosen by a Z80 write: two bits (1 MB of samples) in sets 1, 3 and 4, three bits (2 MB) in set 2, where a write also resets the chip when its bit 2 is low.
- The bootleg's graphics hardware draws horizontally flipped sprites differently from the original board (MAME: `m_yawdim_dma`). The blitter has the same variant for these sets (`rtl/yunit_dma.sv`).
- Game ids 15 (sets 1, 3, 4) and 16 (set 2): the Mortal Kombat board at 48 MHz without protection, with the new sound board. The Williams sound board is held in reset for these sets.
- Finishing Moves, the EJB Menu shortcut and the Reptile lines are set up for all four sets from their program ROMs (the game's variables are at the same addresses as in rev 3.0).
- The two T-Unit sets in `mk.zip` (mkr4, mktturbo) belong to the T-Unit core.

**Changed**
- OKI sound chip (rtl/jt6295): a new parameter `IGNORE_BUSY` makes the chip ignore a start command for a voice that is still playing, as MAME's OKI does. Only the Yawdim board uses it; the Williams ADPCM board is unchanged. Every sound command of the Yawdim sets interrupts the Z80 twice and the program starts the sample in both handlers, about 100 microseconds apart; without this the second start restarted the sample with the ADPCM step of the old run, which made some samples about twice as loud as in MAME.
- ROM loading: the sound CPU region (0x900000) of the Yawdim sets is kept in a block RAM inside the new sound board as it arrives; the OKI samples (0xA00000) are read from the SDRAM. Every other game loads as before.
- Timing constraints (`Arcade-Midway-Y-Unit.sdc`): the Z80 runs from a clock enable every 24 clocks of the 96 MHz clock, and the paths between it and the rest of the board are constrained as multicycle paths (setup 8, hold 7).

**Docs & tools**
- Mortal Kombat page, Extra content, README: the four sets, with a Yawdim section in "Hacks and bootlegs" (what is different on this board and what the core does about it).
- `tools/mra_gen.py` writes the four MRAs (the Z80 program and the OKI samples in the places of the ROM image the core reads them from); `tools/yunit_roms.py` and `tools/yunit_fmoves.py` know the sets.
- Checked against MAME 0.289: the image each MRA delivers is byte for byte the program, graphics, Z80 and OKI regions MAME has after starting the game (all four sets). The EJB code, replayed in MAME on each set, enters the menu. In simulation, the attract screens (frame 300 of each set, and frame 600 of set 2) match MAME's pixel for pixel, and the blitter's flipped-sprite variant gives the same pixels as MAME's routine for 18,000 random blits. The sound board was run on its own against MAME's recordings of the same commands: the Z80 and the OKI receive the same writes in the same order, within a few microseconds, and below 3 kHz the sound has MAME's level and volume envelope (sets 1 and 2: 28 seconds each; sets 3 and 4: 12 seconds). Above 3 kHz the core has more energy than MAME, as on the Williams ADPCM board: the chip's output is not smoothed after the 7.6 kHz sample rate. The Yawdim sets are not tested on MiSTer hardware yet, and the compilation of this build has not been looked at (timing, resources).

## Build 80 (2026-10-23)

**Added**
- Mortal Kombat: MRAs for two more sets of MAME's merged `mk.zip`, in `_alternatives/_Mortal Kombat`:
  - **Reptile Man hack** (mkrep): a hack of rev 4.0. MAME patches out its protection when it starts the game; the MRA does the same with three `<patch>` entries after the program ROM, so the core runs the program MAME runs.
  - **Victor bootleg of rev 3.0** (mkla3bl): rev 3.0 on a bootleg board whose graphics ROMs are three 2 MB files with the bytes of the original ROMs interleaved in pairs. The core puts the bytes back in order while the ROMs load (new `rtl/yunit_dlmap.sv`); the MRA lists the three files as they are.
  - Finishing Moves and the EJB Menu shortcut are set up for both from their program ROMs (the same addresses as rev 4.0 and rev 3.0; the EJB code was replayed in MAME on both and enters the menu). The Victor bootleg also has the Reptile options; the Reptile Man hack changes that part of the program, so it has none.
- The other sets in `mk.zip` (the four Yawdim bootlegs) need a different sound board (a Z80 and an OKI) and are not in this build; the two T-Unit sets (mkr4, mktturbo) belong to the T-Unit core.

**Changed**
- ROM loading (rtl/yunit_dlmap.sv): the word-by-word writes of the ROM transfer to the SDRAM moved out of the top level into their own module. For every other set the writes are the same as before (checked over the whole 11 MB transfer against the old expression).

**Docs & tools**
- Mortal Kombat page, Extra content, README: the new sets, and the Reptile lines on the Victor bootleg; new section "Hacks and bootlegs" on the Mortal Kombat page.
- `tools/mra_gen.py` writes `<patch>` elements and checks them in its port of the loader; `tools/yunit_fmoves.py` knows the two sets.
- Checked against MAME 0.289: the image each MRA delivers (with the patches, and with the graphics put in order as the core does) is byte for byte the program, graphics, sound and OKI regions MAME has after starting the game. In simulation, the attract screens (frames 300 and 600) of both sets match MAME's pixel for pixel.

## Build 79 (2026-10-23)

**Docs & tools**
- README: the Status note ("the core is currently undergoing testing ... No releases until testing is complete") is removed; the core is in production. No RTL change.

## Build 78 (2026-10-23)

**Docs & tools**
- Mortal Kombat page: the EJB Menu section now says **when the menu is accessible**. The game takes the code only in its attract mode: from power-up until a game is started, and again from the MIDWAY PRESENTS screen once a game is over. It does not take it during a game, or during the game-over sequence that follows (GAME OVER, the winning-streaks table and the comic book offer, which looks like attract mode but is not: about 47 seconds in a test game), and there the OSD shortcut says "Not now: the code works in the attract mode". Checked in MAME with the full code played on both Block buttons: during the comic book page after a game over nothing happens (the game's state word is 11); in the attract mode that follows the menu opens (state 1, then 12). The summary lines in the Mortal Kombat and Extra content pages say the same in one sentence. No RTL change.

## Build 77 (2026-10-23)

**Docs & tools**
- README, test plan, changelog introduction: the hardware testing is now stated as done on **MiSTer hardware**, and the core as not verified against an original Y Unit board. README: "Verified on MiSTer hardware", a sentence under the progress bar that the core has not been verified against an original board, the Testing setup paragraph, "All 134 tests pass on MiSTer hardware". `docs/TestPlan.md`: the tests are run on MiSTer hardware; the core has not been verified against an original Y Unit board. No RTL change.

## Build 76 (2026-10-22)

**Docs & tools**
- README: Timing and resources from the Build 75 compilation (60 Hz code and Terminator 2 sight overlay gone): **timing is met on every clock**. Setup on the 96 MHz system clock has 0.496 ns to spare (total negative slack 0, Fmax 100.81 MHz; Build 73: 0.024 ns); the HDMI PLL clock has 0.541 ns, in the framework's scaler (`sys/`); hold (>= 0.247 ns), recovery (1.749 ns), removal (0.644 ns) and minimum pulse width (1.041 ns) are met. The closest paths on the 96 MHz clock are the reset hold-off counter into the TMS34010's graphics unit; the SDRAM controller's read-delay paths that limited Builds 69 and 73 are now 0.748 ns or more. Resource use is still from the Build 68 compilation.

## Build 75 (2026-10-22)

**Removed**
- Video Timing: the 60 Hz frame (263 lines) and the speed-up that went with it are gone from the board (rtl/midway_yunit.sv: the `vtiming` input is one bit, 54.7 Hz or 57 Hz; its CPU machine-cycle and blitter steps for 60 Hz are removed). The OSD had stopped listing 60 Hz in Build 68 because games run too fast with it; now the code is gone too. A 60 Hz setting saved by an earlier build runs as 57 Hz, as before. Checked in simulation: Smash T.V., Mortal Kombat and Terminator 2 (the three CPU speeds), 100 frames each at 54.7 Hz and 57 Hz, give the same frames, the same audio and the same cycle counts as Build 74 (24 of 24 files identical; 54.73 and 57.08 Hz), and the timing registers match for every setting.

**Changed**
- Terminator 2: the DIP switch **Cabinet?** is now **Cabinet** (Dedicated or Kit; MAME's name has a question mark, Trog already said Cabinet). Only the name changed in the six Terminator 2 MRAs: the bit, values and default are the same, so saved settings carry over. The MRA generator (`tools/mra_gen.py`) and the DIP checker use the same name; the checker finds 0 differences with MAME's driver in all 46 MRAs.

**Docs & tools**
- Comments that mentioned 60 Hz are reworded (rtl/tms34010/tms34010.sv, rtl/video/yunit_crt.sv, rtl/crt_adjust/crt_vsize.sv, the top level); no logic changed in those three files.
- The README's timing report is still that of Build 73 until the next compilation (this build removes logic, so the fit changes). Lint: no errors, the same 230 warnings as Build 74.

## Build 74 (2026-10-22)

**Docs & tools**
- README: Timing and resources from the Build 73 compilation (Terminator 2's sight overlay gone): **timing is met on every clock**, but the margin on the 96 MHz system clock is very thin: 0.024 ns (total negative slack 0, Fmax 96.23 MHz; Build 71: 0.530 ns); the HDMI PLL clock has 0.633 ns; hold (>= 0.214 ns), recovery (2.373 ns), removal (0.909 ns) and minimum pulse width (1.041 ns) are met. The closest paths on the 96 MHz clock are the SDRAM controller's read-delay register into its address pins, the same family as in Build 69. Resource use is still from the Build 68 compilation.

## Build 73 (2026-10-22)

**Removed**
- Terminator 2: the **Crosshair** option and the red and green sights the core drew over the picture. The game draws its own crosshairs, so the core's were a second set on top (and a green one for player 2 even in a one-player game); the picture is the game's own again. **Gun Control** (Joystick or Mouse) stays. The Crosshair entry is gone from the DIP Switches menu of all six Terminator 2 MRAs (the main set and the five alternatives); a saved Crosshair setting is ignored. Nothing else changes in the picture or the controls.

**Docs & tools**
- TestPlan: T2-06 (Crosshair Off) is removed with the option and the Terminator 2 tests after it move up (T2-06 to T2-12); T2-03 to T2-05 now say "the game's sight". Terminator 2 is 12 of 12, 134 tests in all. README, the Terminator 2 and Extra content pages, the test plan CSV and the release notes follow; `tools/mra_gen.py` no longer adds the Crosshair entry.
- The README's timing report is still that of Build 71 until the next compilation (this build removes logic, so the fit changes).

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
