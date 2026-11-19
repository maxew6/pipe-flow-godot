extends CanvasLayer
## Autoload "Nav": scene navigation with a short fade, plus the level the
## player picked. Taps are blocked while a transition runs, so double-presses
## can never start two scene changes. Uses tweens (not awaits), so nothing is
## left dangling if a scene is freed mid-transition.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const LEVELS_SCENE := "res://scenes/level_select.tscn"
const GAME_SCENE := "res://scenes/game.tscn"

var selected_level_id: int = 1

var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	get_tree().root.theme = DS.make_theme()  # global body font
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.14, 0.09, 1.0)
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func play_level(level_id: int) -> void:
	selected_level_id = level_id
	go(GAME_SCENE)


func go(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade_out := create_tween()
	fade_out.tween_property(_fade, "modulate:a", 1.0, 0.18)
	fade_out.tween_callback(_swap.bind(scene_path))


func _swap(scene_path: String) -> void:
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("Could not open scene %s (error %d)" % [scene_path, err])
	var fade_in := create_tween()
	fade_in.tween_interval(0.08)
	fade_in.tween_property(_fade, "modulate:a", 0.0, 0.22)
	fade_in.tween_callback(_finish)


func _finish() -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
