extends Node3D
## Detailed anatomical presentation. Existing world behavior owns positions and reactions.
var species := "aeral"
var model: Node3D
var wings: Array[Node3D] = []
var legs: Array[Node3D] = []
var body: Node3D
var signal_materials: Array[Dictionary] = []
var pose_state: Dictionary = {}

func configure(kind: String) -> void:
	species = kind
	var packed := load("res://assets/visual_fauna/aeral_showcase.glb" if kind=="aeral" else "res://assets/visual_fauna/" + kind + ".glb") as PackedScene
	assert(packed != null, "Detailed creature resource missing: " + kind)
	model = packed.instantiate()
	add_child(model)
	var materials:Dictionary={}
	for node in model.find_children("*", "Node3D", true, false):
		if str(node.name).ends_with("MainWing_L") or str(node.name).ends_with("MainWing_R"):
			wings.append(node)
			var pivot:=Vector3(-.75 if str(node.name).ends_with("_L") else .75,3.5,-.4)
			node.position=pivot
			for child in node.get_children():
				if child is Node3D:child.position-=pivot
		if str(node.name).begins_with("LandingLeg_"): legs.append(node)
		if node.name == "BreathingBody": body = node
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if "perch_support" in str(mesh.name):mesh.visible=false;continue
		for shape in mesh.mesh.get_blend_shape_count():mesh.set_blend_shape_value(shape,1.0)
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original != null:
				if materials.has(original.resource_name):
					mesh.set_surface_override_material(surface,materials[original.resource_name]);continue
				var material:=ShaderMaterial.new();material.shader=load("res://shaders/bioceramic.gdshader")
				var label:=original.resource_name
				var tint:=Color("354c60")
				if "mineral" in label:tint=Color("657583")
				elif "membrane" in label:tint=Color("667692")
				elif "eyes" in label:tint=Color("0e232b")
				material.set_shader_parameter("tint",tint)
				material.set_shader_parameter("softness",.5 if "skin" in label else .2)
				material.set_shader_parameter("glow",.11 if "membrane" in label else .03)
				mesh.set_surface_override_material(surface,material)
				materials[original.resource_name]=material
		mesh.visibility_range_end=95.0

func pose(time: float, alarm: float, pulse: float, moving: float = 0.0) -> void:
	pose_state = {"alarm":alarm,"pulse":pulse,"moving":moving,"time":time}
	if species == "aeral":
		var beat := sin(time * (1.7 + alarm * 1.3))
		for wing in wings:
			var side := -1.0 if str(wing.name).ends_with("_L") else 1.0
			wing.rotation.z = side * (0.08 + beat * (0.17 + alarm * 0.22))
			wing.rotation.y = side * sin(time * 0.65) * 0.055
		for leg in legs:
			leg.rotation.x = (-0.25 - alarm * 0.20) * clampf(moving,0.0,1.0)
		if body != null:
			body.scale.y = 1.0 + sin(time * 1.8) * 0.013
	for entry in signal_materials:
		entry.material.emission_energy_multiplier = float(entry.energy) * (0.85 + pulse * 1.2 + (1.0 - alarm) * 0.15)
