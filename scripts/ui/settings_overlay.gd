class_name SettingsOverlay
extends Control
## Reusable settings panel (menu and pause screen both use it).
## Sound effects and vibration toggles are saved immediately.
## Vibration is only shown on devices that can vibrate. There is no music
## toggle yet because the game has no music track; it will be added with one.

signal closed

var _panel: PanelContainer


func _init() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.1, 0.06, 0.7)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(860.0, 0.0)
	_panel.add_theme_stylebox_override("panel", UiKit.parchment_panel())
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 30)
	_panel.add_child(box)

	var title := UiKit.make_label("Settings", 78, UiKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_add_toggle_row(box, "Sound Effects", SaveManager.data.sfx_on, _on_sfx_toggled)
	if Feedback.vibration_supported():
		_add_toggle_row(box, "Vibration", SaveManager.data.vibration_on, _on_vibration_toggled)

	var note := UiKit.make_plain_label("Music will arrive in a later update.", 34, Color(0.45, 0.33, 0.2))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)

	var close_btn := Button.new()
	close_btn.text = "Back"
	close_btn.custom_minimum_size = Vector2(0.0, 140.0)
	UiKit.style_button(close_btn, UiKit.GREEN, UiKit.GREEN_DARK)
	close_btn.pressed.connect(close)
	box.add_child(close_btn)

	UiKit.center_pivot(_panel)


func open() -> void:
	visible = true
	_panel.pivot_offset = _panel.get_combined_minimum_size() * 0.5
	_panel.scale = Vector2(0.85, 0.85)
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _add_toggle_row(parent: Control, text: String, initial: bool, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var label := UiKit.make_plain_label(text, 52, UiKit.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var toggle := ToggleSwitch.new()
	row.add_child(toggle)
	toggle.set_state(initial, false)
	toggle.toggled.connect(callback)
	parent.add_child(row)


func _on_sfx_toggled(on: bool) -> void:
	SaveManager.set_sfx(on)
	if on:
		Feedback.play("click")


func _on_vibration_toggled(on: bool) -> void:
	SaveManager.set_vibration(on)
	if on:
		Feedback.vibrate(30)
