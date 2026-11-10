extends Area3D

signal activada(posicion)

func _enter_tree():
	add_to_group("balizas")

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(cuerpo):
	if not cuerpo.is_in_group("jugador"):
		return
	var m = StandardMaterial3D.new()
	m.albedo_color = Color("#00F5D4")
	m.emission_enabled = true
	m.emission = Color("#00F5D4")
	$Modelo.material_override = m
	activada.emit(global_position)
