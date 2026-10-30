# Lego Lemmings — Swift / macOS

A port of the Java version in `../src` to Swift and AppKit, reading the same
`../assets` and the same `levelChooser.txt`.

```
./build-and-run.sh
```

No Xcode project: it is a Swift package, so `swift build` and `swift run` work
too. Assets are found relative to the source tree, the working directory, or an
app bundle; `LEGO_LEMMINGS_ASSETS` overrides the search.

## How it maps to the Java

The game is a pixel-mask engine — `BufferedImage.getRGB`/`setRGB` on a collision
mask drives all of the physics and every ability carves terrain by writing
pixels — so the port keeps that shape rather than moving to a sprite framework.

| Java | Swift |
| --- | --- |
| `BufferedImage` | `Bitmap` — packed `0xAARRGGBB` over a `CGContext` on the same memory |
| `Graphics2D` | `Graphics` — same calls, still origin-top-left with baseline text |
| `Lemming`, `LiteKernel` | `Lemming.swift`, `LiteKernel.swift`, ported closely |
| `Level` + `CanvasListener` | `Level` — `tick()` and `draw()` instead of a thread |
| `LemmingCanvas` + `StartListener` | `GameController` — screens as state, not booleans |
| `LevelChooser`, `LevelData` | same names; the parser splits on `||` |
| `NetServer`/`NetClient` + threads | `NetPeer` over Network.framework, same wire format |
| `Frame` + `BufferStrategy` | `GameView` (`NSView`) + `main.swift` |
| `HiResTimer` | `currentTimeMillis()` in `Util.swift` |

The mask palette, for reference: black is empty air, red is diggable terrain,
green is indestructible (and what a blocker paints), white kills on contact, and
blue is the exit.

## Deliberate changes

Everything else is meant to behave as it did.

- **Drawing happens on repaint.** The original drew each menu once with
  `frame.getGraphics()` and left it sitting in the window; AppKit repaints on
  demand, so the current screen is state and `draw()` renders it. Same reason
  the help and about overlays stay up while paused instead of relying on a
  frozen back buffer.
- **No busy-wait.** `while (isPaused) { isPaused = true; }` became a skipped
  `tick()`. Time spent paused is no longer charged against the level clock.
- **Out-of-bounds mask reads clamp** to the edge instead of throwing
  `ArrayIndexOutOfBoundsException` and killing the animation thread. Every level
  mask has a green (indestructible) border, so clamping makes the edge of the
  level behave like the wall it looks like.
- **The frame clock advances once per frame.** It used to be re-read inside the
  per-lemming loop, so with zero lemmings on screen time stopped and no further
  lemmings could ever be released.
- **All ten digits work** when typing a port number. The original tested
  `char > VK_0 && char < VK_9`, which rejected `0` and `9`.
- **A ninth ability, Cluster**, with no use limit. It bursts the chosen lemming
  into fifteen duplicates that arc away and detonate, each blowing a crater.
  The fan is described by each duplicate's normalized position across the
  spread, not by its index, so changing `Level.clusterCount` makes the burst
  denser rather than wider — driving it off the index threw the outermost of
  fifteen sideways at 42px a frame, into the nearest wall. The
  carrier goes with them — that cost is what stops an unlimited ability from
  simply deleting a level — and anything standing in a blast dies too. Craters
  only remove diggable earth: rock, hazard and the exit survive, so a cluster
  can open a route but cannot breach the level's indestructible frame or the
  pillars that pen a chamber.
- **A tenth ability, Lodestone**, also with no use limit, and the only one that
  never switches off. It plants the lemming as a magnetic anchor projecting a
  120px field, and that field does two things for as long as it stands:
  *steers* anyone inside it to face the anchor, so a scattered crowd walks
  itself back together, and *cushions* them, holding their fall counter at zero
  so a drop that lands inside the field is survivable however far it fell. On
  level 0 a crowd dropped without one loses 10 of 14; with one, it loses 1.
  Terrain still wins over steering — a lemming pointed at the anchor turns
  around when it walks into a wall.
- **`z` and `x` also zoom**, because macOS usually gives F1/F2 to the system,
  and **`f`** refits the level to the window.
- **The window opens large and resizes.** It is sized to the display (locked to
  4:3 so the pixels never stretch) rather than nailed to 800x600, and a level
  now opens zoomed out far enough to show all of itself, centred. The original
  always started at 1:1, which on a 1200x750 level meant seeing about a third
  of it and scrolling blind to find the exit.
- **The multiplayer connect screen says which field you are typing into.**
  Enter still moves from port to host, as before.
- **Game over is a screen**, not a `wait(5000)` that threw
  `IllegalMonitorStateException` and exited before anything was readable.
- Abilities are a fixed-size list keyed by ability rather than a `Stack` that
  got cloned, popped, and `insertElementAt`-ed at hand-computed indices.

One quirk was kept on purpose, and `LiteKernel.swift` says so at the top: the
kernel reads the lemming's position into locals and writes them back at the end,
so it discards whatever `climb()` and `mine()` did to the position unless it
returns early. That is load-bearing for how climbing looks.

## Generated levels

Sixteen themed levels live alongside the original four, generated by `LevelGen`
into `../assets` and listed below a marker in `levelChooser.txt`:

| | | | |
| --- | --- | --- | --- |
| pirates — Shipwreck Cove | space — Lunar Outpost | castle — Dragon Keep | western — Gold Gulch |
| arctic — Frozen Floe | jungle — Temple Ruins | aquazone — Coral Deep | dino — Raptor Valley |
| pharaoh — Scarab Tomb | city — Downtown Blaze | ninja — Shadow Dojo | train — Iron Trestle |
| volcano — Magma Core | factory — Gear Works | haunted — Crypt Hollow | mars — Red Frontier |

```
swift run LevelGen                  # redraw them all
swift run LegoLemmings --verify     # prove each one is still beatable
```

Regenerating rewrites only the part of `levelChooser.txt` below
`# --- generated levels ---`, so the hand-written levels above it are left
alone and running it twice changes nothing.

### How a level is built

Each one is a route the lemmings walk unaided from the spawn to a **gate** — a
sealed room that is the only thing between them and the exit, and that opens for
exactly one ability. Five layouts (`cascade`, `gallery`, `vault`, `chasm`,
`spire`) are combined with sixteen palettes and sets of scenery.

The route is one-way by construction: lemmings keep the direction they are
facing when they land, each platform's far edge overhangs the next thing down,
and the near border catches anyone who walks the other way at the start. The
geometry that makes that work, all of it learned from the engine:

- A drop over roughly **228px** kills on landing, so no drop exceeds 150 — and
  the vault is sized so that even two shafts dug in line stay under 200.
- A step over about **19px** is a wall a lemming turns at rather than climbs,
  so the pillars that pen a chamber stand 68px above its floor.
- Those pillars are **indestructible**. They wall in both the chamber and the
  room beneath it, so if they could be dug through, one misaimed ability would
  open a hole into dead space and strand everyone.
- A gate's trigger area is trimmed by a sprite width on the right, because a
  lemming's position is its left edge but it digs from the middle of its body.
- The engine repaints dug-out terrain with the art pixel at **(200, 200)**, so
  that pixel is kept as flat sky in every level.

`LevelGen` checks all of this and refuses to pass a level with a door that has
no headroom, a gate room with no diggable floor, a mask containing a colour the
engine has no meaning for, or a spawn buried in terrain.

### Gate hints

`assets/levelHints.txt` records each gate — the room, and the ability it wants.
It is a development artefact that the game itself ignores; `--verify` reads it
to play each level's intended solution and check the level's own goal is met.

## LEMMING DASH

A side-scroller built on the same assets, reachable from the title screen or
with `swift run LegoLemmings --dash [level]`.

The puzzle game watches a crowd from above and tells them what to do. This
plays one of them, from the side, at 60Hz. It reads the same collision masks —
red and green solid, white kills, blue is the way out — so all twenty levels
are playable without a single new asset, and the terrain is destructible for
the same reason: if a wall is in the way, dig through the floor or blow a hole
in it. Platformers almost never let you do that; this engine was already built
for it.

```
arrows / WASD   move          space   jump
S / down        dig downward  X       bash forward
B               bomb          R       reset      N / P  change level
```

Drop a bomb while standing still and it lands at your feet — ride the blast and
it throws you about 75px straight up. That is the rocket jump, and it is the
fastest way out of a hole you dug yourself into. Lob one while running and it
arcs ahead instead. The puzzle game's lemmings wander the same level on their
own 10Hz movement code, and you can land on their heads.

The view runs at 60Hz, which the puzzle game cannot: its movement constants,
release rates and fall distances are all tuned to a 10Hz step. So the window
ticks at 60 and `GameController.tickFrame` gives the puzzle game one step in
six, leaving `tick()` exactly what it always was for the headless harnesses.

## DOOMMINGS

A first-person shooter played inside a Lemmings level, from the title screen or
`swift run LegoLemmings --doom [level]`.

A level mask is already exactly what a raycaster wants: a 2D grid of solid and
empty. So the side-on cross-section of a level gets read as a *floor plan* and
walked through from the inside — the platforms you used to drop lemmings onto
become the walls of a maze.

```
WASD move  .  arrows turn  .  R run  .  space fire  .  N/P level  .  esc out
```

Firing puts a visible rocket down the corridor, blows a fireball where it
lands, and kills anything caught in it — the launcher sits bottom-right and
bobs as you walk, with a muzzle flash and a crosshair. All of that is separate
from whether the *mechanics* work, which is a distinction the first version got
wrong: space fired correctly and opened walls from the start, but drew nothing
at all, so it read as a dead key. `--doom-test` now checks both, comparing the
screen on the frame of the shot against a quiet frame and hunting for the
rocket's hot core in flight.

Nothing here is new art. Walls take their colour from the level painting at the
point the ray strikes, so every level keeps its own palette; the wanderers are
the lemming sprites billboarded against a z-buffer; the automap in the corner is
the collision mask drawn directly. And because the mask *is* the world, walls
are destructible for free — rockets carve the same pixels, and the renderer sees
the hole on the very next frame. Rock still shrugs them off.

The world renders at 400x280 and scales up, which keeps the pixel count sane and
looks right for the period. One number matters more than it looks: `cellSize`,
the mask pixels per grid cell. Wall height on screen is inverse to distance *in
cells*, so at 10 the open sky of a level put every wall forty cells away and two
pixels tall. At 16 the world comes in to roughly Wolfenstein proportions.

## LEMMING SIEGE

A horde-defence game, from the title screen or `swift run LegoLemmings --siege`.

The lemmings have stopped needing rescuing and started coming for you. They
pour in from both edges, converge on the tower in the middle, and chew on it
until it falls. You have five guns — see below.

Each barrel tracks the aim *point* rather than sharing one angle, so they
converge on the cursor from their own mountings instead of firing parallel. The
firing clock is fractional for the same reason: at `fireInterval / guns.count`,
integer division would round five guns to the wrong rate entirely.

```
mouse aims  .  hold to fire  .  space also fires  .  right button focuses
Q nuke  .  E force field  .  M mute  .  N backdrop  .  esc out
```

**Seven guns.** Three on the tower roof, and a pair under each of two airships
holding station in the upper corners, drifting gently as they do. They take
turns, so the stream is `fireInterval / guns.count` — each barrel fires every
four frames, and seven of them make 105 rounds a second.

Each airship carries one of each kind. Its **brass** barrel is *mirrored about
the horizon*: aim low at the ground and it swings high into the sky, so one
cursor covers both at once and the paratroopers are not a separate job. Its
**steel** barrel points straight at the cursor like the tower's. Holding the
**right button** drops the mirror and brings all seven onto the same point, for
when one thing needs all of it. The nuke moved to `Q` when the right button
took this over.

**The dead stay where they fall.** Bodies heap up — bucketed along the ground,
each one raising the pile — and lie there until the wave turns or a nuke goes
off, either of which sweeps the field. The stains they leave outlast them.

**Sound.** The guns, deaths, bites, nuke, dome and the brute's arrival all make
a noise. None of it is an audio file: every effect is synthesized as PCM at
startup from a few lines of arithmetic, in the idiom of an early-90s DOS
shooter — noise cracks, square waves and exponential decays. That is a style,
not an asset, so there is nothing to license and nothing to ship.

The gun is a held sound — it loops while the trigger is down rather than being
retriggered per round, with only the sustained body of the sample looped and
the decay tail discarded, so a recorded burst still gives continuous fire.
Everything else is one-shot and rate limited by its own length. Heavies have a death cry of their own,
separate from the one walkers, runners, bombers and brutes use. `M` mutes.

To use your own recordings instead, drop a WAV into `assets/sounds/` named
after the effect (`shot.wav`, `death.wav`, `nuke.wav`, `field.wav`, `boss.wav`,
`bite.wav`) and it is loaded in preference. That directory is gitignored, so
anything you put there stays local — which is the only safe way to use audio
lifted out of a commercial game.

**Two force fields, recharging.** `E` raises a dome over the tower. Anything
inside it is shoved back out to the perimeter and pinned there for seven
seconds — brutes included — so nothing reaches the wall to bite. It buys more
than its duration: the horde is pushed 127px further out than the wall, so it
has the whole walk back to make afterwards. And a crowd pinned against a dome
is a crowd standing still in front of three guns. One dome at a time, and a
charge comes back about every twenty-five seconds.

**Three nukes, recharging.** Right click or `Q` wipes everything on the field —
brutes included, which makes spending one on a boss a real trade against the
swarm you then cannot clear. The rack holds three and earns one back roughly
every thirty-five seconds, so about one a wave; the next pip in the HUD fills
as it charges. A nuke on an empty field is refused rather than wasted.

It opens on a setup screen where you choose the wave to start on, rather than
grinding through the early ones every run: arrows or `-`/`+` to step, up/down
to jump five, enter or click to begin. The screen states what that wave sends —
wave 12 opens with 41 raiders including heavies, against 8 plain walkers at
wave 1 — and the briefing is read off the same table the spawner uses, so it
cannot drift from what actually arrives. `swift run LegoLemmings --siege 12`
skips the screen entirely.

Dying offers both routes: `R` retries the wave you chose, enter goes back to
pick a different one.

Six kinds show up, and the mix hardens with each wave: walkers, runners,
bombers that take a fifth of the wall with them on arrival, heavies that soak
six rounds — and two that do not simply walk at you.

**Paratroopers** drop out of the sky anywhere across the field rather than
walking in from an edge, so the approach you have been watching is not the only
one. They come down under `floater.png`, which is already a lemming holding a
parachute — the bomber, which used to borrow that sprite, now carries a drawn
charge with a sparking fuse instead. **Shooters** stop 310px out and shell the tower from there, using the
digger sprite. That standoff is deliberately well outside the force field's
205px dome: the dome stops their shells but not them, so it buys time rather
than ending the problem.

**A guided bomb, every eight seconds or so.** The airships release one in turn,
with no input: it steers toward wherever the guns are pointed and goes off when
it gets there, clearing a 66px radius. It turns at a fixed rate rather than
instantly, so swinging the aim hard across the field makes it arc after you
rather than snap round — it lands near where you are looking, not exactly on
it. It never touches the wall. The readiness dial is the BOMB pip in the HUD.

**Supply crates fall from the sky.** A crate on a parachute drifts down every
twenty-odd seconds — twice as often once the wall is below half, so they arrive
when they are wanted. Shoot it and it patches 18% of the wall; leave it and it
lands, sits for seven seconds blinking, and is gone. It has to be hit, so it is
a reward for noticing it and swinging the guns across rather than a freebie,
and crates are tested before raiders so one drifting past a crowd is still
hittable.

**The wall repairs itself from kills.** Every raider killed banks a little
masonry — half a point for a walker, nearly two for a heavy, fourteen for a
brute — which is then paid back into the wall at 0.012 a frame, well under one
percent a second. It is kill-driven, not time-driven: standing still earns
nothing, and the payout never outruns a wave. The bank is capped at 30 so a
quiet spell at full health cannot stockpile a whole wall. The gauge shows
pending repair as a dim segment ahead of the solid bar.

Waves are bigger and faster than they were — a pack of 52 at wave 9 against 32
before, arriving at 8.6 a second against 2.5, and from wave 8 they come in
twos.

**Every third wave ends with a Brute.** It is four and a half times the size of
a lemming, has a health bar of its own across the top of the screen, and scales
with how deep you are — 126hp at wave 3, 270hp at wave 15. It will not be
hurried: it is slow, it hits for a third of your wall, and it speeds up as it
is wounded. Each quarter of its health it sheds a pair of walkers, so you
cannot simply hold the trigger on it and ignore everything else. Nothing is
spawned behind it until it is down, because it is an ordinary attacker as far
as the wave logic is concerned — the next wave's "is everything dead yet" test
simply will not pass while it stands. All of them are the existing sprite sheet — heavies are the
blocker pose scaled up, bombers carry the floater's umbrella, and everything
that dies plays the puzzle game's own three-frame death. The backdrop is a
level painting darkened to 40%, which has to be baked into a copy up front
because `Graphics` has no alpha to wash over the top with.

The wall shows its damage: battlements crumble, cracks open at 75%, 45% and
20%, and the gauge on the parapet turns amber then red.

## Checking it without playing it

```
swift run LegoLemmings --selftest          # every level x every ability, fast
swift run LegoLemmings --verify            # play each generated level's solution
swift run LegoLemmings --screens  <dir>    # every menu screen to PNG
swift run LegoLemmings --smoke 600 <dir> [level]  # play a level, snapshot frames
swift run LegoLemmings --trace pirates     # one level, frame by frame
swift run LegoLemmings --cluster [dir]     # fire a cluster, check it carves
swift run LegoLemmings --lodestone [dir]   # plant an anchor, check it gathers
swift run LegoLemmings --dash-test <lvl> [dir]  # play the side-scroller, scripted
swift run LegoLemmings --doom-test <lvl> [dir]  # walk the FPS, scripted
swift run LegoLemmings --siege-test [dir]       # hold the fortress, scripted
swift run LegoLemmings --sound-test [dir]       # render every effect to WAV
```

`--selftest` drives every level with each ability and plays one to completion;
`--verify` proves the generated ones can actually be won. `--trace` prints where
every lemming is each frame, which is how the gate bugs above were found. It is worth running after touching `LiteKernel` or any of the
terrain-carving code in `Lemming`, since that is where a bad write would hide.
