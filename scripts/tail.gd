extends Control

@export var fill_color: Color  = Color(1, 1, 1, 0.95)
@export var border_color: Color = Color(0.1, 0.15, 0.3)
@export var border_width: float = 2.0

func _draw() -> void:
	var w := size.x
	var h := size.y

	var pts := PackedVector2Array([
		Vector2(w * 0.5, h),  # bottom center
		Vector2(0, 0),        # top left
		Vector2(w, 0)         # top right
	])

	draw_polygon(pts, PackedColorArray([fill_color, fill_color, fill_color]))
	draw_line(pts[1], pts[0], border_color, border_width)
	draw_line(pts[0], pts[2], border_color, border_width)
	draw_line(pts[2], pts[1], border_color, border_width)
