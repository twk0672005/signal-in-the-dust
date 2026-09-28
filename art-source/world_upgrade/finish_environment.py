"""One-time recorded transformation from the resumed 2026-09-26 candidate.

Run only against the preserved resume baseline. Production GDScript is the source
of truth after this patch; subsequent local repairs are recorded in the handoff.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / 'godot/scripts/living_habitat.gd'
s = p.read_text(encoding='utf-8')
s = s.replace('var _triangle_budget := 0', '''var _triangle_budget := 0
var collision_shapes: Dictionary = {}
var placements: Array[Dictionary] = []
var _collision_count := 0''')
s = s.replace('terrain.build_stats["regional_ground_triangles"] = _triangle_budget', '''terrain.build_stats["regional_ground_triangles"] = _triangle_budget
	terrain.build_stats["habitat_collision_instances"] = _collision_count
	terrain.build_stats["habitat_shared_collision_shapes"] = collision_shapes.size()''')
s = s.replace('var count := 15 if id==3 else 12', 'var count := 19 if id==3 else 15')
s = s.replace('[22.0,35.0,17.0,49.0,28.0]', '[18.0,33.0,15.0,45.0,25.0]')
s = s.replace('[5.5,2.9,3.4,3.8]', '[6.0,4.2,4.0,5.0]')
s = s.replace('var fs := rng.randf_range(.22,.48)*size', 'var fs := rng.randf_range(.27,.52)*size')
s = s.replace('if _clear(fx,fz,footprint*fs):', 'if _clear(fx,fz,[6.0,4.2,4.0,5.0][id]*fs):')
s = s.replace('if _clear(x,z,7.0): transforms[family].append(_placement(x,z,rng.randf_range(1,1.8)))', '''var far_size := rng.randf_range(1.25,2.15)
		if _clear(x,z,[6.0,4.2,4.0,5.0][id]*far_size): transforms[family].append(_placement(x,z,far_size))''')
s = s.replace('material.roughness = .88 if material.roughness_texture!=null else .64', '''material.roughness = .78 if material.roughness_texture!=null else .62
			material.albedo_color = material.albedo_color.darkened(.22)''')
s = s.replace('var key := Vector2i(floori(t.origin.x/50.0),floori(t.origin.z/65.0))', 'var key := Vector2i(floori(t.origin.x/70.0),floori(t.origin.z/90.0))')
s = s.replace('for t: Transform3D in transforms:\n\t\tvar key', '''for t: Transform3D in transforms:
		if family in ["frost_shelf","vent_stack","pale_branch","root_hummock","canopy"]:
			_add_habitat_collision(family,t)
		var key''')
s = s.replace('node.visibility_range_end = 250.0 if landmark else 115.0', 'node.visibility_range_end = 320.0 if landmark else 130.0')
s = s.replace('st.set_color(color)\n\t\tst.set_uv', 'st.set_color(color.srgb_to_linear())\n\t\tst.set_uv')
s = s.replace('material.cull_mode = BaseMaterial3D.CULL_DISABLED', '''material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = load("res://assets/terrain/basalt_albedo.png")
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * .28
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.albedo_color = color.lightened(.18)''')
a=s.index('func _build_native_kit()')
b=s.index('func _shelf(',a)
s=s[:a]+'''func _build_native_kit() -> void:
	# Broken frost escarpments: intersecting thick volumes, never repeated plates.
	var st := _surface()
	_shelf(st,Vector3(-1.1,.95,.3),Vector3(3.3,2.6,2.9),-.2,Color("869b9e"),2)
	_shelf(st,Vector3(2.1,.42,-.2),Vector3(3.0,1.7,2.6),.36,Color("9caaa9"),5)
	_shelf(st,Vector3(-1.0,2.15,.5),Vector3(2.4,.65,2.0),-.12,Color("b0c2be"),4)
	for i in 5:
		var a := i*2.4
		_shelf(st,Vector3(cos(a)*3.8,-.06,sin(a)*2.7),Vector3(1.5,.45,.95),a,Color("8b9d9b"),i+7)
	_register_kit("frost_shelf",st,_kit_material(Color("b6cecd"),.83,true))
	# Fused fumaroles have shoulders and asymmetric necks with a mineral lip.
	st = _surface()
	for i in 3:
		var base := Vector3(sin(i*2.2)*1.4,-.3,cos(i*2.2)*1.0)
		var h := 3.5+i*.95
		_tapered_tube(st,[base,base+Vector3(.1,.75,0),base+Vector3(-.32,h*.48,.1),base+Vector3(.1,h*.82,.35),base+Vector3(.25,h,.25)],[1.35,1.08,.82,.47,.40],Color("756353"),13,.11)
		_fan(st,base+Vector3(.25,h-.12,.25),.57,.10,.1,Color("a58b63"),2.0)
		_shelf(st,base+Vector3(.2,.12,0),Vector3(2.5,.7,2.0),i*.8,Color("71574a"),i+3)
	_register_kit("vent_stack",st,_kit_material(Color("b29885"),.92,true))
	# Braided hummocks with open inter-root spaces and damp lamellae.
	st = _surface()
	for branch in 8:
		var a := branch/8.0*TAU
		var tip := Vector3(cos(a)*3.3,-.30,sin(a)*3.3)
		_tapered_tube(st,[Vector3(0,1.25,0),Vector3(cos(a)*.85,.95,sin(a)*.85),tip*.77+Vector3.UP*.35,tip],[.63,.45,.23,.04],Color("526d5b"),10,.065)
	_shelf(st,Vector3(0,.56,0),Vector3(2.0,1.4,1.7),.3,Color("5d7662"),3)
	for i in 5:
		_fan(st,Vector3(sin(i*2.4)*.8,.8+i*.19,cos(i*2.4)*.8),1.2,.22,i*2.4,Color("69847a"),1.1)
	_register_kit("root_hummock",st,_kit_material(Color("bdcaba"),.68))
	# Pale is a mineralised fungal woodland, with pigmented crowns and branching ribs.
	st = _surface()
	_tapered_tube(st,[Vector3(0,-.4,0),Vector3(.22,1.4,.15),Vector3(-.26,3.4,0),Vector3(.12,5.35,.28)],[1.0,.68,.47,.16],Color("8c8277"),13,.10)
	for branch in 7:
		var a := branch*2.39
		var h := 1.55+branch*.52
		var origin := Vector3(0,h,0)
		var end := Vector3(cos(a)*(2.1+branch*.14),h+.95,sin(a)*(2.1+branch*.14))
		_tapered_tube(st,[origin,origin.lerp(end,.6)+Vector3.DOWN*.23,end,end+Vector3(cos(a)*.25,.65,sin(a)*.25)],[.36,.27,.17,.065],Color("a29a8a"),10,.085)
		for crown in 3:
			var p := end+Vector3(cos(a)*.16,crown*.26,sin(a)*.16)
			_fan(st,p,1.2-crown*.19,.20,a+PI,Color("998997").darkened(crown*.045),1.8)
		if branch%2==0:
			var fork := end+Vector3(cos(a+.6)*.8,.9,sin(a+.6)*.8)
			_tapered_tube(st,[end-Vector3.UP*.3,fork],[.15,.035],Color("afa391"),8,.06)
	for index in 6:
		var a := index*TAU/6.0
		_tapered_tube(st,[Vector3(0,.65,0),Vector3(cos(a)*1.55,.12,sin(a)*1.55),Vector3(cos(a)*2.65,-.42,sin(a)*2.65)],[.40,.22,.055],Color("726b62"),10,.09)
	_register_kit("pale_branch",st,_kit_material(Color("d6c9bb"),.88))
	for id in 4:
		st = _surface()
		for blade in (9 if id==2 else 7):
			var a := blade*2.39
			var h := .45+float(blade%4)*.19
			var palette: Color = [Color("7d9999"),Color("8c644b"),Color("457868"),Color("897382")][id]
			if id==3 or id==0:
				var p := Vector3(cos(a)*.35,.1+blade*.12,sin(a)*.35)
				_fan(st,p,.44+blade*.055,.12,a,palette,1.5)
				_tapered_tube(st,[Vector3(p.x,-.15,p.z),p],[.075,.055],palette.darkened(.2),7,0)
			else: _leaf(st,Vector3(cos(a)*.17,-.1,sin(a)*.17),h,.08 if id==2 else .24,a,palette)
		var family: String = ["frost_fan","ember_bract","reed_fan","spore_shelf"][id]
		_register_kit(family,st,_kit_material(Color.WHITE,.53 if id==2 else .76))

func _add_habitat_collision(family: String,t: Transform3D) -> void:
	# One reusable concave shape per kit; preserve branch and canopy openings.
	if not collision_shapes.has(family):
		var faces := PackedVector3Array()
		for part: Dictionary in source_meshes[family]: faces.append_array(part.mesh.get_faces())
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		collision_shapes[family] = shape
	var body := StaticBody3D.new()
	body.name = "HabitatCollision_"+family
	body.transform = t
	# A separate bit enables deterministic evidence rays without excluding gameplay bit 1.
	body.collision_layer = 1 | 128
	var collider := CollisionShape3D.new()
	collider.shape = collision_shapes[family]
	body.add_child(collider)
	add_child(body)
	placements.append({"family":family,"transform":t,"shape":collider.shape,"body":body})
	_collision_count += 1

''' +s[b:]
# Geometry normals now share vertices within each organic surface.
s=s.replace('st.generate_normals()\n\tst.index()', 'st.index()\n\tst.generate_normals()')
# Less geometric-looking ragged fans: curved scalloped shelves with thickness.
s=s.replace('const STEPS := 14', 'const STEPS := 20')
s=s.replace('var pa := origin+Vector3(cos(a)*radius,rise+sin(j*.8)*.035,sin(a)*radius)', 'var ra := radius*(1.0+.075*sin(j*1.91)+.025*cos(j*.7))\n\t\tvar pa := origin+Vector3(cos(a)*ra,rise+sin(j*.8)*.04,sin(a)*ra)')
s=s.replace('var pb := origin+Vector3(cos(b)*radius,rise+sin((j+1)*.8)*.035,sin(b)*radius)', 'var rb := radius*(1.0+.075*sin((j+1)*1.91)+.025*cos((j+1)*.7))\n\t\tvar pb := origin+Vector3(cos(b)*rb,rise+sin((j+1)*.8)*.04,sin(b)*rb)')
s=s.replace('var palettes := [Color("889da8"),Color("886248"),Color("496e62"),Color("837582")]', 'var palettes := [Color("799190"),Color("74634d"),Color("416658"),Color("706574")]')
s=s.replace('var h := rng.randf_range(.22,.63)*(1.35 if id==2 else .85)', 'var h := rng.randf_range(.17,.44)*(1.25 if id==2 else .8)')
s=s.replace('var width := h*(.11 if id==3 else .045)', 'var width := h*(.038 if id==3 else .021)')
s=s.replace('st.set_color(color)\n\t\t\t\t\tst.set_uv', 'st.set_color(color.srgb_to_linear())\n\t\t\t\t\tst.set_uv')
# Dry ground fans with compound leaf silhouettes in the same spatial community mesh.
s=s.replace('for blade in 3:', '''if id!=2 and i%3==0:
				_fan(st,Vector3(x,y+.035,z),h*.75,.06,angle,color,1.65)
				_triangle_budget += 80
				continue
			for blade in 4:''')
p.write_text(s,encoding='utf-8')

p=ROOT/'godot/scripts/world.gd'
s=p.read_text(encoding='utf-8')
# Restrained twilight materials; atmosphere separates far mountains without hiding play space.
s=s.replace('var tint:=Color(0.12,0.16,0.25)','var tint:=Color(0.26,0.31,0.36)')
s=s.replace('var begin:=120.0','var begin:=65.0').replace('var finish:=1400.0','var finish:=940.0')
s=s.replace('tint=Color(0.20,0.14,0.18);begin=80.0;finish=850.0','tint=Color(0.30,0.25,0.26);begin=55.0;finish=800.0')
s=s.replace('tint=Color(0.11,0.18,0.25);begin=65.0;finish=680.0','tint=Color(0.20,0.29,0.30);begin=42.0;finish=650.0')
s=s.replace('tint=Color(0.20,0.17,0.23);begin=85.0;finish=1100.0','tint=Color(0.28,0.26,0.32);begin=60.0;finish=860.0')
s=s.replace('_environment.fog_depth_curve,1.15','_environment.fog_depth_curve,0.86')
s=s.replace('_environment.ambient_light_energy = 0.62','_environment.ambient_light_energy = 0.66')
s=s.replace('_environment.fog_depth_curve = 1.15','_environment.fog_depth_curve = 0.86')
s=s.replace('sun.light_energy = 1.05','sun.light_energy = 0.72')
s=s.replace('sun.shadow_bias = 0.06','sun.shadow_bias = 0.04\n\tsun.shadow_blur = 2.0\n\tsun.shadow_opacity = 0.74')
s=s.replace('rim.light_energy = 0.18','rim.light_energy = 0.14')
s=s.replace('fill.light_energy=.7','fill.light_energy=.42')
s=s.replace('_terrain_material.set_shader_parameter("wetland_center", _wetland_center())', '''_terrain_material.set_shader_parameter("wetland_center", _wetland_center())
	var pool := _wetland_center()
	_terrain_material.set_shader_parameter("water_level",height_at(pool.x,pool.y)+.64)''')
# Remove regular radial corrugation from mountains; introduce offset erosion channels instead.
s=s.replace('ridge += sin(radial * 61.0 + angle * 4.0) * 5.5 * smoothstep(0.08, 0.25, radial)', 'ridge += (sin(angle*23.0+radial*7.0)*4.0 + sin(angle*41.0-radial*11.0)*2.0)*sin(radial*PI)')
a=s.index('func _build_terrain()')
b=s.index('func _build_horizon()',a)
s=s[:a]+'''func _build_terrain() -> void:
	const NX := 155
	const NZ := 193
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pool := _wetland_center()
	var triangles := 0
	for iz in NZ-1:
		for ix in NX-1:
			var x0 := -192.0+ix*(384.0/float(NX-1))
			var z0 := -700.0+iz*(900.0/float(NZ-1))
			# Only the bank needs sub-metre geometry. Render and collision use the same mesh.
			var divisions := 8 if Vector2(x0+1.25,z0+2.35).distance_to(pool)<16.0 else 1
			var dx := 384.0/float(NX-1)/divisions
			var dz := 900.0/float(NZ-1)/divisions
			for rz in divisions:
				for rx in divisions:
					var origin := Vector2(x0+rx*dx,z0+rz*dz)
					for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
						var x := origin.x+corner.x*dx
						var z := origin.y+corner.y*dz
						var hx := (height_at(x+.15,z)-height_at(x-.15,z))/.3
						var hz := (height_at(x,z+.15)-height_at(x,z-.15))/.3
						st.set_normal(Vector3(-hx,1,-hz).normalized())
						st.set_uv(Vector2(x,z)*.11)
						st.add_vertex(Vector3(x,height_at(x,z),z))
					triangles += 2
	st.index()
	st.generate_tangents()
	var ground := MeshInstance3D.new()
	ground.name = "CollidableDustBasin"
	ground.mesh = st.commit()
	ground.material_override = _terrain_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	ground.create_trimesh_collision()
	build_stats["terrain_triangles"] = triangles

''' +s[b:]
# Mineral specimens replace primitive cones while retaining existing survey collision and response.
a=s.index('\t\tfor i in 3:\n\t\t\tvar shard',s.index('func _build_survey_sites'))
b=s.index('\n\t\t_eco_sphere(node,Vector3(0,2.1',a)
s=s[:a]+'''		for i in 3:
			var shard := MeshInstance3D.new()
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var height := 1.1+.47*i
			var column: Array[Vector3] = []
			for ring in 6:
				var t := ring/5.0
				for side in 9:
					var angle := side/9.0*TAU
					var radius := .23*(.78+.2*sin(t*4.0+i))*(1.0-.62*pow(t,4.0))*(1.0+.13*sin(side*3.4+i))
					column.append(Vector3(cos(angle)*radius+sin(t*3+i)*.07,t*height,sin(angle)*radius*.85))
			for ring in 5:
				for side in 9:
					var j := ring*9+side
					var k := ring*9+(side+1)%9
					for index in [j,j+9,k,k,j+9,k+9]:
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
				_eco_sphere(shard,Vector3(.08,height*(.28+ridge*.18),.08),Vector3(.20,.07,.16),stone)'''+s[b:]
# Water edge is the actual terrain-water intersection, not an independent disk.
s=s.replace('for i in 64:\n\t\tvar a:float=i/64.0*TAU;var b:float=(i+1)/64.0*TAU\n\t\tvar ra:float=4.05+sin(a*3.0)*.18+sin(a*7.0)*.10\n\t\tvar rb:float=4.05+sin(b*3.0)*.18+sin(b*7.0)*.10', '''for i in 96:
		var a:float=i/96.0*TAU;var b:float=(i+1)/96.0*TAU
		var ra := _pool_edge_radius(center,a)
		var rb := _pool_edge_radius(center,b)''')
s=s.replace('water_surface.set_uv(Vector2(p.x,p.z)/8.4+Vector2(.5,.5));water_surface.add_vertex(p)', 'water_surface.set_uv(Vector2(p.x,p.z)/14.0+Vector2(.5,.5));water_surface.add_vertex(p)')
s=s.replace('_wetland_water_material.shader = WETLAND_SHADER', '''_wetland_water_material.shader = WETLAND_SHADER
	_wetland_water_material.set_shader_parameter("pool_center",center)
	_wetland_water_material.set_shader_parameter("water_level",_wetland_root.position.y+.64)''')
s=s.replace('\n\t_build_shore_transition(center)', '\n\t# Moist sediment is shaded directly on the authoritative terrain; no intersecting apron.\n\tbuild_stats["shore_shared_height_field"] = true')
# Six curved subsurface conduits replace straight radial light rods, preserving response materials.
a=s.index('\t\t_eco_rod(\n\t\t\t_wetland_root,\n\t\t\tVector3(cos(angle) * 0.45')
b=s.index('\n\n\t_build_wetland_reader',a)
s=s[:a]+'''		for segment in 5:
			var t0 := segment/5.0
			var t1 := (segment+1)/5.0
			var a0 := angle+sin(t0*3.5+i)*.19
			var a1 := angle+sin(t1*3.5+i)*.19
			var r0 := .55+t0*3.0
			var r1 := .55+t1*3.0
			_eco_rod(_wetland_root,Vector3(cos(a0)*r0,.59,sin(a0)*r0),Vector3(cos(a1)*r1,.59,sin(a1)*r1),.019,vein_material)'''+s[b:]
a=s.index('func _build_shore_transition(')
b=s.index('func _build_wetland_reader(',a)
s=s[:a]+'''func _pool_edge_radius(center: Vector2,angle: float) -> float:
	var level := height_at(center.x,center.y)+.64
	var inside := 3.4
	var outside := 10.0
	for step in 12:
		var radius := (inside+outside)*.5
		var point := center+Vector2(cos(angle),sin(angle))*radius
		if height_at(point.x,point.y)<level+.025: inside=radius
		else: outside=radius
	return (inside+outside)*.5

''' +s[b:]
p.write_text(s,encoding='utf-8')
print('Environment candidate transformed. Do not run this one-time patch again.')
