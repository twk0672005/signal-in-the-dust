extends SceneTree
## Bake the exact existing driving surface once; visual materials remain runtime-owned.
func _initialize() -> void:
	_bake.call_deferred()

func _bake() -> void:
	var world := preload("res://scripts/world.gd").new()
	world.staged_boot = true
	root.add_child(world)
	world._terrain_material = ShaderMaterial.new()
	world._terrain_material.shader = world.TERRAIN_SHADER
	await world._build_terrain(true)
	var ground: MeshInstance3D = world.get_node("CollidableDustBasin")
	assert(ground.mesh.get_surface_count() == 1)
	var arrays := ground.mesh.surface_get_arrays(0)
	assert(arrays[Mesh.ARRAY_VERTEX].size() > 50000)
	assert(arrays[Mesh.ARRAY_NORMAL].size() == arrays[Mesh.ARRAY_VERTEX].size())
	for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]: assert(p.is_finite())
	var folder := "res://assets/alien_renewal"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file := folder + "/terrain_v%d.res" % world.TERRAIN_REVISION
	assert(ResourceSaver.save(ground.mesh,file,ResourceSaver.FLAG_COMPRESS) == OK)
	var copy := ResourceLoader.load(file,"ArrayMesh",ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
	assert(copy != null and copy.get_faces() == ground.mesh.get_faces())
	var collision: CollisionShape3D = ground.get_child(0).get_child(0)
	assert(ResourceSaver.save(collision.shape,folder+"/terrain_collision_v%d.res" % world.TERRAIN_REVISION,ResourceSaver.FLAG_COMPRESS) == OK)
	world._strata_material = ShaderMaterial.new()
	world._strata_material.shader = world.STRATA_SHADER
	world._build_horizon(true)
	var horizon: MeshInstance3D = world.get_node("AuthoredDistantCaldera")
	assert(ResourceSaver.save(horizon.mesh,folder+"/horizon_v1.res",ResourceSaver.FLAG_COMPRESS) == OK)
	var center: Vector2 = world._wetland_center()
	var origin := Vector3(center.x,world.height_at(center.x,center.y),center.y)
	var water: ArrayMesh = world._terrain_clipped_water(origin,.37,true)
	assert(water.get_faces().size() > 300)
	var water_file := folder+"/water_surface_v%d.res" % world.TERRAIN_REVISION
	assert(ResourceSaver.save(water,water_file,ResourceSaver.FLAG_COMPRESS) == OK)
	var water_copy := ResourceLoader.load(water_file,"ArrayMesh",ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
	assert(water_copy.get_faces() == water.get_faces())
	print("BAKED_TERRAIN_PASS revision=",world.TERRAIN_REVISION," vertices=",arrays[Mesh.ARRAY_VERTEX].size()," triangles=",world._triangle_count(copy))
	quit(0)
