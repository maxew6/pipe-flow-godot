class_name MenuStage
extends Control
## The illustrated environment behind the menu screens.
##
## Layers (assets/menu/*.png) live in a 1200x2400 "art space". The whole stage is
## scaled to COVER the screen (never stretched), so the sides/top are cropped
## instead of distorted. MenuArtLayout.SAFE_RECT is what stays visible on every
## portrait aspect from 9:16 to 9:20, and the art keeps its key scenery inside it.
##
## Motion is deliberately small: drifting clouds, water streaks on the waterfall,
## river glints and a slight leaf sway. No shaders, only moving textures.
##
## Drop-in replacement: put a finished illustration at
## res://assets/menu/override/bg_full.png and it is shown (cover-scaled) instead
## of the layers.

const OVERRIDE_PATH := "res://assets/menu/override/bg_full.png"

## 0..1 darkening for screens that need a calmer backdrop (level select).
var dim: float = 0.0:
	set(value):
		dim = value
		if _dim_rect != null:
			_dim_rect.color.a = dim

var _stage: Control
var _dim_rect: ColorRect
var _clouds: Array[Dictionary] = []
var _sway: Array[Dictionary] = []
var _fall_tile: TextureRect
var _glint_tile: TextureRect
var _time: float = 0.0
var _animated: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _ready() -> void:
	if ResourceLoader.exists(OVERRIDE_PATH):
		_build_override()
		_animated = false
	else:
		_build_layers()
	_dim_rect = ColorRect.new()
	_dim_rect.color = Color(0.02, 0.10, 0.06, dim)
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim_rect)
	_dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_relayout)
	_relayout()
	set_process(_animated)


func _build_override() -> void:
	var full := TextureRect.new()
	full.texture = load(OVERRIDE_PATH)
	full.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(full)
	full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_layers() -> void:
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = MenuArtLayout.ART_SIZE
	add_child(_stage)

	_add_layer("sky")
	for i in 4:
		var cloud := _add_layer("cloud_%d" % (i + 1))
		if cloud != null:
			_clouds.append({"node": cloud, "x0": cloud.position.x, "speed": 7.0 + 4.0 * float(i), "span": MenuArtLayout.ART_SIZE.x + cloud.size.x + 80.0})
	_add_layer("mountains")
	_add_layer("midground")
	_add_layer("river")
	_glint_tile = _add_scrolling_tile(MenuArtLayout.RIVER_RECT, "river_glints", 0.5, true)
	_add_layer("scenery")
	_fall_tile = _add_scrolling_tile(MenuArtLayout.WATERFALL_RECT, "fall_streaks", 0.55, false)
	for entry in [["fg_br", 0.9, 1.0, 0.0], ["fg_bl", 0.25, 1.0, 1.7], ["fg_tl", 0.0, 0.85, 3.1]]:
		var node := _add_layer(str(entry[0]))
		if node != null:
			node.pivot_offset = Vector2(node.size.x * float(entry[1]), node.size.y * float(entry[2]))
			_sway.append({"node": node, "phase": float(entry[3])})


func _add_layer(layer_name: String) -> TextureRect:
	var texture := Art.menu(layer_name)
	if texture == null or not MenuArtLayout.LAYERS.has(layer_name):
		return null
	var rect: Rect2 = MenuArtLayout.LAYERS[layer_name]
	var layer := TextureRect.new()
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.position = rect.position
	layer.size = rect.size
	_stage.add_child(layer)
	return layer


## A clipped window holding a tiled texture that scrolls (waterfall / river motion).
func _add_scrolling_tile(rect: Rect2, tile_name: String, alpha: float, horizontal: bool) -> TextureRect:
	var texture := Art.menu(tile_name)
	if texture == null:
		return null
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = rect.position
	clip.size = rect.size
	_stage.add_child(clip)
	var tile := TextureRect.new()
	tile.texture = texture
	tile.stretch_mode = TextureRect.STRETCH_TILE
	tile.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.modulate.a = alpha
	var extra := texture.get_size()
	tile.size = rect.size + (Vector2(extra.x, 0.0) if horizontal else Vector2(0.0, extra.y))
	clip.add_child(tile)
	return tile


func _relayout() -> void:
	if _stage == null:
		return
	var cover := maxf(size.x / MenuArtLayout.ART_SIZE.x, size.y / MenuArtLayout.ART_SIZE.y)
	_stage.scale = Vector2(cover, cover)
	_stage.position = (size - MenuArtLayout.ART_SIZE * cover) * 0.5


func _process(delta: float) -> void:
	_time += delta
	for c in _clouds:
		var node: Control = c["node"]
		node.position.x = fposmod(float(c["x0"]) + _time * float(c["speed"]), float(c["span"])) - 40.0
	for s in _sway:
		var node2: Control = s["node"]
		node2.rotation = sin(_time * 0.7 + float(s["phase"])) * 0.012
	if _fall_tile != null:
		_fall_tile.position.y = -_fall_tile.texture.get_size().y + fposmod(_time * 170.0, _fall_tile.texture.get_size().y)
	if _glint_tile != null:
		_glint_tile.position.x = -_glint_tile.texture.get_size().x + fposmod(_time * 16.0, _glint_tile.texture.get_size().x)
