extends SceneTree
## Matching actual-world views plus motion/contact readback; not a travel proof.
var output := ""
var game: Node3D
var review: Node
var rows: Array = []

func _initialize() -> void:
	root.size = Vector2i(1280,720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func run() -> void:
	if output.is_empty(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate()
	game.save_path = output.path_join("probe-expedition.json")
	root.add_child(game)
	await process_frame
	game.start_expedition()
	game._set_phase("exploring")
	review = load("res://scripts/world_review.gd").new()
	root.add_child(review)
	review.setup(game)
	var shots := ["aurora_shelf","aurora_shelf_reverse","aurora_shelf_side","ember_rift","ember_rift_reverse","ember_rift_side","veil_marsh","veil_marsh_reverse","veil_marsh_side","pale_decay","pale_decay_reverse","pale_decay_side","veyra","aeral","morrow","shore","microfauna"]
	for id in shots:
		assert(review.set_view(id), "Unknown view " + id)
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(id+".png"))
		rows.append({"view":id,"position":str(review.camera.position),"rotation":str(review.camera.rotation),"fov":review.camera.fov,
			"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var creatures: Array = []
	for i in game.world._ecology_nodes.size():
		var node: Node3D = game.world._ecology_nodes[i]
		var detailed: Node3D = node.get_node_or_null("DetailedVisual")
		creatures.append({"name":str(node.name),"kind":str(game.world._ecology_meta[i].kind),"hasDetailedVisual":detailed!=null,
			"worldPosition":str(node.global_position),"terrainHeight":game.world.height_at(node.position.x,node.position.z),
			"pose":detailed.get("pose_state") if detailed != null else null})
	var receipt := {"kind":"native_graphical_actual_world_fixed_views_not_journey","engine":Engine.get_version_info().string,
		"device":RenderingServer.get_video_adapter_name(),"viewport":str(root.size),"shots":rows,"creatures":creatures,"buildStats":game.world.build_stats}
	var file := FileAccess.open(output.path_join("views.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  "))
	file.close()
	print("WORLD_UPGRADE_CAPTURE_COMPLETE ",shots.size())
	game.set_process(false)
	for player in game.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	game.queue_free()
	await process_frame
	await process_frame
	quit()
