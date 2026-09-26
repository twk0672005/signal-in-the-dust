extends SceneTree
## Fixed-view comparison of the real game scene. Fixtures are not player travel proof.
var output := ""
var samples: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func run() -> void:
	if output.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://main.tscn").instantiate()
	game.save_path = output.path_join("visual-probe-save.json")
	root.add_child(game)
	await process_frame
	game.start_expedition()
	game._set_phase("exploring")
	game.rover.set_driving_enabled(false)
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 800.0
	root.add_child(camera)
	camera.current = true
	for z in [125.0, -100.0, -275.0, -495.0]:
		var x: float = game.world.path_x(z)
		var ground: float = game.world.height_at(x,z)
		var point := Vector3(x, ground+0.1, z)
		game.rover.global_position = point
		game.world.set_player_state(point,0.0)
		var region: String = game.world.region_at(point)
		game.world.set_region_mood(region,10.0)
		camera.position = Vector3(x+5.5,ground+3.5,z+8.0)
		camera.look_at(Vector3(game.world.path_x(z-24.0),ground+2.6,z-24.0))
		await create_timer(1.0).timeout
		var frame_times: Array = []
		for i in 120:
			await process_frame
			frame_times.append(game.get_process_delta_time()*1000.0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(region+".png"))
		frame_times.sort()
		samples.append({"region":region,"position":str(camera.position),"fov":camera.fov,
			"p50ms":frame_times[59],"p95ms":frame_times[113],"worstMs":frame_times[-1],
			"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var report := {"kind":"native_graphical_fixed_world_views_not_player_journey", "engine":Engine.get_version_info().string,
		"device":RenderingServer.get_video_adapter_name(),"samples":samples,"buildStats":game.world.build_stats,"visualAcceptance":false}
	var file := FileAccess.open(output.path_join("visual-probe.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report))
	game.set_process(false)
	for player in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	await process_frame
	quit()
