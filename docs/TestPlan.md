# Test plan

[Back to the main README](../README.md)

The hardware tests each game needs before the core is considered done. Run
them on a MiSTer with the game's main MRA (the alternatives have their own
test), and write **Pass** or **Fail** in the Result column; an empty Result
means not tested yet. Put what went wrong in Notes. If you are unsure what
is correct, compare with MAME.

The summary counts the passed tests in each section while testing is under
way. A game is done when every test in its section passes: mark it Pass in
the summary, set its Status in the [README's game table](../README.md#games) to
"Verified" and move the README's progress bar on by one. The core is done
when every game and the core-wide tests pass.

## Summary

| Game | Tests | Result |
|---|---|---|
| [Core-wide](#core-wide) | 19 | 8 / 19 passed |
| [Trog](#trog) | 11 | Pass |
| [Smash T.V.](#smash-tv) | 10 | Pass |
| [High Impact Football](#high-impact-football) | 13 | Pass |
| [Super High Impact](#super-high-impact) | 13 | Pass |
| [Strike Force](#strike-force) | 11 | Pass |
| [Mortal Kombat](#mortal-kombat) | 29 | Pass |
| [Terminator 2 - Judgment Day](#terminator-2---judgment-day) | 13 | Pass |
| [Total Carnage](#total-carnage) | 13 | Pass |
| [Y-Unit Test ROM](#y-unit-test-rom) | 3 | Pass |

## What you need

- The core's rbf and the MRAs from this repository, and the merged MAME
  0.289 ROM zips (see [ROMs](../README.md#roms))
- Two controllers (four for Trog, High Impact Football and Super High
  Impact), one with a right analog stick for Smash T.V. and Total Carnage, a
  left analog stick and a mouse for Terminator 2
- HDMI; an analog CRT for the CRT tests (marked "analog")

On the very first start of a game, an empty CMOS may stop on a "factory
settings restored ... press any button" screen: press a button. That is
normal once; it must not come back after the CMOS has been saved (test 7 of
each game).

## Core-wide

Run with any game (Mortal Kombat or Smash T.V. covers them all).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| C-01 | Open the OSD | Main page: Video Settings, Move List and Finishing Moves (Mortal Kombat only), Passwords (Total Carnage only), DIP Switches, Hidden Items (games with a hidden menu only), Service Mode, Pause when OSD is open, Reset, Reset and close OSD | Pass | |
| C-02 | Video Settings: Aspect Ratio, Scandoubler Fx, Scale | Each option changes the HDMI picture as named | Pass | |
| C-03 | Video Timing 54.7 Hz / 57 Hz / 60 Hz | Picture stable on HDMI and analog at each; at 57 / 60 Hz the game runs a little faster, music keeps its pitch | | |
| C-04 | CRT Adjust: H-Size, H-Position, V-Shift, Auto-Width (analog) | The picture resizes and moves; Auto-Width fits it to the screen | | |
| C-05 | CRT V-Size, PVM and Cabinet modes (analog) | "+" taller, "-" shorter in both modes; the screen keeps sync, also while V-Size is turned on, changed or set back to 0 (PVM: no roll or tear) | | |
| C-06 | Pause when OSD is open: On, then Off | On: the game stops while the OSD is open. Off: it keeps running | Pass | |
| C-07 | Pause button on the controller | Pauses and resumes the game | Pass | |
| C-08 | Reset, then Reset and close OSD | Both restart the game; the first leaves the OSD open, the second closes it | Pass | |
| C-09 | Change a DIP switch (e.g. Coinage or Free Play), close the OSD, then Reset | Nothing changes until the reset; after it the new setting applies | Pass | |
| C-10 | DIP Switches → Service Credit "Press", close the OSD | One credit is added | Pass | |
| C-11 | DIP Switches → Tilt "Press", close the OSD | The game shows its tilt message | | |
| C-12 | Service Mode On, then Off; then the Test button | The game's test menu opens and closes; the Test button opens it too | | |
| C-13 | Change a setting in the game's test menu (or set a high score), open the OSD, reload the MRA | The setting / score is still there | Pass | |
| C-14 | Trigger a Hidden Items item at the wrong time (e.g. EJB Menu during a fight) and close the OSD | A message shows for about 2 seconds after the OSD closes | | |
| C-15 | Define joystick buttons for a game | The button names match the game's controls page | | |
| C-16 | Play a game, then load another game from the menu | The screen stays black behind the loading box | | |
| C-17 | Open DIP Switches in each game | The switches in alphabetical order (Service Credit and Tilt among them), and each switch's settings too; every value shows on its line | | |
| C-18 | Video Timing 57 Hz, then 60 Hz, with CRT Adjust on: CRT V-Size "+7" in PVM and in Cabinet mode | The whole picture stays on screen (the bottom rows too); "+" makes it only as tall as the frame allows | | |
| C-19 | Mortal Kombat: let the attract mode run into a demo fight and on; Smash T.V.: lose a game to GAME OVER | Each tune stops cleanly when the music changes or stops; no FM notes keep droning | | |

## Trog

Main MRA: Trog (rev LA5). [Controls](Trog.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| TR-01 | Boot | Attract mode: title, demo, high scores | Pass | |
| TR-02 | Coin and Start for players 1-4; coin 3 from the third controller | Credits added, each player joins | Pass | |
| TR-03 | Controls of each player (test menu switch test or in game) | 4-way stick (on a diagonal the last direction pressed wins), Punch | Pass | |
| TR-04 | Play a level with 2+ players | Picture correct: sprites, backgrounds, colours, no garbage | Pass | |
| TR-05 | Sound in attract and game | Music, effects and speech, no crackle or missing voices | Pass | |
| TR-06 | Play to game over | Continue screen, initials entry | Pass | |
| TR-07 | Set a high score in the Top Trogs table, open the OSD, reload | Score kept, no CMOS error on boot. The Daily Dinos table starts afresh at every power-up, as on the board | Pass | |
| TR-08 | Test menu: switch test, sound test | Every switch shows; sounds play | Pass | |
| TR-09 | Change a DIP switch, reset | Applied | Pass | |
| TR-10 | Trog (prototype, rev 4.00) MRA | Boots; 8-way stick, Bone button | Pass | |
| TR-11 | Each MRA in `_alternatives/_Trog` | Boots to attract and plays | Pass | |

## Smash T.V.

Main MRA: Smash T.V. (rev 8.00). [Controls](SmashTV.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| ST-01 | Boot | Attract mode: title, demo, high scores | Pass | |
| ST-02 | Coin and Start for players 1-2; coin 3 | Credits added, each player joins | Pass | |
| ST-03 | Move with the d-pad / left stick; fire with B1-B4, two at once | Moves in 8 directions; fires up, down, left, right and diagonals | Pass | |
| ST-04 | Fire with the right analog stick | Fires the way it points | Pass | |
| ST-05 | Play the first arena with 2 players | Picture correct, no slowdown or garbage | Pass | |
| ST-06 | Sound in attract and game | Music, effects, host's speech | Pass | |
| ST-07 | Set a high score in the All Time table, open the OSD, reload | Score kept, no CMOS error on boot. The Today table starts afresh at every power-up, as on the board | Pass | |
| ST-08 | Test menu: switch test, sound test | Every switch shows; sounds play | Pass | |
| ST-09 | Play to game over | Continue screen, initials entry | Pass | |
| ST-10 | Each MRA in `_alternatives/_Smash T.V_` | Boots to attract and plays | Pass | |

## High Impact Football

Main MRA: High Impact Football (rev LA5). [Controls and hidden menu](HighImpactFootball.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| HI-01 | Boot | Attract mode: title, demo plays, standings | Pass | |
| HI-02 | Coin and Start for players 1-4; coins 3 and 4 | Credits added, each player joins | Pass | |
| HI-03 | Controls of each player | 8-way stick, Action | Pass | |
| HI-04 | Play a quarter | Picture correct: field scrolls, players, scoreboard | Pass | |
| HI-05 | Sound | Music, effects, announcer | Pass | |
| HI-06 | Change a setting, open the OSD, reload | Kept, no CMOS error on boot | Pass | |
| HI-07 | Players DIP switch at 2, reset | 2-player cabinet: only players 1-2 | Pass | |
| HI-08 | Hidden Items → Octopus Bookkeeping in the attract mode | Octopus Bookkeeping pages open; message "Octopus Bookkeeping: code entered" | Pass | |
| HI-09 | The same during a game | Nothing is pressed; message "Not now: the code works in the attract mode" | Pass | |
| HI-10 | HI-08 with the Players DIP switch at 2 | Pages open | Pass | |
| HI-11 | Prototype 8.6 MRA: Octopus Bookkeeping | Message "Not in this revision of the game" | Pass | |
| HI-12 | Each MRA in `_alternatives/_High Impact Football` | Boots to attract and plays | Pass | |
| HI-13 | DIP Switches → Coinage: select it repeatedly, then Free Play and reset | Six settings in turn (1 Coin/1 Credit, 2 Coins/1 Credit, 2C/1C - 4C/3C, 2C/1C - 4C/4C, ECA, Free Play); after the reset the game is on free play | Pass | |

## Super High Impact

Main MRA: Super High Impact (rev LA2). [Controls and hidden menu](SuperHighImpact.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| SH-01 | Boot | Attract mode: title, demo plays, HIGHEST PAID SUPERSTARS | Pass | |
| SH-02 | Coin and Start for players 1-4; coins 3 and 4 | Credits added, each player joins | Pass | |
| SH-03 | Controls of each player | 8-way stick, Action | Pass | |
| SH-04 | Play a quarter | Picture correct: field scrolls, players, scoreboard | Pass | |
| SH-05 | Sound | Music, effects, announcer | Pass | |
| SH-06 | Change a setting, open the OSD, reload | Kept, no CMOS error on boot | Pass | |
| SH-07 | Players DIP switch at 2, reset | 2-player cabinet: only players 1-2 | Pass | |
| SH-08 | Hidden Items → Octopus Bookkeeping while HIGHEST PAID SUPERSTARS shows | Octopus Bookkeeping opens; message "Octopus Bookkeeping: code entered" | Pass | Lost sound when exiting the octopus menu – Reset game fixes it |
| SH-09 | The same on another attract screen | Nothing is pressed; message "Not now: the code works while the attract mode shows HIGHEST PAID SUPERSTARS" | Pass | |
| SH-10 | SH-08 with the Players DIP switch at 2 | Opens | Pass | Lost sound when exiting the octopus menu – Reset game fixes it |
| SH-11 | A prototype MRA: Octopus Bookkeeping | Message "Not in this revision of the game" | Pass | |
| SH-12 | Each MRA in `_alternatives/_Super High Impact` | Boots to attract and plays | Pass | |
| SH-13 | DIP Switches → Coinage: select it repeatedly, then Free Play and reset | Six settings in turn (as HI-13); after the reset the game is on free play | Pass | |

## Strike Force

Main MRA: Strike Force (rev 1). [Controls](StrikeForce.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| SF-01 | Boot | Attract mode: title, demo, high scores | Pass | |
| SF-02 | Coin and Start for players 1-2; coins 3 and 4 | Credits added, each player joins | Pass | |
| SF-03 | Controls | 8-way stick; Fire, Weapon, Weapon Select; Start transforms in a game | Pass | |
| SF-04 | Play the first stage with 2 players | Picture correct: scrolling, sprites, colours | Pass | |
| SF-05 | Sound | Music, effects, speech | Pass | |
| SF-06 | Set a high score, open the OSD, reload | Score kept, no CMOS error on boot | Pass | Just like Smash TV “Today’s” scores do not save after reset |
| SF-07 | Test menu: switch test, sound test | Every switch shows; sounds play | Pass | |
| SF-08 | Play to game over | Continue screen, initials entry | Pass | |
| SF-09 | Change a DIP switch, reset | Applied | Pass | |
| SF-10 | Saurian Front MRA (`_alternatives/_Strike Force`) | Boots to attract and plays | Pass | |
| SF-11 | DIP Switches → Coin A, then Extra Ship Points: select each repeatedly | All 16 Coin A settings and the 4 Extra Ship Points values show on their line (1C/1C - 2C/3C style for the two-step ones) | Pass | |

## Mortal Kombat

Main MRA: Mortal Kombat (rev 4.0). [Controls, move list, finishing moves, hidden menu and Reptile](MortalKombat.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| MK-01 | Boot | Attract mode: title, bios, demo fight | Pass | |
| MK-02 | Coin and Start for players 1-2; coin 3 | Credits added, each player joins | Pass | |
| MK-03 | Controls of each player | 8-way stick; High Punch, Low Punch, High Kick, Low Kick, Block | Pass | |
| MK-04 | Play a match, 1 player vs the CPU and 2 players | Picture correct: fighters, backgrounds, blood | Pass | |
| MK-05 | Sound | Music, effects, voices ("Finish him", announcer) | Pass | |
| MK-06 | Set a high score / winning streak, open the OSD, reload | Kept, no CMOS error on boot | Pass | |
| MK-07 | Test menu: switch test, sound test | Every switch shows; sounds play | Pass | |
| MK-08 | Finishing Moves: Johnny Cage, Decapitation | Played at FINISH HIM; the fatality runs | Pass | |
| MK-09 | Kano, Heart Rip | As MK-08 | Pass | |
| MK-10 | Sub-Zero, Spine Rip | As MK-08 | Pass | |
| MK-11 | Sonya, Kiss of Death | As MK-08 | Pass | |
| MK-12 | Raiden, Electrocution | As MK-08 | Pass | |
| MK-13 | Liu Kang, Cartwheel | As MK-08 | Pass | |
| MK-14 | Scorpion, Fire Breath | As MK-08 | Pass | |
| MK-15 | The Pit, on The Pit stage | The loser falls into the pit | Pass | |
| MK-16 | A fatality with player 2 the winner | Played on player 2's controls | Pass | |
| MK-17 | Set a move before the match | Message "Finishing move set: it plays at the next FINISH HIM"; it plays at FINISH HIM | Pass | |
| MK-18 | Stand too far for Johnny Cage, then walk in | Message "Too far: step closer"; the move plays once close | Pass | |
| MK-19 | Clear the set move | Message "Finishing move cleared"; nothing plays | Pass | |
| MK-20 | Move List: Page 1, then Page 2 | Over the dimmed title screen, MOVE LIST 1/2 (Johnny Cage to Sonya) and 2/2 (Raiden to Scorpion): special moves, fatality with its distance, The Pit at the bottom; the text reads clearly | Pass | |
| MK-21 | Hidden Items → EJB Menu in the attract mode | EJB Menu opens; message "EJB Menu: code entered" | Pass | |
| MK-22 | The same during a fight | Nothing is pressed; message "Not now: the code works in the attract mode" | Pass | |
| MK-23 | Each MRA in `_alternatives/_Mortal Kombat` | Boots to attract and plays; prototype 4.0's EJB Menu says "Not in this revision of the game" | Pass | |
| MK-24 | Set Move List to a page during a fight, close the OSD, then set it Off | The fight waits behind the page and goes on where it was once Off | Pass | |
| MK-25 | Hidden Items → Reptile Fight Next, then win a match in a 1-player game | Message "Reptile fight set: win a match in a 1-player game"; after the win "YOU HAVE FOUND ME", then the fight with Reptile below The Pit | Pass | |
| MK-26 | Reptile Fight Next twice | Message "Reptile fight cleared"; the next win goes on as usual | Pass | |
| MK-27 | Moon Silhouettes Always On, play to The Pit | Silhouettes cross the moon in every round there | Pass | |
| MK-28 | Reptile Hints Always On, start a match | Reptile drops in with a hint before each round's "FIGHT!"; the EJB Menu's game audits are not cleared | Pass | |
| MK-29 | Hidden Items on rev 2.0 or a prototype | Only EJB Menu (no Reptile lines); on rev 3.0 and the Turbo hacks the Reptile lines show | Pass | |

## Terminator 2 - Judgment Day

Main MRA: Terminator 2 - Judgment Day (rev LA4). [Controls and gun options](Terminator2.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| T2-01 | Boot | Attract mode: title, demo, high scores | Pass | |
| T2-02 | Coin and Start for players 1-2; coins 3 and 4 | Credits added, each player joins | Pass | |
| T2-03 | Aim with the left analog stick and shoot | The sight follows the stick across the whole screen; shots land where it points | Pass | |
| T2-04 | Aim with the d-pad | The sight moves steadily | Pass | |
| T2-05 | Gun Control "Mouse" (DIP Switches), aim player 1 with the mouse | The sight follows the mouse; left button fires, right throws a bomb | Pass | |
| T2-06 | Crosshair Off | The sight is hidden | Pass | |
| T2-07 | Trigger and Bomb, both players | Fire and bomb work | Pass | |
| T2-08 | Play the first level with 2 players | Picture correct; the game does not freeze | Pass | |
| T2-09 | Sound | Music, effects, voices | Pass | |
| T2-10 | Set a high score, open the OSD, reload | Score kept, no CMOS error on boot | Pass | Just like Smash TV “Today’s” scores do not save after reset |
| T2-11 | Test menu: switch test, sound test | Every switch shows; sounds play | Pass | |
| T2-12 | Play to game over | Continue screen, initials entry | Pass | |
| T2-13 | Each MRA in `_alternatives/_Terminator 2 - Judgment Day` | Boots to attract and plays | Pass | |

## Total Carnage

Main MRA: Total Carnage (rev LA1). [Controls](TotalCarnage.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| TC-01 | Boot | Attract mode: title, demo, high scores | Pass | |
| TC-02 | Coin and Start for players 1-2; coin 3 | Credits added, each player joins | Pass | |
| TC-03 | Move with the d-pad / left stick; fire with B1-B4, two at once | Moves in 8 directions; fires in 8 directions | Pass | |
| TC-04 | Fire with the right analog stick; Start in a game | Fires the way it points; Start throws a bomb | Pass | |
| TC-05 | Play the first level with 2 players | Picture correct, no garbage | Pass | |
| TC-06 | Sound | Music, effects, voices | Pass | |
| TC-07 | Set a high score, open the OSD, reload | Score kept, no CMOS error on boot | Pass | |
| TC-08 | Test menu (Service Mode On): switch test, sound test | Every switch shows; Tilt and Service Credit (OSD DIP Switches, Press) light their lamp for about half a second once the OSD is shut; sounds play. The Test Switch DIP opens the menu but leaves the TEST lamp dark, as in MAME | Pass | |
| TC-09 | Play to game over | Continue screen, initials entry | Pass | |
| TC-10 | Each MRA in `_alternatives/_Total Carnage` | Boots to attract and plays | Pass | |
| TC-11 | Passwords On during a game, close the OSD, then set it Off | Over the dimmed title screen: how to enter a code, the 16 codes by mission and the two warp bonuses, all readable; the game waits behind it and goes on once Off | Pass | |
| TC-12 | Start a game, walk onto the warp disc, YES, enter ZULU, END | Weasel Warp Bonus (40,000 points, 50 hostages, flags and gems, 10 keys) in the bunker | Pass | |
| TC-13 | Leave the attract mode running until the high score table (about 1 minute 40 seconds after a reset) | The table waves in line by line from the right and later waves out, as in MAME; the picture stays steady, no streaks or torn lines | Pass | |

## Y-Unit Test ROM

MRA: Y-Unit Test ROM (v1.40). [About it](YUnitTestROM.md). It has no sound or
graphics ROMs, so their tests are not expected to show anything.

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| YT-01 | Boot | The diagnostic starts and shows its screens | Pass | |
| YT-02 | Pick tests with the DIP switches, reset | The chosen test runs | Pass | |
| YT-03 | Hidden Items → Octopus Bookkeeping | Message "Not in this revision of the game" | Pass | |
