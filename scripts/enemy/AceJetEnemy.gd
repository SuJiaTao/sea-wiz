extends JetEnemy
class_name AceJetEnemy

# A rare, very good pilot. He flies the same jet within the same limits as
# everyone else, but flies it well:
#  - he hangs back and works round the ship until the gunner is looking the
#    other way, then runs in from there;
#  - each pass is either a close-range missile shot or a gun run, turn about,
#    so while you deal with his missile he is coming round for the next pass;
#  - inside our gun's reach he never holds a straight line, and the moment
#    the gun swings onto him and fires he breaks across the stream;
#  - he answers a missile early with long strings of flares, and if he is
#    pointing the right way he simply shoots it down, even one just off our
#    deck or one chasing his own missile.

## Inside this range of the ship he weaves the whole time.
@export var weave_range: float = 2200.0
@export var weave_strength: float = 0.55
## A break out of the gun stream lasts this long.
@export var gun_break_time: float = 1.6
## The gun swinging within this many degrees of him while firing makes him break.
@export var dodge_cone_deg: float = 5.0
## Holds off at this distance while the gunner is looking his way.
@export var stalk_radius: float = 2000.0
## He only runs in once he is this far off the gunner's line of sight...
@export var unseen_deg: float = 75.0
## ...unless he has been stalking this long and decides to go anyway.
@export var stalk_patience: float = 12.0
## Shooting down our missiles: how far, how far off his nose, how often.
@export var missile_gun_range: float = 1500.0
@export var missile_gun_cone_deg: float = 20.0
@export var missile_gun_cooldown: float = 1.2
@export_range(0.0, 1.0) var missile_kill_chance: float = 0.7

var _last_pass_missile: bool = false
var _stalking: float = 0.0
var _gun_ready_in: float = 0.0


func _on_flight_step(delta: float) -> void:
	super(delta)
	var offset := global_position - target_position
	var flat_range := Vector2(offset.x, offset.z).length()
	jink_strength = weave_strength if flat_range < weave_range else 0.0
	_dodge_gun(flat_range)
	_gun_ready_in = maxf(_gun_ready_in - delta, 0.0)
	_shoot_missiles()


func _desired_velocity(delta: float) -> Vector3:
	if _leg == Leg.RUN_IN and not BlindArc.contains(global_position):
		var from_ship := global_position - target_position
		var flat_range := Vector2(from_ship.x, from_ship.z).length()
		if flat_range > launch_range and GunnerView.off_aim_deg(global_position) < unseen_deg and _stalking < stalk_patience:
			_stalking += delta
			return _hold_altitude(_stalk_direction(from_ship, flat_range)) * speed
	return super(delta)


## Round the ship, away from where the gunner is looking, holding off.
func _stalk_direction(from_ship: Vector3, flat_range: float) -> Vector3:
	var out := _flat(from_ship)
	var around := Vector3.UP.cross(out) * GunnerView.away_side(global_position)
	var settle := clampf((stalk_radius - flat_range) / stalk_radius, -0.5, 0.5)
	return around + out * settle + Vector3.UP * (attack_altitude - global_position.y + target_position.y) * 0.002


func _wants_missile() -> bool:
	return missiles_carried > 0 and not _last_pass_missile


func _launch_missile() -> void:
	_last_pass_missile = true
	_stalking = 0.0
	super()


func _strafe() -> void:
	_last_pass_missile = false
	_stalking = 0.0
	super()


func _dodge_gun(flat_range: float) -> void:
	if _break_remaining > 0.0 or not GunnerView.shooting or flat_range > weave_range:
		return
	if GunnerView.off_aim_deg(global_position) <= dodge_cone_deg:
		_break_remaining = gun_break_time
		_break_from = target_position


func _on_damage(amount: float, world_point: Vector3) -> void:
	super(amount, world_point)
	if _break_remaining > 0.0:
		return
	# The rounds come from the ship: turn across the line of fire, not along it.
	_break_remaining = gun_break_time
	_break_from = target_position


func _shoot_missiles() -> void:
	if _gun_ready_in > 0.0 or contact_damage <= 0.0 or BlindArc.contains(global_position):
		return
	var nose := velocity.normalized()
	var best: MissileProjectile
	var best_distance := missile_gun_range
	for missile in MissileProjectile.in_flight:
		if not missile.is_flying():
			continue
		var offset := missile.position - global_position
		var distance := offset.length()
		if distance >= best_distance or rad_to_deg(nose.angle_to(offset)) > missile_gun_cone_deg:
			continue
		best = missile
		best_distance = distance
	if best == null:
		return
	_gun_ready_in = missile_gun_cooldown
	var flight := best_distance / GunBurst.ROUND_SPEED
	var burst := GunBurst.new()
	burst.shooter = self
	burst.target = best.position + best.velocity * flight
	get_parent().add_child(burst)
	if randf() < missile_kill_chance:
		get_tree().create_timer(flight, false).timeout.connect(best.shoot_down)
