extends TaskBase
## "Sem acesso à pasta": o jogador ajusta as permissões rwx (dono, grupo, outros).

const TARGETS := ["755", "750", "644", "640", "700", "600", "775", "664", "711", "754"]
const FILES := ["/srv/financeiro/balanco.xlsx", "/srv/rh/folha.csv", "/srv/marketing/campanha/",
	"/opt/erp/iniciar.sh", "/srv/diretoria/ata.pdf", "/home/compartilhado/manual.pdf"]
const WHO := ["Dono", "Grupo", "Outros"]
const PERM := ["ler", "escrever", "executar"]

var rounds := 2
var round_i := 0
var target := ""
var mode := ""
var _bits: Array[CheckBox] = []
var _prompt: Label
var _current: Label
var _round_label: Label


func _init() -> void:
	task_title = "Permissões de arquivo (chmod)"
	explain = "Cada grupo (dono, grupo, outros) soma: ler (r) = 4, escrever (w) = 2, executar (x) = 1. Ex.: rwx = 7, r-x = 5, r-- = 4."


func build() -> void:
	_round_label = make_label("", &"MutedLabel")
	add_child(_round_label)
	_prompt = make_label("", &"HeadingLabel")
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.custom_minimum_size = Vector2(760, 0)
	add_child(_prompt)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	add_child(grid)
	grid.add_child(make_label(""))
	for p in ["r (4)", "w (2)", "x (1)"]:
		grid.add_child(make_label(p, &"MutedLabel"))
	for g in 3:
		grid.add_child(make_label(WHO[g]))
		for k in 3:
			var cb := CheckBox.new()
			cb.focus_mode = Control.FOCUS_NONE
			_bits.append(cb)
			cb.text = "[%d]" % (g * 3 + k + 1)
			cb.toggled.connect(func(_on: bool) -> void: _refresh())
			grid.add_child(cb)
	# registra as 9 caixas como teclas 1–9
	for cb in _bits:
		_hotkeys_append(cb)

	_current = make_label("", &"HeadingLabel")
	add_child(_current)
	add_child(make_enter_button("Aplicar chmod", _on_apply))
	_new_round()


func _hotkeys_append(b: Button) -> void:
	# reaproveita o mecanismo de teclas da TaskBase sem mudar o texto
	if _hotkeys.size() < 9:
		_hotkeys.append(b)


func _new_round() -> void:
	target = pick(TARGETS)
	mode = "octal" if round_i == 0 else "texto"
	var file: String = pick(FILES)
	for cb in _bits:
		cb.set_pressed_no_signal(false)
	if mode == "octal":
		_prompt.text = "Execute: chmod %s %s" % [target, file]
	else:
		var bits := OSLogic.octal_to_bits(target)
		var parts: Array[String] = []
		for g in 3:
			var can: Array[String] = []
			for k in 3:
				if bits[g * 3 + k]:
					can.append(PERM[k])
			parts.append("%s: %s" % [WHO[g], ", ".join(can) if not can.is_empty() else "nada"])
		_prompt.text = "Pedido do chamado para %s:  %s" % [file, " · ".join(parts)]
	_round_label.text = "Etapa %d de %d" % [round_i + 1, rounds]
	_refresh()


func _state() -> Array[bool]:
	var out: Array[bool] = []
	for cb in _bits:
		out.append(cb.button_pressed)
	return out


func _refresh() -> void:
	var s := _state()
	for i in _bits.size():
		_bits[i].text = "[%d] %s" % [i + 1, "X" if s[i] else "  "]
		tint_button(_bits[i], GOOD if s[i] else Color("2a3566"))
	_current.text = "Atual: %s  =  %s" % [OSLogic.bits_to_symbolic(s), OSLogic.bits_to_octal(s)]


func _on_apply() -> void:
	if is_solved:
		return
	var cur := OSLogic.bits_to_octal(_state())
	if cur != target:
		var tsym := OSLogic.bits_to_symbolic(OSLogic.octal_to_bits(target))
		if mode == "octal":
			wrong("Ainda não: você montou %s, mas %s = %s." % [cur, target, tsym])
		else:
			wrong("Ainda não: atual %s (%s). Releia o pedido grupo por grupo." % [cur, OSLogic.bits_to_symbolic(_state())])
		return
	round_i += 1
	if round_i >= rounds:
		solve("Permissões corretas! O usuário já consegue acessar.")
	else:
		say("chmod %s aplicado! Próximo pedido..." % cur)
		_new_round()
