extends TaskBase
## "Disco cheio": marcar só o que é seguro apagar até liberar o espaço necessário.

var items: Array = []        # {name, gb, safe, why}
var target := 0.0
var _checks: Array[CheckBox] = []
var _freed: Label


func _init() -> void:
	task_title = "Disco cheio"
	explain = "Marque o que pode ser apagado SEM perder nada importante até liberar o espaço pedido. Depois aperte Enter."


func build() -> void:
	var safe := Helpdesk.CLEANUP_SAFE.duplicate()
	var unsafe := Helpdesk.CLEANUP_UNSAFE.duplicate()
	Helpdesk.shuffle(safe, rng)
	var bad_idx := Helpdesk.pick_fresh("cleanup", unsafe.size(), 2, rng)
	for it in safe.slice(0, 4):
		items.append({"name": it.name, "gb": it.gb, "safe": true, "why": ""})
		target += it.gb
	for i in bad_idx:
		items.append({"name": unsafe[i].name, "gb": unsafe[i].gb, "safe": false, "why": unsafe[i].why})
	target = snappedf(target * 0.85, 0.5)     # precisa de quase todos os itens seguros
	Helpdesk.shuffle(items, rng)
	add_child(make_label("Disco C: 98%% cheio · é preciso liberar pelo menos %.1f GB" % target, &"HeadingLabel", 20, WARN))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 2)
	add_child(grid)
	for h in ["", "Item", "Tamanho"]:
		grid.add_child(make_label(h, &"MutedLabel"))
	for it in items:
		var cb := CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_constant_override("h_separation", 2)
		var compact := cb.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if compact:
			compact.content_margin_top = 4
			compact.content_margin_bottom = 4
			for st in ["normal", "hover", "pressed", "hover_pressed"]:
				cb.add_theme_stylebox_override(st, compact)
		_hotkeys.append(cb)
		var n := _hotkeys.size()
		cb.text = "[%d]  " % n
		cb.toggled.connect(func(on: bool) -> void:
			cb.text = "[%d] %s" % [n, "X" if on else "  "]
			tint_button(cb, WARN if on else Color("181425"))
			_refresh())
		_checks.append(cb)
		grid.add_child(cb)
		grid.add_child(make_label(it.name))
		grid.add_child(make_label("%.1f GB" % it.gb))
	_freed = make_label("", &"HeadingLabel")
	add_child(_freed)
	add_child(make_enter_button("Excluir os itens marcados", _on_clean))
	_refresh()


func _selected_gb() -> float:
	var total := 0.0
	for i in items.size():
		if _checks[i].button_pressed:
			total += items[i].gb
	return total


func _refresh() -> void:
	_freed.text = "Marcado para liberar: %.1f GB de %.1f GB" % [_selected_gb(), target]


func _on_clean() -> void:
	if is_solved:
		return
	for i in items.size():
		if _checks[i].button_pressed and not items[i].safe:
			wrong("NÃO apague \"%s\": %s" % [items[i].name, items[i].why])
			return
	if _selected_gb() + 0.01 < target:
		wrong("Ainda falta espaço: %.1f GB marcados, precisa de %.1f GB. Procure mais itens seguros." % [_selected_gb(), target])
		return
	solve("%.1f GB liberados sem perder nada importante!" % _selected_gb())
