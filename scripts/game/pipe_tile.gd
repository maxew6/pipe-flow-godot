class_name PipeTile
extends Control
## One grid cell: stone slab + rotatable pipe art + water overlay.
## Emits `tapped` when pressed. It never decides connections; the model does.

signal tapped(cell: Vector2i)

var cell := Vector2i.ZERO
var piece_type: String = PipeDefs.EMPTY

var _pipe: PipeArt
var _water: WaterArt
var _angle_target: float = 0.0
var _turn_tween: Tween
var _pop_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pipe = PipeArt.new()
	add_child(_pipe)
	_pipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_water = WaterArt.new()
	add_child(_water)
	_water.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func setup(p_cell: Vector2i, p_type: String, p_rot: int) -> void:
	cell = p_cell
	piece_type = p_type
	_pipe.piece_type = p_type
	snap_rotation(p_rot)
	queue_redraw()


## Jump (no animation) to the model's rotation. Used on build and on Reset.
func snap_rotation(rot: int) -> void:
	if _turn_tween != null and _turn_tween.is_valid():
		_turn_tween.kill()
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_angle_target = float(rot) * PI * 0.5
	_pipe.rotation = _angle_target
	_set_art_scale(1.0)


## Smoothly turn the pipe 90 degrees clockwise. Rapid taps queue up cleanly
## because the target angle always grows by exactly one quarter turn per tap.
func rotate_visual() -> void:
	_angle_target += PI * 0.5
	if _turn_tween != null and _turn_tween.is_valid():
		_turn_tween.kill()
	_turn_tween = create_tween()
	_turn_tween.tween_property(_pipe, "rotation", _angle_target, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_set_art_scale(0.9)
	_pop_tween = create_tween()
	_pop_tween.tween_method(_set_art_scale, 0.9, 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Little celebratory hop used when the level is won.
func bounce(delay: float) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_method(_set_art_scale, 1.0, 1.14, 0.12)
	tw.tween_method(_set_art_scale, 1.14, 1.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Hands this tile its slice of the animation plan (once per run).
func set_flow(timing: FlowPlan.CellTiming, seed_value: float) -> void:
	_water.set_flow(timing, seed_value)


func set_flow_time(t: float) -> void:
	_water.set_time(t)


func clear_water() -> void:
	_water.clear()
	_set_art_offset(0.0)


func add_leak(side: int) -> void:
	_water.add_leak(side)


## Quick left-right wobble that draws the eye to a problem tile.
func shake() -> void:
	var tw := create_tween()
	var previous := 0.0
	for target in [9.0, -8.0, 6.0, -4.0, 0.0]:
		tw.tween_method(_set_art_offset, previous, float(target), 0.05)
		previous = float(target)


func _set_art_offset(x: float) -> void:
	_pipe.position.x = x
	_water.position.x = x


func _set_art_scale(value: float) -> void:
	_pipe.scale = Vector2(value, value)
	_water.scale = Vector2(value, value)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			tapped.emit(cell)
			accept_event()


func _draw() -> void:
	var inset := 3.0
	var rect := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	var variation := float((cell.x * 7 + cell.y * 13) % 5) / 4.0
	var base := UiKit.STONE.lerp(UiKit.STONE_DARK, variation * 0.45)
	if piece_type == PipeDefs.EMPTY:
		base = base.darkened(0.25)
	var radius := int(size.x * 0.12)
	draw_style_box(UiKit.box(base, base.darkened(0.35), radius, 3), rect)
	draw_style_box(UiKit.box(Color(0.0, 0.0, 0.0, 0.0), Color(1.0, 1.0, 1.0, 0.2), radius, 2), rect.grow(-6.0))
