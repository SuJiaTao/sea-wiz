extends RefCounted
class_name SaveDataManager

const PATH := "user://save_data.cfg"

static var file := ConfigFile.new()


## Returns null if this fails, otherwise returns the value of the section's key
static func _load_from_file(section: StringName, key: StringName) -> Variant:
	# print(OS.get_data_dir())
	if file.load(PATH) != OK:
		return null
	return file.get_value(section, key, 0)


## Returns true if save is successful, false otherwise
static func _save_to_file(section: StringName, key: StringName, value: Variant) -> bool:
	file.set_value(section, key, value)
	if file.save(PATH) != OK:
		return false
	return true