# Super High Impact

[Back to the main README](../README.md)

| | |
|---|---|
| Sets | shimpact (rev LA2, main MRA); LA1, prototypes 6.0, 5.0, 4.0 |
| ROM zip | `shimpact.zip` (merged set) |
| Players | 4 (or 2 with the Players DIP switch) |
| Sound | CVSD board |

## Controls

| Input | Use |
|---|---|
| Stick | Move (8-way) |
| B1 | Action |
| Start / Coin | Players 1-4; the third and fourth controllers' Coin are coins 3 and 4 |
| Test, Pause | Service mode switch, pause |

## Hidden developer menu: Octopus Bookkeeping

Revisions LA2 and LA1 hide a page of developer audits behind a 27-press code.
**OSD → Hidden Items → Octopus Bookkeeping** enters it for you (about 3 seconds;
leave the controls alone). The game only accepts it while attract mode shows
**HIGHEST PAID SUPERSTARS** (about 8 seconds, roughly half a minute into each
attract cycle), so select it while that screen is up; with "Pause when OSD is
open" it starts when the OSD closes. The prototypes have no such menu.

A message says how it went: "Octopus Bookkeeping: code entered" when the
page opens, "Not now: the code works while the attract mode shows HIGHEST
PAID SUPERSTARS" at any other time (the code is not entered), "Code not
taken: try again" if the page did not open (the screen changed while the
code played), and "Not in this revision of the game" on the prototypes.

By hand: press the Action buttons of P2 (0) and P3 (1) in the order
`0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 0 0 1 0 0 1 1 1 0 0 0 0`, each press within
about a quarter of a second of the last; with the Players DIP switch at 2,
use P1 (0) and P2 (1).
