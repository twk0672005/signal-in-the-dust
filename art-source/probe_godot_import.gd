extends SceneTree
## Structural importer/clip probe; headless results are not visual quality proof.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://pipeline-probe.glb") as PackedScene
	if scene == null:
		push_error("Probe GLB failed to import")
		quit(1)
		return
	var instance := scene.instantiate()
	root.add_child(instance)
	await process_frame
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	var skeletons := instance.find_children("*", "Skeleton3D", true, false)
	var players := instance.find_children("*", "AnimationPlayer", true, false)
	var data: Dictionary = {"kind":"headless_import_animation_structure_not_visual", "godot":Engine.get_version_info().string,"meshes":meshes.size(),"skeletons":skeletons.size(),"players":players.size()}
	var passed := meshes.size() == 1 and skeletons.size() == 1 and players.size() == 1
	if passed:
		var material := (meshes[0] as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		data["transparency"] = material.transparency
		data["normal_enabled"] = material.normal_enabled
		data["normal_texture"] = material.normal_texture != null
		data["albedo"] = str(material.albedo_color)
		var player: AnimationPlayer = players[0]
		data["clips"] = Array(player.get_animation_list())
		var clip := ""
		for name in player.get_animation_list():
			if name != "RESET": clip = name
		passed = not clip.is_empty() and material.transparency != 0 and material.normal_texture != null
		if not clip.is_empty():
			var skeleton: Skeleton3D = skeletons[0]
			var bone := skeleton.find_bone("tip")
			player.play(clip)
			player.advance(0.0)
			var start := skeleton.get_bone_pose_rotation(bone)
			player.advance(0.5)
			var middle := skeleton.get_bone_pose_rotation(bone)
			data["bone_count"] = skeleton.get_bone_count()
			data["clip_length"] = player.get_animation(clip).length
			data["start_rotation"] = str(start)
			data["middle_rotation"] = str(middle)
			data["bone_animated"] = start.angle_to(middle) > 0.1
			passed = passed and bool(data.bone_animated)
	data["passed"] = passed
	var file := FileAccess.open("res://../godot-import.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("PIPELINE_IMPORT " + JSON.stringify(data))
	quit(0 if passed else 1)
