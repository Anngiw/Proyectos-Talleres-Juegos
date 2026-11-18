extends Node

signal portal_abierto
signal pausa_cambiada(activa)
signal terminado(ganado, motivo)

enum Estado { JUGANDO, PAUSA, GANADO, PERDIDO }

@export var duracion = 180.0

var estado = Estado.JUGANDO
var tiempo = 0.0
var recogidas = 0
var total = 0

func _enter_tree():
	add_to_group("juego")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready():
	tiempo = duracion
	var reliquias = get_tree().get_nodes_in_group("reliquias")
	total = reliquias.size()
	for r in reliquias:
		r.recogida.connect(_on_reliquia)
	var vidas = get_tree().get_first_node_in_group("vidas")
	if vidas != null:
		vidas.sin_vidas.connect(_on_sin_vidas)
	for p in get_tree().get_nodes_in_group("portal"):
		p.entro_jugador.connect(_on_portal)

func _process(delta):
	if estado != Estado.JUGANDO:
		return
	tiempo = maxf(tiempo - delta, 0.0)
	if tiempo <= 0.0:
		terminar(false, "Se acabó el tiempo")

func _unhandled_input(event):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_P:
		alternar_pausa()
	elif event.keycode == KEY_R and estado != Estado.JUGANDO:
		reiniciar()

func alternar_pausa():
	if estado == Estado.JUGANDO:
		estado = Estado.PAUSA
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pausa_cambiada.emit(true)
	elif estado == Estado.PAUSA:
		reanudar()

func reanudar():
	estado = Estado.JUGANDO
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pausa_cambiada.emit(false)

func reiniciar():
	get_tree().paused = false
	get_tree().reload_current_scene()

func ir_al_menu():
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/ui/menu_principal.tscn")

func terminar(ganado, motivo):
	if estado == Estado.GANADO or estado == Estado.PERDIDO:
		return
	estado = Estado.GANADO if ganado else Estado.PERDIDO
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	terminado.emit(ganado, motivo)

func _on_reliquia():
	recogidas += 1
	if recogidas >= total:
		for p in get_tree().get_nodes_in_group("portal"):
			p.abrir()
		portal_abierto.emit()

func _on_portal():
	if estado == Estado.JUGANDO:
		terminar(true, "Cruzaste el portal con todas las reliquias")

func _on_sin_vidas():
	terminar(false, "Te quedaste sin vidas")
