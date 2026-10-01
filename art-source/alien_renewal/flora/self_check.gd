extends SceneTree
var output := ""
var checks: Dictionary={}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2);return
	run.call_deferred()

func run() -> void:
	var world: Node3D=load("res://scripts/world.gd").new()
	world.staged_boot=true
	root.add_child(world)
	world.staged_boot=false
	world._prepare_landform_clearances()
	world.set_process(false)
	var habitat: Node3D=load("res://scripts/living_habitat.gd").new()
	world.add_child(habitat)
	var started := Time.get_ticks_usec()
	await habitat.build(world)
	var build_ms := (Time.get_ticks_usec()-started)/1000.0
	checks.all_four_regions=habitat.source_meshes.size()==17
	checks.two_shared_opaque_materials=habitat._kit_materials.size()==2
	var opaque := true
	var reusable_triangles := 0
	var material_names: Array=[]
	for name in habitat._kit_materials:
		var mat: StandardMaterial3D=habitat._kit_materials[name]
		opaque=opaque and mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_texture!=null and mat.roughness_texture!=null and mat.normal_texture!=null
		material_names.append(name)
	for name in habitat.source_meshes:
		if name=="cups": continue
		for part: Dictionary in habitat.source_meshes[name]: reusable_triangles+=part.mesh.get_faces().size()/3
	checks.material_texture_maps_present=opaque
	var palettes: Dictionary={}
	for region: String in habitat.REGIONS:
		for part: Dictionary in habitat.source_meshes[region+"_crown"]:
			if part.collision:continue
			var colours: PackedColorArray=part.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			if not colours.is_empty():palettes[region]=colours[0]
	checks.authored_vertex_palettes_exported=palettes.size()==4 and palettes.aurora.r>palettes.veil.r and palettes.ember.r>palettes.ember.b and palettes.pale.r>palettes.pale.g and palettes.aurora!=Color.WHITE
	checks.reusable_kit_under_30000_triangles=reusable_triangles<30000
	checks.baked_path_has_no_runtime_topology=not bool(world.build_stats.get("flora_baked_layout",false)) or world.build_stats.get("flora_runtime_topology_triangles",-1)==0
	checks.connected_ground_beds=int(world.build_stats.get("connected_ground_beds",0))>=40
	var margin_contact := habitat._shore_mesh!=null
	if habitat._shore_mesh!=null:
		var margin_vertices: PackedVector3Array=habitat._shore_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for point in margin_vertices: margin_contact=margin_contact and absf(point.y-world.height_at(point.x,point.z)-.013)<.001
	checks.shore_sediment_follows_authoritative_height=margin_contact
	var short_margin_edges := habitat._shore_mesh!=null
	if habitat._shore_mesh!=null:
		var margin_faces: PackedVector3Array=habitat._shore_mesh.get_faces()
		for index in range(0,margin_faces.size(),3):
			for pair in [Vector2i(0,1),Vector2i(1,2),Vector2i(2,0)]:
				var a := margin_faces[index+pair.x]
				var b := margin_faces[index+pair.y]
				short_margin_edges=short_margin_edges and Vector2(a.x-b.x,a.z-b.z).length()<=2.4
	checks.shore_margin_has_no_long_apron_edges=short_margin_edges
	checks.reusable_floor_tufts_under_120_triangles=true
	for region: String in habitat.REGIONS:
		var floor_triangles := 0
		for part: Dictionary in habitat.source_meshes[region+"_floor"]:floor_triangles+=part.mesh.get_faces().size()/3
		checks.reusable_floor_tufts_under_120_triangles=checks.reusable_floor_tufts_under_120_triangles and floor_triangles<=120
	var max_gap := -INF
	var triangles := 0
	var instance_count := 0
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	for group: Dictionary in habitat._layout_groups:
		instance_count+=group.poses.size()
		digest.update(var_to_bytes(group.family))
		for pose: Transform3D in group.poses:
			digest.update(var_to_bytes(pose))
			# Populate exact mesh support cache also on the baked path.
			habitat._seat_transform(group.family,pose)
			for point: Vector3 in habitat._support_vertices[group.family]:
				var placed := pose*point
				max_gap=maxf(max_gap,placed.y-world.height_at(placed.x,placed.z))
		for part: Dictionary in habitat.source_meshes[group.family]: triangles+=part.mesh.get_faces().size()/3*group.poses.size()
	checks.support_vertices_do_not_float=max_gap<=-.020
	checks.all_instances_under_1400000_triangles=triangles<1400000
	checks.four_authored_sightline_groups=true
	for id in 4: checks.four_authored_sightline_groups=checks.four_authored_sightline_groups and int(world.build_stats.get("sightline_habitat_"+str(id)+"_structures",0))>=3
	var road_clear := true
	var approach_clear := true
	var minimum_road := INF
	var rays := 0
	var missed_rays: Array=[]
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	for record: Dictionary in habitat.placements:
		var pose: Transform3D=record.transform
		var faces: PackedVector3Array=record.shape.get_faces()
		for local in faces:
			var placed := pose*local
			if placed.y>world.height_at(placed.x,placed.z)+3.0: continue
			var road_distance := absf(placed.x-world.path_x(placed.z))
			minimum_road=minf(minimum_road,road_distance)
			road_clear=road_clear and road_distance>=5.0
			approach_clear=approach_clear and world.environment_access_distance(placed.x,placed.z)>=6.0
		var ray_hit := false
		for offset in range(0,faces.size(),3):
			if offset+2>=faces.size():break
			var a: Vector3=pose*faces[offset]
			var b: Vector3=pose*faces[offset+1]
			var c: Vector3=pose*faces[offset+2]
			var center := (a+b+c)/3
			if center.y<world.height_at(center.x,center.z)+.05:continue
			var normal := (b-a).cross(c-a).normalized()
			var query := PhysicsRayQueryParameters3D.create(center+normal*.10,center-normal*.10,128)
			if space.intersect_ray(query).get("collider")==record.body:ray_hit=true;break
		if ray_hit:rays+=1
		else:missed_rays.append({"family":record.family,"origin":str(pose.origin)})
	checks.low_solid_vertices_clear_10m_road=road_clear
	checks.low_solid_vertices_clear_activity_approaches=approach_clear
	checks.actual_static_shapes_hit=not habitat.placements.is_empty() and rays==habitat.placements.size()
	checks.microfauna_preserved=is_instance_valid(habitat.microfauna) and habitat.microfauna.animals.size()==28
	var old_clock: float=habitat.clock
	habitat.tick(.25,true)
	checks.paused_wind_clock_preserved=habitat.clock==old_clock
	habitat.tick(.25,false)
	checks.unpaused_wind_clock_advances=habitat.clock>old_clock
	habitat.set_low_quality(true)
	var low_safe := true
	for batch: Dictionary in habitat.batches:
		if batch.landmark:low_safe=low_safe and batch.node.multimesh.visible_instance_count==-1
	checks.low_keeps_all_solid_instances=low_safe
	habitat.set_low_quality(false)
	habitat.set_paused(true)
	habitat.set_paused(false)
	var layout := Resource.new()
	layout.set_meta("terrain_revision",world.TERRAIN_REVISION)
	layout.set_meta("flora_revision",habitat.FLORA_REVISION)
	layout.set_meta("groups",habitat._layout_groups)
	layout.set_meta("stats",habitat._layout_stats)
	layout.set_meta("shore_mesh",habitat._shore_mesh)
	if "--flora-author-layout" in OS.get_cmdline_user_args():
		checks.layout_saved=ResourceSaver.save(layout,"res://assets/alien_flora/habitat-layout.res")==OK
	else: checks.baked_layout_loaded=bool(world.build_stats.get("flora_baked_layout",false))
	var passed := true
	for result in checks.values():passed=passed and bool(result)
	var receipt := {"passed":passed,"kind":"isolated_native_geometry_contact_fixture_not_Web_acceptance","checks":checks,"materials":material_names,"engine":Engine.get_version_info().string,"appdata":OS.get_environment("APPDATA"),"build_ms":build_ms,"reusable_kit_triangles":reusable_triangles,"triangles_all_instances":triangles,"instances":instance_count,"spatial_batches":habitat.batches.size(),"solid_instances":habitat.placements.size(),"solid_ray_hits":rays,"missed_rays":missed_rays,"max_support_gap_m":max_gap,"min_low_solid_road_distance_m":minimum_road,"placement_sha256":digest.finish().hex_encode(),"stats":world.build_stats}
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("flora-self-check.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  "));file.close()
	print("FLORA_SELF_CHECK "+JSON.stringify(receipt))
	world.free()
	quit(0 if passed else 1)
