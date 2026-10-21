# Phalanx CIWS

A 360 degree point defence shooter for Godot 4.4+. You are the gun mount on a
ship's deck. You can't move. You traverse, elevate and fire, and everything you
see comes through the mount's own low resolution thermal sensor: black sky,
white heat, coarse grey levels, sensor noise.

Nothing is imported. Every aircraft is built from primitive shapes at runtime
and every sound is synthesised by `tools/make_audio.py`.

## Running it

1. Open Godot 4.4 or 4.5.
2. Import, then pick this folder's `project.godot`.
3. Press F5. Click on the title screen to start.

The first launch reimports the audio files and the icon, which takes a second.

## Controls

Everything works from the mouse. Keyboard keys are there as a backup.

| Input | Action |
|---|---|
| Move mouse | Traverse and elevate |
| Left button | Gun |
| Right button | Full sensor zoom while held (55° down to 17°) |
| Wheel | Step the zoom and leave it there |
| Middle button | Reload (1550 rounds, 2.4 s) |
| Side button 1 or `Q` | Missile. Zoom in, hold it on a target until it locks |
| Side button 2 or `E` | Salvo. Fires at everything on screen |
| `Esc` | Pause. The wheel sets mouse sensitivity while paused |
| `F` | Switch white hot / black hot |
| `W` `A` `S` `D` | Slew with keys instead of the mouse |

The diamond next to a tracked contact is the lead pipper: where to aim so the
rounds arrive where the target will be, bullet drop included. Put the cross on
the diamond, not on the aircraft. `TOF` beside it is the time of flight.

## Levels

The first four levels are scripted so the good stuff shows up fast.

| Level | Name | What happens |
|---|---|---|
| 1 | First Contact | Six drones, then two fast jets |
| 2 | Saturation | Drones, jets, helicopters, sea skimming missiles, one heavy bomber |
| 3 | Mothership | A 360 m airship carrier arrives with two escorts and drops drones and jets out of its belly bay until you bring it down |
| 4 | Orbital | A 2 km dreadnought drops out of warp overhead and launches craft from its hangars until you bring it down |

From level 5 on, a budget based wave director builds each wave from the enemy
table, bigger budget every wave. The mothership can show up again from level 8,
the Leviathan from level 12 and the dreadnought from level 16.

## The mothership

A rigid airship, 360 m long, carrying a launch bay. It closes to about 1.2 km,
turns broadside and circles you while the bay opens every 8 seconds and drops
three craft. It never comes in, so the level doesn't end until it's dead.

It has 14,000 HP. Things that help:

- The four engine pods take triple damage. They're the brightest things on the
  hull.
- The open bay on the belly takes 2.5x, and the bridge under the nose takes 3x.
- It catches fire in stages at 75%, 50% and 25% integrity, wherever you last
  hit it, so you can read the damage you've done straight off the image.
- Missiles help, but it takes a lot of them.

Its hitbox is a chain of spheres down the hull plus the gondola, pods and tail,
so rounds that pass through empty sky beside it miss.

## The dreadnought

A warship about 2 km long. It doesn't fly in. First a point of heat appears in
the sky and grows while a warning gives its bearing. Then the sensor whites
out, the ship drops out of warp several kilometres away, stretched and
trailing a hot wake, and brakes hard until it stops broadside about 1.7 km
from you, filling most of the screen. It can't be hit until it has stopped.

From then on it barely moves. Every 10 seconds its belly hangars launch three
craft (jets, drones, dropships, gunships), up to 14 times.

It has 50,000 HP. Things that help:

- The six drive bells at the stern take triple damage.
- The emitter between the bow prongs takes 4x, the bridge on the tall sail 3x.
- The four lit hangar slots on the belly take 2.5x, the radiator wings 1.8x.
- It starts burning early and burns harder at 75%, 50% and 25%.

When it dies it doesn't vanish. It loses lift and falls into the sea nose
first over about nine seconds, with explosions riding it down, then one last
flash.

## Missiles

**Lock on.** Zoom in first, the seeker won't work at wide field. Hold the
button with the cross within 3.2° of a target. The lock builds over about 2.5
seconds with an accelerating tone, then a missile leaves the launcher behind
you, climbs over your head and turns downrange. Eight ready cells, one rearms
every 9 seconds, and they refill every level.

**Salvo.** No zoom needed. Locks everything currently on screen (up to 12) and
ripple fires one missile at each. It needs a full charge, and the charge only
fills from gun kills, faster when you chain kills together (the combo counter).
It doesn't use up your eight cells.

One missile kills anything up to a heavy bomber. Big ships need many.

## How it plays

Contacts spawn 0.8 to 3 km out and close on you. Anything that gets within
55 m damages the hull, and at zero the mount is destroyed. Clearing a level pays
a bonus and gives you seven seconds to rearm. Best level and best score are
saved between sessions.

Rounds are 20 mm at 900 m/s with gravity, fired at 4500 rpm through a slight
random spread that slowly drifts. At 1500 m the round takes about 1.7 s to
arrive, so you lead targets a long way.

Heat is shown as brightness and distance fades things with real fog, so a far
contact is only its engine glow and turns into a recognisable shape as it gets
close. That's on purpose: picking out what you're looking at is part of the
challenge.

## Enemies

All of them live in one table, `scripts/EnemyDB.gd`.

| id | Shows as | Notes |
|---|---|---|
| `drone` | UAV / SMALL | cheap, weaves |
| `jet` | FAST JET | 240 m/s strafing runs |
| `helo` | ROTARY WING | hangs back and slides sideways |
| `missile` | SEA-SKIMMER | 310 m/s at 12 to 30 m, the real danger |
| `heavy_jet` | HEAVY / MULTI-ENGINE | four engine pods are weak points |
| `dropship` | DROPSHIP | tilt rotor, nacelles are weak points |
| `gunship` | ASSAULT GUNSHIP | armoured, launches drones |
| `orb` | UNKNOWN / NON-BALLISTIC | very agile |
| `mothership` | MOTHERSHIP / SKY CARRIER | 360 m airship, launches drones and jets |
| `leviathan` | CAPITAL / LEVIATHAN | 150 m warship, launches jets; aim for the stern |
| `dreadnought` | ORBITAL / DREADNOUGHT | 2 km warship, warps in, launches everything; falls when killed |

## Adding an enemy

Add one entry to `EnemyDB.TYPES`:

```gdscript
"interceptor": {
    "display": "INTERCEPTOR",
    "mesh": "jet", "scale": 0.8,
    "hp": 40.0, "radius": 4.5, "speed": 330.0,
    "alt": [200.0, 500.0], "dist": [1800.0, 2400.0],
    "behavior": "strafe", "agility": 0.9,
    "threat": 16.0, "score": 350, "cost": 3.0, "min_wave": 7,
},
```

The wave director, radar, HUD and scoring all read this table, so that's the
whole job. Optional fields:

- `weak_points`: spots on the model that take extra damage
- `hit_volumes`: a proper hitbox made of spheres, for anything big
- `boss`: gets the integrity bar, a warning banner and a staged death
- `carrier`: launches smaller craft, optionally several at once from set bay
  positions
- `flares`: decoys missiles. Fully working, but no enemy uses it yet
- `warp`: arrives out of warp instead of flying in
- `wreck`: falls into the sea when killed instead of vanishing

For a new look, add a builder to `MeshFactory.build()` and point `mesh` at it.
Build it facing -Z and set brightness with the `COLD`, `WARM`, `HOT` and
`EXHAUST` values. Anything above 1.0 glows.

Movement types: `beeline`, `weave`, `strafe`, `terminal`, `hover`, `capital`,
`station`. New ones go in `Enemy._desired_velocity()`.

## Project layout

```
scenes/Main.tscn          node skeleton; everything else is built in code
scripts/Game.gd           world setup, levels and waves, score, input, title
scripts/Turret.gd         mount, gun, ammo, missiles, salvo, shake, audio
scripts/BulletManager.gd  every round in flight, drawn as one batch
scripts/MissileManager.gd every missile and its trail
scripts/Enemy.gd          one contact: movement, damage, hitbox, launches
scripts/EnemyDB.gd        the enemy table
scripts/MeshFactory.gd    every model, built from primitives
scripts/FXManager.gd      sparks and explosions
scripts/HUD.gd            the overlay, drawn at full resolution
scripts/Controls.gd       sets up the input bindings
shaders/thermal.gdshader  the sensor look
shaders/sea.gdshader      the sea
tools/make_audio.py       regenerates the sound files
```

Worth knowing before changing things:

- The 3D world is rendered at a quarter of the window resolution and then
  scaled up, and the thermal shader runs on that. The HUD is drawn separately
  at full resolution, which is why it stays sharp.
- `Environment.glow_bloom` has to stay at 0. Anything else turns the black sky
  grey.
- All input is handled in `Game._unhandled_input()`. The turret sits inside the
  low resolution viewport and never receives input on its own, so mouse
  movement is passed to it by hand. New controls go in `Game`.

## Tuning

| What | Where |
|---|---|
| Pixel size | `Game._pixel_scale` |
| Grey levels, noise, scanlines | `shaders/thermal.gdshader` |
| Fire rate, magazine, spread, muzzle velocity | top of `Turret.gd` |
| Damage per round | `BulletManager.damage` |
| Lock time, lock cone, missile cells | `Turret.gd`, missiles section |
| Salvo size and charge rate | `Turret.gd`, salvo section |
| Missile speed, turning, warhead | top of `MissileManager.gd` |
| Screen shake | `SHAKE_TO_OFFSET` in `Turret.gd` |
| Scripted levels | `Game._authored_wave()` |
| How fast waves grow after level 3 | `Game.BASE_BUDGET`, `BUDGET_PER_WAVE` |
| Mothership HP, launches, weak points | `"mothership"` in `EnemyDB.gd` |
| Dreadnought HP, size, launches, weak points | `"dreadnought"` in `EnemyDB.gd` |
| Warp timing | `WARP_CHARGE`, `WARP_BRAKE` in `Enemy.gd` |

## Debug switches

Set these as environment variables before launching:

- `CIWS_DEMO=1`: the game plays itself. Good for checking balance or recording.
- `CIWS_START_WAVE=3`: start at a given level. 3 goes straight to the
  mothership, 4 to the dreadnought.
- `CIWS_RAW=1`: turns off the thermal shader so you can see the plain 3D scene.

## Sound

```
python3 tools/make_audio.py      # needs numpy
```

The gun loop is an exact whole number of shots long so it loops without a seam.

## What's next

See `ROADMAP.md`.
