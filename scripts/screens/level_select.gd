extends Control
## Level selection: three difficulty sections, each with a progress bar.
## Locked levels are disabled and show a padlock; completed levels show the
## best stars earned. Opening a level never changes progress.

const SIDE_MARGIN := 28
const COLUMNS := 4

var _levels: Array = []
var _scroll: ScrollContainer
var _current_button: Button
var _resume_id: int = 1


func _ready() -> void:
	_levels = LevelLoader.load_all()
	_resume_id = SaveManager.data.resume_level(_levels.size())
	_build_ui()
	get_tree().process_frame.connect(_scroll_to_current, CONNECT_ONE_SHOT)


func _build_ui() -> void:
	var scenery := MenuStage.new()
	scenery.dim = 0.38
	add_child(scenery)
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets := UiKit.safe_margins(self, SIDE_MARGIN)
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", insets.x)
	margin.add_theme_constant_override("margin_bottom", insets.y)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)
	column.add_child(_build_top_bar())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 34)
	_scroll.add_child(list)
	for difficulty in Difficulty.ORDER:
		var section := _build_section(difficulty)
		if section != null:
			list.add_child(section)


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.wood_panel())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var back := Button.new()
	back.custom_minimum_size = Vector2(130.0, 110.0)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.style_button(back, UiKit.BLUE, UiKit.BLUE_DARK)
	var glyph := IconGlyph.new()
	glyph.kind = "back"
	back.add_child(glyph)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.pressed.connect(_go_back)
	row.add_child(back)

	var title := UiKit.make_label("Select Level", 64, UiKit.PARCHMENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	var star_box := HBoxContainer.new()
	star_box.add_theme_constant_override("separation", 8)
	star_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var one_star := StarRow.new()
	one_star.total = 1
	one_star.custom_minimum_size = Vector2(54.0, 54.0)
	one_star.filled = 1
	star_box.add_child(one_star)
	var count := UiKit.make_label("%d/%d" % [SaveManager.data.total_stars(), _levels.size() * 3], 42, UiKit.PARCHMENT)
	star_box.add_child(count)
	row.add_child(star_box)
	return panel


## One chapter section, or null when no level of that chapter exists yet (nothing is shown for
## chapters that are not in the build).
func _build_section(difficulty: String) -> Control:
	var group: Array = []
	for entry in _levels:
		var level: Dictionary = entry
		if LevelLoader.difficulty_of(level) == difficulty:
			group.append(level)
	if group.is_empty():
		return null

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.add_child(_build_header(difficulty, group))

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	for entry in group:
		var level: Dictionary = entry
		grid.add_child(_make_level_button(level))
	box.add_child(grid)
	return box


func _build_header(difficulty: String, group: Array) -> Control:
	var color := UiKit.difficulty_color(difficulty)
	var first_id := int(group[0]["id"])
	var last_id := int(group[group.size() - 1]["id"])
	var done := SaveManager.data.completed_count_in_range(first_id, last_id)
	var stars := SaveManager.data.stars_in_range(first_id, last_id)
	var chapter_locked := not SaveManager.data.is_unlocked(first_id)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(color.darkened(0.15), color.darkened(0.55), 28, 5, 0, 18))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var row := HBoxContainer.new()
	box.add_child(row)
	var name_label := UiKit.make_label(Difficulty.label(difficulty), 54, Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var progress_text := "Locked" if chapter_locked else "%d / %d" % [done, group.size()]
	row.add_child(UiKit.make_label(progress_text, 40, Color.WHITE))

	var sub := HBoxContainer.new()
	box.add_child(sub)
	var chapter_label := UiKit.make_plain_label("Chapter %d - %s" % [Difficulty.chapter_number(difficulty), Difficulty.chapter_name(difficulty)], DS.T_SMALL, Color(1.0, 1.0, 1.0, 0.92))
	chapter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.add_child(chapter_label)
	var star_text := UiKit.make_plain_label("Stars %d / %d" % [stars, group.size() * 3], DS.T_SMALL, Color(1.0, 0.93, 0.6))
	sub.add_child(star_text)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, 22.0)
	bar.show_percentage = false
	bar.max_value = maxf(1.0, float(group.size()))
	bar.value = float(done)
	bar.add_theme_stylebox_override("background", UiKit.box(Color(0.0, 0.0, 0.0, 0.35), Color(0.0, 0.0, 0.0, 0.0), 11, 0))
	bar.add_theme_stylebox_override("fill", UiKit.box(Color.WHITE, Color.WHITE, 11, 0))
	box.add_child(bar)
	return panel


func _make_level_button(level: Dictionary) -> Button:
	var id := int(level["id"])
	var info := SaveManager.data.info(id)
	var unlocked := SaveManager.data.is_unlocked(id)
	var completed: bool = info["completed"]
	var group_color := UiKit.difficulty_color(LevelLoader.difficulty_of(level))

	var fill := UiKit.STONE
	var border := UiKit.WOOD_DARK
	var border_w := 6
	if not unlocked:
		fill = Color("5b5f66")
		border = Color("3a3d42")
	elif completed:
		fill = UiKit.STONE.lightened(0.1)
		border = group_color.darkened(0.2)
	elif id == _resume_id:
		fill = UiKit.STONE.lightened(0.18)
		border = UiKit.BLUE
		border_w = 10

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0.0, 210.0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = str(id) if unlocked else ""
	btn.add_theme_font_size_override("font_size", 84)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", UiKit.WOOD_DARK)
	btn.add_theme_constant_override("outline_size", 12)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := UiKit.box(fill, border, 30, border_w, 8)
		if state == "pressed":
			sb = UiKit.box(fill.darkened(0.12), border, 30, border_w, 2)
		sb.content_margin_bottom = 50.0
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	if unlocked:
		UiKit.polish_button(btn)
		btn.pressed.connect(_open_level.bind(id))
		if completed:
			var stars := StarRow.new()
			stars.filled = int(info["best_stars"])
			btn.add_child(stars)
			stars.anchor_left = 0.12
			stars.anchor_right = 0.88
			stars.anchor_top = 0.66
			stars.anchor_bottom = 0.92
	else:
		btn.disabled = true
		var lock := IconGlyph.new()
		lock.kind = "lock"
		lock.color = Color(0.78, 0.8, 0.84)
		btn.add_child(lock)
		lock.anchor_left = 0.2
		lock.anchor_right = 0.8
		lock.anchor_top = 0.15
		lock.anchor_bottom = 0.85

	if id == _resume_id:
		_current_button = btn
	return btn


func _open_level(id: int) -> void:
	Nav.play_level(id)


func _go_back() -> void:
	Nav.go(Nav.MENU_SCENE)


func _scroll_to_current() -> void:
	if _current_button != null and is_instance_valid(_current_button) and _scroll != null:
		_scroll.ensure_control_visible(_current_button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
