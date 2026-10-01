extends SceneTree
## CPU-only preparation contract; the exported Web/GPU run remains a separate gate.
const Main = preload("res://scripts/main.gd")
var checks: Dictionary = {}

class TerrainFixture extends Node3D:
	var heights := [10.0,20.0,30.0,40.0,50.0,60.0]
	var current := 70.0
	var changed := true
	func height_at(_x: float, _z: float) -> float: return current
	func environment_terrain_changed_at(_x: float, _z: float) -> bool: return changed
	func legacy_height_at(_x: float, _z: float) -> float: return heights[0]
	func previous_height_at(_x: float, _z: float) -> float: return heights[1]
	func revision_3_height_at(_x: float, _z: float) -> float: return heights[2]
	func revision_4_height_at(_x: float, _z: float) -> float: return heights[3]
	func revision_5_height_at(_x: float, _z: float) -> float: return heights[4]
	func revision_6_height_at(_x: float, _z: float) -> float: return heights[5]

func _initialize() -> void:
	var game := Main.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; void fragment(){ ALBEDO=vec3(0.5); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	var alternate := ShaderMaterial.new()
	alternate.shader = shader
	checks.shared_shader_uniforms_do_not_duplicate_work = game._warm_material_key(material) == game._warm_material_key(alternate)
	var plain := StandardMaterial3D.new()
	var tint := StandardMaterial3D.new()
	tint.albedo_color = Color.RED
	checks.tints_do_not_duplicate_work = game._warm_material_key(plain) == game._warm_material_key(tint)
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	checks.actual_shader_features_stay_distinct = game._warm_material_key(plain) != game._warm_material_key(tint)
	var multi_surface := ArrayMesh.new()
	var box := BoxMesh.new()
	for item in [material,plain]:
		multi_surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0))
		multi_surface.surface_set_material(multi_surface.get_surface_count()-1,item)
	var mesh := MeshInstance3D.new()
	mesh.mesh = multi_surface
	game.add_child(mesh)
	var batch := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = 1
	box.material = alternate
	batch.multimesh = multimesh
	game.add_child(batch)
	var dust := CPUParticles3D.new()
	dust.mesh = box
	game.add_child(dust)
	var plan := game._warm_material_plan()
	checks.all_surfaces_included_without_tint_duplicates = plan.size() == 2
	var shader_family: Dictionary = {}
	for family in plan:
		if family.material is ShaderMaterial: shader_family = family
	checks.mesh_instancing_and_particles_cover_one_family = shader_family.get("mesh",false) and shader_family.get("instanced",false)
	mesh.material_override = material
	checks.override_replaces_inactive_surface_work = game._warm_material_plan().size() == 1
	mesh.material_overlay = plain
	plain.next_pass = tint
	checks.overlays_and_next_passes_are_prepared = game._warm_material_plan().size() == 3
	var regular := game._warm_proxy(false) as MeshInstance3D
	var instanced := game._warm_proxy(true) as MultiMeshInstance3D
	checks.representatives_use_bounded_geometry = regular.mesh.get_faces().size() == 36 and instanced.multimesh.instance_count == 1 and instanced.multimesh.mesh.get_faces().size() == 36
	checks.instance_data_layout_is_retained = instanced.multimesh.use_colors and instanced.multimesh.use_custom_data and instanced.multimesh.transform_format == MultiMesh.TRANSFORM_3D
	checks.samples_start_without_shadow_submission = regular.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and instanced.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game._set_boot_preparation("world")
	checks.world_work_has_no_guessed_total = game._boot_preparation == {"version":1,"phase":"world"}
	game._set_boot_preparation("materials",1,3)
	checks.material_progress_uses_completed_known_work = game._boot_preparation == {"version":1,"phase":"materials","completed":1,"total":3}
	game._set_boot_preparation("first-view",7,7)
	checks.first_view_count_is_distinct_from_play_readiness = game._boot_preparation.completed == 7 and not game.ready_for_play and not game._web_boot.first_frame_ready
	game._set_boot_preparation("unsupported",1,1)
	checks.unsupported_preparation_phase_is_ignored = game._boot_preparation.phase == "first-view"
	game._set_boot_preparation("world",4,3)
	checks.inconsistent_counts_are_omitted = not game._boot_preparation.has("completed") and not game._boot_preparation.has("total")
	var terrain := TerrainFixture.new()
	game.world = terrain
	for revision in 6:
		var state: Dictionary = game._resume_terrain(Vector3(0,terrain.heights[revision]+.08,0))
		checks["revision_%d_height_accepted_only_in_changed_surface" % (revision+1)] = state.valid and state.changed and state.height == terrain.current
	checks.current_height_still_accepted = game._resume_terrain(Vector3(0,terrain.current+.08,0)).valid
	checks.unrecognized_height_rejected = not game._resume_terrain(Vector3(0,95,0)).valid
	terrain.changed = false
	checks.historical_height_does_not_relax_unchanged_area = not game._resume_terrain(Vector3(0,terrain.heights[4]+.08,0)).valid
	terrain.changed = true
	terrain.heights.fill(terrain.current)
	checks.unchanged_road_within_revision_envelope_keeps_exact_height = not game._resume_terrain(Vector3(0,terrain.current+.08,0)).changed
	var passed := true
	for result in checks.values(): passed = passed and bool(result)
	print("STARTUP_PREPARATION " + JSON.stringify({"kind":"CPU_material_coverage_and_progress_not_Web_or_GPU_proof","passed":passed,"checks":checks}))
	regular.free()
	instanced.free()
	terrain.free()
	game.free()
	quit(0 if passed else 1)
