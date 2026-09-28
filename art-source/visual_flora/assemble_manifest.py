"""Bind delivered assets, source, offline evidence and limits into one receipt."""
import json, hashlib, datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'art-source/visual_flora'
OUT=ROOT/'godot/assets/visual_flora'
EVIDENCE=ROOT/'evidence/visual-upgrade-20260923/flora-authoring'
FAMILIES=['canopy','sails','pods','cups','mat','spores']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def item(p):return {'path':str(p.relative_to(ROOT)).replace('\\','/'),'bytes':p.stat().st_size,'sha256':sha(p)}
audit=json.loads((EVIDENCE/'glb-structural-audit.json').read_text(encoding='utf8'))
assert audit['status']=='STRUCTURAL_READBACK_PASS'
blend=json.loads((EVIDENCE/'blend-readback.json').read_text(encoding='utf8'))
bound={a['family']:a for a in blend['assets']}
descriptions={
 'canopy':'Asymmetric paired load arches, subsoil buttress roots, layered mineral scales, broad front/rear vascular membrane cowls, connecting vaulted roof, lateral perch and pendant epiphytes.',
 'sails':'Three staggered curved pleated blades, thick outer edge, firm raised ribs, vascular PBR tissue, planted root holdfasts, beaded condensation and sparse cyan axils.',
 'pods':'Crooked thick branching shrub with eight nonuniform fruits: green closed, waxy ripe with local amber fissures, and physically open valves exposing seeds. Shed husks connect it to the ground.',
 'cups':'Three asymmetric concave folded bowls with shared physical inner/outer shell, thick lip, lowered drainage channel, exterior support veins and distinct dark rooted pads.',
 'mat':'Irregular low root/fibre network with linked lace islands, granular mineral pockets, nutrient films, sparse nodes and actual bare gaps. No rectangle/ground card.',
 'spores':'Overlapping inclined fan/accordion growths on a decaying mineral root, genuinely perforated hard crust, pale deep lamellae, mineralized lips and sparse rim organs.'}
assets=[]
for name in FAMILIES:
    high=json.loads((OUT/(name+'.manifest.json')).read_text(encoding='utf8'))
    low=json.loads((OUT/(name+'_lod1.manifest.json')).read_text(encoding='utf8'))
    render=json.loads((EVIDENCE/(name+'-render.json')).read_text(encoding='utf8'))
    assert high['sourceScriptSha256']==sha(SOURCE/'build_flora.py')
    assert high['sha256']==sha(OUT/(name+'.glb'))==render['sourceSha256']==low['sourceGlbSha256']
    assert high['sourceBlendSha256']==bound[name]['sha256']==sha(SOURCE/(name+'.blend'))
    assert {'front','side','back','night'}<={a['view'] for a in render['images']}
    assert all(not a['emissionEnabled'] for a in render['images'] if a['view']!='night')
    assets.append({'family':name,'description':descriptions[name],'high':high,'distant':low,
                   'source':item(SOURCE/(name+'.blend')),'renderEvidence':item(EVIDENCE/(name+'-render.json')),
                   'images':[item(EVIDENCE/a['file']) for a in render['images']]})
record={'createdAtUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'truthLabel':'STRUCTURAL_READBACK_PASS / OFFLINE_MULTIANGLE_RENDERED / RUNTIME_AND_INDEPENDENT_ART_REVIEW_PENDING',
 'notClaimed':['Godot import/export/build','Web/Compatibility transparency','Actual terrain contact or collider clearance','Animation','Runtime performance','90 percent concept match','Final human acceptance'],
 'tool':{'path':'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe','version':'5.2.1 LTS','build':'9e2066aef7ef'},
 'scope':['art-source/visual_flora/','godot/assets/visual_flora/','evidence/visual-upgrade-20260923/flora-authoring/'],
 'sources':[item(p) for p in sorted(SOURCE.glob('*.py'))]+[item(SOURCE/'README.md')],
 'textures':[item(p) for p in sorted((OUT/'textures').glob('*.png'))],
 'license':'Original project-authored procedural geometry and raster PBR maps. No external mesh/photographic texture/addon, network or paid generation used. Project concept images are reference only and are not embedded.',
 'integration':{'units':'metres','axis':'glTF/Godot Y up; authoring Blender Z up','pivot':'terrain-contact origin, never lift to minimum bounds',
    'subsoil':'Negative root geometry is deliberately below origin. Root pads require local terrain grounding by runtime owner.',
    'alpha':'Only sail_tissue uses BLEND at alpha 0.94. All other surfaces are opaque. Sails require actual Compatibility sorting/overdraw check.',
    'materials':'Standard glTF metallic/roughness with sRGB albedo/emission, non-color roughness and OpenGL tangent normals; embedded PNGs.',
    'perchGodotLocal':'Load-bearing side branch runs approximately x -4.8 to 4.4, y 13.2 to 15.2, z 0.6 to 1.6. Runtime owner must check actual actor feet and collision support.',
    'lod':'Distant forms consolidate by material and preserve static silhouette, not high-form per-organ animation hierarchy. Determine switching thresholds from actual scene profile.',
    'instancing':'Reuse imported PackedScenes/meshes and shared materials. Test high/distant texture deduplication; embedded texture copies can dominate memory and downloads.'},
 'assets':assets,
 'evidence':{'binaryAudit':item(EVIDENCE/'glb-structural-audit.json'),'nativeReadback':item(EVIDENCE/'blend-readback.json'),
             'neutralNightSheet':item(EVIDENCE/'neutral-night-contact.png'),'multiViewSheet':item(EVIDENCE/'neutral-multiview-contact.png')},
 'remainingArtGaps':['Concept-level weathering, eroded hollows and fine moist microstructure remain richer than this authored kit.',
    'Tissue uses standard alpha/opaque PBR, not physical subsurface/transmission. It needs target renderer lighting calibration.',
    'Mat has a local flat contact footprint; conforming to real rock fractures requires scene placement/deformation, not blanket scattering.',
    'Small pores, root overlays and repeated anatomy may simplify in distant forms. Final LOD distance and instancing decisions require actual Godot profile.',
    'Offline blue-violet night studies prove the asset shape/material read in that setup; they do not prove the real game atmosphere or final reference similarity.']}
(OUT/'kit.manifest.json').write_text(json.dumps(record,indent=2),encoding='utf8')
(EVIDENCE/'delivery-receipt.json').write_text(json.dumps(record,indent=2),encoding='utf8')
print(record['truthLabel'])
for a in assets:
    h=a['high'];l=a['distant'];s=h['boundsBlenderXYZ']['size']
    print(a['family'],h['triangles'],l['triangles'],h['bytes'],l['bytes'],'metres',*[round(v,2) for v in s])
