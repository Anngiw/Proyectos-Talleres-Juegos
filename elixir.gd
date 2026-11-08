extends Node

enum Estado { LISTA, ACTIVA, RECARGA }

@export var tecla = "elixir"
@export var duracion = 5.0
@export var recarga = 10.0
@export var elixires = 3
@onready var pj = get_parent()

var estado = Estado.LISTA
var tiempo = 0.0
var altura_antes = 0.0

func _physics_process(delta):
	tiempo -= delta
	match estado:
		Estado.LISTA:
			if Input.is_action_just_pressed(tecla) and puede():
				empezar()
		Estado.ACTIVA:
			if tiempo <= 0.001:
				terminar()
		Estado.RECARGA:
			if tiempo <= 0.001:
				estado = Estado.LISTA

func puede():
	return elixires > 0

func empezar():
	estado = Estado.ACTIVA
	tiempo = duracion
	elixires -= 1
	altura_antes = pj.altura_salto
	pj.altura_salto = 4.0
	print("empieza: ", tecla, " cuadro ", Engine.get_physics_frames())
	print("cazadores al 70 %")
	print("salto ", snappedf(sqrt(2 * pj.gravedad * pj.altura_salto), 0.01), " m/s · elixires que quedan ", elixires)

func terminar():
	estado = Estado.RECARGA
	tiempo = recarga
	pj.altura_salto = altura_antes
	print("termina: ", tecla, " cuadro ", Engine.get_physics_frames())
