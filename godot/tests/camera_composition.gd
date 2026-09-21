extends SceneTree
var game: Node3D
var output := ""
var records: Array[Dictionary] = []

func _initialize() -> void:
	root.size=Vector2i(1440,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
	if output.is_empty() or DisplayServer.get_name()=="headless": quit(2);return
	run.call_deferred()

func frames(count: int) -> void:
	for i in count: await process_frame

func shot(name: String) -> bool:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await frames(15)
	game.start_expedition();game._set_phase("exploring")
	game.rover.set_driving_enabled(false);game.rover.set_process(false)
	game.world.set_paused(true);game.audio.set_paused(true)
	game.ready_for_play=false
	game.rover.set_camera_mode("first_person")
	var poses=[{"id":"spawn","z":150.0,"offset":0.0,"yaw":0.0},{"id":"ridge","z":30.0,"offset":4.0,"yaw":0.0},{"id":"rift","z":-108.0,"offset":0.0,"yaw":0.25}]
	var layouts=[{"id":"before","mount":Vector3(0,1.4,-0.43),"pitch":-0.1},{"id":"after","mount":Vector3(0,1.48,-0.43),"pitch":-0.1}]
	var meshes: Array=game.rover.model.find_children("*","MeshInstance3D",true,false)
	var materials: Array=[]
	for mesh in meshes: materials.append(mesh.material_override)
	var white:=StandardMaterial3D.new();white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;white.albedo_color=Color.WHITE
	var black:=Environment.new();black.background_mode=Environment.BG_COLOR;black.background_color=Color.BLACK
	var all_ok:=true
	for pose in poses:
		var x: float=game.world.path_x(pose.z)+pose.offset
		game.rover.position=Vector3(x,game.world.height_at(x,pose.z)+0.02,pose.z)
		game.rover.heading=pose.yaw;game.rover.rotation.y=-pose.yaw
		game.rover.model.rotation=Vector3.ZERO
		game.rover.set_driving_enabled(true)
		for i in 90: await physics_frame
		game.rover.set_driving_enabled(false)
		game.world.set_region_mood(game.world.region_at(game.rover.position),10.0)
		game.ui.update_readout(game.target_distance(),0,0,false,0,24,"first_person",{})
		game._update_survey_readout()
		for layout in layouts:
			game.rover.camera_rig.position=layout.mount
			game.rover.camera.rotation=Vector3(layout.pitch,0,0)
			await frames(3)
			var label: String=pose.id+"-"+layout.id
			all_ok=await shot(label) and all_ok
			game.world.visible=false;game.contact.visible=false;game.ui.visible=false
			game.rover.camera.environment=black
			for mesh in meshes: mesh.material_override=white
			await frames(2)
			all_ok=await shot(label+"-rover-mask") and all_ok
			for i in meshes.size(): meshes[i].material_override=materials[i]
			game.rover.camera.environment=null
			game.world.visible=true;game.contact.visible=true;game.ui.visible=true
			records.append({"pose":pose.id,"layout":layout.id,"mount":str(layout.mount),"pitch":layout.pitch,"kind":"staged_camera_composition_not_driving"})
	var file:=FileAccess.open(output.path_join("composition.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"captured":all_ok,"viewport":[1440,900],"records":records},"  "));file.close()
	game.queue_free();await frames(2);quit(0 if all_ok else 1)
