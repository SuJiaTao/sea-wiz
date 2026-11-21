extends JetEnemy
class_name AceJetEnemy

# A rare, very good pilot. He flies the same jet within the same limits as
# everyone else, but flies it well.
#
# He opens with a statement: a flat-out pass low over the deck with two
# wingmen, no shots fired, and a rock of the wings as he goes. Then he hunts:
#  - he hangs back and works round the ship until the gunner is looking the
#    other way, and he remembers where he got caught before and stays clear
#    of it, so it feels like he is reading you;
#  - some passes he climbs high and comes straight down on you from above;
#  - as he commits he sometimes jams our radar, blanking the scope;
#  - passes alternate between a close missile shot and a gun run, so while
#    you deal with his missile he is coming round for the next pass;
#  - inside our gun's reach he never holds a straight line, and the moment
#    the gun swings onto him and fires he breaks across the stream;
#  - he answers a missile with flares or, pointing the right way, shoots it
#    down, and rocks his wings when one fails to get him.
# Badly hurt, he picks one way to finish: usually all in, ripple-firing his
# last missiles and making reckless gun runs; sometimes he breaks off and
# gets away, to come back later still carrying the damage; and very rarely
# he aims the jet at the ship and ejects.

signal jamming(seconds: float)
signal ejected(at: Vector3, carried: Vector3)

enum Mood { ENTRANCE, HUNTING, ALL_IN, BUGGING_OUT, KAMIKAZE }

const ROCK_DEG: float = 35.0
const ROCK_RATE: float = 9.0
const CLIMB_PULL: float = 0.002
const MEMORY_SIZE: int = 3
## A top attack dives once he is this many attack altitudes up.
const DIVE_FROM_ALTITUDES: float = 2.0
## The kamikaze run aims this share of the entrance height above the deck.
const KAMIKAZE_AIM_SHARE: float = 0.2
## He jams as he commits, within this share past his stalking radius.
const JAM_REACH: float = 1.25

@export_group("Entrance")
@export var entrance_speed_share: float = 1.45
@export var entrance_altitude: float = 65.0
## The entrance pass is over once he is this far past the ship.
@export var entrance_clear: float = 600.0
@export var wingman_scene: PackedScene
@export var wingmen: int = 2
@export var wingman_spacing := Vector2(80.0, 60.0)

@export_group("Hunting")
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
## ...and not within this many degrees of a bearing he was caught on before...
@export var caught_spread_deg: float = 50.0
## ...unless he has been stalking this long and decides to go anyway.
@export var stalk_patience: float = 12.0
@export_range(0.0, 1.0) var top_attack_chance: float = 0.4
@export var top_altitude: float = 1200.0
@export_range(0.0, 1.0) var jam_chance: float = 0.5
@export var jam_time: float = 6.0
@export var wing_rock_time: float = 2.0

@export_group("Missile defence")
## Shooting down our missiles: how far, how far off his nose, how often.
@export var missile_gun_range: float = 1500.0
@export var missile_gun_cone_deg: float = 20.0
@export var missile_gun_cooldown: float = 1.2
@export_range(0.0, 1.0) var missile_kill_chance: float = 0.7

@export_group("Wounded")
@export_range(0.0, 1.0) var wounded_below: float = 0.4
@export_range(0.0, 1.0) var bug_out_chance: float = 0.25
@export_range(0.0, 1.0) var kamikaze_chance: float = 0.12
@export var ripple_gap: float = 0.4
@export var all_in_egress: float = 700.0
## Once this far off while breaking away, he is gone for now.
@export var escape_range: float = 3800.0
@export var eject_range: float = 1300.0
@export var kamikaze_damage: float = 45.0
@export var kamikaze_blast: float = 4.0

var _mood: Mood = Mood.ENTRANCE
var _cruise_speed: float = 0.0
var _came_back: bool = false
var _last_pass_missile: bool = false
var _stalking: float = 0.0
var _top_pass: bool = false
var _jammed_this_pass: bool = false
var _gun_ready_in: float = 0.0
var _ripple_in: float = 0.0
var _rock_left: float = 0.0
var _caught: Array[float] = []
var _homing_on_me: int = 0
var _pilot_out: bool = false


func _create() -> void:
	_came_back = AceLegend.escaped
	super()
	hp = AceLegend.come_back(max_hp)
	_cruise_speed = speed
	speed = _cruise_speed * entrance_speed_share
	velocity = velocity.normalized() * speed
	_bring_wingmen()


func _bring_wingmen() -> void:
	if wingman_scene == null:
		return
	var ahead := velocity.normalized()
	var right := ahead.cross(Vector3.UP).normalized()
	for index in wingmen:
		var side := 1.0 if index % 2 == 0 else -1.0
		var rank := float(index / 2 + 1)
		var wingman := wingman_scene.instantiate() as FlyingEnemy
		wingman.velocity = velocity
		if wingman is StrikeAircraft:
			(wingman as StrikeAircraft).pass_through()
		var slot := right * side * wingman_spacing.x * rank - ahead * wingman_spacing.y * rank
		weapon_launched.emit(wingman, Transform3D(Basis.IDENTITY, global_position + slot))


func _on_flight_step(delta: float) -> void:
	super(delta)
	_rock_wings(delta)
	_watch_missiles()
	var offset := global_position - target_position
	var flat_range := Vector2(offset.x, offset.z).length()
	jink_strength = weave_strength if _mood == Mood.HUNTING and flat_range < weave_range else 0.0
	_gun_ready_in = maxf(_gun_ready_in - delta, 0.0)
	match _mood:
		Mood.HUNTING:
			_dodge_gun(flat_range)
			_shoot_missiles()
			_maybe_jam(flat_range)
		Mood.ALL_IN:
			_shoot_missiles()
			_ripple_missiles(delta)
		Mood.KAMIKAZE:
			_maybe_eject(flat_range)


func _desired_velocity(delta: float) -> Vector3:
	match _mood:
		Mood.ENTRANCE:
			return _entrance_velocity()
		Mood.BUGGING_OUT:
			return _bug_out_velocity()
		Mood.KAMIKAZE:
			return _kamikaze_velocity()
	if _mood == Mood.HUNTING and _leg == Leg.RUN_IN and not BlindArc.contains(global_position):
		var from_ship := global_position - target_position
		var flat_range := Vector2(from_ship.x, from_ship.z).length()
		if flat_range > launch_range and _seen() and _stalking < stalk_patience:
			_stalking += delta
			return _hold_altitude(_stalk_direction(from_ship, flat_range)) * speed
	return super(delta)


## Flat out and low, straight over the deck and away.
func _entrance_velocity() -> Vector3:
	var to_ship := target_position - global_position
	if _flat(velocity).dot(_flat(to_ship)) < 0.0 and Vector2(to_ship.x, to_ship.z).length() > entrance_clear:
		_end_entrance()
		return velocity
	var aim := target_position + Vector3.UP * entrance_altitude
	return (aim - global_position).normalized() * speed


func _end_entrance() -> void:
	_mood = Mood.HUNTING
	speed = _cruise_speed
	_rock_left = wing_rock_time
	_leg = Leg.EGRESS
	_egress_heading = _flat(velocity)


func _bug_out_velocity() -> Vector3:
	var away := global_position - target_position
	if Vector2(away.x, away.z).length() > escape_range:
		AceLegend.record_escape(hp)
		request_destroy()
	return _hold_altitude(_flat(away) + Vector3.UP * egress_climb) * speed


## Lines the jet up on the deck, then holds it there with nobody aboard.
func _kamikaze_velocity() -> Vector3:
	if _pilot_out:
		return velocity
	var aim := target_position + Vector3.UP * entrance_altitude * KAMIKAZE_AIM_SHARE
	return (aim - global_position).normalized() * speed


func _on_arrival() -> void:
	match _mood:
		Mood.ENTRANCE:
			return
		Mood.KAMIKAZE:
			request_destroy()
			reached_target.emit(contact_damage)
			return
	super()


## The gunner is looking his way, or he is on a bearing he was caught on.
func _seen() -> bool:
	if GunnerView.off_aim_deg(global_position) < unseen_deg:
		return true
	var bearing := _bearing()
	for caught in _caught:
		if absf(angle_difference(bearing, caught)) < deg_to_rad(caught_spread_deg):
			return true
	return false


func _bearing() -> float:
	var from_ship := global_position - target_position
	return atan2(from_ship.z, from_ship.x)


func _remember_caught() -> void:
	_caught.append(_bearing())
	if _caught.size() > MEMORY_SIZE:
		_caught.pop_front()


## Round the ship, away from where the gunner is looking, holding off, and
## climbing first if this pass comes down from above.
func _stalk_direction(from_ship: Vector3, flat_range: float) -> Vector3:
	var out := _flat(from_ship)
	var around := Vector3.UP.cross(out) * GunnerView.away_side(global_position)
	var settle := clampf((stalk_radius - flat_range) / stalk_radius, -0.5, 0.5)
	var goal := top_altitude if _top_pass else attack_altitude
	return around + out * settle + Vector3.UP * (goal - global_position.y + target_position.y) * CLIMB_PULL


## A top attack comes straight down on the ship instead of in low.
func _run_in_heading() -> Vector3:
	if _top_pass and global_position.y - target_position.y > attack_altitude * DIVE_FROM_ALTITUDES:
		return (target_position + Vector3.UP * attack_altitude - global_position).normalized()
	return super()


func _wants_missile() -> bool:
	return _mood == Mood.HUNTING and missiles_carried > 0 and not _last_pass_missile


func _launch_missile() -> void:
	_last_pass_missile = true
	_new_pass()
	super()


func _strafe() -> void:
	_last_pass_missile = false
	_new_pass()
	super()


func _new_pass() -> void:
	_stalking = 0.0
	_jammed_this_pass = false
	_top_pass = _mood == Mood.HUNTING and randf() < top_attack_chance


## As he commits to a pass he may jam our radar, once a pass.
func _maybe_jam(flat_range: float) -> void:
	if _jammed_this_pass or _leg != Leg.RUN_IN or flat_range > stalk_radius * JAM_REACH:
		return
	if flat_range > launch_range and _seen():
		return
	_jammed_this_pass = true
	if randf() < jam_chance:
		jamming.emit(jam_time)


func _dodge_gun(flat_range: float) -> void:
	if _break_remaining > 0.0 or not GunnerView.shooting or flat_range > weave_range:
		return
	if GunnerView.off_aim_deg(global_position) <= dodge_cone_deg:
		_break_remaining = gun_break_time
		_break_from = target_position
		_remember_caught()


func _on_damage(amount: float, world_point: Vector3) -> void:
	super(amount, world_point)
	if _mood != Mood.HUNTING:
		return
	_remember_caught()
	if hp < max_hp * wounded_below:
		_choose_ending()
		return
	if _break_remaining <= 0.0:
		# The rounds come from the ship: turn across the line of fire.
		_break_remaining = gun_break_time
		_break_from = target_position


func _choose_ending() -> void:
	var roll := randf()
	if roll < kamikaze_chance:
		_mood = Mood.KAMIKAZE
	elif roll < kamikaze_chance + bug_out_chance and not _came_back:
		_mood = Mood.BUGGING_OUT
		_rock_left = wing_rock_time
	else:
		_mood = Mood.ALL_IN
		egress_distance = all_in_egress
	_break_remaining = 0.0
	_leg = Leg.RUN_IN


func _ripple_missiles(delta: float) -> void:
	if missiles_carried <= 0 or BlindArc.contains(global_position):
		return
	_ripple_in -= delta
	if _ripple_in > 0.0:
		return
	_ripple_in = ripple_gap
	missiles_carried -= 1
	var missile := missile_scene.instantiate() as FlyingEnemy
	missile.velocity = velocity
	weapon_launched.emit(missile, Transform3D(Basis.IDENTITY, global_position + LAUNCH_DROP))


func _maybe_eject(flat_range: float) -> void:
	if _pilot_out or flat_range > eject_range:
		return
	_pilot_out = true
	countermeasures_enabled = false
	contact_damage = kamikaze_damage
	blast_size = kamikaze_blast
	ejected.emit(global_position, velocity)


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


## A missile that was coming for him and is not any more gets a rock of
## the wings.
func _watch_missiles() -> void:
	var homing := 0
	for missile in MissileProjectile.in_flight:
		if missile.is_flying() and missile.homing_target() == self:
			homing += 1
	if homing < _homing_on_me and _mood != Mood.KAMIKAZE:
		_rock_left = wing_rock_time
	_homing_on_me = homing


func _rock_wings(delta: float) -> void:
	if visuals == null:
		return
	_rock_left = maxf(_rock_left - delta, 0.0)
	var envelope := sin(PI * _rock_left / wing_rock_time) if _rock_left > 0.0 else 0.0
	visuals.rotation.z = sin(_rock_left * ROCK_RATE) * deg_to_rad(ROCK_DEG) * envelope
