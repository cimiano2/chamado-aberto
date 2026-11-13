extends TaskBase
## "Servidor de arquivos lento": o jogador atende as requisições de disco na ordem do algoritmo.

const MAX_CYL := 199

var algorithm := ""
var head := 0
var requests: Array = []
var expected: Array[int] = []
var served: Array[int] = []
var _buttons := {}
var _track: Control


func _init() -> void:
	task_title = "Escalonamento de disco"


func build() -> void:
	algorithm = pick(["SSTF", "LOOK", "C-LOOK"])
	while true:
		head = rng.randi_range(40, 160)
		requests.clear()
		while requests.size() < 6:
			var r := rng.randi_range(0, MAX_CYL)
			if r != head and not requests.has(r) and requests.all(func(x): return absi(x - r) > 8):
				requests.append(r)
		var below := requests.filter(func(r): return r < head).size()
		if below >= 2 and below <= 4 and (algorithm != "SSTF" or OSLogic.sstf_unambiguous(head, requests)):
			break
	expected = OSLogic.disk_order(head, requests, algorithm)
	match algorithm:
		"SSTF":
			explain = "SSTF (Shortest Seek Time First): atende sempre o pedido MAIS PRÓXIMO da posição atual da cabeça."
		"LOOK":
			explain = "LOOK: a cabeça SOBE atendendo em ordem crescente até o maior pedido, depois DESCE atendendo o resto."
		"C-LOOK":
			explain = "C-LOOK: SOBE atendendo em ordem crescente; depois SALTA para o menor pedido e volta a subir."

	add_child(make_label("Algoritmo: %s · cabeça no cilindro %d%s" % [algorithm, head, "" if algorithm == "SSTF" else " · sentido: subindo"], &"HeadingLabel"))
	_track = Control.new()
	_track.custom_minimum_size = Vector2(760, 120)
	_track.draw.connect(_draw_track)
	add_child(_track)

	add_child(make_label("Próximo cilindro a atender:", &"MutedLabel"))
	var r := row(8)
	add_child(r)
	var sorted := requests.duplicate()
	sorted.sort()
	for c in sorted:
		var b := make_button(str(c), _on_pick.bind(c), true, Vector2(90, 44))
		r.add_child(b)
		_buttons[c] = b


func _on_pick(c: int) -> void:
	if is_solved:
		return
	var want: int = expected[served.size()]
	var pos: int = head if served.is_empty() else served[-1]
	if c != want:
		match algorithm:
			"SSTF":
				wrong("Da posição %d, o pedido %d está a %d cilindros; o %d está mais perto (%d)." % [pos, c, absi(c - pos), want, absi(want - pos)])
			"LOOK":
				wrong("No LOOK a cabeça segue no mesmo sentido enquanto houver pedidos. O próximo é %d." % want)
			"C-LOOK":
				wrong("No C-LOOK só se atende subindo; ao chegar no topo, salta para o menor pedido. O próximo é %d." % want)
		return
	served.append(c)
	_buttons[c].disabled = true
	_track.queue_redraw()
	say("Cilindro %d atendido (%d de movimento até aqui)." % [c, OSLogic.seek_distance(head, served)])
	if served.size() == expected.size():
		solve("Todas as requisições atendidas! Movimento total: %d cilindros." % OSLogic.seek_distance(head, served))


func _draw_track() -> void:
	var w := _track.size.x - 40.0
	var x0 := 20.0
	var y := 26.0
	var to_x := func(c: int) -> float: return x0 + w * c / float(MAX_CYL)
	_track.draw_line(Vector2(x0, y), Vector2(x0 + w, y), MUTED, 2)
	var font := _track.get_theme_default_font()
	for c in [0, 50, 100, 150, 199]:
		_track.draw_line(Vector2(to_x.call(c), y - 5), Vector2(to_x.call(c), y + 5), MUTED, 1)
		_track.draw_string(font, Vector2(to_x.call(c) - 10, y - 10), str(c), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	for c in requests:
		var col := GOOD if served.has(c) else WARN
		_track.draw_circle(Vector2(to_x.call(c), y), 6, col)
	_track.draw_circle(Vector2(to_x.call(head), y), 8, ACCENT)
	# caminho percorrido
	var pts := [head] + served
	var yy := y + 18.0
	for i in range(1, pts.size()):
		var a := Vector2(to_x.call(pts[i - 1]), yy + (i - 1) * 12.0)
		var b := Vector2(to_x.call(pts[i]), yy + i * 12.0)
		_track.draw_line(a, b, ACCENT, 2)
		_track.draw_circle(b, 3, ACCENT)
