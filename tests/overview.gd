extends SceneTree
## Renderiza o andar inteiro numa imagem (revisão de cenário):
##   godot --path . -s tests/overview.gd -- <saida.png>

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var vp := SubViewport.new()
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var map: OfficeMap = load("res://scripts/office_map.gd").new()
	vp.add_child(map)
	await process_frame
	var b := map.iso_bounds()
	vp.size = Vector2i(b.size)
	var cam := Camera2D.new()
	cam.position = b.get_center()
	vp.add_child(cam)
	cam.make_current()
	# marca obstáculos (vermelho) e pontos de atendimento (verde) por cima
	var dbg := Node2D.new()
	dbg.z_index = 10
	dbg.draw.connect(func():
		for o in map.obstacles:
			var pts := PackedVector2Array([OfficeMap.iso(o.position), OfficeMap.iso(Vector2(o.end.x, o.position.y)), OfficeMap.iso(o.end), OfficeMap.iso(Vector2(o.position.x, o.end.y)), OfficeMap.iso(o.position)])
			dbg.draw_polyline(pts, Color(1, 0, 0, 0.9), 1.0)
		for d in map.desks:
			dbg.draw_circle(OfficeMap.iso(d.pos), 2, Color(0, 1, 0)))
	vp.add_child(dbg)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("salvo ", out, " ", img.get_size())
	quit()
