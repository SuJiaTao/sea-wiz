extends RefCounted
class_name EnemyCodexData

static var _entries := {
	"NULL": {
		"description": "No item found",
		"unlocked": false
	},
	"DRONE": {
		"description": "example description",
		"unlocked": false
	},
	"WRECK": {
		"description": "example description",
		"unlocked": false
	},
	"FIGHTER": {
		"description": "example description",
		"unlocked": false
	},
	"SEA SKIMMER": {
		"description": "example description",
		"unlocked": false
	},
	"HELICOPTER": {
		"description": "example description",
		"unlocked": false
	},
	"BALLISTIC": {
		"description": "example description",
		"unlocked": false
	},
	"HEAVY BOMBER": {
		"description": "example description",
		"unlocked": false
	},
	"SUPERSONIC": {
		"description": "example description",
		"unlocked": false
	},
	"INTERCEPTOR": {
		"description": "example description",
		"unlocked": false
	},
}


static func _static_init() -> void:
	_load_unlocks()


## Returns null if no entry found for given enemy name
static func get_entry(name: StringName) -> Variant:
	var result = _entries.get(name, null)
	if !result:
		push_warning("No codex entry for '" + name +"' found.")
	return result


## Sets "unlocked" of the entry of name to true.[br]
## Saves state to file if save = true (true by default).[br]
## Does nothing if entry already unlocked
static func unlock(name: StringName, save: bool=true) -> void:
	var entry = get_entry(name)
	if entry:
		if entry.unlocked:
			return
		entry.unlocked = true
	if save:
		_save_unlocks()


## Sets "unlocked" of the entry of name to false.[br]
## Saves state to file if save = true (true by default).[br]
## Does nothing if entry already locked
static func lock(name: StringName, save: bool=true) -> void:
	var entry = get_entry(name)
	if entry:
		if not entry.unlocked:
			return
		entry.unlocked = false
	if save:
		_save_unlocks()


static func get_unlocked_data() -> Dictionary:
	var result : Dictionary = {}
	for key in _entries.keys():
		result.set(key, {"unlocked": _entries.get(key).unlocked})

	return result


static func _save_unlocks() -> void:
	EnemyCodexStore.save_entries_state(get_unlocked_data())


static func _load_unlocks() -> void:
	var data = EnemyCodexStore.load_codex_data()
	for key in _entries.keys():
		if not data.has(key):
			push_warning("Corrupted entry data.")
			return
		
		var entry = _entries.get(key)
		entry.unlocked = data.get(key).unlocked
		_entries.set(key, entry)


static func lock_all() -> void:
	for key in _entries.keys():
		var entry = _entries.get(key)
		entry.unlocked = false
		_entries.set(key, entry)
	
	_save_unlocks()