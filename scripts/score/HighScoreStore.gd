extends RefCounted
class_name HighScoreStore

const PATH := "user://high_score.cfg"
const SECTION := "score"
const KEY := "best"


static func load_best() -> int:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return 0
	return int(file.get_value(SECTION, KEY, 0))


static func save_best(value: int) -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, KEY, value)
	if file.save(PATH) != OK:
		push_warning("Could not save the high score.")
