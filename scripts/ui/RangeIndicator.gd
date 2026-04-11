extends Node2D
# RangeIndicator — draws a semi-transparent ring at a given radius.
# Add as a child of any unit that needs a visible attack-range circle.

class_name RangeIndicator

var radius: float = 375.0
var ring_color: Color = Color(0.85, 0.75, 0.2, 0.45)  # gold ring


func _ready() -> void:
	z_index = -1          # render behind units, above map background
	queue_redraw()


func _draw() -> void:
	# Very faint filled disc
	draw_circle(Vector2.ZERO, radius,
		Color(ring_color.r, ring_color.g, ring_color.b, 0.05))
	# Visible ring outline
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 80, ring_color, 1.5)
