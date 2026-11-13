extends TaskBase
## "Não consigo abrir o arquivo": escolher o programa certo pela extensão (4 arquivos).

const COUNT := 4

var files: Array = []
var index := 0
var _file_label: Label
var _counter: Label


func _init() -> void:
	task_title = "Que programa abre este arquivo?"
	explain = "A extensão (as letras depois do ponto) diz o tipo do arquivo: .docx é texto, .xlsx planilha, .pdf documento PDF, .zip arquivo compactado..."


func build() -> void:
	for i in Helpdesk.pick_fresh("ext", Helpdesk.EXTENSIONS.size(), COUNT, rng):
		files.append(Helpdesk.EXTENSIONS[i])
	_counter = make_label("", &"MutedLabel")
	add_child(_counter)
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("f4f4f4")
	st.border_color = Color("181425")
	st.set_border_width_all(3)
	st.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", st)
	add_child(card)
	_file_label = make_label("", &"", 24, Color("124e89"))
	card.add_child(_file_label)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	for p in Helpdesk.EXT_PROGRAMS:
		var b := make_button(p, _on_pick.bind(p), true, Vector2(380, 44))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(b)
	_show()


func _show() -> void:
	_counter.text = "Arquivo %d de %d" % [index + 1, COUNT]
	_file_label.text = "Arquivo: " + files[index].file


func _on_pick(program: String) -> void:
	if is_solved:
		return
	var f: Dictionary = files[index]
	if program != f.program:
		var ext: String = f.file.get_extension()
		wrong("Arquivos .%s não abrem em \"%s\". Olhe a extensão de novo." % [ext, program])
		return
	index += 1
	if index >= COUNT:
		solve("Todos os arquivos abertos! Dica: a extensão sempre mostra o tipo do arquivo.")
	else:
		say("Isso: .%s abre no %s." % [f.file.get_extension(), program])
		_show()
