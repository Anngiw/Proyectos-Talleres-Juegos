extends Control

func _ready():
	$Centro/Caja/BotonNivel1.pressed.connect(_on_nivel1)
	$Centro/Caja/BotonSalir.pressed.connect(_on_salir)
	$Centro/Caja/BotonNivel1.grab_focus()

func _on_nivel1():
	get_tree().change_scene_to_file("res://scenes/world/world.tscn")

func _on_salir():
	get_tree().quit()
