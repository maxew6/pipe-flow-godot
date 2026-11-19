class_name PipeDefs
extends RefCounted
## Pipe piece types and their base (rotation 0) openings.
## Rotation is stored as clockwise quarter turns 0..3.

const EMPTY := "empty"
const STRAIGHT := "straight"
const ELBOW := "elbow"
const TEE := "tee"
const CROSS := "cross"
const CAP := "cap"

## Openings at rotation 0 (bits: N=1, E=2, S=4, W=8).
const BASE_MASKS := {
	"empty": 0,
	"straight": 5,  # N + S
	"elbow": 3,     # N + E
	"tee": 7,       # N + E + S
	"cross": 15,    # all four
	"cap": 1,       # N only (a closed dead end)
}

## One-letter tokens used in the level files.
const TOKENS := {
	".": "empty",
	"I": "straight",
	"L": "elbow",
	"T": "tee",
	"X": "cross",
	"C": "cap",
}


static func is_valid_type(type: String) -> bool:
	return BASE_MASKS.has(type)


static func mask_for(type: String, rot: int) -> int:
	if not BASE_MASKS.has(type):
		return 0
	return Dirs.rotate_mask(BASE_MASKS[type], rot)


## Empty cells and crosses look the same in every rotation, so tapping them is ignored.
static func is_rotatable(type: String) -> bool:
	return type != EMPTY and type != CROSS and BASE_MASKS.has(type)


static func type_from_token(token: String) -> String:
	return TOKENS.get(token, "")
