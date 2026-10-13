# Mortal Kombat

[Back to the main README](../README.md)

| | |
|---|---|
| Sets | mkla4 (rev 4.0, main MRA); rev 3.0, 2.0, 1.0; prototypes 9.0, 8.0, 4.0; Turbo 3.0 / 3.1 and Nifty Kombo / Nifty Kombo 666 hacks |
| ROM zip | `mk.zip` (MAME's merged Mortal Kombat set) |
| Players | 2 |
| Sound | ADPCM board |

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

**OSD → Finishing Moves** lists each fighter's fatality and The Pit. Pick the
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

Every fighter also has The Pit (on that stage): D+HP, close (up to 80).

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
| Stage move: The Pit only | The Pit set, another stage |
| FINISH HIM is over: the move waits for the next one | FINISH HIM ended before the move could start |
| Move not taken | The game did not take it (the opponent was hit, the distance changed) |
| Finishing move cleared | After Clear the set move |

## Move List

**OSD → Move List** (Off, then the fighters in the select screen's order)
shows the move list page with that fighter over the game, on the title
screen dimmed: two pages, Johnny Cage to Sonya and Raiden to Scorpion, as in
the Midway T-Unit core. Each fighter has the special moves and the fatality
with the distance it needs; The Pit, the same for all, is at the bottom. The
game waits while the page is on (the OSD can stay open over it; pick a
fighter on the other page to turn it); set Move List to **Off** to play on. It is for reference: the core does not enter these moves
(Finishing Moves does that for the fatality and The Pit).

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

Every fighter: The Pit, D+HP, Close, on The Pit stage only.

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
