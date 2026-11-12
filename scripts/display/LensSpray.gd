extends Node
class_name LensSpray

const MAX_DROPLETS: int = 12
const UNIFORM := "droplets"
const SHAPE_UNIFORM := "droplet_shapes"
const FALL_SPEED: float = 0.03
const SLOWEST_FALL: float = 0.008
const REFERENCE_RADIUS: float = 0.02
const TURN_SLIP: float = 0.12
const GRIP: float = 10.0
const SCREEN := Rect2(-0.1, -0.1, 1.2, 1.2)
const FULL_STRENGTH: float = 1.0

@export var thermal: ThermalView
@export var droplets_per_splash := Vector2(3.0, 10.0)
@export var droplet_radius := Vector2(0.012, 0.03)

var _droplets: Array[LensDroplet] = []
var _last_look := Vector2.INF

@onready var _thermal: ShaderMaterial = thermal.material as ShaderMaterial


func splash(strength: float) -> void:
	var count := roundi(lerpf(droplets_per_splash.x, droplets_per_splash.y, clampf(strength, 0.0, 1.0)))
	for index in count:
		add_droplet()


func add_droplet() -> void:
	if _droplets.size() >= MAX_DROPLETS:
		return
	_droplets.push_back(LensDroplet.new(
		Vector2(randf(), randf()),
		randf_range(droplet_radius.x, droplet_radius.y)
	))


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var turn := _camera_turn(delta)
	for droplet in _droplets:
		droplet.age += delta
		_slide(droplet, turn, delta)
	_droplets = _droplets.filter(_on_lens)
	_upload()


func _camera_turn(delta: float) -> Vector2:
	var forward := -thermal.turret.camera.global_basis.z
	var look := Vector2(atan2(-forward.x, -forward.z), asin(clampf(forward.y, -1.0, 1.0)))
	var turn := Vector2.ZERO
	if _last_look != Vector2.INF:
		turn = Vector2(wrapf(look.x - _last_look.x, -PI, PI), look.y - _last_look.y) / delta
	_last_look = look
	return turn


func _slide(droplet: LensDroplet, turn: Vector2, delta: float) -> void:
	var fall := FALL_SPEED * droplet.radius / REFERENCE_RADIUS
	var wanted := Vector2(turn.x * TURN_SLIP, maxf(fall + turn.y * TURN_SLIP, SLOWEST_FALL))
	droplet.velocity = droplet.velocity.lerp(wanted, clampf(GRIP * delta, 0.0, 1.0))
	droplet.move(delta)


func _on_lens(droplet: LensDroplet) -> bool:
	return SCREEN.has_point(droplet.position)


func _upload() -> void:
	var packed := PackedVector4Array()
	var shapes := PackedVector4Array()
	packed.resize(MAX_DROPLETS)
	shapes.resize(MAX_DROPLETS)
	for index in _droplets.size():
		var droplet := _droplets[index]
		packed[index] = Vector4(droplet.position.x, droplet.position.y, droplet.radius, FULL_STRENGTH)
		shapes[index] = droplet.shape()
	_thermal.set_shader_parameter(UNIFORM, packed)
	_thermal.set_shader_parameter(SHAPE_UNIFORM, shapes)
