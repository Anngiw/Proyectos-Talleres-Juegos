extends Control

@export var activo: bool = true
@export var pausar_si_jugador_muerto: bool = true

@export_group("Posición y Tamaño")
@export var tamano_radar: Vector2 = Vector2(210.0, 178.0)
@export var margen_inferior_derecho: Vector2 = Vector2(24.0, 22.0)
@export var tamano_letra: int = 18

@export_group("Detección y Visibilidad de Reliquia")
@export var grupo_reliquias: String = "reliquias"
@export var distancia_cerca: float = 10.0
@export var distancia_media: float = 24.0
@export var distancia_lejos: float = 45.0
@export var requiere_estar_a_la_vista: bool = true
@export var mascara_vision: int = 1

@export_group("Colores y Titileo")
@export var color_lejos_azul: Color = Color(0.12, 0.56, 0.92, 1.0)
@export var color_medio_blanco: Color = Color(0.92, 0.99, 1.0, 1.0)
@export var color_reliquia_por_defecto: Color = Color(0.0, 0.96, 1.0, 1.0)
@export var leer_color_de_reliquia: bool = true
@export var velocidad_titileo_cerca: float = 12.0
@export var suavizado_transicion: float = 8.0
@export var suavizado_aparicion: float = 7.5

var _jugador: Node3D = null
var _brujula: _BrujulaSensor = null
var _lbl_texto: Label = null
var _color_actual: Color = Color(0.12, 0.56, 0.92, 1.0)
var _cercania_suave: float = 0.0
var _angulo_aguja: float = 0.0
var _fase_titileo: float = 0.0
var _intensidad_titileo: float = 0.45
var _opacidad_actual: float = 0.0


class _BrujulaSensor:
	extends Control

	var color_base: Color = Color(0.12, 0.56, 0.92, 1.0)
	var cercania: float = 0.0
	var angulo_aguja: float = 0.0
	var intensidad_titileo: float = 0.45
	var titilando: bool = false

	func _rotar(origen: Vector2, punto: Vector2, ang: float) -> Vector2:
		var rel := punto - origen
		var c := cos(ang)
		var s := sin(ang)
		return origen + Vector2(rel.x * c - rel.y * s, rel.x * s + rel.y * c)

	func _draw() -> void:
		var s := size
		if s.x <= 4.0 or s.y <= 4.0:
			return

		var centro := s * 0.5
		var radio := minf(s.x, s.y) * 0.44
		var brillo := clampf(intensidad_titileo, 0.2, 1.35)

		if titilando:
			draw_circle(centro, radio * 1.12, Color(color_base.r, color_base.g, color_base.b, 0.22 * brillo))

		draw_circle(centro, radio, Color(0.03, 0.07, 0.13, 0.88))
		draw_arc(centro, radio, 0.0, TAU, 64, Color(color_base.r, color_base.g, color_base.b, clampf(0.55 + 0.4 * brillo, 0.35, 1.0)), 2.4, true)
		draw_arc(centro, radio * 0.76, 0.0, TAU, 64, Color(color_base.r, color_base.g, color_base.b, 0.30 * brillo), 1.4, true)

		for i in range(8):
			var ang := (TAU / 8.0) * float(i) - PI * 0.5
			var dir := Vector2(cos(ang), sin(ang))
			var es_principal := (i % 2 == 0)
			var r_ext := radio - 1.5
			var r_int := radio - (9.5 if es_principal else 5.5)
			var col_marca := color_base.lightened(0.28 * brillo) if es_principal else Color(color_base.r, color_base.g, color_base.b, 0.65)
			draw_line(centro + dir * r_int, centro + dir * r_ext, col_marca, 2.3 if es_principal else 1.5, true)

		var largo_punta := radio * 0.68
		var largo_cola := radio * 0.34
		var ancho_aguja := radio * 0.15

		var punta := _rotar(centro, centro + Vector2(0.0, -largo_punta), angulo_aguja)
		var izq := _rotar(centro, centro + Vector2(-ancho_aguja, 0.0), angulo_aguja)
		var der := _rotar(centro, centro + Vector2(ancho_aguja, 0.0), angulo_aguja)
		var cola := _rotar(centro, centro + Vector2(0.0, largo_cola), angulo_aguja)

		var col_aguja := Color(
			clampf(color_base.r * (0.78 + 0.35 * brillo), 0.0, 1.0),
			clampf(color_base.g * (0.78 + 0.35 * brillo), 0.0, 1.0),
			clampf(color_base.b * (0.78 + 0.35 * brillo), 0.0, 1.0),
			1.0
		)
		var col_cola := Color(color_base.r * 0.45, color_base.g * 0.45, color_base.b * 0.45, 0.88)
		var col_contorno := color_base.lightened(0.45)

		draw_colored_polygon(PackedVector2Array([punta, der, centro, izq]), col_aguja)
		draw_colored_polygon(PackedVector2Array([izq, centro, der, cola]), col_cola)
		draw_polyline(PackedVector2Array([punta, der, cola, izq, punta]), col_contorno, 2.0, true)

		draw_circle(centro, maxf(3.4, radio * 0.09), Color(0.04, 0.08, 0.14, 1.0))
		draw_circle(centro, maxf(2.1, radio * 0.055), col_contorno)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	_color_actual = color_lejos_azul
	_construir_hud()
	_actualizar_layout()


func configurar_jugador(jugador: Node3D) -> void:
	_jugador = jugador


func _construir_hud() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "ContenedorBrujulaHUD"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	_brujula = _BrujulaSensor.new()
	_brujula.name = "BrujulaReliquia"
	_brujula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brujula.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brujula.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_brujula)

	_lbl_texto = Label.new()
	_lbl_texto.name = "TextoBrujula"
	_lbl_texto.text = "Reliquia lejo"
	_lbl_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_texto.add_theme_font_size_override("font_size", tamano_letra)
	_lbl_texto.add_theme_color_override("font_color", _color_actual.lightened(0.3))
	_lbl_texto.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	_lbl_texto.add_theme_constant_override("shadow_offset_x", 1)
	_lbl_texto.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(_lbl_texto)


func _actualizar_layout() -> void:
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	var tam_seguro := Vector2(
		minf(tamano_radar.x, maxf(140.0, vp_size.x - margen_inferior_derecho.x * 2.0)),
		minf(tamano_radar.y, maxf(120.0, vp_size.y - margen_inferior_derecho.y * 2.0))
	)
	size = tam_seguro

	var pos_x := vp_size.x - size.x - margen_inferior_derecho.x
	var pos_y := vp_size.y - size.y - margen_inferior_derecho.y
	position = Vector2(
		clampf(pos_x, 8.0, maxf(8.0, vp_size.x - size.x - 8.0)),
		clampf(pos_y, 8.0, maxf(8.0, vp_size.y - size.y - 8.0))
	)

	if _lbl_texto:
		_lbl_texto.add_theme_font_size_override("font_size", tamano_letra)
	if _brujula:
		_brujula.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_actualizar_layout()


func _obtener_jugador() -> Node3D:
	if _jugador != null and is_instance_valid(_jugador):
		return _jugador
	var n := get_tree().get_first_node_in_group("jugador")
	if n is Node3D:
		_jugador = n as Node3D
	return _jugador


func _jugador_esta_muerto(jug: Node3D) -> bool:
	if not pausar_si_jugador_muerto or jug == null:
		return false
	if "_muerto_definitivo" in jug and bool(jug._muerto_definitivo):
		return true
	if "_muriendo" in jug and bool(jug._muriendo):
		return true
	return false


func _buscar_reliquias_activas() -> Array[Node3D]:
	var lista: Array[Node3D] = []
	for nodo in get_tree().get_nodes_in_group(grupo_reliquias):
		if nodo is Node3D and is_instance_valid(nodo) and nodo not in lista:
			if not nodo.is_inside_tree() or not nodo.visible:
				continue
			var ya_tomada: Variant = nodo.get("ya_recogida")
			if typeof(ya_tomada) == TYPE_BOOL and ya_tomada == true:
				continue
			var recogida_prop: Variant = nodo.get("recogida")
			if typeof(recogida_prop) == TYPE_BOOL and recogida_prop == true:
				continue
			lista.append(nodo as Node3D)
	return lista


func _obtener_color_reliquia(reliquia: Node3D) -> Color:
	if not leer_color_de_reliquia or reliquia == null or not is_instance_valid(reliquia):
		return color_reliquia_por_defecto

	var prop_color: Variant = reliquia.get("color_reliquia")
	if prop_color is Color:
		return prop_color

	var cola: Array[Node] = [reliquia]
	while not cola.is_empty():
		var actual: Node = cola.pop_front()
		if actual is MeshInstance3D:
			var m := actual as MeshInstance3D
			var mat := m.material_override
			if mat == null and m.mesh != null and m.mesh.get_surface_count() > 0:
				mat = m.get_active_material(0)
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				if sm.emission_enabled and sm.emission.get_luminance() > 0.08:
					var em := sm.emission
					em.a = 1.0
					return em
				if sm.albedo_color.get_luminance() > 0.08:
					var alb := sm.albedo_color
					alb.a = 1.0
					return alb
		for h in actual.get_children():
			cola.append(h)

	return color_reliquia_por_defecto


func _reliquia_a_la_vista(jug: Node3D, reliquia: Node3D) -> bool:
	if not requiere_estar_a_la_vista:
		return true
	if jug == null or reliquia == null or not is_instance_valid(reliquia):
		return false

	var cam := get_viewport().get_camera_3d()
	if cam != null:
		if not cam.is_position_in_frustum(reliquia.global_position):
			return false

	var world_3d: World3D = null
	if jug != null and jug.is_inside_tree():
		world_3d = jug.get_world_3d()
	elif cam != null and cam.is_inside_tree():
		world_3d = cam.get_world_3d()

	if world_3d != null and world_3d.direct_space_state != null:
		var desde := cam.global_position if cam != null else (jug.global_position + Vector3(0.0, 1.2, 0.0))
		var hasta := reliquia.global_position + Vector3(0.0, 0.4, 0.0)
		var query := PhysicsRayQueryParameters3D.create(desde, hasta)
		query.collision_mask = mascara_vision
		var excluidos: Array[RID] = []
		if jug is CollisionObject3D:
			excluidos.append((jug as CollisionObject3D).get_rid())
		if reliquia is CollisionObject3D:
			excluidos.append((reliquia as CollisionObject3D).get_rid())
		query.exclude = excluidos
		var hit: Dictionary = world_3d.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var collider: Object = hit.get("collider")
			if collider != null and collider != reliquia and not reliquia.is_ancestor_of(collider as Node):
				return false

	return true


func _calcular_angulo_hacia_reliquia(jug: Node3D, reliquia: Node3D) -> float:
	var delta_pos := reliquia.global_position - jug.global_position
	var dir_mundo := Vector2(delta_pos.x, delta_pos.z)
	if dir_mundo.length_squared() < 0.0001:
		return _angulo_aguja

	var yaw_ref := jug.rotation.y
	if "_camara" in jug and jug._camara is Node3D:
		yaw_ref = (jug._camara as Node3D).global_rotation.y
	elif "camara" in jug and jug.camara is Node3D:
		yaw_ref = (jug.camara as Node3D).global_rotation.y
	else:
		var vp_cam := get_viewport().get_camera_3d()
		if vp_cam != null:
			yaw_ref = vp_cam.global_rotation.y

	var dir_rot := dir_mundo.rotated(-yaw_ref)
	return atan2(dir_rot.x, -dir_rot.y)


func _process(delta: float) -> void:
	_actualizar_layout()

	var jug := _obtener_jugador()
	var reliquias: Array[Node3D] = []
	if activo and is_inside_tree() and jug != null and not _jugador_esta_muerto(jug):
		reliquias = _buscar_reliquias_activas()
	var debe_mostrarse := not reliquias.is_empty()

	var objetivo_alpha := 1.0 if debe_mostrarse else 0.0
	_opacidad_actual = lerpf(_opacidad_actual, objetivo_alpha, clampf(suavizado_aparicion * delta, 0.0, 1.0))
	modulate.a = _opacidad_actual
	visible = _opacidad_actual > 0.01

	if not visible or reliquias.is_empty() or jug == null:
		return

	var rel_cercana: Node3D = reliquias[0]
	var dist_min: float = INF
	for r in reliquias:
		var d: float = jug.global_position.distance_to(r.global_position)
		if d < dist_min:
			dist_min = d
			rel_cercana = r

	var d_cerca: float = maxf(0.5, distancia_cerca)
	var d_media: float = maxf(d_cerca + 0.5, distancia_media)
	var d_lejos: float = maxf(d_media + 1.0, distancia_lejos)

	var cercania_objetivo: float
	if dist_min >= d_media:
		var t_medio := 1.0 - clampf((dist_min - d_media) / (d_lejos - d_media), 0.0, 1.0)
		cercania_objetivo = t_medio * 0.5
	else:
		var t_cerca := 1.0 - clampf((dist_min - d_cerca) / (d_media - d_cerca), 0.0, 1.0)
		cercania_objetivo = 0.5 + t_cerca * 0.5

	_cercania_suave = lerpf(_cercania_suave, cercania_objetivo, clampf(suavizado_transicion * delta, 0.0, 1.0))

	var angulo_objetivo := _calcular_angulo_hacia_reliquia(jug, rel_cercana)
	_angulo_aguja = lerp_angle(_angulo_aguja, angulo_objetivo, clampf(10.0 * delta, 0.0, 1.0))

	var color_reliquia := _obtener_color_reliquia(rel_cercana)
	var color_objetivo: Color
	if _cercania_suave < 0.5:
		color_objetivo = color_lejos_azul.lerp(color_medio_blanco, _cercania_suave * 2.0)
	else:
		color_objetivo = color_medio_blanco.lerp(color_reliquia, (_cercania_suave - 0.5) * 2.0)

	_color_actual = _color_actual.lerp(color_objetivo, clampf(suavizado_transicion * delta, 0.0, 1.0))

	var esta_cerca := dist_min <= d_media
	var a_la_vista := _reliquia_a_la_vista(jug, rel_cercana)
	var debe_titilar := esta_cerca and a_la_vista

	if debe_titilar:
		var urgencia := clampf(1.0 - ((dist_min - d_cerca) / maxf(d_media - d_cerca, 0.5)), 0.25, 1.0)
		_fase_titileo += delta * lerpf(velocidad_titileo_cerca * 0.65, velocidad_titileo_cerca, urgencia) * TAU
		var onda := 0.5 + 0.5 * sin(_fase_titileo)
		_intensidad_titileo = lerpf(0.25, 1.25, onda)
	else:
		_intensidad_titileo = lerpf(_intensidad_titileo, lerpf(0.45, 0.85, _cercania_suave), clampf(8.0 * delta, 0.0, 1.0))

	if _brujula:
		_brujula.color_base = _color_actual
		_brujula.cercania = _cercania_suave
		_brujula.angulo_aguja = _angulo_aguja
		_brujula.intensidad_titileo = _intensidad_titileo
		_brujula.titilando = debe_titilar
		_brujula.queue_redraw()

	if _lbl_texto:
		if esta_cerca:
			_lbl_texto.text = "Reliquia cerca"
		else:
			_lbl_texto.text = "Reliquia lejo"

		var col_lbl := _color_actual.lightened(0.28)
		_lbl_texto.add_theme_color_override("font_color", col_lbl)
