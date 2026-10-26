extends Node

static var singleton

@export var demo_output : Control
@export var target : DemoUpgradeTarget

const ROTATION_RATE_RAD : float = PI / 4

var rotating : bool = false

static var clones : Array[Node]

func _ready() -> void:
	target.upgrades_changed.connect(update)
	target.spin_was_reset.connect(reset_spin)
	if not singleton:
		singleton = self


func update() -> void:
	rotating = target.is_spinning
	demo_output.modulate = target.modulate
	demo_output.scale = Vector2(1, 1) * (0.3 if target.is_tiny else 1.0)
	clone(target.clones)


func _process(delta: float) -> void:
	if rotating:
		demo_output.rotation += ROTATION_RATE_RAD * delta


func reset_spin() -> void:
	demo_output.rotation = 0.0


static func clone(count: int) -> void:
	if count == clones.size():
		return
	if count > clones.size():
		var new_object = singleton.demo_output.duplicate(DuplicateFlags.DUPLICATE_DEFAULT)
		clones.push_back(new_object)
		singleton.demo_output.add_sibling(new_object)
		new_object.position = singleton.demo_output.global_position
		new_object.position.x -= (singleton.demo_output.size.x + 10.0) * clones.size()
	else:
		var old_object = clones.pop_back()
		old_object.queue_free()
