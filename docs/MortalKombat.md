# Mortal Kombat

[Back to the main README](../README.md)

<img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Mortal_Kombat.png" width="400" alt="Mortal Kombat title screen"> <img src="https://github.com/Gm0rk/Arcade-Midway-Y-Unit_MiSTer/blob/main/media/Mortal_Kombat_2.png" width="400" alt="Mortal Kombat gameplay">

| | |
|---|---|
| Sets | mkla4 (rev 4.0, main MRA); rev 3.0, 2.0, 1.0; prototypes 9.0, 8.0, 4.0; Turbo 3.0 / 3.1, Nifty Kombo / Nifty Kombo 666 and Reptile Man hacks; the Victor bootleg of rev 3.0; the four Yawdim bootlegs |
| ROM zip | `mk.zip` (MAME's merged Mortal Kombat set) |
| Players | 2 |
| Sound | ADPCM board (the Yawdim bootlegs: a Z80 with an OKI M6295) |

## Extra content

Mortal Kombat has the most extras: five OSD features and its own button layout.

- **[Finishing Moves](#finishing-moves)** (main page): pick a fighter's fatality, and the core enters it on the round winner's controls at the next FINISH HIM, for either player. The distance is measured the way the game does it, from the fighters' centres. Messages say when the fighter is too far or too close, the move waits for another fighter's FINISH HIM, FINISH HIM is over, the move was not taken, or it was cleared. **Clear the set move** drops it.
- **[Move List](#move-list)** (Off, On): a reference window over the dimmed title screen with each fighter's special moves, fatality and the distance it needs, and The Pit's uppercut in the footer. With the OSD closed, Left or Right turns to the other page. The game waits while it shows.
- **[Fixed AI Difficulty](#fixed-ai-difficulty)** (main page: Off, 0 to 9; Off by default): holds the CPU opponent at one of the game's ten levels, 0 (easiest) to 9, from the first fight to the last, as the Fixed AI Difficulty of Mortal Kombat: Legacy Kollection does. Off is the game's own curve, which starts easy and gets harder with every match you win. Set it in the OSD before you press Start to begin a game. Shang Tsung follows it like any fighter; Goro much less (see [Fixed AI Difficulty](#fixed-ai-difficulty)).
- **[EJB Menu shortcut](#hidden-developer-menu-ejb-menu)** (Hidden Items, every revision except prototype 4.0): plays the 27-press code on the two Block buttons in about 3 seconds, for diagnostics, audits, enter initials and character endings. The game takes the code only in attract mode, not during a game or the game-over screens that follow it. Start 1 and 2 are held released while it plays so a Start press cannot spoil it. Messages report the result.
- **[Reptile on demand](#reptile)** (Hidden Items, rev 3.0, rev 4.0, the Turbo hacks, the Victor bootleg and the Yawdim bootlegs): Reptile Fight Next, Moon Silhouettes Always and Reptile Hints Always. The core changes a few of the game's instructions as the CPU fetches them; nothing is written to the ROM or the CMOS.
- **Button layout**: High Punch, Low Punch, High Kick, Low Kick, Block, then Start, Coin, Test, Pause. The board's second Block input stays unused, as the cabinet has one block button per player.
- **Coin 3** on the third controller's Coin button.

The [core-wide extras](ExtraContent.md#core-wide-features) (CRT Adjust, CRT V-Size, Video Timing, DIP Switches, Service Mode and the rest) apply to every game.

The game draws a few stray pixels in the first line of the picture: at the left of the title screen, and a couple that blink during a fight. A cabinet's overscan hides them; on HDMI, turn on [HDMI Top Row Pixel Fix](ExtraContent.md#video-output) in Video Settings to hide that line (the analog output does not change).

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

## Fixed AI Difficulty

The game keeps the CPU opponent's difficulty as a **level from 0 (easiest) to
9**, and the CPU's behaviour follows it: the game's tables of how the CPU
fights are indexed by the level. A 1-player game starts at a level from the
game's own difficulty adjustment (0 on its default setting), the level goes up
after every match you win (by 1 on the default setting; more on the harder
ones), it is held at a minimum while you are on a winning streak, and it goes
down after a match you lose. That is why the CPU gets harder as you go.

**OSD → Fixed AI Difficulty** (Off, then 0 to 9; Off by default) holds the
level at the one you pick, so the CPU is as hard in the last fight as in the
first. It is modelled on the setting of the same name in Mortal Kombat:
Legacy Kollection, with the same range. Off leaves the game's own curve.

- **When to set it:** in the OSD, before you press Start to begin a game. The
  game sets the level the moment Start is pressed, before the character
  select, and the core replaces that level with yours, so the first fight is
  already at it. Putting the coin in before or after changes nothing; it is
  Start that counts. The attract mode's demo fights use it too.
- **Changed during a game** (character select, a fight, the continue
  countdown), it takes effect at the next level the game sets, which is when
  the current match ends. Until then the CPU stays at the level it had. Set
  back to Off during a game, the level stays where it is and the game's own
  curve carries on from there: up after a match you win, down after one you
  lose.
- It is for 1-player games; a 2-player game has no CPU opponent.
- **Goro and Shang Tsung** have no difficulty curve of their own: like every
  other fighter they read the game's one level word. **Shang Tsung** follows
  it like the normal fighters: in MAME, replaying the start of his fight at
  level 0 and at level 9 with the same inputs, the two fights part within about
  two seconds, as Johnny Cage's and Sub-Zero's do. **Goro** follows it much
  less: his fight is identical at both levels for the first four and a half
  seconds, and after that the game reads the level only now and then, in
  short bursts, where the other fighters read it all the time. So the option
  changes Goro far less than anyone else; expect him to stay hard at a low
  setting and not to get much harder at a high one. How large the
  difference is (his damage, how often he attacks) was not measured, and these
  tests were run in MAME on mkla4 with one fighter, not on hardware.
- What the CPU does at each level is the game's own: the option picks the
  level, it does not change the game's AI.
- It is off while the test menu is selected (Service Mode, a Test button or
  the Test Switch DIP). The test menu's CPU board test writes patterns over
  the whole RAM and reads them back; with the level held it would report a
  fault.
- The core does it on the board: every time the game writes a level (0 to 9)
  to its level word, the level you picked is stored instead. The program ROM
  is not changed. The word is at 0104D6E0 in rev 1.0 to 4.0, the Turbo hacks,
  the Reptile Man hack and the bootlegs, at 0104D6C0 or 0104D6D0 in the
  prototypes and Nifty Kombo (`tools/yunit_fmoves.py`, `level_scan`, finds it
  in every set from the routine that moves the level).

## Hidden developer menu: EJB Menu

Every revision except prototype 4.0 hides the **EJB Menu**: diagnostics, coin
bookkeeping, game audits, "Hello", enter initials and character endings.
**OSD → Hidden Items → EJB Menu** enters the code for you (about 3 seconds; leave
the controls alone); with "Pause when OSD is open" it starts when the OSD closes.

**When it is accessible.** The game takes the code only while it is in its
attract mode, whether the core enters it or you do by hand:

- **Accessible:** the attract mode that runs from power-up until a game is
  started, and again once a game is over, from the MIDWAY PRESENTS screen on.
- **Not accessible:** during a game (character select, the fights, the
  continue countdown) and during the game-over sequence that follows it: the
  GAME OVER screen, the winning-streaks table and the Mortal Kombat comic book
  offer. The game is not in attract mode yet, although it looks like it. In a
  test game that was lost without entering anything this lasted about 47
  seconds; wait for MIDWAY PRESENTS, then use the shortcut.

A message says how it went: "EJB Menu: code entered" when the menu opens,
"Not now: the code works in the attract mode" when the game is not in attract
mode (during a game or the game-over sequence; the code is not entered),
"Code not taken: try again" if the menu did not open, and "Not in this revision
of the game" on prototype 4.0.

By hand: press P1 Block (0) and P2 Block (1) in the order
`0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 0 0 1 0 0 1 1 1 0 0 0 0`, each press within
about a quarter of a second of the last.

## Reptile

Rev 4.0, rev 3.0, the two Turbo hacks, the Victor bootleg and the Yawdim
bootlegs (rev 3.0's program) have Reptile, the secret green ninja (the older revisions, the
prototypes and Nifty Kombo do not; the Reptile Man hack changes this part of
the program, so the core offers no Reptile options on it). In the
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

## Hacks and bootlegs

Some sets of the `_alternatives` folder need a word:

- **Reptile Man hack** (mkrep): a hack of rev 4.0 (9/28/92). MAME marks it as
  not working because its protection is not emulated, and patches that
  protection out when it starts the game; the MRA does the same with three
  `<patch>` entries after the program ROM, so the program the core runs is the
  one MAME runs. Finishing Moves and the EJB Menu shortcut work as on rev 4.0;
  Hidden Items has no Reptile lines (see [Reptile](#reptile)).
- **Victor bootleg of rev 3.0** (mkla3bl): rev 3.0's program with its sound,
  on a bootleg board whose graphics ROMs are three 2 MB files with the bytes of
  the original ROMs interleaved in pairs. MAME puts them back in order when it
  starts; the core does it while the ROMs load (the MRA lists the three files as
  they are). Everything else is rev 3.0: Finishing Moves, the EJB Menu shortcut
  and the Reptile lines work as on it.
- **Yawdim bootlegs** (mkyawdim, mkyawdim2, mkyawdim3, mkyawdim4: "Mortal Kombat
  (Yawdim bootleg, set 1)" to "set 4"): rev 3.0 (about 330 bytes of its program
  changed for the bootleg board) on a board with no protection and without
  Williams' sound board. The sound comes from a Z80 (4 MHz)
  that plays samples through an OKI M6295 (1 MHz, no music chip); the main board
  sends it a command byte and the Z80 starts the sample. The core has this board
  (a Z80 core under `rtl/tv80`, `rtl/sound/yawdim_sound.sv`), and it follows
  MAME's driver in the details that differ between the sets:
  - Sets 1, 3 and 4 interrupt the Z80 with every command; set 2 holds the interrupt
    until the Z80 has read the command.
  - The OKI plays from banks of 256 KB, chosen by a Z80 write: two bits (1 MB of
    samples) in sets 1, 3 and 4, three bits (2 MB) in set 2.
  - The bootleg's graphics hardware draws horizontally flipped sprites differently
    from the original board; the core does it the way MAME does for these sets.
  - The ADPCM board's interrupt line (input bit 14) is not connected.

  The bootleg board has a 48 MHz oscillator (MAME's driver runs the 34010 at 40 MHz),
  and the core runs it at 48 MHz, like Mortal Kombat. MAME marks sets 3 and 4 as
  having imperfect sound and says that some sound effects are missing on the real
  PCB of set 2; the core plays what MAME plays. Finishing Moves, the EJB Menu
  shortcut and the Reptile lines work as on rev 3.0 (the game's variables are at the
  same addresses in all four sets). Sets 1 and 2 have the same program; sets 3 and 4
  differ from set 1 by 3 and 27 bytes.
