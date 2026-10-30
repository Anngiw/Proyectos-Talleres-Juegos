extends CharacterBody3D
## Personaje base del equipo: Rogue, el explorador (versión 3D).
## Se mueve libremente por el suelo con W A S D (o flechas) y salta con Espacio.
## NO EDITEN este archivo en su rama: usen los tres enchufes de abajo desde su propio script.

# ============================================================================
#  LOS TRES ENCHUFES  (otros scripts pueden cambiarlos; este archivo los usa)
# ============================================================================
## Multiplica la rapidez de las teclas. 1 = normal, 0.5 = mitad, 0 = quieto aunque se presionen teclas.
var multiplicador: float = 1.0
## Velocidad que se SUMA, en m/s (x y z; la y se ignora). Sirve para dash, retroceso o empujón.
var empuje: Vector3 = Vector3.ZERO
## Nombre de una animación de Rogue. Mientras no esté vacío, se hace esa animación en vez de idle/walk.
## Rogue trae: Idle, Walk, Run, Roll, Punch, Dagger_Attack, Dagger_Attack2, Attacking_Idle,
## PickUp, RecieveHit, RecieveHit_2 y Death. (Para repetir una acción, ponla en "" y luego otra vez.)
var accion: String = ""

# ============================================================================
#  NÚMEROS DEL JUEGO
# ============================================================================
@export var speed: float = 4.0          # m/s al caminar
@export var gravedad: float = 9.8       # m/s²
@export var fuerza_salto: float = 6.0   # m/s hacia arriba al saltar
@export var velocidad_giro: float = 12.0  # qué tan rápido gira el modelo hacia donde camina

## Estado actual: "idle", "walk", "jump" o "fall".
var estado: String = "idle"

## Rogue no trae animación de salto ni de caída: se usa Roll al subir y Idle al caer.
## Si el equipo consigue otras, solo se cambia esta tabla.
const ANIMACIONES := {"idle": "Idle", "walk": "Walk", "jump": "Roll", "fall": "Idle"}
## Las animaciones que Rogue trae sin bucle y que deben repetirse mientras dure el estado.
const ANIMACIONES_EN_BUCLE := ["Idle", "Walk", "Run", "Attacking_Idle"]

@onready var modelo: Node3D = $Modelo
@onready var animador: AnimationPlayer = $Modelo/Rogue/AnimationPlayer

var _animacion_actual: String = ""
var _animacion_invalida: String = ""

# ============================================================================
#  PRUEBA AUTOMÁTICA  (Inspector → Prueba; se toca F5 sin tocar el teclado)
# ============================================================================
@export_group("Prueba")
@export_enum("Ninguna", "Avanzar 60 cuadros", "Avanzar 60 y soltar",
		"Avanzar y la acción desde el cuadro 30", "Mantener la acción 2 s",
		"Avanzar con la acción 60 cuadros", "Diagonal W+D 60 cuadros") var prueba: int = 0
## Nombre de la acción del Input Map que usan las pruebas 3, 4 y 5 (por ejemplo: correr).
@export var accion_prueba: String = ""
@export_group("")

const DURACION_PRUEBA := [0, 60, 90, 60, 120, 60, 60]
var _cuadro: int = 0
var _prueba_en_curso: bool = false
var _teclas_pulsadas: Array[String] = []
var _y_suelo: float = 0.0
var _y_suelo_fijada: bool = false
var _altura_maxima: float = 0.0
var _registro_estados: Dictionary = {}


func _ready() -> void:
	for nombre in ANIMACIONES_EN_BUCLE:
		if animador.has_animation(nombre):
			animador.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
	_reproducir("Idle")
	if prueba != 0:
		_prueba_en_curso = true
		print("=== PRUEBA: ", _nombre_de_la_prueba(), " ===")


func _physics_process(delta: float) -> void:
	if _prueba_en_curso:
		_cuadro += 1
		_aplicar_teclas_de_la_prueba()

	# --- Movimiento horizontal (W A S D): libre en x y z --------------------
	var entrada := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direccion := Vector3(entrada.x, 0.0, entrada.y)
	velocity.x = direccion.x * speed * multiplicador + empuje.x
	velocity.z = direccion.z * speed * multiplicador + empuje.z

	# --- Gravedad y salto ----------------------------------------------------
	if not is_on_floor():
		velocity.y -= gravedad * delta
	elif Input.is_action_just_pressed("saltar"):
		velocity.y = fuerza_salto

	move_and_slide()

	# --- Hacia dónde mira ----------------------------------------------------
	var se_mueve := direccion != Vector3.ZERO and multiplicador > 0.0
	if se_mueve:
		var objetivo := atan2(direccion.x, direccion.z)
		modelo.rotation.y = lerp_angle(modelo.rotation.y, objetivo, clampf(velocidad_giro * delta, 0.0, 1.0))

	# --- Estado y animación --------------------------------------------------
	var nuevo := "idle"
	if not is_on_floor():
		nuevo = "jump" if velocity.y > 0.0 else "fall"
	elif se_mueve:
		nuevo = "walk"
	estado = nuevo

	var deseada: String = accion if accion != "" else ANIMACIONES[estado]
	if not animador.has_animation(deseada):
		if deseada != _animacion_invalida:
			_animacion_invalida = deseada
			push_warning("Rogue no tiene la animación '%s'." % deseada)
		deseada = ANIMACIONES[estado]
	_reproducir(deseada)

	if _prueba_en_curso:
		_registrar_cuadro()


func _reproducir(nombre: String) -> void:
	if nombre == _animacion_actual:
		return
	_animacion_actual = nombre
	animador.play(nombre, 0.15)


# ============================================================================
#  CÓDIGO DE LA PRUEBA
# ============================================================================
func _nombre_de_la_prueba() -> String:
	var opciones: PackedStringArray = ["Ninguna", "Avanzar 60 cuadros", "Avanzar 60 y soltar",
		"Avanzar y la acción desde el cuadro 30", "Mantener la acción 2 s",
		"Avanzar con la acción 60 cuadros", "Diagonal W+D 60 cuadros"]
	return opciones[prueba]


func _teclas_de_la_prueba(c: int) -> Array[String]:
	var t: Array[String] = []
	match prueba:
		1, 2:
			if c <= 60: t.append("move_up")
		3:
			t.append("move_up")
			if c >= 30: t.append(accion_prueba)
		4:
			t.append(accion_prueba)
		5:
			t.append("move_up")
			t.append(accion_prueba)
		6:
			if c <= 60:
				t.append("move_up")
				t.append("move_right")
	return t


func _aplicar_teclas_de_la_prueba() -> void:
	if _cuadro > DURACION_PRUEBA[prueba]:
		_terminar_prueba()
		return
	var quiero := _teclas_de_la_prueba(_cuadro)
	for t in _teclas_pulsadas.duplicate():
		if not quiero.has(t):
			Input.action_release(t)
			_teclas_pulsadas.erase(t)
	for t in quiero:
		if t != "" and InputMap.has_action(t) and not _teclas_pulsadas.has(t):
			Input.action_press(t)
			_teclas_pulsadas.append(t)
		elif t == "" or not InputMap.has_action(t):
			push_warning("La prueba necesita una acción del Input Map en 'Accion Prueba' (ahora: '%s')." % t)


func _terminar_prueba() -> void:
	for t in _teclas_pulsadas:
		Input.action_release(t)
	_teclas_pulsadas.clear()
	_prueba_en_curso = false
	if _altura_maxima > 0.01:
		print("Altura máxima del salto: %.2f m" % _altura_maxima)
	print("=== FIN DE LA PRUEBA (dejen Prueba en Ninguna) ===")


func _nodos_hijos_con_datos() -> Array[Node]:
	var lista: Array[Node] = []
	for n in find_children("*", "", true, false):
		if "estado" in n or (n is AnimationPlayer and n != animador):
			lista.append(n)
	return lista


func _registrar_cuadro() -> void:
	if not _y_suelo_fijada and is_on_floor():
		_y_suelo = global_position.y
		_y_suelo_fijada = true
	var altura := global_position.y - _y_suelo
	_altura_maxima = maxf(_altura_maxima, altura)
	var p := global_position
	var linea := "cuadro %3d | pos (%.2f, %.2f, %.2f) | rapidez suelo %.2f m/s | altura %.2f m | anim %s | estado %s" % [
		_cuadro, p.x, p.y, p.z, Vector2(velocity.x, velocity.z).length(), altura,
		animador.current_animation, estado]
	for n in _nodos_hijos_con_datos():
		var ruta := str(get_path_to(n))
		if "estado" in n:
			linea += " | %s estado %s" % [ruta, str(n.estado)]
		if n is AnimationPlayer:
			linea += " | %s anim %s" % [ruta, n.current_animation]
	print(linea)

	# Cada vez que un estado o una animación cambia, una línea con el cuadro exacto.
	_avisar_cambio("Personaje", "estado", estado)
	_avisar_cambio("Personaje", "animación", _animacion_actual)
	for n in _nodos_hijos_con_datos():
		if "estado" in n:
			_avisar_cambio(str(get_path_to(n)), "estado", str(n.estado))


func _avisar_cambio(quien: String, que: String, valor: String) -> void:
	var clave := quien + "/" + que
	if _registro_estados.has(clave) and _registro_estados[clave] != valor:
		print(">>> cuadro %d: %s — %s: %s → %s" % [_cuadro, quien, que, _registro_estados[clave], valor])
	_registro_estados[clave] = valor
