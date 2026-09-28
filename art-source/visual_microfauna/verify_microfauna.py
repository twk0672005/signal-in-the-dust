"""Fresh-process GLB read-back and neutral candidate evidence. No Godot access."""
import bpy, json, struct, hashlib, sys, math, os
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'godot/assets/visual_microfauna'
BASE=ROOT/'evidence/visual-upgrade-20260923/microfauna-authoring'
phase=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'original'
DEST=BASE/phase;DEST.mkdir(exist_ok=True)

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def inspect_glb(path):
    raw=path.read_bytes();magic,version,total=struct.unpack_from('<4sII',raw)
    length,typ=struct.unpack_from('<II',raw,12);g=json.loads(raw[20:20+length])
    assert magic==b'glTF' and version==2 and total==len(raw)
    acc=g['accessors'];tris=0;surfaces=0
    for mesh in g.get('meshes',[]):
        for p in mesh['primitives']:
            assert p.get('mode',4)==4;assert 'TEXCOORD_0' in p['attributes'];assert 'JOINTS_0' in p['attributes'];surfaces+=1
            tris+=acc[p['indices']]['count']//3
    animations={}
    for a in g.get('animations',[]):
        root_translation=[]
        for c in a['channels']:
            node=g['nodes'][c['target']['node']]
            if c['target']['path']=='translation' and node.get('name') in ['root','detritus_crawler_01_rig','membrane_flier_01_rig']:
                accessor=acc[a['samplers'][c['sampler']]['output']]
                root_translation.append({'target':node.get('name'),'minimum':accessor.get('min'),'maximum':accessor.get('max')})
        duration=max(acc[s['input']]['max'][0] for s in a['samplers'])-min(acc[s['input']]['min'][0] for s in a['samplers'])
        animations[a['name']]={'duration_seconds':duration,'channels':len(a['channels']),'root_translation':root_translation}
    images=[{'name':i.get('name'), 'mimeType':i.get('mimeType'),'bytes':g['bufferViews'][i['bufferView']]['byteLength']} for i in g.get('images',[])]
    return {'glb_bytes':len(raw),'sha256':sha(path),'nodes':len(g['nodes']),'mesh_count':len(g['meshes']),'triangles':tris,'surfaces':surfaces,'skin_count':len(g.get('skins',[])),'joint_count':sum(len(s['joints']) for s in g.get('skins',[])),'materials':[{'name':m['name'],'alphaMode':m.get('alphaMode','OPAQUE'),'doubleSided':m.get('doubleSided',False)} for m in g.get('materials',[])],'embedded_images':images,'embedded_texture_bytes':sum(i['bytes'] for i in images),'animations':animations}

def aim(obj,target):obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

def stage(center,scale,floor_z):
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.render.threads_mode='FIXED';scene.render.threads=4
    scene.render.resolution_x=1100;scene.render.resolution_y=850;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False;scene.render.fps=24
    scene.world=bpy.data.worlds.new('Neutral_readback_world');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.24,.24,.24,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.32
    scene.view_settings.view_transform='AgX'
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,floor_z));ground=bpy.context.object;ground.name='EVIDENCE_ONLY_ground'
    m=bpy.data.materials.new('neutral_ground');m.diffuse_color=(.18,.19,.20,1);m.use_nodes=True;m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.18,.19,.20,1);m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.80;ground.data.materials.append(m)
    for name,loc,power,size in [('Key',(-.55,.48,.85),55,.70),('Fill',(.60,.22,.40),28,.65),('Rim',(.1,-.60,.60),44,.45)]:
        data=bpy.data.lights.new('EVIDENCE_ONLY_'+name,'AREA');data.energy=power;data.shape='DISK';data.size=size
        light=bpy.data.objects.new(data.name,data);bpy.context.collection.objects.link(light);light.location=loc;aim(light,center)
    data=bpy.data.cameras.new('EVIDENCE_ONLY_camera');camera=bpy.data.objects.new(data.name,data);bpy.context.collection.objects.link(camera);scene.camera=camera
    data.type='ORTHO';data.ortho_scale=scale;data.lens=60
    return camera

def capture(camera,path,pos,target):
    camera.location=pos;aim(camera,target);bpy.context.scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)

def metrics(obj):
    dep=bpy.context.evaluated_depsgraph_get();ev=obj.evaluated_get(dep);mesh=ev.to_mesh();pts=[ev.matrix_world@v.co for v in mesh.vertices]
    mn=[min(p[i] for p in pts) for i in range(3)];mx=[max(p[i] for p in pts) for i in range(3)]
    digest=hashlib.sha256(b''.join(struct.pack('<fff',*p) for p in pts)).hexdigest()
    ev.to_mesh_clear();return {'min_xyz':mn,'max_xyz':mx,'dimensions_xyz':[mx[i]-mn[i] for i in range(3)],'deformed_vertex_sha256':digest}

def set_action(rig,action):
    if rig.animation_data:
        for track in rig.animation_data.nla_tracks:track.mute=True
    for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
    rig.animation_data_create();rig.animation_data.action=action
    if action and len(action.slots):rig.animation_data.action_slot=action.slots[0]
    bpy.context.view_layer.update()

def run(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path=OUT/(name+'.glb');report=inspect_glb(path)
    bpy.ops.import_scene.gltf(filepath=str(path))
    rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE'];meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(rigs)==1 and len(meshes)==1
    rig,obj=rigs[0],meshes[0]
    report['imported_actions']=[{'name':a.name,'frames':list(a.frame_range),'slots':[s.identifier for s in a.slots]} for a in bpy.data.actions]
    set_action(rig,None);bpy.context.scene.frame_set(1)
    report['rest_readback']=metrics(obj)
    report['imported_bones']=list(rig.data.bones.keys())
    crawler=name.startswith('detritus');center=(0,0,.065) if crawler else (0,-.01,.015);scale=.53 if crawler else .78
    camera=stage(center,scale,0 if crawler else -.055)
    capture(camera,DEST/(name+'_three_quarter.png'),(.52,.62,.40) if crawler else (.52,.65,.66),center)
    capture(camera,DEST/(name+'_side_contact.png'),(.65,0,.105) if crawler else (.7,.02,.085),center)
    clip='walk' if crawler else 'flutter';action=next(a for a in bpy.data.actions if a.name==clip or a.name.startswith(clip+'.'))
    set_action(rig,action)
    frames=[4,16] if crawler else [2,5]
    report['animation_observations']=[]
    for frame in frames:
        bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();entry={'clip':clip,'frame':frame,'seconds':(frame-1)/24,**metrics(obj)}
        if crawler:entry['ankle_z']={p.name:float((rig.matrix_world@p.tail).z) for p in rig.pose.bones if p.name.endswith('_lower')}
        report['animation_observations'].append(entry)
        capture(camera,DEST/f'{name}_{clip}_f{frame:03}.png',(.52,.62,.34) if crawler else (.52,.65,.66),center)
    assert report['animation_observations'][0]['deformed_vertex_sha256']!=report['animation_observations'][1]['deformed_vertex_sha256']
    # Prove clip endpoints and every requested clip change by evaluated geometry.
    report['clip_samples']={}
    for anim in report['animations']:
        action=next(a for a in bpy.data.actions if a.name==anim or a.name.startswith(anim+'.'));set_action(rig,action)
        samples=[]
        end=49 if anim=='idle' else 25
        for frame in [1,5,13,end]:
            bpy.context.scene.frame_set(frame);samples.append({'frame':frame,**metrics(obj)})
        report['clip_samples'][anim]=samples
    bpy.ops.wm.save_as_mainfile(filepath=str(DEST/(name+'_readback.blend')))
    report['offline_only']=True;report['blender_version']=bpy.app.version_string;report['process_id']=os.getpid()
    (DEST/(name+'_readback.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('READBACK_COMPLETE '+json.dumps({'name':name,'triangles':report['triangles'],'surfaces':report['surfaces'],'actions':report['imported_actions']}))
    return report

all_reports={name:run(name) for name in ['detritus_crawler_01','membrane_flier_01']}
(DEST/'verification.json').write_text(json.dumps(all_reports,indent=2),encoding='utf-8')
print('MICROFAUNA_VERIFY_COMPLETE')
