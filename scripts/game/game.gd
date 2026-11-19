extends Control
## Gameplay screen. Owns the level session (moves, state machine) and the HUD.
## All pipe/connection rules live in scripts/core; this file only orchestrates.
##
## States:
##   PLAYING  - taps rotate pipes
##   FLOWING  - water animation running (taps and Start are ignored; Reset works)
##   FAILED   - route incomplete; first tap clears the water, Start can be re-run
##   COMPLETE - tap reached; progress saved exactly once; completion panel is up
##
## The level to play comes from Nav.selected_level_id. Leaving the screen at any
## moment is safe: no awaits, only node-bound tweens, so nothing outlives the scene.

enum State { PLAYING, FLOWING, FAILED, COMPLETE }

const MSG_INFO := "info"
const MSG_ERROR := "error"
const MSG_SUCCESS := "success"
const SIDE_MARGIN := 28

var _levels: Array = []
var _level_index: int = 0
var _level: Dictionary = {}
var _board: BoardModel
var _par: int = 0
var _moves: int = 0
var _state: int = State.PLAYING
var _run_id: int = 0  # bumps on every (re)start so stale callbacks can bail out
var _pending_result: FlowSolver.FlowResult

var _margin: MarginContainer
var _board_view: BoardView
var _level_label: Label
var _title_label: Label
var _moves_label: Label
var _stars: StarRow
var _message_panel: PanelContainer
var _message_label: Label
var _pause_btn: Button
var _reset_btn: Button
var _start_btn: Button

var _overlay: Control
var _dim: ColorRect
var _complete_panel: PanelContainer
var _complete_stars: StarRow
var _complete_stats: Label
var _chapter_label: Label
var _chapter_done: bool = false
var _next_btn: Button
var _replay_btn: Button
var _home_btn: Button

var _pause_overlay: PauseOverlay
var _settings_overlay: SettingsOverlay


func _ready() -> void:
	_build_ui()
	_levels = LevelLoader.load_all()
	if _levels.is_empty():
		_reset_btn.disabled = true
		_start_btn.disabled = true
		_set_message("No playable levels were found. Check the files in data/levels/.", MSG_ERROR)
		return
	var start_index := _index_of_level(Nav.selected_level_id)
	if start_index < 0 or not SaveManager.data.is_unlocked(int(_levels[start_index]["id"])):
		start_index = maxi(0, _index_of_level(SaveManager.data.resume_level(_levels.size())))
	_load_level(start_index)


func _index_of_level(id: int) -> int:
	for i in _levels.size():
		var level: Dictionary = _levels[i]
		if int(level["id"]) == id:
			return i
	return -1


# ---------------------------------------------------------------- UI building

func _build_ui() -> void:
	# Backdrop: baked soft texture (cover-scaled, never stretched). No code-drawn shapes.
	var backdrop := TextureRect.new()
	backdrop.texture = Art.game("bg_game")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_margin = MarginContainer.new()
	add_child(_margin)
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_margins()
	resized.connect(_apply_margins)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	_margin.add_child(column)

	column.add_child(_build_top_bar())

	_board_view = BoardView.new()
	_board_view.custom_minimum_size = Vector2(300.0, 400.0)
	_board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_view.tile_tapped.connect(_on_tile_tapped)
	_board_view.flow_finished.connect(_on_flow_finished)
	column.add_child(_board_view)

	column.add_child(_build_message_panel())
	column.add_child(_build_button_row())
	_build_complete_overlay()

	_pause_overlay = PauseOverlay.new()
	add_child(_pause_overlay)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.resume_requested.connect(_close_pause)
	_pause_overlay.restart_requested.connect(_on_pause_restart)
	_pause_overlay.settings_requested.connect(_on_pause_settings)
	_pause_overlay.levels_requested.connect(_on_levels_pressed)
	_pause_overlay.home_requested.connect(_on_home_pressed)

	# Added last so it sits above the pause panel and gets Esc/Back first.
	_settings_overlay = SettingsOverlay.new()
	add_child(_settings_overlay)
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.wood_panel())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	_pause_btn = Button.new()
	_pause_btn.custom_minimum_size = Vector2(120.0, 120.0)
	_pause_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.style_button(_pause_btn, UiKit.BLUE, UiKit.BLUE_DARK)
	var glyph := IconGlyph.new()
	glyph.kind = "pause"
	_pause_btn.add_child(glyph)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_btn.pressed.connect(_open_pause)
	row.add_child(_pause_btn)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	_level_label = UiKit.make_label("Level 1", 72, UiKit.PARCHMENT)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_level_label)

	_title_label = UiKit.make_plain_label("", DS.T_SMALL + 4, Color(UiKit.PARCHMENT, 0.9))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_title_label)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 28)
	info.add_child(stats)

	_stars = StarRow.new()
	_stars.custom_minimum_size = Vector2(230.0, 62.0)
	stats.add_child(_stars)

	_moves_label = UiKit.make_label("Moves: 0   Par: 0", 44, UiKit.PARCHMENT)
	_moves_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats.add_child(_moves_label)

	var balance := Control.new()  # keeps the title centred opposite the pause button
	balance.custom_minimum_size = Vector2(120.0, 120.0)
	row.add_child(balance)
	return panel


func _build_message_panel() -> Control:
	_message_panel = PanelContainer.new()
	_message_panel.custom_minimum_size = Vector2(0.0, 130.0)
	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.add_theme_font_size_override("font_size", 38)
	_message_panel.add_child(_message_label)
	_set_message("", MSG_INFO)
	return _message_panel


func _build_button_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DS.SP_MD)

	_reset_btn = Button.new()
	_reset_btn.text = "Reset"
	_reset_btn.custom_minimum_size = Vector2(280.0, 140.0)
	UiKit.style_button(_reset_btn, UiKit.BLUE, UiKit.BLUE_DARK, 52)
	_reset_btn.pressed.connect(_on_reset_pressed)
	row.add_child(_reset_btn)

	_start_btn = Button.new()
	_start_btn.text = "Start Water"
	_start_btn.custom_minimum_size = Vector2(0.0, 140.0)
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.style_button(_start_btn, UiKit.GREEN, UiKit.GREEN_DARK, 52)
	GameButton.add_centered_icon(_start_btn, Art.ui("icon_play_btn"))
	_start_btn.pressed.connect(_on_start_pressed)
	row.add_child(_start_btn)
	return row


func _build_complete_overlay() -> void:
	_overlay = Control.new()
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.1, 0.06, 0.62)
	_overlay.add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_complete_panel = PanelContainer.new()
	_complete_panel.custom_minimum_size = Vector2(840.0, 0.0)
	_complete_panel.add_theme_stylebox_override("panel", UiKit.parchment_panel())
	center.add_child(_complete_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	_complete_panel.add_child(box)

	var title := UiKit.make_label("Level Complete!", 84, UiKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_chapter_label = UiKit.make_label("", 40, UiKit.GOLD)
	_chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chapter_label.visible = false
	box.add_child(_chapter_label)

	_complete_stars = StarRow.new()
	_complete_stars.custom_minimum_size = Vector2(540.0, 140.0)
	_complete_stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_complete_stars)

	_complete_stats = UiKit.make_plain_label("", 48, UiKit.INK)
	_complete_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_complete_stats)

	_next_btn = Button.new()
	_next_btn.text = "Next Level"
	_next_btn.custom_minimum_size = Vector2(0.0, 150.0)
	UiKit.style_button(_next_btn, UiKit.GREEN, UiKit.GREEN_DARK)
	_next_btn.pressed.connect(_on_next_pressed)
	box.add_child(_next_btn)

	_replay_btn = Button.new()
	_replay_btn.text = "Replay"
	_replay_btn.custom_minimum_size = Vector2(0.0, 125.0)
	UiKit.style_button(_replay_btn, UiKit.BLUE, UiKit.BLUE_DARK)
	_replay_btn.pressed.connect(_on_replay_pressed)
	box.add_child(_replay_btn)

	_home_btn = Button.new()
	_home_btn.text = "Home"
	_home_btn.custom_minimum_size = Vector2(0.0, 125.0)
	UiKit.style_button(_home_btn, UiKit.WOOD_LIGHT, UiKit.WOOD_DARK)
	_home_btn.pressed.connect(_on_complete_home_pressed)
	box.add_child(_home_btn)


## Keeps content clear of notches / system bars (approximate; verify on device).
func _apply_margins() -> void:
	var insets := UiKit.safe_margins(self, SIDE_MARGIN)
	_margin.add_theme_constant_override("margin_left", SIDE_MARGIN)
	_margin.add_theme_constant_override("margin_right", SIDE_MARGIN)
	_margin.add_theme_constant_override("margin_top", insets.x)
	_margin.add_theme_constant_override("margin_bottom", insets.y)


# ------------------------------------------------------------- level session

func _load_level(index: int) -> void:
	if index < 0 or index >= _levels.size():
		return
	_level_index = index
	_level = _levels[index]
	_par = LevelLoader.par_moves(_level)
	_board = LevelLoader.make_board(_level, "grid")
	_board_view.build(_board)
	SaveManager.set_last_level(int(_level["id"]))
	_begin_play()


## Common "fresh attempt" setup, used by load, Reset and Replay.
func _begin_play() -> void:
	_run_id += 1
	_moves = 0
	_chapter_done = false
	_state = State.PLAYING
	_overlay.visible = false
	_pause_btn.disabled = false
	_reset_btn.disabled = false
	_start_btn.disabled = false
	_update_hud()
	_set_message(str(_level.get("hint", "Rotate the pipes to connect the tank to the tap.")), MSG_INFO)


func _update_hud() -> void:
	_level_label.text = "Level %d" % int(_level.get("id", _level_index + 1))
	_title_label.text = str(_level.get("title", ""))
	_moves_label.text = "Moves: %d   Par: %d" % [_moves, _par]
	_stars.filled = Scoring.stars_for(_moves, _par)


func _set_message(text: String, kind: String) -> void:
	var fill := UiKit.PARCHMENT
	var border := UiKit.WOOD_DARK
	if kind == MSG_ERROR:
		fill = Color("fde2dc")
		border = UiKit.CORAL_DARK
	elif kind == MSG_SUCCESS:
		fill = Color("dff5d8")
		border = UiKit.GREEN_DARK
	_message_panel.add_theme_stylebox_override("panel", UiKit.box(fill, border, 28, 5, 0, 18))
	_message_label.add_theme_color_override("font_color", UiKit.INK)
	_message_label.text = text


func _failure_text(result: FlowSolver.FlowResult) -> String:
	if result.failure == FlowSolver.FAIL_SOURCE_CLOSED:
		return "The pipe next to the tank does not open toward it."
	if result.failure == FlowSolver.FAIL_SINK_CLOSED:
		return "Water reached the last pipe, but it does not open toward the tap."
	if result.failure == FlowSolver.FAIL_LEAK:
		return "Water would leak at the red mark. Every open pipe end must meet a pipe or an end cap."
	if result.failure == FlowSolver.FAIL_NO_ROUTE:
		if not result.dead_ends.is_empty():
			return "Water leaks at the red mark. Rotate pipes to close the gap."
		return "The water cannot reach the tap on this route yet."
	return "The water did not reach the tap. Keep trying!"


# ------------------------------------------------------------ pause / back

func _open_pause() -> void:
	if _state == State.COMPLETE or _pause_overlay.visible:
		return
	get_tree().paused = true
	_pause_overlay.open()


func _close_pause() -> void:
	_pause_overlay.close()
	get_tree().paused = false


func _on_pause_restart() -> void:
	_close_pause()
	_on_reset_pressed()


func _on_pause_settings() -> void:
	_settings_overlay.open()


func _on_levels_pressed() -> void:
	Nav.go(Nav.LEVELS_SCENE)


func _on_home_pressed() -> void:
	Nav.go(Nav.MENU_SCENE)


## Android Back / Esc: close what is open, else pause, else leave the level.
func _go_back() -> void:
	if _settings_overlay.visible:
		_settings_overlay.close()
	elif _pause_overlay.visible:
		_close_pause()
	elif _state == State.COMPLETE:
		Nav.go(Nav.LEVELS_SCENE)
	else:
		_open_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------- input

func _on_tile_tapped(cell: Vector2i) -> void:
	if _state == State.FLOWING or _state == State.COMPLETE:
		return
	if not _board.can_rotate(cell):
		return
	if _state == State.FAILED:
		_board_view.clear_water()
		_state = State.PLAYING
		_start_btn.disabled = false
		_set_message("Press Start Water when the pipes connect.", MSG_INFO)
	_board.rotate_cell(cell)
	_moves += 1
	_board_view.animate_rotation(cell)
	Feedback.play("rotate")
	Feedback.vibrate(10)
	_update_hud()


func _on_start_pressed() -> void:
	if _state != State.PLAYING and _state != State.FAILED:
		return
	_board_view.clear_water()
	_state = State.FLOWING
	_start_btn.disabled = true
	_set_message("Water is flowing...", MSG_INFO)
	Feedback.play("start")
	_pending_result = FlowSolver.solve(_board)
	_board_view.play_flow(_pending_result)


func _on_reset_pressed() -> void:
	if _levels.is_empty():
		return
	_board_view.stop_flow()
	_board = LevelLoader.make_board(_level, "grid")
	_board_view.sync_all(_board)
	_begin_play()


func _on_flow_finished(reached: bool) -> void:
	if _state != State.FLOWING:
		return
	if reached:
		# Single transition into COMPLETE per run: progress is recorded exactly once here.
		_state = State.COMPLETE
		_reset_btn.disabled = true
		_pause_btn.disabled = true
		var stars := Scoring.stars_for(_moves, _par)
		SaveManager.record_completion(int(_level["id"]), _moves, stars, _levels.size())
		_chapter_done = _is_chapter_complete(int(_level["id"]))
		Feedback.play("success")
		Feedback.vibrate(40)
		_set_message("The water reached the tap!", MSG_SUCCESS)
		_board_view.play_victory(_pending_result)
		var wait := create_tween()
		wait.tween_interval(0.9)
		wait.tween_callback(_show_complete.bind(_run_id))
	else:
		_state = State.FAILED
		_start_btn.disabled = false
		Feedback.play("error")
		_set_message(_failure_text(_pending_result), MSG_ERROR)


func _show_complete(run: int) -> void:
	if run != _run_id or _state != State.COMPLETE:
		return
	var earned := Scoring.stars_for(_moves, _par)
	_complete_stars.filled = 0
	_complete_stats.text = "Moves: %d   Par: %d" % [_moves, _par]
	var is_last := _level_index >= _levels.size() - 1
	_next_btn.text = "Level Select" if is_last else "Next Level"
	_chapter_label.visible = _chapter_done
	if _chapter_done:
		var chapter := Difficulty.for_level_id(int(_level["id"]))
		_chapter_label.text = "Chapter %d complete!\n%s" % [Difficulty.chapter_number(chapter), Difficulty.chapter_name(chapter)]
	_dim.modulate.a = 0.0
	_complete_panel.modulate.a = 0.0
	_complete_panel.pivot_offset = _complete_panel.get_combined_minimum_size() * 0.5
	_complete_panel.scale = Vector2(0.7, 0.7)
	_overlay.visible = true

	var pop := create_tween()
	pop.set_parallel(true)
	pop.tween_property(_dim, "modulate:a", 1.0, 0.25)
	pop.tween_property(_complete_panel, "modulate:a", 1.0, 0.2)
	pop.tween_property(_complete_panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var reveal := create_tween()
	reveal.tween_interval(0.35)
	for i in earned:
		reveal.tween_callback(_complete_stars.set.bind("filled", i + 1))
		reveal.tween_interval(0.28)


## True when this level is the last of its chapter and every level of that chapter is now completed.
func _is_chapter_complete(level_id: int) -> bool:
	if not Difficulty.is_chapter_last(level_id):
		return false
	var chapter := Difficulty.for_level_id(level_id)
	var first := Difficulty.first_id(chapter)
	return SaveManager.data.completed_count_in_range(first, level_id) >= level_id - first + 1


func _on_next_pressed() -> void:
	if _state != State.COMPLETE:
		return
	var next_index := _level_index + 1
	if next_index >= _levels.size():
		Nav.go(Nav.LEVELS_SCENE)
		return
	var next_level: Dictionary = _levels[next_index]
	if not SaveManager.data.is_unlocked(int(next_level["id"])):
		Nav.go(Nav.LEVELS_SCENE)
		return
	_load_level(next_index)


func _on_replay_pressed() -> void:
	if _state != State.COMPLETE:
		return
	_on_reset_pressed()


func _on_complete_home_pressed() -> void:
	if _state != State.COMPLETE:
		return
	Nav.go(Nav.MENU_SCENE)
