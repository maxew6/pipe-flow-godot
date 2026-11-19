class_name PauseOverlay
extends Control
## Pause panel shown over the game. It keeps processing while the tree is
## paused (PROCESS_MODE_ALWAYS) so its buttons and animation still work.
## It only emits signals; the game screen decides what each one does.

signal resume_requested
signal restart_requested
signal settings_requested
signal levels_requested
signal home_requested

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
	_panel.custom_minimum_size = Vector2(800.0, 0.0)
	_panel.add_theme_stylebox_override("panel", UiKit.parchment_panel())
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	_panel.add_child(box)

	var title := UiKit.make_label("Paused", 82, UiKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_add_button(box, "Resume", UiKit.GREEN, UiKit.GREEN_DARK, 140, resume_requested)
	_add_button(box, "Restart", UiKit.BLUE, UiKit.BLUE_DARK, 120, restart_requested)
	_add_button(box, "Settings", UiKit.WOOD_LIGHT, UiKit.WOOD_DARK, 120, settings_requested)
	_add_button(box, "Levels", UiKit.WOOD_LIGHT, UiKit.WOOD_DARK, 120, levels_requested)
	_add_button(box, "Home", UiKit.WOOD_LIGHT, UiKit.WOOD_DARK, 120, home_requested)


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
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _add_button(parent: Control, text: String, fill: Color, border: Color, height: int, action: Signal) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0.0, float(height))
	UiKit.style_button(btn, fill, border, 56)
	btn.pressed.connect(func() -> void: action.emit())
	parent.add_child(btn)
