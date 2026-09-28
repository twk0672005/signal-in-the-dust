"""Low eye-level structural comparison; actual revision-b GLB reimports only."""
import bpy,sys,argparse,json,hashlib,os
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'evidence/visual-upgrade-20260923/flora-authoring/revision-b'
ASSETS=ROOT/'godot/assets/visual_flora/revision-b'

def light(name,position,power,size,color,target):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size;data.color=color
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.location=position
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
    return obj

def render(name,views):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    path=ASSETS/(name+'.glb');bpy.ops.import_scene.gltf(filepath=str(path))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    coords=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
    lo=Vector([min(c[i] for c in coords) for i in range(3)]);hi=Vector([max(c[i] for c in coords) for i in range(3)])
    center=(lo+hi)*.5;size=hi-lo;extent=max(size)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True;scene.cycles.device='CPU'
    scene.render.threads_mode='FIXED';scene.render.threads=6
    scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
    world=bpy.data.worlds.new('RevisionComparisonWorld');world.use_nodes=True;scene.world=world
    bpy.ops.mesh.primitive_plane_add(size=extent*160,location=(center.x,center.y,0))
    floor=bpy.context.object;floor.name='INSPECTION_ONLY_ContactPlane'
    mat=bpy.data.materials.new('Inspection_only_grey');mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.18,.19,.20,1);bs.inputs['Roughness'].default_value=.9
    floor.data.materials.append(mat)
    lights=[light('Large neutral key',center+Vector((-extent*.7,-extent*.9,extent*.75)),extent**2*18,extent*.70,(1,.93,.85),center),
            light('Soft neutral fill',center+Vector((extent*.9,-extent*.15,extent*.5)),extent**2*13,extent*.65,(.78,.86,1),center),
            light('Roof separation',center+Vector((0,extent*.85,extent*.9)),extent**2*17,extent*.60,(.92,.95,1),center)]
    data=bpy.data.cameras.new('GLB inspection camera');camera=bpy.data.objects.new('GLB inspection camera',data);bpy.context.collection.objects.link(camera);scene.camera=camera
    data.type='ORTHO';data.clip_end=extent*300
    emissions=[]
    for obj in meshes:
        for m in obj.data.materials:
            if m.use_nodes:
                bs=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
                if bs and all(bs!=old[0] for old in emissions):emissions.append((bs,bs.inputs['Emission Strength'].default_value))
    receipt={'asset':name,'revision':'b','sourceGlb':str(path),'sourceSha256':hashlib.sha256(path.read_bytes()).hexdigest(),
       'blender':bpy.app.version_string,'executable':bpy.app.binary_path,'processId':os.getpid(),
       'renderer':'Cycles CPU 6 threads, 32 samples, denoising. Offline GLB review; not Godot.',
       'imageSize':[1200,1200],'groundZ':0,'images':[]}
    for view in views:
        night=view=='night'
        for bs,value in emissions:bs.inputs['Emission Strength'].default_value=value if night else 0
        world.node_tree.nodes['Background'].inputs['Color'].default_value=(.045,.055,.12,1) if night else (.33,.35,.39,1)
        world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55 if night else .65
        colors=[(.4,.46,1),(.15,.58,.73),(.79,.50,.27)] if night else [(1,.93,.85),(.78,.86,1),(.92,.95,1)]
        for idx,obj in enumerate(lights):obj.data.color=colors[idx];obj.data.energy=extent**2*([10,7,9][idx] if night else [18,13,17][idx])
        target=center.copy();target.z=max(.5,(hi.z)*.48)
        offset={'front':(.43,-1.8,-.10 if name=='canopy' else .10),
                'side':(1.9,.30,.10),'back':(-.45,1.85,.05),'night':(.43,-1.8,-.10 if name=='canopy' else .10)}
        scale=extent*1.13
        if view in ('support_detail','tissue_detail'):
            if name=='canopy':
                target=Vector((-6.8,0,5.8)) if view=='support_detail' else Vector((-.5,-1.5,17.5))
                scale=13 if view=='support_detail' else 20
            else:
                target=Vector((-.1,.1,1.1)) if view=='support_detail' else Vector((1.35,.1,4.8))
                scale=3.2 if view=='support_detail' else 4.8
            position=target+Vector((.45,-1.8,.35))*scale
        else:position=target+Vector(offset[view])*extent
        data.type='ORTHO' if view in ('support_detail','tissue_detail') else 'PERSP'
        data.lens=50
        camera.location=position;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();data.ortho_scale=scale
        out=OUT/(name+'-'+view+'.png');scene.render.filepath=str(out);bpy.ops.render.render(write_still=True)
        receipt['images'].append({'file':out.name,'view':view,'emissionEnabled':night,'camera':list(position),'target':list(target),'orthoScale':scale,
                                   'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
    (OUT/(name+'-render.json')).write_text(json.dumps(receipt,indent=2),encoding='utf8')
    print('REVISION_RENDER_COMPLETE '+name,flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--families',default='canopy,sails');p.add_argument('--views',default='front,side,back,night,support_detail,tissue_detail')
    a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for name in a.families.split(','):render(name,a.views.split(','))
