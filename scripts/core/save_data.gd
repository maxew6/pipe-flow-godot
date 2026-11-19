class_name SaveData
extends RefCounted
## Pure save-game model (no file access, no nodes) so it can be unit-tested.
## SaveStore reads/writes it; the SaveManager autoload owns the live instance.
##
## Safety rules:
##  * from_variant() accepts ANY value (missing, corrupt, older) and always
##    returns a sane SaveData.
##  * A level can only be completed if it is unlocked, so a stray call can
##    never unlock content.
##  * Completing a level only ever improves records (best moves, best stars).

const VERSION := 1
const MAX_ID := 9999
const MAX_SCORE := 100000000

var total_score: int = 0
var highest_unlocked: int = 1
var last_level: int = 1
var sfx_on: bool = true
var vibration_on: bool = true
## int level id -> {"completed": bool, "best_moves": int, "best_stars": int}
var levels: Dictionary = {}


func to_dict() -> Dictionary:
	var out_levels := {}
	for id in levels.keys():
		var entry: Dictionary = levels[id]
		out_levels[str(id)] = entry.duplicate()
	return {
		"version": VERSION,
		"total_score": total_score,
		"highest_unlocked": highest_unlocked,
		"last_level": last_level,
		"settings": {"sfx": sfx_on, "vibration": vibration_on},
		"levels": out_levels,
	}


static func from_variant(value: Variant) -> SaveData:
	var data := SaveData.new()
	if typeof(value) != TYPE_DICTIONARY:
		return data
	var d: Dictionary = value
	data.total_score = clampi(_to_int(d.get("total_score", 0), 0), 0, MAX_SCORE)
	data.highest_unlocked = clampi(_to_int(d.get("highest_unlocked", 1), 1), 1, MAX_ID)
	data.last_level = clampi(_to_int(d.get("last_level", 1), 1), 1, MAX_ID)

	var settings: Variant = d.get("settings", {})
	if typeof(settings) == TYPE_DICTIONARY:
		var s: Dictionary = settings
		data.sfx_on = _to_bool(s.get("sfx", true), true)
		data.vibration_on = _to_bool(s.get("vibration", true), true)

	var raw_levels: Variant = d.get("levels", {})
	if typeof(raw_levels) == TYPE_DICTIONARY:
		var rl: Dictionary = raw_levels
		for key in rl.keys():
			var id := _to_int(key, -1)
			if id < 1 or id > MAX_ID:
				continue
			var raw_entry: Variant = rl[key]
			if typeof(raw_entry) != TYPE_DICTIONARY:
				continue
			var e: Dictionary = raw_entry
			var completed := _to_bool(e.get("completed", false), false)
			data.levels[id] = {
				"completed": completed,
				"best_moves": clampi(_to_int(e.get("best_moves", 0), 0), 0, 99999),
				"best_stars": clampi(_to_int(e.get("best_stars", 0), 0), 0, 3),
			}
			if completed:
				data.highest_unlocked = maxi(data.highest_unlocked, mini(id + 1, MAX_ID))
	data.last_level = mini(data.last_level, data.highest_unlocked)
	return data


func is_unlocked(id: int) -> bool:
	return id >= 1 and id <= highest_unlocked


## Copy of a level's record with defaults filled in.
func info(id: int) -> Dictionary:
	if levels.has(id):
		var entry: Dictionary = levels[id]
		return entry.duplicate()
	return {"completed": false, "best_moves": 0, "best_stars": 0}


func is_completed(id: int) -> bool:
	return bool(info(id)["completed"])


func has_progress() -> bool:
	return not levels.is_empty()


## Completed levels with ids in [first, last] (used for chapter progress).
func completed_count_in_range(first: int, last: int) -> int:
	var count := 0
	for id in levels.keys():
		if int(id) >= first and int(id) <= last:
			var entry: Dictionary = levels[id]
			if bool(entry["completed"]):
				count += 1
	return count


func stars_in_range(first: int, last: int) -> int:
	var total := 0
	for id in levels.keys():
		if int(id) >= first and int(id) <= last:
			var entry: Dictionary = levels[id]
			total += int(entry["best_stars"])
	return total


func total_stars() -> int:
	var total := 0
	for id in levels.keys():
		var entry: Dictionary = levels[id]
		total += int(entry["best_stars"])
	return total


## The level the Play/Continue button should open: the first unlocked level the
## player has not finished, or the last level played once everything is done.
func resume_level(total_levels: int) -> int:
	var count := maxi(total_levels, 1)
	var target := clampi(highest_unlocked, 1, count)
	if is_completed(target):
		return clampi(last_level, 1, count)
	return target


## Records a finished level. Returns {} if the level is locked or out of range
## (nothing changes), otherwise a summary of what changed.
func record_completion(id: int, moves: int, stars: int, total_levels: int) -> Dictionary:
	if id < 1 or id > total_levels or not is_unlocked(id):
		return {}
	var entry := info(id)
	var first := not bool(entry["completed"])
	var old_moves: int = entry["best_moves"]
	var old_stars: int = entry["best_stars"]
	var safe_moves := maxi(moves, 0)
	var safe_stars := clampi(stars, 1, 3)

	var new_moves := old_moves
	if old_moves == 0 or (safe_moves > 0 and safe_moves < old_moves):
		new_moves = safe_moves
	var new_stars := maxi(old_stars, safe_stars)

	levels[id] = {"completed": true, "best_moves": new_moves, "best_stars": new_stars}
	last_level = id

	var newly_unlocked := 0
	var next_id := mini(id + 1, total_levels)
	if next_id > highest_unlocked:
		highest_unlocked = next_id
		newly_unlocked = next_id

	return {
		"first_completion": first,
		"new_best_moves": new_moves < old_moves or old_moves == 0,
		"new_best_stars": new_stars > old_stars,
		"newly_unlocked": newly_unlocked,
	}


static func _to_int(value: Variant, fallback: int) -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			var f: float = value
			if is_nan(f) or is_inf(f):
				return fallback
			return int(f)
		TYPE_STRING:
			var s: String = value
			if s.is_valid_int():
				return s.to_int()
	return fallback


static func _to_bool(value: Variant, fallback: bool) -> bool:
	if typeof(value) == TYPE_BOOL:
		return value
	return fallback
