class_name BoardModel
extends RefCounted
## Pure board state: which piece sits in each cell and how it is rotated.
## No nodes, no drawing, no animation. Connection checks live in FlowSolver.
##
## The source (tank) and sink (tap) each sit outside the grid, attached to one
## side of one cell. Example: source_cell (0,0) + source_side W means the tank
## is on the left of the top-left cell.

var cols: int = 1
var rows: int = 1
var source_cell := Vector2i.ZERO
var source_side: int = Dirs.W
var sink_cell := Vector2i.ZERO
var sink_side: int = Dirs.E

var _types: Array[String] = []
var _rots: Array[int] = []


func _init(p_cols: int = 1, p_rows: int = 1) -> void:
	cols = maxi(p_cols, 1)
	rows = maxi(p_rows, 1)
	_types.resize(cols * rows)
	_rots.resize(cols * rows)
	for i in cols * rows:
		_types[i] = PipeDefs.EMPTY
		_rots[i] = 0


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func _index(cell: Vector2i) -> int:
	return cell.y * cols + cell.x


func get_type(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return PipeDefs.EMPTY
	return _types[_index(cell)]


func get_rot(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return 0
	return _rots[_index(cell)]


## Current openings of the cell as a 4-bit mask (0 for empty or out of bounds).
func mask_at(cell: Vector2i) -> int:
	return PipeDefs.mask_for(get_type(cell), get_rot(cell))


func set_cell(cell: Vector2i, type: String, rot: int) -> bool:
	if not in_bounds(cell) or not PipeDefs.is_valid_type(type):
		return false
	_types[_index(cell)] = type
	_rots[_index(cell)] = ((rot % 4) + 4) % 4
	return true


func can_rotate(cell: Vector2i) -> bool:
	return in_bounds(cell) and PipeDefs.is_rotatable(get_type(cell))


## Rotates one piece 90 degrees clockwise. Returns false if nothing changed.
func rotate_cell(cell: Vector2i) -> bool:
	if not can_rotate(cell):
		return false
	var i := _index(cell)
	_rots[i] = (_rots[i] + 1) % 4
	return true


func copy() -> BoardModel:
	var c := BoardModel.new(cols, rows)
	c.source_cell = source_cell
	c.source_side = source_side
	c.sink_cell = sink_cell
	c.sink_side = sink_side
	for i in _types.size():
		c._types[i] = _types[i]
		c._rots[i] = _rots[i]
	return c
