"""Assemble original Blender renders; no image edits or generated image service."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'evidence/assets'
sheet=Image.new('RGB',(1600,1320),'#111820')
draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',25)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
draw.text((34,20),'SIGNAL IN THE DUST / AUTHORED ASSET STUDIES',font=font,fill='#eee6d6')
for i,(file,title) in enumerate([('rover-front','01 / FIELD ROVER - FRONT'),('rover-rear','02 / ROCKER BOGIE - REAR'),('signal','03 / LISTENING BASALT - 8 RIBS'),('rocks','04 / WEATHERED BASALT FAMILY')]):
    image=Image.open(out/(file+'.png')).convert('RGB').resize((780,585))
    x=10+(i%2)*800;y=70+(i//2)*620
    sheet.paste(image,(x,y));draw.text((x+15,y+590),title,font=small,fill='#bfc9d5')
draw.text((25,1300),'Blender 5.2.1 LTS / original local geometry / asset candidates - runtime approval pending',font=small,fill='#83919e')
sheet.save(out/'contact-sheet.png')
