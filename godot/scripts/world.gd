extends Node3D
## Authored geological basin. Coordinates and height queries are shared with driving.
const SURVEYS = preload("res://scripts/expedition_activities.gd")
const HABITAT_FEATURES = preload("res://scripts/living_habitat.gd")
const CREATURE_VISUAL = preload("res://scripts/creature_visual.gd")
var _living_habitat:Node3D
const ECOLOGY_RESPONSE = preload("res://scripts/ecology_response.gd")
const ROCKS_PATH := "res://assets/models/rocks.glb"
const TERRAIN_SHADER = preload("res://shaders/terrain.gdshader")
const SKY_SHADER = preload("res://shaders/storm_sky.gdshader")
const ROOT_SHADER = preload("res://shaders/response_roots.gdshader")
const STRATA_SHADER = preload("res://shaders/geological_strata.gdshader")
const WETLAND_SHADER = preload("res://shaders/wetland_pool.gdshader")
const GROUND037_ALBEDO_PATH := "res://assets/terrain/cc0/ground037_alb_ht.png"
const GROUND037_NORMAL_PATH := "res://assets/terrain/cc0/ground037_nrm_rgh.png"
const PASSAGE_Z := [-235.0, -260.0, -285.0, -310.0, -330.0]
const PASSAGE_X_OFFSETS := [-6.0, 7.0, -7.0, 6.0, -5.0]
const ROOT_NETWORK_Z := [-405.0, -455.0, -520.0, -595.0]
const ROOT_NETWORK_X_OFFSETS := [20.0, -22.0, 24.0, -16.0]
const ROOT_NETWORK_SOLUTION := [1, 2, 1]
var _environment: Environment
var _roots_material: ShaderMaterial
var _small_dressing: Array[MultiMeshInstance3D] = []
var _dust: CPUParticles3D
var _rng := RandomNumberGenerator.new()
var _terrain_material: ShaderMaterial
var _strata_material: ShaderMaterial
var _rock_meshes: Array[Mesh] = []
var _low_meshes: Array[Mesh] = []
var _rock_transforms: Array[Array] = []
var _bank_transforms: Array[Array] = []
var _small_transforms: Array[Array] = []
var _low_quality := false
var _world_time: float = 0.0
var _paused: bool = false
var _player_position := Vector3.ZERO
var _player_speed: float = 0.0
var _ecology_reactions: Array[RefCounted] = []
var _ecology_glow: Array[Array] = []
var _ecology_nodes: Array[Node3D] = []
var _ecology_meta: Array[Dictionary] = []
var _observed_regions: Dictionary = {}
var build_stats: Dictionary = {}
var _escort_state: Dictionary = {}
var _shelter_material: StandardMaterial3D
var _survey_materials: Dictionary = {}
var _resonance_crystals: Array[Node3D] = []
var _resonance_glows: Array[StandardMaterial3D] = []
var _resonance_open := 0.0
var _passage_state: Dictionary = {"phase":"idle", "gate":0, "alarm":0.0}
var _passage_gates: Array[Node3D] = []
var _passage_wings: Array[Array] = []
var _passage_materials: Array[StandardMaterial3D] = []
var _passage_open: Array[float] = []
var _root_network_state: Dictionary = {"ports":[0, 0, 0], "powered":0, "complete":false}
var _root_relays: Array[Node3D] = []
var _root_relay_rotors: Array[Node3D] = []
var _root_selector_materials: Array[StandardMaterial3D] = []
var _root_port_angles: Array[Array] = []
var _root_conduits: Array[Array] = []
var _root_conduit_materials: Array[Array] = []
var _root_network_endpoints: Array[Array] = []
var _root_terminal_shells: Array[Node3D] = []
var _root_terminal_shell_origins: Array[Vector3] = []
var _root_terminal_glow: Node3D
var _root_terminal_glow_material: StandardMaterial3D
var _root_network_open: float = 0.0
var _thermal_state: Dictionary = {"vent_observed":false, "route":"warm", "locked":false}
var _thermal_vent: Node3D
var _thermal_vent_plates: Array[Dictionary] = []
var _thermal_steam: Array[MeshInstance3D] = []
var _thermal_steam_material: StandardMaterial3D
var _thermal_cue_material: StandardMaterial3D
var _thermal_open: float = 0.0
var _cool_bed_material: StandardMaterial3D
var _wetland_state: Dictionary = {"prepared":false, "startled":false, "recovered":false, "complete":false}
var _wetland_root: Node3D
var _wetland_plants: Array[Dictionary] = []
var _wetland_vein_materials: Array[StandardMaterial3D] = []
var _wetland_water_material: ShaderMaterial
var _wetland_reader_material: StandardMaterial3D
var _wetland_reader_label: Label3D
var _wetland_open: float = 0.0
var _wetland_alarm: float = 0.0

func path_x(z: float) -> float:
	return 18.0 * sin((150.0 - z) * 0.012) + 4.0 * sin((150.0 - z) * 0.033)

func _base_height_at(x: float, z: float) -> float:
	var d := absf(x - path_x(z))
	var banks := smoothstep(5.5, 33.0, d)
	var base := 0.8 * sin(z * 0.023) + 0.38 * sin(z * 0.064)
	var shelf := 1.8 + 2.2 * sin(z * 0.039 + x * 0.018) + 1.4 * sin(x * 0.087 + z * 0.022)
	var broken := sin(x * 0.31 + sin(z * 0.09)) * sin(z * 0.26) * 0.35
	var flank := smoothstep(65.0, 170.0, d) * (9.0 + 4.0 * sin(z * 0.021 + x * 0.026))
	var zone_wave := 0.0
	if z < 40.0 and z > -130.0: zone_wave = sin(x * 0.18 + z * 0.04) * 0.5
	elif z <= -130.0 and z > -300.0: zone_wave = sin(x * 0.11) * 1.2 + cos(z * 0.13) * 0.45
	elif z <= -300.0 and z > -470.0: zone_wave = sin(x * 0.27 + z * 0.02) * 0.22 - 0.45
	else: zone_wave = sin(x * 0.08 + z * 0.07) * 0.8 + 0.35
	var signal_clear := 1.0 - smoothstep(11.0, 24.0, Vector2(x - path_x(-650.0), z + 650.0).length())
	return base + zone_wave + (banks * (shelf + broken) + flank) * (1.0 - signal_clear)

func _wetland_center() -> Vector2:
	return Vector2(path_x(-342.0) - 32.0, -342.0)

func height_at(x: float, z: float) -> float:
	var base_height := _base_height_at(x, z)
	var center := _wetland_center()
	var distance := Vector2(x - center.x, z - center.y).length()
	if distance >= 10.0:
		return base_height
	# The coarse 2.5 x 4.7 m terrain sampling needs a broad, flat-bottomed bowl.
	# Outside ten metres the blend is exactly zero, preserving every established route height.
	var basin_floor := _base_height_at(center.x, center.y) - 1.2
	return lerpf(basin_floor, base_height, smoothstep(3.4, 10.0, distance))

func spawn_origin() -> Vector3:
	return Vector3(path_x(150.0), height_at(path_x(150.0), 150.0), 150.0)

func signal_origin() -> Vector3:
	return Vector3(path_x(-650.0), height_at(path_x(-650.0), -650.0), -650.0)

func passage_route() -> Array[Vector2]:
	var route: Array[Vector2] = []
	for i in PASSAGE_Z.size():
		var z: float = PASSAGE_Z[i]
		route.append(Vector2(path_x(z) + PASSAGE_X_OFFSETS[i], z))
	return route

func root_network_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in ROOT_NETWORK_Z.size():
		var z: float = ROOT_NETWORK_Z[i]
		points.append(Vector2(path_x(z) + ROOT_NETWORK_X_OFFSETS[i], z))
	return points

func _ready() -> void:
	_rng.seed = 20260915
	_build_atmosphere()
	_build_material()
	_build_terrain()
	_build_horizon()
	_build_landmarks()
	_build_rocks()
	_build_wetland_pool()
	_build_root_network()
	var habitats := HABITAT_FEATURES.new()
	habitats.name = "HabitatFeatures"
	add_child(habitats)
	habitats.build(self)
	_living_habitat=habitats
	_build_passage_gates()
	_build_survey_sites()
	_build_resonance_grove()
	_build_ecology()
	_build_escort_shelter()
	_build_thermal_route()
	_prepare_ecology_responses()
	_build_response()
	_build_dust()
	reset()

func _prepare_ecology_responses() -> void:
	for node in _ecology_nodes:
		_ecology_reactions.append(ECOLOGY_RESPONSE.new())
		var glow: Array = []
		for child in node.get_children():
			if child is MeshInstance3D and child.material_override is StandardMaterial3D:
				var material := child.material_override.duplicate() as StandardMaterial3D
				child.material_override = material
				if material.emission_enabled:
					glow.append({"material": material, "energy": material.emission_energy_multiplier})
		_ecology_glow.append(glow)

func _process(delta: float) -> void:
	if _paused: return
	_world_time += delta
	if is_instance_valid(_living_habitat):_living_habitat.tick(delta,false)
	_tick_ecology(delta)
	_tick_thermal(delta)
	_tick_passage_gates(delta)
	_tick_root_network(delta)
	_tick_wetland(delta)

func _tick_ecology(delta: float) -> void:
	for i in _ecology_nodes.size():
		var node := _ecology_nodes[i]
		var data := _ecology_meta[i]
		var reaction: RefCounted = _ecology_reactions[i]
		var phase: float = data["phase"]
		var base: Vector3 = data["base"]
		var kind: String = data["kind"]
		if i==0 and _escort_state.get("phase","idle")!="idle":
			reaction.step(INF,0.0,delta)
			reaction.alert=clampf(float(_escort_state.alarm),0.0,1.0)
		else:
			reaction.step(node.global_position.distance_to(_player_position), _player_speed, delta)
		var alarm: float = reaction.alert
		var pulse: float = reaction.pulse_amount()
		if kind == "root_choir" and bool(_root_network_state.get("complete", false)):
			# Completion is presentation-only: the choir breathes without altering observation state.
			pulse = maxf(pulse, 0.34 + 0.16 * sin(_world_time * 1.8 + phase))
		var away := Vector3(base.x - _player_position.x, 0, base.z - _player_position.z).normalized()
		if away.is_zero_approx(): away = Vector3.RIGHT
		var target := base
		if kind == "aeral":
			var passage_phase := str(_passage_state.get("phase", "idle"))
			var aeral_index := int(data.get("passage_index", 0))
			if passage_phase == "complete":
				var corridor := passage_route()[clampi(aeral_index, 0, PASSAGE_Z.size() - 1)]
				var side := -1.0 if aeral_index % 2 == 0 else 1.0
				var corridor_x := corridor.x + side * (9.0 + float(aeral_index % 3))
				var corridor_z := corridor.y + (float(aeral_index % 2) - 0.5) * 4.0
				target = Vector3(corridor_x, height_at(corridor_x, corridor_z) + 3.2, corridor_z)
			elif passage_phase == "scattered":
				var gate_index := clampi(int(_passage_state.get("gate", 0)), 0, PASSAGE_Z.size() - 1)
				var gate_point := passage_route()[gate_index]
				var from_gate := Vector3(base.x - gate_point.x, 0.0, base.z - gate_point.y)
				var influence := 1.0 - smoothstep(16.0, 70.0, from_gate.length())
				if from_gate.is_zero_approx(): from_gate = Vector3.RIGHT
				var passage_alarm := clampf(float(_passage_state.get("alarm", 0.0)), 0.0, 2.0)
				target += from_gate.normalized() * influence * (2.8 + passage_alarm * 1.4)
				target += Vector3.UP * influence * (2.6 + passage_alarm * 1.7)
			target += Vector3(sin(_world_time * 0.55 + phase) * 2.4, sin(_world_time * 0.8 + phase) * 0.75, cos(_world_time * 0.44 + phase) * 1.5)
			var response_alarm := alarm * 0.35 if passage_phase == "complete" else alarm
			target += away * response_alarm * 3.0 + Vector3.UP * response_alarm * 3.5
			node.rotation = Vector3(0, phase + sin(_world_time * 0.4 + phase) * 0.25, sin(_world_time * 1.2 + phase) * (0.08 + alarm * 0.28))
		elif kind == "veyra":
			var cool_targets := [Vector2(-64.0,-143.0),Vector2(-57.0,-147.0),Vector2(-64.0,-151.0)]
			var cool_complete := bool(_escort_state.get("complete",false)) and str(_thermal_state.get("route","warm"))=="cool"
			if cool_complete and i>=1 and i<=3:
				var bed_target: Vector2=cool_targets[i-1]
				target=Vector3(bed_target.x,height_at(bed_target.x,bed_target.y)+0.35,bed_target.y)
			else:
				target += away * alarm * 3.0 + Vector3(sin(_world_time * 0.7 + phase) * 0.35, 0, cos(_world_time * 0.55 + phase) * 0.35)
			target.y = height_at(target.x, target.z) + 0.35 + absf(sin(_world_time * 2.0 + phase)) * 0.08
			if i!=0 or _escort_state.get("phase","idle")=="idle": node.rotation.y = phase + sin(_world_time * 0.7 + phase) * 0.5
		else:
			node.rotation.y = phase + sin(_world_time * 0.2 + phase) * 0.12
		if i==0 and not _escort_state.is_empty() and _escort_state.phase!="idle":
			var point: Dictionary=_escort_state.position
			target=Vector3(float(point.x),height_at(float(point.x),float(point.z))+0.35,float(point.z))
			var direction:=target-node.position
			if Vector2(direction.x,direction.z).length()>0.05:
				node.rotation.y=lerp_angle(node.rotation.y,atan2(-direction.x,-direction.z),1.0-exp(-delta*4.0))
			alarm=maxf(alarm,float(_escort_state.alarm))
			# A frightened animal visibly folds down; it waits rather than clipping through rocks while fleeing.
		node.position = node.position.lerp(target, 1.0 - exp(-delta * 5.0))
		var width := 1.0 + pulse * 0.12
		node.scale = Vector3(width, (1.0 - alarm * (0.55 if kind=="root_choir" else 0.3) if kind=="root_choir" or (i==0 and not _escort_state.is_empty()) else 1.0) + pulse * 0.1, width)
		var detailed=node.get_node_or_null("DetailedVisual")
		if detailed!=null:detailed.pose(_world_time+phase,alarm,pulse,1.0)
		for entry: Dictionary in _ecology_glow[i]:
			entry["material"].emission_energy_multiplier = float(entry["energy"]) * (1.0 + pulse * 2.0 - alarm * 0.65)

func reaction_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in _ecology_reactions.size():
		var reaction: RefCounted = _ecology_reactions[i]
		result.append({"kind": _ecology_meta[i]["kind"], "alert": reaction.alert, "recovery": reaction.recovery, "pulse": reaction.pulse})
	return result

func region_at(position: Vector3) -> String:
	if position.z > -10.0: return "aurora_shelf"
	if position.z > -170.0: return "ember_rift"
	if position.z > -350.0: return "veil_marsh"
	return "pale_decay"

func region_label(position: Vector3) -> String:
	return {"aurora_shelf":"Aurora Shelf / 極光高原", "ember_rift":"Ember Rift / 熱泉裂谷", "veil_marsh":"Veil Marsh / 濃霧沼澤", "pale_decay":"Pale Decay / 孢子衰變"}.get(region_at(position), "Unknown")

func set_region_mood(region: String, delta: float = 0.016) -> void:
	if not is_instance_valid(_environment): return
	var tint:=Color(0.12,0.16,0.25)
	var begin:=120.0
	var finish:=1400.0
	match region:
		"ember_rift":
			tint=Color(0.20,0.14,0.18);begin=80.0;finish=850.0
		"veil_marsh":
			tint=Color(0.11,0.18,0.25);begin=65.0;finish=680.0
		"pale_decay":
			tint=Color(0.20,0.17,0.23);begin=85.0;finish=1100.0
	var blend:=1.0-exp(-maxf(delta,0.0)*2.0)
	_environment.fog_light_color=_environment.fog_light_color.lerp(tint,blend)
	_environment.fog_light_energy=lerpf(_environment.fog_light_energy,0.72,blend)
	_environment.fog_depth_begin=lerpf(_environment.fog_depth_begin,begin,blend)
	_environment.fog_depth_end=lerpf(_environment.fog_depth_end,finish,blend)
	_environment.fog_depth_curve=lerpf(_environment.fog_depth_curve,1.15,blend)

func set_player_state(position: Vector3, speed: float) -> void:
	_player_position = position
	_player_speed = speed

func ecology_state(kind: String, position: Vector3) -> String:
	var index := -1
	var distance := INF
	for i in _ecology_nodes.size():
		if _ecology_meta[i]["kind"] != kind: continue
		var candidate := position.distance_to(_ecology_nodes[i].global_position)
		if candidate < distance: distance = candidate; index = i
	if index < 0 or distance >= 42.0: return "quiet"
	if _ecology_reactions[index].alert > 0.2: return "disturbed"
	if distance < 10.0 and absf(_player_speed) < 1.5: return str(_ecology_meta[index]["label"])
	return "near"

func nearest_ecology(position: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for i in _ecology_nodes.size():
		var distance := position.distance_to(_ecology_nodes[i].global_position)
		if distance < best_distance:
			best_distance = distance
			best = _ecology_meta[i].duplicate()
			best["index"] = i
			best["distance"] = distance
			best["position"] = _ecology_nodes[i].global_position + Vector3(0,0.3,0)
	return best

func observe_ecology(position: Vector3) -> Dictionary:
	var target := nearest_ecology(position)
	if target.is_empty() or float(target.get("distance", 999.0)) > 14.0: return {}
	var kind := str(target.get("kind", ""))
	_ecology_reactions[int(target["index"])].observe()
	_observed_regions[kind] = true
	target["observed"] = true
	return target

func survey_position(id: String) -> Vector3:
	var p: Vector2 = SURVEYS.point(id)
	return Vector3(p.x,height_at(p.x,p.y)+0.08,p.y)

func _build_survey_sites() -> void:
	for id in SURVEYS.SITES:
		var node := Node3D.new()
		node.name = "Survey_"+id
		node.position = survey_position(id)
		add_child(node)
		var body:=StaticBody3D.new()
		var collider:=CollisionShape3D.new()
		var box:=BoxShape3D.new()
		box.size=Vector3(2.2,2.4,0.8)
		collider.shape=box
		collider.position.y=1.2
		body.add_child(collider)
		node.add_child(body)
		var stone := _ecology_material(Color("7d8786"),Color.BLACK,0,0.85)
		stone.albedo_texture=load("res://assets/terrain/cc0/rock023_alb_ht.png")
		stone.uv1_triplanar=true
		var response := _ecology_material(Color("ad8751"),Color("d9a752"),0.6,0.45)
		for i in 3:
			var shard := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius=0.03;mesh.bottom_radius=0.23;mesh.height=1.2+0.5*i;mesh.radial_segments=5
			shard.mesh=mesh
			shard.material_override=stone
			shard.position=Vector3((i-1)*0.65,mesh.height/2,0)
			shard.rotation.z=(i-1)*0.12
			node.add_child(shard)
		_eco_sphere(node,Vector3(0,2.1,0),Vector3(0.20,0.10,0.20),response)
		_survey_materials[id]=response

func apply_survey_progress(data: Dictionary) -> void:
	var core: Dictionary=data.get("completed_regions",{})
	var extras: Dictionary=data.get("optional_observations",{})
	var fields: Dictionary=data.get("field_notes",{})
	for id in _survey_materials:
		var finished: bool=core.get(id,extras.get(id,fields.get(id,false)))
		var material: StandardMaterial3D=_survey_materials[id]
		material.albedo_color=Color("84c9c3") if finished else Color("ad8751")
		material.emission=material.albedo_color
		material.emission_energy_multiplier=1.3 if finished else 0.6


func _build_resonance_grove() -> void:
	var grove:=Node3D.new()
	grove.name="ResonanceGrove"
	grove.position=survey_position("aurora_echo")
	add_child(grove)
	var shades: Array[Color]=[Color("759da7"),Color("8b84ac"),Color("aea477")]
	for band in 3:
		var crystal:=Node3D.new()
		crystal.position=Vector3((band-1)*2.2,0,-2.2)
		grove.add_child(crystal)
		var glow:=_ecology_material(shades[band],shades[band],0.25,0.38)
		glow.albedo_texture=load("res://assets/terrain/cc0/rock023_alb_ht.png")
		glow.uv1_triplanar=true
		for tip in 3:
			var shard:=MeshInstance3D.new()
			var mesh:=CylinderMesh.new()
			mesh.top_radius=0.02;mesh.bottom_radius=0.24;mesh.height=2.2+0.55*band+0.22*tip;mesh.radial_segments=6
			shard.mesh=mesh;shard.material_override=glow
			shard.position=Vector3((tip-1)*0.38,mesh.height/2,0)
			shard.rotation.z=(tip-1)*0.18
			crystal.add_child(shard)
		var number:=Label3D.new()
		number.name="BandNumber";number.text=str(band+1);number.font_size=48;number.pixel_size=0.012
		number.position=Vector3(0,3.7+band*0.5,0)
		number.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		crystal.add_child(number)
		_resonance_crystals.append(crystal);_resonance_glows.append(glow)

func set_resonance_visual(band: int, complete: bool, delta: float = 0.0) -> void:
	_resonance_open=move_toward(_resonance_open,1.0 if complete else 0.0,maxf(0.0,delta)*0.6)
	for i in _resonance_crystals.size():
		var crystal:=_resonance_crystals[i]
		crystal.rotation.z=(1-i)*0.42*_resonance_open
		crystal.scale=Vector3.ONE*(1.0+_resonance_open*0.25)
		crystal.get_node("BandNumber").visible=not complete
		_resonance_glows[i].emission_energy_multiplier=1.6 if i==band else (0.65 if complete else 0.18)

func _build_escort_shelter() -> void:
	var shelter:=Node3D.new()
	shelter.name="WarmMineralShelter"
	var z: float=-157.0
	shelter.position=Vector3(path_x(z),height_at(path_x(z),z),z)
	add_child(shelter)
	_shelter_material=_ecology_material(Color("7f6848"),Color("c68a46"),0.12,0.83)
	_shelter_material.albedo_texture=load("res://assets/terrain/cc0/rock023_alb_ht.png")
	_shelter_material.uv1_triplanar=true
	for side in [-1.0,1.0]:
		for step in 3:
			var stone:=MeshInstance3D.new()
			stone.mesh=_low_meshes[step%_low_meshes.size()] if not _low_meshes.is_empty() else SphereMesh.new()
			stone.scale=Vector3(0.65+step*0.12,0.45+step*0.08,0.75)
			var local_x: float=side*(2.2+step*0.2)
			var local_z: float=-1.0+step
			var foot: float=height_at(shelter.position.x+local_x,z+local_z)-shelter.position.y
			stone.position=Vector3(local_x,foot-stone.mesh.get_aabb().position.y*stone.scale.y,local_z)
			stone.material_override=_shelter_material
			shelter.add_child(stone)

func set_escort_state(data: Dictionary, instant: bool = false) -> void:
	_escort_state=data
	if instant and data.phase!="idle":
		_ecology_nodes[0].position=Vector3(data.position.x,height_at(data.position.x,data.position.z)+0.35,data.position.z)
	if instant:
		_apply_cool_gather(true)
	_apply_thermal_outcome()

func thermal_pulse() -> float:
	return (1.0+sin(_world_time*TAU/6.0))*0.5

func set_thermal_state(data: Dictionary, instant: bool = false) -> void:
	var route:=str(data.get("route","warm"))
	if route not in ["warm","cool"]: route="warm"
	_thermal_state={"vent_observed":bool(data.get("vent_observed",false)),"route":route,"locked":bool(data.get("locked",false))}
	if instant:
		_thermal_open=1.0 if _thermal_state.vent_observed else 0.0
		_apply_cool_gather(true)
	_apply_thermal_visual()
	_apply_thermal_outcome()

func _thermal_vent_open(value: float = -1.0) -> float:
	if value>=0.0:
		_thermal_open=clampf(value,0.0,1.0)
		_apply_thermal_visual()
	return _thermal_open

func _apply_cool_gather(instant: bool) -> void:
	if not instant or _ecology_nodes.size()<4: return
	if not bool(_escort_state.get("complete",false)) or str(_thermal_state.get("route","warm"))!="cool": return
	var targets := [Vector2(-64.0,-143.0),Vector2(-57.0,-147.0),Vector2(-64.0,-151.0)]
	for i in range(1,4):
		var point: Vector2=targets[i-1]
		_ecology_nodes[i].position=Vector3(point.x,height_at(point.x,point.y)+0.35,point.y)

func _apply_thermal_outcome() -> void:
	var complete:=bool(_escort_state.get("complete",false))
	var route:=str(_thermal_state.get("route","warm"))
	if is_instance_valid(_shelter_material):
		_shelter_material.emission_energy_multiplier=(0.38+thermal_pulse()*0.08) if complete and route=="warm" else 0.12
	if is_instance_valid(_cool_bed_material):
		_cool_bed_material.emission_energy_multiplier=(0.52+thermal_pulse()*0.12) if complete and route=="cool" else 0.035

func _tick_thermal(delta: float) -> void:
	var target:=1.0 if bool(_thermal_state.get("vent_observed",false)) else 0.0
	_thermal_open=move_toward(_thermal_open,target,delta*1.5)
	_apply_thermal_visual()
	_apply_thermal_outcome()

func _apply_thermal_visual() -> void:
	if not is_instance_valid(_thermal_vent): return
	var pulse:=thermal_pulse()
	for plate_data: Dictionary in _thermal_vent_plates:
		var plate: Node3D=plate_data.node
		var side: float=plate_data.side
		plate.position=plate_data.closed_position+Vector3(side*_thermal_open*0.42,_thermal_open*0.22,0.0)
		plate.rotation.z=float(plate_data.closed_rotation)+side*_thermal_open*0.62
	var route:=str(_thermal_state.get("route","warm"))
	var cue_color:=Color("cf8c4d") if route=="warm" else Color("63b9c6")
	if is_instance_valid(_thermal_cue_material):
		_thermal_cue_material.albedo_color=cue_color
		_thermal_cue_material.emission=cue_color
		_thermal_cue_material.emission_energy_multiplier=(0.08 if not bool(_thermal_state.get("locked",false)) else 0.16)+pulse*0.035
	for i in _thermal_steam.size():
		var steam:=_thermal_steam[i]
		var phase:=float(i)*1.9
		var lift:=fposmod(_world_time*0.24+float(i)/float(_thermal_steam.size()),1.0)
		steam.position=Vector3(sin(_world_time*0.55+phase)*0.18,2.2+lift*2.0,cos(_world_time*0.43+phase)*0.16)
		var puff:=0.32+lift*0.3+pulse*0.035
		steam.scale=Vector3(puff*0.7,puff,puff*0.7)
	if is_instance_valid(_thermal_steam_material):
		_thermal_steam_material.albedo_color=Color(0.72,0.75,0.73,0.055+0.035*pulse)

func _build_thermal_route() -> void:
	_thermal_vent=Node3D.new()
	_thermal_vent.name="ThermalVent"
	_thermal_vent.position=survey_position("ember_vent")+Vector3(0,0,-3)
	add_child(_thermal_vent)
	var vent_rock:=_passage_material(Color("4b4038"))
	vent_rock.emission_energy_multiplier=0.0
	for i in 6:
		var angle:=float(i)/6.0*TAU
		var stone:=MeshInstance3D.new()
		stone.mesh=_low_meshes[i%_low_meshes.size()] if not _low_meshes.is_empty() else SphereMesh.new()
		stone.material_override=vent_rock
		stone.position=Vector3(cos(angle)*0.85,0.34+float(i%2)*0.28,sin(angle)*0.72)
		stone.rotation=Vector3(0.08*sin(angle),angle,0.12*cos(angle))
		stone.scale=Vector3(0.46,0.5+float(i%2)*0.18,0.42)
		_thermal_vent.add_child(stone)
	for side in [-1.0,1.0]:
		var plate:=MeshInstance3D.new()
		plate.mesh=_low_meshes[0] if not _low_meshes.is_empty() else SphereMesh.new()
		plate.material_override=vent_rock
		plate.position=Vector3(side*0.46,1.1,0.0)
		plate.rotation=Vector3(0.0,0.18*side,0.12*side)
		plate.scale=Vector3(0.44,0.16,0.58)
		_thermal_vent.add_child(plate)
		_thermal_vent_plates.append({"node":plate,"side":side,"closed_position":plate.position,"closed_rotation":plate.rotation.z})
	_thermal_cue_material=_ecology_material(Color("cf8c4d"),Color("cf8c4d"),0.08,0.45)
	for side in [-1.0,1.0]:
		_eco_rod(_thermal_vent,Vector3(side*0.2,0.7,-0.48),Vector3(side*0.46,1.34,-0.34),0.035,_thermal_cue_material)
	_thermal_steam_material=_ecology_material(Color(0.72,0.75,0.73,0.07),Color.BLACK,0.0,1.0)
	_thermal_steam_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	_thermal_steam_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 3:
		var steam:=_eco_sphere(_thermal_vent,Vector3(0,2.2+float(i)*0.6,0),Vector3(0.3,0.45,0.3),_thermal_steam_material)
		steam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_thermal_steam.append(steam)
	var bed:=Node3D.new()
	bed.name="CoolMineralBed"
	var bed_point:=Vector2(-60.0,-145.0)
	bed.position=Vector3(bed_point.x,height_at(bed_point.x,bed_point.y),bed_point.y)
	add_child(bed)
	var bed_rock:=_passage_material(Color("354246"))
	bed_rock.emission_energy_multiplier=0.0
	for i in 9:
		var angle:=float(i)/9.0*TAU
		var stone:=MeshInstance3D.new()
		stone.mesh=_low_meshes[i%_low_meshes.size()] if not _low_meshes.is_empty() else SphereMesh.new()
		stone.material_override=bed_rock
		stone.position=Vector3(cos(angle)*3.1,0.18+0.12*sin(angle*2.0),sin(angle)*2.35)
		stone.rotation.y=angle+PI*0.5
		stone.scale=Vector3(0.62,0.24,0.74)
		bed.add_child(stone)
	_cool_bed_material=_ecology_material(Color("467078"),Color("66c6d0"),0.035,0.38)
	for i in 5:
		var angle:=float(i)/5.0*TAU+0.35
		_eco_rod(bed,Vector3(cos(angle)*0.35,0.16,sin(angle)*0.3),Vector3(cos(angle)*2.25,0.22,sin(angle)*1.65),0.055,_cool_bed_material)

func _build_atmosphere() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.48, 0.57, 0.76)
	_environment.ambient_light_energy = 0.48
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_exposure = 0.9
	_environment.fog_enabled = true
	_environment.fog_mode = Environment.FOG_MODE_DEPTH
	_environment.fog_light_color = Color(0.215, 0.225, 0.31)
	_environment.fog_light_energy = 0.72
	_environment.fog_depth_begin = 95.0
	_environment.fog_depth_end = 1400.0
	_environment.fog_depth_curve = 1.15
	_environment.fog_sky_affect = 0.08
	var world_environment := WorldEnvironment.new()
	world_environment.name = "BasinAtmosphere"
	world_environment.environment = _environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "LowWarmSun"
	sun.rotation_degrees = Vector3(-36.0, -40.0, 0.0)
	sun.light_color = Color(0.72, 0.81, 1.0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.06
	add_child(sun)
	for location in [Vector2(path_x(-242)-13,-242),Vector2(path_x(-328)-25,-328),Vector2(path_x(-88)+16,-88)]:
		var fill:=OmniLight3D.new();fill.position=Vector3(location.x,height_at(location.x,location.y)+3.0,location.y)
		fill.light_color=Color("dbac72") if location.y>-150 else Color("65c1ce")
		fill.light_energy=.7;fill.omni_range=18;fill.shadow_enabled=false;add_child(fill)

func _build_material() -> void:
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = TERRAIN_SHADER
	_terrain_material.set_shader_parameter("basalt_map", load("res://assets/terrain/basalt_albedo.png"))
	_terrain_material.set_shader_parameter("dust_map", load("res://assets/terrain/dust_albedo.png"))
	_terrain_material.set_shader_parameter("normal_map", load("res://assets/terrain/geology_normal.png"))
	_terrain_material.set_shader_parameter("rough_map", load("res://assets/terrain/geology_roughness.png"))
	_strata_material = ShaderMaterial.new()
	_strata_material.shader = STRATA_SHADER
	_strata_material.set_shader_parameter("basalt_map", load("res://assets/terrain/basalt_albedo.png"))
	_strata_material.set_shader_parameter("rough_map", load("res://assets/terrain/geology_roughness.png"))

func _build_terrain() -> void:
	const NX := 155
	const NZ := 193
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tangents := PackedFloat32Array()
	var indices := PackedInt32Array()
	vertices.resize(NX * NZ)
	normals.resize(NX * NZ)
	uvs.resize(NX * NZ)
	tangents.resize(NX * NZ * 4)
	for iz in NZ:
		for ix in NX:
			var x := -192.0 + ix * (384.0 / float(NX - 1))
			var z := -700.0 + float(iz) * (900.0 / float(NZ - 1))
			var i := iz * NX + ix
			vertices[i] = Vector3(x, height_at(x, z), z)
			var dx := (height_at(x + 0.15, z) - height_at(x - 0.15, z)) / 0.3
			var dz := (height_at(x, z + 0.15) - height_at(x, z - 0.15)) / 0.3
			normals[i] = Vector3(-dx, 1.0, -dz).normalized()
			uvs[i] = Vector2(x, z) * 0.11
			var tangent := Vector3(1.0, dx, 0.0).normalized()
			tangents[i * 4] = tangent.x
			tangents[i * 4 + 1] = tangent.y
			tangents[i * 4 + 2] = tangent.z
			tangents[i * 4 + 3] = 1.0
	for iz in NZ - 1:
		for ix in NX - 1:
			var a := iz * NX + ix
			indices.append_array(PackedInt32Array([a, a + 1, a + NX, a + 1, a + NX + 1, a + NX]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var terrain := MeshInstance3D.new()
	terrain.name = "CollidableDustBasin"
	terrain.mesh = mesh
	terrain.material_override = _terrain_material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)
	terrain.create_trimesh_collision()
	build_stats["terrain_triangles"] = indices.size() / 3

func _build_horizon() -> void:
	# A continuous asymmetrical crater ring; four authored high sectors flank a low signal gap.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 256
	const RINGS := 17
	for r in RINGS - 1:
		for a in SEGMENTS:
			var p0 := _horizon_point(a, r)
			var p1 := _horizon_point(a + 1, r)
			var p2 := _horizon_point(a, r + 1)
			var p3 := _horizon_point(a + 1, r + 1)
			for p: Vector3 in [p0, p2, p1, p1, p2, p3]:
				st.set_uv(Vector2(p.x, p.z) * 0.008)
				st.add_vertex(p)
	st.generate_normals()
	st.generate_tangents()
	var rim := MeshInstance3D.new()
	rim.name = "AuthoredDistantCaldera"
	rim.mesh = st.commit()
	rim.material_override = _strata_material
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)
	build_stats["horizon_triangles"] = SEGMENTS * (RINGS - 1) * 2

func _horizon_point(a: int, r: int) -> Vector3:
	var angle := float(a) / 256.0 * TAU
	var radial := float(r) / 16.0
	# Bury the inner seam inside the rectangular ground skirt, beyond all driving bounds.
	# The old 180m circular hole crossed the expanded southern play area.
	var inner_radius := minf(170.0 / maxf(absf(cos(angle)), 0.0001), 445.0 / maxf(absf(sin(angle)), 0.0001))
	var radius := inner_radius + pow(radial, 1.25) * 1250.0
	var x := cos(angle) * radius
	var z := -250.0 + sin(angle) * radius
	var foothill := height_at(x, z)
	var peak := 130.0 + 58.0 * sin(angle * 3.0 + 0.4) + 32.0 * sin(angle * 7.0) + 21.0 * sin(angle * 13.0 + 1.0) + 11.0 * sin(angle * 47.0) + 7.0 * sin(angle * 73.0)
	# Signal corridor points north; the far gap frames the mineral silhouette.
	peak *= 1.0 - 0.64 * exp(-pow((angle - 4.71) / 0.24, 2.0))
	var ridge := exp(-pow((radial - 0.37) / 0.19, 2.0)) * peak
	var fissures := absf(sin(angle * 35.0 + sin(radial * 13.0))) * 0.13 + absf(sin(angle * 61.0 + radial * 17.0)) * 0.07
	ridge *= 1.0 - fissures
	# Unequal lava benches interrupt the continuous soft cone profile.
	ridge += sin(radial * 61.0 + angle * 4.0) * 5.5 * smoothstep(0.08, 0.25, radial)
	var height := lerpf(foothill - 3.0, ridge + 10.0, smoothstep(0.0, 0.18, radial))
	return Vector3(x, height, z)

func _build_landmarks() -> void:
	# Three eroded wall fins form an offset cleft; the path remains open for its full 10 m width.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cleft_x := path_x(30.0)
	_append_fault_fin(st, Vector3(cleft_x - 13.5, 0, 31), Vector3(5.5, 14, 9), -0.15, 1)
	_append_fault_fin(st, Vector3(cleft_x - 19.5, 0, 27), Vector3(5.0, 11.5, 11), -0.22, 2)
	_append_fault_fin(st, Vector3(cleft_x + 12.5, 0, 22), Vector3(4.5, 11, 8), 0.16, 3)
	# The second landmark has three mismatched fracture blades and a collapsed foot slab.
	var split_x := path_x(-70.0)
	_append_fault_fin(st, Vector3(split_x + 16.0, 0, -69), Vector3(3.3, 17, 5), 0.25, 4)
	_append_fault_fin(st, Vector3(split_x + 21.7, 0, -72), Vector3(2.8, 13, 4.2), -0.2, 5)
	_append_fault_fin(st, Vector3(split_x + 25.8, 0, -76), Vector3(3.9, 9, 6), -0.35, 6)
	_append_fault_fin(st, Vector3(split_x + 18.8, 0, -65), Vector3(7, 3.0, 7), 0.4, 7)
	st.generate_normals()
	st.generate_tangents()
	var landmark := MeshInstance3D.new()
	landmark.name = "CleftAndFractureLandmarks"
	landmark.mesh = st.commit()
	landmark.material_override = _strata_material
	add_child(landmark)
	landmark.create_trimesh_collision()
	build_stats["landmark_triangles"] = _triangle_count(landmark.mesh)

func _ecology_material(color: Color, emission: Color = Color.BLACK, energy: float = 0.0, roughness: float = 0.65) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	return mat

func _eco_sphere(parent: Node3D, position: Vector3, scale: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 10
	mesh.rings = 6
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.scale = scale
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _eco_cylinder(parent: Node3D, position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _eco_rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var rod := _eco_cylinder(parent, (a + b) * 0.5, radius, a.distance_to(b), material)
	rod.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func _passage_material(color: Color) -> StandardMaterial3D:
	var material := _ecology_material(color, Color("65aaa0"), 0.12, 0.64)
	material.albedo_texture = load("res://assets/terrain/cc0/rock023_alb_ht.png")
	material.normal_enabled = true
	material.normal_texture = load("res://assets/terrain/cc0/rock023_nrm_rgh.png")
	material.normal_scale = 0.32
	material.roughness_texture = material.normal_texture
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.36
	return material

func _build_passage_gates() -> void:
	var route := passage_route()
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radial_segments = 8
	leaf_mesh.rings = 6
	var rib_material := _passage_material(Color("36544f"))
	rib_material.emission_energy_multiplier = 0.04
	for i in route.size():
		var center := route[i]
		var gate := Node3D.new()
		gate.name = "QuietPassageGate%d" % i
		gate.position = Vector3(center.x, height_at(center.x, center.y), center.y)
		var previous := route[maxi(0, i - 1)]
		var following := route[mini(route.size() - 1, i + 1)]
		var travel := Vector3(following.x - previous.x, 0.0, following.y - previous.y).normalized()
		gate.rotation.y = atan2(-travel.x, -travel.z)
		add_child(gate)
		var material := _passage_material(Color("496f67"))
		var wings: Array[Node3D] = []
		for side in [-1.0, 1.0]:
			var wing := Node3D.new()
			wing.name = "MembraneLeft" if side < 0.0 else "MembraneRight"
			var anchor := Vector3(side * 8.6, 0.0, 0.0)
			var world_anchor := gate.position + gate.basis * anchor
			# An offset gate must leave both its own opening and the main driving road clear.
			var road_x:=path_x(world_anchor.z)
			if absf(world_anchor.x-road_x)<9.0:
				world_anchor.x=road_x+side*9.0
				anchor=gate.basis.inverse()*(world_anchor-gate.position)
			anchor.y = height_at(world_anchor.x, world_anchor.z) - gate.position.y
			wing.position = anchor
			gate.add_child(wing)
			for leaf_index in 3:
				var leaf := MeshInstance3D.new()
				leaf.name = "LeafFin%d" % leaf_index
				leaf.mesh = leaf_mesh
				leaf.material_override = material
				leaf.position = Vector3(side * (0.22 + leaf_index * 0.12), 1.8 + leaf_index * 0.68, (leaf_index - 1) * 1.05)
				leaf.scale = Vector3(0.62 - leaf_index * 0.07, 2.15 + leaf_index * 0.42, 0.24)
				leaf.rotation = Vector3(0.08 * (leaf_index - 1), side * 0.12 * leaf_index, side * (0.13 + leaf_index * 0.04))
				wing.add_child(leaf)
			var body := StaticBody3D.new()
			body.name = "MembraneBankCollision"
			var collider := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.6, 3.6, 2.0)
			collider.shape = box
			collider.position.y = 1.8
			body.add_child(collider)
			body.position = anchor
			gate.add_child(body)
			wings.append(wing)
			# The ribs stay beyond the six-metre drive circle and visually root the soft fins.
			_eco_rod(gate, Vector3(side * 7.2, 0.28, -2.1), Vector3(side * 9.4, 0.72, -0.55), 0.12, rib_material)
			_eco_rod(gate, Vector3(side * 7.2, 0.28, 2.1), Vector3(side * 9.4, 0.72, 0.55), 0.12, rib_material)
		_passage_gates.append(gate)
		_passage_wings.append(wings)
		_passage_materials.append(material)
		_passage_open.append(0.0)
	build_stats["quiet_passage_gates"] = _passage_gates.size()

func set_passage_state(data: Dictionary, delta: float = 0.0, instant: bool = false) -> void:
	var phase := str(data.get("phase", "idle"))
	if phase not in ["idle", "crossing", "scattered", "complete"]: phase = "idle"
	_passage_state = {
		"phase":phase,
		"gate":clampi(int(data.get("gate", 0)), 0, PASSAGE_Z.size()),
		"alarm":clampf(float(data.get("alarm", 0.0)), 0.0, 2.0)
	}
	if instant or delta > 0.0: _tick_passage_gates(maxf(delta, 0.0), instant)

func _tick_passage_gates(delta: float, instant: bool = false) -> void:
	if _passage_gates.is_empty(): return
	var phase := str(_passage_state.get("phase", "idle"))
	var next_gate := clampi(int(_passage_state.get("gate", 0)), 0, PASSAGE_Z.size())
	var alarm := clampf(float(_passage_state.get("alarm", 0.0)), 0.0, 2.0)
	for i in _passage_gates.size():
		var completed := phase == "complete" or i < next_gate
		var active := not completed and i == next_gate and next_gate < PASSAGE_Z.size()
		var scattered := phase == "scattered" and active
		var target_open := 1.0 if completed else (-0.42 if scattered else (0.12 if active else 0.0))
		_passage_open[i] = target_open if instant else move_toward(_passage_open[i], target_open, delta * 1.7)
		for wing_index in _passage_wings[i].size():
			var wing: Node3D = _passage_wings[i][wing_index]
			var side := -1.0 if wing_index == 0 else 1.0
			wing.rotation.y = side * (0.18 + _passage_open[i] * 0.72)
			var breathe := 1.0 + (0.018 * (0.5 + 0.5 * sin(_world_time * 2.0 + i)) if active and not scattered else 0.0)
			wing.scale = Vector3(breathe, 1.0 + (breathe - 1.0) * 0.6, breathe)
		var material := _passage_materials[i]
		if scattered:
			material.albedo_color = Color("7a6748").lerp(Color("9a7444"), alarm * 0.16)
			material.emission = Color("9c7442")
			material.emission_energy_multiplier = 0.08 + alarm * 0.05
		elif completed:
			material.albedo_color = Color("47766c")
			material.emission = Color("69b9ad")
			material.emission_energy_multiplier = 0.16
		elif active:
			var pulse := 0.5 + 0.5 * sin(_world_time * 2.0 + i)
			material.albedo_color = Color("496f67").lerp(Color("5d8d83"), pulse * 0.12)
			material.emission = Color("65aaa0")
			material.emission_energy_multiplier = 0.11 + pulse * 0.08
		else:
			material.albedo_color = Color("45645d")
			material.emission = Color("56877f")
			material.emission_energy_multiplier = 0.07

func _root_network_material(color: Color, emission: Color = Color("936846"), energy: float = 0.04) -> StandardMaterial3D:
	var material := _passage_material(color)
	material.emission = emission
	material.emission_energy_multiplier = energy
	material.uv1_scale = Vector3.ONE * 0.48
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _root_ground_rock(parent: Node3D, local_position: Vector3, scale: Vector3, material: Material, salt: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh: Mesh
	if _low_meshes.is_empty():
		mesh = SphereMesh.new()
	else:
		mesh = _low_meshes[posmod(salt, _low_meshes.size())]
	instance.mesh = mesh
	instance.scale = scale
	instance.material_override = material
	instance.rotation = Vector3(0.06 * sin(float(salt)), float(salt) * 0.73, 0.05 * cos(float(salt)))
	var world_x := parent.position.x + local_position.x
	var world_z := parent.position.z + local_position.z
	var bounds := mesh.get_aabb()
	instance.position = Vector3(
		local_position.x,
		height_at(world_x, world_z) - parent.position.y - bounds.position.y * scale.y,
		local_position.z
	)
	parent.add_child(instance)
	return instance

func _root_stump_endpoint(relay_index: int, port: int) -> Vector2:
	var center := root_network_points()[relay_index]
	var side := 1.0 if ROOT_NETWORK_X_OFFSETS[relay_index] > 0.0 else -1.0
	var z := center.y - 10.0 + float(port) * 9.0 + float(relay_index % 2) * 2.0
	var x := center.x + side * (7.0 + float(port) * 1.7)
	if absf(x - path_x(z)) < 10.0:
		x = path_x(z) + side * (10.0 + float(port))
	return Vector2(x, z)

func _root_conduit_mesh(start: Vector2, endpoint: Vector2, bend: float, salt: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var travel := endpoint - start
	var normal := Vector2(-travel.y, travel.x).normalized()
	const SEGMENTS := 28
	for segment in SEGMENTS:
		var quad: Array[Vector3] = []
		var quad_uv: Array[Vector2] = []
		for step in 2:
			var t := float(segment + step) / float(SEGMENTS)
			var curve := sin(t * PI) * bend + sin(t * TAU * 2.0 + float(salt)) * sin(t * PI) * 0.32
			var center := start.lerp(endpoint, t) + normal * curve
			var width := lerpf(0.2, 0.11, t) * (0.9 + 0.1 * sin(t * 19.0 + float(salt)))
			for side in [-1.0, 1.0]:
				var point: Vector2 = center + normal * width * side
				quad.append(Vector3(point.x, height_at(point.x, point.y) + 0.105, point.y))
				quad_uv.append(Vector2(t * 8.0, (side + 1.0) * 0.5))
		for index: int in [0, 1, 2, 1, 3, 2]:
			st.set_uv(quad_uv[index])
			st.add_vertex(quad[index])
	st.generate_normals()
	return st.commit()

func _build_root_network() -> void:
	var points := root_network_points()
	var shell_material := _root_network_material(Color("4b3a3f"), Color("795841"), 0.035)
	for relay_index in 3:
		var center: Vector2 = points[relay_index]
		var relay := Node3D.new()
		relay.name = "RootRelay%d" % relay_index
		relay.position = Vector3(center.x, height_at(center.x, center.y), center.y)
		add_child(relay)
		_root_ground_rock(relay, Vector3.ZERO, Vector3(2.5, 0.62, 1.8), shell_material, relay_index + 2)
		for lobe in 3:
			var lobe_angle := float(lobe) * TAU / 3.0 + float(relay_index) * 0.47
			var lobe_position := Vector3(cos(lobe_angle) * (1.8 + lobe * 0.25), 0.0, sin(lobe_angle) * (1.8 + lobe * 0.25))
			_root_ground_rock(relay, lobe_position, Vector3(1.1 + lobe * 0.16, 0.36 + lobe * 0.07, 0.72), shell_material, relay_index * 5 + lobe + 4)
		var selector_material := _root_network_material(Color("76523b"), Color("b77b45"), 0.16)
		var rotor := Node3D.new()
		rotor.name = "PortRotor"
		rotor.position.y = 0.42
		relay.add_child(rotor)
		_eco_sphere(rotor, Vector3(0.0, 0.14, 0.0), Vector3(0.72, 0.2, 0.72), selector_material)
		_eco_rod(rotor, Vector3(0.0, 0.13, 0.1), Vector3(0.0, 0.15, -2.8), 0.13, selector_material)
		_eco_sphere(rotor, Vector3(0.0, 0.15, -2.8), Vector3(0.3, 0.16, 0.42), selector_material)
		_root_relays.append(relay)
		_root_relay_rotors.append(rotor)
		_root_selector_materials.append(selector_material)
		var conduit_row: Array = []
		var material_row: Array = []
		var endpoint_row: Array = []
		var angle_row: Array = []
		for port in 3:
			var endpoint: Vector2 = points[relay_index + 1] if port == ROOT_NETWORK_SOLUTION[relay_index] else _root_stump_endpoint(relay_index, port)
			endpoint_row.append(endpoint)
			var direction := (endpoint - center).normalized()
			angle_row.append(atan2(-direction.x, -direction.y))
			var conduit_material := _root_network_material(Color("332b2d"), Color("9a6840"), 0.025)
			var conduit := MeshInstance3D.new()
			conduit.name = "RootConduit%d_%d" % [relay_index, port]
			var bend_sign := -1.0 if (relay_index + port) % 2 == 0 else 1.0
			conduit.mesh = _root_conduit_mesh(center, endpoint, bend_sign * (2.2 + port * 0.45), relay_index * 3 + port)
			conduit.material_override = conduit_material
			conduit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(conduit)
			conduit_row.append(conduit)
			material_row.append(conduit_material)
			var marker_position := Vector3(direction.x * 3.2, 0.0, direction.y * 3.2)
			marker_position.y = height_at(relay.position.x + marker_position.x, relay.position.z + marker_position.z) - relay.position.y + 0.13
			_eco_sphere(relay, marker_position, Vector3(0.42, 0.13, 0.58), conduit_material)
			if port != ROOT_NETWORK_SOLUTION[relay_index]:
				var stump := Node3D.new()
				stump.name = "RootStump%d_%d" % [relay_index, port]
				stump.position = Vector3(endpoint.x, height_at(endpoint.x, endpoint.y), endpoint.y)
				add_child(stump)
				_root_ground_rock(stump, Vector3.ZERO, Vector3(1.45, 0.42, 1.05), shell_material, relay_index * 7 + port + 12)
				for twig in 2:
					var twig_angle := float(twig) * 1.7 + relay_index
					_eco_rod(stump, Vector3(0.0, 0.16, 0.0), Vector3(cos(twig_angle) * 1.6, 0.18, sin(twig_angle) * 1.6), 0.07, shell_material)
		_root_conduits.append(conduit_row)
		_root_conduit_materials.append(material_row)
		_root_network_endpoints.append(endpoint_row)
		_root_port_angles.append(angle_row)
	var terminal_point: Vector2 = points[3]
	var terminal := Node3D.new()
	terminal.name = "RootTerminal"
	terminal.position = Vector3(terminal_point.x, height_at(terminal_point.x, terminal_point.y), terminal_point.y)
	add_child(terminal)
	for pad in 5:
		var pad_angle := float(pad) / 5.0 * TAU + 0.35
		var pad_position := Vector3(cos(pad_angle) * (2.2 + 0.25 * (pad % 2)), 0.0, sin(pad_angle) * (2.2 + 0.25 * (pad % 2)))
		_root_ground_rock(terminal, pad_position, Vector3(1.45, 0.34 + 0.05 * (pad % 2), 0.85), shell_material, pad + 31)
		_eco_rod(terminal, Vector3(0.0, 0.16, 0.0), Vector3(pad_position.x, 0.18, pad_position.z), 0.09, shell_material)
	var shell_mesh: Mesh = _low_meshes[0] if not _low_meshes.is_empty() else SphereMesh.new()
	for shell_index in 2:
		var side := -1.0 if shell_index == 0 else 1.0
		var shell := Node3D.new()
		shell.name = "TerminalShellLeft" if side < 0.0 else "TerminalShellRight"
		shell.position = Vector3(side * 1.1, 0.0, 0.0)
		terminal.add_child(shell)
		var shell_piece := MeshInstance3D.new()
		shell_piece.mesh = shell_mesh
		shell_piece.scale = Vector3(1.65, 0.65, 1.1)
		shell_piece.position.y = -shell_mesh.get_aabb().position.y * shell_piece.scale.y
		shell_piece.rotation.y = side * 0.34
		shell_piece.material_override = shell_material
		shell.add_child(shell_piece)
		_root_terminal_shells.append(shell)
		_root_terminal_shell_origins.append(shell.position)
	_root_terminal_glow_material = _root_network_material(Color("315a58"), Color("6bc9c0"), 0.08)
	_root_terminal_glow = Node3D.new()
	_root_terminal_glow.name = "RootTerminalGlow"
	_root_terminal_glow.position.y=0.35
	terminal.add_child(_root_terminal_glow)
	_eco_rod(_root_terminal_glow,Vector3.ZERO,Vector3(0,1.65,0),0.11,_root_terminal_glow_material)
	for branch in 5:
		var angle:=branch*TAU/5.0+0.4
		var stem:=Vector3(0,0.5+branch*0.18,0)
		var elbow:=stem+Vector3(cos(angle)*0.48,0.48,sin(angle)*0.48)
		var tip:=elbow+Vector3(cos(angle)*0.27,0.43,sin(angle)*0.27)
		_eco_rod(_root_terminal_glow,stem,elbow,0.065,_root_terminal_glow_material)
		_eco_rod(_root_terminal_glow,elbow,tip,0.045,_root_terminal_glow_material)
		_eco_sphere(_root_terminal_glow,tip,Vector3(0.12,0.24,0.12),_root_terminal_glow_material)
	build_stats["root_network_relays"] = _root_relays.size()
	build_stats["root_network_conduits"] = 9

func set_root_network_state(data: Dictionary, instant: bool = false) -> void:
	var incoming_ports = data.get("ports", [0, 0, 0])
	var ports: Array[int] = []
	for i in 3:
		var value := int(incoming_ports[i]) if incoming_ports is Array and incoming_ports.size() > i else 0
		ports.append(clampi(value, 0, 2))
	_root_network_state = {
		"ports":ports,
		"powered":clampi(int(data.get("powered", 0)), 0, 3),
		"complete":bool(data.get("complete", false))
	}
	if instant:
		_root_network_open = 1.0 if _root_network_state.complete else 0.0
		_tick_root_network(0.0, true)

func _tick_root_network(delta: float, instant: bool = false) -> void:
	if _root_relays.is_empty(): return
	var ports: Array = _root_network_state.get("ports", [0, 0, 0])
	var powered_count := clampi(int(_root_network_state.get("powered", 0)), 0, 3)
	var complete := bool(_root_network_state.get("complete", false))
	var pulse := 0.5 + 0.5 * sin(_world_time * 2.2)
	for relay_index in _root_relays.size():
		var selected_port := clampi(int(ports[relay_index]), 0, 2)
		var target_angle := float(_root_port_angles[relay_index][selected_port])
		var rotor := _root_relay_rotors[relay_index]
		rotor.rotation.y = target_angle if instant else lerp_angle(rotor.rotation.y, target_angle, 1.0 - exp(-delta * 5.0))
		var relay_powered := relay_index < powered_count or complete
		var selector_material := _root_selector_materials[relay_index]
		selector_material.albedo_color = Color("4d8b87") if relay_powered else Color("76523b")
		selector_material.emission = Color("6bc9c0") if relay_powered else Color("b77b45")
		selector_material.emission_energy_multiplier = (0.25 + pulse * 0.1) if relay_powered else (0.12 + pulse * 0.05)
		for port in 3:
			var material: StandardMaterial3D = _root_conduit_materials[relay_index][port]
			var energized: bool = (port == selected_port and relay_index < powered_count) or (complete and port == ROOT_NETWORK_SOLUTION[relay_index])
			var selected: bool = port == selected_port and relay_index == powered_count and not complete
			if energized:
				material.albedo_color = Color("426e6b")
				material.emission = Color("65c5bc")
				material.emission_energy_multiplier = 0.25 + pulse * 0.12
			elif selected:
				material.albedo_color = Color("65462f")
				material.emission = Color("b87842")
				material.emission_energy_multiplier = 0.12 + pulse * 0.08
			else:
				material.albedo_color = Color("332b2d")
				material.emission = Color("805235")
				material.emission_energy_multiplier = 0.025
	var target_open := 1.0 if complete else 0.0
	_root_network_open = target_open if instant else move_toward(_root_network_open, target_open, delta * 0.55)
	for shell_index in _root_terminal_shells.size():
		var side := -1.0 if shell_index == 0 else 1.0
		var shell := _root_terminal_shells[shell_index]
		shell.position = _root_terminal_shell_origins[shell_index] + Vector3(side * _root_network_open * 1.45, _root_network_open * 0.28, 0.0)
		shell.rotation.z = side * (0.08 + _root_network_open * 0.5)
	if is_instance_valid(_root_terminal_glow):
		var glow_scale := lerpf(0.45, 0.9, _root_network_open)
		if complete: glow_scale *= 1.0 + pulse * 0.045
		_root_terminal_glow.scale = Vector3.ONE * glow_scale
		_root_terminal_glow_material.albedo_color = Color("315a58").lerp(Color("528f84"), _root_network_open)
		_root_terminal_glow_material.emission_energy_multiplier = lerpf(0.08, 0.32 + pulse * 0.10, _root_network_open)

func _build_ecology() -> void:
	# Three local organisms occupy different energy gradients. They are deliberately readable silhouettes, not decorative glow props.
	var veyra_shell := _ecology_material(Color("536265"), Color("a86b3f"), 0.08, 0.72)
	veyra_shell.albedo_texture=load("res://assets/terrain/cc0/rock023_alb_ht.png")
	veyra_shell.normal_enabled=true;veyra_shell.normal_texture=load("res://assets/terrain/cc0/rock023_nrm_rgh.png");veyra_shell.uv1_triplanar=true
	var veyra_core := _ecology_material(Color("b56b42"), Color("e47d42"), 1.0, 0.48)
	for i in 4:
		var node := Node3D.new()
		node.name = "VeyraLithovore_%02d" % i
		var z := -105.0 + i * 7.0
		var x := path_x(z) + 7.0 + sin(i * 2.1) * 2.0
		node.position = Vector3(x, height_at(x, z) + 0.35, z)
		add_child(node)
		_eco_sphere(node, Vector3(0,.65,0), Vector3(1.0,.6,1.55), veyra_shell)
		_eco_sphere(node, Vector3(0,0.48,-0.72), Vector3(0.42,0.24,0.32), veyra_core)
		for side in [-1.0,1.0]:
			for leg in 3:
				var zoff := -0.62 + leg * 0.62
				_eco_rod(node, Vector3(side * .65,.5,zoff), Vector3(side * 1.2,-0.08,zoff + 0.16), 0.14, veyra_shell)
		for plate_index in 4:
			if not _low_meshes.is_empty():
				var plate:=MeshInstance3D.new();plate.mesh=_low_meshes[plate_index%_low_meshes.size()];plate.material_override=veyra_shell
				plate.position=Vector3(0,1.02,-1.0+plate_index*.55);plate.scale=Vector3(1.6,.35,.8);node.add_child(plate)
		_ecology_nodes.append(node)
		_ecology_meta.append({"kind":"veyra","label":"VEYRA / 礦脈群體","phase":float(i) * 1.7,"base":node.position})
	var aeral_membrane := _ecology_material(Color("76644e"), Color("dca66d"), 0.7, 0.52)
	var aeral_core := _ecology_material(Color("d2c58f"), Color("f1d98f"), 1.3, 0.42)
	for i in 5:
		var node := Node3D.new()
		node.name = "AeralVeil_%02d" % i
		var z := -285.0 - i * 5.5
		var x := path_x(z) - 5.5 + cos(i * 1.8) * 3.0
		node.position = Vector3(x, height_at(x,z) + 5.0 + (i % 2) * 1.6, z)
		add_child(node)
		if i==0:
			var detailed:=CREATURE_VISUAL.new();detailed.name="DetailedVisual"
			node.add_child(detailed);detailed.configure("aeral");detailed.scale=Vector3.ONE*.56
		else:
			_eco_sphere(node,Vector3.ZERO,Vector3(.45,.22,.8),aeral_membrane)
			for side in [-1.0,1.0]:
				var fin:=_eco_sphere(node,Vector3(side*.75,0,.1),Vector3(.9,.045,.7),aeral_membrane)
				fin.rotation.z=side*.2
		_ecology_nodes.append(node)
		_ecology_meta.append({"kind":"aeral","label":"AERAL VEIL / 霧膜群","phase":float(i) * 1.1,"base":node.position,"passage_index":i})
	var decay_shell := _ecology_material(Color("57464d"), Color("744e86"), 0.32, 0.91)
	var decay_spore := _ecology_material(Color("c08bce"), Color("cc70dd"), 1.2, 0.58)
	for i in 4:
		var node := Node3D.new()
		node.name = "MorrowShell_%02d" % i
		var z := -470.0 - i * 8.0
		var x := path_x(z) + 8.0 + sin(i * 1.9) * 3.0
		node.position = Vector3(x, height_at(x,z) + 0.7, z)
		add_child(node)
		_eco_sphere(node, Vector3.ZERO, Vector3(1.2,0.75,1.0), decay_shell)
		for j in 5:
			var angle := float(j) / 5.0 * TAU
			_eco_rod(node, Vector3(cos(angle)*0.45,0.35,sin(angle)*0.45), Vector3(cos(angle)*1.45,0.85,sin(angle)*1.45), 0.035, decay_spore)
		_ecology_nodes.append(node)
		_ecology_meta.append({"kind":"root_choir","label":"MORROW SHELL / 孢殼群","phase":float(i) * 2.0,"base":node.position})

func _append_fault_fin(st: SurfaceTool, center: Vector3, size: Vector3, yaw: float, salt: int) -> void:
	const SIDES := 11
	const LEVELS := 12
	var points: Array[Vector3] = []
	var base_y := height_at(center.x, center.z) - 0.5
	for ring in LEVELS:
		var t := float(ring) / float(LEVELS - 1)
		var profile := [1.12, 1.05, 0.97, 0.8, 0.91, 0.7, 0.78, 0.63, 0.72, 0.53, 0.59, 0.38]
		var taper: float = profile[ring] + sin(t * 16.0 + salt) * 0.085
		var lean := t * t * size.y * 0.07 * (-1.0 if salt % 2 == 0 else 1.0)
		for side in SIDES:
			var angle := float(side) / SIDES * TAU
			var jagged := 1.0 + sin(side * 2.31 + salt * 1.7 + t * 0.6) * 0.23
			var p := Vector3(cos(angle) * size.x * 0.5 * taper * jagged + lean, t * size.y, sin(angle) * size.z * 0.5 * taper * jagged)
			if ring == LEVELS - 1:
				p.y += sin(side * 3.71 + salt) * size.y * 0.065
			p = p.rotated(Vector3.UP, yaw) + Vector3(center.x, base_y, center.z)
			points.append(p)
	for ring in LEVELS - 1:
		for side in SIDES:
			var a := ring * SIDES + side
			var b := ring * SIDES + (side + 1) % SIDES
			for i: int in [a, b, a + SIDES, b, b + SIDES, a + SIDES]:
				st.set_uv(Vector2(points[i].x + points[i].z, points[i].y) * 0.12)
				st.add_vertex(points[i])
	for side in range(1, SIDES - 1):
		for i: int in [(LEVELS - 1) * SIDES, (LEVELS - 1) * SIDES + side, (LEVELS - 1) * SIDES + side + 1]:
			st.set_uv(Vector2(points[i].x, points[i].z) * 0.12)
			st.add_vertex(points[i])

func _collect_rock_meshes(node: Node, target: Array[Mesh]) -> void:
	if node is MeshInstance3D:
		# Model material islands are collapsed because world rocks share one triplanar material.
		var original: Mesh = (node as MeshInstance3D).mesh
		var combined := SurfaceTool.new()
		combined.begin(Mesh.PRIMITIVE_TRIANGLES)
		for s in original.get_surface_count():
			combined.append_from(original, s, Transform3D.IDENTITY)
		target.append(combined.commit())
	for child in node.get_children():
		_collect_rock_meshes(child, target)

func _build_rocks() -> void:
	if not ResourceLoader.exists(ROCKS_PATH):
		push_warning("WORLD_ROCK_ASSET_PENDING: " + ROCKS_PATH)
		return
	var packed := load(ROCKS_PATH) as PackedScene
	var source := packed.instantiate()
	_collect_rock_meshes(source, _rock_meshes)
	source.free()
	if _rock_meshes.is_empty():
		push_error("WORLD_ROCK_ASSET_EMPTY")
		return
	if ResourceLoader.exists("res://assets/models/rocks_low.glb"):
		var low_source: Node = (load("res://assets/models/rocks_low.glb") as PackedScene).instantiate()
		_collect_rock_meshes(low_source, _low_meshes)
		low_source.free()
	if _low_meshes.size() != _rock_meshes.size():
		_low_meshes = _rock_meshes
	for i in _rock_meshes.size():
		_rock_transforms.append([])
		_bank_transforms.append([])
		_small_transforms.append([])
	# Designed sight-line anchors: asymmetrical gates, split outcrops and long horizontal shelves.
	var anchors := [Vector3(-23, 15, 49), Vector3(36, 12, 17), Vector3(-33, 19, -29), Vector3(30, 14, -86), Vector3(-44, 16, -210), Vector3(43, 22, -320), Vector3(-65, 25, -455), Vector3(82, 19, -560)]
	for anchor: Vector3 in anchors:
		for j in 4:
			var x := anchor.x + j * 3.0 - 5.0
			var z := anchor.z + _rng.randf_range(-5.0, 5.0)
			var size := Vector3(_rng.randf_range(5.0, 10.0), anchor.y * _rng.randf_range(0.45, 1.0), _rng.randf_range(4.0, 8.0))
			_place_rock(x, z, size, false, true, true)
	# Bedrock slabs emerge from bank crests. Placement avoids the entire clear driving corridor.
	for i in 160:
		var z := _rng.randf_range(-620.0, 170.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := path_x(z) + side * _rng.randf_range(10.0, 74.0)
		var size := Vector3(_rng.randf_range(1.6, 5.0), _rng.randf_range(0.5, 2.9), _rng.randf_range(1.5, 4.5))
		_place_rock(x, z, size, false, true)
	for i in 120:
		var z := _rng.randf_range(-610.0, 170.0)
		var x := path_x(z) + _rng.randf_range(6.5, 80.0) * (-1.0 if i % 2 == 0 else 1.0)
		var s := _rng.randf_range(0.12, 0.58)
		_place_rock(x, z, Vector3(s * 1.7, s * 0.7, s), true, false)
	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = Color(0.64, 0.59, 0.56)
	rock_material.albedo_texture = load("res://assets/terrain/basalt_albedo.png")
	rock_material.normal_enabled = true
	rock_material.normal_texture = load("res://assets/terrain/geology_normal.png")
	rock_material.normal_scale = 0.75
	rock_material.roughness_texture = load("res://assets/terrain/geology_roughness.png")
	rock_material.roughness = 0.95
	rock_material.uv1_triplanar = true
	rock_material.uv1_scale = Vector3(1.7, 1.7, 1.7)
	var rock_triangles := 0
	for i in _rock_meshes.size():
		_make_multimesh(_rock_meshes[i], _rock_transforms[i], rock_material, false)
		_make_multimesh(_low_meshes[i], _bank_transforms[i], rock_material, false)
		_make_multimesh(_low_meshes[i], _small_transforms[i], rock_material, true)
		rock_triangles += _triangle_count(_rock_meshes[i]) * _rock_transforms[i].size()
		rock_triangles += _triangle_count(_low_meshes[i]) * (_bank_transforms[i].size() + _small_transforms[i].size())
	build_stats["rock_triangles_all_instances"] = rock_triangles
	build_stats["rock_batches"] = _rock_meshes.size() * 3

func _wetland_ground_material(color: Color) -> StandardMaterial3D:
	var material := _ecology_material(color, Color("6e9f86"), 0.025, 0.86)
	var albedo_path := GROUND037_ALBEDO_PATH if ResourceLoader.exists(GROUND037_ALBEDO_PATH) else "res://assets/terrain/dust_albedo.png"
	var normal_path := GROUND037_NORMAL_PATH if ResourceLoader.exists(GROUND037_NORMAL_PATH) else "res://assets/terrain/geology_normal.png"
	material.albedo_texture = load(albedo_path)
	material.normal_enabled = true
	material.normal_texture = load(normal_path)
	material.normal_scale = 0.24
	if normal_path == GROUND037_NORMAL_PATH:
		material.roughness_texture = material.normal_texture
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.42
	return material

func _build_wetland_pool() -> void:
	var center := _wetland_center()
	_wetland_root = Node3D.new()
	_wetland_root.name = "PairedMarshStudy"
	_wetland_root.position = Vector3(center.x, height_at(center.x, center.y), center.y)
	add_child(_wetland_root)

	# A real terrain depression contains the water. The water body itself is deliberately cheap and opaque.
	var water := MeshInstance3D.new()
	water.name = "ContainedShallowWater"
	var water_surface:=SurfaceTool.new();water_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 64:
		var a:float=i/64.0*TAU;var b:float=(i+1)/64.0*TAU
		var ra:float=4.05+sin(a*3.0)*.18+sin(a*7.0)*.10
		var rb:float=4.05+sin(b*3.0)*.18+sin(b*7.0)*.10
		for p in [Vector3.ZERO,Vector3(cos(b)*rb,0,sin(b)*rb),Vector3(cos(a)*ra,0,sin(a)*ra)]:
			water_surface.set_uv(Vector2(p.x,p.z)/8.4+Vector2(.5,.5));water_surface.add_vertex(p)
	water_surface.generate_normals();water_surface.generate_tangents()
	water.mesh=water_surface.commit()
	water.position.y = 0.64
	_wetland_water_material = ShaderMaterial.new()
	_wetland_water_material.shader = WETLAND_SHADER
	water.material_override = _wetland_water_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wetland_root.add_child(water)

	var rock_material := _passage_material(Color("4e5d58"))
	rock_material.emission_energy_multiplier = 0.015
	var shore_material := _wetland_ground_material(Color("4c665b"))
	var plant_material := _wetland_ground_material(Color("315b50"))
	plant_material.emission = Color("6aa88f")
	plant_material.emission_energy_multiplier = 0.045
	for i in 11:
		var angle := float(i) / 11.0 * TAU + sin(float(i) * 2.31) * 0.12
		var radius := 5.1 + float(i % 4) * 0.48 + sin(float(i) * 1.73) * 0.28
		var local := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var rock_scale := Vector3(0.54 + float(i % 3) * 0.17, 0.22 + float((i + 1) % 3) * 0.08, 0.46 + float((i + 2) % 4) * 0.12)
		_root_ground_rock(_wetland_root, local, rock_scale, rock_material, 60 + i)
		var patch_angle := angle + 0.17
		var patch_radius := radius - 0.55
		var patch_x := cos(patch_angle) * patch_radius
		var patch_z := sin(patch_angle) * patch_radius
		var patch_world_x := center.x + patch_x
		var patch_world_z := center.y + patch_z
		var patch := _eco_sphere(
			_wetland_root,
			Vector3(patch_x, height_at(patch_world_x, patch_world_z) - _wetland_root.position.y + 0.035, patch_z),
			Vector3(0.72 + float(i % 2) * 0.24, 0.045, 0.46 + float(i % 3) * 0.12),
			shore_material
		)
		patch.name = "Ground037ShorePatch%02d" % i

	for i in 9:
		var angle := float(i) / 9.0 * TAU + 0.29
		var radius := 5.5 + float(i % 3) * 0.78
		var local_x := cos(angle) * radius
		var local_z := sin(angle) * radius
		var world_x := center.x + local_x
		var world_z := center.y + local_z
		var plant := Node3D.new()
		plant.name = "MembranePlant%02d" % i
		plant.position = Vector3(local_x, height_at(world_x, world_z) - _wetland_root.position.y, local_z)
		plant.rotation.y = -angle + PI * 0.5
		_wetland_root.add_child(plant)
		_eco_rod(plant, Vector3.ZERO, Vector3(0.0, 0.75 + float(i % 3) * 0.11, 0.0), 0.045, plant_material)
		var lobes: Array[MeshInstance3D] = []
		var closed: Array[float] = []
		var opened: Array[float] = []
		for lobe_index in 3:
			var side := float(lobe_index - 1)
			var lobe := _eco_sphere(
				plant,
				Vector3(side * 0.16, 0.78 + float(lobe_index % 2) * 0.18, 0.0),
				Vector3(0.24 + float(i % 2) * 0.035, 0.7 + float(lobe_index) * 0.1, 0.065),
				plant_material
			)
			lobe.name = "MembraneLobe%d" % lobe_index
			var closed_angle := side * 0.12
			var open_angle := side * (0.58 + float(i % 3) * 0.08)
			lobe.rotation.z = closed_angle
			lobes.append(lobe)
			closed.append(closed_angle)
			opened.append(open_angle)
		_wetland_plants.append({"node":plant, "lobes":lobes, "closed":closed, "opened":opened, "phase":float(i) * 0.91})

	for i in 6:
		var angle := float(i) / 6.0 * TAU + 0.18
		var vein_material := _ecology_material(Color("345f59"), Color("70b6a5"), 0.025, 0.42)
		_wetland_vein_materials.append(vein_material)
		_eco_rod(
			_wetland_root,
			Vector3(cos(angle) * 0.45, 0.695, sin(angle) * 0.45),
			Vector3(cos(angle) * (3.2 + float(i % 2) * 0.45), 0.695, sin(angle) * (3.2 + float(i % 2) * 0.45)),
			0.026,
			vein_material
		)

	_build_wetland_reader(plant_material)
	build_stats["wetland_pool_radius"] = 4.2
	build_stats["wetland_bowl_radius"] = 10.0
	build_stats["wetland_membrane_plants"] = _wetland_plants.size()

func _build_wetland_reader(material: StandardMaterial3D) -> void:
	var field := SURVEYS.point("marsh_reed")
	var reader := Node3D.new()
	reader.name = "MarshPairedReaderSeed"
	var x := field.x + 2.8
	var z := field.y + 1.2
	reader.position = Vector3(x, height_at(x, z) + 0.08, z)
	add_child(reader)
	_wetland_reader_material = material.duplicate() as StandardMaterial3D
	_wetland_reader_material.emission_energy_multiplier = 0.025
	_eco_rod(reader, Vector3.ZERO, Vector3(0.0, 0.85, 0.0), 0.055, _wetland_reader_material)
	_eco_sphere(reader, Vector3(0.0, 0.98, 0.0), Vector3(0.26, 0.14, 0.26), _wetland_reader_material)
	_wetland_reader_label = Label3D.new()
	_wetland_reader_label.name = "PairedStudyReadout"
	_wetland_reader_label.text = "-- / 2"
	_wetland_reader_label.font_size = 36
	_wetland_reader_label.pixel_size = 0.009
	_wetland_reader_label.position = Vector3(0.0, 1.65, 0.0)
	_wetland_reader_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reader.add_child(_wetland_reader_label)

func set_wetland_study_state(data: Dictionary, instant: bool = false) -> void:
	_wetland_state = {
		"prepared":bool(data.get("prepared", false)),
		"startled":bool(data.get("startled", false)),
		"recovered":bool(data.get("recovered", false)),
		"complete":bool(data.get("complete", false))
	}
	if instant:
		_wetland_open = 1.0 if _wetland_state.complete else 0.0
		_wetland_alarm = 1.0 if _wetland_state.startled and not _wetland_state.recovered else 0.0
	_apply_wetland_readout()
	_tick_wetland(0.0, instant)

func _apply_wetland_readout() -> void:
	if not is_instance_valid(_wetland_reader_label): return
	if _wetland_state.complete:
		_wetland_reader_label.text = "2 / 2"
	elif _wetland_state.recovered:
		_wetland_reader_label.text = "2 / 2"
	elif _wetland_state.startled:
		_wetland_reader_label.text = "1 / 2"
	elif _wetland_state.prepared:
		_wetland_reader_label.text = "0 / 2"
	else:
		_wetland_reader_label.text = "-- / 2"
	var active: bool = bool(_wetland_state.prepared) or bool(_wetland_state.startled) or bool(_wetland_state.recovered) or bool(_wetland_state.complete)
	_wetland_reader_material.albedo_color = Color("79a98f") if active else Color("315b50")
	_wetland_reader_material.emission_energy_multiplier = 0.18 if active else 0.025

func _tick_wetland(delta: float, instant: bool = false) -> void:
	if not is_instance_valid(_wetland_root): return
	var target_open := 1.0 if bool(_wetland_state.get("complete", false)) else 0.0
	var target_alarm := 1.0 if bool(_wetland_state.get("startled", false)) and not bool(_wetland_state.get("recovered", false)) else 0.0
	_wetland_open = target_open if instant else move_toward(_wetland_open, target_open, delta * 0.52)
	_wetland_alarm = target_alarm if instant else move_toward(_wetland_alarm, target_alarm, delta * 1.4)
	var response := _wetland_open * (1.0 - _wetland_alarm)
	if is_instance_valid(_wetland_water_material):
		_wetland_water_material.set_shader_parameter("world_time", _world_time)
		_wetland_water_material.set_shader_parameter("response", response)
		_wetland_water_material.set_shader_parameter("alarm", _wetland_alarm)
	for i in _wetland_plants.size():
		var data: Dictionary = _wetland_plants[i]
		var plant: Node3D = data.node
		var pulse := 0.5 + 0.5 * sin(_world_time * 1.05 + float(data.phase))
		var living_scale := response * pulse * 0.035
		plant.scale = Vector3(1.0 + living_scale, lerpf(1.0, 0.66, _wetland_alarm) + living_scale, 1.0 + living_scale)
		var lobes: Array = data.lobes
		for lobe_index in lobes.size():
			var lobe: MeshInstance3D = lobes[lobe_index]
			var closed_angle: float = data.closed[lobe_index]
			var open_angle: float = data.opened[lobe_index]
			lobe.rotation.z = lerpf(closed_angle, open_angle, response)
	for i in _wetland_vein_materials.size():
		var vein: StandardMaterial3D = _wetland_vein_materials[i]
		var vein_pulse := 0.5 + 0.5 * sin(_world_time * 1.25 - float(i) * 0.72)
		vein.emission_energy_multiplier = 0.025 + response * (0.11 + vein_pulse * 0.09)
		vein.albedo_color = Color("6e6551") if _wetland_alarm > 0.5 else Color("345f59").lerp(Color("508b79"), response * 0.45)

func _triangle_count(mesh: Mesh) -> int:
	var triangles := 0
	for s in mesh.get_surface_count():
		var array := mesh.surface_get_arrays(s)
		triangles += array[Mesh.ARRAY_INDEX].size() / 3 if array[Mesh.ARRAY_INDEX] != null and array[Mesh.ARRAY_INDEX].size() > 0 else array[Mesh.ARRAY_VERTEX].size() / 3
	return triangles

func _place_rock(x: float, z: float, size: Vector3, small: bool, collidable: bool, hero: bool = false) -> void:
	var footprint := maxf(size.x, size.z) * 0.55
	for id in SURVEYS.SITES:
		if Vector2(x,z).distance_to(SURVEYS.point(id))<8.0+footprint: return
	if absf(x - path_x(z)) < 5.5 + footprint:
		return
	if Vector2(x - signal_origin().x, z + 650.0).length() < 12.0 + footprint:
		return
	var type := _rng.randi_range(0, _rock_meshes.size() - 1)
	var yaw := _rng.randf_range(-PI, PI)
	var basis := Basis.from_euler(Vector3(_rng.randf_range(-0.13, 0.13), yaw, _rng.randf_range(-0.12, 0.12))).scaled(size)
	# Consume the original random draws before omitting a pond rock; other placements stay stable.
	if Vector2(x, z).distance_to(_wetland_center()) < 10.0 + footprint: return
	var bounds := _rock_meshes[type].get_aabb()
	var position := Vector3(x, height_at(x, z) - bounds.position.y * size.y - size.y * 0.12, z)
	var transform := Transform3D(basis, position)
	if small:
		_small_transforms[type].append(transform)
	elif hero:
		_rock_transforms[type].append(transform)
	else:
		_bank_transforms[type].append(transform)
	if collidable and absf(x) < 96.0 and z > -670.0 and z < 180.0:
		var body := StaticBody3D.new()
		body.name = "BedrockCollision"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bounds.size * size * Vector3(0.78, 0.82, 0.78)
		shape.shape = box
		shape.position = bounds.get_center() * size
		body.position = position
		body.rotation.y = yaw
		body.add_child(shape)
		add_child(body)

func _make_multimesh(mesh: Mesh, transforms: Array, material: Material, small: bool) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "SmallBasaltDressing" if small else "AuthoredBasaltClusters"
	instance.multimesh = mm
	instance.material_override = material
	if small:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_small_dressing.append(instance)
	add_child(instance)

func _build_response() -> void:
	_roots_material = ShaderMaterial.new()
	_roots_material.shader = ROOT_SHADER
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := signal_origin()
	for branch in 17:
		var angle := float(branch) / 17.0 * TAU + _rng.randf_range(-0.12, 0.12)
		var length := _rng.randf_range(38.0, 95.0)
		for i in 70:
			var t0 := float(i) / 70.0
			var t1 := float(i + 1) / 70.0
			var points: Array[Vector3] = []
			for t: float in [t0, t1]:
				var bend := angle + sin(t * 13.0 + branch) * 0.085 + sin(t * 31.0) * 0.025
				var center := origin + Vector3(cos(bend), 0.0, sin(bend)) * (1.1 + t * length)
				var width := lerpf(0.12, 0.018, t)
				for side: float in [-1.0, 1.0]:
					var point := center + Vector3(-sin(bend), 0, cos(bend)) * width * side
					point.y = height_at(point.x, point.z) + 0.085
					points.append(point)
			var uv := [Vector2(t0, 0), Vector2(t0, 1), Vector2(t1, 0), Vector2(t1, 1)]
			for index: int in [0, 1, 2, 1, 3, 2]:
				st.set_uv(uv[index])
				st.add_vertex(points[index])
	st.generate_normals()
	var roots := MeshInstance3D.new()
	roots.name = "SubsurfaceResponseRoots"
	roots.mesh = st.commit()
	roots.material_override = _roots_material
	roots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(roots)
	build_stats["response_triangles"] = 17 * 70 * 2

func _build_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.name = "LowDriftingDust"
	_dust.amount = 64
	_dust.lifetime = 18.0
	_dust.preprocess = 8.0
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(75.0, 0.7, 390.0)
	_dust.position = Vector3(0, 1.3, -210)
	_dust.direction = Vector3(1, 0.01, 0.2)
	_dust.spread = 8.0
	_dust.gravity = Vector3.ZERO
	_dust.initial_velocity_min = 0.5
	_dust.initial_velocity_max = 1.4
	_dust.scale_amount_min = 0.4
	_dust.scale_amount_max = 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 0.18)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.51, 0.37, 0.25, 0.055)
	mat.albedo_texture = load("res://assets/terrain/dust_mask.png")
	quad.material = mat
	_dust.mesh = quad
	add_child(_dust)

func set_response(progress: float, elapsed: float) -> void:
	if _roots_material:
		_roots_material.set_shader_parameter("progress", clampf(progress, 0.0, 1.0))
		_roots_material.set_shader_parameter("elapsed", elapsed)

func set_low_quality(value: bool) -> void:
	_low_quality = value
	if is_instance_valid(_living_habitat):_living_habitat.set_low_quality(value)
	for instance in _small_dressing:
		instance.visible = not value
	if _dust:
		_dust.emitting = not value
		_dust.visible = not value

func set_paused(value: bool) -> void:
	_paused = value
	if is_instance_valid(_living_habitat):_living_habitat.set_paused(value)
	if is_instance_valid(_dust): _dust.speed_scale = 0.0 if value else 1.0

func reset() -> void:
	_escort_state.clear()
	_resonance_open=0.0
	set_resonance_visual(-1,false)
	set_passage_state({"phase":"idle", "gate":0, "alarm":0.0}, 0.0, true)
	_world_time = 0.0
	set_wetland_study_state({"prepared":false,"startled":false,"recovered":false,"complete":false}, true)
	set_thermal_state({"vent_observed":false,"route":"warm","locked":false},true)
	set_root_network_state({"ports":[0, 0, 0], "powered":0, "complete":false}, true)
	_player_position = spawn_origin()
	_player_speed = 0.0
	_observed_regions.clear()
	for i in _ecology_nodes.size():
		_ecology_nodes[i].position = _ecology_meta[i]["base"]
		_ecology_nodes[i].rotation = Vector3(0, float(_ecology_meta[i]["phase"]), 0)
		_ecology_nodes[i].scale = Vector3.ONE
		_ecology_reactions[i].reset()
		for entry: Dictionary in _ecology_glow[i]:
			entry["material"].emission_energy_multiplier = entry["energy"]
	set_paused(false)
	set_response(0.0, 0.0)
	set_low_quality(_low_quality)
