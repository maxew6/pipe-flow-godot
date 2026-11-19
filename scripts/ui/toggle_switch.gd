class_name ToggleSwitch
extends Control
## Large pill-shaped on/off switch. Emits `toggled(on)` only for player taps.

signal toggled(on: bool)

var on: bool = true

var _knob_t: float = 1.0  # 0 = off, 1 = on
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(150.0, 80.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Sets the state without emitting `toggled` (used for initial values).
func set_state(value: bool, animate: bool = true) -> void:
	on = value
	var target := 1.0 if on else 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(_set_knob, _knob_t, target, 0.15)
	else:
		_set_knob(target)


func _set_knob(value: float) -> void:
	_knob_t = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			set_state(not on, true)
			toggled.emit(on)
			Feedback.play("click")
			accept_event()


func _draw() -> void:
	var h := size.y
	var track := Color("8b8478").lerp(UiKit.GREEN, _knob_t)
	var border := Color("5d574e").lerp(UiKit.GREEN_DARK, _knob_t)
	draw_style_box(UiKit.box(track, border, int(h * 0.5), 5, 4), Rect2(Vector2.ZERO, size))
	var radius := h * 0.36
	var x := lerpf(h * 0.5, size.x - h * 0.5, _knob_t)
	draw_circle(Vector2(x, h * 0.5 + 3.0), radius, Color(0.0, 0.0, 0.0, 0.25))
	draw_circle(Vector2(x, h * 0.5), radius, Color("fffaf0"))
	draw_circle(Vector2(x, h * 0.5), radius * 0.62, Color("efe3c6"))
