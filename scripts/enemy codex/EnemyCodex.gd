extends RefCounted
class_name EnemyCodexData

static var entries := {
	"NULL": {
		"description": "No item found",
		"unlocked": false
	},
	"DRONE": {
		"description": "example description of a drone",
		"unlocked": false
	}
}


## Returns null if no entry found for given enemy name
static func get_entry(name: StringName) -> Variant:
	return entries.get(name, null)


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
		EnemyCodexStore.save_entries_state(get_unlocked_data())


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
		EnemyCodexStore.save_entries_state(get_unlocked_data())


static func get_unlocked_data() -> Dictionary:
	var result : Dictionary = {}
	for key in entries.keys():
		result.set(key, {"unlocked": entries.get(key).unlocked})

	return result