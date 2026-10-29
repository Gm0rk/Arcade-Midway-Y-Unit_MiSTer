# Total Carnage

[Back to the main README](../README.md)

<img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Total_Carnage.png" width="400" alt="Total Carnage title screen"> <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Total_Carnage_2.png" width="400" alt="Total Carnage gameplay"> 

| | |
|---|---|
| Sets | totcarn (rev LA1, main MRA); prototypes v2.0 and v1.0 |
| ROM zip | `totcarn.zip` (merged set) |
| Players | 2 |
| Sound | ADPCM board |

## Extra content

- **[Passwords](#passwords)** (main page, Off or On): a window over the game, on Total Carnage's own title screen, with how to enter a warp code at the PASSWORD REQUIRED disc, the 16 codes by mission with where each warps to, and the Weasel and Orcus warp bonuses. The game waits while it shows.
- **Twin-stick fire** from B1-B4 (two together fire diagonally) or the right analog stick.
- **Opposite directions**: Up with Down and Left with Right never reach the game, on the move stick or the fire stick; the one pressed last wins.
- **Start/Bomb**: Start also throws a bomb in a game.
- **Coin 3** on the third controller's Coin button.

The [core-wide extras](ExtraContent.md#core-wide-features) (CRT Adjust, CRT V-Size, Video Timing, DIP Switches, Service Mode and the rest) apply to every game.

## Controls

Total Carnage is a twin-stick game: one stick moves, the other fires.

| Input | Use |
|---|---|
| Stick (d-pad / left stick) | Move (Up with Down or Left with Right: the last press wins) |
| B1-B4 | Fire up, down, left, right (pressing two fires diagonally; opposite ones: the last press wins) |
| Right analog stick | Fire in the direction it points, instead of B1-B4 |
| Start | Start; in a game it throws a bomb |
| Coin | Players 1-2; the third controller's Coin is coin 3 |
| Test, Pause | Service mode switch, pause |

## Test menu

Open the game's test menu with **OSD → Service Mode** (On; Off leaves it) or the Test button. **Diagnostic Tests → Switch Test** shows a lamp for each switch while it is closed. The ones that are not on a controller:

| Lamp | How to close it |
|---|---|
| SERVICE CREDIT | OSD → DIP Switches → Service Credit → Press. The lamp lights for about half a second once the game runs again (after the OSD is shut, unless Pause when OSD is open is Off) |
| SLAM - TILT | OSD → DIP Switches → Tilt → Press, the same |
| TEST | Service Mode On, or the Test button held |

The **Test Switch** DIP (DS2:8) is another switch: it opens the test menu too, but it never lights the TEST lamp, as in MAME. 4 COIN (the bill input) and VIDEO FREEZE have no control.

## Passwords

The game hides warp codes: at the start of a game a red and white disc
(PASSWORD REQUIRED) sits to the right of the player. Walk onto it, pick YES
and press Start, then enter the four letters within 20 seconds: the left
stick moves the arrow, the right stick up or down (B1 / B2) changes the
letter, and END enters the code. A code from the list warps there; any
other costs a life and the disc is gone. **OSD → Passwords** shows the list
over the game (which waits until it is Off).

| Code | Warps to |
|---|---|
| GOOB | Mission 1: the gate |
| ZULU | Mission 1: the bunker, with the Weasel Warp Bonus (40,000 points, 50 hostages, 50 flags, 50 gems, 10 keys) |
| ORCS | Mission 1: past Orcus, with the Orcus Warp Bonus (50,000 points, 100 hostages, 100 flags, 100 gems, 10 keys) |
| ROAD | Mission 2: the first road |
| LIPS | Mission 2: the airport gate |
| LICK | Mission 2: the airfield |
| FIRE | Mission 2: the hangar |
| SHOK | Mission 2: Akhboob's electric chair |
| FOOD | Mission 3: the second road |
| EATS | Mission 3: the mutant transmission |
| TOID | Mission 3: the road to the factory |
| BOOF | Mission 3: the reactor |
| MARK | Mission 3: the reactor basement |
| DOME | The ending: Akhboob escapes (no keys, no Pleasure Domes) |
| WORM | The ending: Akhboob is fried (no keys, no Pleasure Domes) |
| AZAZ | The ending: the Pleasure Domes (500 keys) |

The prototypes have the same codes.
