"""Canopy/sail geometry reconstruction after independent art NO-SHIP.
Uses an independent Blender process. Does not connect to MCP or touch Godot.
Previous six-family kit and all other four families remain immutable.
"""
import bpy, math, json, sys, argparse, random, hashlib, importlib.util, os
import numpy as np
from pathlib import Path
from mathutils import Vector, noise

ROOT=Path(__file__).resolve().parents[3]
SRC=ROOT/'art-source/visual_flora/revision-b'
OUT=ROOT/'godot/assets/visual_flora/revision-b'
EVID=ROOT/'evidence/visual-upgrade-20260923/flora-authoring/revision-b'
for p in (SRC,OUT/'textures',EVID):p.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('flora_geometry',ROOT/'art-source/visual_flora/build_flora.py')
lib=importlib.util.module_from_spec(spec);spec.loader.exec_module(lib)
lib.OUT=OUT;lib.SOURCE=SRC;lib.EVIDENCE=EVID
R=random.Random(901173);TAU=math.tau
GROUPS={};SCULPTS=[];ROOT_NODE=None

def grp(name,mat):
    if name not in GROUPS:GROUPS[name]=lib.Mesh(name,mat)
    return GROUPS[name]

def pbr(name,base,kind,rough,alpha=1,emission=None):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*base,1)
    bs.inputs['Roughness'].default_value=rough
    bs.inputs['Metallic'].default_value=0
    bs.inputs['Specular IOR Level'].default_value=.30
    if alpha<1:
        bs.inputs['Alpha'].default_value=alpha;mat.surface_render_method='DITHERED';mat.use_backface_culling=False
    if emission:
        bs.inputs['Emission Color'].default_value=(*emission,1);bs.inputs['Emission Strength'].default_value=1.8
    if kind!='organ':
        n=1024;y,x=np.mgrid[0:n,0:n].astype(float)/n
        f=lib.noise(x,y,7);f2=lib.noise(x,y,23)
        if kind=='mineral':
            strata=np.power(np.maximum(0,np.sin((x+.035*f2)*TAU*27)),18)
            pits=np.maximum(0,-f-.18)**2
            height=.14*f+.045*f2-.14*strata-.2*pits
            shade=.84+.35*f-.18*strata
        elif kind=='rib':
            height=.08*f+.025*np.sin(x*TAU*34+f2)
            shade=.90+.20*f
        else:
            vascular=lib.vascular_network(x,y,29 if kind=='sail' else 13)
            fiber=np.exp(-np.abs(np.sin((x+.003*f2)*TAU*71))*18)
            height=.025*f+.060*vascular+.010*fiber
            shade=.91+.10*f+.13*vascular
        rgb=np.stack([np.clip(base[i]*shade*(1+f2*.025*(i-1)),0,1) for i in range(3)],axis=-1)
        t=mat.node_tree.nodes.new('ShaderNodeTexImage');t.image=lib.image_map(name+'_albedo',rgb)
        mat.node_tree.links.new(t.outputs['Color'],bs.inputs['Base Color'])
        dx=np.roll(height,-1,axis=1)-np.roll(height,1,axis=1);dy=np.roll(height,-1,axis=0)-np.roll(height,1,axis=0)
        normal=np.stack([-dx*5,-dy*5,np.ones_like(dx)],axis=-1);normal/=np.linalg.norm(normal,axis=-1,keepdims=True)
        t=mat.node_tree.nodes.new('ShaderNodeTexImage');t.image=lib.image_map(name+'_normal',normal*.5+.5,True)
        nm=mat.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.65
        mat.node_tree.links.new(t.outputs['Color'],nm.inputs['Color']);mat.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
        t=mat.node_tree.nodes.new('ShaderNodeTexImage');t.image=lib.image_map(name+'_roughness',np.clip(rough+.08*f2,.14,.93),True)
        mat.node_tree.links.new(t.outputs['Color'],bs.inputs['Roughness'])
    lib.MATERIALS[name]=mat
    return mat

def setup_materials():
    pbr('MAT_Mineral_Growth',(.40,.345,.285),'mineral',.73)
    pbr('MAT_Rib_Living',(.48,.40,.29),'rib',.54)
    pbr('MAT_Canopy_ThinTissue',(.35,.47,.48),'canopy',.44)
    pbr('MAT_Sail_ThinTissue',(.44,.49,.58),'sail',.44,alpha=.94)
    pbr('MAT_Cyan_Embedded',(.07,.34,.38),'organ',.32,emission=(.04,.48,.59))

def tube(g,points,radius,sides=14,steps=34,ridges=.075,flatten=1):
    return lib.tube(g,points,radius,sides,steps,ridges,flatten)

def at(path,t):
    v=max(0,min(.999999,t))*(len(path)-1);i=int(v)
    return path[i].lerp(path[i+1],v-i)

def growth_root(body,anchor,target,width,count=7,spread=4):
    # Root blades sweep into the same collar; remesh fuses these shared volumes.
    a=Vector(anchor);b=Vector(target)
    for k in range(count):
        theta=TAU*k/count+R.uniform(-.18,.18);rr=spread*R.uniform(.7,1.1)
        tip=a+Vector((math.cos(theta)*rr,math.sin(theta)*rr,-.24))
        heel=a+Vector((math.cos(theta)*rr*.44,math.sin(theta)*rr*.44,.22))
        neck=a.lerp(b,.47)+Vector((math.cos(theta)*width*.9,math.sin(theta)*width*.9,0))
        points=[tip,heel,neck,b]
        tube(body,points,lambda t: .04+width*(math.sin(t*math.pi*.60)**1.1),16,36,.10,.68)

def fuse_growth(obj,voxel,ratio,sculpt_name):
    print('FUSE_START '+obj.name,flush=True)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Fuse shared root and branching load volume','REMESH');mod.mode='VOXEL';mod.voxel_size=voxel;mod.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    print('FUSE_VOLUME_READY '+str(len(obj.data.vertices)),flush=True)
    smooth=obj.modifiers.new('Primary organic surface relaxation','SMOOTH');smooth.factor=.72;smooth.iterations=4
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    # Real medium-scale growth erosion, not independent rectangular flakes.
    obj.data.update()
    coords=np.empty(len(obj.data.vertices)*3,dtype=np.float32)
    normals=np.empty(len(obj.data.vertices)*3,dtype=np.float32)
    obj.data.vertices.foreach_get('co',coords)
    obj.data.vertices.foreach_get('normal',normals)
    coords=coords.reshape(-1,3);normals=normals.reshape(-1,3)
    for i,row in enumerate(coords):
        p=Vector(row)
        field=noise.noise_vector(p*.65,noise_basis='PERLIN_ORIGINAL').x
        small=noise.noise_vector(p*2.4,noise_basis='PERLIN_ORIGINAL').y
        coords[i]+=normals[i]*(field*voxel*.47+small*voxel*.15)
    obj.data.vertices.foreach_set('co',coords.ravel())
    obj.data.update()
    print('FUSE_EROSION_READY',flush=True)
    # Keep the pre-reduction sculpt inside native source only, excluded from export.
    high=bpy.data.objects.new(sculpt_name,obj.data.copy());bpy.context.collection.objects.link(high)
    high.hide_render=True;high.hide_set(True);high['role']='preserved fused sculpt before export reduction; not exported'
    SCULPTS.append(high)
    dec=obj.modifiers.new('Static export surface reduction','DECIMATE');dec.ratio=ratio;dec.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=dec.name)
    print('FUSE_REDUCED '+str(len(obj.data.polygons)),flush=True)
    # World-projected mineral microdetail; geometric ridges already follow growth.
    mesh=obj.data;uv=mesh.uv_layers.get('UVMap') or mesh.uv_layers.new(name='UVMap')
    for polygon in mesh.polygons:
        polygon.use_smooth=True
        dominant=max(range(3),key=lambda k:abs(polygon.normal[k]));axes=[i for i in range(3) if i!=dominant]
        for loop in polygon.loop_indices:
            co=mesh.vertices[mesh.loops[loop].vertex_index].co
            uv.data[loop].uv=(co[axes[0]]*.37,co[axes[1]]*.37)
    obj['construction']='single voxel-fused root/branch volume; reduced static surface; open channels between ribs are intentional hollows'
    return obj

def color_variation(obj,is_tissue=False):
    mesh=obj.data
    attr=mesh.color_attributes.new(name='GrowthVariation',type='FLOAT_COLOR',domain='POINT')
    for i,v in enumerate(mesh.vertices):
        p=v.co;f=noise.noise_vector(p*.32,noise_basis='PERLIN_ORIGINAL').x
        if is_tissue:
            val=.89+.08*f;rgb=(val*.95,val,val*1.02)
        else:
            wet=max(0,1-p.z/2.7)*.22
            val=.86+.12*f-wet;rgb=(val*1.03,val,val*.95)
        attr.data[i].color=(*rgb,1)
    mesh.color_attributes.active_color=attr
    obj['vertexColor']='GrowthVariation RGB: subtle mottling and dark damp root transition; alpha=1. Not illumination.'

def canopy():
    body=grp('SM_Canopy_ContinuousHollowGrowth','MAT_Mineral_Growth')
    rib=grp('SM_Canopy_BranchingVascularRibs','MAT_Rib_Living')
    leaf=grp('SM_Canopy_IntegratedVaultTissue','MAT_Canopy_ThinTissue')
    organs=grp('SM_Canopy_EmbeddedNodes','MAT_Cyan_Embedded')
    # Four unequal mineral ribs form an open, leaning hollow trunk, not posts.
    paths=[
      [(-8.9,-1.5,-.5),(-8.5,-1.6,2.8),(-7.6,-1.15,6.9),(-5.8,-.7,10.8),(-3.4,-.2,13.1)],
      [(-6.4,-.5,-.4),(-7.05,-.2,3.2),(-6.5,.0,7.2),(-5.4,.3,10.2),(-3.4,-.2,13.1)],
      [(-8.5,1.8,-.5),(-9.0,1.3,3.0),(-8.0,1.1,6.8),(-6.2,1.7,10.0),(-3.3,.7,13.2)],
      [(-6.8,2.1,-.4),(-6.7,1.7,3.8),(-5.8,1.5,7.5),(-4.7,1.3,10.5),(-3.3,.7,13.2)]]
    for i,p in enumerate(paths):
        tube(body,p,lambda t:.66+.50*(1-t)**1.3,20,58,.12,.90)
    growth_root(body,(-8,0,0),(-8,.1,3.7),.62,9,5.2)
    # Growing side bridges connect ribs around open erosion windows.
    tube(body,[(-8.3,-1.3,2.0),(-7.6,-1.4,3.4),(-7.0,-.2,4.6)],.36,14,28,.1)
    tube(body,[(-8.1,1.2,5.6),(-7.4,.5,6.4),(-6.6,.05,7.6)],.30,13,28,.08)
    tube(body,[(-6.5,1.6,3.8),(-6.2,1.7,5.7),(-5.85,1.5,7.4)],.34,14,26,.10)
    # Two strongly inclined, unequal root braces feed directly into crown load paths.
    brace=[(10.4,5.2,-.4),(9.2,5.0,3.0),(7.6,4.6,6.5),(4.6,3.4,11.7),(.6,1.5,15.8),(-3.2,.2,13.1)]
    tube(body,brace,lambda t:.68+.30*math.sin(t*math.pi),20,84,.095)
    growth_root(body,(10.4,5.2,0),(9.2,5.0,3.2),.47,6,3.6)
    tube(body,[(11.4,6.4,-.4),(10.8,6.4,3.1),(8.4,5.3,6.2),(5.0,3.6,11.5)],lambda t:.66*(1-t)+.38,18,54,.1)
    rear=[(2.6,9.0,-.4),(1.1,8.3,3.4),(-.6,6.8,7.5),(-2.0,4.7,11.2),(-3.3,.7,13.2)]
    tube(body,rear,lambda t:.55+.12*math.sin(t*math.pi),18,62,.1)
    growth_root(body,(2.6,9,0),(1.1,8.3,3.4),.39,5,2.9)
    # Crown rays grow from the hollow trunk itself and spread through real depth.
    tips=[(-11.5,-4.0,18.0),(-7.0,-7.0,21.3),(-.5,-7.6,22.6),(7.8,-4.5,20.7),
          (13.4,.5,16.9),(10.5,7.3,17.9),(3.0,10.6,20.4),(-5.4,8.4,20.5),(-11.7,3.5,17.9)]
    rays=[]
    for i,tip in enumerate(tips):
        start=Vector((-4.2+.45*math.sin(i*.7),.4+.4*math.cos(i),11.9+.4*math.sin(i)))
        end=Vector(tip);delta=end-start
        control=[start,start+delta*.30+Vector((0,0,3.0)),start+delta*.67+Vector((0,0,2.5)),end]
        ps=tube(body,control,lambda t:.64*(1-t)**1.3+.055,18,64,.085)
        rays.append(ps)
        # Each ray also carries a fused slender longitudinal growth ridge.
        offset=Vector((.10*math.sin(i),.10*math.cos(i),.17))
        tube(body,[tuple(at(ps,t)+offset*(1-t)) for t in (0,.2,.4,.6,.8,.94)],lambda t:.16*(1-t)+.027,10,34,.06)
    # Independent stretched bays follow the load rays; they are not a crown card.
    for bay in range(len(rays)):
        left=rays[bay];right=rays[(bay+1)%len(rays)]
        start=.31+(.04 if bay%3==0 else -.025)
        def panel(u,v,left=left,right=right,start=start,bay=bay):
            inner=start+.07*math.sin(u*math.pi)
            t=inner+(1-inner)*v
            p=at(left,t).lerp(at(right,t),u)
            p.z-= (.28+.10*math.sin(bay*1.9))*math.sin(u*math.pi)*math.sin(v*math.pi*.9)
            p.z+=.045*math.sin(u*math.pi*3+bay)*math.sin(v*math.pi)*math.exp(-v*3)
            return tuple(p)
        lib.grid_shell(leaf,panel,22,30,.032)
        # A narrow organic outer vein resolves the tissue boundary, not a thick rim.
        tube(rib,[panel(j/24,1) for j in range(25)],.035,8,34,.03)
        for n in range(6):
            tt=.28+n*.115
            # Branches fork off each load rib into membrane and meet across the bay.
            for side in (0,1):
                target=.46 if side==0 else .54
                points=[panel(side+(target-side)*q,tt+q*.14) for q in (0,.25,.5,.75,1)]
                tube(rib,points,lambda t:.032*(1-t)+.008,7,16,.025)
                for split in (.45,.72):
                    points=[panel(side+(target-side)*(split+q*.24),tt+(split+q*.24)*.14+q*.055) for q in (0,.35,.7,1)]
                    tube(rib,points,.006,5,10,0)
    # Load-bearing perch is fused into the trunk and a right-hand crown ray.
    tube(body,[(-5.8,-.65,10.6),(-3.3,-1.9,12.0),(.5,-2.6,13.6),(3.6,-2.45,15.5),(5.6,-2.8,18.8)],lambda t:.48*(1-t)+.13,18,58,.07,.8)
    # Sparse nodules are seated into the growth surface and stay secondary.
    for p in [(-8.8,-2.0,1.4),(-7.6,-1.75,6.3),(-5.7,-1.18,10.4),(7.75,3.9,6.3),(9.8,4.7,2.0),(-.1,7.6,5.4)]:
        lib.ellipsoid(organs,p,(.10,.085,.22),12,8)
    return {'body':body.name,'voxel':.085,'ratio':.42,
      'construction':'Continuous fused hollow rib trunk; 3 unequal root systems; inclined load braces; 9 radial crown rays with membrane bays spanning those exact rays; no separate bark flakes or hanging crown card.'}

def sails():
    body=grp('SM_Sail_FusedRootAndCurvedSpars','MAT_Mineral_Growth')
    ribs=grp('SM_Sail_BranchingFineFibres','MAT_Rib_Living')
    tissue=grp('SM_Sail_TensionedThinBays','MAT_Sail_ThinTissue')
    organs=grp('SM_Sail_RootAxilNodes','MAT_Cyan_Embedded')
    growth_root(body,(0,0,0),(-.18,.1,1.12),.23,7,1.62)
    main=[(-.13,0,-.12),(-.30,.02,1.6),(-.47,.05,3.8),(-.56,.22,5.8),(.13,.42,7.72)]
    tube(body,main,lambda t:.245*(1-t)**1.3+.018,16,70,.075)
    # Open unequal collar ribs, fused at both ends and exposing small hollow channels.
    for i,p in enumerate([
       [(-.74,-.10,-.05),(-.72,-.15,.65),(-.55,-.12,1.4),(-.3,.02,2.0)],
       [(.61,.18,-.08),(.60,.08,.62),(.13,.0,1.32),(-.3,.02,1.83)],
       [(-.12,.72,-.08),(-.31,.56,.86),(-.38,.22,1.71)]
    ]):tube(body,p,lambda t:.13*(1-t)+.058,13,28,.08)
    endpoints=[(.13,.42,7.72),(1.15,.15,7.26),(2.40,.54,6.42),(3.58,.66,5.27),(3.96,.29,4.04),(3.66,-.08,3.00),(2.80,-.24,2.14)]
    rays=[]
    for i,end in enumerate(endpoints):
        t=i/(len(endpoints)-1)
        start=Vector((-.24,.035,.81+.19*t))
        e=Vector(end);d=e-start
        c1=start+d*.27+Vector((-.26,-.04,.36))
        c2=start+d*.67+Vector((-.22,.13*math.sin(i*1.6),.52))
        # These are nonparallel curved rays, so adjacent bays have differing loads.
        ps=tube(body,[start,c1,c2,e],lambda v: (.063 if i else .13)*(1-v)**1.25+.008,12,56,.03,.80)
        rays.append(ps)
    folds=[.018,.075,.012,.115,.035,.008]
    for bay in range(6):
        left=rays[bay];right=rays[bay+1];amp=folds[bay]
        def panel(u,v,left=left,right=right,bay=bay,amp=amp):
            # Inner holes at collar transition; taut mid-bay, local pinched folds.
            inner=.10+.035*math.sin(u*math.pi)
            t=inner+(1-inner)*v;p=at(left,t).lerp(at(right,t),u)
            p.y-=amp*math.sin(u*math.pi)*math.sin(v*math.pi*.92)
            p.y+=.023*math.sin(u*math.pi*3.5+bay)*math.sin(v*math.pi)*math.exp(-v*5)
            p.y+=.016*math.sin(v*math.pi*4+u*3)*math.sin(u*math.pi)*v**4
            # A single localized diagonal stress fold, not evenly spaced inflation.
            if bay==3:p.y+=.065*math.exp(-((u-.22-.28*v)/.14)**2)*math.sin(v*math.pi)
            return tuple(p)
        lib.grid_shell(tissue,panel,22,42,.006)
        tube(ribs,[panel(j/25,1) for j in range(26)],.0085,7,32,.015)
        # Real, branching fibres emerge from structural ribs; patchy spacing is intentional.
        for q,height in enumerate([.19,.31,.47,.61,.78]):
            u0=0 if (q+bay)%2==0 else 1
            across=.76 if u0==0 else .24
            points=[panel(u0+(across-u0)*s,height+s*.11) for s in (0,.25,.5,.75,1)]
            tube(ribs,points,lambda t:.0075*(1-t)+.0026,6,18,0)
            for split in (.44,.70):
                pts=[panel(u0+(across-u0)*(split+s*.19),height+(split+s*.19)*.11+s*.049) for s in (0,.33,.67,1)]
                tube(ribs,pts,.0024,5,10,0)
    for p in [(-.45,-.16,.62),(.22,-.15,.44),(-.30,-.13,1.22)]:
        lib.ellipsoid(organs,p,(.035,.026,.055),10,7)
    return {'body':body.name,'voxel':.016,'ratio':.45,
      'construction':'Single representative sail. Fused hollow root collar and curved nonparallel load rays. 6 mm tissue across six independently tensioned bays, variable local folds, fine branching fibres and 8.5 mm edge. Alpha held at prior 0.94.'}

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def build(name):
    global GROUPS,SCULPTS,ROOT_NODE,R
    GROUPS={};SCULPTS=[];R=random.Random(901173+(name=='sails')*119)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    ROOT_NODE=bpy.data.objects.new(name+'_revision_b_root',None);bpy.context.collection.objects.link(ROOT_NODE)
    ROOT_NODE['units']='metres';ROOT_NODE['origin']='Terrain contact; negative roots intentionally subsoil'
    ROOT_NODE['revision']='Independent art rejection response: primary structural reconstruction'
    params=(canopy if name=='canopy' else sails)()
    print('GEOMETRY_AUTHORED '+name,flush=True)
    objects=[]
    for group in GROUPS.values():
        obj=group.object(ROOT_NODE)
        if obj.name==params['body']:fuse_growth(obj,params['voxel'],params['ratio'],'SCULPT_'+name+'_preserved_fused_volume')
        color_variation(obj,'Tissue' in obj.name or 'ThinBays' in obj.name)
        objects.append(obj)
    scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    bpy.context.view_layer.update()
    coords=[obj.matrix_world@Vector(v) for obj in objects for v in obj.bound_box]
    low=[min(v[i] for v in coords) for i in range(3)];high=[max(v[i] for v in coords) for i in range(3)]
    bpy.ops.object.select_all(action='DESELECT');ROOT_NODE.select_set(True)
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.context.preferences.filepaths.save_version=0
    blend=SRC/(name+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    glb=OUT/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_yup=True,
       export_animations=False,export_extras=True,export_vertex_color='ACTIVE',export_all_vertex_colors=False)
    raw=glb.read_bytes();g=json.loads(raw[20:20+int.from_bytes(raw[12:16],'little')]);acc=g['accessors']
    primitives=[p for mesh in g['meshes'] for p in mesh['primitives']]
    report={'family':name,'revision':'b','blender':bpy.app.version_string,'processId':os.getpid(),
       'executable':bpy.app.binary_path,'scriptSha256':sha(Path(__file__)),'utilityScriptSha256':sha(ROOT/'art-source/visual_flora/build_flora.py'),
       'sourceBlend':str(blend),'sourceBlendSha256':sha(blend),'file':str(glb),'sha256':sha(glb),'bytes':len(raw),
       'triangles':sum(acc[p['indices']]['count']//3 for p in primitives),'meshCount':len(g['meshes']),
       'materials':len(g['materials']),'images':len(g['images']),'missingUV':sum('TEXCOORD_0' not in p['attributes'] for p in primitives),
       'missingVertexVariation':sum('COLOR_0' not in p['attributes'] for p in primitives),
       'boundsBlenderXYZ':{'min':low,'max':high,'size':[high[i]-low[i] for i in range(3)]},
       'sculptReferenceFaces':sum(len(o.data.polygons) for o in SCULPTS),'construction':params,
       'license':'Original local geometry and heightfield-authored raster PBR maps. No external assets. Concept is supplied project reference only.',
       'status':'EXPORTED_FOR_GLTF_REIMPORT_VISUAL_REVIEW; NOT runtime or art acceptance'}
    assert report['missingUV']==0 and report['missingVertexVariation']==0
    (OUT/(name+'.manifest.json')).write_text(json.dumps(report,indent=2),encoding='utf8')
    print('REVISION_B_EXPORT '+json.dumps(report),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--families',default='canopy,sails')
    a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    setup_materials()
    for name in a.families.split(','):build(name)
