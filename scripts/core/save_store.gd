class_name SaveStore
extends RefCounted
## Reads and writes SaveData as JSON in user://.
## Every save writes a backup copy FIRST and then the main file, so an
## interrupted write can never leave both files unreadable. Loading tries the
## main file, then the backup, then falls back to a fresh save.

const MAIN_PATH := "user://savegame.json"
const BACKUP_PATH := "user://savegame.bak"


static func load_data(main_path: String = MAIN_PATH, backup_path: String = BACKUP_PATH) -> SaveData:
	for path in [main_path, backup_path]:
		var parsed: Variant = _read_json(path)
		if typeof(parsed) == TYPE_DICTIONARY:
			return SaveData.from_variant(parsed)
	return SaveData.new()


## Returns true when the main file was written.
static func save_data(data: SaveData, main_path: String = MAIN_PATH, backup_path: String = BACKUP_PATH) -> bool:
	var text := JSON.stringify(data.to_dict(), "\t")
	_write_text(backup_path, text)
	return _write_text(main_path, text)


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


static func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.close()
	return true
