extends CharacterBody3D
#Nivel 3
enum Estado { QUIETO, CAMINAR, CORRER, AIRE, MUERTO }
const RUIDO = [0.0, 2.0, 6.0, 0.0, 0.0]
const RUTA_SCRIPT_ESFERA := "res://radar_esfera_hud.gd"
# ---
signal golpeado
signal repelido_terminado
signal salto_iniciado(con_elixir: bool)
signal murio
signal vida_cambiada(vidas_actuales: int)
signal reaparecio_en_baliza(pos: Vector3)

@export var camara: Camera3D
@export var speed_caminar: float = 6
@export var speed_correr: float = 7
@export var tiempo_arranque: float = 0.18
@export var gravedad: float = 14.0
@export var altura_salto: float = 2.5

@export_group("Vidas y Baliza")
@export var vidas_iniciales: int = 3
@export var iniciar_en_baliza: bool = true
@export var tiempo_invulnerable_respawn: float = 1.8
@export var posicion_respaldo: Vector3 = Vector3.ZERO

@export_group("Muerte (Daño, Titileo e Impulso)")
@export var fuerza_lanzar_atras: float = 9.5
@export var impulso_lanzar_arriba: float = 2.6
@export var duracion_muerte_video: float = 0.55
@export var energia_destello_inicial: float = 4.0
@export var frecuencia_titileo_dano: float = 24.0

@export_group("Esfera Radar (Esquina Inferior Derecha)")
@export var radar_activo: bool = true
@export var tamano_esfera_hud: Vector2 = Vector2(210.0, 178.0)
@export var margen_esfera_hud: Vector2 = Vector2(24.0, 22.0)
@export var distancia_cerca: float = 10.0
@export var distancia_media: float = 24.0
@export var frecuencia_titileo_lejos: float = 2.2
@export var frecuencia_titileo_cerca: float = 15.0

@onready var anim = $Modelo/Rogue/AnimationPlayer

@onready var audio_pasos: AudioStreamPlayer3D = $paso if has_node("paso") else null
@onready var audio_salto: AudioStreamPlayer3D = $salto if has_node("salto") else null
var _tiempo_paso: float = 0.0
@export var intervalo_caminar: float = 0.5
@export var intervalo_correr: float = 0.28

# Enchufes: otros scripts (las acciones del juego) cambian estas variables.
var multiplicador = 1.0     # 1 = rapidez normal, 0.5 = la mitad, 0 = quieto
var empuje = Vector3.ZERO   # velocidad extra en m/s (dash, retroceso)
var accion = ""             # animación de la acción; "" = ninguna
var avance = Vector3.ZERO   # [NOTA ASIGNADA POR CAMBIO DE DISEÑO 2.5D A 3.0D] La parte de la velocidad que dan las teclas
var estado = Estado.QUIETO
var ruido = 0.0

# --- Estado de vidas y muerte ---
var elixir_activo := false
var invulnerable := 0.0
var control_activo := true
var efectos = null
var oculto := false
var vidas: int = 3

var _muriendo := false
var _muerto_definitivo := false
var _id_muerte := 0
var _t_muerte_restante := 0.0
var _fase_dano := 0.0
var _capa_original := 2
var _mascara_original := 1
var _mat_destello: StandardMaterial3D = null
var _ultima_accion := ""
var _emitio_repelido := false
var _radar_hud: Control = null


func _ready() -> void:
	add_to_group("jugador")
	_capa_original = collision_layer
	_mascara_original = collision_mask
	if posicion_respaldo == Vector3.ZERO:
		posicion_respaldo = global_position

	vidas = maxi(1, vidas_iniciales)
	var nodo_vidas := _obtener_nodo_vidas()
	if nodo_vidas != null and "vidas" in nodo_vidas and int(nodo_vidas.vidas) > 0:
		vidas = int(nodo_vidas.vidas)

	_configurar_loops_animacion(["Idle", "Walk", "Run", "Roll"])
	_preparar_destello_blanco()
	call_deferred("_montar_esfera_radar")
	if iniciar_en_baliza:
		call_deferred("_ubicar_en_baliza_inicial")
	call_deferred("_notificar_hud_vidas")
	animar()


func _montar_esfera_radar() -> void:
	if not is_inside_tree():
		return
	if not ResourceLoader.exists(RUTA_SCRIPT_ESFERA):
		print("[radar_esfera] No se encontró el script en: ", RUTA_SCRIPT_ESFERA)
		return
	var script_esfera: Script = load(RUTA_SCRIPT_ESFERA) as Script
	if script_esfera == null:
		return

	var existente := get_tree().root.find_child("RadarEsferaInferiorDerecha", true, false)
	if existente is Control:
		_radar_hud = existente as Control
	else:
		var layer := CanvasLayer.new()
		layer.name = "CapaRadarEsfera"
		layer.layer = 15
		get_tree().root.add_child(layer)

		_radar_hud = Control.new()
		_radar_hud.name = "RadarEsferaInferiorDerecha"
		_radar_hud.set_script(script_esfera)
		layer.add_child(_radar_hud)

	if _radar_hud:
		_radar_hud.set("activo", radar_activo)
		_radar_hud.set("tamano_radar", tamano_esfera_hud)
		_radar_hud.set("margen_inferior_derecho", margen_esfera_hud)
		_radar_hud.set("distancia_cerca", distancia_cerca)
		_radar_hud.set("distancia_media", distancia_media)
		_radar_hud.set("frecuencia_lejos", frecuencia_titileo_lejos)
		_radar_hud.set("frecuencia_cerca", frecuencia_titileo_cerca)
		if _radar_hud.has_method("configurar_jugador"):
			_radar_hud.call("configurar_jugador", self)


func _configurar_loops_animacion(nombres: Array) -> void:
	if not anim:
		return
	for nombre in nombres:
		if anim.has_animation(nombre):
			var clip: Animation = anim.get_animation(nombre)
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR


func _obtener_nodo_vidas() -> Node:
	var n := get_tree().get_first_node_in_group("vidas")
	if n == null and get_parent() and get_parent().has_node("Vidas"):
		n = get_parent().get_node("Vidas")
	return n


func _obtener_nodos_hud() -> Array[Node]:
	var encontrados: Array[Node] = []
	for nodo in get_tree().get_nodes_in_group("hud"):
		if is_instance_valid(nodo) and nodo not in encontrados:
			encontrados.append(nodo)
	var hud_por_nombre := get_tree().root.find_child("Hud", true, false)
	if hud_por_nombre and is_instance_valid(hud_por_nombre) and hud_por_nombre not in encontrados:
		encontrados.append(hud_por_nombre)
	return encontrados


func _notificar_hud_vidas() -> void:
	vida_cambiada.emit(vidas)
	for nodo in _obtener_nodos_hud():
		if nodo.has_method("_on_vida_perdida"):
			nodo.call("_on_vida_perdida", vidas)
		if nodo.has_node("Corazones"):
			var cont := nodo.get_node("Corazones")
			for i in range(cont.get_child_count()):
				cont.get_child(i).visible = i < vidas


func _llamar_si_coincide(obj: Object, metodo: String, args: Array = []) -> bool:
	if obj == null or not is_instance_valid(obj) or not obj.has_method(metodo):
		return false
	for info in obj.get_method_list():
		if info.get("name", "") == metodo:
			var total_args: int = info.get("args", []).size()
			var max_args: int = total_args
			var min_args: int = maxi(0, total_args - info.get("default_args", []).size())
			if args.size() >= min_args and args.size() <= max_args:
				obj.callv(metodo, args)
				return true
	return false


func _notificar_derrota() -> void:
	var juego := get_tree().get_first_node_in_group("juego")
	if juego == null and get_parent() and get_parent().has_node("Juego"):
		juego = get_parent().get_node("Juego")
	if juego:
		if not _llamar_si_coincide(juego, "perder", []):
			if not _llamar_si_coincide(juego, "fin_juego", [false]):
				_llamar_si_coincide(juego, "game_over", [])

	var pantallas := get_tree().root.find_child("Pantallas", true, false)
	if pantallas:
		if not _llamar_si_coincide(pantallas, "mostrar_derrota", []):
			if not _llamar_si_coincide(pantallas, "derrota", []):
				_llamar_si_coincide(pantallas, "perder", [])


func _ubicar_en_baliza_inicial() -> void:
	if not is_inside_tree():
		return
	var baliza_ini := _obtener_baliza_cercana()
	if baliza_ini != Vector3.ZERO or _tiene_baliza_en_escena():
		global_position = baliza_ini
		velocity = Vector3.ZERO
		avance = Vector3.ZERO
		empuje = Vector3.ZERO


func _tiene_baliza_en_escena() -> bool:
	for b in get_tree().get_nodes_in_group("balizas"):
		if b is Node3D and is_instance_valid(b):
			return true
	for b in get_tree().get_nodes_in_group("zona_segura"):
		if b is Node3D and is_instance_valid(b):
			return true
	return false


func _obtener_baliza_cercana() -> Vector3:
	var balizas := get_tree().get_nodes_in_group("balizas")
	balizas.append_array(get_tree().get_nodes_in_group("zona_segura"))
	var mejor_pos := posicion_respaldo
	var mejor_dist := INF
	for b in balizas:
		if b is Node3D and is_instance_valid(b):
			var dist := global_position.distance_to(b.global_position)
			if dist < mejor_dist:
				mejor_dist = dist
				mejor_pos = b.global_position + Vector3(0.0, 0.5, 0.0)
	return mejor_pos


func _preparar_destello_blanco() -> void:
	_mat_destello = StandardMaterial3D.new()
	_mat_destello.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	_mat_destello.emission_enabled = true
	_mat_destello.emission = Color(1.0, 1.0, 1.0, 1.0)
	_mat_destello.emission_energy_multiplier = energia_destello_inicial
	_mat_destello.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _aplicar_destello_blanco(activo: bool) -> void:
	if not has_node("Modelo"):
		return
	$Modelo.visible = true
	if activo and _mat_destello:
		_mat_destello.emission_energy_multiplier = energia_destello_inicial
	for mesh_inst in _buscar_meshes($Modelo):
		if activo:
			mesh_inst.material_override = _mat_destello
		else:
			if mesh_inst.material_override == _mat_destello:
				mesh_inst.material_override = null


func _buscar_meshes(nodo: Node) -> Array[MeshInstance3D]:
	var lista: Array[MeshInstance3D] = []
	for hijo in nodo.get_children():
		if hijo is MeshInstance3D:
			lista.append(hijo)
		lista.append_array(_buscar_meshes(hijo))
	return lista


func _physics_process(delta):
	if not is_inside_tree():
		return

	if _muerto_definitivo:
		empuje = empuje.move_toward(Vector3.ZERO, 15.0 * delta)
		velocity.x = empuje.x
		velocity.z = empuje.z
		if not is_on_floor():
			velocity.y -= gravedad * delta
		elif velocity.y < 0.0:
			velocity.y = 0.0
		move_and_slide()
		estado = Estado.MUERTO
		ruido = 0.0
		return

	if _muriendo:
		_fase_dano += delta * frecuencia_titileo_dano
		empuje = empuje.move_toward(Vector3.ZERO, 14.0 * delta)
		if empuje.length() < 0.2 and not _emitio_repelido:
			_emitio_repelido = true
			repelido_terminado.emit()
		velocity.x = empuje.x
		velocity.z = empuje.z
		if not is_on_floor():
			velocity.y -= gravedad * delta
		elif velocity.y < 0.0:
			velocity.y = 0.0
		move_and_slide()

		if has_node("Modelo"):
			var f := clampf(_t_muerte_restante / maxf(duracion_muerte_video, 0.01), 0.0, 1.0)
			var onda := sin(_fase_dano)
			$Modelo.visible = onda > -0.35
			if _mat_destello:
				var pulso := 0.5 + 0.5 * absf(onda)
				_mat_destello.emission_energy_multiplier = lerpf(1.2, energia_destello_inicial, f) * pulso

		estado = Estado.MUERTO
		ruido = RUIDO[estado]
		_prueba()
		return

	invulnerable = maxf(0.0, invulnerable - delta)
	if has_node("Modelo") and invulnerable > 0.0:
		$Modelo.visible = int(invulnerable * 10.0) % 2 == 0
	elif has_node("Modelo"):
		$Modelo.visible = true

	# --- Gravedad y salto ----------------------------------------------------
	if not is_on_floor():
		velocity.y -= gravedad * delta
	elif control_activo and Input.is_action_just_pressed("saltar"):
		velocity.y = sqrt(2 * gravedad * altura_salto)
		salto_iniciado.emit(elixir_activo)
		if audio_salto and audio_salto.stream:
			audio_salto.play()

	# --- Movimiento en X y Z con Cámara, Correr, Arranque y Frenado --------
	var entrada = Input.get_vector("move_left", "move_right", "move_up", "move_down") if control_activo else Vector2.ZERO

	var giro_cam = camara.global_rotation.y if camara else 0.0
	var direction = Vector3(entrada.x, 0.0, entrada.y).rotated(Vector3.UP, giro_cam).normalized()

	var corre = control_activo and Input.is_action_pressed("correr")
	var speed = speed_correr if corre else speed_caminar

	var objetivo = direction * speed * multiplicador
	var paso = (speed / tiempo_arranque) * delta

	avance = avance.move_toward(objetivo, paso)

	velocity.x = avance.x + empuje.x
	velocity.z = avance.z + empuje.z

	# --- Rotación suave hacia donde camina según la cámara -------------------
	if direction.length() > 0:
		var angulo_objetivo = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, angulo_objetivo, 14.0 * delta)

	# --- Control rítmico de pasos al caminar o correr ------------------------
	if is_on_floor() and direction.length() > 0:
		_tiempo_paso += delta
		var intervalo_actual = intervalo_correr if corre else intervalo_caminar
		if _tiempo_paso >= intervalo_actual:
			_tiempo_paso = 0.0
			if audio_pasos and audio_pasos.stream:
				audio_pasos.play()
	else:
		_tiempo_paso = intervalo_caminar

	# --- Esqueleto viejo borrado Control de Animaciones ----------------------------------------------
	#_________________

	move_and_slide()
	var antes = estado
	estado = elegir_estado()
	ruido = RUIDO[estado]
	if estado != antes or accion != _ultima_accion:
		print("estado ", Estado.keys()[estado], " · ruido ", ruido, " m")
		animar()
	elif anim and not anim.is_playing() and anim.current_animation != "":
		anim.speed_scale = 1.0
		anim.play()
	_prueba()


func golpear(desde: Vector3) -> void:
	golpeado.emit()
	morir(desde)


func quitar_vida(desde: Vector3 = Vector3.ZERO) -> void:
	morir(desde)


func perder_vida(desde: Vector3 = Vector3.ZERO) -> void:
	morir(desde)


func recibir_daño(_cantidad: float = 1.0, desde: Vector3 = Vector3.ZERO) -> void:
	golpeado.emit()
	morir(desde)


func morir(desde: Vector3 = Vector3.ZERO) -> void:
	if _muerto_definitivo or _muriendo or invulnerable > 0.0 or not is_inside_tree():
		return
	_muriendo = true
	_emitio_repelido = false
	_id_muerte += 1
	var token_actual := _id_muerte
	_t_muerte_restante = duracion_muerte_video
	_fase_dano = 0.0

	vidas = maxi(0, vidas - 1)
	var nodo_vidas := _obtener_nodo_vidas()
	if nodo_vidas != null:
		if "vidas" in nodo_vidas:
			nodo_vidas.vidas = vidas
		if nodo_vidas.has_signal("vida_perdida"):
			nodo_vidas.emit_signal("vida_perdida", vidas)
	_notificar_hud_vidas()

	control_activo = false
	multiplicador = 0.0
	avance = Vector3.ZERO
	accion = ""
	estado = Estado.MUERTO
	ruido = RUIDO[estado]

	collision_layer = 0
	collision_mask = _mascara_original

	var dir_atras := Vector3.ZERO
	if desde != Vector3.ZERO:
		dir_atras = Vector3(global_position.x - desde.x, 0.0, global_position.z - desde.z)
	if dir_atras.length_squared() < 0.001:
		dir_atras = -global_transform.basis.z
	dir_atras = dir_atras.normalized()

	empuje = dir_atras * fuerza_lanzar_atras
	velocity = Vector3(empuje.x, impulso_lanzar_arriba, empuje.z)

	_aplicar_destello_blanco(true)
	animar()
	_resolver_muerte_video(token_actual)


func _resolver_muerte_video(token_actual: int) -> void:
	var paso := 0.04
	while _t_muerte_restante > 0.0:
		if not is_inside_tree() or token_actual != _id_muerte or not _muriendo:
			return
		var espera_t := minf(paso, _t_muerte_restante)
		await get_tree().create_timer(espera_t).timeout
		_t_muerte_restante = maxf(0.0, _t_muerte_restante - espera_t)

	if not is_inside_tree() or token_actual != _id_muerte or not _muriendo:
		return

	_aplicar_destello_blanco(false)
	if not _emitio_repelido:
		_emitio_repelido = true
		repelido_terminado.emit()

	if vidas > 0:
		_reaparecer_en_baliza()
	else:
		_muriendo = false
		_muerto_definitivo = true
		control_activo = false
		multiplicador = 0.0
		avance = Vector3.ZERO
		if has_node("Modelo"):
			$Modelo.visible = false
		_notificar_derrota()
		murio.emit()


func _reaparecer_en_baliza() -> void:
	var destino_respawn := _obtener_baliza_cercana()
	_muriendo = false
	_t_muerte_restante = 0.0
	_fase_dano = 0.0
	global_position = destino_respawn
	velocity = Vector3.ZERO
	avance = Vector3.ZERO
	empuje = Vector3.ZERO
	accion = ""
	multiplicador = 1.0
	control_activo = true
	collision_layer = _capa_original
	collision_mask = _mascara_original
	invulnerable = tiempo_invulnerable_respawn

	_aplicar_destello_blanco(false)
	if has_node("Modelo"):
		$Modelo.visible = true

	estado = elegir_estado()
	ruido = RUIDO[estado]
	animar()
	reaparecio_en_baliza.emit(destino_respawn)


func elegir_estado():
	if _muriendo or _muerto_definitivo:
		return Estado.MUERTO
	if not is_on_floor():
		return Estado.AIRE
	var rapidez = Vector2(velocity.x, velocity.z).length()
	if rapidez < 0.1:
		return Estado.QUIETO
	if rapidez > speed_caminar + 0.1:
		return Estado.CORRER
	return Estado.CAMINAR


func animar():
	var animacion_deseada = ""

	if accion != "":
		animacion_deseada = accion
	else:
		match estado:
			Estado.QUIETO:
				animacion_deseada = "Idle"
			Estado.CAMINAR:
				animacion_deseada = "Walk"
			Estado.CORRER:
				animacion_deseada = "Run"
			Estado.AIRE:
				animacion_deseada = "Roll"
			Estado.MUERTO:
				animacion_deseada = "Idle"

	_ultima_accion = accion
	if anim and animacion_deseada != "":
		anim.speed_scale = 1.0
		if anim.current_animation != animacion_deseada or not anim.is_playing():
			anim.play(animacion_deseada)


# ---------------------------------------------------------------------------
# PRUEBAS AUTOMÁTICAS. No hace falta entender esta parte: en el Inspector del
# Personaje elijan "Prueba" (y, si la prueba usa una acción, escriban su nombre
# en "Accion Prueba"). Con F5 el personaje se mueve solo y escribe los números
# en el panel Output. La última línea de _physics_process() es _prueba().
# ---------------------------------------------------------------------------
@export_enum("Ninguna", "Avanzar 60 cuadros", "Avanzar 60 y soltar", "Avanzar y la acción desde el cuadro 30", "Mantener la acción 2 s", "Avanzar con la acción 60 cuadros", "Diagonal W+D 60 cuadros") var prueba = 0
@export var accion_prueba = ""
var _cuadro = 0
var _termino = false
var _y_max = 0.0
var _cuadro_max = 0


func _prueba():
	if prueba == 0 or _termino:
		return
	_cuadro += 1
	var avanzar = "move_right"
	var lado = "move_up"
	if _cuadro == 1:
		if prueba <= 3 or prueba == 5:
			_apretar(avanzar)
		if prueba == 4 or prueba == 5:
			_apretar(accion_prueba)
		if prueba == 6:
			_apretar(avanzar)
			_apretar(lado)
		return
	var n = _cuadro - 1
	if prueba == 3 and n == 30:
		_apretar(accion_prueba)
	if prueba == 2 and n == 60:
		Input.action_release(avanzar)
	var marcas = []
	if prueba == 1 or prueba == 5:
		marcas = [1, 2, 3, 5, 10, 15, 20, 30, 60]
	elif prueba == 2:
		marcas = [59, 60, 61, 62, 63, 65, 70, 80, 90]
	elif prueba == 3:
		marcas = [29, 30, 31, 32, 33, 35, 40, 45, 50, 60, 75, 90]
	elif prueba == 6:
		marcas = [1, 30, 60]
	else:
		marcas = [1, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150]
	if n in marcas:
		print("[prueba] cuadro ", n, ": ", _resumen())
	_cambios(n)
	if global_position.y > _y_max + 0.0001:
		_y_max = global_position.y
		_cuadro_max = n
	if n == marcas[-1]:
		Input.action_release(avanzar)
		Input.action_release(lado)
		_soltar(accion_prueba)
		_termino = true
		if _y_max > 0.01:
			print("[prueba] altura máxima ", snappedf(_y_max, 0.01), " en el cuadro ", _cuadro_max)


func _resumen():
	var t = "posición " + str(global_position.snappedf(0.01))
	t += " · rapidez " + str(snappedf(avance.length(), 0.01))
	t += " · y " + str(snappedf(global_position.y, 0.01))
	t += " · animación " + str(anim.current_animation)
	for nodo in _con_estado():
		t += " · " + str(nodo.name) + ".estado " + _nombre(nodo)
	return t


# Escribe el cuadro exacto en el que cambia cualquier variable "estado".
var _antes = {}


func _cambios(n):
	for nodo in _con_estado():
		var e = _nombre(nodo)
		if _antes.has(nodo) and _antes[nodo] != e:
			print("[prueba] cuadro ", n, ": ", nodo.name, ".estado cambia a ", e)
		_antes[nodo] = e


func _con_estado():
	var lista = []
	for nodo in [self] + get_children() + get_tree().get_nodes_in_group("probar"):
		if nodo.get_script() != null and "estado" in nodo:
			lista.append(nodo)
	return lista


func _nombre(nodo):
	var nombres = nodo.get_script().get_script_constant_map().get("Estado", {})
	for k in nombres:
		if nombres[k] == nodo.estado:
			return k
	return str(nodo.estado)


func _apretar(a):
	if a == "":
		print("[prueba] escriban el nombre de la acción en 'Accion Prueba'")
	elif not InputMap.has_action(a):
		print("[prueba] falta la acción '", a, "' en el Input Map")
	else:
		Input.action_press(a)


func _soltar(a):
	if a != "" and InputMap.has_action(a):
		Input.action_release(a)
