extends CharacterBody3D

enum Estado { PATRULLAR, ESPERAR, PERSEGUIR, ATACAR, BUSCAR }

@export var rapidez = 5.0
@export var fuerza_salto = 5.8 
@export var espera = 1.0
@export var rango_vision = 16.0
@export var rango_ataque = 1.5
@export var tiempo_busqueda = 4.0

# Ruta por defecto (se sobrescribe automáticamente si pones Marker3D en el grupo "puntos_patrulla")
@export var ruta: Array[Vector3] = [
	Vector3.ZERO, 
	Vector3(10, 0, 0), 
	Vector3(10, 0, -10), 
	Vector3(-10, 0, -10)
]

var estado = Estado.PATRULLAR
var puntos: Array[Vector3] = []
var indice = 0
var reloj = 0.0
var jugador = null
var ultimo_visto = Vector3.ZERO
var busca = 0.0
var tiempo_animacion = 0.0

@onready var anim = $Modelo/AnimationPlayer
@onready var vision = $Vision
@onready var luz_corporal = $LuzCorporal if has_node("LuzCorporal") else null

# Nodo Laser (OmniLight3D) estrictamente con S
@onready var laser = $Laser if has_node("Laser") else null

func _ready():
	jugador = get_tree().get_first_node_in_group("jugador")
	
	# Cargar puntos de patrulla inteligentes desde el mapa
	var marcadores = get_tree().get_nodes_in_group("puntos_patrulla")
	if not marcadores.is_empty():
		for m in marcadores:
			if m is Node3D:
				puntos.append(m.global_position)
		print(name, " -> Ruta inteligente cargada: ", puntos.size(), " puntos en el mapa.")
	else:
		for d in ruta:
			puntos.append(global_position + d)
		print(name, " -> Usando ruta local por defecto.")
		
	# 1. Luz corporal PERMANENTE: Siempre activa para iluminar el cuerpo
	if luz_corporal:
		luz_corporal.visible = true
		luz_corporal.light_color = Color(1.0, 0.9, 0.9)
		luz_corporal.omni_range = 4.0
		luz_corporal.light_energy = 2.0

	# 2. APAGADO INICIAL ESTRICTO: El láser arranca completamente apagado
	if laser:
		laser.visible = false
		laser.light_energy = 0.0

func _physics_process(delta):
	# Aplicar gravedad si no está en el suelo
	if not is_on_floor():
		velocity.y -= 12.0 * delta
		
	reloj = maxf(reloj - delta, 0.0)
	busca = maxf(busca - delta, 0.0)
	tiempo_animacion += delta
	
	if not jugador:
		return
	
	# 1. MEDIR (Distancia, visión directa y balizas seguras)
	var d = distancia_a(jugador.global_position)
	var en_baliza = esta_en_baliza_segura(jugador.global_position)
	var ve = lo_ve() and not en_baliza
	
	if ve:
		ultimo_visto = jugador.global_position
	
	# 2. DECIDIR ESTADO
	var nuevo = decidir(d, ve, en_baliza)
	if nuevo != estado:
		estado = nuevo
		print(name, " -> Estado: ", Estado.keys()[estado])
			
	# 3. CONTROL ESTRICTO DE LUCES
	if luz_corporal:
		luz_corporal.visible = true # La luz del cuerpo nunca se apaga

	if laser:
		# ÚNICA CONDICIÓN DE ACTIVACIÓN: El láser se enciende SOLO si está persiguiendo o atacando
		if estado == Estado.PERSEGUIR or estado == Estado.ATACAR:
			laser.visible = true
			if laser is OmniLight3D:
				laser.omni_range = 5.0 + sin(tiempo_animacion * 8.0) * 1.5
			laser.light_color = Color(1.0, 0.0, 0.0)
			laser.light_energy = 8.0
		else:
			# APAGADO ABSOLUTO: Si patrulla, espera o busca, el láser se desactiva por completo
			laser.visible = false
			laser.light_energy = 0.0

	# 4. ACTUAR SEGÚN EL ESTADO
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
			
			if jugador.has_method("recibir_daño"):
				jugador.recibir_daño(100.0)
			
			var anim_jugador = jugador.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if anim_jugador and anim_jugador.has_animation("Death"):
				if anim_jugador.current_animation != "Death":
					anim_jugador.play("Death")
		Estado.BUSCAR:
			if distancia_a(ultimo_visto) > 0.5:
				ir_a(ultimo_visto)
			else:
				frenar()
				
	move_and_slide()

func decidir(d, ve, en_baliza):
	# Si entra a baliza, deja de ver al jugador o se sale del rango de visión -> Termina la persecución al instante
	if en_baliza or not ve or d > rango_vision:
		if estado == Estado.PERSEGUIR or estado == Estado.ATACAR:
			busca = tiempo_busqueda
			return Estado.BUSCAR

	if ve and d <= rango_ataque:
		return Estado.ATACAR
	if ve and d <= rango_vision:
		return Estado.PERSEGUIR
		
	if busca > 0.001:
		return Estado.BUSCAR
	if reloj > 0.001:
		return Estado.ESPERAR
		
	return Estado.PATRULLAR

func lo_ve():
	if not jugador:
		return false
		
	var dist = global_position.distance_to(jugador.global_position)
	if dist > rango_vision:
		return false
		
	var pecho = jugador.global_position + Vector3(0, 1.0, 0)
	var dir_hacia_jugador = vision.to_local(pecho)
	vision.target_position = dir_hacia_jugador.normalized() * min(dir_hacia_jugador.length(), rango_vision)
	vision.force_raycast_update()
	
	if vision.is_colliding():
		var col = vision.get_collider()
		if col == jugador or (col and col.is_in_group("jugador")):
			return true
			
	if dist <= (rango_vision * 0.45):
		return true
	
	return false

func esta_en_baliza_segura(pos: Vector3) -> bool:
	var balizas = get_tree().get_nodes_in_group("balizas")
	balizas.append_array(get_tree().get_nodes_in_group("zona_segura"))
	
	for b in balizas:
		if b.has_method("contiene") and b.contiene(pos):
			return true
		elif "radio" in b and b.global_position.distance_to(pos) <= b.radio:
			return true
		elif b.global_position.distance_to(pos) <= 2.5:
			return true
			
	return false

func patrullar():
	if puntos.is_empty():
		return
	var destino = puntos[indice]
	if distancia_a(destino) < 1.0:
		indice = (indice + 1) % puntos.size()
		reloj = espera
		frenar()
		return
	ir_a(destino)

func ir_a(destino):
	var hacia = destino - global_position
	hacia.y = 0.0 # Aislar componente horizontal
	
	if hacia.length() > 0.2:
		var dir = hacia.normalized()
		
		# Autonomía ante obstáculos (desvío por muros y salto de desniveles)
		if is_on_wall():
			var normal = get_wall_normal()
			dir = dir.slide(normal).normalized()
			
			if is_on_floor() and destino.y > global_position.y + 0.4:
				velocity.y = fuerza_salto
		
		velocity.x = dir.x * rapidez
		velocity.z = dir.z * rapidez
		
		var angulo_objetivo = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, angulo_objetivo, 10.0 * get_physics_process_delta_time())
		
		anim.play("Walk")
	else:
		velocity.x = move_toward(velocity.x, 0, rapidez)
		velocity.z = move_toward(velocity.z, 0, rapidez)
		frenar()

func frenar():
	velocity.x = move_toward(velocity.x, 0, rapidez)
	velocity.z = move_toward(velocity.z, 0, rapidez)
	anim.play("Idle")

func distancia_a(p):
	var o = global_position
	return Vector2(p.x - o.x, p.z - o.z).length()
