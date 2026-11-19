extends Node
## Autoload "SaveManager": owns the live SaveData and writes it to disk.
## Saves happen on real events (level completed, setting changed, level
## started, app paused/closed), never every frame.

var data: SaveData = SaveData.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = SaveStore.load_data()


func save() -> void:
	SaveStore.save_data(data)


## Returns what changed, or {} when the completion was rejected (locked level).
func record_completion(level_id: int, moves: int, stars: int, total_levels: int) -> Dictionary:
	var result := data.record_completion(level_id, moves, stars, total_levels)
	if not result.is_empty():
		save()
	return result


func set_last_level(level_id: int) -> void:
	if level_id >= 1 and data.is_unlocked(level_id) and data.last_level != level_id:
		data.last_level = level_id
		save()


func set_sfx(on: bool) -> void:
	data.sfx_on = on
	save()


func set_vibration(on: bool) -> void:
	data.vibration_on = on
	save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
