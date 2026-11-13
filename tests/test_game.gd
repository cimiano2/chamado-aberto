extends SceneTree
## Teste de integração headless: carrega o jogo, abre cada tipo de chamado e
## resolve o minijogo "pelo teclado" (handle_key), incluindo um erro proposital.
##   godot --headless --path . -s tests/test_game.gd

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _init() -> void:
	print("Chamado Aberto — testes do jogo")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var map: OfficeMap = main.get_node("%OfficeMap")
	check(map.desks.size() == 20, "20 mesas/servidores com chamados possíveis")
	for d in map.desks:
		var feet := Rect2(d.pos + Player.FEET.position, Player.FEET.size)
		if not map.is_walkable(feet):
			check(false, "ponto de atendimento caminhável: %s" % d.employee)
	check(map.is_walkable(Rect2(OfficeMap.START + Player.FEET.position, Player.FEET.size)), "posição inicial caminhável")
	check(not map.is_walkable(Rect2(Vector2(850, 300), Vector2(28, 14))), "parede entre salas bloqueia")

	# ---- sistema de chamados
	var ts: TicketSystem = main.tickets
	main._on_overlay_action()   # sai da tela de título
	var t := ts.spawn()
	check(not t.is_empty() and ts.tickets.size() == 1, "chamado aberto numa mesa")
	ts.spawn_timer = 9999.0
	var sla_before: float = t.sla_left
	ts.begin(t.id)
	ts.update(5.0)
	check(is_equal_approx(t.sla_left, sla_before), "SLA do chamado em atendimento fica pausado")
	ts.cancel()
	ts.update(5.0)
	check(t.sla_left < sla_before, "SLA volta a correr ao sair do atendimento")
	var sat: float = ts.satisfaction
	t.sla_left = 0.01
	ts.update(0.1)
	check(ts.tickets.is_empty() and ts.satisfaction < sat and ts.expired == 1, "SLA estourado remove chamado e reduz satisfação")

	# ---- cada minijogo, resolvido pelo teclado
	for kind in TicketSystem.TYPES.keys():
		var desk := 0
		for i in map.desks.size():
			if map.desks[i].kinds.has(kind):
				desk = i
				break
		ts.tickets.clear()
		var tk := {"id": 900, "desk": desk, "kind": kind, "dept": "Teste", "employee": "Fulano",
			"title": "teste", "priority": false, "sla_total": 999.0, "sla_left": 999.0}
		ts.tickets.append(tk)
		main._open_task(tk)
		var task: TaskBase = main._task
		await process_frame
		var errors_before: int = main._task_mistakes
		var ok := await _solve(task, kind)
		check(ok and task.is_solved, "minijogo '%s' resolvido pelo teclado" % kind)
		check(main._task_mistakes == errors_before + 1, "minijogo '%s' registrou o erro proposital" % kind)
		await create_timer(2.0).timeout
		check(main._task == null and ts.get_ticket(900).is_empty(), "chamado '%s' fechado após resolver" % kind)

	# ---- fim do expediente e próximo dia
	ts.tickets.clear()
	ts.clock = TicketSystem.DAY_END - 0.1
	ts.update(1.0)
	await process_frame
	check(main.state == main.State.DAY_END and main._overlay.visible, "18:00 encerra o dia e mostra o relatório")
	main._on_overlay_action()
	check(ts.day == 2 and main.state == main.State.PLAYING and int(ts.clock) == TicketSystem.DAY_START, "Enter começa o dia 2 às 09:00")
	check(ts.sla_for(false) < 95.0, "dia 2 tem prazos menores")
	# ---- game over
	ts.satisfaction = 0.5
	var tk2 := ts.spawn()
	tk2.sla_left = 0.01
	ts.update(0.1)
	await process_frame
	check(main.state == main.State.GAME_OVER, "satisfação zerada encerra o jogo")
	main._on_overlay_action()
	check(main.tickets.day == 1 and main.tickets.satisfaction == 100.0, "Enter recomeça do dia 1")

	print("\n%s" % ("TODOS OS TESTES PASSARAM" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


func _key(task: TaskBase, n: int) -> void:
	task.handle_key(KEY_1 + n)


## Resolve o minijogo apertando as teclas, com um erro proposital antes da resposta certa.
func _solve(task: TaskBase, kind: String) -> bool:
	match kind:
		"network":
			var first := true
			while not task.is_solved:
				var good: int = task.options.find(task.scenario.cause)
				if first:
					_key(task, (good + 1) % 4)
					first = false
				_key(task, good)
				await process_frame
		"printer":
			var joke := -1
			for i in task.actions.size():
				if task.actions[i].issue == "":
					joke = i
					break
			_key(task, joke)
			for _n in 2:
				for i in task.actions.size():
					if task.issues.has(task.actions[i].issue):
						_key(task, i)
						break
		"password":
			# identidade: o erro primeiro, depois a certa
			var btns: Array = task._hotkeys
			var right := -1
			for i in btns.size():
				if btns[i].text.contains("crachá"):
					right = i
			_key(task, (right + 1) % btns.size())
			_key(task, right)
			await process_frame
			for i in task.candidates.size():
				if Helpdesk.password_problems(task.candidates[i], task.full_name).is_empty():
					_key(task, i)
					break
		"slow":
			# erro: marca um essencial e finaliza
			var ess: int = task.procs.find(task.procs.filter(func(p): return p.kind == "essential")[0])
			_key(task, ess)
			task.handle_key(KEY_ENTER)
			_key(task, ess)
			for i in task.procs.size():
				if task.procs[i].kind == "culprit":
					_key(task, i)
			task.handle_key(KEY_ENTER)
		"phishing":
			var first := true
			while not task.is_solved:
				var is_phish: bool = task.emails[task.index].phish
				if first:
					_key(task, 0 if is_phish else 1)
					first = false
				_key(task, 1 if is_phish else 0)
		"cables":
			var first := true
			while not task.is_solved:
				var d: Dictionary = task.devices[task.index]
				if first:
					for i in Helpdesk.PORTS.size():
						if not d.ports.has(Helpdesk.PORTS[i]):
							_key(task, i)
							break
					first = false
				_key(task, Helpdesk.PORTS.find(d.ports[0]))
	return task.is_solved
