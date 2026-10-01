extends SceneTree
## Native scene/save readback. This does not render the Web warmup.
const Save = preload("res://scripts/expedition_save.gd")
var output := ""
var checks: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var userdata := ProjectSettings.globalize_path("user://").replace("\\","/")
	checks.preferences_are_isolated = userdata.begins_with(output.replace("\\","/").get_base_dir().path_join("native-userdata")+"/")
	var game: Node3D = load("res://main.tscn").instantiate()
	game.save_path = output.path_join("isolated-startup-save.json")
	Save.clear(game.save_path)
	root.add_child(game)
	await physics_frame
	await physics_frame
	checks.native_boot_ready_without_fabricated_render = game.ready_for_play and game.phase == "menu" and not game._web_boot.first_frame_ready
	var family_modes: Array = []
	for family in game._warm_material_plan():
		var material: Material = family.material
		var shader_name := material.get_class() if material != null else "default"
		if material is ShaderMaterial and material.shader != null:
			shader_name = material.shader.resource_path if not material.shader.resource_path.is_empty() else material.shader.resource_name
		family_modes.append({"shader":shader_name,"mesh":family.mesh,"instanced":family.instanced,"omni":family.omni})
	checks.real_scene_has_material_and_instanced_coverage = family_modes.size() > 0 and family_modes.any(func(family): return family.instanced)
	checks.new_expedition_still_uses_existing_arrival = game.start_expedition() and game.phase == "arrival" and not game.rover.driving
	game._set_phase("exploring")
	game.rover.set_driving_enabled(false)
	game.elapsed = 123.4
	game.rover.distance_travelled = 86.2
	game.observed_ecology = {"veyra":true}
	game.transmit_count = 2
	checks.fixture_save = game.save_expedition()
	var original: Dictionary = Save.read(game.save_path)
	var road_position: Vector3 = game.rover.position
	checks.unchanged_road_resume_is_exact = game.load_expedition() and game.rover.position == road_position
	game.rover.set_driving_enabled(false)
	var migrations: Array = []
	var methods := ["legacy_height_at","previous_height_at","revision_3_height_at","revision_4_height_at","revision_5_height_at"]
	if game.world.has_method("revision_6_height_at"): methods.append("revision_6_height_at")
	for method in methods:
		var tried: Array = []
		var restored_revision := false
		if game.world.has_method(method):
			for z in [125.0,-100.0,-275.0,-495.0]:
				for x in [-70.0,70.0,-45.0,45.0]:
					var old_y: float = game.world.call(method,x,z)
					var current: float = game.world.height_at(x,z)
					if absf(old_y-current) <= .1: continue
					var old_save := original.duplicate(true)
					old_save.position = {"x":x,"y":old_y+.08,"z":z}
					Save.clear(game.save_path)
					if not Save.write(game.save_path,old_save): continue
					var bytes := FileAccess.get_file_as_bytes(game.save_path)
					var restored: bool = game.load_expedition()
					game.rover.set_driving_enabled(false)
					var local_restore := Vector2(game.rover.position.x-x,game.rover.position.z-z).length() <= 6.1
					var progress_kept: bool = is_equal_approx(game.elapsed,123.4) and is_equal_approx(game.rover.distance_travelled,86.2) and game.observed_ecology.get("veyra",false) and game.transmit_count == 2
					var bytes_kept := FileAccess.get_file_as_bytes(game.save_path) == bytes
					var free: bool = game._resume_space_clear(game.rover.position,game.rover.heading)
					tried.append({"old":[x,old_y,z],"current_height":current,"restored":restored,"local":local_restore,"progress":progress_kept,"bytes":bytes_kept,"free":free,"position":str(game.rover.position)})
					restored_revision = restored and local_restore and progress_kept and bytes_kept and free
					if restored_revision: break
				if restored_revision: break
		checks[method+"_resume_keeps_progress_bytes_and_safe_position"] = restored_revision
		migrations.append({"method":method,"trials":tried})
	var position_before: Vector3 = game.rover.position
	var invalid := original.duplicate(true)
	invalid.position = {"x":position_before.x,"y":game.world.height_at(position_before.x,position_before.z)+80.0,"z":position_before.z}
	Save.clear(game.save_path)
	Save.write(game.save_path,invalid)
	checks.unrecognized_height_preserves_current_progress = not game.load_expedition() and game.rover.position == position_before and is_equal_approx(game.elapsed,123.4) and game.transmit_count == 2
	var passed := true
	for result in checks.values(): passed = passed and bool(result)
	var receipt := {"kind":"native_scene_material_inventory_and_historical_save_recovery_not_Web_or_GPU_proof","passed":passed,"checks":checks,"userdata":userdata,"terrain_revision":game.world.build_stats.get("terrain_revision"),"material_families":family_modes,"migrations":migrations}
	var file := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  "))
	file.close()
	print("STARTUP_SCENE " + JSON.stringify(receipt))
	game.queue_free()
	await create_timer(.5).timeout
	quit(0 if passed else 1)
