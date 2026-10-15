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

Core tested (rbf date): ____________

## Summary

| Game | Tests | Result |
|---|---|---|
| [Core-wide](#core-wide) | 17 | |
| [Trog](#trog) | 11 | 2 / 11 passed |
| [Smash T.V.](#smash-tv) | 10 | 2 / 10 passed |
| [High Impact Football](#high-impact-football) | 13 | 2 / 13 passed |
| [Super High Impact](#super-high-impact) | 13 | 2 / 13 passed |
| [Strike Force](#strike-force) | 11 | 1 / 11 passed |
| [Mortal Kombat](#mortal-kombat) | 29 | 2 / 29 passed |
| [Terminator 2 - Judgment Day](#terminator-2---judgment-day) | 13 | 1 / 13 passed |
| [Total Carnage](#total-carnage) | 10 | 2 / 10 passed |
| [Y-Unit Test ROM](#y-unit-test-rom) | 3 | 1 / 3 passed |

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
| C-01 | Open the OSD | Main page: Video Settings, Move List and Finishing Moves (Mortal Kombat only), DIP Switches, Hidden Items (games with a hidden menu only), Service Mode, Pause when OSD is open, Reset, Reset and close OSD | | |
| C-02 | Video Settings: Aspect Ratio, Scandoubler Fx, Scale | Each option changes the HDMI picture as named | | |
| C-03 | Video Timing 54.7 Hz / 57 Hz / 60 Hz | Picture stable on HDMI and analog at each; at 57 / 60 Hz the game runs a little faster, music keeps its pitch | | |
| C-04 | CRT Adjust: H-Size, H-Position, V-Shift, Auto-Width (analog) | The picture resizes and moves; Auto-Width fits it to the screen | | |
| C-05 | CRT V-Size, PVM and Cabinet modes (analog) | "+" taller, "-" shorter in both modes; the screen keeps sync | | |
| C-06 | Pause when OSD is open: On, then Off | On: the game stops while the OSD is open. Off: it keeps running | | |
| C-07 | Pause button on the controller | Pauses and resumes the game | | |
| C-08 | Reset, then Reset and close OSD | Both restart the game; the first leaves the OSD open, the second closes it | | |
| C-09 | Change a DIP switch (e.g. Coinage or Free Play), close the OSD, then Reset | Nothing changes until the reset; after it the new setting applies | | |
| C-10 | DIP Switches → Service Credit "Press", close the OSD | One credit is added | | |
| C-11 | DIP Switches → Tilt "Press", close the OSD | The game shows its tilt message | | |
| C-12 | Service Mode On, then Off; then the Test button | The game's test menu opens and closes; the Test button opens it too | | |
| C-13 | Change a setting in the game's test menu (or set a high score), open the OSD, reload the MRA | The setting / score is still there | | |
| C-14 | Trigger a Hidden Items item at the wrong time (e.g. EJB Menu during a fight) and close the OSD | A message shows for about 2 seconds after the OSD closes | | |
| C-15 | Define joystick buttons for a game | The button names match the game's controls page | | |
| C-16 | Play a game, then load another game from the menu | The screen stays black behind the loading box | | |
| C-17 | Open DIP Switches in each game | The switches in alphabetical order (Service Credit and Tilt among them), and each switch's settings too; every value shows on its line | | |

## Trog

Main MRA: Trog (rev LA5). [Controls](Trog.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| TR-01 | Boot | Attract mode: title, demo, high scores | Pass | |
| TR-02 | Coin and Start for players 1-4; coin 3 from the third controller | Credits added, each player joins | | |
| TR-03 | Controls of each player (test menu switch test or in game) | 4-way stick (on a diagonal the last direction pressed wins), Punch | | |
| TR-04 | Play a level with 2+ players | Picture correct: sprites, backgrounds, colours, no garbage | | |
| TR-05 | Sound in attract and game | Music, effects and speech, no crackle or missing voices | | |
| TR-06 | Play to game over | Continue screen, initials entry | | |
| TR-07 | Set a high score, open the OSD, reload | Score kept, no CMOS error on boot | | |
| TR-08 | Test menu: switch test, sound test | Every switch shows; sounds play | | |
| TR-09 | Change a DIP switch, reset | Applied | | |
| TR-10 | Trog (prototype, rev 4.00) MRA | Boots; 8-way stick, Bone button | | |
| TR-11 | Each MRA in `_alternatives/_Trog` | Boots to attract and plays | Pass | |

## Smash T.V.

Main MRA: Smash T.V. (rev 8.00). [Controls](SmashTV.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| ST-01 | Boot | Attract mode: title, demo, high scores | Pass | |
| ST-02 | Coin and Start for players 1-2; coin 3 | Credits added, each player joins | | |
| ST-03 | Move with the d-pad / left stick; fire with B1-B4, two at once | Moves in 8 directions; fires up, down, left, right and diagonals | | |
| ST-04 | Fire with the right analog stick | Fires the way it points | | |
| ST-05 | Play the first arena with 2 players | Picture correct, no slowdown or garbage | | |
| ST-06 | Sound in attract and game | Music, effects, host's speech | | |
| ST-07 | Set a high score, open the OSD, reload | Score kept, no CMOS error on boot | | |
| ST-08 | Test menu: switch test, sound test | Every switch shows; sounds play | | |
| ST-09 | Play to game over | Continue screen, initials entry | | |
| ST-10 | Each MRA in `_alternatives/_Smash T.V_` | Boots to attract and plays | Pass | |

## High Impact Football

Main MRA: High Impact Football (rev LA5). [Controls and hidden menu](HighImpactFootball.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| HI-01 | Boot | Attract mode: title, demo plays, standings | Pass | |
| HI-02 | Coin and Start for players 1-4; coins 3 and 4 | Credits added, each player joins | | |
| HI-03 | Controls of each player | 8-way stick, Action | | |
| HI-04 | Play a quarter | Picture correct: field scrolls, players, scoreboard | | |
| HI-05 | Sound | Music, effects, announcer | | |
| HI-06 | Change a setting, open the OSD, reload | Kept, no CMOS error on boot | | |
| HI-07 | Players DIP switch at 2, reset | 2-player cabinet: only players 1-2 | | |
| HI-08 | Hidden Items → Octopus Bookkeeping in the attract mode | Octopus Bookkeeping pages open; message "Octopus Bookkeeping: code entered" | | |
| HI-09 | The same during a game | Nothing is pressed; message "Not now: the code works in the attract mode" | | |
| HI-10 | HI-08 with the Players DIP switch at 2 | Pages open | | |
| HI-11 | Prototype 8.6 MRA: Octopus Bookkeeping | Message "Not in this revision of the game" | | |
| HI-12 | Each MRA in `_alternatives/_High Impact Football` | Boots to attract and plays | Pass | |
| HI-13 | DIP Switches → Coinage: select it repeatedly, then Free Play and reset | Six settings in turn (1 Coin/1 Credit, 2 Coins/1 Credit, 2C/1C - 4C/3C, 2C/1C - 4C/4C, ECA, Free Play); after the reset the game is on free play | | |

## Super High Impact

Main MRA: Super High Impact (rev LA2). [Controls and hidden menu](SuperHighImpact.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| SH-01 | Boot | Attract mode: title, demo plays, HIGHEST PAID SUPERSTARS | Pass | |
| SH-02 | Coin and Start for players 1-4; coins 3 and 4 | Credits added, each player joins | | |
| SH-03 | Controls of each player | 8-way stick, Action | | |
| SH-04 | Play a quarter | Picture correct: field scrolls, players, scoreboard | | |
| SH-05 | Sound | Music, effects, announcer | | |
| SH-06 | Change a setting, open the OSD, reload | Kept, no CMOS error on boot | | |
| SH-07 | Players DIP switch at 2, reset | 2-player cabinet: only players 1-2 | | |
| SH-08 | Hidden Items → Octopus Bookkeeping while HIGHEST PAID SUPERSTARS shows | Octopus Bookkeeping opens; message "Octopus Bookkeeping: code entered" | | |
| SH-09 | The same on another attract screen | Nothing is pressed; message "Not now: the code works while the attract mode shows HIGHEST PAID SUPERSTARS" | | |
| SH-10 | SH-08 with the Players DIP switch at 2 | Opens | | |
| SH-11 | A prototype MRA: Octopus Bookkeeping | Message "Not in this revision of the game" | | |
| SH-12 | Each MRA in `_alternatives/_Super High Impact` | Boots to attract and plays | Pass | |
| SH-13 | DIP Switches → Coinage: select it repeatedly, then Free Play and reset | Six settings in turn (as HI-13); after the reset the game is on free play | | |

## Strike Force

Main MRA: Strike Force (rev 1). [Controls](StrikeForce.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| SF-01 | Boot | Attract mode: title, demo, high scores | Pass | |
| SF-02 | Coin and Start for players 1-2; coins 3 and 4 | Credits added, each player joins | | |
| SF-03 | Controls | 8-way stick; Fire, Weapon, Weapon Select; Start transforms in a game | | |
| SF-04 | Play the first stage with 2 players | Picture correct: scrolling, sprites, colours | | |
| SF-05 | Sound | Music, effects, speech | | |
| SF-06 | Set a high score, open the OSD, reload | Score kept, no CMOS error on boot | | |
| SF-07 | Test menu: switch test, sound test | Every switch shows; sounds play | | |
| SF-08 | Play to game over | Continue screen, initials entry | | |
| SF-09 | Change a DIP switch, reset | Applied | | |
| SF-10 | Saurian Front MRA (`_alternatives/_Strike Force`) | Boots to attract and plays | | |
| SF-11 | DIP Switches → Coin A, then Extra Ship Points: select each repeatedly | All 16 Coin A settings and the 4 Extra Ship Points values show on their line (1C/1C - 2C/3C style for the two-step ones) | | |

## Mortal Kombat

Main MRA: Mortal Kombat (rev 4.0). [Controls, move list, finishing moves, hidden menu and Reptile](MortalKombat.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| MK-01 | Boot | Attract mode: title, bios, demo fight | Pass | |
| MK-02 | Coin and Start for players 1-2; coin 3 | Credits added, each player joins | | |
| MK-03 | Controls of each player | 8-way stick; High Punch, Low Punch, High Kick, Low Kick, Block | | |
| MK-04 | Play a match, 1 player vs the CPU and 2 players | Picture correct: fighters, backgrounds, blood | | |
| MK-05 | Sound | Music, effects, voices ("Finish him", announcer) | | |
| MK-06 | Set a high score / winning streak, open the OSD, reload | Kept, no CMOS error on boot | | |
| MK-07 | Test menu: switch test, sound test | Every switch shows; sounds play | | |
| MK-08 | Finishing Moves: Johnny Cage, Decapitation | Played at FINISH HIM; the fatality runs | | |
| MK-09 | Kano, Heart Rip | As MK-08 | | |
| MK-10 | Sub-Zero, Spine Rip | As MK-08 | | |
| MK-11 | Sonya, Kiss of Death | As MK-08 | | |
| MK-12 | Raiden, Electrocution | As MK-08 | | |
| MK-13 | Liu Kang, Cartwheel | As MK-08 | | |
| MK-14 | Scorpion, Fire Breath | As MK-08 | | |
| MK-15 | The Pit, on The Pit stage | The loser falls into the pit | | |
| MK-16 | A fatality with player 2 the winner | Played on player 2's controls | | |
| MK-17 | Set a move before the match | Message "Finishing move set: it plays at the next FINISH HIM"; it plays at FINISH HIM | | |
| MK-18 | Stand too far for Johnny Cage, then walk in | Message "Too far: step closer"; the move plays once close | | |
| MK-19 | Clear the set move | Message "Finishing move cleared"; nothing plays | | |
| MK-20 | Move List: Page 1, then Page 2 | Over the dimmed title screen, MOVE LIST 1/2 (Johnny Cage to Sonya) and 2/2 (Raiden to Scorpion): special moves, fatality with its distance, The Pit at the bottom; the text reads clearly | | |
| MK-21 | Hidden Items → EJB Menu in the attract mode | EJB Menu opens; message "EJB Menu: code entered" | | |
| MK-22 | The same during a fight | Nothing is pressed; message "Not now: the code works in the attract mode" | | |
| MK-23 | Each MRA in `_alternatives/_Mortal Kombat` | Boots to attract and plays; prototype 4.0's EJB Menu says "Not in this revision of the game" | Pass | |
| MK-24 | Set Move List to a page during a fight, close the OSD, then set it Off | The fight waits behind the page and goes on where it was once Off | | |
| MK-25 | Hidden Items → Reptile Fight Next, then win a match in a 1-player game | Message "Reptile fight set: win a match in a 1-player game"; after the win "YOU HAVE FOUND ME", then the fight with Reptile below The Pit | | |
| MK-26 | Reptile Fight Next twice | Message "Reptile fight cleared"; the next win goes on as usual | | |
| MK-27 | Moon Silhouettes Always On, play to The Pit | Silhouettes cross the moon in every round there | | |
| MK-28 | Reptile Hints Always On, start a match | Reptile drops in with a hint before each round's "FIGHT!"; the EJB Menu's game audits are not cleared | | |
| MK-29 | Hidden Items on rev 2.0 or a prototype | Only EJB Menu (no Reptile lines); on rev 3.0 and the Turbo hacks the Reptile lines show | | |

## Terminator 2 - Judgment Day

Main MRA: Terminator 2 - Judgment Day (rev LA4). [Controls and gun options](Terminator2.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| T2-01 | Boot | Attract mode: title, demo, high scores | | |
| T2-02 | Coin and Start for players 1-2; coins 3 and 4 | Credits added, each player joins | | |
| T2-03 | Aim with the left analog stick and shoot | The sight follows the stick across the whole screen; shots land where it points | | |
| T2-04 | Aim with the d-pad | The sight moves steadily | | |
| T2-05 | Gun Control "Mouse" (DIP Switches), aim player 1 with the mouse | The sight follows the mouse; left button fires, right throws a bomb | | |
| T2-06 | Crosshair Off | The sight is hidden | | |
| T2-07 | Trigger and Bomb, both players | Fire and bomb work | | |
| T2-08 | Play the first level with 2 players | Picture correct; the game does not freeze | | |
| T2-09 | Sound | Music, effects, voices | | |
| T2-10 | Set a high score, open the OSD, reload | Score kept, no CMOS error on boot | | |
| T2-11 | Test menu: switch test, sound test | Every switch shows; sounds play | | |
| T2-12 | Play to game over | Continue screen, initials entry | | |
| T2-13 | Each MRA in `_alternatives/_Terminator 2 - Judgment Day` | Boots to attract and plays | Pass | |

## Total Carnage

Main MRA: Total Carnage (rev LA1). [Controls](TotalCarnage.md).

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| TC-01 | Boot | Attract mode: title, demo, high scores | Pass | |
| TC-02 | Coin and Start for players 1-2; coin 3 | Credits added, each player joins | | |
| TC-03 | Move with the d-pad / left stick; fire with B1-B4, two at once | Moves in 8 directions; fires in 8 directions | | |
| TC-04 | Fire with the right analog stick; Start in a game | Fires the way it points; Start throws a bomb | | |
| TC-05 | Play the first level with 2 players | Picture correct, no garbage | | |
| TC-06 | Sound | Music, effects, voices | | |
| TC-07 | Set a high score, open the OSD, reload | Score kept, no CMOS error on boot | | |
| TC-08 | Test menu: switch test, sound test | Every switch shows; sounds play | | |
| TC-09 | Play to game over | Continue screen, initials entry | | |
| TC-10 | Each MRA in `_alternatives/_Total Carnage` | Boots to attract and plays | Pass | |

## Y-Unit Test ROM

MRA: Y-Unit Test ROM (v1.40). [About it](YUnitTestROM.md). It has no sound or
graphics ROMs, so their tests are not expected to show anything.

| # | Test | Expected | Result | Notes |
|---|---|---|---|---|
| YT-01 | Boot | The diagnostic starts and shows its screens | Pass | |
| YT-02 | Pick tests with the DIP switches, reset | The chosen test runs | | |
| YT-03 | Hidden Items → Octopus Bookkeeping | Message "Not in this revision of the game" | | |
