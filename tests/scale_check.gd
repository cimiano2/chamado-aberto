extends SceneTree
## Capturas em várias resoluções de janela (precisa de display grande, ex.:
##   xvfb-run -a -s "-screen 0 2600x1500x24" godot --path . -s tests/scale_check.gd -- <pasta> 1366x768 1920x1080
## Mede também o "tremor": quantas colunas de pixel mudam de largura entre dois quadros andando.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var sizes := args.slice(1)
	SaveGame.clear()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3: await process_frame
	for s in sizes:
		var p: PackedStringArray = s.split("x")
		if DisplayServer.window_get_size() != Vector2i(int(p[0]), int(p[1])):
			DisplayServer.window_set_size(Vector2i(int(p[0]), int(p[1])))
		for i in 6: await process_frame
		if main.state != 0:
			main.back_to_menu()
		main._show_menu()
		for i in 6: await process_frame
		_save(out + "/menu_%s.png" % s)
		main.start_session({"name": "Marina Lopes", "class_code": "INFO1A", "skin": 2, "hair": 3, "shirt": 1, "body": 1}, "avaliacao", false)
		var ts: TicketSystem = main.tickets
		ts.spawn_timer = 9999.0
		for i in 4: ts.spawn()
		main.get_node("%Player").position = Vector2(600, 760)
		for i in 40: await process_frame
		_save(out + "/jogo_%s.png" % s)
		print("tamanho ", s, " janela=", DisplayServer.window_get_size(), " viewport=", root.get_visible_rect().size, " escala=", root.get_final_transform().get_scale(), " mundo x", main.view_scale, " quadro=", main._world_view.position, main._world_view.size, " canto_tela=", root.get_final_transform() * main._world_view.get_global_transform().origin, " escala_tela=", root.get_final_transform().get_scale() * main._world_view.get_global_transform().get_scale())
		main.back_to_menu() if main.has_method("back_to_menu") else null
	quit()

func _save(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
