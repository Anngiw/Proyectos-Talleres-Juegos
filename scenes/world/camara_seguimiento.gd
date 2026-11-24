extends Camera3D

@export var objetivo: Node3D
@export var distancia: float = 6.0
@export var distancia_minima: float = 1.2
@export var altura_inicial: float = 2.5
@export var sensibilidad_mouse: float = 0.003
@export var suavizado: float = 14.0
@export var margen_colision: float = 0.25
@export_flags_3d_physics var mascara_colision: int = 1

var yaw: float = 0.0
var pitch: float = 0.35 # inclinación inicial hacia abajo

const PITCH_MIN: float = -0.6
const PITCH_MAX: float = 1.3

func _ready() -> void:
	top_level = true
	# Captura el cursor al iniciar el juego para la vista 360
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if objetivo:
		global_position = _evitar_colision(objetivo.global_position + _calcular_offset())
		look_at(objetivo.global_position + Vector3(0, 1.0, 0), Vector3.UP)

# Control con ESC para liberar/capturar el cursor
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		yaw -= event.relative.x * sensibilidad_mouse
		pitch -= event.relative.y * sensibilidad_mouse
		pitch = clamp(pitch, PITCH_MIN, PITCH_MAX)

func _physics_process(delta: float) -> void:
	if not objetivo:
		return

	var destino = objetivo.global_position + _calcular_offset()
	destino = _evitar_colision(destino)

	global_position = global_position.lerp(destino, clamp(suavizado * delta, 0.0, 1.0))
	
	# Mira hacia el centro del personaje
	var foco = objetivo.global_position + Vector3(0, 1.0, 0)
	look_at(foco, Vector3.UP)

func _calcular_offset() -> Vector3:
	var dist = max(distancia, distancia_minima)
	return Vector3(
		sin(yaw) * cos(pitch) * dist,
		sin(pitch) * dist + altura_inicial,
		cos(yaw) * cos(pitch) * dist
	)

func _evitar_colision(destino: Vector3) -> Vector3:
	var origen = objetivo.global_position + Vector3(0, 1.2, 0)
	var direccion = destino - origen
	var largo = direccion.length()
	if largo <= 0.001:
		return origen

	var consulta = PhysicsRayQueryParameters3D.create(origen, destino, mascara_colision)
	consulta.exclude = [self, objetivo]
	if objetivo is CollisionObject3D:
		consulta.exclude.append(objetivo.get_rid())

	var golpe = get_world_3d().direct_space_state.intersect_ray(consulta)
	var resultado = destino

	if not golpe.is_empty():
		var dist_golpe = origen.distance_to(golpe.position)
		var dist_segura = max(dist_golpe - margen_colision, distancia_minima)
		resultado = origen + (direccion / largo) * dist_segura

	# Evita quedar por debajo del piso
	if resultado.y < 0.2:
		resultado.y = 0.2

	return resultado
