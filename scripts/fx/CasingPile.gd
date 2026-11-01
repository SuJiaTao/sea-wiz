extends MultiMeshInstance3D
class_name CasingPile

const NOW_PARAMETER := &"now"
const WORLD_BOUNDS := AABB(Vector3(-200, -50, -200), Vector3(400, 100, 400))
const LYING_DOWN := Basis(Vector3.RIGHT, PI * 0.5)
const HIDDEN := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)

@export var casing_mesh: Mesh
@export var casing_material: ShaderMaterial
@export var capacity: int = 3000
@export var max_flying: int = 160
@export var gravity: float = 9.81
@export var restitution: float = 0.3
@export var friction: float = 0.55
@export var settle_speed: float = 1.4
@export var spin_speed: float = 25.0
@export var platform_centre := Vector3(0.0, 9.94, 0.0)
@export var platform_radius: float = 8.6
@export var deck_height: float = 6.0
@export var deck_half_beam: float = 9.0
@export var pile_cell: float = 0.35
@export var layer_height: float = 0.01
@export var max_pile_height: float = 0.5
@export var drop_height: float = 0.0

var _flying: Array[FlyingCasing] = []
var _pile_heights: Dictionary[Vector2i, float] = {}
var _next_slot: int = 0
var _clock: float = 0.0


func _ready() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = casing_mesh
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = WORLD_BOUNDS


func eject(world_position: Vector3, world_velocity: Vector3) -> void:
	if _flying.size() >= max_flying:
		return
	var casing := FlyingCasing.new(
		_next_slot,
		to_local(world_position),
		global_basis.inverse() * world_velocity,
		ParticleBatch.random_direction() * spin_speed
	)
	_next_slot = (_next_slot + 1) % capacity
	multimesh.visible_instance_count = mini(multimesh.visible_instance_count + 1, capacity)
	multimesh.set_instance_custom_data(casing.slot, Color(_clock, 0.0, 0.0, 0.0))
	_flying.append(casing)


func _process(delta: float) -> void:
	_clock += delta
	casing_material.set_shader_parameter(NOW_PARAMETER, _clock)
	var still_flying: Array[FlyingCasing] = []
	for casing in _flying:
		casing.fly(delta, gravity)
		if _bounce(casing):
			still_flying.append(casing)
		multimesh.set_instance_transform(casing.slot, Transform3D(casing.orientation, casing.position))
	_flying = still_flying


func _bounce(casing: FlyingCasing) -> bool:
	var floor_level := _floor_under(casing.position)
	if is_nan(floor_level):
		if casing.position.y > drop_height:
			return true
		casing.orientation = HIDDEN
		return false
	if casing.position.y > floor_level:
		return true
	casing.position.y = floor_level
	casing.velocity.y = -casing.velocity.y * restitution
	casing.velocity.x *= friction
	casing.velocity.z *= friction
	if casing.velocity.length() > settle_speed:
		return true
	_settle(casing, floor_level)
	return false


func _settle(casing: FlyingCasing, floor_level: float) -> void:
	casing.orientation = Basis(Vector3.UP, randf() * TAU) * LYING_DOWN
	casing.position.y = floor_level + layer_height
	var cell := _cell(casing.position)
	_pile_heights[cell] = minf(_pile_heights.get(cell, 0.0) + layer_height, max_pile_height)


func _floor_under(local_position: Vector3) -> float:
	var pile: float = _pile_heights.get(_cell(local_position), 0.0)
	var from_centre := Vector2(
		local_position.x - platform_centre.x, local_position.z - platform_centre.z
	)
	if from_centre.length() < platform_radius:
		return platform_centre.y + pile
	if absf(local_position.x) < deck_half_beam:
		return deck_height + pile
	return NAN


func _cell(local_position: Vector3) -> Vector2i:
	return Vector2i(floori(local_position.x / pile_cell), floori(local_position.z / pile_cell))
