extends Node
class_name LensSpray

const MAX_DROPLETS: int = 12
const UNIFORM := "droplets"

@export var thermal: ThermalView
@export var droplets_per_splash := Vector2(3.0, 10.0)
@export var droplet_radius := Vector2(0.025, 0.08)
@export var droplet_life := Vector2(2.5, 5.5)
@export var slide_speed: float = 0.25

var _droplets: Array[LensDroplet] = []

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
	for droplet in _droplets:
		droplet.age += delta
		droplet.position.y += slide_speed * droplet.radius * delta
	_droplets = _droplets.filter(func(droplet: LensDroplet) -> bool: return droplet.strength > 0.0)
	_upload()


func _upload() -> void:
	var packed := PackedVector4Array()
	packed.resize(MAX_DROPLETS)
	for index in _droplets.size():
		var droplet := _droplets[index]
		packed[index] = Vector4(droplet.position.x, droplet.position.y, droplet.radius, droplet.strength)
	_thermal.set_shader_parameter(UNIFORM, packed)
