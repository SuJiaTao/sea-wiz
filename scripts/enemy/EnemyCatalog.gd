extends Resource
class_name EnemyCatalog

@export var scenes: Array[PackedScene] = []


func names() -> Array[String]:
	var result: Array[String] = []
	for scene in scenes:
		result.append(_name_of(scene))
	return result


func find(enemy_name: String) -> PackedScene:
	for scene in scenes:
		if _name_of(scene) == enemy_name.to_lower():
			return scene
	return null


func _name_of(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename().to_lower()
