extends Node3D
class_name GunBurst

# A strafing jet's cannon burst: a short stream of glowing rounds from the
# jet's nose to the ship. The damage is dealt by the jet; this is the visual,
# and it reports each round as it strikes.

const ROUNDS: int = 18
const ROUND_GAP: float = 0.035
const ROUND_SPEED: float = 900.0
const TRACER_LENGTH: float = 14.0
const TRACER_WIDTH: float = 0.25
const SCATTER: float = 0.012
const TRACER_HEAT := Color(3.0, 3.0, 2.6, 1.0)

signal round_landed(at: Vector3)

var shooter: Node3D
var target := Vector3.ZERO

var _fired: int = 0
var _clock: float = 0.0
var _rounds: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _lives: Array[float] = []
var _mesh := BoxMesh.new()


func _ready() -> void:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = TRACER_HEAT
	_mesh.material = glow
	_mesh.size = Vector3(TRACER_WIDTH, TRACER_WIDTH, TRACER_LENGTH)


func _process(delta: float) -> void:
	_clock += delta
	while _fired < ROUNDS and _clock >= ROUND_GAP * _fired and is_instance_valid(shooter):
		_fire(shooter.global_position)
	for index in range(_rounds.size() - 1, -1, -1):
		_lives[index] -= delta
		if _lives[index] <= 0.0:
			round_landed.emit(_rounds[index].global_position)
			_rounds[index].queue_free()
			_rounds.remove_at(index)
			_velocities.remove_at(index)
			_lives.remove_at(index)
			continue
		_rounds[index].global_position += _velocities[index] * delta
	if _rounds.is_empty() and (_fired >= ROUNDS or not is_instance_valid(shooter)):
		queue_free()


func _fire(origin: Vector3) -> void:
	_fired += 1
	var aim := (target - origin).normalized()
	aim = (aim + Vector3(randfn(0.0, SCATTER), randfn(0.0, SCATTER), randfn(0.0, SCATTER))).normalized()
	var round := MeshInstance3D.new()
	round.mesh = _mesh
	round.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(round)
	round.global_position = origin
	round.look_at(origin + aim, Vector3.UP if absf(aim.y) < 0.99 else Vector3.RIGHT)
	_rounds.append(round)
	_velocities.append(aim * ROUND_SPEED)
	_lives.append(origin.distance_to(target) / ROUND_SPEED)
