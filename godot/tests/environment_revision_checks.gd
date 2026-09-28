extends SceneTree
const Save = preload("res://scripts/expedition_save.gd")
var checks: Dictionary = {}
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node3D=load("res://main.tscn").instantiate()
	game.save_path=output.path_join("isolated-terrain-save.json")
	Save.clear(game.save_path)
	root.add_child(game)
	await physics_frame
	await physics_frame
	game.start_expedition()
	game._set_phase("exploring")
	game.rover.set_driving_enabled(false)
	game.elapsed=123.4
	game.observed_ecology={"veyra":true}
	game.rover.distance_travelled=86.2
	checks.initial_save=game.save_expedition()
	var original: Dictionary=Save.read(game.save_path)
	var pool: Vector2=game.world._wetland_center()
	var point: Vector2=pool+Vector2(-16.0,2.0)
	var legacy: float=game.world.legacy_height_at(point.x,point.y)
	var current: float=game.world.height_at(point.x,point.y)
	checks.fixture_actually_changes_height=absf(legacy-current)>.1
	var migrated:=original.duplicate(true)
	migrated.position={"x":point.x,"y":legacy+.08,"z":point.y}
	Save.clear(game.save_path)
	Save.write(game.save_path,migrated)
	var saved_bytes:=FileAccess.get_file_as_bytes(game.save_path)
	checks.old_terrain_continue=game.load_expedition()
	checks.preserved_progress=is_equal_approx(game.elapsed,123.4) and game.observed_ecology.get("veyra",false) and is_equal_approx(game.rover.distance_travelled,86.2)
	checks.same_horizontal_position=Vector2(game.rover.position.x,game.rover.position.z).distance_to(point)<.001
	checks.grounded_above_new_mesh=game.rover.position.y>=current+.03 and game.rover.position.y<current+8.0
	checks.load_keeps_original_save_bytes=FileAccess.get_file_as_bytes(game.save_path)==saved_bytes
	game.rover.set_driving_enabled(false)
	# New grove geometry may cover a valid old off-road position outside the basin.
	var blocked_point: Vector3=game.world.spawn_origin()+Vector3(0,.08,0)
	checks.unobstructed_ground_is_clear=game._resume_space_clear(blocked_point,0.0)
	var obstacle:=StaticBody3D.new()
	obstacle.collision_layer=1|128
	var obstacle_shape:=CollisionShape3D.new()
	var box:=BoxMesh.new();box.size=Vector3(4,4,4)
	obstacle_shape.shape=box.create_trimesh_shape()
	obstacle_shape.shape.backface_collision=true
	obstacle.add_child(obstacle_shape)
	obstacle.position=blocked_point+Vector3.UP*1.5;root.add_child(obstacle)
	await physics_frame;await physics_frame
	var obstructed:=original.duplicate(true)
	obstructed.position={"x":blocked_point.x,"y":blocked_point.y,"z":blocked_point.z}
	Save.clear(game.save_path);Save.write(game.save_path,obstructed)
	checks.new_solid_detected=not game._resume_space_clear(blocked_point,0.0)
	checks.obstructed_legacy_continue=game.load_expedition()
	checks.obstructed_resume_is_free=game._resume_space_clear(game.rover.position,game.rover.heading)
	checks.obstructed_resume_keeps_progress=is_equal_approx(game.elapsed,123.4) and game.observed_ecology.get("veyra",false)
	checks.obstructed_resume_moves_only_locally=Vector2(game.rover.position.x,game.rover.position.z).distance_to(Vector2(blocked_point.x,blocked_point.z))<=6.1
	game.rover.set_driving_enabled(false)
	# Two volumes share one body, matching chunked grove collision ownership.
	var upper_shape:=box.create_trimesh_shape();upper_shape.backface_collision=true
	var upper_owner:=obstacle.create_shape_owner(obstacle)
	obstacle.shape_owner_add_shape(upper_owner,upper_shape)
	obstacle.shape_owner_set_transform(upper_owner,Transform3D(Basis.IDENTITY,Vector3.UP*6.0))
	await physics_frame;await physics_frame
	checks.stacked_solids_detected=not game._resume_space_clear(blocked_point,0.0)
	Save.clear(game.save_path);Save.write(game.save_path,obstructed)
	var stacked_bytes:=FileAccess.get_file_as_bytes(game.save_path)
	checks.stacked_continue=game.load_expedition()
	checks.stacked_resume_outside_box_bounds=absf(game.rover.position.x-blocked_point.x)>2.75 or absf(game.rover.position.z-blocked_point.z)>3.15
	checks.stacked_progress_preserved=is_equal_approx(game.elapsed,123.4) and game.observed_ecology.get("veyra",false)
	checks.stacked_save_bytes_unchanged=FileAccess.get_file_as_bytes(game.save_path)==stacked_bytes
	game.rover.set_driving_enabled(false)
	obstacle.remove_shape_owner(upper_owner)
	obstacle.position.y+=4.0
	await physics_frame;await physics_frame
	checks.free_space_beneath_overhang_is_preserved=game._resume_space_clear(blocked_point,0.0)
	obstacle.position=Vector3(point.x,current+5.5,point.y)
	await physics_frame;await physics_frame
	Save.clear(game.save_path);Save.write(game.save_path,migrated)
	checks.old_pond_save_stays_below_overhang=game.load_expedition() and game.rover.position.y<current+1.0
	game.rover.set_driving_enabled(false)
	obstacle.queue_free();await physics_frame
	var preserved_position: Vector3=game.rover.position
	migrated.position.y=maxf(legacy,current)+30.0
	Save.clear(game.save_path)
	Save.write(game.save_path,migrated)
	checks.invalid_height_rejected=not game.load_expedition() and game.rover.position==preserved_position
	var road_unchanged:=true
	for z in range(-390,-285,3):
		var x: float=game.world.path_x(float(z))
		road_unchanged=road_unchanged and is_equal_approx(game.world.height_at(x,float(z)),game.world.legacy_height_at(x,float(z)))
	checks.protected_road_unchanged=road_unchanged
	var shore_dry:=true
	for i in 64:
		var shore: Vector2=game.world.wetland_shore_point(float(i)/64.0*TAU,1.1)
		shore_dry=shore_dry and game.world.height_at(shore.x,shore.y)>=game.world.wetland_water_level()
	checks.shared_shore_query_stays_dry=shore_dry
	var fauna: Node=game.world._living_habitat.get_node_or_null("Microfauna")
	if fauna==null:
		for child in game.world._living_habitat.get_children():
			if child.get_script()!=null and child.get_script().resource_path.ends_with("microfauna_visual.gd"):
				fauna=child
	var anchors_dry:=fauna!=null
	if fauna!=null:
		for animal in fauna.animals:
			if animal.habitat in ["wetland_bank","wetland_rim"]:
				var anchor: Vector2=animal.anchor
				anchors_dry=anchors_dry and game.world.height_at(anchor.x,anchor.y)>=game.world.wetland_water_level()
	checks.fauna_anchors_dry=anchors_dry
	var passed:=true
	for value in checks.values(): passed=passed and bool(value)
	var receipt:={"passed":passed,"checks":checks,"legacy_height":legacy,"new_height":current,"kind":"native_scene_terrain_migration_not_browser_proof"}
	var file:=FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  "));file.close()
	print("ENVIRONMENT_REVISION "+JSON.stringify(receipt))
	game.queue_free()
	# Let the native audio thread release looping playback after node teardown.
	await create_timer(0.5).timeout
	quit(0 if passed else 1)

