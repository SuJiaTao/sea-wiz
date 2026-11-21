extends Node
class_name DamagedJetSmoke

# Jets that have been hit show it: below half strength an engine trails
# smoke, thicker the worse the damage, and below a quarter it is burning,
# throwing flame and sparks into the smoke.

const SMOKING_BELOW: float = 0.5
const BURNING_BELOW: float = 0.25
const SMOKE_PER_SECOND: float = 30.0
const SMOKE_SIZE := Vector2(0.6, 1.6)
const SMOKE_LIFE: float = 1.6
## Puffs are left a little behind the jet, so the trail streams off its tail.
const TAIL_OFFSET: float = 6.0
const FLAME_PER_SECOND: float = 12.0
const FLAME_SIZE: float = 0.5
const EMBERS_PER_SECOND: float = 10.0
const EMBER_SPEED: float = 4.0
const FLAME_DRAG: float = 0.1

@export var enemies: EnemyManager
@export var effects: EffectManager


func _process(delta: float) -> void:
	for enemy in enemies.live_enemies():
		var jet := enemy as FlyingEnemy
		if jet == null or not jet.jet_engine or jet.max_hp <= 0.0:
			continue
		var health := jet.hp / jet.max_hp
		if health >= SMOKING_BELOW:
			continue
		var damage := 1.0 - health / SMOKING_BELOW
		var tail := jet.global_position - jet.velocity.normalized() * TAIL_OFFSET
		for puff in _due(SMOKE_PER_SECOND * damage, delta):
			effects.smoke.emit(tail, Vector3.ZERO, lerpf(SMOKE_SIZE.x, SMOKE_SIZE.y, damage), SMOKE_LIFE)
		if health >= BURNING_BELOW:
			continue
		for flame in _due(FLAME_PER_SECOND, delta):
			effects.fireballs.emit(tail, jet.velocity * FLAME_DRAG, FLAME_SIZE)
		for ember in _due(EMBERS_PER_SECOND, delta):
			effects.embers.emit(tail, ParticleBatch.random_direction() * EMBER_SPEED)


## How many to emit this frame for a rate, carrying fractions by chance.
func _due(per_second: float, delta: float) -> int:
	var owed := per_second * delta
	return int(owed) + (1 if randf() < owed - floorf(owed) else 0)
