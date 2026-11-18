extends Area3D

signal entro_jugador

var abierto = false

func _enter_tree():
	add_to_group("portal")

func _ready():
	body_entered.connect(_on_body_entered)

func _process(delta):
	$Anillo.rotate_y(delta)

func abrir():
	abierto = true
	var m = StandardMaterial3D.new()
	m.albedo_color = Color("#00F5D4")
	m.emission_enabled = true
	m.emission = Color("#00F5D4")
	m.emission_energy_multiplier = 3.0
	$Anillo.material_override = m
	$Luz.light_color = Color("#00F5D4")
	$Luz.light_energy = 4.0

func _on_body_entered(cuerpo):
	if abierto and cuerpo.is_in_group("jugador"):
		entro_jugador.emit()
