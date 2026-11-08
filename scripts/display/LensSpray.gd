extends Node
class_name LensSpray

const MAX_DROPLETS: int = 12
const UNIFORM := "droplets"
const GRAVITY: float = 0.6
const INERTIA: float = 0.5
const STICKING: float = 0.025
const MOBILITY: float = 8.0
const GRIP: float = 10.0
const WOBBLE: float = 0.6
const SCREEN := Rect2(-0.1, -0.1, 1.2, 1.2)

@export var thermal: ThermalView
@export var droplets_per_splash := Vector2(3.0, 10.0)
@export var droplet_radius := Vector2(0.025, 0.08)
@export var droplet_life := Vector2(2.5, 5.5)

var _droplets: Array[LensDroplet] = []
var _last_look := Vector2.INF

@onready var _thermal: ShaderMaterial = thermal.material as ShaderMaterial


func splash(strength: float) -> void:
	var count := roundi(lerpf(droplets_per_splash.x, droplets_per_splash.y, clampf(strength, 0.0, 1.0)))
	for index in count:
		add_droplet()


func add_droplet() -> void:
	_droplets.push_back(LensDroplet.new(
		Vector2(randf(), randf()),
		randf_range(droplet_radius.x, droplet_radius.y),
		randf_range(droplet_life.x, droplet_life.y)
	))
	while _droplets.size() > MAX_DROPLETS:
		_droplets.pop_front()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var push := _lens_push(delta)
	for droplet in _droplets:
		droplet.age += delta
		_slide(droplet, push, delta)
	_droplets = _droplets.filter(_on_lens)
	_upload()


func _lens_push(delta: float) -> Vector2:
	var forward := -thermal.turret.camera.global_basis.z
	var look := Vector2(atan2(-forward.x, -forward.z), asin(clampf(forward.y, -1.0, 1.0)))
	var turn := Vector2.ZERO
	if _last_look != Vector2.INF:
		turn = Vector2(wrapf(look.x - _last_look.x, -PI, PI), look.y - _last_look.y) / delta
	_last_look = look
	return Vector2(turn.x, turn.y) * INERTIA + Vector2.DOWN * GRAVITY * cos(look.y)


func _slide(droplet: LensDroplet, push: Vector2, delta: float) -> void:
	var drive := push * droplet.radius
	var terminal := Vector2.ZERO
	if drive.length() > STICKING:
		var along := drive.normalized()
		terminal = along * (drive.length() - STICKING) * MOBILITY
		terminal += along.orthogonal() * randfn(0.0, WOBBLE) * terminal.length()
	droplet.velocity = droplet.velocity.lerp(terminal, clampf(GRIP * delta, 0.0, 1.0))
	droplet.position += droplet.velocity * delta


func _on_lens(droplet: LensDroplet) -> bool:
	return droplet.strength > 0.0 and SCREEN.has_point(droplet.position)


func _upload() -> void:
	var packed := PackedVector4Array()
	packed.resize(MAX_DROPLETS)
	for index in _droplets.size():
		var droplet := _droplets[index]
		packed[index] = Vector4(droplet.position.x, droplet.position.y, droplet.radius, droplet.strength)
	_thermal.set_shader_parameter(UNIFORM, packed)
