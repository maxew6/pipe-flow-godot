class_name UiKit
extends RefCounted
## Design tokens and small style/drawing helpers shared by every screen.
## Everything here is PROCEDURAL PLACEHOLDER art, not final production assets.

const PIPE_RADIUS := 0.2  # half the pipe thickness, as a fraction of the tile size

# Colours come from the design system (DS). These names are kept so older code still works.
const WOOD_DARK := DS.WOOD_DARK
const WOOD := DS.WOOD
const WOOD_LIGHT := DS.WOOD_LIGHT
const PARCHMENT := DS.PARCHMENT
const INK := DS.INK
const GOLD := DS.GOLD
const GOLD_DARK := DS.GOLD_DARK
const GREEN := DS.GREEN
const GREEN_DARK := DS.GREEN_DARK
const BLUE := DS.BLUE
const BLUE_DARK := DS.BLUE_DARK
const CORAL := DS.CORAL
const CORAL_DARK := DS.CORAL_DARK
const STONE := DS.STONE
const STONE_DARK := DS.STONE_DARK
const MOSS_DARK := Color("1f4a2b")

# Metal and copper (pipe art)
const OUTLINE := Color("262c35")
const METAL_DARK := Color("6d7b8a")
const METAL := Color("a5b3c0")
const METAL_LIGHT := Color("e3ecf3")
const METAL_MID := Color("8b99a8")
const COPPER := Color("cf8040")
const COPPER_LIGHT := Color("f0b27a")
const COPPER_DARK := Color("86471c")

# Water
const WATER_DEEP := DS.AQUA_DEEP
const WATER_LIGHT := DS.AQUA_LIGHT

const EASY_COLOR := DS.EASY_COLOR
const MEDIUM_COLOR := DS.MEDIUM_COLOR
const HARD_COLOR := DS.HARD_COLOR
const EXTREME_COLOR := DS.EXTREME_COLOR


static func box(fill: Color, border: Color, radius: int, border_w: int = 4, shadow: int = 0, pad: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	if shadow > 0:
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0.0, float(shadow) * 0.5)
	if pad > 0:
		sb.set_content_margin_all(float(pad))
	return sb


## Wooden sign panel (HUD bars, level headers).
static func wood_panel() -> StyleBoxTexture:
	return _panel("panel_wood", 64.0, 34.0, 28.0, 40.0)


## Parchment panel in a wooden frame (pause, settings, level complete).
static func parchment_panel() -> StyleBoxTexture:
	return _panel("panel_parchment", 100.0, 64.0, 56.0, 70.0)


static func _panel(texture_name: String, slice: float, side: float, top: float, bottom: float) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = Art.ui(texture_name)
	sb.texture_margin_left = slice
	sb.texture_margin_right = slice
	sb.texture_margin_top = slice
	sb.texture_margin_bottom = slice
	sb.content_margin_left = side
	sb.content_margin_right = side
	sb.content_margin_top = top
	sb.content_margin_bottom = bottom
	return sb


## Compatibility shim: maps the old (fill, border) colour arguments to a GameButton kind.
static func style_button(btn: Button, fill: Color, _border: Color, font_size: int = 54) -> void:
	var kind := GameButton.WOOD
	if fill == GREEN:
		kind = GameButton.GREEN
	elif fill == BLUE:
		kind = GameButton.BLUE
	GameButton.skin(btn, kind, font_size)
	polish_button(btn)


static func make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.03, 1.0))
	var heading_font := DS.font_display() if font_size >= 56 else DS.font_body()
	if heading_font != null:
		label.add_theme_font_override("font", heading_font)
	label.add_theme_constant_override("outline_size", maxi(2, int(float(font_size) / 9.0)))
	return label


## A straight metal pipe segment (for the tank/tap stubs). Call from inside ci's _draw().
static func pipe_segment(ci: CanvasItem, a: Vector2, b: Vector2, r: float) -> void:
	ci.draw_line(a, b, OUTLINE, r * 2.0 * 1.18)
	ci.draw_line(a, b, METAL_DARK, r * 2.0)
	ci.draw_line(a, b, METAL, r * 2.0 * 0.72)
	ci.draw_line(a, b, METAL_LIGHT, r * 2.0 * 0.34)


## A straight water segment. Call from inside ci's _draw().
static func water_segment(ci: CanvasItem, a: Vector2, b: Vector2, r: float) -> void:
	ci.draw_line(a, b, WATER_DEEP, r * 2.0)
	ci.draw_line(a, b, WATER_LIGHT, r * 0.9)


static func make_plain_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func difficulty_color(difficulty: String) -> Color:
	if difficulty == Difficulty.MEDIUM:
		return MEDIUM_COLOR
	if difficulty == Difficulty.HARD:
		return HARD_COLOR
	if difficulty == Difficulty.EXTREME:
		return EXTREME_COLOR
	return EASY_COLOR


## Keeps a control's pivot at its centre so scale/rotation animate around the middle.
static func center_pivot(ctrl: Control) -> void:
	ctrl.resized.connect(func() -> void: ctrl.pivot_offset = ctrl.size * 0.5)
	ctrl.pivot_offset = ctrl.size * 0.5


static func scale_to(node: Control, target: float, seconds: float) -> void:
	var old: Variant = node.get_meta("scale_tween", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(target, target), seconds)
	node.set_meta("scale_tween", tw)


## Subtle press animation + click sound. style_button() applies this automatically.
static func polish_button(btn: Button) -> void:
	center_pivot(btn)
	btn.button_down.connect(func() -> void: scale_to(btn, 0.94, 0.06))
	btn.button_up.connect(func() -> void: scale_to(btn, 1.0, 0.14))
	btn.pressed.connect(func() -> void: _play_click(btn))


static func _play_click(btn: Button) -> void:
	var tree := btn.get_tree()
	if tree == null:
		return
	var feedback := tree.root.get_node_or_null("Feedback")
	if feedback != null and feedback.has_method("play"):
		feedback.play("click")


## Margins that keep content clear of notches and system bars.
## x = top margin, y = bottom margin (viewport pixels). Approximate; verify on device.
static func safe_margins(ctrl: Control, base: int) -> Vector2i:
	var top := base
	var bottom := base
	var win := DisplayServer.window_get_size()
	if win.y > 0:
		var safe := DisplayServer.get_display_safe_area()
		var factor := ctrl.get_viewport_rect().size.y / float(win.y)
		top += clampi(int(float(safe.position.y) * factor), 0, 160)
		bottom += clampi(int(float(win.y - safe.end.y) * factor), 0, 160)
	return Vector2i(top, bottom)
