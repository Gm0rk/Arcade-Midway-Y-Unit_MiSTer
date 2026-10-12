# High Impact Football

[Back to the main README](../README.md)

| | |
|---|---|
| Sets | hiimpact (rev LA5, main MRA); LA4, LA3, LA2, LA1, prototype 8.6 |
| ROM zip | `hiimpact.zip` (merged set) |
| Players | 4 (or 2 with the Players DIP switch) |
| Sound | CVSD board |

## Controls

| Input | Use |
|---|---|
| Stick | Move (8-way) |
| B1 | Action |
| Start / Coin | Players 1-4; the third and fourth controllers' Coin are coins 3 and 4 |
| Test, Pause | Service mode switch, pause |

The **Players** DIP switch (OSD, DIP Switches) sets a 4-player or 2-player
cabinet.

## Hidden developer menu: Octopus Bookkeeping

Revisions LA1-LA5 hide a page of developer audits behind two switch
combinations. **OSD → Hidden Items → Octopus Bookkeeping** enters them for you
(about 4 seconds; leave the controls alone). Use it any time in attract mode,
before a game is started; with "Pause when OSD is open" it starts when the
OSD closes. A button turns the page. The prototype has no such menu.

A message says how it went: "Octopus Bookkeeping: code entered" when the
pages open, "Not now: the code works in the attract mode" during a game (the
code is not entered), "Code not taken: try again" if they did not open, and
"Not in this revision of the game" on the prototype.

By hand: hold P2 Down + P3 Up and press P3 Action for about a second; let go,
and within a second hold P2 Right + P3 Left and press P2 Action. Nothing else
may be pressed. With the Players DIP switch at 2: P1 Down + P2 Up + P2
Action, then P1 Right + P2 Left + P1 Action.
