extends Control
## Home screen. The game always starts here, never inside a level.
## Play/Continue -> the most appropriate unlocked level; Levels -> level
## select; Settings -> settings overlay. Android Back quits from this screen.
##
## Layout: illustrated MenuStage behind a column of UI (logo, three buttons,
## version). The column uses containers + the design-system sizes, so it adapts
## to any portrait aspect ratio and respects the safe-area insets.

const SIDE_MARGIN := 40

var _total_levels: int = 0
var _logo: TextureRect
var _buttons: Array[Button] = []
var _settings: SettingsOverlay
var _play_btn: Button


func _ready() -> void:
	_total_levels = LevelLoader.load_all().size()
	_build_ui()
	_play_intro()


func _build_ui() -> void:
	var stage := MenuStage.new()
	add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets := UiKit.safe_margins(self, SIDE_MARGIN)
	margin.add_theme_constant_override("margin_left", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", insets.x)
	margin.add_theme_constant_override("margin_bottom", insets.y)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", DS.SP_MD)
	margin.add_child(column)

	column.add_child(_spacer(0.7))

	_logo = TextureRect.new()
	_logo.texture = Art.ui("logo")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.custom_minimum_size = Vector2(0.0, 540.0)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.center_pivot(_logo)
	column.add_child(_logo)

	column.add_child(_spacer(1.0))

	var save := SaveManager.data
	var play_text := "Play"
	if save.has_progress():
		play_text = "Continue"
	_play_btn = _menu_button(column, play_text, GameButton.GREEN, DS.BTN_H_PRIMARY, DS.T_BUTTON_PRIMARY, "play")
	_play_btn.pressed.connect(_on_play_pressed)
	if _total_levels == 0:
		_play_btn.disabled = true
	_menu_button(column, "Levels", GameButton.WOOD, DS.BTN_H, DS.T_BUTTON, "levels").pressed.connect(_on_levels_pressed)
	_menu_button(column, "Settings", GameButton.WOOD, DS.BTN_H, DS.T_BUTTON, "settings").pressed.connect(_on_settings_pressed)

	column.add_child(_spacer(0.9))

	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var footer := UiKit.make_plain_label("v%s" % version, DS.T_SMALL, Color(1.0, 1.0, 1.0, 0.65))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(footer)

	_settings = SettingsOverlay.new()
	add_child(_settings)
	_settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _spacer(ratio: float) -> Control:
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.size_flags_stretch_ratio = ratio
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return space


func _menu_button(parent: Control, text: String, kind: String, height: int, font_size: int, icon_name: String) -> Button:
	var btn := GameButton.create(text, kind, height, font_size, icon_name)
	btn.custom_minimum_size.x = float(DS.BTN_W_MENU)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(btn)
	_buttons.append(btn)
	return btn


func _play_intro() -> void:
	_logo.modulate.a = 0.0
	_logo.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_logo, "modulate:a", 1.0, DS.DUR_SLOW)
	tw.tween_property(_logo, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var delay := 0.35
	for btn in _buttons:
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.85, 0.85)
		tw.tween_property(btn, "modulate:a", 1.0, 0.3).set_delay(delay)
		tw.tween_property(btn, "scale", Vector2.ONE, DS.DUR_SLOW).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay += 0.14

	var sway := create_tween().set_loops()
	sway.tween_property(_logo, "rotation", 0.012, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(_logo, "rotation", -0.012, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_play_pressed() -> void:
	if _total_levels == 0:
		return
	Nav.play_level(SaveManager.data.resume_level(_total_levels))


func _on_levels_pressed() -> void:
	Nav.go(Nav.LEVELS_SCENE)


func _on_settings_pressed() -> void:
	_settings.open()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _settings != null and _settings.visible:
			_settings.close()
		else:
			SaveManager.save()
			get_tree().quit()
