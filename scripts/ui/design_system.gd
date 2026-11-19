class_name DS
extends RefCounted
## PIPE FLOW design tokens: the single source of truth for colour, type,
## spacing, sizes and motion. UiKit re-exports the colours under its old names.
##
## Palette idea: deep forest green, clear sky blue, aqua water, warm wood,
## natural stone, and a restrained gold used only for stars and rewards.

# --- Palette -----------------------------------------------------------------
const FOREST := Color("1f5f3a")
const FOREST_DARK := Color("0e4228")
const SKY := Color("4fb0ee")
const AQUA := Color("39b4ea")
const AQUA_DEEP := Color("1581d6")
const AQUA_LIGHT := Color("66d6ff")
const WOOD_DARK := Color("4e3118")
const WOOD := Color("8a5628")
const WOOD_LIGHT := Color("b9783a")
const STONE := Color("d2bb92")
const STONE_DARK := Color("a98f66")
const PARCHMENT := Color("f6e6bd")
const INK := Color("3a2411")
const GOLD := Color("ffc933")
const GOLD_DARK := Color("b5710c")
const GREEN := Color("3dbb4c")
const GREEN_DARK := Color("1d7a2c")
const BLUE := Color("2f84e6")
const BLUE_DARK := Color("1a4f9e")
const CORAL := Color("e85d4a")
const CORAL_DARK := Color("a8321f")
const TEXT_LIGHT := Color("fff8e8")
const OUTLINE_GREEN := Color("0e461a")
const OUTLINE_BLUE := Color("0a245c")
const OUTLINE_WOOD := Color("3c1e0c")

# --- Difficulty groups ------------------------------------------------------
const EASY_COLOR := Color("3dbb4c")
const MEDIUM_COLOR := Color("2f9fe0")
const HARD_COLOR := Color("f0a02b")
const EXTREME_COLOR := Color("e24b4b")

# --- Spacing scale (viewport px at the 1080-wide design size) -----------------
const SP_XS := 8
const SP_SM := 16
const SP_MD := 24
const SP_LG := 36
const SP_XL := 56

# --- Type scale ----------------------------------------------------------------
const T_DISPLAY := 84
const T_TITLE := 64
const T_HEADING := 52
const T_BODY := 40
const T_SMALL := 30
const T_BUTTON_PRIMARY := 68
const T_BUTTON := 56

# --- Component sizes -----------------------------------------------------------
const BTN_H_PRIMARY := 200
const BTN_H := 164
const BTN_H_SMALL := 110
const BTN_W_MENU := 620
const TOUCH_MIN := 96
const ICON_PRIMARY := 100
const ICON_BUTTON := 80
const OUTLINE_TEXT := 8

# --- Motion --------------------------------------------------------------------
const DUR_FAST := 0.12
const DUR_BASE := 0.25
const DUR_SLOW := 0.45
const PRESS_SCALE := 0.94

const FONT_BODY_PATH := "res://assets/fonts/Outfit-Bold.ttf"
const FONT_DISPLAY_PATH := "res://assets/fonts/EricaOne-Regular.ttf"

static var _fonts: Dictionary = {}


static func font_body() -> Font:
	return _load_font(FONT_BODY_PATH)


static func font_display() -> Font:
	return _load_font(FONT_DISPLAY_PATH)


static func _load_font(path: String) -> Font:
	if _fonts.has(path):
		return _fonts[path]
	var font: Font = null
	if ResourceLoader.exists(path):
		font = load(path)
	else:
		push_warning("Missing font: %s (falling back to the engine default)" % path)
	_fonts[path] = font
	return font


## Default theme applied to the whole app (body font + sensible default size).
static func make_theme() -> Theme:
	var theme := Theme.new()
	var body := font_body()
	if body != null:
		theme.default_font = body
	theme.default_font_size = T_BODY
	return theme
