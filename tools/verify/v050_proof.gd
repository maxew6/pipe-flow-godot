extends SceneTree
## Real-scene visual/runtime proof runner. Set PIPEFLOW_CAPTURE_DIR and PIPEFLOW_CAPTURE_SIZE=WxH.
var _capture_dir := ""
var _size := Vector2i(1080, 1920)

func _initialize() -> void:
	var raw_size := OS.get_environment("PIPEFLOW_CAPTURE_SIZE")
	if raw_size.contains("x"):
		var parts := raw_size.split("x")
		_size = Vector2i(int(parts[0]), int(parts[1]))
	_capture_dir = OS.get_environment("PIPEFLOW_CAPTURE_DIR")
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	DisplayServer.window_set_size(_size)
	root.size = _size
	await process_frame
	await process_frame
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _settle(1.0)
	var menu: Variant = current_scene
	await _capture("01-main-menu")
	menu._settings.open()
	await _settle(0.2)
	await _capture("02-settings")
	menu._settings.close()

	change_scene_to_file("res://scenes/level_select.tscn")
	await _settle(0.4)
	await _capture("03-level-select")
	change_scene_to_file("res://scenes/game.tscn")
	await _settle(0.4)
	var game: Variant = current_scene
	await _capture("04-gameplay-idle")
	game._open_pause()
	await _settle(0.2)
	await _capture("05-pause")
	game._close_pause()
	await _settle(0.2)

	# Solve Level 1 through the same Game controller and real BoardView used in play.
	game._board = LevelLoader.make_board(game._level, "solution")
	game._board_view.build(game._board)
	game._on_start_pressed()
	await _settle(0.15)
	await _capture("06-water-start")
	await _settle(0.65)
	await _capture("07-water-mid-stream")
	var plan_end: float = game._board_view._plan.t_end
	var remaining := maxf(0.0, plan_end - game._board_view._flow_time - 0.15)
	await _settle(remaining)
	await _capture("08-water-near-end")
	var guard := 0
	while not game._overlay.visible and guard < 1000:
		await process_frame
		guard += 1
	await _capture("09-level-complete")

	# Regression board from the v0.5 test suite: the tap remains reachable, but
	# the tee opening reaches the wrong face of a cap, so the entire network leaks.
	game._load_level(3)
	var regression := {
		"cols": 4, "rows": 4,
		"source": {"x": 0, "y": 0, "side": "W"},
		"sink": {"x": 3, "y": 3, "side": "E"},
		"grid": ["I1 T1 L2 L1", "I0 C2 I0 I1", "L1 I1 L0 L2", "I1 L0 I0 L0"],
	}
	game._board = LevelLoader.make_board(regression, "grid")
	game._board_view.build(game._board)
	game._begin_play()
	game._on_start_pressed()
	await _settle(0.08)
	await _capture("10-sealed-network-leak-immediate")
	await _settle(0.8)
	await _capture("11-sealed-network-leak-message")
	print("PROOF_OK size=%dx%d captures=11 level4_reachable_leak_rejected=%s message=%s" % [_size.x, _size.y, str(not game._pending_result.valid and game._pending_result.reached_sink), str(game._message_label.text)])
	quit(0)

func _settle(seconds: float) -> void:
	await create_timer(seconds, true).timeout
	await process_frame

func _capture(name: String) -> void:
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var path := _capture_dir.path_join(name + ".png")
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save %s (error %d)" % [path, error])
	else:
		print("CAPTURE %s %dx%d" % [path, image.get_width(), image.get_height()])
