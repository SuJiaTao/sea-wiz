extends AbstractDeckWeapon
class_name EmergencyCoolant

signal vented()

const COOLDOWN: float = 30.0

@export var barrel_heat: BarrelHeat
@export var turret: Turret

var cooldown_left: float = 0.0


func _trigger() -> void:
	if cooldown_left > 0.0:
		return
	cooldown_left = COOLDOWN
	barrel_heat.heat = 0.0
	barrel_heat.icing = 0.0
	turret.set_overheated(false)
	vented.emit()


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
