extends CharacterBody3D

enum Estado { PATRULLAR, ESPERAR, PERSEGUIR, ATACAR, BUSCAR }

@export var rapidez = 4.5
@export var fuerza_salto = 5.8
@export var espera = 1.0
@export var rango_vision = 26.0
@export var rango_ataque = 1.5
@export var tiempo_busqueda = 5.0
@export var retraso_ataque = 0.25

@export_group("Recorrido Individual y Persecución")
@export var multiplicador_persecucion: float = 1.24
@export var factor_anticipacion: float = 0.22
@export var radio_exploracion_mapa: float = 28.0
@export var cantidad_puntos_exploracion: int = 8
@export var detectar_siempre_en_rango: bool = true

# Ruta por defecto individual si no hay marcadores propios
@export var ruta: Array[Vector3] = [
	Vector3.ZERO,
	Vector3(14, 0, 0),
	Vector3(14, 0, -14),
	Vector3(-14, 0, -14),
	Vector3(-14, 0, 14)
]

var estado = Estado.PATRULLAR
var puntos: Array[Vector3] = []
var indice = 0
var reloj = 0.0
var jugador = null
var ultimo_visto = Vector3.ZERO
var _punto_busqueda_fijo = Vector3.ZERO
var _dir_ultimo_visto = Vector3.ZERO
var _dir_evasion = Vector3.ZERO
var _tiempo_evasion = 0.0
var busca = 0.0
var tiempo_animacion = 0.0
var _reloj_ataque = 0.0
var _pos_inicial = Vector3.ZERO

@onready var anim = $Modelo/AnimationPlayer
@onready var vision = $Vision
@onready var luz_corporal = $LuzCorporal if has_node("LuzCorporal") else null

# Referencia exacta al nodo "laser" en minúsculas tal como está en Cazador_2.tscn
@onready var laser = $laser if has_node("laser") else ($Laser if has_node("Laser") else null)


func _ready():
	_pos_inicial = global_position
	jugador = get_tree().get_first_node_in_group("jugador")

	_construir_ruta_individual()

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


func _construir_ruta_individual() -> void:
	puntos.clear()

	# 1) Si existe un grupo exclusivo para este cazador (ej: puntos_patrulla_Cazador1)
	var grupo_propio: String = "puntos_patrulla_%s" % name
	var marcadores_propios := get_tree().get_nodes_in_group(grupo_propio)
	if not marcadores_propios.is_empty():
		for m in marcadores_propios:
			if m is Node3D:
				puntos.append(m.global_position)
		print(name, " -> Ruta propia cargada (", puntos.size(), " puntos).")
		return

	# 2) Si tiene nodos Marker3D hijos directos
	for hijo in get_children():
		if hijo is Marker3D:
			puntos.append(hijo.global_position)
	if not puntos.is_empty():
		print(name, " -> Ruta desde hijos cargada (", puntos.size(), " puntos).")
		return

	# 3) Ruta individual distribuida por el mapa usando semilla única por cazador
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%s" % [name, str(_pos_inicial)])

	var marcadores_globales := get_tree().get_nodes_in_group("puntos_patrulla")
	var validos: Array[Vector3] = []
	for m in marcadores_globales:
		if m is Node3D:
			validos.append(m.global_position)

	if not validos.is_empty():
		var offset: int = absi(name.hash()) % validos.size()
		for i in range(validos.size()):
			var idx: int = (i + offset) % validos.size()
			var base_p: Vector3 = validos[idx]
			var variacion := Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0))
			puntos.append(Vector3(base_p.x + variacion.x, _pos_inicial.y, base_p.z + variacion.z))
	else:
		for d in ruta:
			var rotado: Vector3 = d.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			puntos.append(Vector3(_pos_inicial.x + rotado.x, _pos_inicial.y, _pos_inicial.z + rotado.z))

	# Añade puntos de exploración amplios para recorrer distintas zonas del mapa
	var extra: int = maxi(4, cantidad_puntos_exploracion)
	for i in range(extra):
		var angulo: float = (TAU * float(i) / float(extra)) + rng.randf_range(-0.35, 0.35)
		var dist: float = rng.randf_range(radio_exploracion_mapa * 0.45, radio_exploracion_mapa)
		var px: float = _pos_inicial.x + cos(angulo) * dist
		var pz: float = _pos_inicial.z + sin(angulo) * dist
		puntos.append(Vector3(px, _pos_inicial.y, pz))

	indice = rng.randi_range(0, maxi(0, puntos.size() - 1))
	print(name, " -> Ruta individual generada con ", puntos.size(), " puntos.")


func _preparar_punto_busqueda() -> void:
	_punto_busqueda_fijo = ultimo_visto
	if _dir_ultimo_visto.length() > 0.15:
		var dir_plana := Vector3(_dir_ultimo_visto.x, 0.0, _dir_ultimo_visto.z).normalized()
		_punto_busqueda_fijo = ultimo_visto + dir_plana * 1.4


func _physics_process(delta):
	# Aplicar gravedad si no está en el suelo
	if not is_on_floor():
		velocity.y -= 12.0 * delta

	reloj = maxf(reloj - delta, 0.0)
	busca = maxf(busca - delta, 0.0)
	_reloj_ataque = maxf(_reloj_ataque - delta, 0.0)
	_tiempo_evasion = maxf(_tiempo_evasion - delta, 0.0)
	tiempo_animacion += delta

	if not jugador or not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador")
		if not jugador:
			move_and_slide()
			return

	# 1. MEDIR (Distancia, detección 360° incluyendo espaldas y balizas seguras)
	var d = distancia_a(jugador.global_position)
	var en_baliza = esta_en_baliza_segura(jugador.global_position)
	var ve = lo_ve() and not en_baliza

	if ve:
		ultimo_visto = jugador.global_position
		if "velocity" in jugador:
			var vh = Vector3(jugador.velocity.x, 0.0, jugador.velocity.z)
			if vh.length() > 0.2:
				_dir_ultimo_visto = vh.normalized()

	# 2. DECIDIR ESTADO
	var nuevo = decidir(d, ve, en_baliza)
	if nuevo != estado:
		estado = nuevo
		_tiempo_evasion = 0.0
		if estado == Estado.ATACAR:
			_reloj_ataque = retraso_ataque
		elif estado == Estado.BUSCAR:
			_preparar_punto_busqueda()
		print(name, " -> Estado: ", Estado.keys()[estado])

	# 3. CONTROL ESTRICTO DE LUCES
	if luz_corporal:
		luz_corporal.visible = true # La luz del cuerpo nunca se apaga

	if laser:
		# ÚNICA CONDICIÓN DE ACTIVACIÓN: El láser se enciende en rojo SOLO si está persiguiendo o atacando
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
			var vel_persecucion = rapidez * multiplicador_persecucion
			var objetivo_calculado = _calcular_objetivo_persecucion(d, vel_persecucion)
			ir_a(objetivo_calculado, vel_persecucion, true)
		Estado.ATACAR:
			velocity.x = 0.0
			velocity.z = 0.0
			var hacia_jug = jugador.global_position - global_position
			hacia_jug.y = 0.0
			if hacia_jug.length() > 0.05:
				var ang_ataque = atan2(-hacia_jug.x, -hacia_jug.z)
				rotation.y = lerp_angle(rotation.y, ang_ataque, 10.0 * delta)
			if _reloj_ataque <= 0.0:
				if anim and anim.current_animation != "Punch":
					anim.play("Punch")

				if jugador.has_method("recibir_daño"):
					jugador.recibir_daño(100.0, global_position)

				var anim_jugador = jugador.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if anim_jugador and anim_jugador.has_animation("Death"):
					if anim_jugador.current_animation != "Death":
						anim_jugador.play("Death")
		Estado.BUSCAR:
			# Avanza una sola vez hacia el punto fijo de búsqueda y luego frena para inspeccionar
			if distancia_a(_punto_busqueda_fijo) > 0.9:
				ir_a(_punto_busqueda_fijo, rapidez * 0.95, false)
			else:
				frenar()
				var ang_base := atan2(-_dir_ultimo_visto.x, -_dir_ultimo_visto.z) if _dir_ultimo_visto.length() > 0.1 else rotation.y
				var giro_inspeccion := sin(tiempo_animacion * 2.2) * 0.55
				rotation.y = lerp_angle(rotation.y, ang_base + giro_inspeccion, 5.0 * delta)

	move_and_slide()


func _calcular_objetivo_persecucion(d: float, vel_mov: float) -> Vector3:
	var objetivo = jugador.global_position
	if "velocity" in jugador:
		var vel_horizontal = Vector3(jugador.velocity.x, 0.0, jugador.velocity.z)
		if vel_horizontal.length() > 0.15:
			var tiempo_llegada = clampf(d / maxf(vel_mov, 1.0), 0.02, factor_anticipacion)
			objetivo += vel_horizontal * tiempo_llegada
	return objetivo


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
	if not jugador or not is_instance_valid(jugador):
		return false

	var dist = global_position.distance_to(jugador.global_position)
	if dist > rango_vision:
		return false

	# Capta al personaje en 360° (incluyendo espaldas) dentro del rango de visión
	if detectar_siempre_en_rango:
		return true

	if not vision:
		return true

	var pecho = jugador.global_position + Vector3(0, 1.0, 0)
	var dir_hacia_jugador = vision.to_local(pecho)
	vision.target_position = dir_hacia_jugador.normalized() * min(dir_hacia_jugador.length(), rango_vision)
	vision.force_raycast_update()

	if vision.is_colliding():
		var col = vision.get_collider()
		if col == jugador or (col and col.is_in_group("jugador")):
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
	if distancia_a(destino) < 1.2:
		indice = (indice + 1) % puntos.size()
		reloj = espera
		frenar()
		return
	ir_a(destino, rapidez, false)


# Solo detecta colisión con cuerpos fijos (StaticBody3D), nunca con el jugador.
func _obtener_normal_obstaculo_fijo() -> Vector3:
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		if not col:
			continue
		var collider := col.get_collider()
		if collider is StaticBody3D:
			var n := col.get_normal()
			n.y = 0.0
			if n.length() > 0.05 and absf(col.get_normal().y) < 0.7:
				return n.normalized()
	return Vector3.ZERO


func ir_a(destino, vel_mov = rapidez, corriendo = false):
	var hacia = destino - global_position
	hacia.y = 0.0

	if hacia.length() > 0.25:
		var dir: Vector3 = hacia.normalized()

		# Esquivar únicamente objetos fijos (StaticBody3D) con dirección estable para evitar temblores
		if is_on_wall() and _tiempo_evasion <= 0.0:
			var normal_fija := _obtener_normal_obstaculo_fijo()
			if normal_fija != Vector3.ZERO:
				var tangente_a := Vector3(-normal_fija.z, 0.0, normal_fija.x).normalized()
				var tangente_b := -tangente_a
				var cand_a: Vector3 = (tangente_a + dir * 0.45).normalized()
				var cand_b: Vector3 = (tangente_b + dir * 0.45).normalized()
				_dir_evasion = cand_a if cand_a.dot(dir) >= cand_b.dot(dir) else cand_b
				_tiempo_evasion = 0.45

		if _tiempo_evasion > 0.0:
			dir = _dir_evasion

		velocity.x = move_toward(velocity.x, dir.x * vel_mov, vel_mov * 12.0 * get_physics_process_delta_time())
		velocity.z = move_toward(velocity.z, dir.z * vel_mov, vel_mov * 12.0 * get_physics_process_delta_time())

		var angulo_objetivo = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, angulo_objetivo, 9.0 * get_physics_process_delta_time())

		if anim:
			if corriendo and anim.has_animation("Run"):
				if anim.current_animation != "Run":
					anim.play("Run")
			elif anim.has_animation("Walk"):
				if anim.current_animation != "Walk":
					anim.play("Walk")
	else:
		velocity.x = move_toward(velocity.x, 0, vel_mov * 10.0 * get_physics_process_delta_time())
		velocity.z = move_toward(velocity.z, 0, vel_mov * 10.0 * get_physics_process_delta_time())
		frenar()


func frenar():
	velocity.x = move_toward(velocity.x, 0, rapidez * 10.0 * get_physics_process_delta_time())
	velocity.z = move_toward(velocity.z, 0, rapidez * 10.0 * get_physics_process_delta_time())
	if anim and anim.has_animation("Idle") and anim.current_animation != "Idle":
		anim.play("Idle")


func distancia_a(p):
	var o = global_position
	return Vector2(p.x - o.x, p.z - o.z).length()
