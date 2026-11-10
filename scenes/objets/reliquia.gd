extends Area3D

signal recogida

var ya_recogida = false

func _enter_tree():
	add_to_group("reliquias")

func _ready():
	body_entered.connect(_on_body_entered)

func _process(delta):
	$Modelo.rotate_y(delta * 2.0)

func _on_body_entered(cuerpo):
	if ya_recogida or not cuerpo.is_in_group("jugador"):
		return
	ya_recogida = true
	recogida.emit()
	$Sonido.play()
	$Modelo.visible = false
	$CollisionShape3D.set_deferred("disabled", true)
	await $Sonido.finished
	queue_free()
