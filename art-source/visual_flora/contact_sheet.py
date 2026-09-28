"""Assemble unaltered offline inspection renders. Labels are evidence metadata."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import argparse
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'evidence/visual-upgrade-20260923/flora-authoring'
p=argparse.ArgumentParser();p.add_argument('--families',default='canopy,sails,pods,cups,mat,spores');p.add_argument('--views',default='front,night');p.add_argument('--name',default='neutral-night-contact');p.add_argument('--directory',default='.')
a=p.parse_args();folder=BASE/a.directory
families=a.families.split(',');views=a.views.split(',')
cell=440;header=94;foot=64
sheet=Image.new('RGB',(cell*len(views),header+len(families)*(cell+42)+foot),'#19212b')
d=ImageDraw.Draw(sheet);font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',23);small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',16)
d.text((18,14),'SIGNAL IN THE DUST / SIX FLORA FAMILIES',font=font,fill='#e7e4dc')
d.text((18,48),'Actual reimported GLB / offline Cycles / emission OFF in neutral views',font=small,fill='#adc2d3')
for j,f in enumerate(families):
    for i,v in enumerate(views):
        img=Image.open(folder/(f+'-'+v+'.png')).convert('RGB');img.thumbnail((cell,cell))
        x=i*cell;y=header+j*(cell+42)
        sheet.paste(img,(x,y));d.text((x+13,y+cell+6),f.upper()+' / '+v.upper(),font=small,fill='#cfdae2')
d.text((18,sheet.height-foot+12),'Original local geometry/PBR. Candidate only: Godot/Web & independent art review pending.',font=small,fill='#a5aeb9')
sheet.save(folder/(a.name+'.png'))
print(folder/(a.name+'.png'))
