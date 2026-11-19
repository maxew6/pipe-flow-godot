class_name Difficulty
extends RefCounted
## The four campaign chapters.
##   Chapter 1  EASY     levels   1-20  "Learn to Read the Pipes"
##   Chapter 2  MEDIUM   levels  21-45  "Think Before You Turn"
##   Chapter 3  HARD     levels  46-75  "Plan the Whole Network"
##   Chapter 4  EXTREME  levels  76-100 "Master the System"

const EASY := "easy"
const MEDIUM := "medium"
const HARD := "hard"
const EXTREME := "extreme"
const ORDER := ["easy", "medium", "hard", "extreme"]
const FIRST_ID := {"easy": 1, "medium": 21, "hard": 46, "extreme": 76}
const LAST_ID := {"easy": 20, "medium": 45, "hard": 75, "extreme": 100}
const CHAPTER_NAMES := {
	"easy": "Learn to Read the Pipes",
	"medium": "Think Before You Turn",
	"hard": "Plan the Whole Network",
	"extreme": "Master the System",
}


static func is_valid(difficulty: String) -> bool:
	return ORDER.has(difficulty)


## Chapter (difficulty group) a level id belongs to.
static func for_level_id(id: int) -> String:
	if id <= 20:
		return EASY
	if id <= 45:
		return MEDIUM
	if id <= 75:
		return HARD
	return EXTREME


static func label(difficulty: String) -> String:
	return difficulty.to_upper()


static func chapter_number(difficulty: String) -> int:
	return ORDER.find(difficulty) + 1


static func chapter_name(difficulty: String) -> String:
	return CHAPTER_NAMES.get(difficulty, "")


static func first_id(difficulty: String) -> int:
	return FIRST_ID.get(difficulty, 1)


static func last_id(difficulty: String) -> int:
	return LAST_ID.get(difficulty, 1)


static func is_chapter_last(id: int) -> bool:
	return LAST_ID.values().has(id)
