extends Camera3D
@export var objetivo: Node3D
@export var distancia = Vector3(0, 4, 6)

func _ready():
	top_level = true
	# Se orienta UNA vez, mirando al objetivo en entorno 3D.
	look_at_from_position(objetivo.global_position + distancia,
	objetivo.global_position)

func _physics_process(_delta):
	# Sigue de forma fluida la posición global del personaje sumando la distancia ampliada
	global_position = objetivo.global_position + distancia
