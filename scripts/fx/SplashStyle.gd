extends Resource
class_name SplashStyle

@export var droplets_per_size: float = 24.0
@export var max_droplets: int = 80
@export var droplet_speed := Vector2(8.0, 16.0)
@export var droplet_spread: float = 0.35
@export var column_puffs_per_size: float = 10.0
@export var max_column_puffs: int = 40
@export var column_speed := Vector2(10.0, 17.0)
@export var column_spread: float = 0.12
@export var ripple_lift: float = 0.08


func droplet_count(size: float) -> int:
	return clampi(ceili(droplets_per_size * size), 1, max_droplets)


func column_count(size: float) -> int:
	return clampi(ceili(column_puffs_per_size * size), 1, max_column_puffs)
