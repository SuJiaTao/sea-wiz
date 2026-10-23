extends Node
class_name FireTexture

const HEAT_PARAMETER := &"fire_heat"

@export var material: ShaderMaterial
@export var wind: WindField
@export var grid_size := Vector2i(64, 56)
@export var tick_rate: float = 27.0
@export var lean_per_wind_speed: float = 0.06
@export_range(0.0, 1.0) var max_lean: float = 0.5

var _fire: DoomFire
var _image: Image
var _texture: ImageTexture
var _until_tick: float = 0.0


func _ready() -> void:
	_fire = DoomFire.new(grid_size.x, grid_size.y)
	_image = Image.create_from_data(
		grid_size.x, grid_size.y, false, Image.FORMAT_R8, _fire.cells
	)
	_texture = ImageTexture.create_from_image(_image)
	material.set_shader_parameter(HEAT_PARAMETER, _texture)


func _process(delta: float) -> void:
	_until_tick -= delta
	if _until_tick > 0.0:
		return
	_until_tick = maxf(_until_tick + 1.0 / tick_rate, 0.0)
	_fire.step(_lean())
	_image.set_data(grid_size.x, grid_size.y, false, Image.FORMAT_R8, _fire.cells)
	_texture.update(_image)


func _lean() -> float:
	var camera := get_viewport().get_camera_3d()
	if wind == null or camera == null:
		return 0.0
	var across := wind.velocity.dot(camera.global_basis.x)
	return clampf(across * lean_per_wind_speed, -max_lean, max_lean)
