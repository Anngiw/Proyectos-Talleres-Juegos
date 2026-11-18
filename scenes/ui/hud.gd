extends CanvasLayer

const CORAZON = preload("res://scenes/ui/corazon.tscn")

var total = 0
var recogidas = 0
var juego = null
var reloj_alerta = 0.0

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
	juego = get_tree().get_first_node_in_group("juego")
	if juego != null:
		juego.portal_abierto.connect(_on_portal_abierto)
	actualizar()

func _process(delta):
	if juego == null:
		return
	var t = int(ceil(juego.tiempo))
	$Tiempo.text = "%02d:%02d" % [floori(t / 60.0), t % 60]
	var alerta = juego.tiempo <= 30.0 and juego.estado == juego.Estado.JUGANDO
	$AlertaTexto.visible = alerta
	$Tiempo.add_theme_color_override("font_color", Color("#D90429") if juego.tiempo <= 30.0 else Color("#00F5D4"))
	if alerta:
		reloj_alerta += delta
		$Alerta.color.a = 0.08 + 0.22 * absf(sin(reloj_alerta * 4.0))
		if not $Alarma.playing:
			$Alarma.play()
	else:
		$Alerta.color.a = 0.0
		$Alarma.stop()

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

func _on_portal_abierto():
	$Mensaje.visible = true
	await get_tree().create_timer(5.0).timeout
	$Mensaje.visible = false

func actualizar():
	$Reliquias.text = "Reliquias: %d/%d" % [recogidas, total]
