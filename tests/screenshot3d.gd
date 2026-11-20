extends SceneTree
## Capturas da versão 3D (precisa de display, ex.: xvfb-run):
##   godot --path . -s tests/screenshot3d.gd -- <pasta_saida>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	SaveGame.clear()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3: await process_frame
	main._menu.profile.view = "3d"
	main._menu._refresh()
	for i in 4: await process_frame
	await _shot(out + "/menu3d.png")
	main.start_session({"name": "Marina Lopes", "class_code": "INFO1A", "skin": 2, "hair": 3, "shirt": 1, "body": 1, "view": "3d"}, "avaliacao", false)
	var ts: TicketSystem = main.tickets
	ts.spawn_timer = 9999.0
	var player: Player = main.get_node("%Player")
	var map: OfficeMap = main.get_node("%OfficeMap")
	for i in 4:
		ts.spawn()
	ts.tickets[0].sla_left = ts.tickets[0].sla_total * 0.2
	for i in 30: await process_frame
	await _shot(out + "/jogo3d_ti.png")
	player.position = Vector2(600, 760)
	main._w3.snap_camera()
	for i in 30: await process_frame
	await _shot(out + "/jogo3d_vendas.png")
	var d: Dictionary = map.desks[ts.tickets[1].desk]
	player.position = d.pos + Vector2(0, 6)
	player.facing = Vector2.UP
	main._w3.snap_camera()
	for i in 30: await process_frame
	await _shot(out + "/jogo3d_mesa.png")
	player.position = Vector2(1300, 900)
	main._w3.snap_camera()
	for i in 30: await process_frame
	await _shot(out + "/jogo3d_corredor.png")
	print("ok")
	quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("salvo ", path)
