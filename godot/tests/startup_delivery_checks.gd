extends SceneTree
const Main = preload("res://scripts/main.gd")
var checks: Dictionary = {}
var output := ""

class StartupFixture extends Main:
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass

class WorldFixture extends Node3D:
	var _ecology_nodes: Array[Node3D] = []
	var low := false
	func set_low_quality(value: bool) -> void: low = value

class RoverFixture extends CharacterBody3D:
	var reduced_motion := false
	var low := false
	func set_low_quality(value: bool) -> void: low = value

class AudioFixture extends Node:
	var mix := 0.0
	func set_mix(value: float) -> void: mix = value

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func run() -> void:
	var game := StartupFixture.new()
	root.add_child(game)
	game.world = WorldFixture.new()
	game.rover = RoverFixture.new()
	game.audio = AudioFixture.new()
	for child in [game.world,game.rover,game.audio]: game.add_child(child)
	var light := OmniLight3D.new()
	light.omni_range = 10.0
	light.light_cull_mask = 1
	game.add_child(light)
	var material := StandardMaterial3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_override = material
	game.add_child(mesh)
	mesh.position.x = 100.0
	checks.stationary_distant_family_omits_unused_omni_variants = not game._warm_material_plan()[0].omni
	mesh.position.x = 10.4
	checks.light_intersection_uses_surface_bounds_not_only_origin = game._warm_material_plan()[0].omni
	mesh.position = Vector3(9,9,0)
	checks.renderer_range_cube_corners_keep_the_omni_specialization = game._warm_material_plan()[0].omni
	mesh.position = Vector3(10.4,0,0)
	mesh.layers = 2
	checks.light_layer_exclusions_are_retained = not game._warm_material_plan()[0].omni
	mesh.layers = 1
	mesh.position.x = 100.0
	mesh.extra_cull_margin = 90.0
	checks.authored_cull_margin_retains_light_coverage = game._warm_material_plan()[0].omni
	mesh.extra_cull_margin = 0.0
	mesh.scale = Vector3(10,1,1)
	mesh.extra_cull_margin = 9.0
	checks.scaled_mesh_cull_margin_matches_renderer_pairing = game._warm_material_plan()[0].omni
	mesh.scale = Vector3.ONE
	mesh.extra_cull_margin = 0.0
	mesh.custom_aabb = AABB(Vector3(-100,-1,-1),Vector3(2,2,2))
	checks.authored_custom_bounds_retain_light_coverage = game._warm_material_plan()[0].omni
	mesh.custom_aabb = AABB()
	game.remove_child(mesh)
	game.rover.add_child(mesh)
	checks.moving_rover_keeps_variants_before_it_enters_light_range = game._warm_material_plan()[0].omni
	game.rover.remove_child(mesh)
	game.add_child(mesh)
	var actor := Node3D.new()
	game.world.add_child(actor)
	game.world._ecology_nodes.append(actor)
	game.remove_child(mesh)
	actor.add_child(mesh)
	checks.moving_ecology_keeps_future_light_variants = game._warm_material_plan()[0].omni
	actor.remove_child(mesh)
	game.add_child(mesh)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh.mesh
	batch.material_override = material
	game.add_child(batch)
	checks.unknown_batch_bounds_keep_conservative_shared_family_coverage = game._warm_material_plan()[0].omni
	game.remove_child(batch)
	batch.free()
	var sibling := MeshInstance3D.new()
	sibling.mesh = mesh.mesh
	sibling.material_override = material
	game.add_child(sibling)
	checks.any_lit_surface_keeps_variants_for_the_whole_material_family = game._warm_material_plan().size() == 1 and game._warm_material_plan()[0].omni
	game.remove_child(sibling)
	sibling.free()
	game.remove_child(light)
	light.free()
	checks.no_authored_omni_means_no_omni_variants = not game._warm_material_plan()[0].omni
	game._on_settings({"low_quality":false,"reduced_motion":true,"volume":.35})
	checks.standard_settings_select_supported_2x_msaa = root.msaa_3d == Viewport.MSAA_2X and not game.world.low and not game.rover.low
	checks.motion_and_audio_preferences_survive_display_changes = game.rover.reduced_motion and is_equal_approx(game.audio.mix,.35)
	game._on_settings({"low_quality":true,"reduced_motion":false,"volume":.5})
	checks.low_settings_remove_msaa_and_use_existing_world_rover_fallbacks = root.msaa_3d == Viewport.MSAA_DISABLED and game.world.low and game.rover.low
	checks.display_preparation_does_not_start_gameplay_or_claim_a_frame = game.phase == "menu" and not game.ready_for_play and game._web_boot.request_id.is_empty() and not game._web_boot.first_frame_ready and game._read_web_launch_request().is_empty()
	var passed := checks.values().all(func(value): return bool(value))
	var receipt := {"kind":"CPU_light_coverage_and_display_settings_not_GPU_Web_or_timing_proof","passed":passed,"checks":checks,"userdata":ProjectSettings.globalize_path("user://")}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(receipt,"  "))
		file.close()
	print("STARTUP_DELIVERY " + JSON.stringify(receipt))
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
