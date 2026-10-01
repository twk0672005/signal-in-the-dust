extends Node3D
## Authored geological basin. Coordinates and height queries are shared with driving.
const SURVEYS = preload("res://scripts/expedition_activities.gd")
const HABITAT_FEATURES = preload("res://scripts/living_habitat.gd")
const CREATURE_VISUAL = preload("res://scripts/creature_visual.gd")
var _living_habitat:Node3D
const ECOLOGY_RESPONSE = preload("res://scripts/ecology_response.gd")
const TERRAIN_REVISION := 7
var _landform_clearances: Array[Vector2] = []
var _environment_access_segments: Array[Vector4] = []
var _cool_access_start := 0
const BOUNDARY_TEXTURE := "res://assets/environment_upgrade/boundary-rocks-v1.png"
const BOUNDARY_TERRACES := "res://assets/environment_upgrade/boundary-terraces-v1.png"
const BOUNDARY_SHADER := preload("res://shaders/boundary_cutout.gdshader")
const ROCKS_PATH := "res://assets/environment_upgrade/fractured/rocks.glb"
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
# Unequal crater sectors interrupt the periodic sine profile without changing driving height.
const RIM_HEIGHTS := [142.0,176.0,154.0,196.0,119.0,148.0,107.0,163.0,183.0,135.0,177.0,110.0,158.0,188.0,126.0,169.0]
var _environment: Environment
var _roots_material: ShaderMaterial
var _small_dressing: Array[MultiMeshInstance3D] = []
var _dust: CPUParticles3D
var _rng := RandomNumberGenerator.new()
var _terrain_material: ShaderMaterial
var _strata_material: ShaderMaterial
var _rock_original_materials: Dictionary = {}
var _rock_material_pairs: Array[Dictionary] = []
var _material_variant := "authored"
var _rock_meshes: Array[Mesh] = []
var _low_meshes: Array[Mesh] = []
var _rock_transforms: Array[Array] = []
var _bank_transforms: Array[Array] = []
var _small_transforms: Array[Array] = []
var _low_quality := false
var _world_time: float = 0.0
var _distant_pose_clock := 0.0
var _paused: bool = false
# Main explicitly awaits the Web build; native callers retain synchronous _ready.
var staged_boot := false
var boot_frame_yield: Callable
var _boot_slice_started := 0
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

func legacy_height_at(x: float, z: float) -> float:
	var base_height := _base_height_at(x, z)
	var center := _wetland_center()
	var distance := Vector2(x - center.x, z - center.y).length()
	if distance >= 10.0:
		return base_height
	# The coarse 2.5 x 4.7 m terrain sampling needs a broad, flat-bottomed bowl.
	# Outside ten metres the blend is exactly zero, preserving every established route height.
	var basin_floor := _base_height_at(center.x, center.y) - 1.2
	return lerpf(basin_floor, base_height, smoothstep(3.4, 10.0, distance))

func _previous_terrain_changed_at(x: float,z: float) -> bool:
	var p:=Vector2(x,z)-_wetland_center()
	return p.x>-48.0 and p.x<18.0 and p.y>-35.0 and p.y<34.0

func environment_terrain_changed_at(x: float,z: float) -> bool:
	return _previous_terrain_changed_at(x,z) or (x>-180.0 and x<180.0 and z>-644.0 and z<192.0)

func wetland_water_level() -> float:
	var center:=_wetland_center()
	return _base_height_at(center.x,center.y)-.83

func _revision_5_basin_distance(point: Vector2) -> float:
	var p:=point-_wetland_center()
	# Connected unequal lobes open westward, away from the protected road.
	return minf((p/Vector2(6.2,6.0)).length(),minf(((p-Vector2(-15.0,2.0))/Vector2(22.0,14.0)).length(),((p-Vector2(-28.0,9.0))/Vector2(12.0,12.0)).length()))

func wetland_basin_distance(point: Vector2) -> float:
	var p:=point-_wetland_center()
	# One water level joins the old research cove to a long western backwater.
	# The east levee and the cross-marsh investigation remain dry access floors.
	return minf(_revision_5_basin_distance(point),minf(((p-Vector2(-24,23))/Vector2(29,30)).length(),minf(((p-Vector2(-49,31))/Vector2(22,20)).length(),((p-Vector2(-64,63))/Vector2(18,38)).length())))

func previous_height_at(x: float,z: float) -> float:
	var original:=legacy_height_at(x,z)
	if not _previous_terrain_changed_at(x,z):return original
	var center:=_wetland_center()
	var p:=Vector2(x,z)-center
	var d:=_revision_5_basin_distance(Vector2(x,z))
	var level:=wetland_water_level()
	var bed:=level-.37-.55*(1.0-smoothstep(.0,.82,d))
	bed+=.06*sin(x*.48+z*.13)*sin(z*.41)
	# Keep the existing study floor exactly seated at its original anchor.
	bed=lerpf(original,bed,smoothstep(2.8,5.8,p.length()))
	var flooded:=lerpf(bed,maxf(original,level+.55),smoothstep(.68,1.08,d))
	var bowl:=lerpf(flooded,original,smoothstep(1.08,1.42,d))
	# Dry root levees are real terrain, queried by all render/physics/placement.
	var levee:=1.05*exp(-pow((p.x-8.0)/5.0,2.0)-pow((p.y+12.0)/16.0,2.0))
	levee+=.85*exp(-pow((p.x+14.0)/19.0,2.0)-pow((p.y-23.0)/4.0,2.0))
	var target:=bowl+levee*smoothstep(.95,1.3,d)
	var mask:=smoothstep(5.5,10.0,absf(x-path_x(z)))
	for id in ["marsh_pool","veil_marsh"]:
		mask*=smoothstep(6.0,9.0,Vector2(x,z).distance_to(SURVEYS.point(id)))
	mask*=smoothstep(0.0,3.0,minf(minf(p.x+48.0,18.0-p.x),minf(p.y+35.0,34.0-p.y)))
	return lerpf(original,target,mask)

func _landform_mask(x: float,z: float) -> float:
	if x<=-164.0 or x>=164.0 or z<=-632.0 or z>=180.0:return 0.0
	var mask:=smoothstep(12.0,30.0,absf(x-path_x(z)))
	if mask==0.0:return 0.0
	mask*=smoothstep(0.0,18.0,minf(164.0-absf(x),minf(z+632.0,180.0-z)))
	# Preserve the complete revision-2 water/shore surface, not only its centre.
	var pool:=Vector2(x,z)-_wetland_center()
	var outside:=maxf(maxf(-48.0-pool.x,pool.x-18.0),maxf(-35.0-pool.y,pool.y-34.0))
	mask*=smoothstep(0.0,18.0,outside)
	if mask==0.0:return 0.0
	_prepare_landform_clearances()
	for point in _landform_clearances:
		if absf(z-point.y)>24.0:continue
		mask*=smoothstep(9.0,24.0,Vector2(x,z).distance_to(point))
	# Broad cross-slope approaches remain driveable to the remote investigations.
	for id in ["aurora_echo","ember_vent","marsh_crossing","spore_pulse"]:
		var point:Vector2=SURVEYS.point(id)
		if absf(z-point.y)>18.0:continue
		var road:=path_x(point.y)
		if x>minf(road,point.x)-6.0 and x<maxf(road,point.x)+6.0:
			mask*=smoothstep(5.0,18.0,absf(z-point.y))
	return mask

func _prepare_landform_clearances() -> void:
	if not _landform_clearances.is_empty():return
	for id in SURVEYS.SITES:_landform_clearances.append(SURVEYS.point(id))
	_landform_clearances.append_array(passage_route())
	_landform_clearances.append_array(root_network_points())
	_landform_clearances.append_array(ecology_anchor_points())
	_landform_clearances.append(Vector2(-61,-148))

func revision_3_height_at(x: float,z: float) -> float:
	var original:=previous_height_at(x,z)
	var mask:=_landform_mask(x,z)
	if mask==0.0:return original
	var delta:=0.0
	if z>-30.0:
		# Wind-cut west table, an eroded cleft and lower detached east shelf.
		var west:=Vector2((x+65.0+(z-85.0)*.18)/43.0,(z-94.0)/85.0).length()
		var cleft:=1.0-.78*exp(-pow((z-83.0+(x+60.0)*.40)/13.0,2.0))
		delta=16.0*(1.0-smoothstep(.60,1.16,west))*cleft
		delta+=9.0*(1.0-smoothstep(.55,1.12,Vector2((x-65.0)/35.0,(z-42.0)/48.0).length()))
		delta+=8.0*exp(-pow((x+132.0)/29.0,2.0)-pow((z-60.0)/93.0,2.0))
		delta*=smoothstep(-30.0,12.0,z)
	if z<12.0 and z>-191.0:
		# Two offset fault ribs end before the thermal basin; no pillar avenue.
		var along:=1.0-smoothstep(.58,1.0,absf(z+76.0)/96.0)
		var rib:=x+49.0-(z+80.0)*.24
		var rift:=19.0*exp(-pow(rib/16.0,2.0))*along
		rift+=13.0*exp(-pow((x-67.0+(z+75.0)*.33)/23.0,2.0)-pow((z+57.0)/37.0,2.0))
		rift-=2.4*exp(-pow((x-49.0)/34.0,2.0)-pow((z+125.0)/25.0,2.0))
		delta+=rift*smoothstep(-191.0,-160.0,z)*(1.0-smoothstep(-22.0,12.0,z))
	if z<-160.0 and z>-374.0:
		# A westward drainage trough has unequal raised root levees and open flats.
		var channel:=x+51.0+12.0*sin((z+245.0)*.040)
		var marsh:=5.8*exp(-pow((channel+25.0)/16.0,2.0))-2.1*exp(-pow(channel/23.0,2.0))
		marsh+=3.5*exp(-pow((channel-25.0)/12.0,2.0))*exp(-pow((z+230.0)/72.0,2.0))
		marsh+=6.0*exp(-pow((x-65.0)/43.0,2.0)-pow((z+204.0)/36.0,2.0))
		delta+=marsh*smoothstep(-374.0,-334.0,z)*(1.0-smoothstep(-193.0,-160.0,z))
	if z<-334.0:
		# Collapsed west basin: an incomplete sediment rim, with a bare east slipface.
		var basin:=Vector2((x+65.0+(z+470.0)*.12)/48.0,(z+490.0)/107.0).length()
		var rim:=10.0*exp(-pow((basin-.95)/.24,2.0))
		rim*=.42+.58*(1.0-smoothstep(-70.0,-29.0,x))
		var pale:=rim-3.2*(1.0-smoothstep(.38,.80,basin))
		pale+=12.0*(1.0-smoothstep(.6,1.15,Vector2((x-83.0)/47.0,(z+525.0)/82.0).length()))
		pale+=5.0*exp(-pow((x+35.0)/24.0,2.0)-pow((z+411.0)/23.0,2.0))
		delta+=pale*(1.0-smoothstep(-383.0,-334.0,z))
	return original+delta*mask

func escort_route_points(choice: String = "warm") -> Array[Vector2]:
	if choice=="cool":
		return [Vector2(path_x(-105),-105),Vector2(-20,-95),Vector2(-48,-55),Vector2(-72,-65),Vector2(-74,-112),Vector2(-63,-145),Vector2(-60,-145)]
	var points: Array[Vector2]=[]
	for z in [-105.0,-75.0,-45.0,-65.0,-90.0,-115.0,-140.0,-157.0]: points.append(Vector2(path_x(z),z))
	return points

func environment_access_distance(x: float,z: float,include_cool: bool=true) -> float:
	# Existing exploration approaches, shared with habitat clearance. Aurora enters
	# its cleft at z95, not at the echo's z55; the other branches leave their survey.
	if _environment_access_segments.is_empty():
		var paths:Array=[
			[Vector2(path_x(95),95),Vector2(-42,95),SURVEYS.point("aurora_echo")],
			[SURVEYS.point("ember_rift"),SURVEYS.point("ember_vent"),Vector2(path_x(-135),-135)],
			[SURVEYS.point("veil_marsh"),SURVEYS.point("marsh_crossing"),Vector2(SURVEYS.point("marsh_crossing").x,-271),Vector2(path_x(-271),-271)],
			[SURVEYS.point("pale_decay"),SURVEYS.point("spore_pulse"),Vector2(path_x(-540),-540)]]
		for path:Array in paths:
			for i in path.size()-1:
				_environment_access_segments.append(Vector4(path[i].x,path[i].y,path[i+1].x,path[i+1].y))
		_cool_access_start=_environment_access_segments.size()
		var cool:=escort_route_points("cool")
		for i in cool.size()-1:
			_environment_access_segments.append(Vector4(cool[i].x,cool[i].y,cool[i+1].x,cool[i+1].y))
	var distance:=INF
	var point:=Vector2(x,z)
	for index in (_environment_access_segments.size() if include_cool else _cool_access_start):
		var segment:=_environment_access_segments[index]
		# Beyond this envelope no terrain cut or structural exclusion can apply.
		if z<minf(segment.y,segment.w)-48.0 or z>maxf(segment.y,segment.w)+48.0:continue
		var a:=Vector2(segment.x,segment.y)
		var delta:=Vector2(segment.z,segment.w)-a
		var nearest:=a+delta*clampf((point-a).dot(delta)/delta.length_squared(),0.0,1.0)
		# Escort needs room beside the animal, not only a narrow center line.
		distance=minf(distance,point.distance_to(nearest)-(6.0 if index>=_cool_access_start else 0.0))
	return distance

func revision_5_height_at(x: float,z: float) -> float:
	return _access_height_at(x,z,environment_access_distance(x,z))

func revision_6_height_at(x: float,z: float) -> float:
	return _revision_6_surface(x,z,revision_5_height_at(x,z))

func _revision_6_surface(x: float,z: float,original: float) -> float:
	if x<=-180.0 or x>=180.0 or z<=-644.0 or z>=192.0:return original
	var road_distance:=absf(x-path_x(z))
	var mask:=smoothstep(8.0,23.0,road_distance)
	mask*=smoothstep(0.0,18.0,minf(180.0-absf(x),minf(z+644.0,192.0-z)))
	if mask==0.0:return original
	var access:=environment_access_distance(x,z)
	mask*=smoothstep(9.0,21.0,access)
	if mask==0.0:return original
	_prepare_landform_clearances()
	for point in _landform_clearances:
		if absf(z-point.y)<17.0:mask*=smoothstep(6.5,17.0,Vector2(x,z).distance_to(point))
	if mask==0.0:return original
	var shaped:=original
	var point:=Vector2(x,z)
	var frost:=smoothstep(-28.0,8.0,z)
	var ember:=smoothstep(-188.0,-156.0,z)*(1.0-smoothstep(-28.0,8.0,z))
	var marsh:=smoothstep(-383.0,-338.0,z)*(1.0-smoothstep(-188.0,-156.0,z))
	var pale:=1.0-smoothstep(-383.0,-338.0,z)
	# Wind-planed, flat-topped tables with cut faces and an eroded diagonal cleft.
	var table:=Vector2((x+61.0+(z-95.0)*.12)/45.0,(z-99.0)/94.0).length()
	var shelf:=20.0*(1.0-smoothstep(.67,.84,table))+7.0*(1.0-smoothstep(.93,1.17,table))
	var cleft:=exp(-pow((z-87.0+(x+51.0)*.46)/10.0,2.0))
	shelf*=1.0-cleft*.78
	var east:=Vector2((x-65.0)/39.0,(z-72.0)/65.0).length()
	shelf+=14.0*(1.0-smoothstep(.62,.80,east))+4.0*(1.0-smoothstep(.90,1.15,east))
	shaped+=frost*(shelf-7.0*(1.0-smoothstep(.52,1.19,table)))
	# A narrow fault wall opposes a low broken bench; the thermal floor stays quiet.
	var fault_axis:=x+50.0-(z+75.0)*.20
	var along:=1.0-smoothstep(.56,1.0,absf(z+76.0)/87.0)
	var fault:=24.0*(1.0-smoothstep(8.0,14.0,absf(fault_axis)))*along
	fault+=7.0*(1.0-smoothstep(17.0,29.0,absf(fault_axis)))*along
	var bench:=Vector2((x-61.0+(z+60.0)*.14)/32.0,(z+69.0)/63.0).length()
	fault+=13.0*(1.0-smoothstep(.58,.79,bench))+3.0*(1.0-smoothstep(.86,1.14,bench))
	shaped+=ember*(fault-4.0*exp(-pow((x+31.0)/27.0,2.0)-pow((z+123.0)/29.0,2.0)))
	# Lower wetland shoulders interrupt the former grass-covered bowl. Root levees
	# follow the backwater instead of surrounding it with evenly raised banks.
	var drainage:=x+55.0+8.0*sin((z+255.0)*.026)
	shaped+=marsh*(-3.8*exp(-pow(drainage/31.0,2.0))+3.7*exp(-pow((drainage-34.0)/10.0,2.0)))
	# Pale has a collapsed amphitheatre and broad bare slipface, with broken terraces.
	var collapse:=Vector2((x+63.0+(z+493.0)*.16)/48.0,(z+492.0)/105.0).length()
	var rim:=15.0*exp(-pow((collapse-.94)/.15,2.0))*(.24+.76*(1.0-smoothstep(-80.0,-25.0,x)))
	var slip:=Vector2((x-76.0)/43.0,(z+527.0)/81.0).length()
	var decay:=rim-4.8*(1.0-smoothstep(.43,.81,collapse))+16.0*(1.0-smoothstep(.60,.83,slip))
	shaped+=pale*decay
	# Metre-scale gullies erode exposed feet. Their amplitude is bounded and zero on
	# protected driving floors; texture detail cannot supply these actual silhouettes.
	var erosion:=sin(x*.19+sin(z*.043)*1.7)*sin(z*.16+x*.025)
	shaped+=erosion*(.50*frost+.72*ember+.17*marsh+.58*pale)
	var basin:=wetland_basin_distance(point)
	if basin<1.48:
		var level:=wetland_water_level()
		var bed:=level-.35-.70*(1.0-smoothstep(.0,.78,basin))+.035*erosion
		var bank:=maxf(shaped,level+.40)
		var bowl:=lerpf(bed,bank,smoothstep(.70,1.09,basin))
		shaped=lerpf(bowl,shaped,smoothstep(1.09,1.48,basin))
		# Retain the established paired-study cove exactly at its anchor, including
		# the radial shoreline query's seed. New branches are continuous outside it.
		shaped=lerpf(original,shaped,smoothstep(5.0,10.0,point.distance_to(_wetland_center())))
	return lerpf(original,shaped,mask)

func height_at(x: float,z: float) -> float:
	var floor:=revision_5_height_at(x,z)
	var original:=_revision_6_surface(x,z,floor)
	if x<=-180 or x>=180 or z<=-644 or z>=192:return original
	var road_distance:=absf(x-path_x(z))
	var mask:=smoothstep(10.0,25.0,road_distance)
	mask*=smoothstep(9.0,22.0,environment_access_distance(x,z))
	mask*=smoothstep(0.0,18.0,minf(180.0-absf(x),minf(z+644.0,192.0-z)))
	if mask==0.0 or wetland_basin_distance(Vector2(x,z))<1.70:return original
	_prepare_landform_clearances()
	for point in _landform_clearances:
		if absf(z-point.y)<19.0:mask*=smoothstep(8.0,19.0,Vector2(x,z).distance_to(point))
	if mask==0.0:return original
	# Large table walls made the road read as a cleared bowl. Keep the outer
	# geological route, but replace their near-slope bulk with eroded smaller ribs.
	var shaped:=floor+(original-floor)*.30
	var joints:=sin(x*.13+z*.069+sin(z*.045)*1.7)*sin(z*.087-x*.04)
	var gullies:=pow(absf(sin(z*.061+x*.025+sin(x*.048))),8.0)
	var grain:=sin(x*.30-z*.14)*sin(z*.32)
	var factor:=1.0 if z>-10 else 1.35 if z>-170 else .45 if z>-350 else .85
	shaped+=(joints*2.7+grain*.8-gullies*4.1)*factor
	return lerpf(original,shaped,mask)

func revision_4_height_at(x: float,z: float) -> float:
	return _access_height_at(x,z,environment_access_distance(x,z,false))

func _access_height_at(x: float,z: float,distance: float) -> float:
	var shaped:=revision_3_height_at(x,z)
	if distance>=20.0:return shaped
	var floor:=previous_height_at(x,z)
	# The legacy region formula jumps at z=-300. In the refined mesh this was a
	# 57-degree step on the Veil branch. Bridge only that dry access crossing;
	# the wetland rectangle ends at z=-308 and the protected road stays exact.
	if z>-306.0 and z<-294.0:
		var ramp:=lerpf(previous_height_at(x,-306.0),previous_height_at(x,-294.0),(z+306.0)/12.0)
		floor=lerpf(floor,ramp,smoothstep(12.0,20.0,absf(x-path_x(z))))
	# A 14 m floor follows the previous, traversed surface and blends into the
	# existing raised banks. Mesh, physics, flora and creature contact all sample it.
	return lerpf(floor,shaped,smoothstep(7.0,20.0,distance))

func wetland_shore_point(angle: float,bank_offset: float=0.0) -> Vector2:
	# Positive bank_offset is landward. Shared by habitat and fauna placement.
	var center:=_wetland_center()
	var direction:=Vector2(cos(angle),sin(angle))
	var level:=wetland_water_level()
	var inside:=0.0
	var outside:=1.0
	while outside<135.0 and height_at(center.x+direction.x*outside,center.y+direction.y*outside)<level+.025:
		inside=outside
		outside+=.5
	for step in 10:
		var radius:float=(inside+outside)*.5
		var point:=center+direction*radius
		if height_at(point.x,point.y)<level+.025:inside=radius
		else:outside=radius
	var radius:float=(inside+outside)*.5+bank_offset
	# A narrow dry tongue can turn back into water after the first intersection.
	# Every positive offset must still seat shore plants and fauna on dry ground.
	if bank_offset>0.0:
		while radius<135.0 and height_at(center.x+direction.x*radius,center.y+direction.y*radius)<level+.035:radius+=.20
	return center+direction*radius

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
	if not staged_boot: build_world()

func boot_yield() -> void:
	if not staged_boot: return
	var now := Time.get_ticks_usec()
	if _boot_slice_started > 0:
		build_stats["boot_max_cpu_slice_ms"] = maxf(float(build_stats.get("boot_max_cpu_slice_ms", 0.0)), (now-_boot_slice_started)/1000.0)
	if boot_frame_yield.is_valid(): await boot_frame_yield.call()
	else: await get_tree().process_frame
	_boot_slice_started = Time.get_ticks_usec()

func build_world() -> void:
	_paused = staged_boot
	_boot_slice_started = Time.get_ticks_usec()
	var stage_started := Time.get_ticks_usec()
	_rng.seed = 20260915
	_build_atmosphere()
	await boot_yield()
	_build_material()
	await boot_yield()
	await _build_terrain()
	build_stats["terrain_revision"] = TERRAIN_REVISION
	build_stats["build_ms_terrain"] = (Time.get_ticks_usec()-stage_started)/1000.0
	stage_started = Time.get_ticks_usec()
	_build_horizon()
	await boot_yield()
	_build_landmarks()
	await boot_yield()
	_build_mineral_vistas()
	await boot_yield()
	_build_rocks()
	await boot_yield()
	build_stats["build_ms_horizon_landmarks_rocks"] = (Time.get_ticks_usec()-stage_started)/1000.0
	stage_started = Time.get_ticks_usec()
	_build_wetland_pool()
	await boot_yield()
	build_stats["build_ms_water"] = (Time.get_ticks_usec()-stage_started)/1000.0
	stage_started = Time.get_ticks_usec()
	_build_root_network()
	await boot_yield()
	var habitats := HABITAT_FEATURES.new()
	habitats.name = "HabitatFeatures"
	add_child(habitats)
	await habitats.build(self)
	build_stats["build_ms_habitat"] = (Time.get_ticks_usec()-stage_started)/1000.0
	stage_started = Time.get_ticks_usec()
	_living_habitat=habitats
	_build_passage_gates()
	await boot_yield()
	_build_survey_sites()
	await boot_yield()
	_build_resonance_grove()
	await boot_yield()
	await _build_ecology()
	_build_escort_shelter()
	await boot_yield()
	_build_thermal_route()
	await boot_yield()
	_prepare_ecology_responses()
	_build_response()
	await boot_yield()
	_build_dust()
	await boot_yield()
	reset()
	if staged_boot: set_paused(true)
	build_stats["build_ms_activities_creatures"] = (Time.get_ticks_usec()-stage_started)/1000.0
	stage_started = Time.get_ticks_usec()

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
	_distant_pose_clock += delta
	var distant_pose_due := _distant_pose_clock >= .1
	if distant_pose_due: _distant_pose_clock = fmod(_distant_pose_clock,.1)
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
		var previous_position := node.position
		node.position = node.position.lerp(target, 1.0 - exp(-delta * 5.0))
		var visual_motion := clampf(node.position.distance_to(previous_position) / maxf(delta, 0.001), 0.0, 1.0)
		var width := 1.0 + pulse * 0.12
		node.scale = Vector3(width, (1.0 - alarm * (0.55 if kind=="root_choir" else 0.3) if kind=="root_choir" or (i==0 and not _escort_state.is_empty()) else 1.0) + pulse * 0.1, width)
		var detailed=node.get_node_or_null("DetailedVisual")
		# All reactions and positions keep their full tick. Sub-pixel distant limbs
		# need not run terrain IK sixty times per second; near animals stay smooth.
		if detailed!=null and (distant_pose_due or node.position.distance_squared_to(_player_position)<25600.0):
			detailed.pose(_world_time+phase,alarm,pulse,visual_motion)
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
	var tint:=Color(0.56,0.67,0.67)
	var begin:=55.0
	var finish:=430.0
	match region:
		"ember_rift":
			tint=Color(0.67,0.56,0.46);begin=58.0;finish=425.0
		"veil_marsh":
			tint=Color(0.45,0.64,0.61);begin=42.0;finish=310.0
		"pale_decay":
			tint=Color(0.59,0.55,0.61);begin=48.0;finish=390.0
	var blend:=1.0-exp(-maxf(delta,0.0)*2.0)
	_environment.fog_light_color=_environment.fog_light_color.lerp(tint,blend)
	_environment.fog_light_energy=lerpf(_environment.fog_light_energy,1.0,blend)
	_environment.fog_depth_begin=lerpf(_environment.fog_depth_begin,begin,blend)
	_environment.fog_depth_end=lerpf(_environment.fog_depth_end,finish,blend)
	_environment.fog_depth_curve=lerpf(_environment.fog_depth_curve,0.86,blend)

func set_player_state(position: Vector3, speed: float) -> void:
	_player_position = position
	_player_speed = speed
	if is_instance_valid(_living_habitat):_living_habitat.update_shadow_culling(position)

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

func observe_ecology(position: Vector3, selected_index: int = -1) -> Dictionary:
	var target: Dictionary = {}
	if selected_index == -1:
		target = nearest_ecology(position)
	elif selected_index >= 0 and selected_index < _ecology_nodes.size() and selected_index < _ecology_reactions.size():
		target = _ecology_meta[selected_index].duplicate()
		target["index"] = selected_index
		target["distance"] = position.distance_to(_ecology_nodes[selected_index].global_position)
		target["position"] = _ecology_nodes[selected_index].global_position + Vector3(0,.3,0)
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
		var palette: Color={"aurora_shelf":Color("a9bdbb"),"ember_rift":Color("a17d59"),"veil_marsh":Color("60877b"),"pale_decay":Color("a392a3")}[SURVEYS.SITES[id].region]
		var stone := _ecology_material(palette,Color.BLACK,0,0.85)
		stone.albedo_texture=load("res://assets/terrain/cc0/rock023_alb_ht.png")
		stone.uv1_triplanar=true
		var response := _ecology_material(Color("ad8751"),Color("d9a752"),0.6,0.45)
		for i in 3:
			var shard := MeshInstance3D.new()
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var height := 1.1+.47*i
			var column: Array[Vector3] = []
			for ring in 6:
				var t := ring/5.0
				for side in 9:
					var angle := side/9.0*TAU
					var profile: float=[.9,1.26,1.1,.79,1.05,.56][ring]
					var radius := .24*profile*(1.0+.13*sin(side*3.4+i))
					column.append(Vector3(cos(angle)*radius+sin(t*3+i)*.11,t*height,sin(angle)*radius*.73))
			for ring in 5:
				for side in 9:
					var j := ring*9+side
					var k := ring*9+(side+1)%9
					for index in [j,k,j+9,k,k+9,j+9]:
						surface.set_uv(Vector2(column[index].x+column[index].z,column[index].y))
						surface.add_vertex(column[index])
			surface.index()
			surface.generate_normals()
			shard.mesh = surface.commit()
			shard.material_override = stone
			shard.position = Vector3((i-1)*.63,0,0)
			shard.rotation.z = (i-1)*.07
			node.add_child(shard)
			for ridge in 3:
				_eco_sphere(shard,Vector3(.08,height*(.28+ridge*.18),.08),Vector3(.20,.07,.16),stone)
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
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.67, 0.78, 0.81)
	_environment.ambient_light_energy = 0.72
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	_environment.tonemap_exposure = 1.0
	_environment.tonemap_white = 6.0
	_environment.fog_enabled = true
	_environment.fog_mode = Environment.FOG_MODE_DEPTH
	# Depth mode uses density as maximum opacity, not exponential extinction.
	# Its 0.01 default left the regional distance controls effectively invisible.
	_environment.fog_density = 0.78
	_environment.fog_light_color = Color(0.56, 0.67, 0.67)
	_environment.fog_light_energy = 1.0
	_environment.fog_depth_begin = 55.0
	_environment.fog_depth_end = 430.0
	_environment.fog_depth_curve = 0.86
	_environment.fog_sky_affect = 0.08
	var world_environment := WorldEnvironment.new()
	world_environment.name = "BasinAtmosphere"
	world_environment.environment = _environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "LowWarmSun"
	sun.rotation_degrees = Vector3(-28.0, -135.0, 0.0)
	sun.light_color = Color(1.0, 0.90, 0.74)
	sun.light_energy = 0.66
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.04
	sun.shadow_blur = 2.0
	sun.shadow_opacity = 0.56
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.name = "DistantWarmHorizon"
	rim.rotation_degrees = Vector3(-18.0, 135.0, 0.0)
	rim.light_color = Color(0.91, 0.66, 0.45)
	rim.light_energy = 0.06
	rim.shadow_enabled = false
	add_child(rim)

func _market_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):return load(path) as Texture2D
	# CPU authoring can read its own newly written maps without an editor/cache
	# import. The exported game uses the imported resources supplied by root.
	if OS.has_feature("web"):return null
	var image:=Image.load_from_file(ProjectSettings.globalize_path(path))
	if image==null:return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _build_material() -> void:
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = TERRAIN_SHADER
	_terrain_material.set_shader_parameter("wetland_center", _wetland_center())
	var pool := _wetland_center()
	_terrain_material.set_shader_parameter("water_level",height_at(pool.x,pool.y)+.37)
	_terrain_material.set_shader_parameter("basalt_map", load("res://assets/terrain/basalt_albedo.png"))
	_terrain_material.set_shader_parameter("dust_map", load("res://assets/terrain/dust_albedo.png"))
	_terrain_material.set_shader_parameter("normal_map", load("res://assets/terrain/geology_normal.png"))
	_terrain_material.set_shader_parameter("rough_map",_market_texture("res://assets/market_environment/cc0/Ground045_1K-JPG_Roughness.jpg"))
	_terrain_material.set_shader_parameter("rock_detail",_market_texture("res://assets/market_environment/cc0/Rock055_1K-JPG_Color.jpg"))
	_terrain_material.set_shader_parameter("rock_normal",_market_texture("res://assets/market_environment/cc0/Rock055_1K-JPG_NormalGL.jpg"))
	_terrain_material.set_shader_parameter("wet_detail",_market_texture("res://assets/market_environment/cc0/Ground045_1K-JPG_Color.jpg"))
	_terrain_material.set_shader_parameter("wet_normal",_market_texture("res://assets/market_environment/cc0/Ground045_1K-JPG_NormalGL.jpg"))
	_terrain_material.set_shader_parameter("grass_detail",_market_texture("res://assets/market_environment/cc0/Grass005_1K-JPG_Color.jpg"))
	_strata_material = ShaderMaterial.new()
	_strata_material.shader = STRATA_SHADER
	_strata_material.set_shader_parameter("basalt_map",_market_texture("res://assets/market_environment/cc0/Rock055_1K-JPG_Color.jpg"))
	_strata_material.set_shader_parameter("rough_map",_market_texture("res://assets/market_environment/cc0/Rock055_1K-JPG_Roughness.jpg"))
	_strata_material.set_shader_parameter("roughness_alpha",false)
	_strata_material.set_shader_parameter("structure_normal",_market_texture("res://assets/market_environment/cc0/Rock055_1K-JPG_NormalGL.jpg"))

func _build_terrain(authoring: bool = false) -> void:
	var baked_path := "res://assets/alien_renewal/terrain_v%d.res" % TERRAIN_REVISION
	if not authoring and ResourceLoader.exists(baked_path):
		var ground := MeshInstance3D.new()
		ground.name = "CollidableDustBasin"
		ground.mesh = load(baked_path) as ArrayMesh
		ground.material_override = _terrain_material
		ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ground)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = load("res://assets/alien_renewal/terrain_collision_v%d.res" % TERRAIN_REVISION)
		ground.add_child(body)
		body.add_child(shape)
		build_stats["terrain_triangles"] = _triangle_count(ground.mesh)
		build_stats["terrain_baked_revision"] = TERRAIN_REVISION
		build_stats["terrain_unique_samples"] = ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		build_stats["terrain_grid_metres"] = Vector2(2,3)
		return
	const NX := 193
	const NZ := 301
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := 0
	var sampled: Dictionary = {}
	for iz in NZ-1:
		if staged_boot and Time.get_ticks_usec()-_boot_slice_started > 8000: await boot_yield()
		for ix in NX-1:
			var x0 := -192.0+ix*(384.0/float(NX-1))
			var z0 := -700.0+iz*(900.0/float(NZ-1))
			# Only the bank needs sub-metre geometry. Render and collision use the same mesh.
			var cell_x := 384.0/float(NX-1)
			var cell_z := 900.0/float(NZ-1)
			var center := Vector2(x0+cell_x*.5,z0+cell_z*.5)
			var divisions := 3 if wetland_basin_distance(center)<1.48 else 1
			var stitch_left := divisions>1 and wetland_basin_distance(center-Vector2(cell_x,0))>=1.48
			var stitch_right := divisions>1 and wetland_basin_distance(center+Vector2(cell_x,0))>=1.48
			var stitch_front := divisions>1 and wetland_basin_distance(center-Vector2(0,cell_z))>=1.48
			var stitch_back := divisions>1 and wetland_basin_distance(center+Vector2(0,cell_z))>=1.48
			var dx := 384.0/float(NX-1)/divisions
			var dz := 900.0/float(NZ-1)/divisions
			for rz in divisions:
				for rx in divisions:
					var origin := Vector2(x0+rx*dx,z0+rz*dz)
					for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
						var x := origin.x+corner.x*dx
						var z := origin.y+corner.y*dz
						var key:=Vector2(x,z)
						if not sampled.has(key):
							var y:=height_at(x,z)
							if (stitch_left and rx+corner.x==0) or (stitch_right and rx+corner.x==divisions):
								y=lerpf(height_at(x,z0),height_at(x,z0+cell_z),(z-z0)/cell_z)
							if (stitch_front and rz+corner.y==0) or (stitch_back and rz+corner.y==divisions):
								y=lerpf(height_at(x0,z),height_at(x0+cell_x,z),(x-x0)/cell_x)
							sampled[key]=Vector3(x,y,z)
						st.set_uv(Vector2(x,z)*.11)
						st.add_vertex(sampled[key])
					triangles += 2
	await boot_yield()
	st.index()
	# The shader uses world-space projection. Indexed smooth normals come from the
	# actual collision surface and avoid four extra height queries per vertex.
	st.generate_normals()
	await boot_yield()
	var ground := MeshInstance3D.new()
	ground.name = "CollidableDustBasin"
	ground.mesh = st.commit()
	ground.material_override = _terrain_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	ground.create_trimesh_collision()
	build_stats["terrain_triangles"] = triangles
	build_stats["terrain_unique_samples"] = sampled.size()
	build_stats["terrain_grid_metres"] = Vector2(384.0/float(NX-1),900.0/float(NZ-1))

func _build_horizon(authoring: bool = false) -> void:
	var baked_path := "res://assets/alien_renewal/horizon_v1.res"
	if not authoring and ResourceLoader.exists(baked_path):
		var rim := MeshInstance3D.new()
		rim.name = "AuthoredDistantCaldera"
		rim.mesh = load(baked_path) as ArrayMesh
		rim.material_override = _horizon_material()
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rim)
		build_stats["horizon_triangles"] = _triangle_count(rim.mesh)
		build_stats["horizon_baked"] = true
		return
	const SEGMENTS := 256
	const RINGS := 17
	var points: Array[Vector3] = []
	for r in RINGS:
		for a in SEGMENTS: points.append(_horizon_point(a,r))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in RINGS-1:
		for a in SEGMENTS:
			for cell: Vector2i in [Vector2i(a,r),Vector2i(a,r+1),Vector2i((a+1)%SEGMENTS,r),Vector2i((a+1)%SEGMENTS,r),Vector2i(a,r+1),Vector2i((a+1)%SEGMENTS,r+1)]:
				var p: Vector3=points[cell.y*SEGMENTS+cell.x]
				var along: Vector3=points[cell.y*SEGMENTS+(cell.x+1)%SEGMENTS]-points[cell.y*SEGMENTS+posmod(cell.x-1,SEGMENTS)]
				var across: Vector3=points[mini(cell.y+1,RINGS-1)*SEGMENTS+cell.x]-points[maxi(cell.y-1,0)*SEGMENTS+cell.x]
				var normal:=across.cross(along).normalized()
				if normal.y<0: normal=-normal
				st.set_normal(normal)
				# Broad exposed ridge versus cooler recess, not repeated height bands.
				st.set_color(Color(.35,.44,.45).lerp(Color(.55,.56,.48),smoothstep(40.0,155.0,p.y)))
				st.set_uv(Vector2(p.x,p.z)*.008)
				st.add_vertex(p)
	st.index()
	st.generate_tangents()
	var rim:=MeshInstance3D.new()
	rim.name="AuthoredDistantCaldera"
	rim.mesh=st.commit()
	rim.material_override=_horizon_material()
	rim.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)
	build_stats["horizon_triangles"] = SEGMENTS*(RINGS-1)*2

func _horizon_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.albedo_texture = _market_texture("res://assets/market_environment/cc0/Rock055_1K-JPG_Color.jpg")
	material.normal_enabled = true
	material.normal_texture = _market_texture("res://assets/market_environment/cc0/Rock055_1K-JPG_NormalGL.jpg")
	material.normal_scale = .14
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * .025
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = .97
	material.metallic_specular = .06
	return material

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
	var sector := angle/TAU*float(RIM_HEIGHTS.size())
	var index := posmod(floori(sector),RIM_HEIGHTS.size())
	var blend := sector-float(floori(sector))
	blend = blend*blend*(3.0-2.0*blend)
	var peak: float = lerpf(RIM_HEIGHTS[index],RIM_HEIGHTS[(index+1)%RIM_HEIGHTS.size()],blend)*1.38
	peak += 31.0*sin(angle*7.0+1.3*sin(angle*3.0)) + 18.0*sin(angle*23.0+sin(angle*5.0))
	# Signal corridor points north; the far gap frames the mineral silhouette.
	peak *= 1.0 - 0.64 * exp(-pow((angle - 4.71) / 0.24, 2.0))
	var crest := .34+.065*sin(angle*3.0+.8)+.03*sin(angle*7.0)
	var ridge := peak*smoothstep(crest-.19,crest-.018,radial)*(1.0-smoothstep(crest+.024,crest+.22,radial))
	var fissures := pow(absf(sin(angle*13.0+radial*3.0+sin(angle*4.0))),5.0)*.19
	ridge *= 1.0 - fissures
	# Unequal lava benches interrupt the continuous soft cone profile.
	ridge += exp(-pow((radial-.13-.035*sin(angle*5.0))/.08,2.0))*(22.0+13.0*sin(angle*4.0+1.0))
	var biome_scale:=.91 if z>-12.0 else 1.04 if z>-170.0 else .79 if z>-360.0 else .83
	var height := lerpf(foothill - 3.0, ridge*biome_scale + 5.0, smoothstep(0.0, 0.18, radial))
	return Vector3(x, height, z)

func _build_boundary_outcrops() -> void:
	if not ResourceLoader.exists(BOUNDARY_TEXTURE) or not ResourceLoader.exists(BOUNDARY_TERRACES):
		build_stats["boundary_texture_pending"]=true
		return
	var surfaces: Array[SurfaceTool]=[]
	var materials: Array[ShaderMaterial]=[]
	for path: String in [BOUNDARY_TEXTURE,BOUNDARY_TERRACES]:
		var material:=ShaderMaterial.new()
		material.shader=BOUNDARY_SHADER
		material.set_shader_parameter("rock_strip",load(path))
		materials.append(material)
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces.append(surface)
	# x,z,width,height,u0,u1,yaw,type(0=spires,1=low terraces).
	# Broad sky openings and different silhouettes, not a continuous rock curtain.
	var cards: Array = [
		[-330,120,245,70,.0,1.0,.12,1],[360,80,210,75,1.0,.0,-.12,1],[-500,155,260,90,.0,1.0,.15,1],
		[-370,-120,115,105,.0,.20,-.10,0],[390,-160,150,92,.65,1.0,.13,0],
		[-350,-328,260,100,.20,.65,.09,0],[380,-300,230,80,.55,1.0,-.17,1],[-525,-395,130,135,.65,1.0,.12,0],
		[-350,-565,280,62,.0,1.0,-.14,1],[430,-590,260,76,1.0,.0,.05,1],
		[0,370,300,75,.0,1.0,-.08,1],[-20,-915,310,85,1.0,.0,.10,1]]
	var bounds: Array=[]
	var abutments:=SurfaceTool.new()
	abutments.begin(Mesh.PRIMITIVE_TRIANGLES)
	for entry: Array in cards:
		var st:SurfaceTool=surfaces[int(entry[7])]
		var anchor:=Vector3(float(entry[0]),0,float(entry[1]))
		var width:float=entry[2]
		var height:float=entry[3]
		var target:=Vector3(path_x(clampf(anchor.z,-650,150)),0,clampf(anchor.z,-650,150))
		var toward:Vector3=(target-anchor).normalized().rotated(Vector3.UP,float(entry[6]))
		var across:=Vector3(toward.z,0,-toward.x)
		var base:=height_at(anchor.x,anchor.z)-8.0
		var tint:=Color(.82,.89,.93) if anchor.z>-12 else Color(.91,.82,.73) if anchor.z>-170 else Color(.78,.85,.82) if anchor.z>-360 else Color(.83,.80,.82)
		var corners: Array[Vector3]=[]
		for uv: Vector2 in [Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,0)]:
			corners.append(anchor+across*((uv.x-.5)*width)+Vector3.UP*(base+(1-uv.y)*height))
		for index in [0,2,1,1,2,3]:
			var uv:Vector2=[Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,0)][index]
			st.set_normal(toward);st.set_color(tint)
			st.set_uv(Vector2(lerpf(float(entry[4]),float(entry[5]),uv.x),uv.y));st.set_uv2(uv)
			st.add_vertex(corners[index])
		# Rock buttresses sit in front of the low-alpha crop valleys and mask
		# lateral card ends with real volume from changing player viewpoints.
		for end in 2:
			var side:float=-1.0 if end==0 else 1.0
			var foot:=anchor+across*(side*width*.47)+toward*13.0
			var rise:float=height*(.26 if int(entry[7])==0 else .16)+4.0
			_append_fault_fin(abutments,foot,Vector3(23.0,rise,31.0),atan2(across.z,across.x),bounds.size()*2+end+73)
		bounds.append({"anchor":anchor,"corners":corners,"uv_span":Vector2(entry[4],entry[5]),"texture_kind":entry[7]})
	var mesh:=ArrayMesh.new()
	for index in surfaces.size():
		surfaces[index].commit(mesh)
		mesh.surface_set_material(index,materials[index])
	var node:=MeshInstance3D.new()
	node.name="DistantBoundaryOutcrops"
	node.mesh=mesh
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("fixed_boundary_cards",bounds)
	add_child(node)
	build_stats["boundary_cards"]=cards.size()
	build_stats["boundary_card_triangles"]=cards.size()*2
	build_stats["boundary_card_draw_surfaces"]=surfaces.size()
	abutments.index();abutments.generate_normals();abutments.generate_tangents()
	var stone:=MeshInstance3D.new()
	stone.name="BoundaryRockAbutments"
	stone.mesh=abutments.commit()
	stone.material_override=_strata_material
	stone.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stone)
	build_stats["boundary_geometry_abutments"]=cards.size()*2

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

func _build_mineral_vistas() -> void:
	# One large, incomplete mineral rib at each ecological landmark. All footings
	# sit beyond the driving floor; the Aurora arch frames the first actual route.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vistas := [Vector4(0,68,32,21),Vector4(-55,-78,18,31),Vector4(-70,-262,24,17),Vector4(55,-514,22,24)]
	var tones := [Color("b9cbc7"),Color("b38c66"),Color("738f83"),Color("b5a7b1")]
	for kind in vistas.size():
		var v: Vector4 = vistas[kind]
		var cx := path_x(v.y)+v.x
		var points: Array[Vector3] = []
		const RINGS := 29
		const SIDES := 11
		for ring in RINGS:
			var t := float(ring)/float(RINGS-1)
			var angle := PI*(1.0-pow(t,.86))
			var x := cos(angle)*v.z+sin(t*TAU)*v.z*.095
			var z := (t-.5)*6.0+sin(t*PI)*6.0+sin(t*TAU)*2.2
			var y := sin(angle)*v.w*(.83+.23*t)+lerpf(height_at(cx-v.z,v.y-3),height_at(cx+v.z,v.y+3),t)-1.1
			var spine := Vector3(cx+x,y,v.y+z)
			var tangent := Vector3(sin(angle)*v.z,-cos(angle)*v.w,3).normalized()
			var across := Vector3.FORWARD
			var up := tangent.cross(across).normalized()
			var thickness := 2.1+5.4*pow(absf(2.0*t-1.0),1.5)+.65*sin(t*17.0+kind)
			for side in SIDES:
				var a := float(side)/SIDES*TAU
				var fracture := 1.0+.19*sin(a*4.0+ring*.47+kind)+.06*cos(a*7.0-ring*.31)
				var broken_edge := .42*sin(a*3.0+kind)+.21*cos(a*7.0) if ring in [16-kind,17-kind] else 0.0
				points.append(spine+(across*cos(a)*1.6+up*sin(a)*.85)*thickness*fracture+tangent*broken_edge)
		for ring in RINGS-1:
			# The crown fracture exposes a gap rather than an engineered perfect arc.
			if ring == 16-kind or (kind == 3 and ring > 21): continue
			for side in SIDES:
				var a := ring*SIDES+side
				var b := ring*SIDES+(side+1)%SIDES
				for i: int in [a,a+SIDES,b,b,a+SIDES,b+SIDES]:
					st.set_color(tones[kind].darkened(.06+.10*(.5+.5*sin(side*1.8+ring*.21))))
					st.set_uv(Vector2(points[i].x+points[i].z,points[i].y)*.12)
					st.add_vertex(points[i])
		# Buttressed ledges merge the aperture into adjoining hills. Unequal strata
		# broaden outwards, leaving every road/activity approach open.
		for side in [-1.0,1.0]:
			var foot := Vector2(cx+side*(v.z+17.0),v.y+(-9.0 if side<0 else 13.0))
			if environment_access_distance(foot.x,foot.y)<24.0:continue
			var bottom := height_at(foot.x,foot.y)-3.0
			for layer in 3:
				var scale := 1.0-float(layer)*.19
				var width := (22.0 if side<0 else 18.0)*scale
				var depth := (27.0 if side<0 else 34.0)*scale
				var low := bottom+layer*4.3
				var high := low+5.8
				var rim: Array[Vector3] = []
				for edge in 8:
					var a := float(edge)/8.0*TAU+.12*layer
					var p := Vector3(cos(a)*width,0,sin(a)*depth).rotated(Vector3.UP,side*.22)
					rim.append(Vector3(foot.x+p.x,high+.8*sin(edge*2.1+layer),foot.y+p.z))
				for edge in 8:
					var a: Vector3=Vector3(rim[edge].x,low,rim[edge].z)
					var b: Vector3=Vector3(rim[(edge+1)%8].x,low,rim[(edge+1)%8].z)
					for p: Vector3 in [a,rim[edge],b,b,rim[edge],rim[(edge+1)%8],Vector3(foot.x,high+.3,foot.y),rim[edge],rim[(edge+1)%8]]:
						st.set_color(tones[kind].darkened(.11+layer*.035))
						st.set_uv(Vector2(p.x+p.z,p.y)*.12)
						st.add_vertex(p)
	st.index()
	st.generate_normals()
	st.generate_tangents()
	var node := MeshInstance3D.new()
	node.name = "ListeningReefMineralRibs"
	node.mesh = st.commit()
	var material := _strata_material.duplicate() as ShaderMaterial
	material.set_shader_parameter("use_vertex_color",true)
	material.set_shader_parameter("surface_roughness",.88)
	node.material_override = material
	add_child(node)
	node.create_trimesh_collision()
	for child in node.get_children():
		if child is CollisionObject3D: child.collision_layer = 129
	build_stats["listening_reef_rib_triangles"] = _triangle_count(node.mesh)

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

func _membrane_leaf_mesh() -> ArrayMesh:
	# Thin folded lamina, with a narrow living stalk and a curled interrupted edge.
	# Reused by all response plants; their existing pivots/scale/state stay intact.
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows:Array[Vector3]=[]
	for row in 7:
		var t:=row/6.0
		var width:float=[.03,.38,.78,.96,.75,.41,.015][row]
		for side:float in [-1.0,0.0,1.0]:
			var edge:=1.0-.18*exp(-pow((t-.66)/.15,2.0)) if side<0 else 1.0
			rows.append(Vector3(side*width*edge+.10*sin(t*PI),t*2.0-1.0,sin(t*PI)*(.16-.19*absf(side))+side*.05*t*t))
	for row in 6:
		for index:int in [0,3,1,1,3,4,1,4,2,2,4,5]:
			var vertex:=row*3+index
			st.set_uv(Vector2((float(vertex%3))*.5,float(vertex/3)/6.0))
			st.add_vertex(rows[vertex])
	st.index();st.generate_normals();st.generate_tangents()
	return st.commit()

func _build_passage_gates() -> void:
	var route := passage_route()
	var leaf_mesh := _membrane_leaf_mesh()
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
				leaf.scale = Vector3(0.72 - leaf_index * 0.07, 2.15 + leaf_index * 0.42, 1.0)
				leaf.rotation = Vector3(0.08 * (leaf_index - 1), side * 0.12 * leaf_index, side * (0.13 + leaf_index * 0.04))
				wing.add_child(leaf)
				# Sphere fins have a narrow base above their parent origin. Give each
				# one a continuous stalk rather than leaving detached floating leaves.
				var stem_root := Vector3(leaf.position.x, 0.0, leaf.position.z)
				var ground_point := wing.to_global(stem_root)
				# The broad terrain triangles interpolate below the analytic field on
				# some banks. Embed enough root to retain contact through gate yaw.
				stem_root.y = height_at(ground_point.x, ground_point.z) - wing.global_position.y - 0.50
				_eco_rod(wing, stem_root, leaf.position, 0.075 + leaf_index * 0.008, rib_material)
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
			# Root ribs follow the displaced bank anchor and its actual terrain.
			# The old gate-centred rods could float across the low driving bed.
			for root_side in [-1.0, 1.0]:
				var root_tip := anchor + Vector3(side * 1.0, 0.0, root_side * 1.65)
				var root_world := gate.to_global(root_tip)
				root_tip.y = height_at(root_world.x, root_world.z) - gate.position.y - 0.08
				_eco_rod(gate, root_tip, anchor + Vector3(0.0, 0.42, root_side * 0.35), 0.14, rib_material)
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

func ecology_anchor_points() -> Array[Vector2]:
	var points: Array[Vector2]=[]
	for i in 4:
		var z:float=-105.0+i*7.0
		points.append(Vector2(path_x(z)+7.0+sin(i*2.1)*2.0,z))
	for i in 5:
		var z:float=-285.0-i*5.5
		points.append(Vector2(path_x(z)-5.5+cos(i*1.8)*3.0,z))
	for i in 4:
		var z:float=-470.0-i*8.0
		points.append(Vector2(path_x(z)+8.0+sin(i*1.9)*3.0,z))
	return points

func _build_ecology() -> void:
	var anchors:=ecology_anchor_points()
	# One visual contract for every member; gameplay kind, positions and reactions stay stable.
	for i in 4:
		await boot_yield()
		var node := Node3D.new()
		node.name = "VeyraLithovore_%02d" % i
		var z:float=anchors[i].y
		var x:float=anchors[i].x
		node.position = Vector3(x, height_at(x,z) + 0.35, z)
		add_child(node)
		_attach_creature_visual(node, "veyra")
		_ecology_nodes.append(node)
		_ecology_meta.append({"kind":"veyra","label":"VEYRA / 礦脈群體","phase":float(i)*1.7,"base":node.position})
	for i in 5:
		await boot_yield()
		var node := Node3D.new()
		node.name = "AeralVeil_%02d" % i
		var z:float=anchors[i+4].y
		var x:float=anchors[i+4].x
		node.position = Vector3(x, height_at(x,z) + 5.0 + (i % 2) * 1.6, z)
		add_child(node)
		_attach_creature_visual(node, "aeral")
		_ecology_nodes.append(node)
		_ecology_meta.append({"kind":"aeral","label":"AERAL VEIL / 霧膜群","phase":float(i)*1.1,"base":node.position,"passage_index":i})
	for i in 4:
		await boot_yield()
		var node := Node3D.new()
		node.name = "MorrowShell_%02d" % i
		var z:float=anchors[i+9].y
		var x:float=anchors[i+9].x
		node.position = Vector3(x, height_at(x,z) + 0.7, z)
		add_child(node)
		_attach_creature_visual(node, "morrow")
		_ecology_nodes.append(node)
		_ecology_meta.append({"kind":"root_choir","label":"MORROW SHELL / 孢殼群","phase":float(i)*2.0,"base":node.position})
	build_stats["detailed_major_creatures"] = _ecology_nodes.size()

func _attach_creature_visual(parent: Node3D, species: String) -> void:
	var detailed := CREATURE_VISUAL.new()
	detailed.name = "DetailedVisual"
	parent.add_child(detailed)
	detailed.configure(species)

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
		var merged := combined.commit()
		target.append(merged)
		# Current rock GLBs each have one original material across every surface.
		# Preserve it for fixed-geometry A/B; do not invent missing PBR maps.
		var original_material: Material = node.get_active_material(0)
		var compatible := original_material != null
		for index in original.get_surface_count():
			compatible = compatible and node.get_active_material(index) == original_material
		if compatible: _rock_original_materials[merged.get_instance_id()] = original_material
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
	if ResourceLoader.exists("res://assets/environment_upgrade/fractured/rocks_low.glb"):
		var low_source: Node = (load("res://assets/environment_upgrade/fractured/rocks_low.glb") as PackedScene).instantiate()
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
	# Small erosion deposits share existing batches and retain later placement randomness.
	var placement_state := _rng.state
	for i in 780:
		var z := _rng.randf_range(-610.0, 170.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := path_x(z) + side * _rng.randf_range(6.5, 22.0)
		var size := _rng.randf_range(.09, .32)
		_place_rock(x,z,Vector3(size*1.5,size*.5,size),true,false)
	_rng.state = placement_state
	var rock_material := StandardMaterial3D.new()
	rock_material.vertex_color_use_as_albedo = true
	rock_material.albedo_color = Color(0.74, 0.72, 0.69)
	rock_material.albedo_texture = _market_texture("res://assets/market_environment/cc0/Rock055_1K-JPG_Color.jpg")
	rock_material.normal_enabled = true
	rock_material.normal_texture = _market_texture("res://assets/market_environment/cc0/Rock055_1K-JPG_NormalGL.jpg")
	rock_material.normal_scale = 0.65
	rock_material.roughness_texture = _market_texture("res://assets/market_environment/cc0/Rock055_1K-JPG_Roughness.jpg")
	rock_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	rock_material.roughness = 0.95
	rock_material.uv1_triplanar = true
	rock_material.uv1_world_triplanar = true
	rock_material.uv1_scale = Vector3(.36, .36, .36)
	rock_material.metallic_specular = .22
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

	# Intersect the EXISTING render/collision triangles with the plane. This is a
	# derived water mesh, not a second basin/height field or a circular apron.
	var water := MeshInstance3D.new()
	water.name = "ContainedShallowWater"
	water.layers = 2
	water.mesh = _terrain_clipped_water(_wetland_root.position, .37)
	water.position.y = 0.37
	_wetland_water_material = ShaderMaterial.new()
	_wetland_water_material.shader = WETLAND_SHADER
	_wetland_water_material.set_shader_parameter("pool_center",center)
	_wetland_water_material.set_shader_parameter("water_level",_wetland_root.position.y+.37)
	water.material_override = _wetland_water_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wetland_root.add_child(water)
	var reflection := ReflectionProbe.new()
	reflection.name = "LocalShoreReflection"
	reflection.position = Vector3(-21,8.0,32)
	reflection.size = Vector3(120,42,145)
	reflection.max_distance = 600.0
	reflection.cull_mask = 1
	reflection.reflection_mask = 2
	reflection.update_mode = ReflectionProbe.UPDATE_ONCE
	reflection.box_projection = true
	reflection.intensity = 1.05
	_wetland_root.add_child(reflection)

	# Moist sediment is shaded directly on the authoritative terrain; no intersecting apron.
	build_stats["shore_shared_height_field"] = true
	var rock_material := _passage_material(Color("4e5d58"))
	rock_material.emission_energy_multiplier = 0.015
	var plant_material := _wetland_ground_material(Color("456253"))
	var membrane_mesh:=_membrane_leaf_mesh()
	plant_material.emission = Color("6aa88f")
	plant_material.emission_energy_multiplier = 0.025
	# Three depositional tongues, not an evenly spaced necklace. Low stones share
	# the terrain contact and leave the eastern study approach open.
	var shore_stones := [Vector3(-4.2,0,-1.8),Vector3(-4.7,0,-1.3),Vector3(-4.8,0,-2.3),Vector3(-5.3,0,-2.0),Vector3(-3.8,0,3.2),Vector3(-4.5,0,3.6),Vector3(-3.2,0,4.0),Vector3(1.7,0,4.8),Vector3(2.1,0,4.5),Vector3(2.8,0,4.7),Vector3(2.5,0,5.3)]
	for i in shore_stones.size():
		var local: Vector3 = shore_stones[i]
		var rock_scale := Vector3(.55+float(i%3)*.17,.19+float((i+1)%3)*.07,.43+float((i+2)%4)*.12)
		_root_ground_rock(_wetland_root,local,rock_scale,rock_material,60+i)

	for i in 9:
		var angle: float = [1.22,1.44,1.85,2.62,2.84,3.14,3.45,4.28,4.55][i]
		var radius := _pool_edge_radius(center,angle)+.65+float(i%3)*.53
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
			lobe.mesh = membrane_mesh
			lobe.scale.z = 1.0
			var closed_angle := side * 0.12
			var open_angle := side * (0.58 + float(i % 3) * 0.08)
			lobe.rotation.z = closed_angle
			lobes.append(lobe)
			closed.append(closed_angle)
			opened.append(open_angle)
		_wetland_plants.append({"node":plant, "lobes":lobes, "closed":closed, "opened":opened, "phase":float(i) * 0.91})

	for i in 4:
		var angle := float(i) / 4.0 * TAU + 0.18
		var vein_material := _ecology_material(Color("514638"), Color("598b66"), 0.015, 0.94)
		vein_material.metallic_specular = 0.0
		_wetland_vein_materials.append(vein_material)
		for segment in 4:
			var t0 := segment/4.0
			var t1 := (segment+1)/4.0
			var a0 := angle+sin(t0*3.5+i)*.19
			var a1 := angle+sin(t1*3.5+i)*.19
			var r0 := .55+t0*3.0
			var r1 := .55+t1*3.0
			var p0 := Vector3(cos(a0)*r0,0,sin(a0)*r0)
			var p1 := Vector3(cos(a1)*r1,0,sin(a1)*r1)
			p0.y=height_at(center.x+p0.x,center.y+p0.z)-_wetland_root.position.y+.035
			p1.y=height_at(center.x+p1.x,center.y+p1.z)-_wetland_root.position.y+.035
			_eco_rod(_wetland_root,p0-Vector3.UP*.08,p1-Vector3.UP*.08,.010,vein_material)

	_build_wetland_reader(plant_material)
	build_stats["wetland_pool_radius"] = 41.0
	build_stats["wetland_water_level_offset"] = .37
	build_stats["wetland_static_reflection_probes"] = 1
	build_stats["wetland_bowl_radius"] = 48.0
	build_stats["wetland_connected_backwater_length_m"] = water.mesh.get_aabb().size.z
	build_stats["wetland_membrane_plants"] = _wetland_plants.size()

func _terrain_clipped_water(origin: Vector3,level_offset: float,authoring: bool = false) -> ArrayMesh:
	var center := _wetland_center()
	var expected := Vector3(center.x,height_at(center.x,center.y),center.y)
	var baked_path := "res://assets/alien_renewal/water_surface_v%d.res" % TERRAIN_REVISION
	if not authoring and is_equal_approx(level_offset,.37) and origin.distance_to(expected)<.001 and ResourceLoader.exists(baked_path):
		var mesh := load(baked_path) as ArrayMesh
		build_stats["water_clipped_triangles"] = _triangle_count(mesh)
		build_stats["water_contact_source"] = "baked_existing_collidable_terrain_triangles"
		build_stats["water_baked_revision"] = TERRAIN_REVISION
		return mesh
	var ground: MeshInstance3D = get_node("CollidableDustBasin")
	var faces := ground.mesh.get_faces()
	var level := origin.y+level_offset
	var polygons: Array = []
	var vertex_links: Dictionary = {}
	var nearest := INF
	var seed := 0
	for i in range(0,faces.size(),3):
		var a := faces[i]
		if Vector2(a.x-origin.x,a.z-origin.z).length()>135.0: continue
		var polygon: Array[Vector3] = []
		for j in 3:
			var p := faces[i+j]
			var q := faces[i+(j+1)%3]
			var p_inside := p.y<level
			var q_inside := q.y<level
			if p_inside: polygon.append(p)
			if p_inside != q_inside: polygon.append(p.lerp(q,(level-p.y)/(q.y-p.y)))
		if polygon.size()<3: continue
		var index := polygons.size()
		polygons.append(polygon)
		for point: Vector3 in polygon:
			var key := Vector2i(roundi(point.x*1000),roundi(point.z*1000))
			if not vertex_links.has(key): vertex_links[key]=[]
			vertex_links[key].append(index)
			var distance := Vector2(point.x-origin.x,point.z-origin.z).length_squared()
			if distance<nearest: nearest=distance; seed=index
	# Keep only the water component connected to the actual bowl centre.
	# Nearby low terrain outside the bowl must not become disconnected puddles.
	if polygons.is_empty():
		push_error("WETLAND_WATER_COMPONENT_EMPTY")
		return ArrayMesh.new()
	var queue: Array[int] = [seed]
	var visited: Dictionary = {seed:true}
	var cursor := 0
	while cursor<queue.size():
		for point: Vector3 in polygons[queue[cursor]]:
			var key := Vector2i(roundi(point.x*1000),roundi(point.z*1000))
			for index: int in vertex_links[key]:
				if not visited.has(index): visited[index]=true; queue.append(index)
		cursor+=1
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for index: int in queue:
		var polygon: Array=polygons[index]
		for j in range(1,polygon.size()-1):
			for point: Vector3 in [polygon[0],polygon[j],polygon[j+1]]:
				var local := Vector3(point.x-origin.x,0,point.z-origin.z)
				surface.set_normal(Vector3.UP)
				surface.set_color(Color(clampf((level-point.y)/2.0,0.0,1.0),0,0,1))
				surface.set_uv(Vector2(local.x,local.z)*.1)
				surface.add_vertex(local)
			count+=1
	surface.index()
	surface.generate_tangents()
	build_stats["water_clipped_triangles"] = count/3
	build_stats["water_contact_source"] = "existing_collidable_terrain_triangles"
	return surface.commit()

func _pool_edge_radius(center: Vector2,angle: float) -> float:
	return wetland_shore_point(angle).distance_to(center)

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
		vein.emission_energy_multiplier = response * (0.025 + vein_pulse * 0.025)
		vein.albedo_color = Color("423b2c") if _wetland_alarm > 0.5 else Color("373c2b").lerp(Color("4a6750"), response * 0.55)

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
	if wetland_basin_distance(Vector2(x,z))<1.45+footprint*.055:return
	if environment_access_distance(x,z)<7.0+footprint:return
	var bounds := _rock_meshes[type].get_aabb()
	var position := Vector3(x, height_at(x, z) - bounds.position.y * size.y - size.y * 0.12, z)
	for ix in 2:
		for iz in 2:
			var foot:=basis*(bounds.position+Vector3(bounds.size.x*ix,0,bounds.size.z*iz))
			position.y=minf(position.y,height_at(x+foot.x,z+foot.z)-foot.y-size.y*.06)
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
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		var p:Vector3=transforms[i].origin
		var tone:Color=Color("a2b7b6") if p.z>-10 else Color("b69a7c") if p.z>-170 else Color("8d9f89") if p.z>-350 else Color("b2a4ae")
		mm.set_instance_color(i,tone.darkened(.10+.09*sin(p.x*.16+p.z*.04)).srgb_to_linear())
	var instance := MultiMeshInstance3D.new()
	instance.name = "SmallBasaltDressing" if small else "AuthoredBasaltClusters"
	instance.multimesh = mm
	instance.material_override = material
	if _rock_original_materials.has(mesh.get_instance_id()):
		_rock_material_pairs.append({"node":instance,"authored":material,"original":_rock_original_materials[mesh.get_instance_id()]})
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
	var reflection := get_node_or_null("PairedMarshStudy/LocalShoreReflection")
	if reflection!=null:reflection.visible=not value
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
	_distant_pose_clock = 0.0
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

func _debug_material_allowed() -> bool:
	if not OS.has_feature("web"): return OS.has_feature("editor")
	return bool(JavaScriptBridge.eval("['localhost','127.0.0.1','[::1]'].includes(location.hostname) && new URLSearchParams(location.search).get('review') === '1'",true))

func debug_set_material_variant(variant: String) -> Dictionary:
	if not _debug_material_allowed(): return {"applied":false,"reason":"local review only"}
	if variant not in ["original","authored"]: return {"applied":false,"reason":"unknown variant"}
	for pair in _rock_material_pairs: pair.node.material_override = pair[variant]
	_material_variant = variant
	var flora: Dictionary = _living_habitat.debug_set_material_variant(variant) if is_instance_valid(_living_habitat) else {}
	return {"applied":true,"variant":variant,"rock_batches":_rock_material_pairs.size(),"flora":flora,"geometry_changed":false,"pose_changed":false,"light_changed":false,"limit":"Procedural kits/terrain/water have no imported original counterpart. Rock originals have vertex color and normal, no albedo/roughness maps."}
