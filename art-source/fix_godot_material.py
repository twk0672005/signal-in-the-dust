"""Asset-only workaround for Godot 4.7 vertex colour importer regression #120625.
The documented -vcol suffix forces imported albedo to use COLOR_0. Compatibility
ignores the associated sRGB flag. Mesh/node/texture BIN bytes remain identical.
"""
import bpy,json,struct,hashlib,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
EVID=ROOT/'evidence/assets/godot-material-fix'
EVID.mkdir(parents=True,exist_ok=True)
rep_path=ROOT/'evidence/assets/report.json'
report=json.loads(rep_path.read_text())
changes=[]
for key in ('signal','rocks','rocks_low'):
    path=ROOT/'godot/assets/models'/(key+'.glb')
    raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+size]);binary=raw[20+size:]
    before=hashlib.sha256(raw).hexdigest()
    backup=EVID/(key+'-before.glb')
    if not backup.exists():shutil.copy2(path,backup)
    for m in doc['materials']:
        if m.get('name','').startswith('basalt vertex strata'):m['name']='basalt vertex strata-vcol'
    encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
    updated=b'glTF'+struct.pack('<II',2,20+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+binary
    path.write_bytes(updated)
    changes.append({'asset':key,'before_sha256':before,'after_sha256':hashlib.sha256(updated).hexdigest(),'binary_geometry_textures_sha256':hashlib.sha256(binary).hexdigest(),'binary_unchanged':True})
    report['assets'][key]['bytes']=len(updated);report['assets'][key]['sha256']=hashlib.sha256(updated).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art-source/signal-in-the-dust.blend'))
for m in bpy.data.materials:
    if m.name.startswith('basalt vertex strata'):m.name='basalt vertex strata-vcol'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source/signal-in-the-dust.blend'))
report['blend_sha256']=hashlib.sha256((ROOT/'art-source/signal-in-the-dust.blend').read_bytes()).hexdigest()
report['script_sha256']=hashlib.sha256((ROOT/'art-source/build_assets.py').read_bytes()).hexdigest()
report['total_glb_bytes']=sum(a['bytes'] for a in report['assets'].values())
report['payload_bytes_including_external_source_textures']=report['total_glb_bytes']+sum(t['bytes'] for t in report['texture_sources'])
report['godot_material_repair']={'cause':'Godot 4.7.2 imported basalt COLOR_0 arrays but set vertex_color_use_as_albedo=false, leaving white fallback albedo. Native override experiment restores basalt.','source':'https://github.com/godotengine/godot/issues/120625','fix':'Documented -vcol material suffix; Compatibility renderer ignores vertex_color_is_srgb.','changes':changes,'native_after_status':'PENDING'}
rep_path.write_text(json.dumps(report,indent=2),encoding='utf-8')
(EVID/'repair.json').write_text(json.dumps(report['godot_material_repair'],indent=2),encoding='utf-8')
print('ASSET_MATERIAL_SUFFIX_APPLIED')
