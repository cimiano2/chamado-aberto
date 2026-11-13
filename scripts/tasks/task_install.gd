extends TaskBase
## "Preciso instalar um programa": escolher os passos na ordem certa, sem cair nas armadilhas.

var program: Dictionary
var buttons: Array = []      # [{text, step (índice ou -1 = armadilha), button}]
var done := 0
var _progress: Label


func _init() -> void:
	task_title = "Instalar programa"
	explain = "Clique nos passos na ordem certa. Cuidado: alguns botões são armadilhas que um técnico nunca deve fazer."


func build() -> void:
	program = Helpdesk.INSTALLS[Helpdesk.pick_fresh("install", Helpdesk.INSTALLS.size(), 1, rng)[0]]
	add_child(make_label("Instalar: %s" % program.program, &"HeadingLabel", 22, WARN))
	_progress = make_label("", &"MutedLabel")
	add_child(_progress)
	var items: Array = []
	for i in program.steps.size():
		items.append({"text": program.steps[i], "step": i})
	var traps := Helpdesk.INSTALL_TRAPS.duplicate()
	Helpdesk.shuffle(traps, rng)
	for t in traps.slice(0, 2):
		items.append({"text": t, "step": -1})
	Helpdesk.shuffle(items, rng)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	for i in items.size():
		var b := make_button(items[i].text, _on_pick.bind(i), true, Vector2(380, 46))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(b)
		items[i].button = b
	buttons = items
	_refresh()


func _refresh() -> void:
	_progress.text = "Passo %d de %d" % [mini(done + 1, program.steps.size()), program.steps.size()]


func _on_pick(i: int) -> void:
	if is_solved:
		return
	var it: Dictionary = buttons[i]
	if it.step == -1:
		wrong("NÃO! \"%s\" coloca a empresa em risco (vírus, pirataria ou programas indesejados)." % it.text)
		return
	if it.step != done:
		wrong("\"%s\" ainda não. Pense no que precisa acontecer antes." % it.text)
		return
	done += 1
	it.button.disabled = true
	it.button.text = "%d. %s" % [done, it.text]
	tint_button(it.button, GOOD)
	_refresh()
	if done >= program.steps.size():
		solve("%s instalado do jeito certo e seguro!" % program.program)
	else:
		say("Certo: %s." % it.text)
