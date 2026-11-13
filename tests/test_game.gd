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
	check(map.is_walkable(Rect2(Vector2(390, 1100) + Player.FEET.position, Player.FEET.size)), "posição inicial caminhável")
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
	for kind in ["cpu", "paging", "deadlock", "disk", "chmod", "alloc"]:
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


## Resolve o minijogo usando a lógica de OSLogic e apertando as teclas.
## Antes da resposta certa, faz uma jogada errada para testar o retorno de erro.
func _solve(task: TaskBase, kind: String) -> bool:
	match kind:
		"cpu":
			var names: Array = task.procs.map(func(p): return p.name)
			var wrong_i := names.find(task.expected[1])
			_key(task, wrong_i)
			for n in task.expected:
				_key(task, names.find(n))
		"deadlock":
			var blocked := -1
			for i in 4:
				if not OSLogic.fits(task.need[i], task.work):
					blocked = i
					break
			_key(task, blocked)
			for _round in 4:
				for i in 4:
					if not task.finished[i] and OSLogic.fits(task.need[i], task.work):
						_key(task, i)
						break
		"disk":
			var sorted: Array = task.requests.duplicate()
			sorted.sort()
			_key(task, sorted.find(task.expected[-1]))
			for c in task.expected:
				_key(task, sorted.find(c))
		"chmod":
			task.handle_key(KEY_ENTER)    # tudo desmarcado: erro (nenhum alvo é 000)
			for _round in task.rounds:
				var bits := OSLogic.octal_to_bits(task.target)
				for i in 9:
					if task._bits[i].button_pressed != bits[i]:
						_key(task, i)
				task.handle_key(KEY_ENTER)
		"alloc":
			var first := true
			while not task.queue.is_empty():
				var req: Dictionary = task.queue[0]
				var good := OSLogic.fit_choices(task.holes, req.size, task.algorithm)
				if first:
					for i in task.holes.size():
						if not good.has(i):
							_key(task, i)
							break
					first = false
				_key(task, good[0])
				await process_frame
		"paging":
			var made_error := false
			var guard := 0
			while not task.is_solved and guard < 400:
				guard += 1
				if task.waiting_choice:
					var good := OSLogic.page_victims(task.algorithm, task.frames, task.loaded_at, task.last_used, task.refs, task.t)
					if not made_error:
						for i in 3:
							if not good.has(i):
								_key(task, i)
								made_error = true
								break
					_key(task, good[0])
				else:
					task._timer.stop()
					task._step()
	return task.is_solved
