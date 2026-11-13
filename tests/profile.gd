extends SceneTree
## Mede desempenho com renderização real (precisa de display):
##   godot --path . -s tests/profile.gd
## Anda pelo escritório com chamados abertos e registra FPS, tempos e chamadas de desenho.

func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)

func _init() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5: await process_frame
	main.start_session({"name": "Perf", "class_code": "", "skin": 0, "hair": 0, "shirt": 0, "body": 0}, "treino", false)
	var ts: TicketSystem = main.tickets
	for i in 5: ts.spawn()
	ts.spawn_timer = 9999.0
	var map: OfficeMap = main.get_node("%OfficeMap")
	var player: Player = main.get_node("%Player")
	player.position = Vector2(760, 1010)
	for i in 30: await process_frame
	var samples := {"frame_ms": [], "process_ms": [], "map_draw_ms": [], "draw_calls": [], "objects": []}
	var t_start := Time.get_ticks_usec()
	var last := Time.get_ticks_usec()
	var dirs := [KEY_RIGHT, KEY_UP, KEY_LEFT, KEY_DOWN]
	for f in 240:
		if f % 60 == 0:
			for d in dirs: _key(d, false)
			_key(dirs[(f / 60) % 4], true)
		await process_frame
		var now := Time.get_ticks_usec()
		samples.frame_ms.append((now - last) / 1000.0)
		last = now
		samples.process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		samples.map_draw_ms.append(map.draw_usec / 1000.0)
		samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		samples.objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	for d in dirs: _key(d, false)
	var secs := (Time.get_ticks_usec() - t_start) / 1e6
	print("PERF fps_medio=%.1f  quadros=240  tempo=%.2fs" % [240 / secs, secs])
	for k in samples:
		var arr: Array = samples[k]
		var avg: float = arr.reduce(func(a, b): return a + b, 0.0) / arr.size()
		print("PERF %-12s media=%8.2f  max=%8.2f" % [k, avg, arr.max()])
	print("PERF itens_desenhados_no_mapa=%d  paredes=%d  props=%d  mesas=%d" % [map.draw_items, map.walls.size(), map.props.size(), map.desks.size()])
	# de onde vêm as chamadas de desenho: mede com partes escondidas
	var hud: CanvasLayer = main.get_node("HUD")
	var world: Control = main.get_node("%WorldView")
	for cfg in [["tudo", true, true], ["so_mundo", true, false], ["so_hud", false, true]]:
		world.visible = cfg[1]
		hud.visible = cfg[2]
		for i in 5: await process_frame
		print("PERF draw_calls[%s]=%d" % [cfg[0], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	world.visible = true
	hud.visible = true
	var st: Node2D = map.get_child(0)
	st.visible = false
	for i in 5: await process_frame
	print("PERF draw_calls[sem_piso_e_fundo]=%d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	st.visible = true
	print("PERF static_memory_MB=%.1f  nos=%d" % [Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	quit()
