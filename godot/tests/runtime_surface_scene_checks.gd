extends SceneTree
var output := ""
var checks: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node3D = load("res://main.tscn").instantiate()
	game.save_path = output.path_join("surface-scene-save.json")
	root.add_child(game)
	await process_frame
	var adapter: Node = game._runtime_surface
	var stats: Dictionary = adapter.snapshot()
	checks.standard_surfaces_use_bounded_shared_programs = stats.adapted_materials > 50 and stats.shared_programs <= 5
	checks.native_menu_and_render_truth_preserved = game.ready_for_play and game.phase == "menu" and not game._web_boot.first_frame_ready
	var programs: Dictionary = {}
	var originals: Dictionary = {}
	for raw in game.find_children("*","GeometryInstance3D",true,false):
		var node := raw as GeometryInstance3D
		var materials: Array[Material] = []
		if node.material_override != null: materials.append(node.material_override)
		elif node is MeshInstance3D and node.mesh != null:
			for surface in node.mesh.get_surface_count(): materials.append(node.get_active_material(surface))
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			for surface in node.multimesh.mesh.get_surface_count(): materials.append(node.multimesh.mesh.surface_get_material(surface))
		elif node is CPUParticles3D and node.mesh != null:
			for surface in node.mesh.get_surface_count(): materials.append(node.mesh.surface_get_material(surface))
		for material in materials:
			if material is ShaderMaterial and material.shader != null: programs[str(material.shader.get_instance_id())] = material.shader.resource_path if not material.shader.resource_path.is_empty() else material.shader.resource_name
			elif material is StandardMaterial3D: originals[material.get_instance_id()] = {"name":material.resource_name,"reason":adapter.unsupported(material)}
	var site: StandardMaterial3D = game.world._survey_materials.aurora_shelf
	var mapped: ShaderMaterial = adapter.adapt(site)
	var before: Color = mapped.get_shader_parameter("albedo_color")
	game.world.apply_survey_progress({"completed_regions":{"aurora_shelf":true}})
	adapter.sync_reactions()
	checks.real_survey_response_reaches_mapped_surface = mapped.get_shader_parameter("albedo_color") == site.albedo_color and mapped.get_shader_parameter("albedo_color") != before and is_equal_approx(mapped.get_shader_parameter("emission_energy_multiplier"),site.emission_energy_multiplier)
	game.world.set_resonance_visual(1,false)
	adapter.sync_reactions()
	var resonance: StandardMaterial3D = game.world._resonance_glows[1]
	checks.real_resonance_response_reaches_mapped_surface = is_equal_approx(adapter.adapt(resonance).get_shader_parameter("emission_energy_multiplier"),resonance.emission_energy_multiplier)
	game.contact.ring_material.albedo_color.a = .23
	adapter.sync_reactions()
	checks.real_contact_ring_alpha_reaches_mapped_surface = is_equal_approx(adapter.adapt(game.contact.ring_material).get_shader_parameter("albedo_color").a,.23)
	checks.state_owners_keep_standard_resource_types = site is StandardMaterial3D and resonance is StandardMaterial3D and game.contact.ring_material is StandardMaterial3D
	checks.existing_terrain_water_biology_programs_survive = programs.values().has("res://shaders/terrain.gdshader") and programs.values().has("res://shaders/wetland_pool.gdshader") and programs.values().has("res://shaders/bioceramic.gdshader")
	checks.original_stock_fallbacks_have_explicit_reasons = originals.size() == stats.unsupported.size() and originals.size() > 0 and originals.values().all(func(value): return not value.reason.is_empty())
	var begin := Time.get_ticks_usec()
	for i in 1000: adapter.sync_reactions()
	var sync_us := Time.get_ticks_usec()-begin
	var passed := true
	for value in checks.values(): passed = passed and bool(value)
	var receipt := {"kind":"native_scene_surface_binding_response_and_CPU_loop_not_Web_speed_or_visual_proof","passed":passed,"checks":checks,"adapter":stats,"active_shader_programs":programs.values(),"remaining_stock_materials":originals.values(),"reaction_sync_1000_calls_usec":sync_us,"families_after_adaptation":game._warm_material_plan().size()}
	var file := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  "))
	file.close()
	print("RUNTIME_SURFACE_SCENE " + JSON.stringify(receipt))
	game.queue_free()
	await create_timer(.5).timeout
	quit(0 if passed else 1)
