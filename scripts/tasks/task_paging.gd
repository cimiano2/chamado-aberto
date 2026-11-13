extends TaskBase
## "Memória cheia": a cada falta de página com quadros cheios, o jogador escolhe a vítima.

const N_FRAMES := 3

var algorithm := ""
var refs: Array = []
var t := 0
var frames: Array = []
var loaded_at: Array = []
var last_used: Array = []
var faults := 0
var hits := 0
var waiting_choice := false

var _ref_labels: Array[Label] = []
var _frame_buttons: Array[Button] = []
var _stats: Label
var _timer: Timer


func _init() -> void:
	task_title = "Substituição de páginas"


func build() -> void:
	algorithm = pick(["FIFO", "LRU", "ÓTIMO"])
	# sorteia uma sequência que exija pelo menos 3 decisões de substituição
	while true:
		refs.clear()
		for i in 12:
			refs.append(rng.randi_range(0, 5))
		if OSLogic.simulate_paging(algorithm, refs, N_FRAMES).evictions >= 3:
			break
	match algorithm:
		"FIFO":
			explain = "FIFO: substitui a página que está há MAIS TEMPO na memória (a primeira que entrou)."
		"LRU":
			explain = "LRU (Least Recently Used): substitui a página usada há MAIS TEMPO."
		"ÓTIMO":
			explain = "Ótimo: substitui a página que vai demorar MAIS para ser usada de novo (ou nunca mais)."
	add_child(make_label("Algoritmo: %s · %d quadros de memória" % [algorithm, N_FRAMES], &"HeadingLabel"))

	add_child(make_label("Sequência de referências:", &"MutedLabel"))
	var r := row(6)
	add_child(r)
	for i in refs.size():
		var l := make_label(str(refs[i]), &"", 20)
		l.custom_minimum_size = Vector2(34, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(l)
		_ref_labels.append(l)

	add_child(make_label("Quadros (escolha a vítima quando houver falta):", &"MutedLabel"))
	var fr := row(12)
	add_child(fr)
	for i in N_FRAMES:
		var b := make_button("—", _on_frame.bind(i), true, Vector2(170, 70))
		b.add_theme_font_size_override("font_size", 20)
		fr.add_child(b)
		_frame_buttons.append(b)

	_stats = make_label("", &"MutedLabel")
	add_child(_stats)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_step)
	add_child(_timer)
	_refresh()
	_timer.start(0.5)


func _step() -> void:
	if t >= refs.size():
		solve("Sequência concluída: %d faltas de página e %d acertos." % [faults, hits])
		return
	var page: int = refs[t]
	var idx := frames.find(page)
	if idx >= 0:
		hits += 1
		last_used[idx] = t
		say("Página %d já está na memória: acerto!" % page)
		_advance()
	elif frames.size() < N_FRAMES:
		faults += 1
		frames.append(page)
		loaded_at.append(t)
		last_used.append(t)
		say("Falta de página: %d carregada num quadro livre." % page)
		_advance()
	else:
		waiting_choice = true
		ask("Falta de página %d! Memória cheia: qual página sai? (%s)" % [page, algorithm])
		_refresh()


func _advance() -> void:
	t += 1
	_refresh()
	_timer.start(0.55)


func _on_frame(i: int) -> void:
	if not waiting_choice or is_solved or i >= frames.size():
		return
	var ok := OSLogic.page_victims(algorithm, frames, loaded_at, last_used, refs, t)
	if not ok.has(i):
		var v: int = ok[0]
		match algorithm:
			"FIFO":
				wrong("A página %d entrou em t=%d, mas a %d entrou antes (t=%d)." % [frames[i], loaded_at[i], frames[v], loaded_at[v]])
			"LRU":
				wrong("A página %d foi usada em t=%d, mas a %d está sem uso há mais tempo (t=%d)." % [frames[i], last_used[i], frames[v], last_used[v]])
			"ÓTIMO":
				var nu := OSLogic.next_use_of(frames[i], refs, t)
				var nv := OSLogic.next_use_of(frames[v], refs, t)
				wrong("A página %d volta a ser usada em t=%d; a %d só %s." % [frames[i], nu, frames[v],
					"em t=%d" % nv if nv >= 0 else "nunca mais"])
		return
	waiting_choice = false
	var page: int = refs[t]
	say("Página %d saiu, página %d entrou." % [frames[i], page])
	faults += 1
	frames[i] = page
	loaded_at[i] = t
	last_used[i] = t
	_advance()


func _refresh() -> void:
	for i in _ref_labels.size():
		var c := MUTED
		if i < t:
			c = Color("4a5585")
		elif i == t:
			c = WARN
		else:
			c = Color("d8e1ff")
		_ref_labels[i].add_theme_color_override("font_color", c)
	for i in N_FRAMES:
		var b := _frame_buttons[i]
		var label := "—"
		if i < frames.size():
			label = "pág. %d" % frames[i]
			match algorithm:
				"FIFO": label += "\nentrou t=%d" % loaded_at[i]
				"LRU": label += "\nusada t=%d" % last_used[i]
				"ÓTIMO":
					var nu := OSLogic.next_use_of(frames[i], refs, t)
					label += "\npróx. uso: %s" % ("t=%d" % nu if nu >= 0 else "nunca")
		b.text = "[%d] %s" % [i + 1, label]
		tint_button(b, WARN if waiting_choice else Color("2a3566"))
	_stats.text = "t = %d   ·   faltas: %d   ·   acertos: %d" % [mini(t, refs.size() - 1), faults, hits]
