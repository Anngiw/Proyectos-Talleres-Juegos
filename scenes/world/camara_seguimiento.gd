extends Camera3D

@export var objetivo: Node3D
@export var distancia: float = 6.0
@export var altura_inicial: float = 2.5
@export var sensibilidad_mouse: float = 0.003
@export var suavizado: float = 14.0

var yaw: float = 0.0
var pitch: float = 0.35 # inclinación inicial hacia abajo

const PITCH_MIN: float = -0.6
const PITCH_MAX: float = 1.3

func _ready() -> void:
	top_level = true
	# Captura el cursor al iniciar el juego para la vista 360
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if objetivo:
		global_position = objetivo.global_position + Vector3(0, altura_inicial, distancia)
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

	# Calcula la posición orbital alrededor del personaje
	var offset = Vector3(
		sin(yaw) * cos(pitch) * distancia,
		sin(pitch) * distancia + altura_inicial,
		cos(yaw) * cos(pitch) * distancia
	)
	
	var destino = objetivo.global_position + offset
	global_position = global_position.lerp(destino, suavizado * delta)
	
	# Mira hacia el centro del personaje
	var foco = objetivo.global_position + Vector3(0, 1.0, 0)
	look_at(foco, Vector3.UP)
