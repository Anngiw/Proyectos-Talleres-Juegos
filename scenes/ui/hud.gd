extends CanvasLayer

const CORAZON = preload("res://scenes/ui/corazon.tscn")

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
	var vidas = get_tree().get_first_node_in_group("vidas")
	if vidas != null:
		for i in vidas.vidas:
			$Corazones.add_child(CORAZON.instantiate())
		vidas.vida_perdida.connect(_on_vida_perdida)
	actualizar()

func _on_reliquia():
	recogidas += 1
	actualizar()

func _on_elixir_recogido():
	$Elixir.visible = true

func _on_elixir_terminado():
	$Elixir.visible = false

func _on_vida_perdida(restantes):
	for i in $Corazones.get_child_count():
		$Corazones.get_child(i).visible = i < restantes

func actualizar():
	$Reliquias.text = "Reliquias: %d/%d" % [recogidas, total]
