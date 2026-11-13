extends TaskBase
## "Programa não abre por falta de memória": o jogador escolhe a lacuna segundo a política.

const TOTAL := 1000
const PROGRAMS := ["AutoCAD", "Power BI", "Photoshop", "SAP", "VS Code", "Teams", "Excel"]

var algorithm := ""
var holes: Array = []        # {start, size}
var used: Array = []         # {start, size, name}
var queue: Array = []        # {name, size}
var _bar: Control
var _req_label: Label
var _choices: HBoxContainer


func _init() -> void:
	task_title = "Alocação de memória contígua"


func build() -> void:
	algorithm = pick(["FIRST FIT", "BEST FIT", "WORST FIT"])
	match algorithm:
		"FIRST FIT":
			explain = "First fit: usa a PRIMEIRA lacuna (menor endereço) onde o programa cabe."
		"BEST FIT":
			explain = "Best fit: usa a MENOR lacuna onde o programa cabe (sobra o mínimo)."
		"WORST FIT":
			explain = "Worst fit: usa a MAIOR lacuna disponível (sobra o máximo)."
	_generate()
	add_child(make_label("Política: %s · memória de %d KB" % [algorithm, TOTAL], &"HeadingLabel"))
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(760, 74)
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_req_label = make_label("", &"HeadingLabel")
	_req_label.add_theme_color_override("font_color", WARN)
	add_child(_req_label)
	add_child(make_label("Escolha a lacuna (endereço · tamanho livre):", &"MutedLabel"))
	_choices = row(8)
	add_child(_choices)
	_refresh()


## Gera 5 lacunas e 3 programas em que a política faz diferença.
func _generate() -> void:
	while true:
		holes.clear()
		used.clear()
		queue.clear()
		var sizes := []
		for i in 5:
			sizes.append(rng.randi_range(6, 26) * 10)
		var free_total: int = sizes.reduce(func(a, b): return a + b)
		if free_total > TOTAL - 150:
			continue
		var used_total := TOTAL - free_total
		# intercala blocos usados e lacunas
		var gaps := []
		var remaining := used_total
		for i in 5:
			var g := 0 if i == 5 else rng.randi_range(2, 9) * 10
			gaps.append(g)
		var gsum: int = gaps.reduce(func(a, b): return a + b)
		if gsum > remaining:
			continue
		gaps[0] += remaining - gsum   # sobra vai para o primeiro bloco usado
		var pos := 0
		for i in 5:
			if gaps[i] > 0:
				used.append({"start": pos, "size": gaps[i], "name": "SO" if i == 0 else "app"})
				pos += gaps[i]
			holes.append({"start": pos, "size": sizes[i]})
			pos += sizes[i]
		if pos != TOTAL:
			continue
		# 3 pedidos que cabem em sequência, com resposta única e diferente do first fit em ao menos um
		var sim := holes.duplicate(true)
		var ok := true
		var differs := algorithm == "FIRST FIT"
		for k in 3:
			var s := rng.randi_range(4, 16) * 10
			var ch := OSLogic.fit_choices(sim, s, algorithm)
			if ch.size() != 1:
				ok = false
				break
			if ch != OSLogic.fit_choices(sim, s, "FIRST FIT"):
				differs = true
			queue.append({"name": PROGRAMS[(k + rng.randi()) % PROGRAMS.size()], "size": s})
			OSLogic.allocate(sim, ch[0], s)
		if ok and differs:
			return


func _refresh() -> void:
	for c in _choices.get_children():
		c.queue_free()
	clear_hotkeys()
	if queue.is_empty():
		return
	var req: Dictionary = queue[0]
	_req_label.text = "Carregar: %s (%d KB)   ·   restam %d" % [req.name, req.size, queue.size()]
	for i in holes.size():
		var h: Dictionary = holes[i]
		var b := make_button("@%d · %d KB" % [h.start, h.size], _on_pick.bind(i), true, Vector2(140, 44))
		_choices.add_child(b)
	_bar.queue_redraw()


func _on_pick(i: int) -> void:
	if is_solved or queue.is_empty():
		return
	var req: Dictionary = queue[0]
	var ok := OSLogic.fit_choices(holes, req.size, algorithm)
	if not ok.has(i):
		if holes[i].size < req.size:
			wrong("A lacuna @%d tem só %d KB; %s precisa de %d KB." % [holes[i].start, holes[i].size, req.name, req.size])
		else:
			var h: Dictionary = holes[ok[0]]
			match algorithm:
				"FIRST FIT": wrong("Cabe, mas a PRIMEIRA lacuna que cabe é @%d." % h.start)
				"BEST FIT": wrong("Cabe, mas a MENOR lacuna que cabe é @%d (%d KB)." % [h.start, h.size])
				"WORST FIT": wrong("Cabe, mas a MAIOR lacuna é @%d (%d KB)." % [h.start, h.size])
		return
	used.append({"start": holes[i].start, "size": req.size, "name": req.name})
	OSLogic.allocate(holes, i, req.size)
	queue.pop_front()
	say("%s carregado em @%d." % [req.name, used[-1].start])
	_refresh()
	if queue.is_empty():
		_req_label.text = ""
		solve("Todos os programas carregados! Memória livre restante: %d KB." % holes.reduce(func(a, h): return a + h.size, 0))


func _draw_bar() -> void:
	var w := _bar.size.x
	var h := 44.0
	var font := _bar.get_theme_default_font()
	_bar.draw_rect(Rect2(0, 0, w, h), Color("0a0d1c"))
	for u in used:
		var r := Rect2(w * u.start / TOTAL, 0, w * u.size / TOTAL, h)
		_bar.draw_rect(r, Color("3a4270"))
		_bar.draw_rect(r, Color("0a0d1c"), false, 1)
		if r.size.x > 40:
			_bar.draw_string(font, r.position + Vector2(4, 27), u.name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, 11, Color("d8e1ff"))
	for i in holes.size():
		var hh: Dictionary = holes[i]
		var r := Rect2(w * hh.start / TOTAL, 0, w * hh.size / TOTAL, h)
		_bar.draw_rect(r.grow(-1), GOOD, false, 2)
		_bar.draw_string(font, r.position + Vector2(4, 18), "[%d]" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 11, GOOD)
		_bar.draw_string(font, r.position + Vector2(4, 36), "%d" % hh.size, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 11, GOOD)
	for c in [0, 250, 500, 750, 1000]:
		_bar.draw_string(font, Vector2(w * c / TOTAL - (24 if c == 1000 else 0), h + 18), str(c), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
