class_name CicloDia
extends Node

const AZUL_NOCHE := Color("#0B132B") # El color bajo de tu paleta para la noche cerrada

@export var hora := 8.0 # h al empezar
@export var duracion_dia := 48.0 # s reales que dura un día de 24 h
@export var pausado := false

func avanzar(dt: float) -> void:
	if not pausado:
		hora = fposmod(hora + dt * (24.0 / duracion_dia), 24.0) # horas de juego en dt segundos

static func elevacion(h: float) -> float:
	return (h - 6.0) * 15.0 # 6 h -> 0°, 12 h -> 90°, 18 h -> 180°

static func factor_sol(h: float) -> float:
	return maxf(0.0, sin(deg_to_rad(elevacion(h))))

static func color_sol(h: float) -> Color:
	return AZUL_NOCHE.lerp(Color.WHITE, factor_sol(h))
