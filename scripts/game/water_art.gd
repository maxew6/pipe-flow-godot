class_name WaterArt
extends Control
## Draws the water inside ONE tile from the animation plan. It replays timing data; it never
## decides whether a connection exists.
##
## Each open side of the piece has a centre-line path (FlowPlan.cell_paths): straight arms,
## or a smooth curve through elbows. A path fills progressively from its start to its end as
## the global flow time advances, so water visibly travels along the pipe, bends around
## corners and never appears across a closed opening. The metal pipe stays visible around the
## narrower water column. Moving highlights and a few bubbles travel in the flow direction.
## Also draws the pulsing red marker for the "first problem" when a route fails.

class FlowPath extends RefCounted:
	var points := PackedVector2Array()
	var lengths := PackedFloat32Array()
	var total: float = 0.0
	var t0: float = 0.0
	var t1: float = 0.0
	var phase: float = 0.0


var _timing: FlowPlan.CellTiming
var _paths: Array[FlowPath] = []
var _seed: float = 0.0
var _time: float = 0.0
var _leak_mask: int = 0
var _leak_time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _ready() -> void:
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	pivot_offset = size * 0.5
	_rebuild()
	queue_redraw()


## Hands this tile its slice of the plan (once per run).
func set_flow(timing: FlowPlan.CellTiming, seed_value: float) -> void:
	_timing = timing
	_seed = seed_value
	_time = 0.0
	_rebuild()
	queue_redraw()


func set_time(t: float) -> void:
	_time = t
	queue_redraw()


func add_leak(side: int) -> void:
	_leak_mask |= (1 << side)
	_leak_time = 0.0
	set_process(true)
	queue_redraw()


func clear() -> void:
	_timing = null
	_paths.clear()
	_leak_mask = 0
	_time = 0.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_leak_time += delta
	queue_redraw()


func _rebuild() -> void:
	_paths.clear()
	if _timing == null:
		return
	for entry in FlowPlan.cell_paths(_timing.mask, _timing.entry):
		var info: Dictionary = entry
		var unit: PackedVector2Array = info["points"]
		var path := FlowPath.new()
		var acc := 0.0
		for i in unit.size():
			var p := unit[i] * size
			path.points.append(p)
			if i > 0:
				acc += p.distance_to(path.points[i - 1])
			path.lengths.append(acc)
		path.total = acc
		var kind: String = info["kind"]
		var dir: int = info["dir"]
		if kind == "entry":
			path.t0 = _timing.t_enter
			path.t1 = _timing.t_center
		elif kind == "exit":
			path.t0 = _timing.t_center
			path.t1 = float(_timing.exits[dir])
		else:
			path.t0 = _timing.t_enter
			path.t1 = float(_timing.exits[dir])
		path.phase = _seed + float(_paths.size()) * 0.31
		_paths.append(path)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var half := s * UiKit.PIPE_RADIUS * 0.66
	if _timing != null:
		for path in _paths:
			var p := clampf((_time - path.t0) / maxf(path.t1 - path.t0, 0.001), 0.0, 1.0)
			if p > 0.0:
				_draw_path(path, p, half)
		if not _timing.bent and _time >= _timing.t_center:
			var c := size * 0.5  # junction hub so branches merge smoothly
			var reach := clampf((_time - _timing.t_center) / 0.12, 0.0, 1.0)
			draw_circle(c, half * reach, WaterStyle.EDGE)
			draw_circle(c, half * 0.78 * reach, WaterStyle.MID)
			draw_circle(c, half * 0.28 * reach, WaterStyle.CORE)
	_draw_leaks(s)


func _draw_path(path: FlowPath, p: float, half: float) -> void:
	var filled := path.total * p
	var pts := _slice(path, 0.0, filled)
	WaterStyle.draw_stream(self, pts, half)
	if p < 1.0 and pts.size() > 0:
		WaterStyle.draw_head(self, pts[pts.size() - 1], half)
	# Highlights travelling in the flow direction (only where water already is).
	for k in 2:
		var start := fposmod(_time * 1.1 + path.phase + float(k) * 0.5, 1.0) * path.total
		if start < filled:
			var seg := _slice(path, start, minf(start + path.total * 0.18, filled))
			if seg.size() >= 2:
				draw_polyline(seg, WaterStyle.SHINE, half * 0.45, true)
	# A few small bubbles drifting along the pipe.
	for k in 3:
		var dist := fposmod(_time * 0.45 + path.phase * 1.7 + float(k) / 3.0, 1.0) * path.total
		if dist < filled - half * 0.5:
			var at := _point_at(path, dist)
			var tangent := _point_at(path, minf(dist + 2.0, path.total)) - at
			var normal := Vector2(-tangent.y, tangent.x).normalized()
			var wobble := sin(_time * 3.0 + float(k) * 2.1 + path.phase) * half * 0.38
			WaterStyle.draw_bubble(self, at + normal * wobble, half * (0.17 + 0.07 * float(k)))


## Polyline between two arc-length distances along a path.
func _slice(path: FlowPath, from_d: float, to_d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if path.points.size() < 2 or to_d <= from_d:
		return out
	out.append(_point_at(path, from_d))
	for i in range(1, path.points.size() - 1):
		if path.lengths[i] > from_d and path.lengths[i] < to_d:
			out.append(path.points[i])
	out.append(_point_at(path, to_d))
	return out


func _point_at(path: FlowPath, dist: float) -> Vector2:
	var d := clampf(dist, 0.0, path.total)
	for i in range(1, path.points.size()):
		if d <= path.lengths[i]:
			var seg := path.lengths[i] - path.lengths[i - 1]
			var f := (d - path.lengths[i - 1]) / maxf(seg, 0.0001)
			return path.points[i - 1].lerp(path.points[i], clampf(f, 0.0, 1.0))
	return path.points[path.points.size() - 1]


func _draw_leaks(s: float) -> void:
	var c := size * 0.5
	for d in 4:
		if (_leak_mask & (1 << d)) != 0:
			var pos := c + Vector2(Dirs.vector(d)) * s * 0.40
			var pulse := 0.5 + 0.5 * sin(_leak_time * 7.0)
			var r := s * (0.12 + 0.025 * pulse)
			draw_circle(pos, r * 1.35, Color(UiKit.CORAL, 0.28 + 0.2 * pulse))
			draw_circle(pos, r, Color.WHITE)
			draw_circle(pos, r * 0.86, UiKit.CORAL)
			var k := r * 0.42
			draw_line(pos + Vector2(-k, -k), pos + Vector2(k, k), Color.WHITE, 4.0)
			draw_line(pos + Vector2(-k, k), pos + Vector2(k, -k), Color.WHITE, 4.0)
