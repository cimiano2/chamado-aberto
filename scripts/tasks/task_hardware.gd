extends TaskBase
## "O PC não liga direito": ler o sintoma e descobrir qual peça está com problema (2 casos).

const ROUNDS := 2

var round_i := 0
var scenario: Dictionary
var options: Array[String] = []
var _used: Array[int] = []
var _symptom: Label
var _choices: VBoxContainer
var _round_label: Label


func _init() -> void:
	task_title = "Defeito de hardware"
	explain = "Leia o que o usuário descreveu e descubra qual peça do computador está causando o problema."


func build() -> void:
	_round_label = make_label("", &"MutedLabel")
	add_child(_round_label)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fee761")
	style.border_color = Color("181425")
	style.set_border_width_all(3)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	_symptom = make_label("", &"", 19, Color("181425"))
	_symptom.custom_minimum_size = Vector2(760, 60)
	_symptom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(_symptom)
	add_child(make_label("Qual peça está com problema?", &"HeadingLabel"))
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	add_child(_choices)
	_new_round()


func _new_round() -> void:
	var idx: int = Helpdesk.pick_fresh("hardware", Helpdesk.HARDWARE.size(), 1, rng)[0]
	while _used.has(idx):
		idx = rng.randi() % Helpdesk.HARDWARE.size()
	_used.append(idx)
	scenario = Helpdesk.HARDWARE[idx]
	_symptom.text = "Sintoma: " + scenario.symptom
	_round_label.text = "Caso %d de %d" % [round_i + 1, ROUNDS]
	options = [scenario.part]
	var others := Helpdesk.HARDWARE.filter(func(s): return s.part != scenario.part)
	Helpdesk.shuffle(others, rng)
	for k in 3:
		options.append(others[k].part)
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
	if options[i] != scenario.part:
		var wrong_one: Dictionary = Helpdesk.HARDWARE.filter(func(s): return s.part == options[i])[0]
		wrong("Não é isso. \"%s\" daria outro sintoma: %s" % [options[i], wrong_one.symptom.to_lower()])
		return
	round_i += 1
	if round_i >= ROUNDS:
		solve("%s. %s" % [scenario.part, scenario.fix])
	else:
		say("Certo! %s" % scenario.fix)
		_new_round()
