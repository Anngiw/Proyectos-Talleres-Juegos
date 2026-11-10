extends Control

func _ready():
	custom_minimum_size = Vector2(40, 36)

func _draw():
	var rojo = Color("#D90429")
	draw_circle(Vector2(11, 11), 10, rojo)
	draw_circle(Vector2(29, 11), 10, rojo)
	draw_colored_polygon(PackedVector2Array([Vector2(2, 15), Vector2(38, 15), Vector2(20, 35)]), rojo)
