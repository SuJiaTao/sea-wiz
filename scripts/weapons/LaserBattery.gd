extends AbstractDeckWeapon
class_name LaserBattery

# The two laser balls beside the missile launcher. Both follow the CIWS lock;
# a shot burns for a moment from the glass window of each ball that can bear
# on the jet, burning it down while the window glows.

signal fired()

const BURN_TIME: float = 1.6
const COOLDOWN: float = 7.0
const DAMAGE_PER_SECOND: float = 420.0
const DEFAULT_RANGE: float = 1500.0
const MAX_RANGE: float = 3000.0
const LENS := Vector3(0.0, 0.0, -0.58)
const LENS_SUFFIX := "BallGeo_Lens_Glass"
const GLOW_PEAK: float = 8.0
const GLOW_FADE_PER_SECOND: float = 10.0
const BEAM_WIDTH: float = 0.1
const BEAM_HEAT := Color(3.0, 2.9, 2.6)
const FLASH_RANGE: float = 9.0
const FLASH_ENERGY: float = 3.0

@export var fire_control: FireControl
@export var damage_source: DamageSource
@export var emitters: Array[DeckGunTurret] = []

var cooldown_left: float = 0.0

var _burn_left: float = 0.0
var _beams: Array[MeshInstance3D] = []
var _flashes: Array[OmniLight3D] = []
var _lenses: Array[MeshInstance3D] = []
var _glow: Array[float] = []


func _ready() -> void:
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3.ONE
	var beam_paint := StandardMaterial3D.new()
	beam_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_paint.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_paint.albedo_color = BEAM_HEAT
	beam_mesh.material = beam_paint
	for emitter in emitters:
		var beam := MeshInstance3D.new()
		beam.mesh = beam_mesh
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.top_level = true
		beam.visible = false
		add_child(beam)
		_beams.append(beam)
		var flash := OmniLight3D.new()
		flash.omni_range = FLASH_RANGE
		flash.light_energy = 0.0
		flash.top_level = true
		add_child(flash)
		_flashes.append(flash)
		var ship := emitter.get_parent()
		_lenses.append(ship.find_child(emitter.node_prefix + LENS_SUFFIX, true, false) as MeshInstance3D)
		_glow.append(0.0)


func _trigger() -> void:
	if not _enabled or cooldown_left > 0.0:
		return
	cooldown_left = COOLDOWN
	_burn_left = BURN_TIME
	fired.emit()


func restock() -> void:
	cooldown_left = 0.0


func readiness() -> float:
	return 1.0 - cooldown_left / COOLDOWN


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	_burn_left = maxf(_burn_left - delta, 0.0)
	var target := fire_control.locked if fire_control.is_locked() else null
	on_target = false
	for index in emitters.size():
		var emitter := emitters[index]
		if not _enabled:
			emitter.park()
		elif target != null:
			emitter.aim_at(target.global_position)
		else:
			emitter.aim_at(fire_control.sight_point(DEFAULT_RANGE))
		var bears := target != null and _bears(emitter, target)
		on_target = on_target or bears
		var burning := _burn_left > 0.0 and bears
		if burning:
			target.take_damage(DAMAGE_PER_SECOND * delta, target.global_position, damage_source)
			_glow[index] = GLOW_PEAK
		else:
			_glow[index] = maxf(_glow[index] - GLOW_FADE_PER_SECOND * delta, 0.0)
		_show(index, burning, target)


func _bears(emitter: DeckGunTurret, target: AbstractEnemy) -> bool:
	var lens := emitter.barrel_point(LENS)
	return emitter.is_on_target() and lens.distance_to(target.global_position) <= MAX_RANGE


func _show(index: int, burning: bool, target: AbstractEnemy) -> void:
	var lens := emitters[index].barrel_point(LENS)
	var beam := _beams[index]
	beam.visible = burning
	if burning:
		var span := target.global_position - lens
		var forward := span.normalized()
		var side := forward.cross(Vector3.UP).normalized()
		var up := side.cross(forward)
		beam.global_transform = Transform3D(
			Basis(side * BEAM_WIDTH, up * BEAM_WIDTH, -forward * span.length()),
			lens + span * 0.5
		)
	var flash := _flashes[index]
	flash.global_position = lens
	flash.light_energy = FLASH_ENERGY * _glow[index] / GLOW_PEAK
	if _lenses[index] != null:
		_lenses[index].set_instance_shader_parameter("glow", _glow[index])
