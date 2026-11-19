class_name Dirs
extends RefCounted
## Cardinal directions and 4-bit "opening masks".
## Direction indices run clockwise: N=0, E=1, S=2, W=3.
## A mask has bit d set when that side of a cell is open.

const N := 0
const E := 1
const S := 2
const W := 3

const NAMES := ["N", "E", "S", "W"]
const VECTORS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


static func bit(dir: int) -> int:
	return 1 << dir


static func opposite(dir: int) -> int:
	return (dir + 2) % 4


static func has(mask: int, dir: int) -> bool:
	return (mask & (1 << dir)) != 0


static func vector(dir: int) -> Vector2i:
	return VECTORS[dir]


## Rotates every opening clockwise by `quarter_turns` x 90 degrees.
static func rotate_mask(mask: int, quarter_turns: int = 1) -> int:
	var m: int = mask & 15
	var turns: int = ((quarter_turns % 4) + 4) % 4
	for i in turns:
		m = ((m << 1) | (m >> 3)) & 15
	return m


## "N"/"E"/"S"/"W" (any case) to a direction index, or -1 when invalid.
static func from_name(side_name: String) -> int:
	return NAMES.find(side_name.to_upper())
