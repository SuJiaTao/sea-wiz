extends AbstractEffect
class_name FlareEffect

const SMOKE_PER_SECOND: float = 18.0
const SMOKE_DRIFT: float = 1.0
## Each frame a flare's glow is redrawn at a random size and only briefly,
## so it sputters and flickers the way burning magnesium does.
const FLICKER_SIZE := Vector2(0.6, 1.5)
const FLICKER_LIFE := Vector2(0.3, 0.6)

var _flares: Array[DecoyFlare]


func _init(flares: Array[DecoyFlare]) -> void:
	_flares = flares


func _on_spawn(_effects: EffectManager) -> void:
	pass


func _on_step(effects: EffectManager, delta: float) -> void:
	var lit := 0
	for flare in _flares:
		flare.advance(delta)
		if not flare.burning:
			continue
		lit += 1
		var at := flare.position
		effects.flares.emit(
			at, Vector3.ZERO,
			randf_range(FLICKER_SIZE.x, FLICKER_SIZE.y), randf_range(FLICKER_LIFE.x, FLICKER_LIFE.y)
		)
		if randf() < SMOKE_PER_SECOND * delta:
			effects.flare_smoke.emit(at, ParticleBatch.random_direction() * SMOKE_DRIFT)
	if lit == 0:
		finish()
