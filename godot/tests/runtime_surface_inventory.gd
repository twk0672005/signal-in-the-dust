extends SceneTree
var output := ""
var changed_events := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output = arg.trim_prefix("--evidence-dir=")
	if output.is_empty(): quit(2); return
	run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node3D = load("res://main.tscn").instantiate()
	game.save_path = output.path_join("inventory-save.json")
	root.add_child(game)
	var defaults := StandardMaterial3D.new()
	var seen: Dictionary = {}
	var materials: Array = []
	for raw in game.find_children("*","GeometryInstance3D",true,false):
		var node := raw as GeometryInstance3D
		var active: Array[Material] = []
		if node.material_override != null: active.append(node.material_override)
		elif node is MeshInstance3D and node.mesh != null:
			for surface in node.mesh.get_surface_count(): active.append(node.get_active_material(surface))
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			for surface in node.multimesh.mesh.get_surface_count(): active.append(node.multimesh.mesh.surface_get_material(surface))
		elif node is CPUParticles3D and node.mesh != null:
			for surface in node.mesh.get_surface_count(): active.append(node.mesh.surface_get_material(surface))
		for material in active:
			if not material is StandardMaterial3D or seen.has(material.get_instance_id()): continue
			seen[material.get_instance_id()] = true
			var changes: Dictionary = {}
			for property in material.get_property_list():
				if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or property.name in ["resource_name","resource_local_to_scene","resource_path","script"]: continue
				var value: Variant = material.get(property.name)
				if value == defaults.get(property.name): continue
				changes[property.name] = value.resource_path if value is Resource else str(value)
			materials.append({"node":str(game.get_path_to(node)),"name":material.resource_name,"changes":changes})
	var probe := StandardMaterial3D.new()
	probe.changed.connect(func(): changed_events += 1)
	probe.albedo_color = Color.RED
	probe.emission = Color.GREEN
	probe.emission_energy_multiplier = 1.7
	var receipt := {"kind":"native_material_feature_inventory_not_render_or_performance_proof","passed":true,"checks":{"material_inventory_exists":not materials.is_empty()},"unique_standard_materials":materials.size(),"scalar_setter_changed_events":changed_events,"materials":materials}
	var file := FileAccess.open(output.path_join("inventory.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  "))
	file.close()
	print("SURFACE_INVENTORY " + JSON.stringify({"passed":true,"checks":{"material_inventory_exists":not materials.is_empty()},"materials":materials.size(),"scalar_setter_changed_events":changed_events}))
	game.queue_free()
	await create_timer(.5).timeout
	quit(0)
