extends TaskBase
## "Sistema travado": o jogador encontra uma sequência segura (algoritmo do banqueiro).

const RES := ["A", "B", "C"]
const PROGS := ["ERP", "Banco", "Relatório", "Backup"]

var alloc: Array = []
var need: Array = []
var work: Array = []
var finished: Array = []
var sequence: Array[String] = []
var _buttons: Array[Button] = []
var _work_label: Label
var _seq_label: Label
var _grid: GridContainer


func _init() -> void:
	task_title = "Deadlock: algoritmo do banqueiro"
	explain = "Execute um processo só se a NECESSIDADE dele couber no DISPONÍVEL. Ao terminar, ele devolve tudo o que tinha ALOCADO."


func build() -> void:
	var st := OSLogic.generate_bank_state(rng, 4, 3)
	alloc = st.alloc
	need = st.need
	work = st.available.duplicate()
	finished.resize(4)
	finished.fill(false)

	add_child(make_label("Recursos A, B e C (impressora, conexões de banco, licenças).", &"HeadingLabel"))
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 28)
	_grid.add_theme_constant_override("v_separation", 6)
	add_child(_grid)
	for h in ["Processo", "Alocado (A B C)", "Necessidade (A B C)", ""]:
		_grid.add_child(make_label(h, &"MutedLabel"))
	for i in 4:
		_grid.add_child(make_label("P%d %s" % [i, PROGS[i]]))
		_grid.add_child(make_label(_vec(alloc[i])))
		_grid.add_child(make_label(_vec(need[i]), &"", 0, WARN))
		var b := make_button("Executar P%d" % i, _on_run.bind(i), true)
		_grid.add_child(b)
		_buttons.append(b)

	_work_label = make_label("", &"HeadingLabel")
	add_child(_work_label)
	_seq_label = make_label("Sequência: —", &"MutedLabel")
	add_child(_seq_label)
	_refresh()


func _on_run(i: int) -> void:
	if is_solved or finished[i]:
		return
	if not OSLogic.fits(need[i], work):
		wrong("P%d precisa de %s, mas só há %s disponível. Ele ficaria esperando: risco de deadlock!" % [i, _vec(need[i]), _vec(work)])
		return
	work = OSLogic.add_vec(work, alloc[i])
	finished[i] = true
	sequence.append("P%d" % i)
	_buttons[i].disabled = true
	_buttons[i].text = "✓ concluído"
	say("P%d terminou e devolveu %s." % [i, _vec(alloc[i])])
	_refresh()
	if not finished.has(false):
		solve("Sequência segura encontrada: %s. Sistema destravado!" % " → ".join(sequence))


func _refresh() -> void:
	_work_label.text = "Disponível agora: %s" % _vec(work)
	_seq_label.text = "Sequência: %s" % (" → ".join(sequence) if not sequence.is_empty() else "—")


func _vec(v: Array) -> String:
	return "(%s)" % " ".join(v.map(func(x): return str(x)))
