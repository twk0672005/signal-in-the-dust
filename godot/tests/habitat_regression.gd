extends SceneTree
var output := ""
var checks: Dictionary = {}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	run.call_deferred()
func run() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	root.add_child(world)
	await physics_frame;await physics_frame
	var features: Node3D = world.get_node("HabitatFeatures")
	var faces_clear := true
	var grounded := true
	var solid_queries := 0
	var collision_count := 0
	var batches := 0
	var triangles := 0
	var space := world.get_world_3d().direct_space_state
	for child in features.get_children():
		if child is MultiMeshInstance3D:
			batches += 1
			var faces: PackedVector3Array = child.multimesh.mesh.get_faces()
			triangles += faces.size()/3 * child.multimesh.instance_count
			for i in child.multimesh.instance_count:
				var pose: Transform3D = child.multimesh.get_instance_transform(i)
				for vertex in faces:
					var point := pose * vertex
					if absf(point.x-world.path_x(point.z)) < 6.0: faces_clear = false
		elif child is StaticBody3D:
			collision_count += 1
			var shape: ConcavePolygonShape3D = child.get_child(0).shape
			var face: PackedVector3Array = shape.get_faces()
			# Base triangles deliberately overlap ground; sample exposed faces instead.
			for offset in range(0, face.size(), 9):
				var a: Vector3 = child.global_transform*face[offset]
				var b: Vector3 = child.global_transform*face[offset+1]
				var c: Vector3 = child.global_transform*face[offset+2]
				var center := (a+b+c)/3.0
				if center.y < world.height_at(center.x,center.z)+0.3: continue
				var normal := -(b-a).cross(c-a).normalized()
				var query := PhysicsRayQueryParameters3D.create(center+normal*0.2,center-normal*0.2)
				var hit := space.intersect_ray(query)
				if hit.get("collider") == child:
					solid_queries += 1
					break
	for record: Dictionary in features.records:
		var point: Vector3 = record.position
		grounded = grounded and absf(point.y-world.height_at(point.x,point.z)+0.25)<0.01
	checks.four_habitat_batches = batches == 4
	checks.all_features_clear_driving_corridor = faces_clear
	checks.bases_follow_terrain = grounded
	checks.solid_geometry_has_ray_collisions = collision_count == 36 and solid_queries == collision_count
	checks.triangle_budget_under_100k = triangles < 100000
	var normal_image: Image = (load("res://assets/terrain/cc0/rock023_nrm_rgh.png") as Texture2D).get_image()
	if normal_image.is_compressed(): normal_image.decompress()
	var min_alpha := 1.0
	var max_alpha := 0.0
	for x in range(0,normal_image.get_width(),32):
		for y in range(0,normal_image.get_height(),32):
			var alpha := normal_image.get_pixel(x,y).a
			min_alpha = minf(min_alpha,alpha);max_alpha = maxf(max_alpha,alpha)
	checks.packed_roughness_alpha_preserved = max_alpha-min_alpha > 0.05
	var passed := true
	for value in checks.values(): passed = passed and bool(value)
	var result := {"passed":passed,"checks":checks,"triangles_all_instances":triangles,"solid_rays_hit":solid_queries,"alpha_range":[min_alpha,max_alpha],"kind":"native_habitat_geometry_fixture_not_full_route"}
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("habitat.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "));file.close()
	print("HABITAT_REGRESSION " + JSON.stringify(result))
	world.queue_free();await process_frame;quit(0 if passed else 1)
