extends TaskBase
## "PC lento": o jogador escolhe a ordem de execução dos processos segundo a política.

const NAMES := ["chrome", "excel", "teams", "antivírus", "backup", "outlook", "erp", "zoom"]

var policy := ""
var procs: Array = []
var expected: Array[String] = []
var done: Array[String] = []
var _buttons := {}
var _gantt: HBoxContainer
var _total_burst := 0


func _init() -> void:
	task_title = "Escalonamento de CPU"


func build() -> void:
	policy = pick(["FCFS", "SJF", "PRIORIDADE"])
	var names := NAMES.duplicate()
	OSLogic._shuffle(names, rng)
	var bursts := [1, 2, 3, 4, 5, 6, 7, 8]
	var prios := [1, 2, 3, 4, 5]
	var arrivals := [0, 1, 2, 3, 4, 5]
	OSLogic._shuffle(bursts, rng)
	OSLogic._shuffle(prios, rng)
	OSLogic._shuffle(arrivals, rng)
	var n := 4 if policy != "FCFS" else 5
	for i in n:
		procs.append({"name": names[i], "burst": bursts[i], "prio": prios[i],
			"arrival": arrivals[i] if policy == "FCFS" else 0, "color": CHIP_COLORS[i]})
		_total_burst += bursts[i]
	expected = OSLogic.schedule_order(procs, policy)

	match policy:
		"FCFS":
			explain = "FCFS (First Come, First Served): executa na ordem de CHEGADA."
		"SJF":
			explain = "SJF (Shortest Job First): executa primeiro o processo com MENOR burst (tempo de CPU)."
		"PRIORIDADE":
			explain = "Prioridade: executa primeiro o MENOR número de prioridade (1 = mais urgente)."
	add_child(make_label("Política do sistema: %s (não preemptivo)" % policy, &"HeadingLabel"))
	add_child(make_label("Escolha o próximo processo a receber a CPU:", &"MutedLabel"))

	var r := row(10)
	add_child(r)
	for p in procs:
		var info := "burst %ds" % p.burst
		if policy == "PRIORIDADE":
			info += " · prio %d" % p.prio
		if policy == "FCFS":
			info += " · chega t=%d" % p.arrival
		var b := make_button("%s\n%s" % [p.name, info], _on_pick.bind(p.name), true, Vector2(150, 64))
		tint_button(b, p.color)
		r.add_child(b)
		_buttons[p.name] = b

	add_child(make_label("Linha do tempo (Gantt):", &"MutedLabel"))
	_gantt = row(2)
	_gantt.custom_minimum_size = Vector2(0, 40)
	add_child(_gantt)


func _on_pick(pname: String) -> void:
	if is_solved:
		return
	var want: String = expected[done.size()]
	if pname != want:
		var a := _proc(pname)
		var w := _proc(want)
		match policy:
			"FCFS":
				wrong("%s chegou em t=%d, mas %s chegou antes (t=%d)." % [pname, a.arrival, want, w.arrival])
			"SJF":
				wrong("%s tem burst %ds, mas %s é mais curto (%ds)." % [pname, a.burst, want, w.burst])
			"PRIORIDADE":
				wrong("%s tem prioridade %d, mas %s é mais urgente (%d)." % [pname, a.prio, want, w.prio])
		return
	done.append(pname)
	var p := _proc(pname)
	_buttons[pname].disabled = true
	var block := ColorRect.new()
	block.color = p.color.darkened(0.25)
	block.custom_minimum_size = Vector2(560.0 * p.burst / _total_burst, 36)
	var lbl := make_label(pname, &"", 12, Color("06141a"))
	lbl.position = Vector2(4, 8)
	block.add_child(lbl)
	_gantt.add_child(block)
	say("%s executando..." % pname)
	if done.size() == expected.size():
		var avg := OSLogic.average_wait(procs, done)
		solve("Ordem correta! Tempo médio de espera: %.2fs." % avg)


func _proc(pname: String) -> Dictionary:
	for p in procs:
		if p.name == pname:
			return p
	return {}
