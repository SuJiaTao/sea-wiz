extends SaveDataManager
class_name HighScoreStore

const SECTION := "score"
const KEY := "best"


static func load_best() -> int:
	var result = _load_from_file(SECTION, KEY)
	if not result:
		return 0
	return int(result)


static func save_best(value: int) -> void:
	if not _save_to_file(SECTION, KEY, value):
		push_warning("Could not save the high score.")
