extends Area3D

signal recogido
signal terminado

@export var duracion = 5.0
@export var altura_con_elixir = 4.0

var usado = false

func _enter_tree():
	add_to_group("elixires")

func _ready():
	body_entered.connect(_on_body_entered)

func _process(delta):
	$Modelo.rotate_y(delta * 2.0)

func _on_body_entered(cuerpo):
	if usado or not cuerpo.is_in_group("jugador"):
		return
	usado = true
	recogido.emit()
	$Sonido.play()
	$Modelo.visible = false
	$CollisionShape3D.set_deferred("disabled", true)
	var altura_antes = cuerpo.altura_salto
	cuerpo.altura_salto = altura_con_elixir
	await get_tree().create_timer(duracion).timeout
	cuerpo.altura_salto = altura_antes
	terminado.emit()
	queue_free()
