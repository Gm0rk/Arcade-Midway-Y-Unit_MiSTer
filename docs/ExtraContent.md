# Extra content

[Back to the main README](../README.md)

Extra content is everything the core offers that the original boards did not: OSD options, shortcuts, helper pages and output features, as opposed to the games and hardware reproduced from MAME. The first section lists what every game gets; the sections after it list what is specific to one game. Each game's own page repeats its section.

## Core-wide features

Every game gets the video, OSD, input and loading extras below.

### Video output

- **Centred analog sync**: the core measures where the picture is and makes new HSync / VSync at the broadcast position around it, for a standard 15 kHz screen.
- **CRT Adjust**: H-Size, H-Position and V-Shift (Video Settings), for analog CRT output.
- **CRT V-Size (experimental)**: makes the picture taller ("+") or shorter ("-"), up to 7 steps of 3 lines, in PVM mode (changes the lines per frame, every line stays sharp) or Cabinet mode (native timing, neighbouring lines blended). "+" stops at the room the frame has.
- **Video Timing**: the board's own 54.7 Hz, or 57 Hz frames for TVs that do not hold 54.7 Hz. Only blank lines are dropped; games run about 4 % faster, while music and voices keep their pitch and tempo. The loading screen (the board in reset while the ROMs load) has the same timing, so a TV that holds 57 Hz holds it too.
- **HDMI Top Row Pixel Fix** (Video Settings, Off by default): hides the picture's first line on HDMI. Some games draw stray pixels there (Mortal Kombat: a few at the left of the title screen's top line, and a couple that blink during a fight); a cabinet's overscan hides them, HDMI shows the whole picture. With the option On the scaler gets a picture one line shorter (two lines with a Scandoubler Fx, which doubles every line). With Scale on Normal the scaler fills the same space with one line less, so the picture is enlarged by about 0.4 % (one line in 254); the Scale item's V-Integer keeps every line the same height instead (the picture is then smaller, as with any integer scale). Only the scaler's picture changes: the analog output is the same signal with the option On or Off. Direct Video (the analog signal sent over HDMI) shows the line too; an analog output that follows the scaler (`vga_scaler` in MiSTer.ini) loses it with the HDMI picture.
- **Black, locked picture while loading**: the screen stays black with sync running during a ROM or NVRAM download, the boot hold and an OSD Reset, so a second game never shows the first one's frame.

### OSD

- **DIP Switches page**: MAME's switches for the loaded game, in alphabetical order with each switch's settings in alphabetical order too. Changes apply after a reset and no longer reset the game by themselves.
- **Service Credit and Tilt**: entries in the DIP Switches menu; each acts as one button press (select "Press"), and the switch stays closed for about half a second once the game runs again.
- **Service Mode**: the cabinet's test switch, on the main page.
- **Pause when OSD is open**: on by default.
- **Reset and Reset and close OSD**: Reset keeps the OSD open.
- **Hidden Items page**: shortcuts to the hidden developer menus of the games that have one (listed per game below), with a message saying whether the code was entered, when it works, or that the revision has none.
- **Information window**: a page drawn over the dimmed, paused game, used for the Mortal Kombat Move List and the Total Carnage Passwords (see those games).

### Saves and inputs

- **NVRAM**: settings, audits and high scores survive power-off. The CMOS is saved when the OSD is opened, if the game changed it.
- **Opposite directions: the last press wins.** A cabinet's stick cannot hold Up with Down or Left with Right, but a d-pad, a keyboard or buttons mapped to directions can, and Smash T.V. is reported to crash on it. When two opposite directions are held, only the one pressed last reaches the game, and letting it go hands control back to the one still held (pressed in the same instant, they cancel until one is let go). It is always on, for every player's stick and for the fire sticks of Smash T.V. and Total Carnage.
- **Every controller has Start, Coin, Test and Pause.** Coins 3 and 4 are on the third and fourth controllers' Coin buttons wherever the game has them. Each game's controls were checked against MAME's input ports (784 cases).

### Loading

- **MRAs for every set**: main sets at the top, other revisions, prototypes and hacks in `_alternatives`, each with an md5 and built for merged MAME 0.289 sets (split sets also work).
- **Y-Unit Test ROM**: Midway's board diagnostic, as its own MRA (see its section).

## Trog

The game's own page: [Trog](Trog.md).

Trog has no game-specific OSD items; it gets the core-wide extras plus two input conveniences.

- **4-way stick filter**: on a diagonal the direction pressed last wins, like the cabinet's 4-way joysticks.
- **Prototype rev 4.00** (trogpa4) has its own MRA, with an 8-way stick and a Bone button in place of Punch.
- **Four players**, with coin 3 on the third controller's Coin button.

## Smash T.V.

The game's own page: [Smash T.V.](SmashTV.md).

Smash T.V. gets the core-wide extras and a gamepad-friendly twin-stick layout.

- **Fire from buttons or the right stick**: B1-B4 fire up, down, left and right (two together fire diagonally), or the right analog stick fires in the direction it points.
- **Opposite directions**: Up with Down and Left with Right never reach the game, on the move stick or the fire stick; the one pressed last wins.
- **Coin 3** on the third controller's Coin button.

## High Impact Football

The game's own page: [High Impact Football](HighImpactFootball.md).

- **Octopus Bookkeeping shortcut** (Hidden Items, revisions LA1-LA5): the core plays the two switch combinations for you, in about 4 seconds, any time in attract mode. A message reports "code entered", "Not now: the code works in the attract mode", "Code not taken: try again" or "Not in this revision of the game" (the prototype has no menu). It follows the Players DIP switch (4 or 2 players).
- **Readable Coinage menu**: Coinage lists the USA settings so every one can be reached from the OSD (Free Play and the 2-coin settings were out of reach before), written short, for example "2C/1C - 4C/3C".
- **Coins 3 and 4** on the third and fourth controllers' Coin buttons.

## Super High Impact

The game's own page: [Super High Impact](SuperHighImpact.md).

- **Octopus Bookkeeping shortcut** (Hidden Items, revisions LA2 and LA1): the core plays the 27-press code for you, in about 3 seconds. The game accepts it only while attract mode shows HIGHEST PAID SUPERSTARS, so the core says "Not now" at any other time instead of spoiling the code. The prototypes have no menu and the message says so.
- **Readable Coinage menu**: the USA settings, so all six can be reached from the OSD, written short.
- **Coins 3 and 4** on the third and fourth controllers' Coin buttons.

## Strike Force

The game's own page: [Strike Force](StrikeForce.md).

Strike Force has no game-specific OSD items.

- **Short DIP labels**: Coin A's two-step settings are written short ("1C/1C - 2C/3C") and "Points for Extra Ship" is "Extra Ship Points", so the value fits on the DIP menu line.
- **Coins 3 and 4** on the third and fourth controllers' Coin buttons.
- **Saurian Front** (the prototype v5.0) has its own MRA among the alternatives.

## Mortal Kombat

The game's own page: [Mortal Kombat](MortalKombat.md).

Mortal Kombat has the most extras: five OSD features and its own button layout.

- **Finishing Moves** (main page): pick a fighter's fatality, and the core enters it on the round winner's controls at the next FINISH HIM, for either player. The distance is measured the way the game does it, from the fighters' centres. Messages say when the fighter is too far or too close, the move waits for another fighter's FINISH HIM, FINISH HIM is over, the move was not taken, or it was cleared. **Clear the set move** drops it. Checked in MAME on all 11 Mortal Kombat sets.
- **Move List** (Off, On): a reference window over the dimmed title screen with each fighter's special moves, fatality and the distance it needs, and The Pit's uppercut in the footer. Page 1 is Johnny Cage to Sonya, page 2 Raiden to Scorpion; close the OSD to see it in full screen and press Left or Right to turn the page. The game waits while it shows.
- **Fixed AI Difficulty** (main page: Off, 0 to 9; Off by default): holds the CPU opponent at one of the game's ten levels, 0 (easiest) to 9, from the first fight to the last, as the Fixed AI Difficulty of Mortal Kombat: Legacy Kollection does. Off is the game's own curve, which starts easy and gets harder with every match you win. Set it in the OSD before you press Start to begin a game. Shang Tsung follows it like any fighter; Goro much less. See the [Mortal Kombat page](MortalKombat.md#fixed-ai-difficulty).
- **EJB Menu shortcut** (Hidden Items, every revision except prototype 4.0): plays the 27-press code on the two Block buttons in about 3 seconds, for diagnostics, audits, enter initials and character endings. The game takes the code only in attract mode, not during a game or the game-over screens that follow it. Start 1 and 2 are held released while it plays so a Start press cannot spoil it. Messages report the result.
- **Reptile on demand** (Hidden Items, rev 3.0, rev 4.0, the Turbo hacks, the Victor bootleg of rev 3.0 and the Yawdim bootlegs):
  - **Reptile Fight Next**: Reptile comes after the next match you win in a 1-player game. One time, and select it again to cancel.
  - **Moon Silhouettes Always**: every match on The Pit has the silhouettes, and with them the chance of Reptile.
  - **Reptile Hints Always**: Reptile drops in with a hint before every round.
  - The core changes a few of the game's instructions as the CPU fetches them. Nothing is written to the ROM or the CMOS.
- **Button layout**: High Punch, Low Punch, High Kick, Low Kick, Block, then Start, Coin, Test, Pause. The board's second Block input stays unused, as the cabinet has one block button per player.
- **Coin 3** on the third controller's Coin button.

## Terminator 2: Judgment Day

The game's own page: [Terminator 2: Judgment Day](Terminator2.md).

Terminator 2 gets its gun control as an OSD entry in the DIP Switches menu.

- **Gun Control**: Joystick or Mouse for player 1.
- **Aiming**: each player's gun is aimed with the left analog stick (it points directly) or the d-pad (it moves the aim); player 1 can also use the mouse. The crosshairs on screen are the game's own.
- **Coins 3 and 4** on the third and fourth controllers' Coin buttons.

## Total Carnage

The game's own page: [Total Carnage](TotalCarnage.md).

- **Passwords** (main page, Off or On): a window over the game, on Total Carnage's own title screen, with how to enter a warp code at the PASSWORD REQUIRED disc, the 16 codes by mission with where each warps to, and the Weasel and Orcus warp bonuses. The game waits while it shows. Each code was checked in MAME and against the list in the program ROM, and the prototypes use the same codes.
- **Twin-stick fire** from B1-B4 (two together fire diagonally) or the right analog stick.
- **Opposite directions**: Up with Down and Left with Right never reach the game, on the move stick or the fire stick; the one pressed last wins.
- **Start/Bomb**: Start also throws a bomb in a game.
- **Coin 3** on the third controller's Coin button.

## Y-Unit Test ROM

The game's own page: [Y-Unit Test ROM](YUnitTestROM.md).

Midway's board diagnostic (yunittst, v1.40) is itself an addition: it has its own MRA and runs with the Super High Impact board settings and controls. Its tests are picked with the DIP switches in the OSD. Its sound and graphics ROMs were never dumped, so it has no sound or graphics to check. The Hidden Items page also shows "Octopus Bookkeeping" for it, because it shares Super High Impact's settings; the item does nothing here.

## At a glance

Mortal Kombat has the most game-specific extras, then Total Carnage; the rest are mostly input and menu conveniences.

| Game | OSD extras | Input and menu extras |
| --- | --- | --- |
| [Trog](Trog.md) | None | 4-way stick filter; prototype 4.00 MRA |
| [Smash T.V.](SmashTV.md) | None | Twin-stick fire from buttons or right stick; coin 3 |
| [High Impact Football](HighImpactFootball.md) | Octopus Bookkeeping | Short Coinage menu; coins 3 and 4 |
| [Super High Impact](SuperHighImpact.md) | Octopus Bookkeeping | Short Coinage menu; coins 3 and 4 |
| [Strike Force](StrikeForce.md) | None | Short DIP labels; coins 3 and 4 |
| [Mortal Kombat](MortalKombat.md) | Finishing Moves, Move List, Fixed AI Difficulty, EJB Menu, 3 Reptile options | Button layout; coin 3 |
| [Terminator 2](Terminator2.md) | Gun Control | Stick, d-pad or mouse aiming; coins 3 and 4 |
| [Total Carnage](TotalCarnage.md) | Passwords | Twin-stick fire; Start/Bomb; coin 3 |
| [Y-Unit Test ROM](YUnitTestROM.md) | Hidden Items shows an unused item | Own MRA |
