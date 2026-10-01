"""Deterministic opaque alien growth, metres/Z-up; Blender 5.2 CPU authoring only."""
import bpy, bmesh, math, json, hashlib, time, struct
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(__file__).parent
OUT = ROOT / 'godot/assets/alien_flora'
EVIDENCE = ROOT / 'evidence/alien-renewal-20260930T200644Z/flora/finish-03'
for path in (SOURCE, OUT, EVIDENCE): path.mkdir(parents=True, exist_ok=True)
START = time.monotonic()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
SCENE = bpy.context.scene
SCENE.unit_settings.system = 'METRIC'
SCENE.unit_settings.scale_length = 1
PALETTES = {
    'aurora': ('bbc8c7', 'aabdbb'),
    'ember': ('a27458', 'b79063'),
    'veil': ('5d817b', '6d9891'),
    'pale': ('afa398', 'ba939e'),
}
FAMILIES = {}

def colour(hex_value, factor=1):
    return tuple(int(hex_value[i:i+2], 16)/255*factor for i in (0, 2, 4))

def image(name, sample, size=512, data=False):
    result = bpy.data.images.new(name, width=size, height=size, alpha=False)
    result.colorspace_settings.name = 'Non-Color' if data else 'sRGB'
    pixels = []
    for y in range(size):
        for x in range(size): pixels.extend((*sample((x+.5)/size, (y+.5)/size), 1))
    result.pixels.foreach_set(pixels)
    result.filepath_raw = str(OUT / (name+'.png'))
    result.file_format = 'PNG'
    result.save()
    return result

def veins(u, v):
    x, y = (u-.5)*2, (v-.5)*2
    r, a = math.hypot(x, y), math.atan2(y, x)
    spine = math.exp(-((math.sin(a*8+r*.7)*max(.06, r)*53)**2))
    branches = math.exp(-((math.sin(a*35+r*38)*max(.08, r)*18)**2))*.32
    pores = math.sin(u*509+math.sin(v*81))*math.sin(v*601)*.021
    return r, max(spine*.84, branches), pores

def mantle_colour(u, v):
    r, vein, grain = veins(u, v)
    value = .70+.11*min(1, r)+grain-vein*.19
    return (value*.99, value, value*.98)

def mantle_roughness(u, v):
    r, vein, grain = veins(u, v)
    value = .60+.14*min(1, r)+vein*.07+grain
    return (value, value, value)

def mantle_normal(u, v):
    step = 1/512
    height = lambda a,b: veins(a,b)[1]*.14+veins(a,b)[2]*.08
    dx = (height(u+step,v)-height(u-step,v))*6
    dy = (height(u,v+step)-height(u,v-step))*6
    normal = Vector((-dx, -dy, 1)).normalized()
    return tuple(.5+.5*x for x in normal)

def stem_colour(u, v):
    furrow = (.5+.5*math.sin(u*91+math.sin(v*18)*.6))**10
    grain = math.sin(u*211+v*351)*math.sin(v*517)*.022
    value = .61+grain-furrow*.13+.06*math.sin(v*23)
    return (value, value*.99, value*.97)

MANTLE_MAP = image('lamina-veins-albedo', mantle_colour)
MANTLE_ROUGH = image('lamina-veins-roughness', mantle_roughness, data=True)
MANTLE_NORMAL = image('lamina-veins-normal', mantle_normal, data=True)
STEM_MAP = image('mineral-stem-albedo', stem_colour)

def material(name, albedo, roughness, normal=None, rough=None):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    nodes, links = result.node_tree.nodes, result.node_tree.links
    bsdf = nodes.get('Principled BSDF')
    bsdf.inputs['Metallic'].default_value = 0
    bsdf.inputs['Roughness'].default_value = roughness
    texture = nodes.new('ShaderNodeTexImage'); texture.image = albedo
    tone = nodes.new('ShaderNodeVertexColor'); tone.layer_name = 'Tone'
    multiply = nodes.new('ShaderNodeMixRGB'); multiply.blend_type = 'MULTIPLY'; multiply.inputs[0].default_value = 1
    links.new(texture.outputs['Color'], multiply.inputs[1]); links.new(tone.outputs['Color'], multiply.inputs[2])
    links.new(multiply.outputs[0], bsdf.inputs['Base Color'])
    if normal:
        texture = nodes.new('ShaderNodeTexImage'); texture.image = normal
        nm = nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value = .22
        links.new(texture.outputs['Color'], nm.inputs['Color']); links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    if rough:
        texture = nodes.new('ShaderNodeTexImage'); texture.image = rough
        links.new(texture.outputs['Color'], bsdf.inputs['Roughness'])
    return result

# Existing scanned bark contributes small normal/roughness variation, not Earth leaf silhouettes.
bark_normal = bpy.data.images.load(str(ROOT/'godot/assets/market_environment/cc0/Bark012_1K-JPG_NormalGL.jpg'))
bark_rough = bpy.data.images.load(str(ROOT/'godot/assets/market_environment/cc0/Bark012_1K-JPG_Roughness.jpg'))
for sample in (bark_normal, bark_rough): sample.colorspace_settings.name = 'Non-Color'
STEM = material('Alien_Stem_Mineral', STEM_MAP, .86, bark_normal, bark_rough)
MANTLE = material('Alien_Mantle_Lamina', MANTLE_MAP, .68, MANTLE_NORMAL, MANTLE_ROUGH)

def family(name):
    parent = bpy.data.objects.new(name, None); SCENE.collection.objects.link(parent)
    FAMILIES[name] = {'parent': parent, 'objects': []}
    return parent

def mesh(name, verts, faces, uv, colours, mat, parent):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces); data.update()
    bm = bmesh.new(); bm.from_mesh(data); bmesh.ops.triangulate(bm, faces=list(bm.faces)); bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.to_mesh(data); bm.free()
    obj = bpy.data.objects.new('GEO-'+name, data); SCENE.collection.objects.link(obj); obj.parent = parent
    data.materials.append(mat)
    layer = data.uv_layers.new(name='UVMap')
    tone = data.color_attributes.new(name='Tone', type='FLOAT_COLOR', domain='POINT')
    for i, value in enumerate(colours): tone.data[i].color_srgb = (*value, 1)
    data.color_attributes.active_color = tone
    for polygon in data.polygons:
        polygon.use_smooth = True
        for loop in polygon.loop_indices: layer.data[loop].uv = uv[data.loops[loop].vertex_index]
    FAMILIES[parent.name]['objects'].append(obj)
    return obj

def tube(name, spine, radii, parent, tint, sides=9, subdivisions=3, curve_out=None):
    verts, faces, uv, colours, curve = [], [], [], [], []
    for index in range((len(spine)-1)*subdivisions+1):
        f=index/subdivisions; seg=min(len(spine)-2,int(f)); t=f-seg
        a,b = Vector(spine[seg]),Vector(spine[seg+1])
        pre,post = Vector(spine[max(0,seg-1)]),Vector(spine[min(len(spine)-1,seg+2)])
        center = .5*((2*a)+(-pre+b)*t+(2*pre-5*a+4*b-post)*t*t+(-pre+3*a-3*b+post)*t*t*t)
        curve.append((center, radii[seg]*(1-t)+radii[seg+1]*t))
    if curve_out is not None: curve_out.extend(center for center, radius in curve)
    for index,(center,radius) in enumerate(curve):
        tangent=(curve[min(len(curve)-1,index+1)][0]-curve[max(0,index-1)][0]).normalized()
        side = tangent.cross(Vector((0,0,1))).normalized() if abs(tangent.z)<.9 else Vector((1,0,0))
        other=tangent.cross(side).normalized()
        for j in range(sides+1):
            angle = j/sides*math.tau
            p = center+(side*math.cos(angle)+other*math.sin(angle))*radius*(1+.07*math.sin(angle*5+index*.3))
            verts.append(tuple(p)); uv.append((j/sides*1.3,index/max(1,len(curve)-1)*max(.5,center.z*.32)))
            colours.append(tuple(c*(.88+.12*index/max(1,len(curve)-1)) for c in tint))
    row=sides+1
    for i in range(len(curve)-1):
        for j in range(sides):
            k=i*row+j;faces.append((k,k+1,k+row+1,k+row))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(curve)-1)*row+j for j in range(sides)))
    return mesh(name, verts, faces, uv, colours, STEM, parent)

def shell(name, center, radius, rise, yaw, lobes, parent, tint, sides=28, rings=3, tilt=.13):
    verts, faces, uv, colours = [], [], [], []
    center = Vector(center)
    # Closed top and underside. The outer edge has real thickness and an uneven scalloped margin.
    for underside in (False, True):
        verts.append(tuple(center+Vector((0,0, -.07 if underside else rise))))
        uv.append((.5,.5)); colours.append(tuple(c*(.63 if underside else .97) for c in tint))
        for ring in range(1,rings+1):
            t=ring/rings
            for j in range(sides):
                angle=j/sides*math.tau+yaw
                lobe=1+.16*math.sin(angle*lobes+.7)+.055*math.sin(angle*(lobes+3)+2.3)
                r=radius*t*lobe
                z=rise*(1-t*t)+math.sin(angle*lobes)*radius*.032*t+math.cos(angle+.7)*radius*tilt*t
                if underside: z-= .065+radius*.045*(1-t)
                p=center+Vector((math.cos(angle)*r,math.sin(angle)*r*.78,z))
                verts.append(tuple(p)); uv.append((.5+math.cos(angle)*t*.485,.5+math.sin(angle)*t*.485))
                factor=(.61+.07*t) if underside else (.94+.06*t)
                colours.append(tuple(c*factor for c in tint))
    half=1+rings*sides
    for offset in (0,half):
        for j in range(sides):faces.append((offset,offset+1+j,offset+1+(j+1)%sides))
        for ring in range(rings-1):
            for j in range(sides):
                k=offset+1+ring*sides+j;n=offset+1+ring*sides+(j+1)%sides
                faces.append((k,n,n+sides,k+sides))
    for j in range(sides):
        k=1+(rings-1)*sides+j;n=1+(rings-1)*sides+(j+1)%sides
        faces.append((k,n,n+half,k+half))
    return mesh(name,verts,faces,uv,colours,MANTLE,parent)

def wing_lobe(name, root, direction, length, width, depth, roll, parent, tint):
    """Closed bent lamina volume, with unequal folds; local thickness is physical."""
    axis=Vector(direction).normalized()
    side=axis.cross(Vector((0,0,1))).normalized()
    if side.length<.01:side=Vector((1,0,0))
    up=side.cross(axis).normalized()
    side,up=side*math.cos(roll)+up*math.sin(roll),up*math.cos(roll)-side*math.sin(roll)
    root=Vector(root);verts=[];faces=[];uv=[];colours=[]
    segments,sides=7,12
    for i in range(segments+1):
        t=i/segments
        profile=max(.015,math.sin(t*math.pi)**.66)*(1+.075*math.sin(t*math.pi*5+.6))
        center=root+axis*(length*t)+up*(math.sin(t*math.pi)*length*.21-length*.05*t*t)
        for j in range(sides+1):
            a=j/sides*math.tau
            fold=1+.12*math.sin(a*3+t*5)+.045*math.cos(a*5-t*3)
            p=center+side*(math.cos(a)*width*profile*fold)+up*(math.sin(a)*depth*profile*fold)
            verts.append(tuple(p));uv.append((j/sides,t));colours.append(tint)
    row=sides+1
    for i in range(segments):
        for j in range(sides):
            k=i*row+j;faces.append((k,k+1,k+row+1,k+row))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple(segments*row+j for j in range(sides)))
    return mesh(name,verts,faces,uv,colours,MANTLE,parent)

def frond_tuft(region, parent, tint):
    """One connected reusable tuft: bent pinnate fronds and fine rising filaments."""
    verts=[];faces=[];uv=[];colours=[]
    height={'aurora':.64,'ember':.59,'veil':.88,'pale':.65}[region]
    def quad(points, tex):
        start=len(verts);verts.extend(tuple(p) for p in points);uv.extend(tex);colours.extend([tint]*4)
        faces.append((start,start+1,start+2,start+3))
    for frond in range(3):
        angle=frond*2.399+.4
        forward=Vector((math.cos(angle),math.sin(angle),0))
        side=Vector((-forward.y,forward.x,0))
        base=Vector((forward.x*.13,forward.y*.13,-.11))
        h=height*(.70+frond*.15)
        def center(t):return base+forward*(h*.95*t*t)+Vector((0,0,h*(t-.22*t*t)))
        for segment in range(3):
            a,b=segment/3,(segment+1)/3
            quad([center(a)-side*.013,center(a)+side*.013,center(b)+side*.008,center(b)-side*.008],[(0,a),(1,a),(1,b),(0,b)])
        for pair in range(5):
            t=.15+pair*.15
            root=center(t)
            length=h*(.36+.43*math.sin(t*math.pi))
            for sign in (-1,1):
                tip=root+side*sign*length+forward*h*.18+Vector((0,0,h*.10))
                shoulder=root+side*sign*length*.52+forward*h*.27+Vector((0,0,h*.18))
                quad([root-forward*h*.10,shoulder,tip,root+forward*h*.19],[(.5,0),(0,.45),(.5,1),(1,.45)])
    for filament in range(2):
        a=filament*2.6+.9;side=Vector((math.cos(a),math.sin(a),0));bend=Vector((-side.y,side.x,0))
        h=height*(.94+filament*.10)
        for segment in range(3):
            points=[];tex=[]
            for t,sign in [(segment/3,-1),(segment/3,1),((segment+1)/3,1),((segment+1)/3,-1)]:
                w=.065*(1-t*.72)
                points.append(side*w*sign+bend*h*t*t*.22+Vector((0,0,-.11+h*t)))
                tex.append(((sign+1)*.5,t))
            quad(points,tex)
    return mesh('rooted-fronds-and-filaments',verts,faces,uv,colours,MANTLE,parent)

def organism(region, form):
    stem, mantle = (colour(x) for x in PALETTES[region])
    parent=family(region+'_'+form)
    if form=='floor':
        frond_tuft(region,parent,mantle)
        return
    tall=form=='crown'
    h=(8.6 if tall else 4.1)*(1.10 if region=='veil' else .88 if region=='ember' else 1)
    count=4 if region=='pale' else 3
    terminal=(.55,-.35,h*.82)
    trunk_curve=[]
    tube('tapered-main-stem',[(0,0,-.45),(.32,.11,h*.25),(-.35,.14,h*.59),terminal], [.73 if tall else .48,.49,.31,.13],parent,stem,11,3,curve_out=trunk_curve)
    for i in range(5):
        a=i*2.399+.3; extent=2.1 if tall else 1.3
        tube('root-buttress-'+str(i),[(.05,.06,.7),(math.cos(a)*extent*.58,math.sin(a)*extent*.58,.09),(math.cos(a)*extent,math.sin(a)*extent,-.38)],[.30,.19,.035],parent,stem,8,2)
    for i in range(count):
        a=i*2.399+.25
        z=h*((.54+.23*i/(count-1)) if tall else (.43+.28*i/(count-1)))
        extent=(2.0 if tall else 1.0)*(.74 if i%2 else 1.0)
        # Branches originate on the actual swept trunk, including its terminal
        # curve. A fixed x/y origin detached the highest branches after bending.
        origin=trunk_curve[0]
        for lower,upper in zip(trunk_curve,trunk_curve[1:]):
            if lower.z<=z-.4<=upper.z:
                origin=lower.lerp(upper,(z-.4-lower.z)/(upper.z-lower.z));break
        tip=Vector((math.cos(a)*extent,math.sin(a)*extent,z+.27))
        tube('connected-crown-branch-'+str(i),[tuple(origin),tuple(origin.lerp(tip,.55)+Vector((0,0,.19))),tuple(tip)],[.30 if tall else .22,.23 if tall else .15,.13 if tall else .10],parent,stem,8,3)
        length=(2.7 if tall else 1.7)*(1.10 if region=='veil' else .9 if region=='ember' else 1)
        for lobe in range(2):
            direction=Vector((math.cos(a+.75*lobe)*(.65 if lobe else .85),math.sin(a+.75*lobe)*(.65 if lobe else .85),.52 if lobe else .28))
            width=(1.24 if tall else .84)*(1.0 if lobe else 1.15)
            depth=width*(.47 if region=='pale' else .40)
            wing_lobe('tilted-connected-lobe-'+str(i)+'-'+str(lobe),tip,direction,length*(.76 if lobe else 1),width,depth,.42 if lobe else -.35,parent,mantle)
    wing_lobe('unequal-terminal-lobe',terminal,(.22,.13,1),2.4 if tall else 1.4,1.28 if tall else .82,.65 if tall else .4,.45,parent,mantle)

for region in PALETTES:
    for form in ('crown','fork','floor'): organism(region,form)

parent=family('veil_rootbed')
for i in range(7):
    a=i*2.399
    tube('drowned-root-'+str(i),[(0,0,.75),(math.cos(a)*1.3,math.sin(a)*1.3,.38),(math.cos(a)*3.0,math.sin(a)*3.0,-.35)],[.42,.28,.055],parent,colour('5d817b'),9,3)
for i in range(3):wing_lobe('root-lamina-'+str(i),(math.sin(i*2.2)*.8,math.cos(i*2.2)*.7,.65+i*.32),(math.cos(i*2.2),math.sin(i*2.2),.55),1.45,.53,.24,i*.3,parent,colour('6d9891'))
parent=family('fallen_root')
tube('fallen-mineral-stem',[(-4.6,0,-.22),(-2.3,.25,.48),(.6,-.15,.65),(4.4,.3,-.18)],[.28,.61,.50,.14],parent,colour('7c8b80'),12,3)
for i in range(3):
    a=i*2.39
    tube('fallen-anchor-'+str(i),[(-2+i*1.7,.15,.5),(-1.2+i*1.7,math.cos(a)*1.5,-.22)],[.23,.04],parent,colour('71827a'),8,3)
    wing_lobe('fallen-young-growth-'+str(i),(-2+i*1.65,.10,.45+i*.15),(math.cos(a),math.sin(a),.7),1.2,.52,.27,a*.3,parent,colour('baa0a8'))
parent=family('pale_nurse')
tube('fungal-nurse-spine',[(-3.8,0,-.35),(-1.7,.25,.5),(.7,-.2,1.0),(3.9,.3,-.15)],[.30,.75,.69,.13],parent,colour('a99e94'),12,3)
for i in range(4):
    p=(-2.4+i*1.5, math.sin(i*2.4)*.45, .8+i%2*.4)
    wing_lobe('mature-folded-gill-'+str(i),p,(math.cos(i*2.4),math.sin(i*2.4),.7),1.5+i%2*.25,.72,.36,i*.2,parent,colour('ba939e'))
parent=family('shore_pebble')
shell('tidal-mineral',(0,0,-.05),.38,.23,.2,5,parent,colour('7c918b'),20,2,.05)

# Join once per family/material before export; no per-leaf runtime topology work.
records={}
for name, record in FAMILIES.items():
    objects=[]
    material_parts=[(mat,[obj for obj in record['objects'] if obj.data.materials[0]==mat]) for mat in (STEM,MANTLE)]
    for mat,parts in material_parts:
        if not parts:continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in parts:obj.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.join()
        obj=parts[0];obj.name='GEO-'+name+('-stem' if mat==STEM else '-mantle');obj.parent=record['parent']
        objects.append(obj)
    record['objects']=objects
    bounds=[Vector((float('inf'),)*3),Vector((-float('inf'),)*3)]
    triangles=0
    for obj in objects:
        obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
        for vertex in obj.data.vertices:
            for axis in range(3):bounds[0][axis]=min(bounds[0][axis],vertex.co[axis]);bounds[1][axis]=max(bounds[1][axis],vertex.co[axis])
    assert triangles<4300, (name,triangles)
    assert bounds[0].z<0 and bounds[1].z>0, name
    records[name]={'triangles':triangles,'material_surfaces':len(objects),'bounds_blender_z_up':[list(p) for p in bounds]}

bpy.ops.object.select_all(action='DESELECT')
for record in FAMILIES.values():
    record['parent'].select_set(True)
    for obj in record['objects']:obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'listening-flora.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=False,export_materials='EXPORT',export_normals=True,export_tangents=True,export_attributes=True)
# Blender 5.2's multiplied VertexColor node exported white COLOR_0 and the actual
# Tone as COLOR_1. Godot consumes COLOR_0: promote the measured authored channel.
blob=(OUT/'listening-flora.glb').read_bytes()
length=struct.unpack_from('<I',blob,12)[0]
document=json.loads(blob[20:20+length])
for model in document['meshes']:
    for primitive in model['primitives']:
        attributes=primitive['attributes']
        assert 'COLOR_1' in attributes, model['name']
        attributes['COLOR_0']=attributes.pop('COLOR_1')
for mat in document['materials']: mat['doubleSided']=False
encoded=json.dumps(document,separators=(',',':')).encode('utf-8')
encoded+=b' '*(-len(encoded)%4)
remainder=blob[20+length:]
(OUT/'listening-flora.glb').write_bytes(struct.pack('<III',0x46546C67,2,20+len(encoded)+len(remainder))+struct.pack('<II',len(encoded),0x4E4F534A)+encoded+remainder)
for sample in bpy.data.images: sample.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'listening-flora.blend'))
manifest={'schema':1,'author':'project-authored original geometry; deterministic mathematical construction','blender':bpy.app.version_string,'units':'metres; Blender Z-up exported glTF Y-up','families':records,'shared_materials':2,'alpha':'OPAQUE; closed mantle surfaces','seed':'fixed construction constants, no external generator','reused_maps':[{'path':'godot/assets/market_environment/cc0/Bark012_1K-JPG_NormalGL.jpg','source':'ambientCG Bark012, CC0'},{'path':'godot/assets/market_environment/cc0/Bark012_1K-JPG_Roughness.jpg','source':'ambientCG Bark012, CC0'}],'new_texture_size':512,'author_seconds':round(time.monotonic()-START,3),'glb_bytes':(OUT/'listening-flora.glb').stat().st_size,'glb_sha256':hashlib.sha256((OUT/'listening-flora.glb').read_bytes()).hexdigest()}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(EVIDENCE/'asset-authoring.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('ALIEN_FLORA_AUTHORED '+json.dumps({'families':len(records),'triangles':sum(x['triangles'] for x in records.values()),'bytes':manifest['glb_bytes'],'seconds':manifest['author_seconds']}))
