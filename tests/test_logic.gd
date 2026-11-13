extends SceneTree
## Testes headless das regras dos chamados:
##   godot --headless --path . -s tests/test_logic.gd

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _init() -> void:
	print("Chamado Aberto — testes das regras")

	# --- política de senha
	var name := "Carla Souza"
	check(Helpdesk.password_problems("Farol42#Lua", name).is_empty(), "senha forte é aceita")
	check(not Helpdesk.password_problems("Ab1!", name).is_empty(), "senha curta é recusada")
	check(not Helpdesk.password_problems("Carla2024!x", name).is_empty(), "senha com o nome é recusada")
	check(not Helpdesk.password_problems("Senha@1234", name).is_empty(), "senha com 'senha'/'123' é recusada")
	check(not Helpdesk.password_problems("girassolazul99!", name).is_empty(), "senha sem maiúscula é recusada")
	check(not Helpdesk.password_problems("FAROLNORTE77#", name).is_empty(), "senha sem minúscula é recusada")
	check(not Helpdesk.password_problems("FarolNorteLua", name).is_empty(), "senha sem número/símbolo é recusada")
	check(Helpdesk.password_problems("souzaFarol9!", name).has("contém o nome do usuário (\"souza\")"), "detecta sobrenome dentro da senha")

	# --- dados dos chamados são consistentes
	var parts := {}
	for s in Helpdesk.HARDWARE:
		parts[s.part] = true
		check(s.symptom != "" and s.fix != "", "hardware: caso '%s' tem sintoma e solução" % s.part)
	check(parts.size() == Helpdesk.HARDWARE.size() and parts.size() >= 4, "hardware: peças distintas (precisa de 4 opções)")
	check(Helpdesk.EMAILS.filter(func(e): return e.phish).size() >= 2 and Helpdesk.EMAILS.filter(func(e): return not e.phish).size() >= 1, "e-mails: há golpes e legítimos suficientes")
	for e in Helpdesk.EMAILS:
		if e.phish:
			check(not e.from.ends_with("@empresa.com.br"), "golpe não usa o domínio oficial: %s" % e.from)
		else:
			check(e.from.ends_with("@empresa.com.br"), "legítimo usa o domínio oficial: %s" % e.from)
	for d in Helpdesk.DEVICES:
		for p in d.ports:
			check(Helpdesk.PORTS.has(p), "porta de '%s' existe: %s" % [d.name, p])
	check(Helpdesk.PROCESSES_ESSENTIAL.all(func(p): return p.cpu < 50), "processos essenciais não parecem culpados (CPU baixa)")
	check(Helpdesk.PROCESSES_CULPRIT.all(func(p): return p.cpu >= 50), "processos culpados têm CPU alta")

	# --- conteúdos novos
	check(Helpdesk.FILES.all(func(f): return Helpdesk.FILE_OPTIONS.has(f.answer)), "arquivo sumiu: toda resposta está entre as opções")
	check(Helpdesk.INSTALLS.all(func(i): return i.steps.size() == 5), "instalar: todo programa tem 5 passos")
	var tot := 0.0
	for it in Helpdesk.CLEANUP_SAFE:
		tot += it.gb
	check(tot > 15.0, "disco cheio: itens seguros liberam espaço suficiente")
	check(Helpdesk.EXTENSIONS.all(func(e): return Helpdesk.EXT_PROGRAMS.has(e.program)), "extensões: todo programa existe")
	var answers := {}
	for sc in Helpdesk.SHORTCUTS:
		answers[sc.a] = true
	check(answers.size() == Helpdesk.SHORTCUTS.size(), "atalhos: respostas distintas")
	check(Helpdesk.HARDWARE.size() >= 10 and Helpdesk.EMAILS.size() >= 12, "mais casos de hardware (%d) e e-mails (%d)" % [Helpdesk.HARDWARE.size(), Helpdesk.EMAILS.size()])

	# --- variedade: casos e tipos não se repetem em seguida
	var r := RandomNumberGenerator.new()
	r.seed = 9
	var last: Array[int] = []
	var repeats := 0
	for i in 60:
		var pick: int = Helpdesk.pick_fresh("teste", 10, 1, r)[0]
		if last.has(pick):
			repeats += 1
		last.append(pick)
		if last.size() > 4:
			last.pop_front()
	check(repeats == 0, "um caso não volta nos 4 sorteios seguintes (60 sorteios)")
	var ts := TicketSystem.new([], 3)
	var kinds := TicketSystem.TYPES.keys()
	var seq: Array[String] = []
	for i in 60:
		seq.append(ts.pick_kind(kinds))
	var back := 0
	for i in range(1, seq.size()):
		for j in range(maxi(0, i - 4), i):
			if seq[i] == seq[j]:
				back += 1
	check(back == 0, "tipo de chamado não se repete nos 4 seguintes")
	var distinct := {}
	for k in seq:
		distinct[k] = true
	check(distinct.size() == kinds.size(), "todos os %d tipos aparecem em 60 chamados" % kinds.size())

	# --- todo tipo de chamado aponta para um minijogo que existe
	for kind in TicketSystem.TYPES:
		check(ResourceLoader.exists(TicketSystem.TYPES[kind].task), "chamado '%s' tem minijogo" % kind)

	print("\n%s" % ("TODOS OS TESTES PASSARAM" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)
