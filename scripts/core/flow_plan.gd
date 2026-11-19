class_name FlowPlan
extends RefCounted
## Animation timeline for ONE Start Water run. Pure data + maths: no nodes, no drawing.
##
## It is built from the solver's FlowResult, so water can only ever travel the validated
## route. The solver decides WHERE water goes; this class only decides WHEN it gets there,
## and the rendering classes (WaterArt, FixtureArt, BoardView) just replay it.
## Only a VALID result (tap reached and no leaks) produces a plan. An invalid route produces an empty plan (valid == false): nothing flows, the tank never drains.

const CELL_TIME := 0.34       # seconds for water to cross one straight tile
const ELBOW_FACTOR := 0.82    # an elbow's centre line is shorter than a straight tile
const LEAD_TIME := 0.40       # water leaves the tank and crosses the outlet pipe
const TAP_PIPE_TIME := 0.40   # water crosses the tap's inlet pipe
const VALVE_TIME := 0.30      # the tap handle turns
const STREAM_MIN := 1.5       # the stream runs at least this long
const TAPER_TIME := 0.60      # the stream thins out and stops
const SETTLE_TIME := 0.20
const TANK_FULL := 0.88       # fraction of the glass that is water at the start
const TANK_EMPTY := 0.04      # nearly empty at the end
const BEND_SAMPLES := 14

const EDGE_MIDS := [Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)]  # N E S W


class CellTiming extends RefCounted:
	var entry: int = 0
	var mask: int = 0
	var bent: bool = false
	var t_enter: float = 0.0    # water reaches the entry edge
	var t_center: float = 0.0   # water reaches the middle of the tile
	var exits: Dictionary = {}  # dir -> time water reaches that exit edge


var valid: bool = false
var cells: Dictionary = {}      # Vector2i -> CellTiming
var t_sink_exit: float = 0.0    # water leaves the last tile toward the tap
var t_all_filled: float = 0.0   # every branch of the network is full
var t_valve_start: float = 0.0
var t_stream_start: float = 0.0
var t_pour_end: float = 0.0     # tank is empty, the stream starts to thin
var t_taper_end: float = 0.0
var t_end: float = 0.0          # the whole sequence is finished


static func edge_mid(dir: int) -> Vector2:
	return EDGE_MIDS[dir]


## Centre-line geometry of the water inside one tile, in unit coordinates (0..1).
## Only OPEN sides are ever used, so water cannot cross a closed opening.
## Returns [] when `entry` is not an open side of `mask`.
## Each entry: {"points": PackedVector2Array, "dir": int, "kind": "entry" | "exit" | "bend"}.
static func cell_paths(mask: int, entry: int) -> Array:
	var paths: Array = []
	if entry < 0 or entry > 3 or not Dirs.has(mask, entry):
		return paths
	var exits: Array[int] = []
	for d in 4:
		if d != entry and Dirs.has(mask, d):
			exits.append(d)
	var center := Vector2(0.5, 0.5)
	if exits.size() == 1 and exits[0] != Dirs.opposite(entry):
		# Elbow: a smooth curve from one edge to the other (control point = tile centre).
		var a := edge_mid(entry)
		var b := edge_mid(exits[0])
		var pts := PackedVector2Array()
		for i in BEND_SAMPLES + 1:
			var t := float(i) / float(BEND_SAMPLES)
			var u := 1.0 - t
			pts.append(a * (u * u) + center * (2.0 * u * t) + b * (t * t))
		paths.append({"points": pts, "dir": exits[0], "kind": "bend"})
		return paths
	paths.append({"points": PackedVector2Array([edge_mid(entry), center]), "dir": entry, "kind": "entry"})
	for d in exits:
		paths.append({"points": PackedVector2Array([center, edge_mid(d)]), "dir": d, "kind": "exit"})
	return paths


static func build(board: BoardModel, result: FlowSolver.FlowResult) -> FlowPlan:
	var plan := FlowPlan.new()
	if board == null or result == null or not result.valid:
		return plan
	var arrival: Dictionary = {board.source_cell: LEAD_TIME}
	var latest := LEAD_TIME
	for cell in result.order:  # breadth-first: a parent is always handled before its children
		var timing := CellTiming.new()
		timing.mask = board.mask_at(cell)
		timing.entry = result.entry_side[cell]
		var exit_dirs: Array[int] = []
		for d in 4:
			if d != timing.entry and Dirs.has(timing.mask, d):
				exit_dirs.append(d)
		timing.bent = exit_dirs.size() == 1 and exit_dirs[0] != Dirs.opposite(timing.entry)
		timing.t_enter = float(arrival.get(cell, LEAD_TIME))
		if timing.bent:
			timing.t_center = timing.t_enter + CELL_TIME * ELBOW_FACTOR * 0.5
			timing.exits[exit_dirs[0]] = timing.t_enter + CELL_TIME * ELBOW_FACTOR
		else:
			timing.t_center = timing.t_enter + CELL_TIME * 0.5
			for d in exit_dirs:
				timing.exits[d] = timing.t_center + CELL_TIME * 0.5
		for d in exit_dirs:
			var t_exit: float = timing.exits[d]
			latest = maxf(latest, t_exit)
			if cell == board.sink_cell and d == board.sink_side:
				plan.t_sink_exit = t_exit
				continue
			var neighbor: Vector2i = cell + Dirs.vector(d)
			# Hand the water on only to this cell's children in the solver's search tree.
			if result.entry_side.has(neighbor) and int(result.entry_side[neighbor]) == Dirs.opposite(d) \
					and int(result.depth[neighbor]) == int(result.depth[cell]) + 1:
				arrival[neighbor] = t_exit
		plan.cells[cell] = timing
	plan.t_all_filled = latest
	plan.t_valve_start = plan.t_sink_exit + TAP_PIPE_TIME * 0.55
	plan.t_stream_start = plan.t_valve_start + VALVE_TIME
	plan.t_pour_end = maxf(plan.t_stream_start + STREAM_MIN, latest + 0.25)
	plan.t_taper_end = plan.t_pour_end + TAPER_TIME
	plan.t_end = plan.t_taper_end + SETTLE_TIME
	plan.valid = true
	return plan


## Water level in the tank (fraction of the glass). Drains smoothly from the moment water
## leaves until the stream stops. An invalid plan never drains.
func tank_level(t: float) -> float:
	if not valid:
		return TANK_FULL
	var u := clampf((t - 0.05) / maxf(t_pour_end - 0.05, 0.01), 0.0, 1.0)
	return lerpf(TANK_FULL, TANK_EMPTY, u * u * (3.0 - 2.0 * u))


func tank_stub_progress(t: float) -> float:
	return clampf(t / LEAD_TIME, 0.0, 1.0) if valid else 0.0


func tap_inlet_progress(t: float) -> float:
	return clampf((t - t_sink_exit) / TAP_PIPE_TIME, 0.0, 1.0) if valid else 0.0


## 0 = handle closed, 1 = fully open.
func valve_open(t: float) -> float:
	if not valid:
		return 0.0
	return smoothstep(0.0, 1.0, clampf((t - t_valve_start) / VALVE_TIME, 0.0, 1.0))


## Strength of the stream leaving the tap: fades in, runs, then tapers to nothing.
func stream_strength(t: float) -> float:
	if not valid or t < t_stream_start:
		return 0.0
	var fade_in := smoothstep(0.0, 1.0, clampf((t - t_stream_start) / 0.25, 0.0, 1.0))
	var taper := 1.0 - smoothstep(0.0, 1.0, clampf((t - t_pour_end) / TAPER_TIME, 0.0, 1.0))
	return fade_in * taper


## Splash pool under the tap: appears with the stream, fades out a little after it.
func pool_strength(t: float) -> float:
	if not valid or t < t_stream_start:
		return 0.0
	var fade_in := clampf((t - t_stream_start) / 0.4, 0.0, 1.0)
	var fade_out := 1.0 - smoothstep(0.0, 1.0, clampf((t - t_pour_end) / (TAPER_TIME + SETTLE_TIME), 0.0, 1.0))
	return fade_in * fade_out
