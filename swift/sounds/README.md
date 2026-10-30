# Sound drop-ins

Put audio here and the game uses it instead of its own synthesized effects.
Matching is by name, case-insensitive, ignoring any trailing take number — so
files keep whatever they were called when you extracted them:

| effect | matches | |
| --- | --- | --- |
| `shot` | `shot`, `chaingun`, `gun`, `machinegun`, `pistol`, `fire` | gunfire — **looped** |
| `death` | `death`, `guard_die`, `die`, `scream` | walkers, runners, bombers, brutes |
| `deathHeavy` | `lebensnd`, `lebens`, `heavydeath`, `officer` | heavies only |
| `boss` | `boss`, `achtung`, `alert`, `halt`, `roar` | the brute arriving |
| `nuke` | `nuke`, `explosion`, `boom`, `blast` | screen clear |
| `field` | `field`, `shield`, `dome`, `powerup` | force field up |
| `bite` | `bite`, `hit`, `thud`, `knock`, `wall` | wall taking damage |
| `pickup` | `pickup`, `health`, `medkit`, `heal`, `treasure` | supply crate opened |

Two files that differ only by a trailing number — `GUARD_DIE1`, `GUARD_DIE2` —
become two takes of the same effect, picked between at random.

The gun is a *held* sound: it loops for as long as the trigger is down rather
than being retriggered per round. A recorded burst is an attack, a body and a
decay, so only the body is looped — everything from the start until the level
falls to half its peak — with the seam crossfaded. Drop in a burst with a long
tail and you still get continuous fire.

Anything is resampled into the engine's format and levelled against the
synthesized sounds, so period audio at 7kHz 8-bit drops straight in. Effects
with no file fall back to synthesis, so a partial set is fine.

Audio files here are gitignored. That matters if you took them from a
commercial game: Wolfenstein 3D's source is GPL but its assets never were, so
they are yours to use locally and not yours to publish.

`swift run LegoLemmings --sound-test <dir>` prints what each effect resolved to
and writes every one out as a WAV to listen to.
