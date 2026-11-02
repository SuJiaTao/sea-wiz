extends Node
class_name ShockwaveLens

const MAX_RINGS: int = 4
const UNIFORM := "shock_rings"

@export var thermal: ThermalView
@export var turret: Turret
@export var effects: EffectManager
@export var ring_speed: float = 420.0
@export var ring_life: float = 1.3
@export var strength_per_size: float = 0.01

var _rings: Array[ShockRing] = []

@onready var _thermal: ShaderMaterial = thermal.material as ShaderMaterial


func _ready() -> void:
	effects.shockwave.connect(_on_shockwave)


func _on_shockwave(at: Vector3, size: float) -> void:
	_rings.push_back(ShockRing.new(at, size))
	while _rings.size() > MAX_RINGS:
		_rings.pop_front()


func _process(delta: float) -> void:
	for ring in _rings:
		ring.age += delta
	_rings = _rings.filter(func(ring: ShockRing) -> bool: return ring.age < ring_life)
	var packed := PackedVector4Array()
	packed.resize(MAX_RINGS)
	for index in _rings.size():
		packed[index] = _screen_ring(_rings[index])
	_thermal.set_shader_parameter(UNIFORM, packed)


func _screen_ring(ring: ShockRing) -> Vector4:
	var camera := turret.camera
	if camera.is_position_behind(ring.origin):
		return Vector4.ZERO
	var screen := Vector2(camera.get_viewport().get_visible_rect().size)
	var centre := camera.unproject_position(ring.origin)
	var edge := camera.unproject_position(ring.origin + camera.global_basis.y * ring_speed * ring.age)
	var strength := ring.size * strength_per_size * (1.0 - ring.age / ring_life)
	return Vector4(centre.x / screen.x, centre.y / screen.y, centre.distance_to(edge) / screen.y, strength)
