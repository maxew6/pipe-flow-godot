class_name FixtureArt
extends Control
## The water tank (source) and the tap (destination) beside the grid.
## They only DISPLAY values pushed in by BoardView from the FlowPlan:
##   tank: level (fraction of the glass that is water), stub_flow, agitation
##   tap : inlet_flow, valve (handle turn), stream (strength), pool (splash pool)
## Waves, bubbles, ripples and droplets animate on their own clock; the amounts come from the plan.

const TANK := "tank"
const TAP := "tap"

var kind: String = TANK
var cell_size: float = 100.0:
	set(value):
		cell_size = value
		queue_redraw()

# --- tank state
var level: float = FlowPlan.TANK_FULL:
	set(value):
		level = value
		queue_redraw()
var stub_flow: float = 0.0:
	set(value):
		stub_flow = value
		queue_redraw()
var agitation: float = 0.3

# --- tap state
var inlet_flow: float = 0.0:
	set(value):
		inlet_flow = value
		queue_redraw()
var valve: float = 0.0:
	set(value):
		valve = value
		queue_redraw()
var stream: float = 0.0:
	set(value):
		stream = clampf(value, 0.0, 1.0)
		_update_processing()
		queue_redraw()
var pool: float = 0.0:
	set(value):
		pool = clampf(value, 0.0, 1.0)
		_update_processing()
		queue_redraw()

var _time: float = 0.0
var _slosh: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_update_processing()


func _update_processing() -> void:
	# The tank keeps gentle waves going always; the tap only animates while water is pouring.
	set_process(kind == TANK or stream > 0.001 or pool > 0.001)


func _process(delta: float) -> void:
	_time += delta
	_slosh = maxf(0.0, _slosh - delta * 1.8)
	queue_redraw()


## A short surface disturbance (used when a route is blocked: water rocks but nothing drains).
func slosh() -> void:
	_slosh = 1.0


## Local y of the stub pipe's centre line (the parent aligns this to the row centre).
func outlet_y() -> float:
	return size.y * (0.70 if kind == TANK else 0.36)


func _draw() -> void:
	if kind == TANK:
		_draw_tank()
	else:
		_draw_tap()


# ------------------------------------------------------------------ tank

func _draw_tank() -> void:
	var w := size.x
	var h := size.y
	var oy := outlet_y()
	var r := cell_size * UiKit.PIPE_RADIUS
	var px := cell_size / 140.0
	var body := Rect2(w * 0.03, h * 0.11, w * 0.70, h * 0.72)
	var stub_start := Vector2(body.end.x - 6.0, oy)

	UiKit.pipe_segment(self, stub_start, Vector2(w, oy), r)
	if stub_flow > 0.0:
		var stub_end := stub_start.lerp(Vector2(w, oy), stub_flow)
		WaterStyle.draw_stream(self, PackedVector2Array([stub_start, stub_end]), r * 0.66)

	# base plate, then the glass interior (back wall)
	draw_style_box(UiKit.box(UiKit.METAL_MID, UiKit.OUTLINE, 10, 4), Rect2(body.position.x - 8.0, body.end.y - 8.0, body.size.x + 16.0, h * 0.085))
	draw_style_box(UiKit.box(Color(0.62, 0.82, 0.92, 0.20), Color(0.0, 0.0, 0.0, 0.0), int(w * 0.16), 0), body)

	# water: wavy surface, depth gradient, bubbles
	var inner := body.grow(-9.0)
	var level_px := inner.size.y * level
	if level_px > 2.0:
		var rad := minf(minf(inner.size.x * 0.28, 26.0 * px), level_px * 0.9)
		var amp := (1.2 + 2.6 * agitation + 3.0 * _slosh) * px
		amp = minf(amp, maxf(0.0, level_px - rad) * 0.25)
		var top_y := inner.end.y - level_px
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var steps := 16
		for i in steps + 1:
			var x := inner.position.x + inner.size.x * float(i) / float(steps)
			var y := top_y + sin(x * 0.09 / px + _time * 2.2) * amp + sin(x * 0.17 / px - _time * 1.4) * amp * 0.5
			pts.append(Vector2(x, y))
			cols.append(WaterStyle.SURFACE_LIGHT)
		var corner_r := Vector2(inner.end.x - rad, inner.end.y - rad)
		for k in 7:
			var a := (PI * 0.5) * float(k) / 6.0
			pts.append(corner_r + Vector2(cos(a), sin(a)) * rad)
		var corner_l := Vector2(inner.position.x + rad, inner.end.y - rad)
		for k in 7:
			var a2 := PI * 0.5 + (PI * 0.5) * float(k) / 6.0
			pts.append(corner_l + Vector2(cos(a2), sin(a2)) * rad)
		for i in range(steps + 1, pts.size()):
			var f := clampf((pts[i].y - top_y) / maxf(level_px, 1.0), 0.0, 1.0)
			cols.append(WaterStyle.SURFACE_LIGHT.lerp(WaterStyle.SURFACE_DEEP, f))
		draw_polygon(pts, cols)
		# surface highlight line and a soft light band inside the water
		draw_polyline(pts.slice(0, steps + 1), Color(0.85, 0.97, 1.0, 0.9), 3.0 * px, true)
		draw_line(Vector2(inner.position.x + inner.size.x * 0.26, top_y + 10.0 * px), Vector2(inner.position.x + inner.size.x * 0.26, inner.end.y - 14.0 * px), Color(1.0, 1.0, 1.0, 0.16), 7.0 * px)
		if level_px > 14.0 * px:
			for i in 7:
				var u := fposmod(_time * (0.10 + 0.025 * float(i)) + float(i) * 0.137, 1.0)
				var bx := inner.position.x + inner.size.x * (0.16 + 0.68 * fposmod(float(i) * 0.37, 1.0)) + sin(_time * 2.0 + float(i)) * 3.0 * px
				var by := inner.end.y - 8.0 * px - u * (level_px - 12.0 * px)
				WaterStyle.draw_bubble(self, Vector2(bx, by), (2.2 + float(i % 3) * 1.3) * px)

	# glass front: rim + reflections
	draw_style_box(UiKit.box(Color(0.9, 0.98, 1.0, 0.07), Color(0.85, 0.96, 1.0, 0.60), int(w * 0.16), maxi(2, int(3.0 * px))), body)
	draw_line(Vector2(body.position.x + body.size.x * 0.20, body.position.y + 16.0 * px), Vector2(body.position.x + body.size.x * 0.20, body.end.y - 18.0 * px), Color(1.0, 1.0, 1.0, 0.34), 6.0 * px)
	draw_line(Vector2(body.position.x + body.size.x * 0.30, body.position.y + 16.0 * px), Vector2(body.position.x + body.size.x * 0.30, body.position.y + body.size.y * 0.45), Color(1.0, 1.0, 1.0, 0.16), 3.0 * px)

	# metal frame: side posts, top cap and lid
	draw_style_box(UiKit.box(UiKit.METAL, UiKit.OUTLINE, 5, 3), Rect2(body.position.x - 3.0, body.position.y + 6.0, 9.0 * px, body.size.y - 8.0))
	draw_style_box(UiKit.box(UiKit.METAL_MID, UiKit.OUTLINE, 5, 3), Rect2(body.end.x - 6.0 * px, body.position.y + 6.0, 9.0 * px, body.size.y - 8.0))
	draw_style_box(UiKit.box(UiKit.METAL, UiKit.OUTLINE, 10, 4), Rect2(body.position.x + body.size.x * 0.05, h * 0.045, body.size.x * 0.90, h * 0.085))
	draw_style_box(UiKit.box(UiKit.METAL_LIGHT, UiKit.OUTLINE, 8, 3), Rect2(body.position.x + body.size.x * 0.34, h * 0.015, body.size.x * 0.32, h * 0.04))

	# copper outlet collar
	var cx := body.end.x
	draw_line(Vector2(cx - 6.0, oy), Vector2(cx + 14.0, oy), UiKit.OUTLINE, r * 2.5 + 6.0)
	draw_line(Vector2(cx - 6.0, oy), Vector2(cx + 14.0, oy), UiKit.COPPER, r * 2.5)
	draw_line(Vector2(cx - 6.0, oy - r * 0.5), Vector2(cx + 14.0, oy - r * 0.5), UiKit.COPPER_LIGHT, r * 0.7)


# ------------------------------------------------------------------- tap

func _draw_tap() -> void:
	var w := size.x
	var h := size.y
	var oy := outlet_y()
	var r := cell_size * UiKit.PIPE_RADIUS
	var cx := w * 0.62
	var spout_len := h * 0.34
	var spout_end := Vector2(cx, oy + spout_len)

	UiKit.pipe_segment(self, Vector2(0.0, oy), Vector2(cx, oy), r)
	UiKit.pipe_segment(self, Vector2(cx, oy), spout_end, r)

	# water arriving through the inlet and down the spout (waits at the nozzle until the valve opens)
	if inlet_flow > 0.0:
		var path := PackedVector2Array([Vector2(0.0, oy), Vector2(cx, oy), spout_end])
		var travelled := (cx + spout_len) * inlet_flow
		var pts := PackedVector2Array([path[0]])
		if travelled <= cx:
			pts.append(Vector2(travelled, oy))
		else:
			pts.append(path[1])
			pts.append(Vector2(cx, oy + (travelled - cx)))
		WaterStyle.draw_stream(self, pts, r * 0.66)
		if inlet_flow < 1.0:
			WaterStyle.draw_head(self, pts[pts.size() - 1], r * 0.66)

	# valve body, stem, T-handle (turns 90 degrees as the tap opens), copper nozzle
	draw_circle(Vector2(cx, oy), r * 1.45, UiKit.OUTLINE)
	draw_circle(Vector2(cx, oy), r * 1.30, UiKit.COPPER)
	draw_circle(Vector2(cx - r * 0.3, oy - r * 0.3), r * 0.45, UiKit.COPPER_LIGHT)
	var wheel_c := Vector2(cx, oy - r * 2.45)
	draw_line(Vector2(cx, oy - r * 1.2), wheel_c, UiKit.OUTLINE, r * 0.6)
	draw_set_transform(wheel_c, valve * PI * 0.5, Vector2.ONE)
	draw_style_box(UiKit.box(UiKit.CORAL, UiKit.CORAL_DARK, 12, 4), Rect2(-r * 1.5, -r * 0.42, r * 3.0, r * 0.84))
	draw_circle(Vector2(-r * 1.5, 0.0), r * 0.46, UiKit.CORAL)
	draw_circle(Vector2(r * 1.5, 0.0), r * 0.46, UiKit.CORAL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_style_box(UiKit.box(UiKit.COPPER, UiKit.OUTLINE, 8, 4), Rect2(cx - r * 1.3, spout_end.y - r * 0.6, r * 2.6, r * 0.8))

	if pool > 0.001:
		_draw_pool(Vector2(cx, size.y * 0.93), r)
	if stream > 0.001:
		_draw_stream(spout_end, r)


func _draw_stream(from: Vector2, r: float) -> void:
	var pool_y := size.y * 0.93
	var top := from + Vector2(0.0, r * 0.25)
	var length := pool_y - top.y
	var half := r * 0.62 * (0.35 + 0.65 * stream)
	var wob := sin(_time * 9.0) * 1.2
	var quad := PackedVector2Array([
		Vector2(from.x - half, top.y), Vector2(from.x + half, top.y),
		Vector2(from.x + half * 1.28 + wob, pool_y), Vector2(from.x - half * 1.28 + wob, pool_y)])
	draw_colored_polygon(quad, WaterStyle.EDGE)
	var inner := PackedVector2Array([
		Vector2(from.x - half * 0.72, top.y), Vector2(from.x + half * 0.72, top.y),
		Vector2(from.x + half * 0.92 + wob, pool_y), Vector2(from.x - half * 0.92 + wob, pool_y)])
	draw_colored_polygon(inner, WaterStyle.MID)
	for k in 5:  # bright streaks sliding down the stream
		var y := top.y + fposmod(_time * 1.7 + float(k) * 0.2, 1.0) * length
		var x := from.x + (float(k) - 2.0) * half * 0.28
		draw_line(Vector2(x, y), Vector2(x, minf(y + length * 0.16, pool_y)), Color(1.0, 1.0, 1.0, 0.5 * stream), maxf(2.0, half * 0.30))
	draw_line(Vector2(from.x, top.y), Vector2(from.x + wob, pool_y), Color(WaterStyle.CORE, 0.8 * stream), maxf(2.0, half * 0.45))


func _draw_pool(at: Vector2, r: float) -> void:
	draw_set_transform(at, 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, r * 2.1 * (0.6 + 0.4 * pool), Color(WaterStyle.MID, 0.55 * pool))
	draw_circle(Vector2.ZERO, r * 1.4 * (0.6 + 0.4 * pool), Color(WaterStyle.CORE, 0.35 * pool))
	for i in 2:  # expanding ripple rings
		var ph := fposmod(_time * 0.9 + float(i) * 0.5, 1.0)
		draw_arc(Vector2.ZERO, lerpf(r * 0.7, r * 2.7, ph), 0.0, TAU, 32, Color(0.85, 0.97, 1.0, (1.0 - ph) * 0.8 * pool), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 6:  # a few splash droplets
		var ph2 := fposmod(_time * 1.3 + float(i) * 0.17, 1.0)
		var ang := -PI * (0.15 + 0.7 * float(i) / 5.0)
		var dist := r * 1.6 * ph2
		var p := at + Vector2(cos(ang) * dist, sin(ang) * dist * 1.3)
		draw_circle(p, r * 0.16 * (1.0 - ph2) * stream, Color(0.85, 0.97, 1.0, (1.0 - ph2) * stream))
