class_name BoardView
extends Control
## Visual board: tiles, tank, tap and the water animation.
##
## Separation of concerns:
##   * FlowSolver decides whether/where water flows (pure logic).
##   * FlowPlan turns that validated route into a timeline (pure maths).
##   * BoardView only REPLAYS the plan: it pushes time-based values into the tiles, the tank and
##     the tap. Animation state can never influence whether a level is solved.
##
## Invalid route: no water, the tank is not drained, the first problem is highlighted.
## Valid route: tank drains while the water travels the route, the tap opens, the stream runs,
## the tank ends nearly empty, then `flow_finished(true)` is emitted.

signal tile_tapped(cell: Vector2i)
signal flow_finished(reached_sink: bool)

const FIXTURE_RATIO := 0.9   # tank/tap column width, in cells
const OVERHANG_RATIO := 0.7  # free space above/below the grid, in cells
const MAX_CELL := 230.0
const BLOCKED_PAUSE := 0.65  # seconds the "blocked" highlight is shown before the failure message

var _board: BoardModel
var _tiles: Dictionary = {}  # Vector2i -> PipeTile
var _tank: FixtureArt
var _tap: FixtureArt
var _cell_size: float = 100.0
var _grid_origin := Vector2.ZERO

var _plan: FlowPlan
var _flow_time: float = 0.0
var _flow_active: bool = false
var _blocked_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	resized.connect(_relayout)


## Creates fresh tiles for a new level.
func build(board: BoardModel) -> void:
	stop_flow()
	_board = board
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_tiles.clear()

	for y in board.rows:
		for x in board.cols:
			var cell := Vector2i(x, y)
			var tile := PipeTile.new()
			add_child(tile)
			tile.setup(cell, board.get_type(cell), board.get_rot(cell))
			tile.tapped.connect(_on_tile_tapped)
			_tiles[cell] = tile

	_tank = FixtureArt.new()
	_tank.kind = FixtureArt.TANK
	add_child(_tank)
	_tap = FixtureArt.new()
	_tap.kind = FixtureArt.TAP
	add_child(_tap)
	_relayout()


## Re-syncs the existing tiles to a (freshly rebuilt) model. Used by Reset.
func sync_all(board: BoardModel) -> void:
	stop_flow()
	_board = board
	clear_water()
	for key in _tiles.keys():
		var cell: Vector2i = key
		var tile: PipeTile = _tiles[key]
		tile.snap_rotation(board.get_rot(cell))


func animate_rotation(cell: Vector2i) -> void:
	var tile: PipeTile = _tiles.get(cell)
	if tile != null:
		tile.rotate_visual()


## Cancels any running animation (flow or blocked highlight). Safe to call at any time.
func stop_flow() -> void:
	_flow_active = false
	set_process(false)
	if _blocked_tween != null and _blocked_tween.is_valid():
		_blocked_tween.kill()
	_blocked_tween = null


## Removes ALL flow effects and restores the tank to its original full level.
func clear_water() -> void:
	_plan = null
	for key in _tiles.keys():
		var tile: PipeTile = _tiles[key]
		tile.clear_water()
	if _tank != null:
		_tank.level = FlowPlan.TANK_FULL
		_tank.stub_flow = 0.0
		_tank.agitation = 0.3
	if _tap != null:
		_tap.inlet_flow = 0.0
		_tap.valve = 0.0
		_tap.stream = 0.0
		_tap.pool = 0.0


## Starts the Start Water animation for a solver result.
## Ignored while an animation is already running (no overlapping runs).
func play_flow(result: FlowSolver.FlowResult) -> void:
	if _flow_active:
		return
	stop_flow()
	clear_water()
	if not result.valid:
		_play_blocked(result)
		return
	_plan = FlowPlan.build(_board, result)
	if not _plan.valid:
		_play_blocked(result)
		return
	for key in _plan.cells.keys():
		var cell: Vector2i = key
		var tile: PipeTile = _tiles[cell]
		tile.set_flow(_plan.cells[cell], float(cell.x * 7 + cell.y * 13) * 0.37)
	_flow_time = 0.0
	_flow_active = true
	_apply_flow(0.0)
	set_process(true)


func play_victory(result: FlowSolver.FlowResult) -> void:
	var i := 0
	for cell in result.path:
		var tile: PipeTile = _tiles.get(cell)
		if tile != null:
			tile.bounce(float(i) * 0.06)
		i += 1


func _process(delta: float) -> void:
	if not _flow_active:
		return
	_flow_time += delta
	_apply_flow(_flow_time)
	if _flow_time >= _plan.t_end:
		_finish_flow()


## Pushes the plan's values for time `t` into the tiles, the tank and the tap.
func _apply_flow(t: float) -> void:
	_tank.level = _plan.tank_level(t)
	_tank.stub_flow = _plan.tank_stub_progress(t)
	_tank.agitation = 1.0 if t < _plan.t_pour_end else 0.3
	for key in _plan.cells.keys():
		var tile: PipeTile = _tiles[key]
		tile.set_flow_time(t)
	_tap.inlet_flow = _plan.tap_inlet_progress(t)
	_tap.valve = _plan.valve_open(t)
	_tap.stream = _plan.stream_strength(t)
	_tap.pool = _plan.pool_strength(t)


func _finish_flow() -> void:
	_flow_active = false
	set_process(false)
	_apply_flow(_plan.t_end)  # settle on the final frame: tank nearly empty, stream stopped
	flow_finished.emit(true)


## Invalid route: nothing flows and the tank is NOT drained. The first problem is marked and
## the tank just rocks slightly, then the failure is reported.
func _play_blocked(result: FlowSolver.FlowResult) -> void:
	var problem := result.first_problem(_board)
	if not problem.is_empty():
		var cell: Vector2i = problem["cell"]
		var tile: PipeTile = _tiles.get(cell)
		if tile != null:
			tile.add_leak(int(problem["dir"]))
			tile.shake()
	_tank.slosh()
	_blocked_tween = create_tween()
	_blocked_tween.tween_interval(BLOCKED_PAUSE)
	_blocked_tween.tween_callback(_emit_blocked)


func _emit_blocked() -> void:
	_blocked_tween = null
	flow_finished.emit(false)


func _on_tile_tapped(cell: Vector2i) -> void:
	tile_tapped.emit(cell)


func _relayout() -> void:
	if _board == null:
		return
	var by_width := size.x / (float(_board.cols) + 2.0 * FIXTURE_RATIO)
	var by_height := size.y / (float(_board.rows) + 2.0 * OVERHANG_RATIO)
	_cell_size = maxf(24.0, floorf(minf(minf(by_width, by_height), MAX_CELL)))

	var grid_w := _cell_size * float(_board.cols)
	var grid_h := _cell_size * float(_board.rows)
	var fixture_w := FIXTURE_RATIO * _cell_size
	_grid_origin = Vector2(
		floorf((size.x - (grid_w + 2.0 * fixture_w)) * 0.5 + fixture_w),
		floorf((size.y - grid_h) * 0.5))

	for key in _tiles.keys():
		var cell: Vector2i = key
		var tile: PipeTile = _tiles[key]
		tile.position = _grid_origin + Vector2(cell) * _cell_size
		tile.size = Vector2(_cell_size, _cell_size)

	if _tank != null:
		_tank.cell_size = _cell_size
		_tank.size = Vector2(fixture_w, _cell_size * 1.7)
		var source_y := _grid_origin.y + (float(_board.source_cell.y) + 0.5) * _cell_size
		_tank.position = Vector2(_grid_origin.x - fixture_w, source_y - _tank.outlet_y())
	if _tap != null:
		_tap.cell_size = _cell_size
		_tap.size = Vector2(fixture_w, _cell_size * 1.5)
		var sink_y := _grid_origin.y + (float(_board.sink_cell.y) + 0.5) * _cell_size
		_tap.position = Vector2(_grid_origin.x + grid_w, sink_y - _tap.outlet_y())
	queue_redraw()


func _draw() -> void:
	if _board == null:
		return
	var pad := _cell_size * 0.12
	var grid := Rect2(_grid_origin, Vector2(_cell_size * float(_board.cols), _cell_size * float(_board.rows)))
	draw_style_box(UiKit.box(UiKit.MOSS_DARK, UiKit.WOOD_DARK, int(pad * 1.5), maxi(2, int(pad * 0.6)), int(pad)), grid.grow(pad))
