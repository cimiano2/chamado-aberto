extends TaskBase
## "Meu arquivo sumiu": escolher o jeito certo de recuperar (2 casos).

const ROUNDS := 2

var round_i := 0
var scenario: Dictionary
var options: Array[String] = []
var _case: Label
var _choices: VBoxContainer
var _round_label: Label


func _init() -> void:
	task_title = "Arquivo sumiu"
	explain = "Descubra o que aconteceu com o arquivo e escolha o jeito certo de recuperar."


func build() -> void:
	_round_label = make_label("", &"MutedLabel")
	add_child(_round_label)
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("c0cbdc")
	st.border_color = Color("181425")
	st.set_border_width_all(3)
	st.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", st)
	add_child(card)
	_case = make_label("", &"", 19, Color("181425"))
	_case.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_case.custom_minimum_size = Vector2(760, 50)
	card.add_child(_case)
	add_child(make_label("O que fazer?", &"HeadingLabel"))
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	add_child(_choices)
	_new_round()


func _new_round() -> void:
	scenario = Helpdesk.FILES[Helpdesk.pick_fresh("files", Helpdesk.FILES.size(), 1, rng)[0]]
	_round_label.text = "Caso %d de %d" % [round_i + 1, ROUNDS]
	_case.text = "\"%s\"" % scenario.case
	options = [scenario.answer]
	var others := Helpdesk.FILE_OPTIONS.filter(func(o): return o != scenario.answer)
	Helpdesk.shuffle(others, rng)
	for k in 3:
		options.append(others[k])
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
	if options[i] != scenario.answer:
		if options[i] == "Formatar o computador":
			wrong("Formatar apaga TUDO! Nunca é o primeiro passo para recuperar um arquivo.")
		else:
			wrong("Não é o melhor caminho para este caso. Releia o que o usuário contou.")
		return
	round_i += 1
	if round_i >= ROUNDS:
		solve("Arquivo recuperado! %s" % scenario.why)
	else:
		say("Certo! %s" % scenario.why)
		_new_round()
