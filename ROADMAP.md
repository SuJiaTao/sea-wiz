# Roadmap

What's planned but not built yet, roughly in the order it makes sense to do it,
with what already exists in the code to build each one on.

## Done since the last roadmap

- **Motherships.** A 360 m airship carrier is in as the Level 3 boss, dropping
  bursts of drones and jets from a belly bay.
- **Big ship hitboxes.** Large ships now have a hitbox built from several
  spheres instead of one giant one. This was the thing holding back everything
  big on this list.
- **Carrier bursts and bays.** Any enemy can now launch several craft at once
  from set points on its model.
- **Boss presentation.** Integrity bar, warning banner with bearing, fires that
  appear as it takes damage, and a chain of explosions down the hull on death.
- **The warp in.** The Level 4 dreadnought arrives as a growing point of heat,
  whites out the sensor and brakes in from warp. About 2 km long, so this is
  the Star Destroyer scale item too.
- **Wrecks.** Capital ships can fall into the sea instead of vanishing.

## 1. Flares

Aircraft that throw off your missiles. The logic already works: a missile asks
its target for a decoy once it gets within 520 m, and a fooled missile chases
the flare instead. Nothing uses it yet. To switch it on for an enemy:

```gdscript
"flares": {"count": 4, "interval": 2.5, "chance": 0.55},
```

Still to do: draw the flares themselves. They should be extremely bright in
thermal, which is the whole reason they work. Fast jets are the natural first
users, so the choice becomes "fire a missile that might get fooled, or wait
for gun range".

## 2. More aircraft, difficulty by size

Only `EnemyDB.gd` and a new model in `MeshFactory.gd`. Size already sets the
difficulty through HP, hitbox, speed and cost, and the wave director spends
cost from a budget, so bigger things naturally show up later and in smaller
numbers.

Good candidates: a fast fragile interceptor, a bomber that hangs back, and a
stealth type that barely shows up until its exhaust points at you. That last one
is cheap to make and is the most interesting thing this sensor allows.

## 3. Enemies that shoot back

Right now enemies only hurt you by reaching the ship.

- **Gun runs.** Dive in, fire, pull away. Needs a small enemy weapon with
  cooldown, burst length and accuracy, plus tracers coming at you.
- **Missile launches.** An aircraft fires a sea skimmer at you from range. The
  good version makes that missile a target in its own right, so the gun's job
  becomes shooting down the weapon, not just the launcher. Craft launching
  craft already works, so this is mostly wiring.
- **Suicide drones.** Ignore everything and dive at the mount. The cheapest of
  the three.

## 4. Ground targets and walking tanks

Tanks, and Metal Gear style walkers. Needs a coastline or beach to exist first
(right now there's only open sea), ground movement, and armour the 20 mm
struggles with so missiles become the answer. Walkers need jointed legs, which
the current model builder can do the same way the helicopter rotor spins. The
biggest item on the list.

## 5. Proper boss phases

The mothership, Leviathan and dreadnought are bosses without phases. Next step: weak points
that only open at certain stages, a scripted approach, and phase markers on the
integrity bar.

## 6. Bigger warp ships

The warp in works. Next ideas: a dreadnought that fires back (broadside guns
or missiles you have to shoot down), parts you can blow off it like the
radiator wings, and more than one of them at once in late waves.
