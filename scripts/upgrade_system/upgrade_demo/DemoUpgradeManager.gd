extends Node

static var prime_node

@export var demo_output : Control
@export var target : DemoUpgradeTarget
@export var circle : Node2D

const ROTATION_RATE_RAD : float = PI / 4

var rotating : bool = false
var super_rotating : bool = false
var z_rotate : bool = false

static var clones : Array[Node]

var t : float = 0
var base_size : Vector2 = Vector2(1, 1)

func _ready() -> void:
	target.upgrades_changed.connect(update)
	target.spin_was_reset.connect(reset_spin)
	if not prime_node:
		prime_node = self
		circle.reparent.call_deferred(demo_output.get_parent())


func update() -> void:
	rotating = target.is_spinning
	demo_output.self_modulate = target.modulate
	base_size = Vector2(1, 1) * (0.3 if target.is_tiny else 1.0)
	clone(target.clones)
	z_rotate = target.green_spin 
	circle_purple(target.purple_circle)
	super_rotating = target.is_super_spin
	if target.has_circle:
		show_circle()
	else:
		hide_circle()

	demo_output.scale = base_size


func _process(delta: float) -> void:
	t += delta
	if t > 2 * PI:
		t = 0

	demo_output.scale = base_size
	if rotating:
		demo_output.rotation += ROTATION_RATE_RAD * delta * (10 if super_rotating else 1)
	if z_rotate:
		demo_output.scale.x *= sin(t)



func reset_spin() -> void:
	demo_output.rotation = 0.0


static func clone(count: int) -> void:
	if count == clones.size():
		return
	if count > clones.size():
		var new_object = prime_node.demo_output.duplicate(DuplicateFlags.DUPLICATE_DEFAULT)
		clones.push_back(new_object)
		prime_node.demo_output.add_sibling(new_object)
		new_object.global_position = prime_node.demo_output.global_position
		new_object.global_position.x -= (prime_node.demo_output.size.x + 10.0) * clones.size()
	else:
		var old_object = clones.pop_back()
		old_object.queue_free()

func show_circle() -> void:
	if self != prime_node:
		return
	circle.show()

func hide_circle() -> void:
	if self != prime_node:
		return
	circle.hide()

func circle_purple(multiplier: int) -> void:
	circle.self_modulate = Color.WHITE - (Color.WHITE - Color.PURPLE) * (multiplier/10.0)