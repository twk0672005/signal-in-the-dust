extends Node3D
## Anatomy only. World owns positions, time and ecology reactions.
## Rebuild: art-source/alien_renewal/biological/build_fauna.py.
const BIO_SHADER = preload("res://shaders/bioceramic.gdshader")
static var _scene_cache: Dictionary = {}
static var _material_cache: Dictionary = {}
var species := "aeral"
var model: Node3D
var body: Node3D
var wings: Array[Dictionary] = []
var legs: Array[Dictionary] = []
var crown: Array[Dictionary] = []
var signal_materials: Array[ShaderMaterial] = []
var _wing_materials: Array[Dictionary] = []
var pose_state: Dictionary = {}
var _terrain: Node3D
var _body_rest := Vector3.ZERO
var _last_time := -1.0
var _gait_clock := 0.0
var _last_position := Vector3.ZERO
var _speed := 0.0
var _travel_direction := Vector3.FORWARD
var _head: Node3D
# These bindings change only surface materials, never nodes, meshes or transforms.
var _material_bindings: Array[Dictionary] = []
var _debug_material_mode := "current"

func configure(kind: String) -> void:
	if model != null:
		remove_child(model)
		model.queue_free()
	wings.clear(); legs.clear(); crown.clear(); signal_materials.clear(); _wing_materials.clear()
	_material_bindings.clear()
	_debug_material_mode = "current"
	species = "morrow" if kind == "root_choir" else kind
	var path := "res://assets/visual_fauna/" + species + "_runtime.glb"
	if not _scene_cache.has(path): _scene_cache[path] = load(path) as PackedScene
	var packed: PackedScene = _scene_cache[path]
	if packed == null:
		push_error("Detailed creature resource missing: " + path)
		return
	model = packed.instantiate() as Node3D
	add_child(model)
	_terrain = _find_terrain()
	body = model.find_child("Body", true, false) as Node3D
	if body != null: _body_rest = body.position
	_head = model.find_child("Head", true, false) as Node3D
	for item in model.find_children("*", "Node3D", true, false):
		var node := item as Node3D
		var label := str(node.name)
		if label == "Wing_L" or label == "Wing_R":
			wings.append({"node": node, "rest": node.rotation, "side": -1.0 if label.ends_with("_L") else 1.0})
		elif label.begins_with("CrownFrond_") and not label.ends_with("Geometry"):
			crown.append({"node": node, "rest": node.rotation, "index": crown.size()})
		elif label.begins_with("Leg_") and not label.ends_with("Geometry"):
			var suffix := label.trim_prefix("Leg_")
			var shin := node.find_child("Shin_" + suffix, true, false) as Node3D
			var foot := node.find_child("Foot_" + suffix, true, false) as Node3D
			if shin != null and foot != null:
				legs.append({"node": node, "shin": shin, "foot": foot, "hip": node.position,
					"upper": shin.position, "lower": foot.position,
					"rest_foot": node.position + shin.position + foot.position,
					"side": -1.0 if "_L_" in label else 1.0, "index": int(suffix.right(1))})
		elif label.begins_with("LandingLeg_") and not label.ends_with("Geometry"):
			legs.append({"node": node, "rest": node.rotation})
		if node is MeshInstance3D: _configure_mesh(node as MeshInstance3D)
	_last_position = global_position if is_inside_tree() else position
	_last_time = -1.0
	pose(0.0, 0.0, 0.0, 0.0)

func _find_terrain() -> Node3D:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("height_at") and ancestor is Node3D: return ancestor as Node3D
		ancestor = ancestor.get_parent()
	return null

func _configure_mesh(node: MeshInstance3D) -> void:
	for surface in node.mesh.get_surface_count():
		var original := node.get_active_material(surface)
		var label := original.resource_name.to_lower() if original != null else "skin"
		# Only armour adds two shared age states; no per-animal texture copies.
		var aged := "mineral" in label and species != "aeral" and int(get_parent().name.hash())%2==0
		var key := species + ":" + label + (":aged" if aged else "")
		if not _material_cache.has(key):
			var material := ShaderMaterial.new()
			material.shader = BIO_SHADER
			material.set_shader_parameter("surface_age",.82 if aged else .26)
			var tint := Color("444b49")
			var roughness := 0.76
			var shell := 0.0
			var membrane := 0.0
			var glow := 0.0
			if species == "veyra":
				tint = Color("424b40")
				if "mineral" in label: tint = Color("6a6047"); shell = 1.0; roughness = 0.72
				elif "worn_edge" in label: tint = Color("a28151"); shell = 0.55
				elif "signal" in label: tint = Color("cd7737"); glow = 0.14
			elif species == "morrow":
				tint = Color("514955")
				if "mineral" in label: tint = Color("797266"); shell = 0.8; roughness = 0.75
				elif "worn_edge" in label: tint = Color("a3937b"); shell = 0.45
				elif "membrane" in label: tint = Color("795064"); membrane = 1.0; roughness = 0.72
				elif "signal" in label: tint = Color("aa8a9d"); glow = 0.10
			else:
				tint = Color("444f60"); roughness = 0.78
				if "mineral" in label: tint = Color("75816f"); shell = 0.65; roughness = 0.73
				elif "membrane" in label: tint = Color("436b73"); membrane = 1.0; roughness = 0.65; glow = 0.12
			if "eyes" in label: tint = Color("111e21"); roughness = 0.24; shell = 0.0
			material.set_shader_parameter("specular_amount", 0.5 if "eyes" in label else 0.52 if membrane > 0.0 else 0.36 if shell > 0.0 else 0.35)
			var role := "fan" if membrane > 0.0 and species == "aeral" else "frond" if membrane > 0.0 else "scute" if species != "aeral" and "mineral" in label else "dermis"
			if "eyes" not in label and "signal" not in label:
				material.set_shader_parameter("structure_enabled", true)
				material.set_shader_parameter("dermal_projection", role == "dermis")
				material.set_shader_parameter("normal_strength", 0.48 if membrane > 0.0 else 0.65 if role == "scute" else 0.46)
				material.set_shader_parameter("structure_map", load("res://assets/visual_fauna/surface_maps/" + role + "_structure.png"))
				material.set_shader_parameter("surface_normal", load("res://assets/visual_fauna/surface_maps/" + role + "_normal.png"))
			material.set_shader_parameter("tint", tint)
			material.set_shader_parameter("roughness", roughness)
			material.set_shader_parameter("shell", shell)
			material.set_shader_parameter("membrane", membrane)
			material.set_shader_parameter("glow", glow)
			material.set_shader_parameter("shell_uv", 1.0 if species != "aeral" and "mineral" in label else 0.0)
			material.set_meta("previous_tint", tint)
			material.set_meta("previous_roughness", roughness)
			# Preserve the authored GLB PBR maps at the common material entry point.
			# The reaction shader still owns wing flex and signal response.
			var source := original as StandardMaterial3D
			if source != null and source.albedo_texture != null:
				material.set_shader_parameter("authored_enabled", true)
				material.set_shader_parameter("authored_albedo", source.albedo_texture)
				material.set_shader_parameter("tint", source.albedo_color)
				material.set_shader_parameter("roughness", source.roughness)
				if source.roughness_texture != null:
					var channel := Vector4.ZERO
					match source.roughness_texture_channel:
						BaseMaterial3D.TEXTURE_CHANNEL_RED: channel.x = 1.0
						BaseMaterial3D.TEXTURE_CHANNEL_GREEN: channel.y = 1.0
						BaseMaterial3D.TEXTURE_CHANNEL_BLUE: channel.z = 1.0
						BaseMaterial3D.TEXTURE_CHANNEL_ALPHA: channel.w = 1.0
						_: channel = Vector4(0.333333,0.333333,0.333333,0.0)
					material.set_shader_parameter("authored_roughness_enabled", true)
					material.set_shader_parameter("authored_roughness", source.roughness_texture)
					material.set_shader_parameter("authored_roughness_channel", channel)
				if source.normal_enabled and source.normal_texture != null:
					material.set_shader_parameter("authored_normal_enabled", true)
					material.set_shader_parameter("authored_normal", source.normal_texture)
					material.set_shader_parameter("normal_strength", source.normal_scale)
			_material_cache[key] = material
		var selected: ShaderMaterial = _material_cache[key]
		var responsive := "signal" in label or (species == "aeral" and "membrane" in label)
		if responsive:
			selected = selected.duplicate() as ShaderMaterial
		if species == "aeral" and str(node.get_parent().name).begins_with("Wing_"):
			selected = selected.duplicate() as ShaderMaterial
			selected.set_shader_parameter("surface_age",.62 if str(node.get_parent().name).ends_with("_L") else .24)
			_wing_materials.append({"material":selected,"side":-1.0 if str(node.get_parent().name).ends_with("_L") else 1.0})
		if responsive: signal_materials.append(selected)
		node.set_surface_override_material(surface, selected)
		_material_bindings.append({"node":node,"surface":surface,"source":original,"current":selected,
			"label":label,"wing":species == "aeral" and str(node.get_parent().name).begins_with("Wing_")})
	node.visibility_range_end = 115.0
	node.visibility_range_end_margin = 12.0

func debug_set_material_mode(mode: String) -> Dictionary:
	# Local inspection only. Public Web release URLs cannot activate this path.
	var permitted := OS.is_debug_build() and not OS.has_feature("web")
	if OS.has_feature("web"):
		permitted = bool(JavaScriptBridge.eval("['localhost','127.0.0.1','[::1]'].includes(location.hostname) && new URLSearchParams(location.search).get('review') === '1'", true))
	if not permitted or mode not in ["current", "previous", "authored_factors"]:
		return {"applied":false,"mode":_debug_material_mode,"reason":"local review only; expected current, previous or authored_factors"}
	for binding in _material_bindings:
		if not binding.has(mode):
			var material: ShaderMaterial
			if mode == "previous":
				material = (binding.current as ShaderMaterial).duplicate() as ShaderMaterial
				material.shader = load("res://shaders/creature_previous.gdshader")
				material.set_shader_parameter("tint", material.get_meta("previous_tint"))
				material.set_shader_parameter("roughness", material.get_meta("previous_roughness"))
				if "signal" in str(binding.label): signal_materials.append(material)
			else:
				var source := binding.source as StandardMaterial3D
				if source == null: return {"applied":false,"reason":"original PBR material missing"}
				material = ShaderMaterial.new()
				material.shader = load("res://shaders/creature_authored_factors.gdshader")
				material.set_shader_parameter("tint",source.albedo_color)
				material.set_shader_parameter("roughness",source.roughness)
				material.set_shader_parameter("metallic",source.metallic)
				material.set_shader_parameter("specular_amount",source.metallic_specular)
				material.set_shader_parameter("authored_emission",source.emission * source.emission_energy_multiplier if source.emission_enabled else Color(0,0,0,1))
			if binding.wing:
				material.set_shader_parameter("wing_flex",binding.current.get_shader_parameter("wing_flex"))
				_wing_materials.append({"material":material})
			binding[mode] = material
		binding.node.set_surface_override_material(binding.surface,binding[mode])
	_debug_material_mode = mode
	return {"applied":true,"mode":mode,"surfaces":_material_bindings.size(),"maps_available":true,"current_external_structure_maps":true,
		"comparison":"current retains the GLB baked PBR maps; authored_factors isolates original constants with identical wing flex"}

func pose(time: float, alarm: float, pulse: float, moving: float = 0.0) -> void:
	if model == null: return
	alarm = clampf(alarm, 0.0, 1.0)
	pulse = clampf(pulse, 0.0, 1.0)
	var dt := clampf(time - _last_time, 0.0, 0.1) if _last_time >= 0.0 else 0.0
	if is_inside_tree() and dt > 0.0:
		var displacement := global_position - _last_position
		displacement.y = 0.0
		if displacement.length_squared() > 0.000001: _travel_direction = displacement.normalized()
		var velocity := displacement.length() / dt
		_speed = lerpf(_speed, minf(velocity, 3.0), 1.0 - exp(-dt * 5.0))
		_last_position = global_position
	_last_time = time
	pose_state = {"alarm": alarm, "pulse": pulse, "moving": moving, "time": time, "visual_speed": _speed}
	if species == "aeral":
		var beat := sin(time * (2.25 + alarm * 2.6))
		for entry in wings:
			var wing: Node3D = entry.node
			var side: float = entry.side
			var rest: Vector3 = entry.rest
			wing.rotation = rest + Vector3(sin(time * 1.1) * 0.035, side * sin(time * 0.7) * 0.045,
				side * (0.07 + beat * (0.16 + alarm * 0.24)))
		for entry in legs: entry.node.rotation = entry.rest + Vector3(-0.16 - alarm * 0.31 + sin(time * 1.3) * 0.035, 0, 0)
		for entry in _wing_materials:
			entry.material.set_shader_parameter("wing_flex", sin(time*(2.25+alarm*2.6)-0.6)*(0.055+alarm*0.045))
		if body != null: body.scale.y = 1.0 + sin(time * 1.8) * 0.012
	elif species == "veyra":
		var locomotion := clampf(maxf(_speed, moving) * 2.4, 0.0, 1.0)
		_gait_clock += dt * (1.8 + _speed * 3.0)
		if body != null:
			body.position = _body_rest + Vector3(0, sin(time * 1.4) * 0.015 - alarm * 0.07, 0)
			body.rotation.z = sin(_gait_clock * 2.0) * 0.015 * locomotion
		if _head != null: _head.rotation.x = 0.06 + sin(time * 0.9) * 0.045 + alarm * 0.13
		for entry in legs: _pose_veyra_leg(entry, locomotion, alarm)
	elif species == "morrow":
		var parent_scale_y := get_parent_node_3d().global_basis.get_scale().y if get_parent_node_3d() != null else 1.0
		model.position.y = -0.7 / maxf(0.25, parent_scale_y) + 0.7
		if _terrain != null:
			var p := global_position
			var gradient_x: float = clampf((_terrain.height_at(p.x+1.2,p.z)-_terrain.height_at(p.x-1.2,p.z))/2.4,-0.35,0.35)
			var gradient_z: float = clampf((_terrain.height_at(p.x,p.z+1.2)-_terrain.height_at(p.x,p.z-1.2))/2.4,-0.35,0.35)
			var up := (global_basis.inverse()*Vector3(-gradient_x,1.0,-gradient_z)).normalized()
			model.quaternion = Quaternion(Vector3.UP,up)
			var contact := Vector3(p.x,_terrain.height_at(p.x,p.z),p.z)
			model.position = to_local(contact) - model.basis * Vector3(0,-0.7,0)
		if body != null: body.scale = Vector3(1.0 + sin(time * 1.2) * 0.012, 1.0, 1.0 + sin(time * 1.2) * 0.015)
		for entry in crown:
			var frond: Node3D = entry.node
			var index: int = entry.index
			var rest: Vector3 = entry.rest
			frond.rotation = rest + Vector3(0.18 + alarm * 0.20 + sin(time * 1.2 + index * 0.7) * (0.08 - alarm * 0.055) - pulse * 0.10, 0, sin(time * 0.8 + index) * 0.035)
			frond.scale = Vector3(1.0-alarm*0.45,1.0-alarm*0.66+pulse*0.025,1.0-alarm*0.75)
	for material in signal_materials: material.set_shader_parameter("response", 0.45 + pulse * 0.8 - alarm * 0.25)

func _pose_veyra_leg(entry: Dictionary, locomotion: float, alarm: float) -> void:
	var leg: Node3D = entry.node
	var shin: Node3D = entry.shin
	var foot: Node3D = entry.foot
	var side: float = entry.side
	var phase := _gait_clock + (PI if (int(entry.index) + (1 if side < 0 else 0)) % 2 else 0.0)
	var hip: Vector3 = entry.hip
	hip.y -= alarm * 0.045
	var target: Vector3 = entry.rest_foot
	var cycle := fposmod(phase, TAU) / TAU
	var swinging := cycle < 0.42 and locomotion > 0.04
	var lift := sin(cycle / 0.42 * PI) * 0.17 * locomotion if swinging else 0.0
	if _terrain != null and is_inside_tree():
		var rest_world := to_global(target)
		var world_foot := rest_world
		if locomotion > 0.04:
			if not entry.has("planted"): entry["planted"] = rest_world
			if swinging:
				if not bool(entry.get("swinging", false)): entry["swing_start"] = entry.planted
				var swing_progress := smoothstep(0.0, 1.0, cycle / 0.42)
				world_foot = (entry.get("swing_start",rest_world) as Vector3).lerp(rest_world + _travel_direction * 0.16 * locomotion, swing_progress)
				entry["planted"] = world_foot
			else:
				world_foot = entry.planted
				# A teleport or a sharp scripted turn starts a fresh contact.
				if Vector2(world_foot.x-rest_world.x,world_foot.z-rest_world.z).length() > 0.42:
					world_foot = rest_world
					entry["planted"] = world_foot
		else: entry["planted"] = rest_world
		entry["swinging"] = swinging
		var surface_y: float = _terrain.height_at(world_foot.x, world_foot.z)
		world_foot.y = surface_y + 0.115 * global_basis.get_scale().y + lift
		target = to_local(world_foot)
	else: target.y = -0.235 + lift
	var upper: Vector3 = entry.upper
	var lower: Vector3 = entry.lower
	var a := upper.length()
	var b := lower.length()
	var reach := target - hip
	var distance := clampf(reach.length(), 0.05, a + b - 0.005)
	var direction := reach.normalized()
	var outward := Vector3(side, 0.5, 0.1)
	var bend := (outward - direction * outward.dot(direction)).normalized()
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	var altitude := sqrt(maxf(0.0, a * a - along * along))
	var knee := hip + direction * along + bend * altitude
	leg.position = hip
	leg.quaternion = Quaternion(upper.normalized(), (knee - hip).normalized())
	shin.position = upper
	var local_lower := leg.basis.inverse() * (target - knee)
	shin.quaternion = Quaternion(lower.normalized(), local_lower.normalized())
	foot.position = lower
	var foot_level := Basis.IDENTITY
	if _terrain != null and is_inside_tree():
		var world_target := to_global(target)
		var gradient_x: float = (_terrain.height_at(world_target.x+0.12,world_target.z)-_terrain.height_at(world_target.x-0.12,world_target.z))/0.24
		var gradient_z: float = (_terrain.height_at(world_target.x,world_target.z+0.12)-_terrain.height_at(world_target.x,world_target.z-0.12))/0.24
		var up := Vector3(-gradient_x,1.0,-gradient_z).normalized()
		var forward := -global_basis.z.normalized()
		var right := forward.cross(up).normalized()
		foot_level = global_basis.orthonormalized().inverse() * Basis(right,up,right.cross(up))
	foot.basis = (leg.basis * shin.basis).inverse() * foot_level
	entry["contact_target"] = target
	entry["lift"] = lift

func debug_snapshot() -> Dictionary:
	var feet: Array = []
	for entry in legs:
		if entry.has("foot"):
			var sole: Vector3 = entry.foot.to_global(Vector3(0,-0.115,0))
			var ground: float = _terrain.height_at(sole.x,sole.z) if _terrain != null else 0.0
			feet.append({"position": str(entry.foot.global_position), "sole":str(sole), "ground":ground,
				"clearance":sole.y-ground,"lift":entry.get("lift",0.0),
				"target_error":entry.foot.global_position.distance_to(to_global(entry.get("contact_target",entry.rest_foot)))})
	var wing_angles: Array = []
	for entry in wings: wing_angles.append(str(entry.node.rotation))
	var crown_scales: Array = []
	var crown_angles: Array = []
	for entry in crown:
		crown_scales.append(str(entry.node.scale))
		crown_angles.append(str(entry.node.rotation))
	return {"species": species, "material_mode":_debug_material_mode,"material_surfaces":_material_bindings.size(), "pose": pose_state.duplicate(), "wings": wings.size(), "legs": legs.size(), "crown": crown.size(), "feet": feet,"wing_angles":wing_angles,"crown_scales":crown_scales,"crown_angles":crown_angles,"body_position":str(body.position) if body != null else "","body_scale":str(body.scale) if body != null else ""}
