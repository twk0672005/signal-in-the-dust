extends SceneTree
## One immutable specimen at a time; engine import/lookdev, never world acceptance.
var output := ""
var kind := "aeral"
var stage: Node3D
var specimen: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var report: Dictionary = {}

func _initialize() -> void:
	root.size=Vector2i(1440,1000)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
		if arg.begins_with("--kind="): kind=arg.trim_prefix("--kind=")
	if output.is_empty() or kind not in ["aeral","canopy","sails"]: quit(2);return
	run.call_deferred()

func _from_blender(point: Vector3) -> Vector3:
	return Vector3(point.x,point.z,-point.y)

func inspect_meshes() -> AABB:
	var nodes:=specimen.find_children("*","MeshInstance3D",true,false)
	var materials:Dictionary={}
	var records:Array[Dictionary]=[]
	var bounds:=AABB()
	var first:=true
	var triangles:=0
	var surfaces:=0
	var invalid_normals:=0
	var zero_area:=0
	for entry in nodes:
		var node:=entry as MeshInstance3D
		var mesh:=node.mesh
		var box:AABB=node.global_transform*node.get_aabb()
		bounds=box if first else bounds.merge(box)
		first=false
		var detail:Dictionary={"node":str(specimen.get_path_to(node)),"surfaces":mesh.get_surface_count(),"scale":str(node.global_transform.basis.get_scale()),"materials":[],"morphs":[],"triangles":0}
		for b in mesh.get_blend_shape_count():
			detail.morphs.append({"name":mesh.get_blend_shape_name(b),"weight":node.get_blend_shape_value(b)})
		for s in mesh.get_surface_count():
			surfaces+=1
			var arrays:=mesh.surface_get_arrays(s)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var count:=indices.size()/3 if not indices.is_empty() else vertices.size()/3
			triangles+=count;detail.triangles+=count
			for normal in normals:
				if not normal.is_finite() or normal.length_squared()<0.25:invalid_normals+=1
			for tri in count:
				var a:=indices[tri*3] if not indices.is_empty() else tri*3
				var b:=indices[tri*3+1] if not indices.is_empty() else tri*3+1
				var c:=indices[tri*3+2] if not indices.is_empty() else tri*3+2
				if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length_squared()<0.0000000000000001:zero_area+=1
			var material:=node.get_active_material(s)
			if material!=null:
				var id:=str(material.get_instance_id())
				if not materials.has(id):
					var info:Dictionary={"name":material.resource_name,"type":material.get_class()}
					if material is StandardMaterial3D:
						info.merge({"albedo":str(material.albedo_color),"roughness":material.roughness,"transparency":material.transparency,"cullMode":material.cull_mode,"normalEnabled":material.normal_enabled,"vertexColor":material.vertex_color_use_as_albedo,"emission":material.emission_enabled,"textures":{}})
						for slot in ["albedo_texture","normal_texture","roughness_texture"]:
							var texture:Texture2D=material.get(slot)
							if texture!=null:info.textures[slot]={"size":str(texture.get_size()),"path":texture.resource_path}
					materials[id]=info
				detail.materials.append(material.resource_name)
		records.append(detail)
	report.merge({"meshCount":nodes.size(),"surfaceCount":surfaces,"triangles":triangles,"materialCount":materials.size(),"materials":materials.values(),"meshRecords":records,"invalidOrZeroNormals":invalid_normals,"zeroAreaTriangles":zero_area,"bounds":{"min":str(bounds.position),"max":str(bounds.end),"size":str(bounds.size)}})
	return bounds

func capture(label: String, position: Vector3, target: Vector3, size: float, blue: bool=false) -> void:
	camera.position=position;camera.look_at(target);camera.size=size
	environment.ambient_light_color=Color("748bc2") if blue else Color.WHITE
	environment.ambient_light_energy=0.62
	environment.background_color=Color("131a32") if blue else Color("505862")
	sun.light_color=Color("b3c7ff") if blue else Color.WHITE
	sun.light_energy=1.35
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output.path_join(label+".png"))
	assert(error==OK)
	report.captures.append({"file":label+".png","camera":str(camera.position),"target":str(target),"orthoWidth":size,"lighting":"blue_violet" if blue else "neutral","drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"renderPrimitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	stage=Node3D.new();root.add_child(stage)
	var asset:="res://aeral-v9-probe.glb" if kind=="aeral" else "res://"+kind+"-b-probe.glb"
	specimen=(load(asset) as PackedScene).instantiate();stage.add_child(specimen)
	await process_frame
	report={"kind":"native_Compatibility_single_specimen_probe_not_Web_or_gameplay","specimen":kind,"asset":asset,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"viewport":str(root.size),"captures":[]}
	var bounds:=inspect_meshes()
	var center:=bounds.get_center()
	var extent:=maxf(bounds.size.x,bounds.size.y)
	var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(160,160);ground.mesh=plane;ground.position.y=-0.34
	var groundmat:=StandardMaterial3D.new();groundmat.albedo_color=Color("4b4e54");groundmat.roughness=0.85;ground.material_override=groundmat;stage.add_child(ground)
	environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var env:=WorldEnvironment.new();env.environment=environment;stage.add_child(env)
	sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);sun.shadow_enabled=true;sun.directional_shadow_max_distance=80;stage.add_child(sun)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.near=.05;camera.far=200;stage.add_child(camera);camera.current=true
	root.msaa_3d=Viewport.MSAA_4X
	if kind=="aeral":
		var target:=_from_blender(Vector3(0,-.25,3.8))
		await capture("neutral-three-quarter",_from_blender(Vector3(13,18,7.5)),target,17)
		await capture("neutral-front",_from_blender(Vector3(0,21,5)),target,17)
		await capture("neutral-side",_from_blender(Vector3(-22,0,5)),target,17)
		await capture("neutral-back",_from_blender(Vector3(0,-23,6)),target,17)
		await capture("neutral-organ-close",_from_blender(Vector3(5,11,4.4)),_from_blender(Vector3(0,1.1,2.9)),6.5)
		await capture("neutral-organ-shift",_from_blender(Vector3(5.08,11,4.4)),_from_blender(Vector3(0,1.1,2.9)),6.5)
		await capture("neutral-wing-root",_from_blender(Vector3(5,6,6)),_from_blender(Vector3(1.4,.5,4.0)),6)
	else:
		await capture("neutral-front",center+Vector3(0,extent*.10,-extent*1.7),center,extent*1.32)
		await capture("neutral-side",center+Vector3(extent*1.7,extent*.10,0),center,extent*1.32)
		await capture("neutral-back",center+Vector3(0,extent*.10,extent*1.7),center,extent*1.32)
		await capture("blue-violet",center+Vector3(extent*1.2,extent*.35,-extent*1.3),center,extent*1.32,true)
		if kind=="canopy":
			await capture("neutral-underside",Vector3(0,4,-14),Vector3(0,16,0),22)
			await capture("neutral-support",Vector3(15,6,-17),Vector3(0,5,0),15)
		else:
			await capture("grazing-a",center+Vector3(extent*1.1,0,-extent*.15),center,extent*.8)
			await capture("grazing-b",center+Vector3(extent*1.1,0,extent*.15),center,extent*.8)
			await capture("neutral-tissue-detail",Vector3(4,5,-10),Vector3(1.8,4.8,0),5.2)
	# Capture overhead is excluded by starting this bounded stationary sample afterward.
	for i in 20:await process_frame
	var samples:Array[float]=[]
	var previous:=Time.get_ticks_usec()
	for i in 150:
		await process_frame
		var now:=Time.get_ticks_usec();samples.append(float(now-previous)/1000.0);previous=now
	samples.sort()
	report["stationaryCost"]={"scope":"150 native fixture frames after screenshots; not gameplay/Web performance","frames":samples.size(),"p50ms":samples[74],"p95ms":samples[142],"p99ms":samples[148],"worstMs":samples[149],"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"videoMemory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"textureMemory":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"bufferMemory":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)}
	report["visualAcceptance"]=false
	var file:=FileAccess.open(output.path_join("native-probe.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("SPECIMEN_PROBE "+JSON.stringify({"specimen":kind,"meshes":report.meshCount,"surfaces":report.surfaceCount,"triangles":report.triangles,"materials":report.materialCount,"bounds":report.bounds,"zeroArea":report.zeroAreaTriangles,"captures":report.captures.size()}))
	quit()
