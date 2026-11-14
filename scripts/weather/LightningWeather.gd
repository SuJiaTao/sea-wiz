extends AbstractWeatherEffect
class_name LightningWeather

const SOUND_SPEED: float = 343.0
const SKY_FLASH := "lightning_flash"
const SKY_DIRECTION := "lightning_direction"
const MIN_STRENGTH: float = 0.3
const NEAR_PITCH: float = 1.0
const FAR_PITCH: float = 0.72

@export var bolt: LightningBolt
@export var environment: WorldEnvironment
@export var sea_material: ShaderMaterial
@export var thermal: ThermalView
@export var thunder: AudioStreamPlayer
@export var light: DirectionalLight3D
@export var light_energy: float = 2.0
@export var distance := Vector2(1500.0, 5000.0)
@export var cloud_base := Vector2(600.0, 1000.0)
@export var flash_peak: float = 1.2
@export var flash_decay: float = 4.0
@export var sensor_glare: float = 0.9

var _until_strike: float = 0.0
var _flash: float = 0.0


func _apply(profile: WeatherProfile, strength: float, delta: float) -> void:
	_flash = maxf(_flash - flash_decay * delta, 0.0)
	_set_flash(_flash)
	if profile.lightning_interval.y <= 0.0 or strength < MIN_STRENGTH:
		return
	_until_strike -= delta
	if _until_strike > 0.0:
		return
	_until_strike = randf_range(profile.lightning_interval.x, profile.lightning_interval.y) / strength
	_strike()


func _strike() -> void:
	var bearing := randf() * TAU
	var range_m := randf_range(distance.x, distance.y)
	var ground := Vector3(sin(bearing), 0.0, -cos(bearing)) * range_m
	var top := ground + Vector3.UP * randf_range(cloud_base.x, cloud_base.y)
	bolt.strike(top, ground)
	var nearness := 1.0 - inverse_lerp(distance.x, distance.y, range_m)
	_flash = flash_peak * lerpf(0.4, 1.0, nearness)
	_sky().set_shader_parameter(SKY_DIRECTION, (top + ground) * 0.5)
	light.basis = Basis.looking_at(-((top + ground) * 0.5).normalized(), Vector3.UP)
	thermal.heat_burst(sensor_glare * nearness)
	get_tree().create_timer(range_m / SOUND_SPEED, false).timeout.connect(_rumble.bind(range_m))


# Thunder from farther away arrives later, quieter by the inverse square law,
# and lower, because the air soaks up the sharp crack and leaves the rumble.
func _rumble(range_m: float) -> void:
	var clap := thunder.duplicate() as AudioStreamPlayer
	clap.volume_db = thunder.volume_db + linear_to_db(distance.x / range_m)
	clap.pitch_scale = lerpf(NEAR_PITCH, FAR_PITCH, inverse_lerp(distance.x, distance.y, range_m))
	clap.finished.connect(clap.queue_free)
	add_child(clap)
	clap.play()


func _set_flash(value: float) -> void:
	light.light_energy = value * light_energy
	light.visible = value > 0.0
	_sky().set_shader_parameter(SKY_FLASH, value)
	sea_material.set_shader_parameter(SKY_FLASH, value)


func _sky() -> ShaderMaterial:
	return environment.environment.sky.sky_material as ShaderMaterial
