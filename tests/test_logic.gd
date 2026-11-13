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
	var causes := {}
	for s in Helpdesk.NETWORK:
		causes[s.cause] = true
		check(s.out != "" and s.fix != "", "rede: cenário '%s' tem saída e solução" % s.cause)
	check(causes.size() == Helpdesk.NETWORK.size() and causes.size() >= 4, "rede: causas distintas (precisa de 4 opções)")
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

	# --- todo tipo de chamado aponta para um minijogo que existe
	for kind in TicketSystem.TYPES:
		check(ResourceLoader.exists(TicketSystem.TYPES[kind].task), "chamado '%s' tem minijogo" % kind)

	print("\n%s" % ("TODOS OS TESTES PASSARAM" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)
