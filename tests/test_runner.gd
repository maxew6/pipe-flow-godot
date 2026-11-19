extends SceneTree
## Headless logic tests. Run from the project folder (after one --import):
##   godot --headless --path . --import
##   godot --headless --path . --script res://tests/test_runner.gd
## Exit code 0 = all passed, 1 = at least one failure.

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_test_rotation_table()
	_test_full_turn_returns_home()
	_test_non_rotatable_pieces()
	_test_model_rotation_and_copy()
	_test_straight_line_success()
	_test_broken_middle_is_dead_end()
	_test_source_closed()
	_test_sink_closed_and_edge_leak()
	_test_cap_is_not_a_leak()
	_test_cycles_terminate()
	_test_determinism()
	_test_token_parsing()
	_test_level_data()
	_test_validation_rejects_bad_levels()
	_test_scoring()
	_test_difficulty_groups()
	_test_save_data_sanitising()
	_test_save_data_progression()
	_test_save_data_round_trip()
	_test_save_store_files()
	_test_art_assets()
	_test_flow_paths()
	_test_flow_plan()
	_test_invalid_route_never_drains()
	_test_first_problem()
	_test_level_plans()
	_test_sealed_network_rule()
	_test_screenshot_regression()
	_test_caps_in_levels()
	_test_board_view_flow_safety()
	_test_completion_recorded_once()
	_test_campaign_schema()
	_test_chapter_progress_helpers()
	print("---- %d passed, %d failed ----" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


## Builds a board from row strings. Source tank on the W side of `source`, tap on the E side of `sink`.
func _board(rows: Array, source: Vector2i, sink: Vector2i) -> BoardModel:
	var cols := String(rows[0]).split(" ", false).size()
	var level := {
		"cols": cols,
		"rows": rows.size(),
		"source": {"x": source.x, "y": source.y, "side": "W"},
		"sink": {"x": sink.x, "y": sink.y, "side": "E"},
		"grid": rows,
	}
	return LevelLoader.make_board(level, "grid")


func _test_rotation_table() -> void:
	# N=1 E=2 S=4 W=8
	var expected := {
		"straight": [5, 10, 5, 10],
		"elbow": [3, 6, 12, 9],
		"tee": [7, 14, 13, 11],
		"cross": [15, 15, 15, 15],
		"cap": [1, 2, 4, 8],
		"empty": [0, 0, 0, 0],
	}
	for type in expected.keys():
		var masks: Array = expected[type]
		for rot in 4:
			check(PipeDefs.mask_for(type, rot) == int(masks[rot]), "rotation: %s at %d quarter turns" % [type, rot])


func _test_full_turn_returns_home() -> void:
	for type in PipeDefs.BASE_MASKS.keys():
		var m := PipeDefs.mask_for(type, 0)
		check(Dirs.rotate_mask(m, 4) == m, "four turns return %s to start" % type)
	check(Dirs.rotate_mask(3, -1) == 9, "negative turns rotate counter-clockwise")


func _test_non_rotatable_pieces() -> void:
	var b := BoardModel.new(2, 1)
	b.set_cell(Vector2i(0, 0), PipeDefs.CROSS, 0)
	check(not b.rotate_cell(Vector2i(0, 0)), "cross is not rotatable")
	check(not b.rotate_cell(Vector2i(1, 0)), "empty cell is not rotatable")
	check(not b.rotate_cell(Vector2i(5, 5)), "out-of-bounds rotate is rejected")


func _test_model_rotation_and_copy() -> void:
	var b := _board(["I0 L0"], Vector2i(0, 0), Vector2i(1, 0))
	var original := b.copy()
	for i in 5:
		b.rotate_cell(Vector2i(1, 0))
	check(b.get_rot(Vector2i(1, 0)) == 1, "five taps equal one tap (mod 4)")
	check(original.get_rot(Vector2i(1, 0)) == 0, "copy is independent of the original")
	var again := _board(["I0 L0"], Vector2i(0, 0), Vector2i(1, 0))
	check(again.get_rot(Vector2i(1, 0)) == 0, "rebuilding from data restores the start state (reset)")


func _test_straight_line_success() -> void:
	var r := FlowSolver.solve(_board(["I1 I1 I1"], Vector2i(0, 0), Vector2i(2, 0)))
	check(r.reached_sink and r.valid, "straight line reaches the tap and is valid")
	check(r.path.size() == 3, "path has three cells")
	check(r.failure == FlowSolver.FAIL_NONE, "no failure code on success")
	check(r.dead_ends.is_empty(), "no dead ends on a clean line")


func _test_broken_middle_is_dead_end() -> void:
	var r := FlowSolver.solve(_board(["I1 I0 I1"], Vector2i(0, 0), Vector2i(2, 0)))
	check(not r.reached_sink, "broken middle does not reach the tap")
	check(r.failure == FlowSolver.FAIL_NO_ROUTE, "failure is no_route")
	check(r.dead_ends.size() == 1, "exactly one dead end reported")
	var info: Dictionary = r.dead_ends[0]
	check(info["cell"] == Vector2i(0, 0) and int(info["dir"]) == Dirs.E, "dead end is the east opening of the first pipe")
	check(r.order.size() == 1, "water never jumps past the break")


func _test_source_closed() -> void:
	var r := FlowSolver.solve(_board(["I0 I1"], Vector2i(0, 0), Vector2i(1, 0)))
	check(r.failure == FlowSolver.FAIL_SOURCE_CLOSED, "pipe not facing the tank fails with source_closed")
	check(not r.source_connected and r.order.is_empty(), "no water enters a closed source")


func _test_sink_closed_and_edge_leak() -> void:
	# Last pipe L3 opens W and N: it is wet but does not face the tap (east).
	var r := FlowSolver.solve(_board(["I1 L3"], Vector2i(0, 0), Vector2i(1, 0)))
	check(not r.reached_sink and r.sink_cell_wet, "last pipe wet but tap not reached")
	check(r.failure == FlowSolver.FAIL_SINK_CLOSED, "failure is sink_closed")
	var found_edge_leak := false
	for entry in r.dead_ends:
		var info: Dictionary = entry
		if info["cell"] == Vector2i(1, 0) and int(info["dir"]) == Dirs.N:
			found_edge_leak = true
	check(found_edge_leak, "opening toward the board edge counts as a dead end")


func _test_cap_is_not_a_leak() -> void:
	var closed := FlowSolver.solve(_board(["I1 T1 I1", ". C0 ."], Vector2i(0, 0), Vector2i(2, 0)))
	check(closed.reached_sink, "route through a tee reaches the tap")
	check(closed.dead_ends.is_empty(), "end cap closes the tee branch (no leak)")
	var open_branch := FlowSolver.solve(_board(["I1 T1 I1", ". C2 ."], Vector2i(0, 0), Vector2i(2, 0)))
	check(open_branch.reached_sink and not open_branch.valid, "mis-turned cap: the tap is reachable but the branch leaks, so the route is NOT valid")
	check(open_branch.dead_ends.size() == 1, "mismatched cap leaves one open branch end")


func _test_cycles_terminate() -> void:
	var no_tap := FlowSolver.solve(_board(["I1 T1 L2", ". L0 L3"], Vector2i(0, 0), Vector2i(2, 1)))
	check(no_tap.order.size() == 5, "loop of five pipes is visited exactly once each")
	check(no_tap.failure == FlowSolver.FAIL_SINK_CLOSED, "loop without an opening toward the tap fails cleanly")
	var with_tap := FlowSolver.solve(_board(["I1 T1 L2", ". L0 T3"], Vector2i(0, 0), Vector2i(2, 1)))
	check(with_tap.valid and with_tap.order.size() == 5, "loop with an open tap side succeeds and is sealed")


func _test_determinism() -> void:
	var board := _board(["I1 T1 L2", ". L0 T3"], Vector2i(0, 0), Vector2i(2, 1))
	var a := FlowSolver.solve(board)
	var b := FlowSolver.solve(board)
	var same_depths := a.depth.size() == b.depth.size()
	for key in a.depth.keys():
		if not b.depth.has(key) or a.depth[key] != b.depth[key]:
			same_depths = false
	check(a.order == b.order and a.path == b.path and same_depths, "same board gives identical results")


func _test_token_parsing() -> void:
	check(LevelLoader.parse_token(".")["ok"], "'.' is a valid empty cell")
	check(LevelLoader.parse_token("L3")["ok"], "'L3' is valid")
	check(not LevelLoader.parse_token("Z1")["ok"], "unknown letter is rejected")
	check(not LevelLoader.parse_token("I")["ok"], "piece without rotation digit is rejected")
	check(not LevelLoader.parse_token("I9")["ok"], "rotation above 3 is rejected")
	check(not LevelLoader.parse_token(".1")["ok"], "empty cell with a digit is rejected")


func _test_level_data() -> void:
	var levels := LevelLoader.load_all()
	check(levels.size() == 20, "all 20 Chapter 1 levels load and validate (%d loaded)" % levels.size())
	for entry in levels:
		var level: Dictionary = entry
		var id := int(level["id"])
		var start := LevelLoader.make_board(level, "grid")
		var goal := LevelLoader.make_board(level, "solution")
		check(FlowSolver.solve(goal).valid, "level %d: stored solution is valid (tap reached, nothing leaks)" % id)
		check(not FlowSolver.solve(start).valid, "level %d: start layout is not already valid" % id)
		var par := LevelLoader.par_moves(level)
		check(par > 0, "level %d: par is positive (%d)" % [id, par])
		# Replay the intended taps through the real model: clockwise taps only.
		var taps := LevelLoader.solution_taps(level)
		for key in taps.keys():
			var cell: Vector2i = key
			for i in int(taps[key]):
				start.rotate_cell(cell)
		check(FlowSolver.solve(start).valid, "level %d: replaying the solution taps solves it" % id)
		check(Scoring.stars_for(par, par) == 3, "level %d: par moves earn three stars" % id)


func _test_validation_rejects_bad_levels() -> void:
	var levels := LevelLoader.load_all()
	if levels.is_empty():
		check(false, "validation tests need at least one loaded level")
		return
	var good: Dictionary = levels[0]
	check(LevelLoader.validate_level(good) == "", "known-good level validates")
	var short_rows := good.duplicate(true)
	short_rows["grid"] = ["I0 I1"]
	check(LevelLoader.validate_level(short_rows) != "", "wrong row count is rejected")
	var unsolvable := good.duplicate(true)
	unsolvable["solution"] = good["grid"]
	check(LevelLoader.validate_level(unsolvable) != "", "level whose stored solution does not solve is rejected")
	var missing := good.duplicate(true)
	missing.erase("sink")
	check(LevelLoader.validate_level(missing) != "", "missing field is rejected")


func _test_scoring() -> void:
	check(Scoring.stars_for(8, 8) == 3, "scoring: equal to par is 3 stars")
	check(Scoring.stars_for(11, 8) == 2, "scoring: slightly over par is 2 stars")
	check(Scoring.stars_for(13, 8) == 1, "scoring: far over par is 1 star")


func _test_difficulty_groups() -> void:
	check(Difficulty.for_level_id(1) == Difficulty.EASY and Difficulty.for_level_id(20) == Difficulty.EASY, "chapters: levels 1-20 are easy")
	check(Difficulty.for_level_id(21) == Difficulty.MEDIUM and Difficulty.for_level_id(45) == Difficulty.MEDIUM, "chapters: levels 21-45 are medium")
	check(Difficulty.for_level_id(46) == Difficulty.HARD and Difficulty.for_level_id(75) == Difficulty.HARD, "chapters: levels 46-75 are hard")
	check(Difficulty.for_level_id(76) == Difficulty.EXTREME and Difficulty.for_level_id(100) == Difficulty.EXTREME, "chapters: levels 76-100 are extreme")
	check(not Difficulty.is_valid("nightmare"), "chapters: an unknown difficulty is rejected")
	check(Difficulty.chapter_number(Difficulty.HARD) == 3 and Difficulty.chapter_name(Difficulty.EASY) == "Learn to Read the Pipes", "chapters: numbers and names")
	var boundaries := true
	for chapter in Difficulty.ORDER:
		if Difficulty.for_level_id(Difficulty.first_id(chapter)) != chapter or Difficulty.for_level_id(Difficulty.last_id(chapter)) != chapter:
			boundaries = false
	check(boundaries and Difficulty.is_chapter_last(20) and Difficulty.is_chapter_last(45) and Difficulty.is_chapter_last(75) and Difficulty.is_chapter_last(100) and not Difficulty.is_chapter_last(19), "chapters: first/last ids and the chapter-finale levels 20/45/75/100")
	var first_level: Dictionary = LevelLoader.load_all()[0]
	var bad: Dictionary = first_level.duplicate(true)
	bad["difficulty"] = "nightmare"
	check(LevelLoader.validate_level(bad) != "", "chapters: a level with an unknown difficulty is rejected")
	var misfiled: Dictionary = first_level.duplicate(true)
	misfiled["difficulty"] = "hard"
	check(LevelLoader.validate_level(misfiled) != "", "chapters: a level filed under the wrong chapter is rejected")


func _test_save_data_sanitising() -> void:
	check(SaveData.from_variant(null).highest_unlocked == 1, "save: null gives a fresh save")
	check(SaveData.from_variant("garbage").total_score == 0, "save: non-dictionary gives a fresh save")
	check(SaveData.from_variant([1, 2, 3]).highest_unlocked == 1, "save: array gives a fresh save")
	var weird := SaveData.from_variant({
		"total_score": -50,
		"highest_unlocked": "7",
		"last_level": 999999,
		"settings": {"sfx": "yes", "vibration": false},
		"levels": {
			"3": {"completed": true, "best_moves": -4, "best_stars": 9},
			"x": {"completed": true},
			"2": 5,
			"0": {"completed": true},
		},
	})
	check(weird.total_score == 0, "save: negative score is clamped")
	check(weird.highest_unlocked == 7, "save: numeric string unlock value is accepted")
	check(weird.last_level <= weird.highest_unlocked, "save: last level never exceeds the unlocked range")
	check(weird.sfx_on == true and weird.vibration_on == false, "save: invalid bool ignored, valid bool kept")
	check(weird.levels.has(3) and not weird.levels.has(2) and not weird.levels.has(0) and weird.levels.size() == 1, "save: only valid level entries survive")
	var entry3 := weird.info(3)
	check(int(entry3["best_stars"]) == 3 and int(entry3["best_moves"]) == 0, "save: stars and moves are clamped")
	var implied := SaveData.from_variant({"highest_unlocked": 1, "levels": {"4": {"completed": true, "best_moves": 5, "best_stars": 2}}})
	check(implied.highest_unlocked == 5, "save: a completed level implies the next one is unlocked")
	var floaty := SaveData.from_variant({"highest_unlocked": 4.0, "total_score": 12.0})
	check(floaty.highest_unlocked == 4 and floaty.total_score == 12, "save: JSON-style floats are accepted as ints")


func _test_save_data_progression() -> void:
	var s := SaveData.new()
	check(s.is_unlocked(1) and not s.is_unlocked(2), "progress: only level 1 starts unlocked")
	check(s.record_completion(2, 5, 3, 5).is_empty(), "progress: a locked level cannot be completed")
	check(s.highest_unlocked == 1 and not s.has_progress(), "progress: rejected completion changes nothing")
	check(s.resume_level(5) == 1, "progress: fresh save resumes at level 1")

	var first := s.record_completion(1, 9, 2, 5)
	check(first["first_completion"] and int(first["newly_unlocked"]) == 2, "progress: first completion unlocks level 2")
	check(s.is_unlocked(2) and s.resume_level(5) == 2, "progress: resume moves to the next unfinished level")

	var worse := s.record_completion(1, 12, 1, 5)
	check(not worse["first_completion"] and int(worse["newly_unlocked"]) == 0, "progress: replaying is not a first completion and unlocks nothing")
	check(int(s.info(1)["best_moves"]) == 9 and int(s.info(1)["best_stars"]) == 2, "progress: a worse run never lowers the records")

	var better := s.record_completion(1, 8, 3, 5)
	check(better["new_best_moves"] and better["new_best_stars"], "progress: a better run improves the records")
	check(int(s.info(1)["best_moves"]) == 8 and int(s.info(1)["best_stars"]) == 3, "progress: records show the best values")
	check(s.highest_unlocked == 2, "progress: replaying level 1 does not unlock extra levels")
	check(s.total_stars() == 3, "progress: total stars add up best stars")

	s.highest_unlocked = 5
	s.record_completion(5, 3, 3, 5)
	check(s.highest_unlocked == 5, "progress: unlocks are capped at the number of levels")
	check(s.resume_level(5) == 5, "progress: all done resumes at the last level played")
	check(s.record_completion(6, 1, 3, 5).is_empty(), "progress: out-of-range level id is rejected")


func _test_save_data_round_trip() -> void:
	var s := SaveData.new()
	s.sfx_on = false
	s.record_completion(1, 8, 3, 5)
	s.record_completion(2, 11, 2, 5)
	var text := JSON.stringify(s.to_dict())
	var back := SaveData.from_variant(JSON.parse_string(text))
	check(back.highest_unlocked == s.highest_unlocked, "round trip: unlocked levels survive JSON")
	check(int(back.info(2)["best_moves"]) == 11 and int(back.info(2)["best_stars"]) == 2, "round trip: records survive JSON (int keys restored)")
	check(back.sfx_on == false and back.vibration_on == true, "round trip: settings survive JSON")
	check(back.is_completed(1) and not back.is_completed(3), "round trip: completion flags survive JSON")


func _test_save_store_files() -> void:
	var main_path := "user://pipeflow_test_main.json"
	var backup_path := "user://pipeflow_test_backup.json"
	_remove_file(main_path)
	_remove_file(backup_path)

	var missing := SaveStore.load_data(main_path, backup_path)
	check(missing.highest_unlocked == 1 and not missing.has_progress(), "store: missing files give a fresh save")

	var s := SaveData.new()
	s.record_completion(1, 8, 3, 5)
	check(SaveStore.save_data(s, main_path, backup_path), "store: save reports success")
	var loaded := SaveStore.load_data(main_path, backup_path)
	check(loaded.is_completed(1) and loaded.highest_unlocked == 2, "store: saved progress loads back")

	_write_raw(main_path, "{ this is not json")
	var recovered := SaveStore.load_data(main_path, backup_path)
	check(recovered.is_completed(1), "store: corrupt main file falls back to the backup")

	_write_raw(backup_path, "also broken")
	var fresh := SaveStore.load_data(main_path, backup_path)
	check(fresh.highest_unlocked == 1 and not fresh.has_progress(), "store: both files corrupt gives a fresh save, no crash")

	_write_raw(main_path, "[1,2,3]")
	check(SaveStore.load_data(main_path, backup_path).highest_unlocked == 1, "store: wrong JSON shape gives a fresh save")

	_remove_file(main_path)
	_remove_file(backup_path)


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove(path.get_file())


func _test_art_assets() -> void:
	for path in Art.required_paths():
		check(FileAccess.file_exists(path), "asset exists: %s" % path)
	var art_bounds := Rect2(Vector2.ZERO, MenuArtLayout.ART_SIZE)
	for key in MenuArtLayout.LAYERS.keys():
		var rect: Rect2 = MenuArtLayout.LAYERS[key]
		check(art_bounds.encloses(rect), "menu layer '%s' lies inside the art space" % key)
	check(art_bounds.encloses(MenuArtLayout.WATERFALL_RECT) and art_bounds.encloses(MenuArtLayout.RIVER_RECT), "waterfall and river overlay windows lie inside the art space")
	check(art_bounds.encloses(MenuArtLayout.SAFE_RECT), "safe rect lies inside the art space")


func _edge_endpoints_are_open(mask: int, paths: Array) -> bool:
	for entry in paths:
		var info: Dictionary = entry
		var pts: PackedVector2Array = info["points"]
		for pt in [pts[0], pts[pts.size() - 1]]:
			if pt.is_equal_approx(Vector2(0.5, 0.5)):
				continue
			var matched := false
			for d in 4:
				if pt.is_equal_approx(FlowPlan.edge_mid(d)):
					matched = Dirs.has(mask, d)
			if not matched:
				return false
	return true


func _test_flow_paths() -> void:
	var elbow := FlowPlan.cell_paths(3, Dirs.N)  # N+E elbow, water enters from the north
	check(elbow.size() == 1 and elbow[0]["kind"] == "bend", "paths: an elbow is ONE smooth bend path")
	var pts: PackedVector2Array = elbow[0]["points"]
	check(pts[0].is_equal_approx(FlowPlan.edge_mid(Dirs.N)) and pts[pts.size() - 1].is_equal_approx(FlowPlan.edge_mid(Dirs.E)), "paths: elbow runs from the north opening to the east opening")
	var inside := true
	for pt in pts:
		if pt.x < 0.0 or pt.x > 1.0 or pt.y < 0.0 or pt.y > 1.0:
			inside = false
	check(inside, "paths: the elbow curve stays inside its tile")
	check(pts.size() > 8, "paths: the elbow is sampled finely enough to look round")
	check(_edge_endpoints_are_open(3, elbow), "paths: elbow touches only open sides")

	var straight := FlowPlan.cell_paths(10, Dirs.W)  # E+W straight
	check(straight.size() == 2 and straight[0]["kind"] == "entry" and straight[1]["kind"] == "exit" and int(straight[1]["dir"]) == Dirs.E, "paths: a straight pipe has an entry arm and one exit arm")
	check(_edge_endpoints_are_open(10, straight), "paths: straight pipe never touches its closed north/south sides")

	var tee := FlowPlan.cell_paths(14, Dirs.W)  # E+S+W tee
	var tee_exits := []
	for entry in tee:
		var info: Dictionary = entry
		if info["kind"] == "exit":
			tee_exits.append(int(info["dir"]))
	tee_exits.sort()
	check(tee.size() == 3 and tee_exits == [Dirs.E, Dirs.S], "paths: a tee splits into exactly its two other open sides")
	check(_edge_endpoints_are_open(14, tee), "paths: tee never touches its closed side")
	check(FlowPlan.cell_paths(15, Dirs.N).size() == 4, "paths: a cross has one entry and three exit arms")
	check(FlowPlan.cell_paths(1, Dirs.N).size() == 1, "paths: an end cap only fills its entry arm")
	check(FlowPlan.cell_paths(5, Dirs.E).is_empty(), "paths: entering through a closed side yields no water")


func _test_flow_plan() -> void:
	var board := _board(["I1 I1 I1"], Vector2i(0, 0), Vector2i(2, 0))
	var plan := FlowPlan.build(board, FlowSolver.solve(board))
	check(plan.valid, "plan: a valid route produces a valid plan")
	var a: FlowPlan.CellTiming = plan.cells[Vector2i(0, 0)]
	var b: FlowPlan.CellTiming = plan.cells[Vector2i(1, 0)]
	var c: FlowPlan.CellTiming = plan.cells[Vector2i(2, 0)]
	check(is_equal_approx(a.t_enter, FlowPlan.LEAD_TIME), "plan: water enters the first pipe right after leaving the tank")
	check(is_equal_approx(b.t_enter, float(a.exits[Dirs.E])) and is_equal_approx(c.t_enter, float(b.exits[Dirs.E])), "plan: each pipe is entered exactly when the previous one is full (continuous flow)")
	check(is_equal_approx(plan.t_sink_exit, float(c.exits[Dirs.E])), "plan: the tap is reached when the last pipe is full")
	check(plan.t_sink_exit < plan.t_valve_start and plan.t_valve_start < plan.t_stream_start and plan.t_stream_start < plan.t_pour_end and plan.t_pour_end < plan.t_taper_end and plan.t_taper_end < plan.t_end, "plan: events happen in order: tap reached, valve, stream, tank empty, taper, done")

	check(is_equal_approx(plan.tank_level(0.0), FlowPlan.TANK_FULL), "tank: starts exactly full (nothing drains before water leaves)")
	check(plan.tank_level(plan.t_pour_end) <= FlowPlan.TANK_EMPTY + 0.01, "tank: nearly empty when the stream finishes")
	var monotonic := true
	var previous := 2.0
	var jump := 0.0
	for i in 301:
		var level := plan.tank_level(plan.t_end * float(i) / 300.0)
		if level > previous + 0.0001:
			monotonic = false
		jump = maxf(jump, previous - level if previous < 2.0 else 0.0)
		previous = level
	check(monotonic, "tank: the level never rises during the run")
	check(jump < 0.02, "tank: it drains gradually, never in one sudden drop (max step %.4f)" % jump)
	check(plan.tank_level(plan.t_sink_exit) > FlowPlan.TANK_EMPTY + 0.1, "tank: still holds water while the pipes are filling")

	check(plan.tap_inlet_progress(plan.t_sink_exit - 0.01) == 0.0, "tap: nothing enters the tap before the water arrives")
	check(plan.valve_open(plan.t_sink_exit) == 0.0, "tap: the handle stays closed until water reaches it")
	check(plan.stream_strength(plan.t_stream_start - 0.01) == 0.0, "tap: no stream before the valve has opened")
	check(plan.stream_strength((plan.t_stream_start + plan.t_pour_end) * 0.5) > 0.95, "tap: the stream runs at full strength mid-pour")
	check(plan.stream_strength(plan.t_taper_end + 0.01) == 0.0, "tap: the stream ends completely")
	var valve_ok := true
	var last_valve := -1.0
	for i in 101:
		var v := plan.valve_open(plan.t_valve_start + FlowPlan.VALVE_TIME * float(i) / 100.0)
		if v < last_valve:
			valve_ok = false
		last_valve = v
	check(valve_ok and is_equal_approx(last_valve, 1.0), "tap: the handle turns smoothly to fully open")

	# cycle: water must visit each pipe once and the plan must still be finite
	var loop := _board(["I1 T1 L2", ". L0 T3"], Vector2i(0, 0), Vector2i(2, 1))
	var loop_plan := FlowPlan.build(loop, FlowSolver.solve(loop))
	check(loop_plan.valid and loop_plan.cells.size() == 5 and loop_plan.t_end < 20.0, "plan: a cyclic network gives a finite plan with one timing per pipe")


func _test_invalid_route_never_drains() -> void:
	var board := _board(["I1 I0 I1"], Vector2i(0, 0), Vector2i(2, 0))
	var plan := FlowPlan.build(board, FlowSolver.solve(board))
	check(not plan.valid and plan.cells.is_empty(), "invalid: a broken route yields an empty plan")
	var always_full := true
	for i in 50:
		if plan.tank_level(float(i) * 0.2) != FlowPlan.TANK_FULL or plan.stream_strength(float(i) * 0.2) != 0.0 or plan.valve_open(float(i) * 0.2) != 0.0:
			always_full = false
	check(always_full, "invalid: the tank never drains and the tap never opens")
	check(not FlowPlan.build(null, null).valid, "invalid: null inputs give an empty plan, no crash")


func _test_first_problem() -> void:
	var closed_source := _board(["I0 I1"], Vector2i(0, 0), Vector2i(1, 0))
	var p1 := FlowSolver.solve(closed_source).first_problem(closed_source)
	check(p1["cell"] == Vector2i(0, 0) and int(p1["dir"]) == Dirs.W, "problem: a pipe not facing the tank is flagged at the tank side")
	var broken := _board(["I1 I0 I1"], Vector2i(0, 0), Vector2i(2, 0))
	var p2 := FlowSolver.solve(broken).first_problem(broken)
	check(p2["cell"] == Vector2i(0, 0) and int(p2["dir"]) == Dirs.E, "problem: the first dead end met by the water is flagged")
	var sink_closed := _board(["I1 L3"], Vector2i(0, 0), Vector2i(1, 0))
	var p3 := FlowSolver.solve(sink_closed).first_problem(sink_closed)
	check(p3["cell"] == Vector2i(1, 0) and int(p3["dir"]) == Dirs.E, "problem: a last pipe not facing the tap is flagged at the tap side")
	var solved := _board(["I1 I1 I1"], Vector2i(0, 0), Vector2i(2, 0))
	check(FlowSolver.solve(solved).first_problem(solved).is_empty(), "problem: a solved route has nothing to flag")


func _test_level_plans() -> void:
	for entry in LevelLoader.load_all():
		var level: Dictionary = entry
		var id := int(level["id"])
		var board := LevelLoader.make_board(level, "solution")
		var result := FlowSolver.solve(board)
		var plan := FlowPlan.build(board, result)
		check(plan.valid and plan.cells.size() == result.order.size(), "level %d: every wet pipe has an animation timing" % id)
		check(plan.t_end > 2.0 and plan.t_end < 30.0, "level %d: the animation lasts a sensible time (%.1fs)" % [id, plan.t_end])
		var ordered := true
		for key in plan.cells.keys():
			var timing: FlowPlan.CellTiming = plan.cells[key]
			if timing.t_center <= timing.t_enter:
				ordered = false
			for dir in timing.exits.keys():
				if float(timing.exits[dir]) <= timing.t_center:
					ordered = false
				if not Dirs.has(timing.mask, int(dir)):
					ordered = false
		check(ordered, "level %d: water reaches each pipe's centre before its exits, and only through open sides" % id)


# ---------------------------------------------------------------------------------------------
# Sealed-network rule: a route is valid only if the tap is reached AND no reachable open end leaks.
# ---------------------------------------------------------------------------------------------

func _leaks_at(result: FlowSolver.FlowResult, cell: Vector2i, dir: int) -> bool:
	for entry in result.dead_ends:
		var info: Dictionary = entry
		if info["cell"] == cell and int(info["dir"]) == dir:
			return true
	return false


func _test_sealed_network_rule() -> void:
	# 1. reciprocal openings
	var ok_board := _board(["I1 I1"], Vector2i(0, 0), Vector2i(1, 0))
	var ok := FlowSolver.solve(ok_board)
	check(ok.valid and ok.dead_ends.is_empty(), "rule 1: adjacent pipes with reciprocal openings connect, nothing leaks")

	# 2. mismatched openings (the elbow opens E+S, so it has no west opening to meet the straight)
	var bad := FlowSolver.solve(_board(["I1 L1"], Vector2i(0, 0), Vector2i(1, 0)))
	check(not bad.reached_sink and not bad.valid and _leaks_at(bad, Vector2i(0, 0), Dirs.E), "rule 2: mismatched openings do not connect and the open end is reported")

	# 3. reachable dead end: the tee's south opening meets the closed side of a straight pipe
	var dead := _board(["I1 T1 I1", "I1 I1 I1"], Vector2i(0, 0), Vector2i(2, 0))
	var dead_r := FlowSolver.solve(dead)
	check(dead_r.reached_sink and not dead_r.valid and dead_r.failure == FlowSolver.FAIL_LEAK and dead_r.dead_ends.size() == 1 and _leaks_at(dead_r, Vector2i(1, 0), Dirs.S), "rule 3: a reachable dead end makes the route invalid even though the tap is reached")

	# 4. reachable open end facing an EMPTY cell
	var empty_board := _board(["I1 T1 I1", ". L0 ."], Vector2i(0, 0), Vector2i(2, 0))
	var empty_r := FlowSolver.solve(empty_board)
	check(empty_r.reached_sink and not empty_r.valid and _leaks_at(empty_r, Vector2i(1, 1), Dirs.E), "rule 4: an open end facing an empty cell is a leak")

	# 5. reachable open end facing OUTSIDE the board (tee opens W+N+E; north is the board edge)
	var outside_r := FlowSolver.solve(_board(["I1 T3 I1"], Vector2i(0, 0), Vector2i(2, 0)))
	check(outside_r.reached_sink and not outside_r.valid and _leaks_at(outside_r, Vector2i(1, 0), Dirs.N), "rule 5: an open end facing outside the board is a leak")

	# 6. correctly capped end
	var capped := _board(["I1 T1 I1", ". C0 ."], Vector2i(0, 0), Vector2i(2, 0))
	var capped_r := FlowSolver.solve(capped)
	check(capped_r.valid and capped_r.dead_ends.is_empty(), "rule 6: a cap whose opening faces the pipe seals the end")

	# 7. incorrectly oriented cap, in every wrong rotation
	for rot in [1, 2, 3]:
		var wrong := _board(["I1 T1 I1", ". C%d ." % rot], Vector2i(0, 0), Vector2i(2, 0))
		var wrong_r := FlowSolver.solve(wrong)
		check(wrong_r.reached_sink and not wrong_r.valid and _leaks_at(wrong_r, Vector2i(1, 0), Dirs.S), "rule 7: cap rotated %d quarter turn(s) does NOT seal the tee (no false connection)" % rot)

	# 8. valid route with no leaks: every shipped level solution
	for entry in LevelLoader.load_all():
		var level: Dictionary = entry
		var solved := FlowSolver.solve(LevelLoader.make_board(level, "solution"))
		check(solved.valid and solved.dead_ends.is_empty(), "rule 8: level %d solution is valid with zero leaks" % int(level["id"]))

	# 9. route that reaches the tap but has a leaking branch is rejected, and the animation plan refuses it
	check(not empty_r.valid and not FlowPlan.build(empty_board, empty_r).valid, "rule 9: tap reached + leaking branch = invalid, no animation plan")
	check(empty_r.first_problem(empty_board)["cell"] == Vector2i(1, 1) and int(empty_r.first_problem(empty_board)["dir"]) == Dirs.E, "rule 9: the first leak is the one highlighted")

	# 10. cycles terminate: sealed cycle is valid, a cycle with a leak is not
	var loop := _board(["I1 T1 L2", ". L0 T3"], Vector2i(0, 0), Vector2i(2, 1))
	var loop_r := FlowSolver.solve(loop)
	check(loop_r.valid and loop_r.order.size() == 5, "rule 10: a sealed cycle is valid and visits each pipe once")
	var leaky_loop := _board(["I1 T1 L2", ". T0 T3"], Vector2i(0, 0), Vector2i(2, 1))
	var leaky_r := FlowSolver.solve(leaky_loop)
	check(leaky_r.reached_sink and not leaky_r.valid and leaky_r.order.size() == 5, "rule 10: a cycle with a leak terminates and is rejected")

	# 11. rotations: covered by the rotation table above; here the leak rule follows a rotated tee
	var tee_rotations_ok := 0
	for rot in 4:
		var single := BoardModel.new(1, 1)
		single.source_cell = Vector2i(0, 0)
		single.sink_cell = Vector2i(0, 0)
		single.set_cell(Vector2i(0, 0), PipeDefs.TEE, rot)
		var r := FlowSolver.solve(single)
		# a lone tee can never be valid: its third opening always faces outside the 1x1 board
		if not r.valid:
			tee_rotations_ok += 1
	check(tee_rotations_ok == 4, "rule 11: a lone tee leaks in all four rotations (its spare opening always faces outside)")


## The exact layout from the bug screenshots (it was Level 4 of the first campaign): tee at (1,0) over a cap at (1,1).
func _screenshot_board() -> BoardModel:
	return _board(["I1 T1 L2 L1", "I0 C0 I0 I1", "L1 I1 L0 L2", "I1 L0 I0 L0"], Vector2i(0, 0), Vector2i(3, 3))


func _test_screenshot_regression() -> void:
	# Tee at (1,0) pointing south into the BACK of the cap at (1,1) (cap rotated to open south).
	# The tap was reachable, so the old rule let water flow.
	var board := _screenshot_board()
	check(FlowSolver.solve(board).valid, "screenshot: the layout with the cap turned correctly is valid")
	board.set_cell(Vector2i(1, 1), PipeDefs.CAP, 2)
	var result := FlowSolver.solve(board)
	check(result.reached_sink, "screenshot: the tap is still reachable (this is why the old rule accepted it)")
	check(not result.valid and result.failure == FlowSolver.FAIL_LEAK, "screenshot: the route is now INVALID with failure 'leak'")
	check(_leaks_at(result, Vector2i(1, 0), Dirs.S), "screenshot: the leak is the tee's south opening")
	var problem := result.first_problem(board)
	check(problem["cell"] == Vector2i(1, 0) and int(problem["dir"]) == Dirs.S, "screenshot: that opening is the highlighted first problem")
	check(not FlowPlan.build(board, result).valid, "screenshot: no animation plan is created, so the tank cannot drain")


func _test_caps_in_levels() -> void:
	# Caps the solution actually uses (water reaches them) seal only in their stored rotation; the other three
	# leave a leak. Decoy caps that the water never reaches may sit in any rotation, so they are skipped.
	for entry in LevelLoader.load_all():
		var level: Dictionary = entry
		var solution := LevelLoader.make_board(level, "solution")
		var wet := FlowSolver.solve(solution).order
		for cell in wet:
			if solution.get_type(cell) != PipeDefs.CAP:
				continue
			var correct := solution.get_rot(cell)
			var all_right := true
			for rot in 4:
				var trial := solution.copy()
				trial.set_cell(cell, PipeDefs.CAP, rot)
				if FlowSolver.solve(trial).valid != (rot == correct):
					all_right = false
			check(all_right, "level %d: the cap at (%d,%d) seals only when it faces its pipe" % [int(level["id"]), cell.x, cell.y])


# ---------------------------------------------------------------------------------------------
# BoardView (node) tests: animation consumes only the validated result.
# ---------------------------------------------------------------------------------------------

func _make_view(board: BoardModel) -> Variant:
	var view := BoardView.new()
	root.add_child(view)
	view.size = Vector2(1000.0, 900.0)
	view.build(board)
	return view


func _run_flow(view: Variant, max_steps: int = 3000) -> void:
	var guard := 0
	while view._flow_active and guard < max_steps:
		view._process(0.05)
		guard += 1


func _test_board_view_flow_safety() -> void:
	var level: Dictionary = LevelLoader.load_all()[0]
	var board := LevelLoader.make_board(level, "solution")
	var result := FlowSolver.solve(board)

	# 12a. Reset during an active flow animation restores everything
	var view: Variant = _make_view(board)
	var events: Array = []
	view.flow_finished.connect(func(ok: bool) -> void: events.append(ok))
	view.play_flow(result)
	check(view._flow_active, "view: a valid route starts the animation")
	for i in 12:
		view._process(0.05)
	check(view._tank.level < FlowPlan.TANK_FULL, "view: the tank is draining mid-flow")
	var time_before: float = view._flow_time
	view.play_flow(result)   # repeated Start Water press while running
	check(is_equal_approx(view._flow_time, time_before), "view: a repeated Start Water press does not restart or overlap the animation")
	view.stop_flow()
	view.clear_water()
	check(not view._flow_active and view._plan == null, "view: reset cancels the running animation")
	check(is_equal_approx(view._tank.level, FlowPlan.TANK_FULL) and view._tank.stub_flow == 0.0, "view: reset restores the original full tank")
	check(view._tap.stream == 0.0 and view._tap.valve == 0.0 and view._tap.inlet_flow == 0.0 and view._tap.pool == 0.0, "view: reset closes the tap and removes the stream")
	view._process(0.5)
	check(events.is_empty() and is_equal_approx(view._tank.level, FlowPlan.TANK_FULL), "view: a cancelled flow never reports success afterwards")

	# 13. A valid route finishes exactly once and leaves the tank nearly empty
	view.play_flow(result)
	_run_flow(view)
	check(events == [true], "view: a valid route reports success exactly once")
	view._process(0.5)
	view._process(0.5)
	check(events == [true], "view: no further success is reported after the animation ended")
	check(view._tank.level <= FlowPlan.TANK_EMPTY + 0.01, "view: the tank ends nearly empty after a successful delivery")
	view.queue_free()

	# 14a. An invalid (plain broken) route never drains, never opens the tap, never reports success
	var broken := _board(["I1 I0 I1"], Vector2i(0, 0), Vector2i(2, 0))
	var view2: Variant = _make_view(broken)
	var events2: Array = []
	view2.flow_finished.connect(func(ok: bool) -> void: events2.append(ok))
	view2.play_flow(FlowSolver.solve(broken))
	check(not view2._flow_active and view2._plan == null, "view: an invalid route starts no flow animation")
	view2._emit_blocked()
	check(events2 == [false], "view: an invalid route can only report failure")
	check(is_equal_approx(view2._tank.level, FlowPlan.TANK_FULL) and view2._tap.stream == 0.0 and view2._tap.valve == 0.0, "view: an invalid route does not drain the tank or open the tap")
	view2.queue_free()

	# 14b. The screenshot state (tap reachable + leaking branch) behaves the same, and flags the leak
	var leaky := _screenshot_board()
	leaky.set_cell(Vector2i(1, 1), PipeDefs.CAP, 2)
	var view3: Variant = _make_view(leaky)
	var events3: Array = []
	view3.flow_finished.connect(func(ok: bool) -> void: events3.append(ok))
	view3.play_flow(FlowSolver.solve(leaky))
	check(not view3._flow_active and view3._plan == null, "view: the leaking state starts NO flow animation")
	check(is_equal_approx(view3._tank.level, FlowPlan.TANK_FULL) and view3._tap.stream == 0.0, "view: the leaking state does not drain the tank or run the tap")
	var marked: PipeTile = view3._tiles[Vector2i(1, 0)]
	check(marked._water._leak_mask == (1 << Dirs.S), "view: the leaking opening (tee, south) gets the red marker")
	view3._emit_blocked()
	check(events3 == [false], "view: the leaking state can only report failure")
	view3.queue_free()


func _test_completion_recorded_once() -> void:
	# Points/stars are only ever recorded from a successful completion; this checks the record layer.
	# (A points total does not exist yet; best moves, stars and unlocks are recorded and are idempotent.)
	var save := SaveData.new()
	var first := save.record_completion(1, 8, 3, 5)
	var again := save.record_completion(1, 8, 3, 5)
	check(first["first_completion"] and not again["first_completion"], "records: only the first completion counts as a first completion")
	check(int(again["newly_unlocked"]) == 0 and save.highest_unlocked == 2, "records: replaying the same result unlocks nothing more")
	var fresh := SaveData.new()
	check(fresh.total_stars() == 0 and not fresh.has_progress(), "records: an invalid route never calls record_completion, so nothing is recorded")


# ---------------------------------------------------------------------------------------------
# Campaign data: every level in the files must satisfy the real rules and the schema.
# ---------------------------------------------------------------------------------------------

func _test_campaign_schema() -> void:
	var levels := LevelLoader.load_all()
	var ids: Array = []
	var titles: Dictionary = {}
	var all_ok := true
	for entry in levels:
		var level: Dictionary = entry
		ids.append(int(level["id"]))
		var title := str(level.get("title", ""))
		if title == "" or titles.has(title):
			all_ok = false
		titles[title] = true
	check(all_ok, "campaign: every level has a unique, non-empty title")
	var contiguous := true
	for i in ids.size():
		if ids[i] != i + 1:
			contiguous = false
	check(contiguous and ids.size() >= 20, "campaign: ids run 1..N with no gaps (%d levels)" % ids.size())

	var first_run := LevelLoader.load_all()
	var second_run := LevelLoader.load_all()
	var same := first_run.size() == second_run.size()
	for i in mini(first_run.size(), second_run.size()):
		var a: Dictionary = first_run[i]
		var b: Dictionary = second_run[i]
		if a["grid"] != b["grid"] or a["solution"] != b["solution"]:
			same = false
	check(same, "campaign: loading twice gives identical levels (deterministic)")

	for entry in levels:
		var level: Dictionary = entry
		var id := int(level["id"])
		var needed := 0
		var turns := LevelLoader.solution_taps(level)
		for key in turns.keys():
			needed += int(turns[key])
		check(LevelLoader.par_moves(level) == needed and needed >= 1, "level %d: par (%d) equals the taps the stored solution needs" % [id, needed])
		check(Difficulty.for_level_id(id) == LevelLoader.difficulty_of(level), "level %d: filed under the right chapter" % id)
		check(str(level.get("expected", "valid")) == "valid", "level %d: expected outcome is 'valid'" % id)

	# Validation really rejects bad data
	var good: Dictionary = levels[0]
	var wrong_par: Dictionary = good.duplicate(true)
	wrong_par["par"] = int(good["par"]) + 3
	check(LevelLoader.validate_level(wrong_par) != "", "campaign: a par that does not match the stored solution is rejected")
	var bad_limit: Dictionary = good.duplicate(true)
	bad_limit["move_limit"] = 1
	check(LevelLoader.validate_level(bad_limit) != "", "campaign: a move limit below what the solution needs is rejected")
	var bad_expected: Dictionary = good.duplicate(true)
	bad_expected["expected"] = "leak"
	check(LevelLoader.validate_level(bad_expected) != "", "campaign: an unexpected 'expected' outcome is rejected")
	var no_title: Dictionary = good.duplicate(true)
	no_title["title"] = "  "
	check(LevelLoader.validate_level(no_title) != "", "campaign: an empty title is rejected")
	var solved_start: Dictionary = good.duplicate(true)
	solved_start["grid"] = good["solution"]
	check(LevelLoader.validate_level(solved_start) != "", "campaign: a level that starts already solved is rejected")
	check(LevelLoader.validate_level(good) == "", "campaign: the unmodified first level validates")


func _test_chapter_progress_helpers() -> void:
	var save := SaveData.new()
	save.highest_unlocked = 20
	for id in range(1, 21):
		save.levels[id] = {"completed": true, "best_moves": 5, "best_stars": 3 if id % 2 == 0 else 2}
	check(save.completed_count_in_range(1, 20) == 20 and save.completed_count_in_range(21, 45) == 0, "chapter progress: completed levels are counted per chapter range")
	check(save.stars_in_range(1, 20) == 50 and save.stars_in_range(1, 10) == 25, "chapter progress: stars are summed per range")
	save.levels.erase(7)
	check(save.completed_count_in_range(1, 20) == 19, "chapter progress: a missing level is not counted")
