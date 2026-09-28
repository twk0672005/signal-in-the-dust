"""Bind final GLBs to their exact source/readback/render and comparison evidence."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,datetime
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'evidence/visual-upgrade-20260923/flora-authoring/revision-b'
SOURCE=ROOT/'art-source/visual_flora/revision-b'
ASSETS=ROOT/'godot/assets/visual_flora/revision-b'
REF=Path('C:/Users/tsang/DeepSpaceRover/deep-space-rover-three-20260906/evidence/visual-upgrade-20260923/creatures/flora-habitat-v1.png')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def file(p):return {'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p)}
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',22)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',17)
for views,name in [(['front','night'],'neutral-night-contact'),(['front','side','back'],'neutral-multiview-contact')]:
    c=440;header=86;rh=c+42
    contact=Image.new('RGB',(c*len(views),header+2*rh+60),'#18212b');d=ImageDraw.Draw(contact)
    d.text((18,12),'CANOPY + SAIL / REVISION B',font=font,fill='#eee7d7')
    d.text((18,48),'Actual exported GLB reimports / neutral emission OFF / independent review pending',font=small,fill='#c0cbd3')
    for row,family in enumerate(('canopy','sails')):
        for col,view in enumerate(views):
            img=Image.open(OUT/(family+'-'+view+'.png')).convert('RGB');img.thumbnail((c,c))
            xx=col*c;yy=header+row*rh;contact.paste(img,(xx,yy));d.text((xx+10,yy+c+7),family.upper()+' / '+view.upper(),font=small,fill='#dce1e6')
    d.text((18,contact.height-40),'Offline candidate only. No Godot, MCP scene integration or world-expansion approval.',font=small,fill='#b8bec6')
    contact.save(OUT/(name+'.png'))
ref=Image.open(REF).convert('RGB');w,h=ref.size
cell=480;head=90;row=cell+44
sheet=Image.new('RGB',(cell*4,head+row*2+68),'#18212b');draw=ImageDraw.Draw(sheet)
draw.text((18,12),'CANOPY + SAIL / STRUCTURAL RECONSTRUCTION',font=font,fill='#eee7d7')
draw.text((18,48),'Concept panels 1/2 versus actual reimported GLB. Neutral light; emission OFF. Different camera/scale, no numerical similarity claim.',font=small,fill='#c0cbd3')
for y,name in enumerate(('canopy','sails')):
    crop=ref.crop((y*w//3,0,(y+1)*w//3,h//2))
    images=[crop]+[Image.open(OUT/(name+'-'+view+'.png')).convert('RGB') for view in ('front','support_detail','tissue_detail')]
    labels=['PROJECT CONCEPT / REFERENCE ONLY','EXPORTED GLB / FULL FORM','EXPORTED GLB / ROOT + SUPPORT','EXPORTED GLB / TISSUE + RIBS']
    for x,(img,label) in enumerate(zip(images,labels)):
        img.thumbnail((cell,cell));px=x*cell;py=head+y*row
        sheet.paste(img,(px+(cell-img.width)//2,py+(cell-img.height)//2));draw.text((px+10,py+cell+8),label,font=small,fill='#dce1e6')
draw.text((18,sheet.height-45),'Candidate only. World expansion remains NO-SHIP until fresh independent art review. No Godot/MCP scene integration.',font=small,fill='#b8bec6')
sheet.save(OUT/'reference-comparison.png')
baseline=json.loads((OUT/'preserved-baseline.json').read_text(encoding='utf-8-sig'))
unchanged=all(sha(Path(v['path'])).lower()==v['sha256'].lower() for v in baseline)
assert unchanged
audit=json.loads((OUT/'glb-structural-audit.json').read_text(encoding='utf8'))
native=json.loads((OUT/'source-readback.json').read_text(encoding='utf8'))
assert audit['status']=='STRUCTURAL_READBACK_PASS'
sources={v['family']:v for v in native['assets']}
assets=[]
for name in ('canopy','sails'):
    m=json.loads((ASSETS/(name+'.manifest.json')).read_text(encoding='utf8'))
    r=json.loads((OUT/(name+'-render.json')).read_text(encoding='utf8'))
    assert m['sha256']==r['sourceSha256']==sha(ASSETS/(name+'.glb'))
    assert m['sourceBlendSha256']==sources[name]['sha256']==sha(SOURCE/(name+'.blend'))
    assert m['scriptSha256']==sha(SOURCE/'build_structural_revision.py')
    assert {'front','side','back','night','support_detail','tissue_detail'}=={v['view'] for v in r['images']}
    for v in r['images']:assert v['sha256']==sha(OUT/v['file'])
    assets.append({'name':name,'model':m,'sourceReadback':sources[name],'render':r})
receipt={'timestampUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'status':'STRUCTURAL_READBACK_PASS; OFFLINE_EXPORTED_GLB_IMAGES_COMPLETE; INDEPENDENT_ART_REVIEW_PENDING',
 'worldExpansionVerdict':'NO-SHIP pending fresh independent review; helper does not approve its own art.',
 'scope':'Only one reconstructed canopy and one representative sail. No other family or runtime change.',
 'preservedBaselineFiles':len(baseline),'baselineHashesUnchanged':unchanged,
 'constructionChange':'Fused volumetric root/branch scaffold replaces overlapping tube columns and separate bark flakes; tensioned thin tissue between curved load rays replaces inflated parallel pleats.',
 'blender':'5.2.1 LTS, build 9e2066aef7ef','assets':assets,
 'sourceScripts':[file(SOURCE/p) for p in ['build_structural_revision.py','render_revision.py','audit_revision.py','readback_revision.py','assemble_review.py']],
 'textures':[file(p) for p in sorted((ASSETS/'textures').glob('*.png'))],
 'evidence':[file(OUT/p) for p in ['reference-comparison.png','neutral-night-contact.png','neutral-multiview-contact.png','glb-structural-audit.json','source-readback.json']],
 'viewConvention':'Full front/side/back/night are perspective 50 mm; close support/tissue views are orthographic. Any orthoScale stored on perspective views is an inactive camera property.',
 'notClaimed':['Godot import or render','MCP scene operation','Runtime performance','Final terrain collision/support','Animated wind','Numerical concept fidelity','Final art acceptance'],
 'provenance':'Original local geometry and raster PBR generation. Source preserves both pre-fusion base and fused sculpt outside GLB selection. No external asset, paid provider or new installation.'}
(OUT/'revision-receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf8')
(ASSETS/'revision.manifest.json').write_text(json.dumps(receipt,indent=2),encoding='utf8')
print(receipt['status'])
print('BASELINE_UNCHANGED',len(baseline))
