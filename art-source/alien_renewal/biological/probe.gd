extends SceneTree
## Isolated dummy-renderer contract checks; no visual or Web verdict.
class TestTerrain:
	extends Node3D
	func height_at(x: float, z: float) -> float: return x * 0.035 + z * 0.02
	func path_x(_z: float) -> float: return 0.0
	func spawn_origin() -> Vector3: return Vector3(0, 0, 0)

var checks: Dictionary = {}
var failures: Array[String] = []
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	run.call_deferred()

func check(label: String, condition: bool) -> void:
	checks[label]=condition
	if not condition: failures.append(label)

func frames(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	var terrain:=TestTerrain.new(); root.add_child(terrain)
	var captures: Array = []
	for kind in ["veyra", "aeral", "root_choir"]:
		var owner:=Node3D.new(); owner.name=kind; owner.position.y=.35 if kind=="veyra" else 5.0 if kind=="aeral" else .7
		terrain.add_child(owner)
		var animal: Node3D=load("res://scripts/creature_visual.gd").new(); owner.add_child(animal); animal.configure(kind)
		check(kind+"_model_body",animal.model!=null and animal.body!=null)
		var maps:=true
		for b in animal._material_bindings:
			maps=maps and bool(b.current.get_shader_parameter("authored_enabled")) and bool(b.current.get_shader_parameter("authored_normal_enabled")) and bool(b.current.get_shader_parameter("authored_roughness_enabled"))
		check(kind+"_all_PBR_maps", maps)
		animal.pose(0.0,0.0,0.0,0.0)
		var before: Dictionary=animal.debug_snapshot()
		for i in 120:
			if kind=="veyra": owner.position.z-=.012
			animal.pose(float(i+1)/60.0, .75 if i>60 else 0.0, .8, .7 if kind=="veyra" else 0.0)
		var after: Dictionary=animal.debug_snapshot()
		if kind=="veyra":
			var planted: bool=after.feet.size()==6;var reach: bool=planted
			for foot in after.feet:
				planted=planted and absf(float(foot.clearance)-float(foot.lift))<.012
				reach=reach and float(foot.target_error)<.012
			check("veyra_six_feet_terrain_contact",planted);check("veyra_IK_target",reach)
		elif kind=="aeral":
			check("aeral_two_wings_two_legs",after.wings==2 and after.legs==2)
			check("aeral_wing_response",before.wing_angles!=after.wing_angles)
			check("aeral_thin_tissue_backlight",animal._wing_materials.size()==4)
		else:
			check("morrow_seven_fronds",after.crown==7)
			check("morrow_alarm_folds_fronds",float(animal.crown[0].node.scale.y)<.55)
			check("morrow_signal_response",animal.signal_materials.size()==7 and float(animal.signal_materials[0].get_shader_parameter("response"))>.8)
		for mode in ["authored_factors", "previous", "current"]:
			check(kind+"_debug_"+mode,bool(animal.debug_set_material_mode(mode).applied))
		captures.append({"kind":kind,"before":before,"after":after})
		owner.queue_free();await process_frame

	# The original controller runs in an isolated flat physics arena.
	for action in ["drive_forward","drive_reverse","turn_left","turn_right","brake","drive_boost","drive_crawl"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	var floor_body:=StaticBody3D.new();root.add_child(floor_body)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(300,.10,300)
	collision.shape=shape;collision.position.y=-.05;floor_body.add_child(collision)
	var rover: CharacterBody3D=load("res://scripts/rover.gd").new();rover.configure(terrain);root.add_child(rover)
	await frames(3)
	check("rover_six_wheels",rover.wheels.size()==6)
	check("rover_collision_box",rover.get_child(0).shape.size==Vector3(1.5,1.0,2.3))
	check("rover_camera_mount_and_arm_length",rover.third_arm.spring_length==7.0 and rover.camera_rig.position==Vector3(0,1.48,-.43))
	rover.set_driving_enabled(true);Input.action_press("drive_forward");await frames(60)
	check("rover_forward_and_wheel_rotation",rover.speed>7.0 and absf(rover.wheels[0].rotation.x)>.1)
	Input.action_press("drive_crawl");await frames(60)
	check("rover_C_crawl",absf(rover.speed-4.32)<.05)
	Input.action_release("drive_crawl");Input.action_press("brake");await frames(20)
	check("rover_brake",absf(rover.speed)<.001)
	rover.clear_inputs();Input.action_press("drive_reverse");await frames(80)
	check("rover_reverse",rover.speed<-.1)
	Input.action_release("drive_reverse");Input.action_press("drive_forward");await frames(120)
	var heading:float=rover.heading;Input.action_press("turn_right");await frames(15)
	check("rover_correct_right_steering",rover.heading>heading and rover.rotation.y<0.0)
	rover.clear_inputs();var original:String=rover.camera_mode;rover.toggle_camera_mode()
	check("rover_V_switch",rover.camera_mode!=original and rover.third_camera.current)
	rover.toggle_camera_mode();check("rover_V_return",rover.camera.current)
	rover.set_driving_enabled(false);check("rover_pause_clears_thrust",rover.speed==0.0 and not Input.is_action_pressed("drive_forward"))
	var result:Dictionary={"passed":failures.is_empty(),"kind":"isolated_headless_rig_material_controller_fixture_no_visual_claim","checks":checks,"failures":failures,"pose_readback":captures}
	var file:=FileAccess.open(output.path_join("native-check.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("BIOLOGICAL_NATIVE_CHECK "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
