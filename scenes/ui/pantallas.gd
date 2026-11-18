extends CanvasLayer

var juego = null

func _ready():
	juego = get_tree().get_first_node_in_group("juego")
	juego.pausa_cambiada.connect(_on_pausa)
	juego.terminado.connect(_on_terminado)
	$Panel/Centro/Caja/BotonContinuar.pressed.connect(juego.reanudar)
	$Panel/Centro/Caja/BotonReiniciar.pressed.connect(juego.reiniciar)
	$Panel/Centro/Caja/BotonMenu.pressed.connect(juego.ir_al_menu)

func _on_pausa(activa):
	if activa:
		mostrar("PAUSA", "El juego está detenido", Color("#00F5D4"), true)
	else:
		$Panel.visible = false

func _on_terminado(ganado, motivo):
	if ganado:
		mostrar("¡GANASTE!", motivo, Color("#FFB703"), false)
	else:
		mostrar("PERDISTE", motivo, Color("#D90429"), false)

func mostrar(titulo, mensaje, color, con_continuar):
	$Panel/Centro/Caja/Titulo.text = titulo
	$Panel/Centro/Caja/Titulo.add_theme_color_override("font_color", color)
	$Panel/Centro/Caja/Mensaje.text = mensaje
	$Panel/Centro/Caja/BotonContinuar.visible = con_continuar
	$Panel.visible = true
	if con_continuar:
		$Panel/Centro/Caja/BotonContinuar.grab_focus()
	else:
		$Panel/Centro/Caja/BotonReiniciar.grab_focus()
