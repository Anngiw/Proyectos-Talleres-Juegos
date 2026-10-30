class_name SistemaSol
extends Node

@export var sol: DirectionalLight3D
@export var entorno: WorldEnvironment
@export var energia_sol := 1.0
@export var azimut := -30.0 # grados en Y: hacia dónde caen las sombras
@export var ambiente_dia := 1.0
@export var ambiente_noche := 0.2

@onready var ciclo: CicloDia = $CicloDia

func _ready() -> void:
	aplicar_hora()

func _process(delta: float) -> void:
	ciclo.avanzar(delta)
	aplicar_hora()

func aplicar_hora() -> void:
	var h := ciclo.hora
	var f := CicloDia.factor_sol(h)
	sol.rotation_degrees = Vector3(-CicloDia.elevacion(h), azimut, 0.0) # Con signo negativo para que rote correctamente en el eje X de Godot
	sol.light_energy = f * energia_sol
	sol.light_color = CicloDia.color_sol(h)
	entorno.environment.ambient_light_energy = lerpf(ambiente_noche, ambiente_dia, f)

static func lambert(normal: Vector3, hacia_luz: Vector3) -> float:
	var n_norm = normal.normalized()
	var l_norm = hacia_luz.normalized()
	return maxf(0.0, n_norm.dot(l_norm))

func prediccion_piso() -> float:
	var hacia_luz = sol.global_transform.basis.z
	var normal_piso = Vector3(0.0, 1.0, 0.0)
	var difusa = lambert(normal_piso, hacia_luz)
	return sol.light_energy * sol.light_color.r * difusa
