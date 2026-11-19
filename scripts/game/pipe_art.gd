class_name PipeArt
extends Control
## Draws one metal pipe piece in its BASE orientation (rotation 0).
## The parent tile rotates this node with a tween, so the pipe visibly turns.
## The logical rotation lives in BoardModel; this node is presentation only.

var piece_type: String = PipeDefs.EMPTY:
	set(value):
		piece_type = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	pivot_offset = size * 0.5
	queue_redraw()


func _draw() -> void:
	if piece_type == PipeDefs.EMPTY:
		return
	var mask := PipeDefs.mask_for(piece_type, 0)
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var edge := s * 0.5
	var r := s * UiKit.PIPE_RADIUS

	# Body layers are drawn across ALL arms at once so joints blend without seams.
	_layer(mask, c, edge, r * 1.18, UiKit.OUTLINE)
	_layer(mask, c, edge, r, UiKit.METAL_DARK)
	_layer(mask, c, edge, r * 0.72, UiKit.METAL)
	_layer(mask, c, edge, r * 0.34, UiKit.METAL_LIGHT)

	# Copper collar near every opening (shows clearly where a pipe is open).
	for d in 4:
		if not Dirs.has(mask, d):
			continue
		var dir := Vector2(Dirs.vector(d))
		var a := c + dir * edge * 0.72
		var b := c + dir * edge * 0.92
		draw_line(a, b, UiKit.OUTLINE, r * 2.5 + 6.0)
		draw_line(a, b, UiKit.COPPER, r * 2.5)
		draw_line(a, b, UiKit.COPPER_LIGHT, r * 0.9)

	if piece_type == PipeDefs.CAP:
		# Closed dome at the dead end.
		draw_circle(c, r * 1.3, UiKit.OUTLINE)
		draw_circle(c, r * 1.15, UiKit.COPPER)
		draw_circle(c, r * 0.8, UiKit.COPPER_DARK)
		draw_circle(c - Vector2(r * 0.25, r * 0.25), r * 0.3, UiKit.COPPER_LIGHT)
	elif piece_type != PipeDefs.STRAIGHT:
		# Joint bolt on elbows, tees and crosses.
		draw_circle(c, r * 0.56, UiKit.OUTLINE)
		draw_circle(c, r * 0.44, UiKit.COPPER)
		draw_circle(c - Vector2(r * 0.12, r * 0.12), r * 0.16, UiKit.COPPER_LIGHT)


func _layer(mask: int, c: Vector2, edge: float, half_width: float, color: Color) -> void:
	draw_circle(c, half_width, color)
	for d in 4:
		if Dirs.has(mask, d):
			draw_line(c, c + Vector2(Dirs.vector(d)) * edge, color, half_width * 2.0)
