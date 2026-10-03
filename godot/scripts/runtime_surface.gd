extends Node
## One bounded adapter for the project's stock PBR surfaces. State owners retain
## their original StandardMaterial3D references; custom shaders are never replaced.
const SURFACE = preload("res://shaders/runtime_surface.gdshaderinc")
const PARAMS := ["albedo_color","albedo_texture","roughness","roughness_texture","metallic","metallic_specular","metallic_texture","normal_enabled","normal_texture","normal_scale","ao_enabled","ao_texture","ao_light_affect","ao_on_uv2","emission_enabled","emission","emission_texture","emission_energy_multiplier","emission_on_uv2","vertex_color_use_as_albedo","vertex_color_is_srgb","uv1_scale","uv1_offset","uv1_triplanar","uv1_world_triplanar","uv1_triplanar_sharpness","uv2_scale","uv2_offset","uv2_triplanar","uv2_world_triplanar","uv2_triplanar_sharpness","alpha_scissor_threshold"]
const FEATURES := [BaseMaterial3D.FEATURE_EMISSION,BaseMaterial3D.FEATURE_NORMAL_MAPPING,BaseMaterial3D.FEATURE_AMBIENT_OCCLUSION]
const FLAGS := [BaseMaterial3D.FLAG_ALBEDO_FROM_VERTEX_COLOR,BaseMaterial3D.FLAG_SRGB_VERTEX_COLOR,BaseMaterial3D.FLAG_UV1_USE_TRIPLANAR,BaseMaterial3D.FLAG_UV2_USE_TRIPLANAR,BaseMaterial3D.FLAG_UV1_USE_WORLD_TRIPLANAR,BaseMaterial3D.FLAG_UV2_USE_WORLD_TRIPLANAR,BaseMaterial3D.FLAG_AO_ON_UV2,BaseMaterial3D.FLAG_EMISSION_ON_UV2,BaseMaterial3D.FLAG_USE_TEXTURE_REPEAT]
var _programs: Dictionary = {}
var _materials: Dictionary = {}
var _unsupported: Dictionary = {}
var _unsupported_geometry: Array[String] = []

func _ready() -> void:
	# World/creature ticks run first, so their current response reaches this draw.
	process_priority = 20

static func unsupported(source: StandardMaterial3D) -> String:
	if source.next_pass != null: return "next_pass"
	if source.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED: return "billboard"
	if source.shading_mode == BaseMaterial3D.SHADING_MODE_PER_VERTEX: return "vertex_lighting"
	if source.diffuse_mode != BaseMaterial3D.DIFFUSE_BURLEY or source.specular_mode != BaseMaterial3D.SPECULAR_SCHLICK_GGX: return "non_default_brdf"
	if source.blend_mode != BaseMaterial3D.BLEND_MODE_MIX: return "blend_mode"
	if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH or source.alpha_antialiasing_mode != BaseMaterial3D.ALPHA_ANTIALIASING_OFF: return "alpha_hash_or_coverage"
	if source.texture_filter != BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS or not source.texture_repeat: return "sampler_filter_or_clamp"
	if source.grow or source.proximity_fade_enabled or source.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED: return "geometry_or_distance_fade"
	if source.stencil_mode != BaseMaterial3D.STENCIL_MODE_DISABLED: return "stencil"
	if ProjectSettings.get_setting("rendering/lights_and_shadows/use_physical_light_units",false): return "physical_light_units"
	for feature in BaseMaterial3D.FEATURE_MAX:
		if feature not in FEATURES and source.get_feature(feature): return "feature_%d" % feature
	for flag in BaseMaterial3D.FLAG_MAX:
		if flag not in FLAGS and source.get_flag(flag): return "flag_%d" % flag
	return ""

static func channel(value: int) -> Vector4:
	if value == BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE: return Vector4(1.0/3.0,1.0/3.0,1.0/3.0,0)
	var result := Vector4.ZERO
	result[clampi(value,0,3)] = 1.0
	return result

func _shader(source: StandardMaterial3D) -> Shader:
	var key := "%d:%d:%d:%d" % [source.cull_mode,source.transparency,source.shading_mode,source.depth_draw_mode]
	if _programs.has(key): return _programs[key]
	var modes: Array[String] = ["blend_mix","diffuse_burley","specular_schlick_ggx"]
	modes.append(["cull_back","cull_front","cull_disabled"][source.cull_mode])
	modes.append(["depth_draw_opaque","depth_draw_always","depth_draw_never"][source.depth_draw_mode])
	if source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED: modes.append("unshaded")
	if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS: modes.append("depth_prepass_alpha")
	var defines := "#define SURFACE_ALPHA\n" if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED else ""
	if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: defines += "#define SURFACE_SCISSOR\n"
	if source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED: defines += "#define SURFACE_UNSHADED\n"
	var shader := Shader.new()
	shader.resource_name = "RoverSharedSurface_" + key
	shader.code = "shader_type spatial;\nrender_mode " + ",".join(modes) + ";\n" + defines + SURFACE.code
	_programs[key] = shader
	return shader

func adapt(source: Material) -> Material:
	if not source is StandardMaterial3D: return source
	var reason := unsupported(source)
	if not reason.is_empty():
		_unsupported[source.get_instance_id()] = {"name":source.resource_name,"reason":reason}
		return source
	var id := source.get_instance_id()
	if _materials.has(id): return _materials[id].material
	var material := ShaderMaterial.new()
	material.resource_name = "Runtime_" + source.resource_name
	material.set_meta("runtime_surface_source",source)
	_materials[id] = {"source":source,"material":material,"slots":[],"reaction":[]}
	source.changed.connect(_refresh.bind(id))
	source.property_list_changed.connect(_refresh.bind(id))
	_refresh(id)
	return material

func _refresh(id: int) -> void:
	if not _materials.has(id): return
	var entry: Dictionary = _materials[id]
	var source: StandardMaterial3D = entry.source
	var material: ShaderMaterial = entry.material
	var reason := unsupported(source)
	var replacement: Material = source if not reason.is_empty() else material
	if reason.is_empty():
		_unsupported.erase(id)
		material.shader = _shader(source)
		material.render_priority = source.render_priority
		for name in PARAMS: material.set_shader_parameter(name,source.get(name))
		material.set_shader_parameter("roughness_channel",channel(source.roughness_texture_channel))
		material.set_shader_parameter("metallic_channel",channel(source.metallic_texture_channel))
		material.set_shader_parameter("ao_channel",channel(source.ao_texture_channel))
		material.set_shader_parameter("emission_multiply",source.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY)
		_sync_reaction(entry)
	else:
		_unsupported[id] = {"name":source.resource_name,"reason":reason}
	for slot in entry.slots:
		if not is_instance_valid(slot.node): continue
		if slot.surface >= 0:
			var current: Material = slot.node.get_surface_override_material(slot.surface)
			if current in [material,source]: slot.node.set_surface_override_material(slot.surface,replacement)
		else:
			var current: Material = slot.node.get(slot.property)
			if current in [material,source]: slot.node.set(slot.property,replacement)

func _bind(node: GeometryInstance3D, property: String, source: Material, surface: int = -1) -> void:
	var material := adapt(source)
	if material == source: return
	_materials[source.get_instance_id()].slots.append({"node":node,"property":property,"surface":surface})
	if surface >= 0: (node as MeshInstance3D).set_surface_override_material(surface,material)
	else: node.set(property,material)

func bind_scene(scene: Node) -> void:
	for raw in scene.find_children("*","GeometryInstance3D",true,false):
		var node := raw as GeometryInstance3D
		if node.material_override != null: _bind(node,"material_override",node.material_override)
		elif node is MeshInstance3D and node.mesh != null:
			for surface in node.mesh.get_surface_count(): _bind(node,"",node.get_active_material(surface),surface)
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			# The project's committed batches use one surface; do not clone geometry.
			if node.multimesh.mesh.get_surface_count() == 1: _bind(node,"material_override",node.multimesh.mesh.surface_get_material(0))
			else: _unsupported_geometry.append(str(scene.get_path_to(node))+":multisurface_multimesh")
		elif node is CPUParticles3D and node.mesh != null:
			if node.mesh.get_surface_count() == 1: _bind(node,"material_override",node.mesh.surface_get_material(0))
			else: _unsupported_geometry.append(str(scene.get_path_to(node))+":multisurface_particles")
		if node.material_overlay != null: _bind(node,"material_overlay",node.material_overlay)

func _sync_reaction(entry: Dictionary) -> void:
	var source: StandardMaterial3D = entry.source
	var state := [source.albedo_color,source.emission,source.emission_enabled,source.emission_energy_multiplier]
	if state == entry.reaction: return
	entry.reaction = state
	var material: ShaderMaterial = entry.material
	material.set_shader_parameter("albedo_color",state[0])
	material.set_shader_parameter("emission",state[1])
	material.set_shader_parameter("emission_enabled",state[2])
	material.set_shader_parameter("emission_energy_multiplier",state[3])

func sync_reactions() -> void:
	# BaseMaterial3D's scalar setters do not emit changed in Godot 4.7.2.
	# ponytail: compare the four values this game animates; other configuration uses
	# changed/property_list_changed, expand this list if a new animation needs it.
	for entry in _materials.values(): _sync_reaction(entry)

func _process(_delta: float) -> void:
	sync_reactions()

func snapshot() -> Dictionary:
	return {"adapted_materials":_materials.size(),"shared_programs":_programs.size(),"unsupported":_unsupported.values(),"unsupported_geometry":_unsupported_geometry.duplicate()}
