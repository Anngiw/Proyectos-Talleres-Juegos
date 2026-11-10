extends Area3D

signal activada(posicion)

func _enter_tree():
	add_to_group("balizas")

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(cuerpo):
	if not cuerpo.is_in_group("jugador"):
		return
	encender()
	activada.emit(global_position)

func encender():
	var base = StandardMaterial3D.new()
	base.albedo_color = Color("#00F5D4")
	base.emission_enabled = true
	base.emission = Color("#00F5D4")
	$Modelo.material_override = base
	var haz = StandardMaterial3D.new()
	haz.albedo_color = Color(0, 0.9608, 0.8314, 0.8)
	haz.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	$Haz.material_override = haz
	$Luz.light_energy = 2.0
