class_name Art
extends RefCounted
## Loads and caches art textures. Missing files return null (and warn once), so a
## missing asset never crashes a screen. tests/test_runner.gd checks that every
## asset the game expects exists.

const UI_DIR := "res://assets/ui/"
const MENU_DIR := "res://assets/menu/"
const GAME_DIR := "res://assets/game/"

static var _cache: Dictionary = {}


static func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path)
	else:
		push_warning("Missing art asset: %s" % path)
	_cache[path] = texture
	return texture


static func ui(asset_name: String) -> Texture2D:
	return tex(UI_DIR + asset_name + ".png")


static func menu(asset_name: String) -> Texture2D:
	return tex(MENU_DIR + asset_name + ".png")


static func game(asset_name: String) -> Texture2D:
	return tex(GAME_DIR + asset_name + ".png")


## Every texture the shipped screens rely on (used by the asset test).
static func required_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for n in ["btn_green", "btn_blue", "btn_wood", "panel_wood", "panel_parchment", "icon_play", "icon_levels",
			"icon_settings", "icon_play_btn", "icon_back", "icon_pause", "icon_lock", "star_gold", "star_empty", "logo"]:
		paths.append(UI_DIR + n + ".png")
	for n in MenuArtLayout.LAYERS.keys():
		paths.append(MENU_DIR + str(n) + ".png")
	paths.append(MENU_DIR + "fall_streaks.png")
	paths.append(MENU_DIR + "river_glints.png")
	paths.append(GAME_DIR + "bg_game.png")
	paths.append(DS.FONT_BODY_PATH)
	paths.append(DS.FONT_DISPLAY_PATH)
	return paths
