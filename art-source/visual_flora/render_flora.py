"""Inspection renders import the exported GLB, never render the authoring scene."""
import bpy, math, json, sys, argparse, hashlib
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'evidence/visual-upgrade-20260923/flora-authoring'
ASSETS=ROOT/'godot/assets/visual_flora'

def light(name,location,energy,size,color,target):
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size;data.color=color
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.location=location
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
    return obj

def render(name,views):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    path=ASSETS/(name+'.glb');bpy.ops.import_scene.gltf(filepath=str(path))
    objs=[o for o in bpy.context.scene.objects if o.type=='MESH']
    coords=[o.matrix_world@Vector(v) for o in objs for v in o.bound_box]
    lo=Vector([min(v[i] for v in coords) for i in range(3)]);hi=Vector([max(v[i] for v in coords) for i in range(3)])
    center=(lo+hi)*.5;size=hi-lo;extent=max(size.x,size.y,size.z)
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.cycles.device='CPU';scene.render.threads_mode='FIXED';scene.render.threads=6
    scene.render.resolution_x=960;scene.render.resolution_y=960;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.view_settings.view_transform='AgX'
    world=bpy.data.worlds.new('InspectionWorld');world.use_nodes=True;scene.world=world
    camera_data=bpy.data.cameras.new('InspectionCamera');camera=bpy.data.objects.new('InspectionCamera',camera_data);bpy.context.collection.objects.link(camera)
    camera_data.type='ORTHO';camera_data.ortho_scale=extent*1.27;camera_data.lens=50;scene.camera=camera
    bpy.ops.mesh.primitive_plane_add(size=extent*200,location=(center.x,center.y,0))
    floor=bpy.context.object;floor.name='INSPECTION_ONLY_GROUND'
    mat=bpy.data.materials.new('InspectionGround');mat.use_nodes=True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.16,.175,.19,1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8;floor.data.materials.append(mat)
    lights=[light('SoftboxKey',center+Vector((-extent*.65,-extent*.70,extent*.9)),extent**2*17,extent*.65,(1,.92,.82),center),
            light('SoftboxFill',center+Vector((extent*.85,-extent*.1,extent*.4)),extent**2*10,extent*.65,(.70,.82,1),center),
            light('Rim',center+Vector((extent*.1,extent*.8,extent*.9)),extent**2*19,extent*.50,(.91,.94,1),center)]
    emissive=[]
    for m in bpy.data.materials:
        if m.use_nodes:
            bs=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
            if bs:emissive.append((bs,bs.inputs['Emission Strength'].default_value))
    report={'family':name,'sourceGlb':str(path),'sourceSha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'blender':bpy.app.version_string,'renderer':'Cycles CPU; 24 samples + denoise; offline structural/material inspection, NOT Godot/Web',
            'worldBoundsXYZ':{'min':list(lo),'max':list(hi)},'groundZ':0,'groundConvention':'Origin is terrain contact; negative root geometry is intentionally subsoil','images':[]}
    for view in views:
        night=view=='night'
        for bs,strength in emissive:bs.inputs['Emission Strength'].default_value=strength if night else 0
        bg=world.node_tree.nodes['Background'];bg.inputs['Color'].default_value=(.035,.045,.12,1) if night else (.35,.37,.41,1)
        bg.inputs['Strength'].default_value=.45 if night else .6
        colors=[(.36,.43,1),(.08,.52,.70),(.83,.42,.16)] if night else [(1,.92,.82),(.70,.82,1),(.91,.94,1)]
        for idx,obj in enumerate(lights):obj.data.color=colors[idx];obj.data.energy=extent**2*([8,5,8][idx] if night else [17,10,19][idx])
        offset={'front':(.68,-1.7,.77),'side':(1.8,.26,.56),'back':(-.68,1.7,.67),'night':(.68,-1.7,.77),'detail':(.28,-1.3,.85)}[view]
        camera.location=center+Vector(offset)*extent
        target=center+Vector((0,0,-size.z*.035))
        camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        if view=='detail':camera_data.ortho_scale=extent*.63
        else:camera_data.ortho_scale=extent*1.24
        output=OUT/(name+'-'+view+'.png');scene.render.filepath=str(output)
        bpy.ops.render.render(write_still=True)
        report['images'].append({'file':output.name,'view':view,'emissionEnabled':night,'cameraPosition':list(camera.location),
                                 'target':list(target),'orthographicScale':camera_data.ortho_scale,'viewport':[960,960]})
    (OUT/(name+'-render.json')).write_text(json.dumps(report,indent=2),encoding='utf8')
    print('GLB_RENDER_COMPLETE '+name,flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--families',default='canopy,sails');p.add_argument('--views',default='front,side,back,night')
    args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for name in args.families.split(','):render(name,args.views.split(','))
