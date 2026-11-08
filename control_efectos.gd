class_name ControlEfectos
extends Node

@export var objetivo: GeometryInstance3D
@export var tecla := KEY_F
@export var radio := 3.0
@export var dura_flash := 0.4

var mat: ShaderMaterial
var flash := 0.0

func _ready() -> void:
	mat = objetivo.material_override.duplicate()
	objetivo.material_override = mat
	for d in get_tree().get_nodes_in_group("disparadores"):
		d.evento.connect(_on_evento)
	print(ControlEfectos.mezclar(Color(0.8, 0.2, 0.1), Color.WHITE, 0.25))
	print(k_para(0.5), " ", k_para(0.4), " ", k_para(0.8))

func _process(delta: float) -> void:
	if Input.is_physical_key_pressed(tecla):
		golpe()
	flash = decaer(flash, 0.0, k_para(dura_flash), delta)
	mat.set_shader_parameter("flash", flash)
	if flash > 0.001:
		print(objetivo.name, " ", snappedf(flash, 0.001))

func _on_evento(posicion: Vector3) -> void:
	if objetivo.global_position.distance_to(posicion) <= radio:
		golpe()

func golpe() -> void:
	flash = 1.0

static func mezclar(base: Color, color_flash: Color, t: float) -> Color:
	return base + (color_flash - base) * t

static func decaer(actual: float, base: float, k: float, dt: float) -> float:
	return actual + (base - actual) * (1.0 - exp(-k * dt))

static func k_para(duracion: float) -> float:
	return 3.0 / duracion
