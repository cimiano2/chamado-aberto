extends SceneTree
## Capturas de tela (precisa de display, ex.: xvfb-run):
##   godot --path . -s tests/screenshot.gd -- <pasta_saida>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	SaveGame.clear()
	SaveGame.clear_board()
	SaveGame.add_to_board("Rafael Souza", "INFO1A", "avaliacao", 2350, 8.4)
	SaveGame.add_to_board("Bia Martins", "INFO1A", "avaliacao", 1980, 7.6)
	SaveGame.add_to_board("Caio Nunes", "INFO1A", "treino", 1210, 6.1)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 8: await process_frame
	await _shot(out + "/menu.png")

	main.start_session({"name": "Marina Lopes", "class_code": "INFO1A", "skin": 2, "hair": 3, "shirt": 1}, "avaliacao", false)
	var ts: TicketSystem = main.tickets
	ts.spawn_timer = 9999.0
	var map: OfficeMap = main.get_node("%OfficeMap")
	var player: Player = main.get_node("%Player")
	player.position = Vector2(600, 760)
	for i in 4:
		ts.spawn()
	ts.tickets[0].sla_left = ts.tickets[0].sla_total * 0.2
	ts.clock = 10 * 60 + 40
	ts.score = 1260
	ts.combo = 2
	for i in 50: await process_frame
	await _shot(out + "/jogo.png")
	# perto de uma mesa com chamado: funcionário fala
	var d: Dictionary = map.desks[ts.tickets[1].desk]
	player.position = d.pos + Vector2(0, 6)
	player.facing = Vector2.UP
	for i in 20: await process_frame
	main._open_task(ts.tickets[1])
	for i in 4: await process_frame
	main._cancel_task()
	for i in 10: await process_frame
	await _shot(out + "/balao.png")
	player.position = Vector2(704, 300)    # dentro da gerência (atrás do vidro)
	for i in 10: await process_frame
	await _shot(out + "/gerencia.png")
	player.position = Vector2(1100, 260)    # copa
	for i in 10: await process_frame
	await _shot(out + "/copa.png")
	for kind in TicketSystem.TYPES.keys():
		var tk := {"id": 42, "desk": 0, "kind": kind, "dept": "Vendas", "employee": "Carla",
			"title": TicketSystem.TYPES[kind].titles[0], "priority": false, "sla_total": 999.0, "sla_left": 999.0}
		ts.tickets.append(tk)
		main._open_task(tk)
		for i in 8: await process_frame
		await _shot(out + "/task_%s.png" % kind)
		main._cancel_task()
		ts.tickets.erase(tk)
	# resultado final
	for i in 6:
		var t := ts.spawn()
		if not t.is_empty():
			ts.resolve(t.id, i % 3 == 0)
	main._show_final("18:00 — FIM DA AVALIAÇÃO", "Expediente concluído. Baixe o relatório e envie para o professor.")
	for i in 10: await process_frame
	await _shot(out + "/final.png")
	var html := Report.html(Report.data(main.profile, ts, "Avaliação", 0))
	FileAccess.open(out + "/relatorio_exemplo.html", FileAccess.WRITE).store_string(html)
	SaveGame.clear()
	SaveGame.clear_board()
	quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("salvo ", path)
