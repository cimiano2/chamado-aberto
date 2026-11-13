extends TaskBase
## "A impressora não imprime": ler o painel e aplicar só as ações necessárias.

var issues: Array[String] = []        # chaves de Helpdesk.PRINTER_ISSUES ainda pendentes
var actions: Array = []               # [{label, issue (ou "" se for piada)}]
var _panel_label: Label


func _init() -> void:
	task_title = "Impressora"
	explain = "Veja as mensagens da impressora e do Windows e faça só o que resolve cada problema."


func build() -> void:
	var keys := Helpdesk.PRINTER_ISSUES.keys()
	Helpdesk.shuffle(keys, rng)
	issues.assign(keys.slice(0, 2))
	add_child(make_label("Painel da impressora / Windows:", &"MutedLabel"))
	var lcd := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d3b2a")
	style.border_color = Color("181425")
	style.set_border_width_all(3)
	style.set_content_margin_all(12)
	lcd.add_theme_stylebox_override("panel", style)
	add_child(lcd)
	_panel_label = make_label("", &"", 18, Color("c4f5a8"))
	_panel_label.custom_minimum_size = Vector2(760, 60)
	lcd.add_child(_panel_label)
	add_child(make_label("O que você faz?", &"HeadingLabel"))
	for k in Helpdesk.PRINTER_ISSUES:
		actions.append({"label": Helpdesk.PRINTER_ISSUES[k].fix, "issue": k})
	for j in Helpdesk.PRINTER_JOKES:
		actions.append({"label": j, "issue": ""})
	Helpdesk.shuffle(actions, rng)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	for i in actions.size():
		var b := make_button(actions[i].label, _on_action.bind(i), true, Vector2(375, 0))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(b)
	_refresh()


func _refresh() -> void:
	if issues.is_empty():
		_panel_label.text = "PRONTA  -  imprimindo página de teste..."
		return
	var lines: Array[String] = []
	for k in issues:
		lines.append("! " + Helpdesk.PRINTER_ISSUES[k].msg)
	_panel_label.text = "\n".join(lines)


func _on_action(i: int) -> void:
	if is_solved:
		return
	var a: Dictionary = actions[i]
	if a.issue == "":
		wrong("Calma! \"%s\" não resolve nada. Leia o painel." % a.label)
		return
	if not issues.has(a.issue):
		wrong("\"%s\" não era necessário: o painel não mostra esse problema." % a.label)
		return
	issues.erase(a.issue)
	_refresh()
	if issues.is_empty():
		solve("Impressora funcionando! Página de teste impressa.")
	else:
		say("Feito: %s. Ainda falta um problema." % a.label)
