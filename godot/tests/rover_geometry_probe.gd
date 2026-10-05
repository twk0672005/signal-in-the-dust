extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var model: Node3D = load("res://assets/models/rover.glb").instantiate()
	root.add_child(model)
	var result: Array = []
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box := node.get_aabb()
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for i in 8:
			var point: Vector3 = node.global_transform * (box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
			low = low.min(point); high = high.max(point)
		if high.y > 1.35: result.append({"name":str(node.name), "min":str(low), "max":str(high)})
	print("ROVER_UPPER_BOUNDS ", JSON.stringify(result))
	quit()
