extends SceneTree
## Actual glTF decode plus source-bound colour semantics; root owns rendered A/B.
const Surface = preload("res://scripts/runtime_surface.gd")
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.get_base_dir().path_join("raw-glb-colors.json")))
	var checks := {"fixture_matches_actual_asset":FileAccess.get_sha256(fixture.asset)==fixture.sha256}
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	checks.actual_gltf_decodes = document.append_from_file(fixture.asset,state)==OK
	if not checks.actual_gltf_decodes:
		print("RUNTIME_SURFACE_COLOR " + JSON.stringify({"passed":false,"checks":checks}))
		quit(1); return
	var mesh: ImporterMesh = state.get_meshes()[0].get_mesh()
	var colors: PackedColorArray = mesh.get_surface_arrays(0)[Mesh.ARRAY_COLOR]
	var actual: Color = colors[0]
	var raw: Array = fixture.samples[0].rawColor0
	var exported := Color(raw[0],raw[1],raw[2],raw[3])
	checks.imported_color_keeps_linear_gltf_values = actual.is_equal_approx(exported)
	var source := state.get_materials()[0] as StandardMaterial3D
	checks.import_does_not_mark_linear_data_as_srgb = not source.vertex_color_is_srgb
	source.vertex_color_use_as_albedo = true
	var adapter := Surface.new()
	var mapped := adapter.adapt(source) as ShaderMaterial
	checks.adapter_retains_linear_colour_flag = not mapped.get_shader_parameter("vertex_color_is_srgb") and mapped.get_shader_parameter("vertex_color_use_as_albedo")
	checks.shader_corrects_only_compatibility_linear_input = mapped.shader.code.contains("if (OUTPUT_IS_SRGB && !vertex_color_is_srgb) ALBEDO = srgb_vertex_color(linear_vertex_color(ALBEDO) * COLOR.rgb);")
	checks.alpha_multiplies_without_transfer_conversion = mapped.shader.code.contains("color.a *= COLOR.a;") and mapped.shader.code.contains("ALPHA = albedo_color.a * color.a;")
	checks.fragment_still_parses_pbr_uniforms = mapped.shader.get_shader_uniform_list().size() >= 30
	# glTF COLOR_0 is a LINEAR multiplier; test against the actual exported palette.
	var texture_tint := Color(.52,.61,.73,.37)
	var desired := texture_tint.srgb_to_linear() * actual
	var corrected_albedo := desired.linear_to_srgb()
	var renderer_output := gles_linear(corrected_albedo)
	var old_output := gles_linear(texture_tint * actual)
	checks.linear_multiplier_reaches_renderer_without_second_decode = Vector3(renderer_output.r-desired.r,renderer_output.g-desired.g,renderer_output.b-desired.b).length() < .003
	checks.actual_old_palette_path_demonstrates_darkening = old_output.r < desired.r*.6 and old_output.g < desired.g*.6
	checks.alpha_stays_exact = is_equal_approx(corrected_albedo.a,texture_tint.a*actual.a)
	source.vertex_color_is_srgb = true
	source.emit_changed()
	checks.explicit_srgb_material_keeps_its_flag = mapped.get_shader_parameter("vertex_color_is_srgb")
	var passed := checks.values().all(func(value): return bool(value))
	var receipt := {"kind":"CPU_actual_gltf_decode_and_source_bound_linear_colour_contract_not_rendered_proof","passed":passed,"checks":checks,"asset_sha256":fixture.sha256,"actual_linear_color":str(actual),"authored_display_srgb":str(actual.linear_to_srgb()),"reference_linear_lit_input":str(desired),"corrected_gles_linear":str(renderer_output),"legacy_gles_linear":str(old_output)}
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  ")); file.close()
	print("RUNTIME_SURFACE_COLOR " + JSON.stringify(receipt))
	adapter.free()
	quit(0 if passed else 1)

func gles_linear(value: Color) -> Color:
	# Pinned GLES3 tonemap_inc.glsl transfer approximation after fragment().
	return Color(value.r*(value.r*(value.r*.305306011+.682171111)+.012522878),value.g*(value.g*(value.g*.305306011+.682171111)+.012522878),value.b*(value.b*(value.b*.305306011+.682171111)+.012522878),value.a)
