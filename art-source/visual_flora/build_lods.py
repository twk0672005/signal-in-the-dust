"""Derive static distant forms from the final high GLBs. No engine import/build."""
import bpy, json, hashlib, sys, argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'godot/assets/visual_flora'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(name,ratio):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    src=OUT/(name+'.glb');bpy.ops.import_scene.gltf(filepath=str(src))
    nodes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    materials={}
    for o in nodes:
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        modifier=o.modifiers.new('Distant mesh reduction','DECIMATE');modifier.ratio=ratio;modifier.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        key=o.data.materials[0].name
        materials.setdefault(key,[]).append(o)
    for mat,objects in materials.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join();obj=bpy.context.object;obj.name=name+'_lod1_'+mat.split('.')[0]
        # Whole distant cluster uses ground origin; wind hierarchies stay in high form.
        bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    out=OUT/(name+'_lod1.glb')
    bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_yup=True,export_animations=False,export_extras=True)
    data=out.read_bytes();g=json.loads(data[20:20+int.from_bytes(data[12:16],'little')]);acc=g['accessors']
    triangles=sum(acc[p['indices']]['count']//3 for m in g['meshes'] for p in m['primitives'])
    report={'family':name,'file':str(out.relative_to(ROOT)).replace('\\','/'),'sourceGlbSha256':digest(src),'sha256':digest(out),
        'bytes':out.stat().st_size,'triangles':triangles,'meshes':len(g['meshes']),'materials':len(g['materials']),
        'decimationRatio':ratio,'blender':bpy.app.version_string,'scriptSha256':digest(Path(__file__)),
        'purpose':'Static distant form with original silhouette/materials. Per-material mesh consolidation. No animation, collision or engine-performance claim.',
        'textureWarning':'Textures remain embedded for portable GLB handoff. Do not blindly preload high and distant copies on memory-limited devices; verify texture deduplication in engine.'}
    (OUT/(name+'_lod1.manifest.json')).write_text(json.dumps(report,indent=2),encoding='utf8')
    print('FLORA_LOD '+json.dumps(report),flush=True)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--families',default='canopy,sails,pods,cups,mat,spores');p.add_argument('--ratio',default=.24,type=float)
    a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for name in a.families.split(','):run(name,a.ratio)
