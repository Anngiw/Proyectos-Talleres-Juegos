extends Node

signal vida_perdida(restantes)
signal sin_vidas

@export var vidas = 3
@export var retraso = 1.2
@export var invulnerable = 3.0

var punto = Vector3.ZERO
var reloj = 0.0
var muriendo = false
var jugador = null
var cazadores = []

func _enter_tree():
	add_to_group("vidas")

func _ready():
	jugador = get_tree().get_first_node_in_group("jugador")
	punto = jugador.global_position
	for nodo in get_parent().get_children():
		if "rango_vision" in nodo:
			cazadores.append(nodo)
	var balizas = get_tree().get_nodes_in_group("balizas")
	for b in balizas:
		b.activada.connect(_on_baliza)
	if balizas.size() > 0:
		punto = balizas[0].global_position + Vector3.UP * 0.2
		balizas[0].encender()

func _on_baliza(posicion):
	punto = posicion + Vector3.UP * 0.2

func _physics_process(delta):
	reloj = maxf(reloj - delta, 0.0)
	if muriendo or reloj > 0.0:
		return
	for c in cazadores:
		if is_instance_valid(c) and c.estado == c.Estado.ATACAR:
			perder_vida()
			return

func perder_vida():
	muriendo = true
	vidas = maxi(vidas - 1, 0)
	vida_perdida.emit(vidas)
	print("vidas: ", vidas)
	await get_tree().create_timer(retraso).timeout
	if vidas == 0:
		sin_vidas.emit()
		print("sin vidas")
		get_tree().reload_current_scene()
		return
	jugador.global_position = punto
	jugador.velocity = Vector3.ZERO
	jugador.avance = Vector3.ZERO
	jugador.animar()
	for c in cazadores:
		if is_instance_valid(c) and c.puntos.size() > 0 and c.global_position.distance_to(punto) < 15.0:
			c.global_position = c.puntos[0]
			c.estado = c.Estado.PATRULLAR
			c.busca = 0.0
	reloj = invulnerable
	muriendo = false
