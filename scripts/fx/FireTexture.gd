extends Node
class_name FireTexture

const HEAT_PARAMETER := &"fire_heat"

@export var material: ShaderMaterial
@export var wind: WindField
@export var grid_size := Vector2i(96, 100)
@export_range(0.0, 1.0) var cooling: float = 0.7
@export var tick_rate: float = 27.0
@export var hot_spot_frequency: float = 1.4
@export_range(0.0, 1.0) var fuel_floor: float = 0.25
@export var flicker_speed: float = 1.1
@export var lean_per_wind_speed: float = 0.06
@export var gust_strength: float = 0.35
@export var gust_frequency: float = 0.35
@export_range(0.0, 1.0) var max_lean: float = 0.6

var _fire: DoomFire
var _fuel: FireFuel
var _gusts := FastNoiseLite.new()
var _image: Image
var _texture: ImageTexture
var _until_tick: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	_fire = DoomFire.new(grid_size.x, grid_size.y, cooling)
	_fuel = FireFuel.new(grid_size.x, hot_spot_frequency, fuel_floor, flicker_speed)
	_gusts.seed = randi()
	_gusts.frequency = gust_frequency
	_image = Image.create_from_data(
		grid_size.x, grid_size.y, false, Image.FORMAT_R8, _fire.cells
	)
	_texture = ImageTexture.create_from_image(_image)
	material.set_shader_parameter(HEAT_PARAMETER, _texture)


func _process(delta: float) -> void:
	_clock += delta
	_until_tick -= delta
	if _until_tick > 0.0:
		return
	var tick := 1.0 / tick_rate
	_until_tick = maxf(_until_tick + tick, 0.0)
	_fuel.advance(tick)
	_fire.feed(_fuel.row)
	_fire.step(_lean())
	_image.set_data(grid_size.x, grid_size.y, false, Image.FORMAT_R8, _fire.cells)
	_texture.update(_image)


func _lean() -> float:
	var gust := _gusts.get_noise_1d(_clock) * gust_strength
	var camera := get_viewport().get_camera_3d()
	if wind == null or camera == null:
		return clampf(gust, -max_lean, max_lean)
	var across := wind.velocity.dot(camera.global_basis.x)
	return clampf(across * lean_per_wind_speed + gust, -max_lean, max_lean)
