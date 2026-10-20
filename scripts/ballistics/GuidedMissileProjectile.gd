extends AbstractProjectile
class_name GuidedMissileProjectile

signal hit_enemy(enemy: Enemy, world_point: Vector3, killed: bool)
signal detonated(position: Vector3, size: float)

const LAUNCH_SPEED := 34.0
const BOOST_DELAY := 0.28
const CRUISE_SPEED := 265.0
const ACCELERATION := 420.0
const TURN_RATE := 4.6
const TURN_RATE_TERMINAL := 8.5
const TERMINAL_RANGE := 260.0
const GRAVITY := 9.81
const FUZE_RADIUS := 16.0
const BLAST_RADIUS := 26.0
const WARHEAD := 260.0
const DECOY_CHECK_RANGE := 520.0
const PUFF_INTERVAL := 0.022

var _target: Enemy
var _tree: SceneTree
var _smoke: MissileSmokeRenderer
var _speed: float = LAUNCH_SPEED
var _last_distance: float = INF
var _decoy := Vector3.INF
var _decoy_velocity := Vector3.ZERO
var _puff_timer: float = 0.0


func _init(
	batch: ProjectileBatch,
	smoke: MissileSmokeRenderer,
	tree: SceneTree,
	origin: Vector3,
	direction: Vector3,
	target: Enemy
) -> void:
	super(origin, direction.normalized() * LAUNCH_SPEED, 0.16, batch)
	_smoke = smoke
	_tree = tree
	_target = target
	ground_height = 0.5
	max_lifetime = 14.0
	max_distance = 6000.0


func _on_fire() -> void:
	super()
	_smoke.play_launch(position)


func _on_propel(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = null
	elif not _target.alive or _target.is_queued_for_deletion():
		_target = null

	var previous := position
	var aim := Vector3.INF
	if age < BOOST_DELAY:
		velocity.y -= GRAVITY * delta
	else:
		_speed = minf(_speed + ACCELERATION * delta, CRUISE_SPEED)
		if _decoy != Vector3.INF:
			_decoy_velocity = (
				_decoy_velocity * (1.0 - clampf(delta * 1.1, 0.0, 1.0))
				+ Vector3.DOWN * 7.0 * delta
			)
			_decoy += _decoy_velocity * delta
			aim = _decoy
		elif _target != null:
			var distance := position.distance_to(_target.global_position)
			if distance < DECOY_CHECK_RANGE:
				var decoy := _target.try_decoy(position)
				if decoy != Vector3.INF:
					_decoy = decoy
					_decoy_velocity = _target.velocity * 0.5 + Vector3(
						randf_range(-9, 9), randf_range(-3, 5), randf_range(-9, 9)
					)
					_target = null
					aim = decoy
			if aim == Vector3.INF and _target != null:
				var time_to_go := distance / maxf(_speed, 1.0)
				aim = _target.global_position + _target.velocity * time_to_go * 0.9
		if aim != Vector3.INF:
			_steer(aim, delta)
		else:
			velocity = velocity.normalized() * _speed
			velocity.y -= GRAVITY * delta

	position += velocity * delta
	_puff_timer -= delta
	if _puff_timer <= 0.0:
		_puff_timer = PUFF_INTERVAL
		_smoke.emit_puff(previous, position, age < BOOST_DELAY)

	if _target != null:
		var distance := _target.surface_distance(position)
		if distance < FUZE_RADIUS or (distance < 75.0 and distance > _last_distance):
			request_impact(ProjectileImpact.new(position, _target))
		_last_distance = distance
	elif _decoy != Vector3.INF:
		if position.distance_to(_decoy) < FUZE_RADIUS:
			request_impact(ProjectileImpact.new(position))


func _steer(aim: Vector3, delta: float) -> void:
	var to_aim := aim - position
	if to_aim.length_squared() <= 0.0001:
		velocity = velocity.normalized() * _speed
		return
	var desired := to_aim.normalized()
	var current := Vector3.UP
	if velocity.length_squared() > 0.000001:
		current = velocity.normalized()
	var rate := TURN_RATE
	if to_aim.length() < TERMINAL_RANGE:
		rate = TURN_RATE_TERMINAL
	var angle := current.angle_to(desired)
	if angle > 0.0001:
		var axis := current.cross(desired)
		if axis.length_squared() <= 0.000001:
			axis = current.cross(Vector3.RIGHT)
			if axis.length_squared() <= 0.000001:
				axis = current.cross(Vector3.UP)
		current = current.rotated(axis.normalized(), minf(rate * delta, angle))
	velocity = current * _speed


func _on_impact(impact: ProjectileImpact) -> void:
	_detonate(impact.enemy != null)


func _on_delete(reason: DeleteReason) -> void:
	if reason == DeleteReason.EXPIRED or reason == DeleteReason.RANGE:
		_detonate(false)
	super(reason)
	_target = null
	_tree = null
	_smoke = null


func _detonate(on_target: bool) -> void:
	var size := BLAST_RADIUS
	if not on_target:
		size *= 0.75
	detonated.emit(position, size)
	for node in _tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		var enemy := node as Enemy
		if enemy == null or not enemy.alive:
			continue
		var distance := enemy.surface_distance(position)
		if distance > BLAST_RADIUS:
			continue
		var falloff := pow(
			clampf(1.0 - maxf(distance, 0.0) / BLAST_RADIUS, 0.0, 1.0), 0.6
		)
		var killed := enemy.take_damage(WARHEAD * falloff, position)
		hit_enemy.emit(enemy, position, killed)


func visual_transform() -> Transform3D:
	var result := super()
	result.basis *= Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	return result


func visual_color() -> Color:
	var heat := 1.2 if age < BOOST_DELAY else 3.0
	return Color(heat, heat, heat * 0.92, 1.0)
