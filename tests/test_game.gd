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
	check(map.desks.size() >= 12, "%d postos com chamado no andar" % map.desks.size())
	for d in map.desks:
		var feet := Rect2(d.pos + Player.FEET.position, Player.FEET.size)
		if not map.is_walkable(feet):
			check(false, "ponto de atendimento caminhável: %s" % d.employee)
	check(map.is_walkable(Rect2(OfficeMap.START + Player.FEET.position, Player.FEET.size)), "posição inicial caminhável")
	check(not map.is_walkable(Rect2(Vector2(470, 220), Vector2(28, 14))), "parede entre salas bloqueia")

	# ---- cenário: objetos dentro do piso, portas livres, mesas alcançáveis
	var outside := []
	for o in map.obstacles:
		for corner in [o.position, Vector2(o.end.x, o.position.y), Vector2(o.position.x, o.end.y), o.end]:
			if not map._in_floor(corner):
				outside.append(o)
				break
	check(outside.is_empty(), "nenhum objeto fora das salas/corredor %s" % [outside])
	var blocked_doors := []
	for d in map.doors:
		for o in map.obstacles:
			if o.intersects(d.grow(8)):
				blocked_doors.append(d)
	check(blocked_doors.is_empty(), "nenhuma porta bloqueada %s" % [blocked_doors])
	# faixa livre de 1 ladrilho na frente de cada porta, dos dois lados (ninguém tromba num móvel ao passar)
	var cramped := []
	for d in map.doors:
		var horizontal := map._in_floor(d.get_center() + Vector2(-64, 0)) and map._in_floor(d.get_center() + Vector2(64, 0))
		var approach := d.grow_individual(64, 0, 64, 0) if horizontal else d.grow_individual(0, 64, 0, 64)
		for o in map.obstacles:
			if o.intersects(approach):
				cramped.append([d.position, o])
	check(cramped.is_empty(), "frente das portas livre para passar %s" % [cramped])
	# parede alta só na borda norte ou como bloco único da coluna oeste
	# (o erro antigo: uma faixa de 2560 un. na borda da frente começando em x=0 virava parede alta)
	var bad_walls := map.walls.filter(func(w): return w.kind == "back" and not (w.rect.position.y < 64 or w.rect.position.x < 64))
	var front_tall := map.walls.filter(func(w): return (w.kind == "glass" or (w.kind == "back" and w.rect.position.x >= 64)) and w.rect.end.y >= map.world_rect.end.y)
	check(bad_walls.is_empty() and front_tall.is_empty(), "parede alta só no fundo do andar (nenhuma na frente)")
	# busca em largura numa grade de 16 un. a partir da sala do suporte
	var step := 16.0
	var seen := {}
	var queue: Array[Vector2] = [OfficeMap.START.snapped(Vector2(step, step))]
	seen[queue[0]] = true
	while not queue.is_empty():
		var p: Vector2 = queue.pop_back()
		for dv in [Vector2(step, 0), Vector2(-step, 0), Vector2(0, step), Vector2(0, -step)]:
			var q: Vector2 = p + dv
			if not seen.has(q) and map.is_walkable(Rect2(q + Player.FEET.position, Player.FEET.size)):
				seen[q] = true
				queue.append(q)
	var unreachable := []
	for d in map.desks:
		var ok := false
		for k in seen:
			if k.distance_to(d.pos) < 60.0:
				ok = true
				break
		if not ok:
			unreachable.append(d.employee)
	check(unreachable.is_empty(), "todas as %d mesas com chamado são alcançáveis %s" % [map.desks.size(), unreachable])

	# ---- sistema de chamados
	main.start_session({"name": "Teste", "class_code": "", "skin": 0, "hair": 0, "shirt": 0}, "treino", false)
	var ts: TicketSystem = main.tickets
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
	check(main.state == main.State.FINAL, "satisfação zerada encerra o jogo e mostra o resultado")
	main._on_overlay_secondary()
	check(main.state == main.State.TITLE and main.tickets.day == 1 and main.tickets.satisfaction == 100.0, "volta ao menu com sessão nova")

	# ---- pontuação: rapidez, prioridade, erros e sequência
	var tsp := TicketSystem.new(map.desks, 1)
	var fast := {"sla_left": 90.0, "sla_total": 90.0, "priority": false}
	check(tsp.points_for(fast, 0) == 200, "chamado resolvido na hora vale 200")
	check(tsp.points_for({"sla_left": 45.0, "sla_total": 90.0, "priority": true}, 1) == 175, "metade do prazo + prioridade − 1 erro = 175")
	tsp.combo = 3
	check(tsp.points_for(fast, 0) == 260, "sequência de 3 sem erro multiplica por 1,3")
	check(tsp.points_for(fast, 2) == 150, "erro zera o multiplicador")

	# ---- relatório: código confere e adulteração é detectada
	var rep_ts := TicketSystem.new(map.desks, 5)
	rep_ts.start_day(1)
	for i in 3:
		var tk3 := rep_ts.spawn()
		rep_ts.resolve(tk3.id, i % 2)
	var rd := Report.data({"name": "Maria Ávila", "class_code": "INFO1A"}, rep_ts, "Avaliação", 0)
	var page := Report.html(rd)
	check(Report.verify_html(page).ok, "relatório gerado confere o código de verificação")
	var tampered := page.replace('"pontos":%d' % rd.pontos, '"pontos":%d' % (rd.pontos + 500))
	check(tampered != page and not Report.verify_html(tampered).ok, "relatório com pontos alterados é detectado")
	check(page.contains("Maria Ávila") and page.contains("INFO1A"), "relatório traz nome e turma")

	# ---- skins: as cores mudam no sprite
	var base_img := Skins.image(0, 0, 0)
	var skin_img := Skins.image(3, 2, 1)
	var changed := 0
	for y in base_img.get_height():
		for x in base_img.get_width():
			if base_img.get_pixel(x, y) != skin_img.get_pixel(x, y):
				changed += 1
	check(changed > 100, "skin recolore o técnico (%d pixels)" % changed)

	# ---- áudio: música desligada por padrão, música e efeitos independentes e salvos
	DirAccess.remove_absolute(Audio.PREF_PATH)
	var au := Audio.new()
	root.add_child(au)
	check(au.music_on and au.sfx_on, "som ambiente e efeitos começam ligados (sem música)")
	check(ResourceLoader.exists("res://assets/audio/office_ambience.ogg") and (load("res://assets/audio/office_ambience.ogg") as AudioStream).get_length() > 60.0, "som ambiente de escritório (gravação) disponível para o jogo")
	au.set_music(true)
	au.set_sfx(false)
	var au2 := Audio.new()
	root.add_child(au2)
	check(au2.music_on and not au2.sfx_on, "escolhas de ambiente e efeitos ficam salvas e são independentes")
	au2.set_music(true)
	au2.set_sfx(true)
	au.queue_free()
	au2.queue_free()

	# ---- música do menu: toca só no menu e pode ser desligada
	DirAccess.remove_absolute(Audio.PREF_PATH)
	var am := Audio.new()
	root.add_child(am)
	main._audio.menu_music_on = true
	main._show_menu()
	await process_frame
	check(main._audio.is_menu_music_playing(), "música original toca no menu")
	main.start_session({"name": "Musica", "class_code": "", "skin": 0, "hair": 0, "shirt": 0}, "treino", false)
	await process_frame
	check(not main._audio.is_menu_music_playing(), "música do menu para quando o jogo começa")
	main.back_to_menu()
	await process_frame
	check(main._audio.is_menu_music_playing(), "música volta ao retornar para o menu")
	main._audio.set_menu_music(false)
	check(not main._audio.is_menu_music_playing(), "botão desliga a música do menu")
	var am2 := Audio.new()
	root.add_child(am2)
	check(not am2.menu_music_on, "música do menu desligada fica salva")
	main._audio.set_menu_music(true)
	am.queue_free()
	am2.queue_free()
	var mt := load("res://assets/audio/menu_theme.ogg") as AudioStream
	check(mt != null and absf(mt.get_length() - 30.0) < 0.2, "tema do menu tem 30 s (loop de 16 compassos)")

	# ---- pausa: voltar ao menu (com confirmação) e continuar depois
	main.start_session({"name": "Pausa Teste", "class_code": "", "skin": 0, "hair": 0, "shirt": 0}, "treino", false)
	main.tickets.score = 333
	main._save_session(false)
	main._show_pause()
	check(main.state == main.State.PAUSED and main._overlay.visible, "P abre a pausa")
	main._on_overlay_secondary()
	check(main.state == main.State.PAUSED and main._confirm_menu, "voltar ao menu pede confirmação")
	main._on_overlay_secondary()
	check(main.state == main.State.TITLE and main._menu != null, "confirmando, volta ao menu inicial")
	var sv := SaveGame.load_session()
	check(sv.has("profile") and sv.profile.name == "Pausa Teste" and int(sv.state.score) == 333, "sessão continua salva para Continuar")

	# ---- sessão salva: continuar restaura a pontuação e conta o reinício
	var prof := {"name": "Teste Save", "class_code": "T1", "skin": 1, "hair": 2, "shirt": 3}
	main.start_session(prof, "avaliacao", false)
	main.tickets.score = 777
	main._save_session(false)
	main.start_session(prof, "avaliacao", true)
	check(main.tickets.score == 777 and main.restarts == 1, "continuar sessão restaura pontos e registra 1 reinício")
	var a_seed: int = main.tickets.rng.seed
	main.start_session(prof, "avaliacao", false)
	check(main.tickets.rng.seed == a_seed, "mesmo código de turma = mesma sequência de chamados")
	SaveGame.clear()
	SaveGame.clear_board()

	print("\n%s" % ("TODOS OS TESTES PASSARAM" if failures == 0 else "%d FALHA(S)" % failures))
	quit(1 if failures > 0 else 0)


func _key(task: TaskBase, n: int) -> void:
	task.handle_key(KEY_1 + n)


## Resolve o minijogo apertando as teclas, com um erro proposital antes da resposta certa.
func _solve(task: TaskBase, kind: String) -> bool:
	match kind:
		"hardware":
			var first := true
			while not task.is_solved:
				var good: int = task.options.find(task.scenario.part)
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
		"files":
			var first := true
			while not task.is_solved:
				var good: int = task.options.find(task.scenario.answer)
				if first:
					_key(task, (good + 1) % 4)
					first = false
				_key(task, good)
				await process_frame
		"install":
			var trap := -1
			for i in task.buttons.size():
				if task.buttons[i].step == -1:
					trap = i
					break
			_key(task, trap)
			for step in task.program.steps.size():
				for i in task.buttons.size():
					if task.buttons[i].step == step:
						_key(task, i)
						break
		"cleanup":
			var bad := -1
			for i in task.items.size():
				if not task.items[i].safe:
					bad = i
					break
			_key(task, bad)
			task.handle_key(KEY_ENTER)          # erro: marcou algo que não pode apagar
			_key(task, bad)
			for i in task.items.size():
				if task.items[i].safe:
					_key(task, i)
			task.handle_key(KEY_ENTER)
		"extensions":
			var first := true
			while not task.is_solved:
				var good: int = Helpdesk.EXT_PROGRAMS.find(task.files[task.index].program)
				if first:
					_key(task, (good + 1) % Helpdesk.EXT_PROGRAMS.size())
					first = false
				_key(task, good)
		"shortcuts":
			var first := true
			while not task.is_solved:
				var good: int = task.options.find(task.questions[task.index].a)
				if first:
					_key(task, (good + 1) % 4)
					first = false
				_key(task, good)
				await process_frame
	return task.is_solved
