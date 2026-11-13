extends TaskBase
## "Meu PC está lento": no Gerenciador de Tarefas, finalizar só o que está pesando.

var procs: Array = []                 # {name, desc, cpu, ram, kind: essential|normal|culprit}
var _checks: Array[CheckBox] = []


func _init() -> void:
	task_title = "Gerenciador de Tarefas"
	explain = "Marque os processos que estão deixando o PC lento e finalize. Cuidado: processos do Windows e o antivírus NÃO podem ser fechados."


func build() -> void:
	var ess := Helpdesk.PROCESSES_ESSENTIAL.duplicate()
	var nor := Helpdesk.PROCESSES_NORMAL.duplicate()
	var cul := Helpdesk.PROCESSES_CULPRIT.duplicate()
	Helpdesk.shuffle(ess, rng)
	Helpdesk.shuffle(nor, rng)
	Helpdesk.shuffle(cul, rng)
	var n_cul := rng.randi_range(1, 2)
	for p in ess.slice(0, 3):
		procs.append(_with_kind(p, "essential"))
	for p in nor.slice(0, 3):
		procs.append(_with_kind(p, "normal"))
	for p in cul.slice(0, n_cul):
		procs.append(_with_kind(p, "culprit"))
	Helpdesk.shuffle(procs, rng)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	for h in ["", "Processo", "Descrição", "CPU", "Memória"]:
		grid.add_child(make_label(h, &"MutedLabel"))
	for p in procs:
		var cb := CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		_hotkeys.append(cb)
		cb.text = "[%d]  " % _hotkeys.size()
		var n := _hotkeys.size()
		cb.toggled.connect(func(on: bool) -> void:
			cb.text = "[%d] %s" % [n, "X" if on else "  "]
			tint_button(cb, BAD if on else Color("181425")))
		_checks.append(cb)
		grid.add_child(cb)
		grid.add_child(make_label(p.name))
		grid.add_child(make_label(p.desc, &"MutedLabel"))
		var hot: bool = p.cpu >= 50
		grid.add_child(make_label("%d%%" % p.cpu, &"", 0, BAD if hot else Color.WHITE))
		grid.add_child(make_label(_mem(p.ram), &"", 0, BAD if p.ram >= 1500 else Color.WHITE))
	add_child(make_enter_button("Finalizar tarefas marcadas", _on_end))


func _with_kind(p: Dictionary, kind: String) -> Dictionary:
	var q := p.duplicate()
	q.kind = kind
	return q


func _mem(mb: int) -> String:
	return "%.1f GB" % (mb / 1000.0) if mb >= 1000 else "%d MB" % mb


func _on_end() -> void:
	if is_solved:
		return
	var killed: Array = []
	for i in procs.size():
		if _checks[i].button_pressed:
			killed.append(procs[i])
	for p in killed:
		if p.kind == "essential":
			wrong("NÃO! %s é essencial (%s). Fechar isso pode travar o Windows." % [p.name, p.desc])
			return
	for p in procs:
		if p.kind == "culprit" and not killed.has(p):
			wrong("O PC continua lento: %s ainda está usando %d%% da CPU." % [p.name, p.cpu])
			return
	var extra := killed.filter(func(p): return p.kind == "normal")
	if not extra.is_empty():
		wrong("Funcionou, mas você fechou %s, que o usuário estava usando! Feche só o que pesa." % extra[0].name)
		return
	solve("PC rápido de novo! Dica: reiniciar de vez em quando e não deixar 87 abas abertas.")
