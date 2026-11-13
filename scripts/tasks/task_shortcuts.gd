extends TaskBase
## "Quero aprender atalhos": responder qual atalho faz cada coisa (4 perguntas).

const COUNT := 4

var questions: Array = []
var options: Array[String] = []
var index := 0
var _q: Label
var _counter: Label
var _choices: GridContainer


func _init() -> void:
	task_title = "Atalhos de teclado"
	explain = "Ensine ao usuário o atalho certo para cada tarefa. Atalhos economizam muito tempo no dia a dia!"


func build() -> void:
	for i in Helpdesk.pick_fresh("shortcuts", Helpdesk.SHORTCUTS.size(), COUNT, rng):
		questions.append(Helpdesk.SHORTCUTS[i])
	_counter = make_label("", &"MutedLabel")
	add_child(_counter)
	_q = make_label("", &"HeadingLabel", 22, WARN)
	add_child(_q)
	_choices = GridContainer.new()
	_choices.columns = 2
	_choices.add_theme_constant_override("h_separation", 8)
	_choices.add_theme_constant_override("v_separation", 6)
	add_child(_choices)
	_show()


func _show() -> void:
	var q: Dictionary = questions[index]
	_counter.text = "Pergunta %d de %d" % [index + 1, COUNT]
	_q.text = "Como faço para: %s?" % q.q.to_lower()
	options = [q.a]
	var others := Helpdesk.SHORTCUTS.filter(func(s): return s.a != q.a)
	Helpdesk.shuffle(others, rng)
	for k in 3:
		options.append(others[k].a)
	Helpdesk.shuffle(options, rng)
	for c in _choices.get_children():
		c.queue_free()
	clear_hotkeys()
	for i in options.size():
		var b := make_button(options[i], _on_pick.bind(i), true, Vector2(380, 48))
		b.add_theme_font_size_override("font_size", 20)
		_choices.add_child(b)


func _on_pick(i: int) -> void:
	if is_solved:
		return
	var q: Dictionary = questions[index]
	if options[i] != q.a:
		var what: Array = Helpdesk.SHORTCUTS.filter(func(s): return s.a == options[i])
		wrong("%s serve para: %s." % [options[i], what[0].q.to_lower()] if not what.is_empty() else "Não é esse.")
		return
	index += 1
	if index >= COUNT:
		solve("O usuário aprendeu %d atalhos novos!" % COUNT)
	else:
		say("Isso! %s = %s." % [q.a, q.q.to_lower()])
		_show()
