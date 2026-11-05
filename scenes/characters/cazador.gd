extends CharacterBody3D

enum Estado { PATRULLAR, ESPERAR, PERSEGUIR, ATACAR, BUSCAR}

@export var rapidez = 2.0
@export var espera = 1.0
@export var rango_vision = 7.0
@export var ruta: Array[Vector3] = [Vector3.ZERO, Vector3(0, 0, -6)]

#Nivel 3
@export var rango_ataque = 1.2
@export var rango_perder = 10.0
@export var tiempo_busqueda = 3.0

var estado = Estado.PATRULLAR
var puntos: Array[Vector3] = []
var indice = 0
var reloj = 0.0
var jugador = null
#Nivel 3
var ultimo_visto = Vector3.ZERO
var busca = 0.0

@onready var anim = $Modelo/AnimationPlayer
@onready var vision = $Vision

func _ready():
	jugador = get_tree().get_first_node_in_group("jugador")
	for d in ruta:
		puntos.append(global_position + d)

func _physics_process(delta):
	velocity += get_gravity() * delta
	reloj = maxf(reloj - delta, 0.0)
	busca = maxf(busca - delta, 0.0)
	
	# 1. MEDIR
	var d = distancia_a(jugador.global_position)
	var ve = lo_ve()
	if ve:
		ultimo_visto = jugador.global_position
	
	# 2. DECIDIR
	var nuevo = decidir(d, ve)
	if nuevo != estado:
		estado = nuevo
		print(name, " -> ", Estado.keys()[estado], " cuadro ",
			Engine.get_physics_frames(), " a ", snappedf(d, 0.01), " m")
			
	# 3. ACTUAR
	match estado:
		Estado.PATRULLAR:
			patrullar()
		Estado.ESPERAR:
			frenar()
		Estado.PERSEGUIR:
			ir_a(jugador.global_position)
		Estado.ATACAR:
			velocity.x = 0.0
			velocity.z = 0.0
			if anim.current_animation != "Punch":
				anim.play("Punch")
			
			# Búsqueda segura del AnimationPlayer del jugador sin importar la ruta exacta
			if jugador:
				var anim_jugador = jugador.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if anim_jugador and anim_jugador.has_animation("Death"):
					if anim_jugador.current_animation != "Death":
						anim_jugador.play("Death")
		Estado.BUSCAR:
			if distancia_a(ultimo_visto) > 0.1:
				ir_a(ultimo_visto)
			else:
				frenar()
	move_and_slide()

# El orden ES la regla: el primer if que se cumple gana.
func decidir(d, ve):
	var alerta = estado == Estado.PERSEGUIR or estado == Estado.ATACAR
	var limite = rango_perder if alerta else rango_vision
	
	if ve and d <= rango_ataque:
		return Estado.ATACAR
	if ve and d <= limite:
		return Estado.PERSEGUIR
	if alerta:
		busca = tiempo_busqueda
		return Estado.BUSCAR
	if busca > 0.001:
		return Estado.BUSCAR
	if reloj > 0.001:
		return Estado.ESPERAR
	return Estado.PATRULLAR

func lo_ve():
	# Se apunta al pecho: el origen del jugador está en los pies.
	var pecho = jugador.global_position + Vector3(0, 0.9, 0)
	vision.target_position = vision.to_local(pecho)
	vision.force_raycast_update()
	if vision.is_colliding():
		# ¿Lo primero que tocó fue el jugador, o una pared?
		return vision.get_collider() == jugador
	return true

func patrullar():
	var destino = puntos[indice]
	if distancia_a(destino) < 0.1:
		indice = (indice + 1) % puntos.size()
		reloj = espera
		frenar()
		return
	ir_a(destino)

func ir_a(destino):
	var hacia = destino - global_position
	hacia.y = 0.0
	var dir = hacia.normalized()
	velocity.x = dir.x * rapidez
	velocity.z = dir.z * rapidez
	basis = Basis.looking_at(dir)
	anim.play("Walk")

func frenar():
	velocity.x = 0.0
	velocity.z = 0.0
	anim.play("Idle")

# Distancia en el suelo: si el otro salta, no "se aleja".
func distancia_a(p):
	var o = global_position
	return Vector2(p.x - o.x, p.z - o.z).length()
