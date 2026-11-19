class_name WaterStyle
extends RefCounted
## One look for ALL water (pipes, tank outlet, tap inlet): deep-blue edges, bright aqua body,
## a pale reflective core. Drawn as three stacked polylines so it follows any geometry.

const EDGE := Color("1268c8")
const MID := Color("2fb0f6")
const CORE := Color("b4ecff")
const SHINE := Color(1.0, 1.0, 1.0, 0.55)
const SURFACE_LIGHT := Color("66d6ff")
const SURFACE_DEEP := Color("1581d6")


## Call from inside ci's _draw(). `half_width` is half the stream's full thickness.
static func draw_stream(ci: CanvasItem, pts: PackedVector2Array, half_width: float) -> void:
	if pts.size() < 2:
		return
	ci.draw_polyline(pts, EDGE, half_width * 2.0, true)
	ci.draw_polyline(pts, MID, half_width * 1.55, true)
	ci.draw_polyline(pts, CORE, half_width * 0.55, true)


## Rounded leading edge of a filling stream.
static func draw_head(ci: CanvasItem, pos: Vector2, half_width: float) -> void:
	ci.draw_circle(pos, half_width, EDGE)
	ci.draw_circle(pos, half_width * 0.78, MID)
	ci.draw_circle(pos, half_width * 0.28, CORE)


static func draw_bubble(ci: CanvasItem, pos: Vector2, radius: float) -> void:
	ci.draw_circle(pos, radius, Color(1.0, 1.0, 1.0, 0.22))
	ci.draw_arc(pos, radius, 0.0, TAU, 14, Color(1.0, 1.0, 1.0, 0.75), maxf(1.0, radius * 0.22))
	ci.draw_circle(pos + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.22, Color(1.0, 1.0, 1.0, 0.9))
