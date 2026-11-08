class_name ControlEfectos
extends Node

@export var objetivo: GeometryInstance3D
@export var tecla := KEY_F
@export var radio := 3.0
@export var dura_flash := 0.4
@export var dura_dissolve := 1.0
@export var puntos := 100

var mat: ShaderMaterial
var flash := 0.0
var avance := 0.0
var disolviendo := false

func _ready() -> void:
	mat = objetivo.material_override.duplicate()
	objetivo.material_override = mat
	for d in get_tree().get_nodes_in_group("disparadores"):
		d.evento.connect(_on_evento)
	print(ControlEfectos.mezclar(Color(0.8, 0.2, 0.1), Color.WHITE, 0.25))
	print(k_para(0.5), " ", k_para(0.4), " ", k_para(0.8))
	print(avance_en(0.0, 0.5, 2.0), " ", avance_visible(0.0), " ", avance_visible(1.0))

func _process(delta: float) -> void:
	if Input.is_physical_key_pressed(tecla):
		golpe()
	flash = decaer(flash, 0.0, k_para(dura_flash), delta)
	mat.set_shader_parameter("flash", flash)
	if flash > 0.001:
		print(objetivo.name, " ", snappedf(flash, 0.001))
	if Input.is_physical_key_pressed(KEY_E):
		disolver()
	if disolviendo:
		avance = avance_en(avance, delta, dura_dissolve)
		mat.set_shader_parameter("avance", avance_visible(avance))
		if avance >= 1.0:
			objetivo.visible = false
			disolviendo = false

func _on_evento(posicion: Vector3) -> void:
	if objetivo.global_position.distance_to(posicion) <= radio:
		golpe()

func golpe() -> void:
	flash = 1.0

func disolver() -> void:
	disolviendo = true

func usar() -> void:
	objetivo.remove_from_group("interactivos")
	disolver()

static func mezclar(base: Color, color_flash: Color, t: float) -> Color:
	return base + (color_flash - base) * t

static func decaer(actual: float, base: float, k: float, dt: float) -> float:
	return actual + (base - actual) * (1.0 - exp(-k * dt))

static func k_para(duracion: float) -> float:
	return 3.0 / duracion

static func avance_en(actual: float, dt: float, duracion: float) -> float:
	return minf(1.0, actual + dt / duracion)

static func avance_visible(a: float) -> float:
	return lerpf(0.2, 0.8, a)
