class_name FlowSolver
extends RefCounted
## Deterministic water-flow solver. Decides whether water reaches the tap.
## It looks ONLY at BoardModel data (types + rotations), never at visuals or
## animation state. Breadth-first search with a visited set, so cyclic pipe
## networks always terminate.
##
## Rules (the game uses dedicated END-CAP pieces; nothing is sealed automatically):
##  * Water enters the source cell only if that piece is open toward the tank.
##  * Water passes between two neighbours only if BOTH have an opening facing
##    each other (reciprocal openings). A cap is a one-opening piece, so it only
##    seals an end when its opening faces that pipe.
##  * The tap is reached only when the sink cell is wet AND open toward the tap.
##  * SEALED NETWORK: every open end the water can reach must connect to another
##    pipe (or be the tank/tap connection). An open end facing an empty cell, the
##    board edge, a closed pipe side, or the BACK of a mis-turned cap is a leak.
##    A route is valid only when the tap is reached AND there is no leak anywhere
##    in the reachable network, including side branches.
##  * Each leak is reported in `dead_ends`, in the order the water meets them.

const FAIL_NONE := ""
const FAIL_INVALID := "invalid_board"
const FAIL_SOURCE_CLOSED := "source_closed"
const FAIL_SINK_CLOSED := "sink_closed"
const FAIL_NO_ROUTE := "no_route"
const FAIL_LEAK := "leak"


class FlowResult extends RefCounted:
	var failure: String = ""
	var source_connected: bool = false
	var sink_cell_wet: bool = false
	var reached_sink: bool = false  # the tap is reachable (NOT enough by itself to win)
	## True only when the tap is reached AND no reachable open end leaks. The single win condition.
	var valid: bool = false
	## Wet cells in breadth-first order.
	var order: Array[Vector2i] = []
	## Vector2i -> int steps from the source (source = 0). Drives animation timing.
	var depth: Dictionary = {}
	## Vector2i -> int side the water enters that cell from.
	var entry_side: Dictionary = {}
	## Array of {"cell": Vector2i, "dir": int}: open sides leading nowhere.
	var dead_ends: Array = []
	## Shortest route source -> sink (only when reached_sink).
	var path: Array[Vector2i] = []

	## The one spot to highlight when the route is not valid: {"cell": Vector2i, "dir": int}, or {} if valid.
	## Order: tank side closed -> last pipe not facing the tap -> first leak the water meets.
	func first_problem(board: BoardModel) -> Dictionary:
		if valid:
			return {}
		if not source_connected:
			return {"cell": board.source_cell, "dir": board.source_side}
		if sink_cell_wet and not reached_sink:
			return {"cell": board.sink_cell, "dir": board.sink_side}
		if not dead_ends.is_empty():
			var first: Dictionary = dead_ends[0]
			return {"cell": first["cell"], "dir": first["dir"]}
		return {"cell": board.source_cell, "dir": board.source_side}


static func is_solved(board: BoardModel) -> bool:
	return solve(board).valid


static func solve(board: BoardModel) -> FlowResult:
	var result := FlowResult.new()
	if board == null or not board.in_bounds(board.source_cell) or not board.in_bounds(board.sink_cell):
		result.failure = FAIL_INVALID
		return result

	var start := board.source_cell
	if not Dirs.has(board.mask_at(start), board.source_side):
		result.failure = FAIL_SOURCE_CLOSED
		return result
	result.source_connected = true

	var parent: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	result.depth[start] = 0
	result.entry_side[start] = board.source_side

	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		result.order.append(cell)
		if cell == board.sink_cell:
			result.sink_cell_wet = true

		var mask := board.mask_at(cell)
		var cell_depth: int = result.depth[cell]
		for dir in 4:
			if not Dirs.has(mask, dir):
				continue
			if cell == start and dir == board.source_side:
				continue  # this opening faces the tank
			if cell == board.sink_cell and dir == board.sink_side:
				result.reached_sink = true  # this opening faces the tap
				continue
			var neighbor: Vector2i = cell + Dirs.vector(dir)
			if board.in_bounds(neighbor) and Dirs.has(board.mask_at(neighbor), Dirs.opposite(dir)):
				if not result.depth.has(neighbor):
					result.depth[neighbor] = cell_depth + 1
					result.entry_side[neighbor] = Dirs.opposite(dir)
					parent[neighbor] = cell
					queue.append(neighbor)
			else:
				result.dead_ends.append({"cell": cell, "dir": dir})

	if result.reached_sink:
		var cursor: Vector2i = board.sink_cell
		var reversed_path: Array[Vector2i] = [cursor]
		while cursor != start:
			cursor = parent[cursor]
			reversed_path.append(cursor)
		reversed_path.reverse()
		result.path = reversed_path
		if result.dead_ends.is_empty():
			result.failure = FAIL_NONE
			result.valid = true
		else:
			result.failure = FAIL_LEAK  # tap reached, but the network is not sealed
	elif result.sink_cell_wet:
		result.failure = FAIL_SINK_CLOSED
	else:
		result.failure = FAIL_NO_ROUTE
	return result
