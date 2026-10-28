extends Node
class_name SearchRadar

signal detected(detection: RadarDetection)

const DETECTION_FALLOFF_POWER := 4.0
const REFERENCE_SIZE := 6.0
const MIN_SIZE_FACTOR := 0.45
const SIZE_ERROR := 0.15

@export var enemies: EnemyManager
@export var antenna: Node3D
@export var sweep_period: float = 1.0
@export var max_range: float = 4000.0
@export_range(0.0, 1.0) var detection_chance: float = 0.92
@export var range_error: float = 4.0
@export var range_error_per_km: float = 6.0
@export var angle_error_deg: float = 0.5

var sweep_angle: float = 0.0


func _physics_process(delta: float) -> void:
	var previous := sweep_angle
	sweep_angle = fposmod(sweep_angle + TAU * delta / sweep_period, TAU)
	for enemy in enemies.live_enemies():
		var offset := enemy.global_position - antenna.global_position
		var distance := offset.length()
		if distance > max_range or distance < 1.0:
			continue
		if not _swept(previous, sweep_angle, _bearing(offset)):
			continue
		if randf() > _chance(distance, enemy.hud_radius):
			continue
		detected.emit(_measure(offset, distance, enemy.hud_radius))


func _bearing(offset: Vector3) -> float:
	return fposmod(atan2(offset.x, -offset.z), TAU)


func _swept(from: float, to: float, bearing: float) -> bool:
	if to >= from:
		return bearing >= from and bearing < to
	return bearing >= from or bearing < to


func _chance(distance: float, size: float) -> float:
	var reach := 1.0 - pow(distance / max_range, DETECTION_FALLOFF_POWER)
	var size_factor := clampf(size / REFERENCE_SIZE, MIN_SIZE_FACTOR, 1.0)
	return detection_chance * reach * size_factor


func _measure(offset: Vector3, distance: float, size: float) -> RadarDetection:
	var sigma_angle := deg_to_rad(angle_error_deg)
	var sigma_range := range_error + range_error_per_km * distance * 0.001
	var direction := offset / distance
	var right := direction.cross(Vector3.UP).normalized()
	var up := right.cross(direction).normalized()
	direction = (
		direction
		+ right * randfn(0.0, sigma_angle)
		+ up * randfn(0.0, sigma_angle)
	).normalized()
	var measured_range := distance + randfn(0.0, sigma_range)
	return RadarDetection.new(
		antenna.global_position + direction * measured_range,
		sigma_range + distance * sigma_angle,
		size * (1.0 + randfn(0.0, SIZE_ERROR))
	)
