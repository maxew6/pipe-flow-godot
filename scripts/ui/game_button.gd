class_name GameButton
extends RefCounted
## The one button component. Every textured button in the game (menu, pause,
## settings, level complete, HUD) is skinned here so they all share one look:
##   kind "green" = primary action, "blue" = utility, "wood" = navigation.
## Skinning keeps the Button's own text; an optional icon sits at the left.

const GREEN := "green"
const BLUE := "blue"
const WOOD := "wood"

const _TEXT_OUTLINE := {
	"green": DS.OUTLINE_GREEN,
	"blue": DS.OUTLINE_BLUE,
	"wood": DS.OUTLINE_WOOD,
}


## Creates a ready-to-use button (skin, press animation, click sound, optional icon).
static func create(text: String, kind: String, height: int, font_size: int, icon_name: String = "") -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0.0, float(height))
	skin(btn, kind, font_size, icon_name != "")
	if icon_name != "":
		var icon_size := float(DS.ICON_PRIMARY if height >= DS.BTN_H_PRIMARY else DS.ICON_BUTTON)
		var icon := TextureRect.new()
		icon.texture = Art.ui("icon_" + icon_name)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
		icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		icon.offset_left = 44.0
		icon.offset_right = 44.0 + icon_size
		icon.offset_top = -icon_size * 0.5 - 4.0
		icon.offset_bottom = icon_size * 0.5 - 4.0
	UiKit.polish_button(btn)
	return btn


## Applies the textured skin and text style to an existing Button.
## States: normal, hover (slightly lighter), pressed (darker, label drops 4 px), disabled (dimmed, opaque),
## focus (none; the game is touch-first). All kinds share one geometry so buttons look like one family.
static func skin(btn: Button, kind: String, font_size: int, has_icon: bool = false) -> void:
	btn.add_theme_stylebox_override("normal", _box(kind, Color.WHITE, has_icon, false))
	btn.add_theme_stylebox_override("hover", _box(kind, Color(1.05, 1.05, 1.05), has_icon, false))
	btn.add_theme_stylebox_override("pressed", _box(kind, Color(0.86, 0.86, 0.86), has_icon, true))
	btn.add_theme_stylebox_override("disabled", _box(kind, Color(0.62, 0.64, 0.64), has_icon, false))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", font_size)
	var body := DS.font_body()
	if body != null:
		btn.add_theme_font_override("font", body)
	var outline: Color = _TEXT_OUTLINE.get(kind, DS.OUTLINE_WOOD)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(color_name, DS.TEXT_LIGHT)
	btn.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.7))
	btn.add_theme_color_override("font_outline_color", outline)
	btn.add_theme_constant_override("outline_size", DS.OUTLINE_TEXT)
	btn.focus_mode = Control.FOCUS_NONE


## Puts a small icon directly left of the label and centres the icon + label pair in the button
## (anchored to the centre, so it stays centred at any button width).
static func add_centered_icon(btn: Button, icon_texture: Texture2D, gap: float = 14.0) -> void:
	if icon_texture == null:
		return
	var font := btn.get_theme_font("font")
	var font_size := btn.get_theme_font_size("font_size")
	var text_width := font.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var icon_size := icon_texture.get_size()
	var shift := icon_size.x + gap
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := btn.get_theme_stylebox(state) as StyleBoxTexture
		if sb != null:
			sb.content_margin_left += shift
	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	var group_width := shift + text_width
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -group_width * 0.5
	icon.offset_right = icon.offset_left + icon_size.x
	icon.offset_top = -icon_size.y * 0.5 - 4.0
	icon.offset_bottom = icon.offset_top + icon_size.y


static func _box(kind: String, tint: Color, has_icon: bool, pressed: bool) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = Art.ui("btn_" + kind)
	sb.texture_margin_left = 52.0
	sb.texture_margin_right = 52.0
	sb.texture_margin_top = 50.0
	sb.texture_margin_bottom = 58.0
	sb.modulate_color = tint
	sb.content_margin_left = 36.0 + (84.0 if has_icon else 0.0)
	sb.content_margin_right = 36.0
	sb.content_margin_top = 12.0 if pressed else 6.0
	sb.content_margin_bottom = 12.0 if pressed else 18.0
	return sb
