extends TaskBase
## "Estou sem internet": ler a saída do diagnóstico e apontar a causa (2 casos).

const ROUNDS := 2

var round_i := 0
var scenario: Dictionary
var options: Array[String] = []
var _used: Array[int] = []
var _output: Label
var _choices: VBoxContainer
var _round_label: Label


func _init() -> void:
	task_title = "Diagnóstico de rede"
	explain = "Leia o resultado dos comandos no PC do usuário e escolha a causa do problema."


func build() -> void:
	_round_label = make_label("", &"MutedLabel")
	add_child(_round_label)
	var term := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b0b12")
	style.border_color = Color("3a4466")
	style.set_border_width_all(3)
	style.set_content_margin_all(12)
	term.add_theme_stylebox_override("panel", style)
	add_child(term)
	_output = make_label("", &"", 17, Color("63c74d"))
	_output.custom_minimum_size = Vector2(760, 120)
	term.add_child(_output)
	add_child(make_label("Qual é a causa?", &"HeadingLabel"))
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	add_child(_choices)
	_new_round()


func _new_round() -> void:
	var idx := rng.randi() % Helpdesk.NETWORK.size()
	while _used.has(idx):
		idx = rng.randi() % Helpdesk.NETWORK.size()
	_used.append(idx)
	scenario = Helpdesk.NETWORK[idx]
	_output.text = scenario.out
	_round_label.text = "Caso %d de %d" % [round_i + 1, ROUNDS]
	options = [scenario.cause]
	var others := Helpdesk.NETWORK.filter(func(s): return s.cause != scenario.cause)
	Helpdesk.shuffle(others, rng)
	for k in 3:
		options.append(others[k].cause)
	Helpdesk.shuffle(options, rng)
	for c in _choices.get_children():
		c.queue_free()
	clear_hotkeys()
	for i in options.size():
		var b := make_button(options[i], _on_pick.bind(i), true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_choices.add_child(b)


func _on_pick(i: int) -> void:
	if is_solved:
		return
	if options[i] != scenario.cause:
		wrong("Não é isso. Olhe de novo a saída: o que ela mostra de diferente?")
		return
	round_i += 1
	if round_i >= ROUNDS:
		solve("%s. %s" % [scenario.cause, scenario.fix])
	else:
		say("Certo! %s" % scenario.fix)
		_new_round()
