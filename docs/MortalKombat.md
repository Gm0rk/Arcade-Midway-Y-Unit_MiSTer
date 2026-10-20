# Mortal Kombat

[Back to the main README](../README.md)

<img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Mortal_Kombat.png" width="400" alt="Mortal Kombat title screen"> <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Mortal_Kombat_2.png" width="400" alt="Mortal Kombat gameplay">

| | |
|---|---|
| Sets | mkla4 (rev 4.0, main MRA); rev 3.0, 2.0, 1.0; prototypes 9.0, 8.0, 4.0; Turbo 3.0 / 3.1 and Nifty Kombo / Nifty Kombo 666 hacks |
| ROM zip | `mk.zip` (MAME's merged Mortal Kombat set) |
| Players | 2 |
| Sound | ADPCM board |

## Extra content

Mortal Kombat has the most extras: four OSD features and its own button layout.

- **[Finishing Moves](#finishing-moves)** (main page): pick a fighter's fatality, and the core enters it on the round winner's controls at the next FINISH HIM, for either player. The distance is measured the way the game does it, from the fighters' centres. Messages say when the fighter is too far or too close, the move waits for another fighter's FINISH HIM, FINISH HIM is over, the move was not taken, or it was cleared. **Clear the set move** drops it.
- **[Move List](#move-list)** (Off, On): a reference window over the dimmed title screen with each fighter's special moves, fatality and the distance it needs, and The Pit's uppercut in the footer. With the OSD closed, Left or Right turns to the other page. The game waits while it shows.
- **[EJB Menu shortcut](#hidden-developer-menu-ejb-menu)** (Hidden Items, every revision except prototype 4.0): plays the 27-press code on the two Block buttons in about 3 seconds, for diagnostics, audits, enter initials and character endings. Start 1 and 2 are held released while it plays so a Start press cannot spoil it. Messages report the result.
- **[Reptile on demand](#reptile)** (Hidden Items, rev 3.0, rev 4.0 and the Turbo hacks): Reptile Fight Next, Moon Silhouettes Always and Reptile Hints Always. The core changes a few of the game's instructions as the CPU fetches them; nothing is written to the ROM or the CMOS.
- **Button layout**: High Punch, Low Punch, High Kick, Low Kick, Block, then Start, Coin, Test, Pause. The board's second Block input stays unused, as the cabinet has one block button per player.
- **Coin 3** on the third controller's Coin button.

The [core-wide extras](ExtraContent.md#core-wide-features) (CRT Adjust, CRT V-Size, Video Timing, DIP Switches, Service Mode and the rest) apply to every game.

## Controls

| Input | Use |
|---|---|
| Stick | Move (8-way) |
| B1 | High Punch |
| B2 | Low Punch |
| B3 | High Kick |
| B4 | Low Kick |
| B5 | Block |
| Start / Coin | Players 1-2; the third controller's Coin is coin 3 |
| Test, Pause | Service mode switch, pause |

The cabinet has one block button per player; the board's second block input
("Block 2" in MAME) is not used.

## Finishing Moves

**OSD → Finishing Moves** lists each fighter's fatality. Pick the
fighter in **Fighter**, then the move: the core enters it for you at the next
FINISH HIM that fighter wins (either player), on the winner's controls. Stand
at the right distance; the core says when you are too far or too close and
waits while you step in or out, then takes the controls for about a second
(your own are ignored meanwhile). A move set before FINISH HIM, or at another
fighter's FINISH HIM, waits for the right one; it is used once. **Clear the
set move** drops it.

| Fighter | Move | Command | Distance |
|---|---|---|---|
| Johnny Cage | Decapitation | F F F HP | close (up to 70) |
| Kano | Heart Rip | B D F LP | close (up to 102) |
| Sub-Zero | Spine Rip | F D F HP | close (up to 99) |
| Sonya | Kiss of Death | F F B B BL | any |
| Raiden | Electrocution | F B B B HP | 74-134 |
| Liu Kang | Cartwheel | D B U F D | any |
| Scorpion | Fire Breath | (BL) U U | 119-158 |

The Pit is not entered for you: on that stage an uppercut (D+HP) up close does it (the Move List's footer says so).

Commands are for a fighter facing right: F and B are toward and away from the
opponent, (BL) means Block held over the directions. Distances are between
the two fighters' centres, in pixels of the 400-pixel-wide picture; standing
as close as possible is about 62. They are the game's own limits (checked on
every revision) less 2 pixels.

Messages (shown after the OSD closes):

| Message | |
|---|---|
| Finishing move set: it plays at the next FINISH HIM | Set outside FINISH HIM |
| Not this fighter's FINISH HIM: the move waits for a later one | Set while another fighter is finishing |
| Too far: step closer / Too close: step back | The distance is outside the move's window |
| FINISH HIM is over: the move waits for the next one | FINISH HIM ended before the move could start |
| Move not taken | The game did not take it (the opponent was hit, the distance changed) |
| Finishing move cleared | After Clear the set move |

## Move List

**OSD → Move List** (Off, On) shows the move list over the game, on the
title screen dimmed: page 1 has Johnny Cage to Sonya, page 2 Raiden to
Scorpion (the select screen's order). Each fighter has the special moves and
the fatality with the distance it needs; The Pit's uppercut, the same for
all, is at the bottom. **Close the OSD** to see the page in full screen, and
press **Left or Right** on either controller to turn to the other page (the
d-pad steers the OSD while it is open, so the pages turn only with it
closed). The list starts on page 1 each time it is switched On. The game
waits while it is on; open the OSD and set Move List to **Off** to play on.
It is for reference: the core does not enter these moves (Finishing Moves
does that for the fatalities).

Commands as the game reads them: F toward the opponent, B away; (BL B F)
means Block held while you enter B F; X+Y pressed together. Distances in
words: Close (touching to a little apart), Sweep (out to a sweep's reach),
Jump (beyond a sweep, about a jump away); "Close to sweep" and "Sweep to
jump" span two (the pixel windows are under Finishing Moves). The list is the
one of rev 4.0; the prototypes may differ.

| Fighter | Move | Command | Distance |
|---|---|---|---|
| Johnny Cage | Green Bolt | B F LP |  |
|  | Shadow Kick | B F LK |  |
|  | Split Punch | LP+BL |  |
|  | Fatality: Decapitation | F F F HP | Close |
| Kano | Knife Throw | (BL B F) |  |
|  | Cannonball | F D B U |  |
|  | Fatality: Heart Rip | B D F LP | Close |
| Sub-Zero | Freeze | D F LP |  |
|  | Slide | B+LP+LK+BL |  |
|  | Fatality: Spine Rip | F D F HP | Close |
| Sonya | Ring Toss | LP B LP, quickly (all within about 0.4 s) |  |
|  | Leg Grab | D+LP+LK+BL |  |
|  | Square Wave | F B HP |  |
|  | Fatality: Kiss of Death | F F B B BL | Anywhere |
| Raiden | Lightning | D F LP |  |
|  | Teleport | D U |  |
|  | Torpedo | B B F |  |
|  | Fatality: Electrocution | F B B B HP | Close to sweep, not when touching |
| Liu Kang | Fireball | F F HP |  |
|  | Flying Kick | F F HK |  |
|  | Fatality: Cartwheel | D B U F D | Anywhere |
| Scorpion | Spear | B B LP |  |
|  | Teleport | D B HP |  |
|  | Fatality: Fire Breath | (BL) U U | Sweep to jump |

Every fighter, on The Pit stage only: an uppercut (D+HP), close. The core does not enter it.

## Hidden developer menu: EJB Menu

Every revision except prototype 4.0 hides the **EJB Menu**: diagnostics, coin
bookkeeping, game audits, "Hello", enter initials and character endings.
**OSD → Hidden Items → EJB Menu** enters the code for you (about 3 seconds; leave
the controls alone). Use it any time in attract mode, before a game is
started; with "Pause when OSD is open" it starts when the OSD closes.

A message says how it went: "EJB Menu: code entered" when the menu opens,
"Not now: the code works in the attract mode" when used during a game (the
code is not entered), "Code not taken: try again" if the menu did not open,
and "Not in this revision of the game" on prototype 4.0.

By hand: press P1 Block (0) and P2 Block (1) in the order
`0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 0 0 1 0 0 1 1 1 0 0 0 0`, each press within
about a quarter of a second of the last.

## Reptile

Rev 4.0, rev 3.0 and the two Turbo hacks have Reptile, the secret green
ninja (the older revisions, the prototypes and Nifty Kombo do not). In the
game you meet him in a 1-player game, after a match on The Pit while a
silhouette crosses the moon: win both rounds flawless, never press Block and
finish with a fatality, and Reptile challenges you on the spikes below. The
silhouettes come rarely: after power-up the game counts 40 won matches, the
next match on The Pit then has them, and the count starts over. Before a
round Reptile very rarely drops in with a hint ("LOOK TO LA LUNA", "BLOCKING
WILL GET YOU NOWHERE", ...): rev 4.0 counts every round the cabinet plays in
the CMOS (the GREEN NINJA COUNTER audit) and sends him at 2000.

On these sets **OSD → Hidden Items** has three more lines:

| Item | |
|---|---|
| Reptile Fight Next | Reptile comes after the next match you win in a 1-player game, wherever it is and however you won. Select it again to cancel; it is used up when his fight starts |
| Moon Silhouettes Always | Every match on The Pit has the silhouettes, and with them the chance: the flawless, no-block, fatality win there brings Reptile |
| Reptile Hints Always | Reptile drops in with a hint before every round |

Messages: "Reptile fight set: win a match in a 1-player game" and "Reptile
fight cleared". The two Always options stay on until you turn them off. The
core changes a few of the game's instructions as the CPU fetches them
(nothing is written to the ROM or the CMOS, and the game's ROM checks still
see the original), so turning an option off puts the game back at once.
One difference with the real hints: when Reptile shows up by himself the
game also clears its audits (the EJB Menu's bookkeeping); with Reptile Hints
Always the core skips that, so the audits are kept.

The Turbo hacks changed the rules: Turbo 3.0 drops the moon and block
conditions, Turbo 3.1 also lets two players and the second stage bring
Reptile and needs no flawless rounds. The options work the same on them.
