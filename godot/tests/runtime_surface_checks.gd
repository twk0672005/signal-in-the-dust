extends SceneTree
const Surface = preload("res://scripts/runtime_surface.gd")
var checks: Dictionary = {}

func _initialize() -> void:
	var adapter := Surface.new()
	var source := StandardMaterial3D.new()
	var image := Image.create(4,4,false,Image.FORMAT_RGBA8)
	image.fill(Color(.2,.4,.6,.8))
	var texture := ImageTexture.create_from_image(image)
	source.albedo_texture = texture
	source.normal_enabled = true
	source.normal_texture = texture
	source.roughness_texture = texture
	source.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
	source.metallic_texture = texture
	source.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	source.ao_enabled = true
	source.ao_texture = texture
	source.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	source.emission_enabled = true
	source.emission_texture = texture
	source.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	source.uv1_triplanar = true
	source.uv1_world_triplanar = true
	source.uv1_scale = Vector3(.3,.4,.5)
	source.uv1_offset = Vector3(1,2,3)
	source.uv1_triplanar_sharpness = 4.0
	source.vertex_color_use_as_albedo = true
	source.vertex_color_is_srgb = true
	var material := adapter.adapt(source) as ShaderMaterial
	checks.used_pbr_features_are_supported = material != null
	checks.texture_objects_are_retained = material.get_shader_parameter("albedo_texture") == texture and material.get_shader_parameter("normal_texture") == texture and material.get_shader_parameter("roughness_texture") == texture and material.get_shader_parameter("metallic_texture") == texture and material.get_shader_parameter("ao_texture") == texture and material.get_shader_parameter("emission_texture") == texture
	checks.packed_texture_channels_are_retained = material.get_shader_parameter("roughness_channel") == Vector4(0,0,0,1) and material.get_shader_parameter("metallic_channel") == Vector4(0,0,1,0) and material.get_shader_parameter("ao_channel") == Vector4(0,1,0,0)
	checks.uv_world_triplanar_and_emission_operator_retained = material.get_shader_parameter("uv1_world_triplanar") and material.get_shader_parameter("uv1_scale") == source.uv1_scale and material.get_shader_parameter("uv1_offset") == source.uv1_offset and material.get_shader_parameter("uv1_triplanar_sharpness") == 4.0 and material.get_shader_parameter("emission_multiply")
	checks.source_material_is_retained_without_replacing_its_type = material.get_meta("runtime_surface_source") == source and source is StandardMaterial3D and source.albedo_texture == texture
	var plain := StandardMaterial3D.new()
	var plain_surface := adapter.adapt(plain) as ShaderMaterial
	checks.tint_maps_and_triplanar_share_one_program = plain_surface.shader == material.shader
	checks.common_shader_parses_uniforms = material.shader.get_shader_uniform_list().size() >= 30
	source.albedo_color = Color.RED
	source.emission = Color.GREEN
	source.emission_energy_multiplier = 1.7
	adapter.sync_reactions()
	checks.unsignalled_color_and_emission_updates_are_visible = material.get_shader_parameter("albedo_color") == Color.RED and material.get_shader_parameter("emission") == Color.GREEN and is_equal_approx(material.get_shader_parameter("emission_energy_multiplier"),1.7)
	source.roughness = .73
	source.normal_scale = .42
	source.emit_changed()
	checks.resource_changed_refreshes_surface_configuration = is_equal_approx(material.get_shader_parameter("roughness"),.73) and is_equal_approx(material.get_shader_parameter("normal_scale"),.42)
	var replacement := ImageTexture.create_from_image(image)
	source.albedo_texture = replacement
	checks.texture_property_signal_refreshes_mapping = material.get_shader_parameter("albedo_texture") == replacement
	var unsupported := StandardMaterial3D.new()
	unsupported.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	checks.billboard_stays_original = adapter.adapt(unsupported) == unsupported
	unsupported.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	unsupported.detail_enabled = true
	checks.advanced_features_stay_original = adapter.adapt(unsupported) == unsupported
	var custom := ShaderMaterial.new()
	custom.shader = load("res://shaders/bioceramic.gdshader")
	checks.biological_and_other_custom_programs_are_untouched = adapter.adapt(custom) == custom
	var scene := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_override = source
	scene.add_child(mesh)
	var multimesh := MultiMeshInstance3D.new()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = BoxMesh.new()
	batch.mesh.surface_set_material(0,plain)
	batch.instance_count = 1
	multimesh.multimesh = batch
	scene.add_child(multimesh)
	adapter.bind_scene(scene)
	checks.scene_slots_use_shared_surfaces_without_cloning_geometry = mesh.material_override == material and multimesh.material_override == plain_surface and batch.mesh.surface_get_material(0) == plain
	source.detail_enabled = true
	source.emit_changed()
	checks.new_unsupported_configuration_restores_original_slot = mesh.material_override == source
	source.detail_enabled = false
	source.cull_mode = BaseMaterial3D.CULL_DISABLED
	source.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	source.alpha_scissor_threshold = .37
	source.emit_changed()
	checks.culling_alpha_scissor_semantics_remain_distinct = mesh.material_override == material and material.shader != plain_surface.shader and material.shader.code.contains("cull_disabled") and material.shader.code.contains("#define SURFACE_SCISSOR") and is_equal_approx(material.get_shader_parameter("alpha_scissor_threshold"),.37)
	checks.alpha_shader_parses_uniforms = material.shader.get_shader_uniform_list().size() >= 30
	checks.grayscale_channel_preserved = Surface.channel(BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE).is_equal_approx(Vector4(1.0/3.0,1.0/3.0,1.0/3.0,0))
	var passed := true
	for result in checks.values(): passed = passed and bool(result)
	print("RUNTIME_SURFACE_CHECKS " + JSON.stringify({"kind":"native_resource_bindings_and_shader_syntax_not_visual_or_GPU_proof","passed":passed,"checks":checks,"adapter":adapter.snapshot()}))
	scene.free()
	adapter.free()
	quit(0 if passed else 1)
