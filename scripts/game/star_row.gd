class_name StarRow
extends Control
## Row of `total` stars, the first `filled` of them gold (textured, assets/ui/star_*.png).

var total: int = 3
var filled: int = 0:
	set(value):
		filled = clampi(value, 0, total)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var gold := Art.ui("star_gold")
	var empty := Art.ui("star_empty")
	var slot := size.x / float(total)
	var star_size := minf(slot, size.y)
	for i in total:
		var center := Vector2(slot * (float(i) + 0.5), size.y * 0.5)
		var rect := Rect2(center - Vector2(star_size, star_size) * 0.5, Vector2(star_size, star_size))
		var texture := gold if i < filled else empty
		if texture != null:
			draw_texture_rect(texture, rect, false)
