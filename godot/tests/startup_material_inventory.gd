extends SceneTree
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func run() -> void:
	var game: Node3D = load("res://main.tscn").instantiate()
	game.save_path = output.path_join("inventory-save.json")
	root.add_child(game)
	await physics_frame
	var rows: Array = game._warm_material_inventory(game._warm_material_plan())
	var fallback_nodes: Array = []
	for raw in game.find_children("*","MeshInstance3D",true,false):
		var node := raw as MeshInstance3D
		for surface in node.mesh.get_surface_count() if node.mesh != null else 0:
			var material := node.get_active_material(surface)
			if material is StandardMaterial3D:
				fallback_nodes.append({"path":str(game.get_path_to(node)),"texture_filter":material.texture_filter,"texture_repeat":material.texture_repeat,"shading_mode":material.shading_mode,"reason":game._runtime_surface.unsupported(material)})
	var receipt := {"kind":"native_complete_material_inventory_not_GPU_compile_time_proof","families":rows,"fallback_nodes":fallback_nodes,"source_api_bound":RenderingServer.has_method("shader_get_native_source_code"),"boot":game._boot_timing_durations_usec}
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  ")); file.close()
	print("STARTUP_MATERIAL_INVENTORY " + JSON.stringify(receipt))
	game.queue_free()
	await create_timer(.5).timeout
	quit()
