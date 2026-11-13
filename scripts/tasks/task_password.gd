extends TaskBase
## "Esqueci minha senha": confirmar a identidade e escolher uma nova senha dentro da política.

const SURNAMES := ["Souza", "Lima", "Costa", "Rocha", "Alves", "Melo"]
const IDENTITY := [
	{"text": "Conferir crachá ou matrícula do usuário", "ok": true},
	{"text": "Trocar a senha direto, ele parece honesto", "ok": false, "why": "Sem confirmar a identidade, qualquer um poderia pedir a senha de outra pessoa."},
	{"text": "Pedir a senha antiga por e-mail", "ok": false, "why": "Nunca peça senha por e-mail: é exatamente o que golpistas fazem."},
	{"text": "Anotar a senha nova num post-it no monitor", "ok": false, "why": "Senha anotada à vista é senha vazada."},
]

var full_name := ""
var step := 0                 # 0 = identidade, 1 = senha
var candidates: Array[String] = []
var _box: VBoxContainer
var _prompt: Label


func _init() -> void:
	task_title = "Troca de senha"
	explain = "Política da empresa: no mínimo 10 caracteres, com MAIÚSCULA, minúscula, número e símbolo, sem o nome do usuário nem sequências fáceis (123, senha...)."


func build() -> void:
	var first: String = get_meta("employee", pick(["Carla", "Bruno", "Elisa", "João"]))
	full_name = "%s %s" % [first.split(" ")[0], pick(SURNAMES)]
	add_child(make_label("Usuário: %s  (conta bloqueada após 5 tentativas)" % full_name, &"HeadingLabel"))
	_prompt = make_label("", &"")
	add_child(_prompt)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	_show_identity()


func _show_identity() -> void:
	_prompt.text = "Antes de desbloquear a conta, o que você faz?"
	var opts := IDENTITY.duplicate()
	Helpdesk.shuffle(opts, rng)
	for o in opts:
		var b := make_button(o.text, _on_identity.bind(o), true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_box.add_child(b)


func _on_identity(o: Dictionary) -> void:
	if step != 0 or is_solved:
		return
	if not o.ok:
		wrong(o.why)
		return
	step = 1
	say("Identidade confirmada. Agora escolha uma senha nova que siga a política.")
	for c in _box.get_children():
		c.queue_free()
	clear_hotkeys()
	_prompt.text = "Qual destas senhas é aceita pela política?"
	var first := full_name.split(" ")[0]
	var good := "%s%d%s%s" % [pick(["Cafe", "Nuvem", "Trilha", "Girassol", "Farol"]), rng.randi_range(10, 99),
		pick(["!", "#", "@", "$"]), pick(["Azul", "Verde", "Lua", "Mar"])]
	candidates = [good, first + "2024!", "Senha@1234", pick(["Ab1!", "Xy9#k", "Qw3$"]),
		pick(["girassolazul99!", "FAROLNORTE77#"])]
	Helpdesk.shuffle(candidates, rng)
	for pw in candidates:
		var b := make_button(pw, _on_password.bind(pw), true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_box.add_child(b)


func _on_password(pw: String) -> void:
	if step != 1 or is_solved:
		return
	var problems := Helpdesk.password_problems(pw, full_name)
	if not problems.is_empty():
		wrong("\"%s\" não serve: %s." % [pw, ", ".join(problems)])
		return
	solve("Conta desbloqueada com a senha nova. Peça para o usuário trocá-la no próximo login!")
