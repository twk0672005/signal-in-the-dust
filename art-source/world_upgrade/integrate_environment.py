from pathlib import Path
p=Path("godot/scripts/world.gd")
s=p.read_text(encoding="utf-8-sig")
start=s.index("func _build_ecology() -> void:")
end=s.index("\nfunc _append_fault_fin",start)
replacement='''func _build_ecology() -> void:
	# One visual contract for every member; gameplay kind, positions and reactions stay stable.
	for i in 4:
		var node := Node3D.new()
		node.name = "VeyraLithovore_%02d" % i
		var z := -105.0 + i * 7.0
		var x := path_x(z) + 7.0 + sin(i * 2.1) * 2.0
		node.position = Vector3(x, height_at(x,z) + 0.35, z)
		add_child(node)
		_attach_creature_visual(node, "veyra")
		_ecology_nodes.append(node)
		_ecology_meta.append({"kind":"veyra","label":"VEYRA / 礦脈群體","phase":float(i)*1.7,"base":node.position})
	for i in 5:
		var node := Node3D.new()
		node.name = "AeralVeil_%02d" % i
		var z := -285.0 - i * 5.5
		var x := path_x(z) - 5.5 + cos(i * 1.8) * 3.0
		node.position = Vector3(x, height_at(x,z) + 5.0 + (i % 2) * 1.6, z)
		add_child(node)
		_attach_creature_visual(node, "aeral")
		_ecology_nodes.append(node)
		_ecology_meta.append({"kind":"aeral","label":"AERAL VEIL / 霧膜群","phase":float(i)*1.1,"base":node.position,"passage_index":i})
	for i in 4:
		var node := Node3D.new()
		node.name = "MorrowShell_%02d" % i
		var z := -470.0 - i * 8.0
		var x := path_x(z) + 8.0 + sin(i * 1.9) * 3.0
		node.position = Vector3(x, height_at(x,z) + 0.7, z)
		add_child(node)
		_attach_creature_visual(node, "morrow")
		_ecology_nodes.append(node)
		_ecology_meta.append({"kind":"root_choir","label":"MORROW SHELL / 孢殼群","phase":float(i)*2.0,"base":node.position})
	build_stats["detailed_major_creatures"] = _ecology_nodes.size()

func _attach_creature_visual(parent: Node3D, species: String) -> void:
	var detailed := CREATURE_VISUAL.new()
	detailed.name = "DetailedVisual"
	parent.add_child(detailed)
	detailed.configure(species)
'''
s=s[:start]+replacement+s[end:]
s=s.replace('\t\tnode.position = node.position.lerp(target, 1.0 - exp(-delta * 5.0))','\t\tvar previous_position := node.position\n\t\tnode.position = node.position.lerp(target, 1.0 - exp(-delta * 5.0))\n\t\tvar visual_motion := clampf(node.position.distance_to(previous_position) / maxf(delta, 0.001), 0.0, 1.0)')
s=s.replace('detailed.pose(_world_time+phase,alarm,pulse,1.0)','detailed.pose(_world_time+phase,alarm,pulse,visual_motion)')
s=s.replace('_environment.ambient_light_color = Color(0.48, 0.57, 0.76)','_environment.ambient_light_color = Color(0.61, 0.65, 0.73)')
s=s.replace('_environment.ambient_light_energy = 0.48','_environment.ambient_light_energy = 0.62')
s=s.replace('_environment.tonemap_exposure = 0.9','_environment.tonemap_exposure = 1.0')
s=s.replace('sun.light_color = Color(0.72, 0.81, 1.0)','sun.light_color = Color(0.84, 0.89, 1.0)')
s=s.replace('sun.light_energy = 0.85','sun.light_energy = 1.05')
s=s.replace('\tadd_child(sun)\n','''	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.name = "DistantWarmHorizon"
	rim.rotation_degrees = Vector3(-18.0, 135.0, 0.0)
	rim.light_color = Color(0.91, 0.66, 0.45)
	rim.light_energy = 0.18
	rim.shadow_enabled = false
	add_child(rim)
''',1)
s=s.replace('\t_terrain_material.shader = TERRAIN_SHADER','\t_terrain_material.shader = TERRAIN_SHADER\n\t_terrain_material.set_shader_parameter("wetland_center", _wetland_center())')
s=s.replace('\tvar rock_material := _passage_material(Color("4e5d58"))','\t_build_shore_transition(center)\n\tvar rock_material := _passage_material(Color("4e5d58"))')
needle='func _build_wetland_reader(material: StandardMaterial3D) -> void:'
shore='''func _build_shore_transition(center: Vector2) -> void:
	# Terrain-conforming sediment apron, with an irregular mineral tide line.
	# This shares height_at and the water origin, so the lip cannot float above the bank.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 96
	for ring in 6:
		for j in SEGMENTS:
			var points: Array[Vector3] = []
			var colors: Array[Color] = []
			for corner in [Vector2(j,ring),Vector2(j+1,ring),Vector2(j,ring+1),Vector2(j+1,ring+1)]:
				var a := corner.x / SEGMENTS * TAU
				var t := corner.y / 6.0
				var radius := lerpf(4.0,8.7,t) + sin(a*3.0)*.18 + sin(a*7.0)*.10
				var x := center.x + cos(a)*radius
				var z := center.y + sin(a)*radius
				points.append(Vector3(x,height_at(x,z)+.025,z))
				var color := Color("233c34").lerp(Color("627167"),smoothstep(.2,1.0,t))
				colors.append(color)
			for index in [0,2,1,1,2,3]:
				st.set_color(colors[index])
				st.set_uv(Vector2(points[index].x,points[index].z)*.42)
				st.add_vertex(points[index])
	st.generate_normals()
	st.generate_tangents()
	var shore := MeshInstance3D.new()
	shore.name = "TerrainConformingWetSediment"
	shore.mesh = st.commit()
	var material := _wetland_ground_material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.roughness = .40
	shore.material_override = material
	shore.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shore)

'''
s=s.replace(needle,shore+needle)
p.write_text(s,encoding="utf-8")

