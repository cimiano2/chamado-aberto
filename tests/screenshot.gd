extends SceneTree
## Capturas de tela (precisa de display, ex.: xvfb-run):
##   godot --path . -s tests/screenshot.gd -- <pasta_saida>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5: await process_frame
	await _shot(out + "/titulo.png")
	main._on_overlay_action()
	var ts: TicketSystem = main.tickets
	ts.rng.seed = 3
	ts.spawn_timer = 9999.0
	for i in 4: ts.spawn()
	ts.tickets[0].sla_left = ts.tickets[0].sla_total * 0.2
	ts.clock = 11 * 60 + 25
	ts.score = 1340
	ts.satisfaction = 78
	# técnico em frente a uma mesa com chamado
	var map: OfficeMap = main.get_node("%OfficeMap")
	var player: Player = main.get_node("%Player")
	player.position = map.desks[ts.tickets[1].desk].pos + Vector2(10, 10)
	player.facing = Vector2.UP
	for i in 40: await process_frame
	await _shot(out + "/jogo.png")
	player.position = Vector2(1180, 680)
	player.facing = Vector2.RIGHT
	for i in 40: await process_frame
	await _shot(out + "/corredor.png")
	player.facing = Vector2(-1, -1)
	for i in 5: await process_frame
	await _shot(out + "/costas_esq.png")
	player.facing = Vector2(-1, 1)
	for i in 5: await process_frame
	await _shot(out + "/frente_esq.png")
	for kind in TicketSystem.TYPES.keys():
		var tk := {"id": 42, "desk": 0, "kind": kind, "dept": "Financeiro", "employee": "Carla",
			"title": TicketSystem.TYPES[kind].titles[0], "priority": false, "sla_total": 999.0, "sla_left": 999.0}
		ts.tickets.append(tk)
		main._open_task(tk)
		for i in 8: await process_frame
		await _shot(out + "/task_%s.png" % kind)
		main._cancel_task()
		ts.tickets.erase(tk)
	quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("salvo ", path)
