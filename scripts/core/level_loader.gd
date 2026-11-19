class_name LevelLoader
extends RefCounted
## Reads data/levels/chapter_N.json, validates every level and builds BoardModels.
## A level is only accepted if its stored solution really connects tank to tap
## (checked with FlowSolver) and its starting layout is NOT already solved.

## One file per chapter. A chapter file that does not exist yet is simply skipped, so the campaign grows
## chapter by chapter and the UI only ever shows levels that really exist.
const LEVEL_FILES := [
	"res://data/levels/chapter_1.json",
	"res://data/levels/chapter_2.json",
	"res://data/levels/chapter_3.json",
	"res://data/levels/chapter_4.json",
]
## This prototype's board view draws the tank on the left of column 0 and the
## tap on the right of the last column, so levels must use those sides.
const REQUIRED_SOURCE_SIDE := "W"
const REQUIRED_SINK_SIDE := "E"


## Returns a level's chapter difficulty, falling back to its campaign id range.
static func difficulty_of(level: Dictionary) -> String:
	return str(level.get("difficulty", Difficulty.for_level_id(int(level.get("id", 1)))))


## Returns only the levels that pass validation (problems are reported with push_error), sorted by id.
static func load_all(paths: Array = LEVEL_FILES) -> Array:
	var levels: Array = []
	var seen_ids: Dictionary = {}
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("Level file is not valid JSON: %s" % path)
			continue
		var data: Dictionary = parsed
		var entries: Variant = data.get("levels", [])
		if typeof(entries) != TYPE_ARRAY:
			push_error("Level file has no 'levels' array: %s" % path)
			continue
		for entry in entries:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var level: Dictionary = entry
			var problem := validate_level(level)
			if problem == "" and seen_ids.has(int(level["id"])):
				problem = "duplicate level id"
			if problem != "":
				push_error("Level %s rejected: %s" % [str(level.get("id", "?")), problem])
				continue
			seen_ids[int(level["id"])] = true
			levels.append(level)
	levels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
	return levels


## Returns "" when the level is valid, otherwise a human-readable problem.
static func validate_level(level: Dictionary) -> String:
	for key in ["id", "cols", "rows", "source", "sink", "grid", "solution"]:
		if not level.has(key):
			return "missing field '%s'" % key
	var cols := int(level["cols"])
	var rows := int(level["rows"])
	if cols < 2 or rows < 2 or cols > 8 or rows > 8:
		return "board size must be between 2x2 and 8x8"
	if level.has("difficulty") and not Difficulty.is_valid(str(level["difficulty"])):
		return "unknown difficulty '%s'" % str(level["difficulty"])
	if level.has("difficulty") and str(level["difficulty"]) != Difficulty.for_level_id(int(level["id"])):
		return "level %d belongs to chapter '%s', not '%s'" % [int(level["id"]), Difficulty.for_level_id(int(level["id"])), str(level["difficulty"])]
	if level.has("chapter") and int(level["chapter"]) != Difficulty.chapter_number(Difficulty.for_level_id(int(level["id"]))):
		return "chapter number does not match the level id"
	if level.has("title") and (typeof(level["title"]) != TYPE_STRING or str(level["title"]).strip_edges() == ""):
		return "title must be a non-empty string"
	if level.has("expected") and str(level["expected"]) != "valid":
		return "expected must be 'valid'"

	for label in ["grid", "solution"]:
		var rows_problem := _validate_rows(level[label], cols, rows, label)
		if rows_problem != "":
			return rows_problem

	var source_problem := _check_endpoint(level["source"], cols, rows, "source", REQUIRED_SOURCE_SIDE, 0)
	if source_problem != "":
		return source_problem
	var sink_problem := _check_endpoint(level["sink"], cols, rows, "sink", REQUIRED_SINK_SIDE, cols - 1)
	if sink_problem != "":
		return sink_problem

	var start := make_board(level, "grid")
	var goal := make_board(level, "solution")
	for y in rows:
		for x in cols:
			var cell := Vector2i(x, y)
			if start.get_type(cell) != goal.get_type(cell):
				return "grid and solution use different pieces at (%d,%d)" % [x, y]
	if not FlowSolver.solve(goal).valid:
		return "the stored solution does not connect the tank to the tap with every open end sealed"
	if FlowSolver.solve(start).valid:
		return "the starting layout is already solved"
	var needed := 0
	var solution_turns := solution_taps(level)
	for key in solution_turns.keys():
		needed += int(solution_turns[key])
	if level.has("par"):
		if not [TYPE_INT, TYPE_FLOAT].has(typeof(level["par"])) or int(level["par"]) < 1:
			return "par must be a positive whole number"
		if int(level["par"]) != needed:
			return "par %d does not match the stored solution, which needs %d taps" % [int(level["par"]), needed]
	if level.has("move_limit"):
		if int(level["move_limit"]) < maxi(needed, 1):
			return "move_limit is below the number of taps the solution needs"
	return ""


static func _validate_rows(value: Variant, cols: int, rows: int, label: String) -> String:
	if typeof(value) != TYPE_ARRAY:
		return "'%s' must be an array of row strings" % label
	var lines: Array = value
	if lines.size() != rows:
		return "'%s' needs %d rows, found %d" % [label, rows, lines.size()]
	for y in rows:
		if typeof(lines[y]) != TYPE_STRING:
			return "'%s' row %d is not a string" % [label, y]
		var tokens: PackedStringArray = String(lines[y]).split(" ", false)
		if tokens.size() != cols:
			return "'%s' row %d needs %d cells, found %d" % [label, y, cols, tokens.size()]
		for token in tokens:
			if not parse_token(token).get("ok", false):
				return "'%s' row %d has an invalid cell '%s'" % [label, y, token]
	return ""


static func _check_endpoint(value: Variant, cols: int, rows: int, label: String, side_needed: String, x_needed: int) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return "'%s' must be an object" % label
	var d: Dictionary = value
	for key in ["x", "y", "side"]:
		if not d.has(key):
			return "'%s' is missing '%s'" % [label, key]
	var x := int(d["x"])
	var y := int(d["y"])
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return "'%s' cell is outside the board" % label
	if x != x_needed:
		return "'%s' must be in column %d in this build" % [label, x_needed]
	if String(d["side"]).to_upper() != side_needed:
		return "'%s' side must be %s in this build" % [label, side_needed]
	return ""


## Parses one cell token: "." (empty) or a piece letter + rotation digit, e.g. "L3".
static func parse_token(token: String) -> Dictionary:
	if token == ".":
		return {"ok": true, "type": PipeDefs.EMPTY, "rot": 0}
	if token.length() != 2:
		return {"ok": false}
	var type: String = PipeDefs.type_from_token(token.substr(0, 1))
	if type == "" or type == PipeDefs.EMPTY:
		return {"ok": false}
	var digit := token.substr(1, 1)
	if not digit.is_valid_int():
		return {"ok": false}
	var rot := digit.to_int()
	if rot < 0 or rot > 3:
		return {"ok": false}
	return {"ok": true, "type": type, "rot": rot}


## Builds a BoardModel from the "grid" (start) or "solution" rows of a validated level.
static func make_board(level: Dictionary, which: String = "grid") -> BoardModel:
	var cols := int(level["cols"])
	var rows := int(level["rows"])
	var board := BoardModel.new(cols, rows)
	var lines: Array = level[which]
	for y in rows:
		var tokens: PackedStringArray = String(lines[y]).split(" ", false)
		for x in cols:
			var parsed := parse_token(tokens[x])
			board.set_cell(Vector2i(x, y), parsed["type"], parsed["rot"])
	var src: Dictionary = level["source"]
	board.source_cell = Vector2i(int(src["x"]), int(src["y"]))
	board.source_side = Dirs.from_name(String(src["side"]))
	var snk: Dictionary = level["sink"]
	board.sink_cell = Vector2i(int(snk["x"]), int(snk["y"]))
	board.sink_side = Dirs.from_name(String(snk["side"]))
	return board


## Vector2i -> clockwise taps needed to turn the starting piece into the solution piece.
static func solution_taps(level: Dictionary) -> Dictionary:
	var start := make_board(level, "grid")
	var goal := make_board(level, "solution")
	var taps: Dictionary = {}
	for y in start.rows:
		for x in start.cols:
			var cell := Vector2i(x, y)
			if not start.can_rotate(cell):
				continue
			var wanted := goal.mask_at(cell)
			for count in 4:
				if Dirs.rotate_mask(start.mask_at(cell), count) == wanted:
					if count > 0:
						taps[cell] = count
					break
	return taps


## Par (the 3-star target). Stored in the level data; falls back to the stored solution's tap count.
## The offline tools check that the stored par is the true minimum over ALL valid solutions.
static func par_moves(level: Dictionary) -> int:
	if level.has("par"):
		return int(level["par"])
	var total := 0
	var taps := solution_taps(level)
	for key in taps.keys():
		total += int(taps[key])
	return total
