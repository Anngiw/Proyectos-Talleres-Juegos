extends Camera3D
## Cámara que sigue al Personaje manteniendo la distancia y el ángulo con los que se colocó en el editor.

@export var objetivo: Node3D
@export var suavizado: float = 6.0

var _desfase: Vector3 = Vector3.ZERO


func _ready() -> void:
	if objetivo:
		_desfase = global_position - objetivo.global_position


func _process(delta: float) -> void:
	if objetivo:
		var destino := objetivo.global_position + _desfase
		global_position = global_position.lerp(destino, 1.0 - exp(-suavizado * delta))
