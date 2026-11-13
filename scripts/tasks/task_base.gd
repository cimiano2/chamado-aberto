class_name TaskBase
extends VBoxContainer
## Base de todos os minijogos de atendimento. Cada tarefa:
##  - define task_title / explain em _init
##  - monta a interface em build() (valores sorteados a cada abertura)
##  - registra botões com teclas 1–9 via make_button(..., true)
##  - chama say() para retorno, wrong() quando o jogador erra e solve() ao terminar.
## Tudo é jogável pelo teclado: 1–9 acionam os botões numerados, Enter o botão principal.

signal feedback(text: String, kind: String)   # kind: good | bad | ask
signal mistake
signal solved(summary: String)

const GOOD := Color("5cff8a")
const BAD := Color("ff5a5a")
const ACCENT := Color("34e7e4")
const WARN := Color("ffd23f")
const MUTED := Color("8592c4")
const CHIP_COLORS: Array[Color] = [Color("34e7e4"), Color("ff9f43"), Color("a17bff"), Color("5cff8a"),
	Color("ff6bd5"), Color("4fa3ff"), Color("ffd23f")]

var task_title := "Tarefa"
var explain := ""
var rng := RandomNumberGenerator.new()
var is_solved := false

var _hotkeys: Array[Button] = []
var _enter_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	if not has_meta("seed"):
		rng.randomize()
	else:
		rng.seed = get_meta("seed")
	build()


## Sobrescrever: monta a interface.
func build() -> void:
	pass


## Chamado pelo painel quando uma tecla é pressionada. Devolve true se tratou.
func handle_key(keycode: Key) -> bool:
	if is_solved:
		return false
	var n := -1
	if keycode >= KEY_1 and keycode <= KEY_9:
		n = keycode - KEY_1
	elif keycode >= KEY_KP_1 and keycode <= KEY_KP_9:
		n = keycode - KEY_KP_1
	if n >= 0 and n < _hotkeys.size():
		var b := _hotkeys[n]
		if is_instance_valid(b) and not b.disabled and b.is_visible_in_tree():
			if b.toggle_mode:
				b.button_pressed = not b.button_pressed
			else:
				b.pressed.emit()
			return true
	if (keycode == KEY_ENTER or keycode == KEY_KP_ENTER) and is_instance_valid(_enter_button) \
			and not _enter_button.disabled:
		_enter_button.pressed.emit()
		return true
	return false


func say(text: String, good: bool = true) -> void:
	feedback.emit(text, "good" if good else "bad")


## Pergunta/instrução ao jogador (amarelo).
func ask(text: String) -> void:
	feedback.emit(text, "ask")


func wrong(text: String) -> void:
	mistake.emit()
	feedback.emit(text, "bad")


func solve(summary: String) -> void:
	if is_solved:
		return
	is_solved = true
	solved.emit(summary)


# ------------------------------------------------------------------ helpers de UI

func make_label(text: String, variation: StringName = &"", size: int = 0, color := Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l


## hotkey=true numera o botão ([1], [2], ...) na ordem de criação.
func make_button(text: String, callback: Callable, hotkey := false, min_size := Vector2(0, 0)) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	if hotkey and _hotkeys.size() < 9:
		_hotkeys.append(b)
		b.text = "[%d] %s" % [_hotkeys.size(), text]
	else:
		b.text = text
	if callback.is_valid():
		b.pressed.connect(callback)
	return b


## Botão acionado por Enter.
func make_enter_button(text: String, callback: Callable) -> Button:
	var b := make_button("[Enter] " + text, callback)
	b.theme_type_variation = &"PrimaryButton"
	_enter_button = b
	return b


func clear_hotkeys() -> void:
	_hotkeys.clear()


func row(separation: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


func tint_button(b: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var base := b.get_theme_stylebox(state) as StyleBoxFlat
		if base == null:
			continue
		var s := base.duplicate() as StyleBoxFlat
		s.border_color = color if state != "disabled" else color.darkened(0.5)
		b.add_theme_stylebox_override(state, s)


func pick(arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]
