extends Node3D
## Deterministic, editable habitat geometry. Audited CC0 maps are shared across batches.
var terrain: Node3D
var records: Array[Dictionary] = []
var _materials: Array[StandardMaterial3D] = []

func build(world: Node3D) -> void:
	terrain = world
	var ids := ["aurora_shelf", "ember_rift", "veil_marsh", "pale_decay"]
	var palettes := [Color("8babc0"), Color("443731"), Color("637e79"), Color("a195a9")]
	var starts := [128.0, -30.0, -192.0, -374.0]
	var spans := [120.0, 110.0, 130.0, 220.0]
	for family in 4:
		var mesh := _make_mesh(family)
		var material := StandardMaterial3D.new()
		material.albedo_color = palettes[family]
		material.albedo_texture = load("res://assets/terrain/cc0/rock023_alb_ht.png")
		material.normal_enabled = true
		material.normal_texture = load("res://assets/terrain/cc0/rock023_nrm_rgh.png")
		material.normal_scale = 0.45 if family == 0 else 0.8
		material.roughness_texture = material.normal_texture
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
		material.roughness = 0.45 if family == 0 else 0.92
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.25
		if family == 2:
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.roughness = 0.42
		_materials.append(material)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = 12
		var node := MultiMeshInstance3D.new()
		node.name = ids[family]
		node.multimesh = mm
		node.material_override = material
		add_child(node)
		for i in 12:
			var z: float = starts[family] - float(i / 2) / 5.0 * spans[family]
			var side := -1.0 if i % 2 == 0 else 1.0
			var x: float = terrain.path_x(z) + side * (18.0 + 9.0 * absf(sin(i * 2.3 + family)))
			var scale_factor := 0.72 + 0.48 * absf(sin(i * 1.63 + family))
			var basis := Basis(Vector3.UP, i * 2.13 + family).scaled(Vector3.ONE * scale_factor)
			var position := Vector3(x, terrain.height_at(x,z) - 0.25, z)
			mm.set_instance_transform(i, Transform3D(basis, position))
			# Small soft fronds bend through the vehicle; solid geological forms use their real mesh.
			if family != 2:
				var body := StaticBody3D.new()
				body.name = ids[family] + "_collision"
				var shape := CollisionShape3D.new()
				shape.shape = mesh.create_trimesh_shape()
				body.add_child(shape)
				body.transform = Transform3D(basis, position)
				add_child(body)
			records.append({"region":ids[family],"position":position,"scale":scale_factor,"solid":family != 2})

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var points: Array[Vector3] = [a,b,c]
	if (b-a).cross(c-a).dot(outward) > 0.0: points = [a,c,b]
	for point in points:
		st.set_uv(Vector2(point.x+point.z,point.y)*0.2)
		st.add_vertex(point)

func _spine(st: SurfaceTool, center: Vector3, width: float, height: float, lean: Vector3) -> void:
	for side in 6:
		var a := float(side) / 6.0 * TAU
		var b := float(side+1) / 6.0 * TAU
		var p := center + Vector3(cos(a),0,sin(a))*width
		var q := center + Vector3(cos(b),0,sin(b))*width
		var r := center + Vector3(cos(a)*width*0.6,height*0.78,sin(a)*width*0.6) + lean*0.78
		var s := center + Vector3(cos(b)*width*0.6,height*0.78,sin(b)*width*0.6) + lean*0.78
		var normal := Vector3(cos(a+PI/6),0,sin(a+PI/6))
		_tri(st,p,r,q,normal); _tri(st,q,r,s,normal)
		_tri(st,r,center+Vector3.UP*height+lean,s,normal)

func _vent(st: SurfaceTool, center: Vector3, height: float, radius: float) -> void:
	for level in 5:
		var t := float(level)/5.0
		var t1 := float(level+1)/5.0
		for side in 10:
			var a := float(side)/10.0*TAU
			var b := float(side+1)/10.0*TAU
			var r0 := radius * (1.0 - t*0.43 + sin(t*19.0)*0.11)
			var r1 := radius * (1.0 - t1*0.43 + sin(t1*19.0)*0.11)
			var p := center+Vector3(cos(a)*r0,t*height,sin(a)*r0)
			var q := center+Vector3(cos(b)*r0,t*height,sin(b)*r0)
			var r := center+Vector3(cos(a)*r1,t1*height,sin(a)*r1)
			var s := center+Vector3(cos(b)*r1,t1*height,sin(b)*r1)
			var normal := Vector3(cos(a),0,sin(a))
			_tri(st,p,r,q,normal); _tri(st,q,r,s,normal)
			if level == 4:
				var ri := center+Vector3(cos(a)*r1*0.63,height-0.2,sin(a)*r1*0.63)
				var si := center+Vector3(cos(b)*r1*0.63,height-0.2,sin(b)*r1*0.63)
				_tri(st,r,ri,s,Vector3.UP);_tri(st,s,ri,si,Vector3.UP)
				_tri(st,ri,center+Vector3(0,height-1.5,0),si,-normal)

func _frond(st: SurfaceTool, angle: float, height: float, bend: float) -> void:
	for segment in 12:
		var t := float(segment)/12.0
		var u := float(segment+1)/12.0
		var points: Array[Vector3] = []
		for v in [t,u]:
			var width: float = sin(v*PI)*0.85+0.035
			var center := Vector3(bend*v*v,height*v,sin(v*PI)*0.7)
			for side in [-1.0,1.0]:
				points.append((center+Vector3(side*width,0,side*0.25*sin(v*PI*2))).rotated(Vector3.UP,angle))
		_tri(st,points[0],points[2],points[1],Vector3.FORWARD)
		_tri(st,points[1],points[2],points[3],Vector3.FORWARD)

func _arch(st: SurfaceTool, yaw: float, radius: float) -> void:
	for segment in 20:
		var a := float(segment)/20.0*PI*0.94
		var b := float(segment+1)/20.0*PI*0.94
		for side in 6:
			var c := float(side)/6.0*TAU
			var d := float(side+1)/6.0*TAU
			var points: Array[Vector3] = []
			for angle in [a,b]:
				var thick: float = 0.34*(1.0-angle/PI*0.72)
				for around in [c,d]:
					points.append(Vector3(cos(angle)*(radius+cos(around)*thick),sin(angle)*(radius+cos(around)*thick),sin(around)*thick).rotated(Vector3.UP,yaw))
			var normal := Vector3(cos(a)*cos(c),sin(a)*cos(c),sin(c)).rotated(Vector3.UP,yaw)
			_tri(st,points[0],points[2],points[1],normal);_tri(st,points[1],points[2],points[3],normal)

func _make_mesh(family: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if family == 0:
		for i in 7:
			var angle := float(i)*2.4
			_spine(st,Vector3(cos(angle)*1.6,0,sin(angle)*1.6),0.34+0.12*(i%3),3.2+0.65*i,Vector3(1.4,0,-0.5))
	elif family == 1:
		_vent(st,Vector3.ZERO,7.4,1.6)
		_vent(st,Vector3(2.3,0,1.5),4.3,1.15)
		_vent(st,Vector3(-1.8,0,1.3),2.4,0.9)
	elif family == 2:
		for i in 9: _frond(st,float(i)*2.4,3.4+0.35*(i%4),1.8+0.25*(i%3))
	else:
		for i in 5: _arch(st,float(i)*0.47,2.8+float(i)*0.4)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()
