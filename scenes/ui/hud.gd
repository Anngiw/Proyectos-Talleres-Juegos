extends CanvasLayer

var total = 0
var recogidas = 0

func _ready():
	var reliquias = get_tree().get_nodes_in_group("reliquias")
	total = reliquias.size()
	for r in reliquias:
		r.recogida.connect(_on_reliquia)
	for e in get_tree().get_nodes_in_group("elixires"):
		e.recogido.connect(_on_elixir_recogido)
		e.terminado.connect(_on_elixir_terminado)
	actualizar()

func _on_reliquia():
	recogidas += 1
	actualizar()

func _on_elixir_recogido():
	$Elixir.visible = true

func _on_elixir_terminado():
	$Elixir.visible = false

func actualizar():
	$Reliquias.text = "Reliquias: %d/%d" % [recogidas, total]
