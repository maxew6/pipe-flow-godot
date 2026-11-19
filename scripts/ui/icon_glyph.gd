class_name IconGlyph
extends Control
## Icon (pause, back, lock...) drawn from assets/ui/icon_*.png. If a texture is
## missing it falls back to simple vector shapes. Place as a child of a Button.

var kind: String = "pause":
	set(value):
		kind = value
		queue_redraw()

var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var icon := Art.ui("icon_" + kind)
	if icon != null:
		draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, color)
		return
	if kind == "pause":
		var bw := s * 0.17
		var bh := s * 0.52
		draw_rect(Rect2(c.x - bw * 1.45, c.y - bh * 0.5, bw, bh), color)
		draw_rect(Rect2(c.x + bw * 0.45, c.y - bh * 0.5, bw, bh), color)
	elif kind == "back":
		var pts := PackedVector2Array([
			Vector2(c.x + s * 0.12, c.y - s * 0.28),
			Vector2(c.x - s * 0.14, c.y),
			Vector2(c.x + s * 0.12, c.y + s * 0.28)])
		draw_polyline(pts, color, s * 0.12)
		draw_circle(pts[0], s * 0.06, color)
		draw_circle(pts[2], s * 0.06, color)
	elif kind == "lock":
		draw_arc(Vector2(c.x, c.y - s * 0.02), s * 0.19, PI, TAU, 24, color, s * 0.09)
		draw_line(Vector2(c.x - s * 0.19, c.y - s * 0.02), Vector2(c.x - s * 0.19, c.y + s * 0.06), color, s * 0.09)
		draw_line(Vector2(c.x + s * 0.19, c.y - s * 0.02), Vector2(c.x + s * 0.19, c.y + s * 0.06), color, s * 0.09)
		draw_style_box(
			UiKit.box(color, color.darkened(0.35), int(s * 0.07), 3),
			Rect2(c.x - s * 0.28, c.y + s * 0.02, s * 0.56, s * 0.40))
		draw_circle(Vector2(c.x, c.y + s * 0.19), s * 0.05, color.darkened(0.55))
