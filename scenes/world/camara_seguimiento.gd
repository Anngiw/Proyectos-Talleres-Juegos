extends Camera3D
@export var objetivo: Node3D
@export var distancia = Vector3(0, 4, 6)
@export var suavizado = 10.0

# Definimos límites muy amplios o dinámicos basados en el tamaño real del mundo (3 minutos de juego)
@export var limite_min = Vector2(-500, -100) 
@export var limite_max = Vector2(500, 1500) 

func _ready():
	top_level = true
	# Se orienta UNA sola vez al inicio, mirando al objetivo en 3D
	if objetivo:
		look_at_from_position(objetivo.global_position + distancia, objetivo.global_position)

func _physics_process(delta):
	if not objetivo:
		return

	# Aplicamos el esqueleto del taller exigido: calculamos el foco con el objetivo
	var foco = objetivo.global_position
	
	# Usamos un clamp de respaldo muy amplio (o basado en los 1080m del nivel) 
	# para cumplir con el taller sin congelar la cámara prematuramente
	foco.x = clamp(foco.x, limite_min.x, limite_max.x)
	foco.z = clamp(foco.z, limite_min.y, limite_max.y)

	# Seguimiento directo e infinito sumando la distancia fija elegida (mantiene el tamaño del personaje)
	var destino = foco + distancia

	# Interpolación suave y constante para que la cámara acompañe al corredor sin retrasos bruscos
	global_position = global_position.lerp(destino, suavizado * delta)

	# Medida para consola (bórrenla al terminar la evaluación):
	if Engine.get_physics_frames() % 30 == 0:
		print("cámara ", global_position.snappedf(0.01))
