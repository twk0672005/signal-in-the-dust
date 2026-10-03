extends SceneTree
const Surface = preload("res://scripts/runtime_surface.gd")
const Main = preload("res://scripts/main.gd")

func _initialize() -> void:
	var checks := {}
	var adapter := Surface.new()
	var unlit := StandardMaterial3D.new()
	unlit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	unlit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	unlit.emission_enabled = true
	unlit.emission = Color(.2,.3,.4)
	unlit.emission_energy_multiplier = 2.4
	unlit.uv1_triplanar = true
	var mapped := adapter.adapt(unlit) as ShaderMaterial
	checks.unshaded_pbr_is_excluded_by_explicit_compile_define = mapped.shader.code.contains("#define SURFACE_UNSHADED") and mapped.shader.code.count("#ifndef SURFACE_UNSHADED") == 2
	checks.unshaded_alpha_emission_and_texture_projection_are_retained = mapped.shader.code.contains("#define SURFACE_ALPHA") and mapped.shader.code.contains("EMISSION =") and mapped.get_shader_parameter("uv1_triplanar") and mapped.get_shader_parameter("emission") == unlit.emission and is_equal_approx(mapped.get_shader_parameter("emission_energy_multiplier"),2.4)
	checks.unshaded_shader_parses = mapped.shader.get_shader_uniform_list().size() >= 30
	var lit := StandardMaterial3D.new()
	lit.normal_enabled = true
	var lit_map := adapter.adapt(lit) as ShaderMaterial
	checks.shaded_pbr_does_not_get_unlit_define = not lit_map.shader.code.contains("#define SURFACE_UNSHADED") and lit_map.get_shader_parameter("normal_enabled")
	checks.shaded_shader_parses = lit_map.shader.get_shader_uniform_list().size() >= 30
	var game := Main.new()
	var plan: Array[Dictionary] = [{"material":mapped,"mesh":true,"instanced":false,"omni":true},{"material":lit_map,"mesh":false,"instanced":true,"omni":false}]
	var inventory: Array = game._warm_material_inventory(plan)
	checks.inventory_binds_actual_program_and_work = inventory.size() == 2 and inventory[0].shader == mapped.shader.resource_name and inventory[0].shader_sha256 == mapped.shader.code.sha256_text() and inventory[0].sample_submissions == 3 and inventory[1].sample_submissions == 2
	checks.inventory_does_not_claim_readiness_or_a_rendered_frame = not game.ready_for_play and not game._web_boot.first_frame_ready
	checks.native_source_extraction_is_not_public_in_the_pinned_runtime = not RenderingServer.has_method("shader_get_native_source_code")
	var passed := checks.values().all(func(value): return bool(value))
	print("STARTUP_COMPILE " + JSON.stringify({"kind":"source_shader_semantics_inventory_and_runtime_API_check_not_GPU_latency_proof","passed":passed,"checks":checks,"inventory":inventory}))
	game.free()
	adapter.free()
	quit(0 if passed else 1)
