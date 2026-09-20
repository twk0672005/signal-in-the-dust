extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	var intruding := 0
	var detached := 0
	for ring in 17:
		for sector in 256:
			var p: Vector3 = world._horizon_point(sector, ring)
			if absf(p.x) < 104.0 and p.z > -680.0 and p.z < 190.0: intruding += 1
			if ring == 0:
				if absf(p.x) > 192.0 or p.z < -700.0 or p.z > 200.0 or p.y > world.height_at(p.x,p.z): detached += 1
	var result := {"passed":intruding == 0 and detached == 0,"intruding_horizon_vertices":intruding,"detached_inner_vertices":detached,"sampled_vertices":17*256,"kind":"horizon_geometry_fixture"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):
			var output := arg.trim_prefix("--evidence-dir=")
			DirAccess.make_dir_recursive_absolute(output)
			var file := FileAccess.open(output.path_join("horizon.json"),FileAccess.WRITE)
			file.store_string(JSON.stringify(result,"  "));file.close()
	print("HORIZON_REGRESSION " + JSON.stringify(result))
	world.free()
	quit(0 if result.passed else 1)
