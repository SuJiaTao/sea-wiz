extends SaveDataManager
class_name EnemyCodexStore

const SECTION := &"codex"
const KEY := &"entires"


static func load_codex_data() -> Variant:
	return _load_from_file(SECTION, KEY)


static func save_entries_state(codex_data: Dictionary) -> void:
	_save_to_file(SECTION, KEY, codex_data)