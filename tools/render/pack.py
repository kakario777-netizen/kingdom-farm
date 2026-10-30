# out/*.png → game/sprites/sheetN.webp + atlas.js (게임이 읽는 그림 묶음)
import json,os
from PIL import Image
OUT='tools/render/out';DST='game/sprites';os.makedirs(DST,exist_ok=True)
meta=json.load(open(OUT+'/meta.json'))
items=[(k,Image.open(f'{OUT}/{k}.png')) for k in meta if os.path.exists(f'{OUT}/{k}.png')]
items.sort(key=lambda kv:-kv[1].height)
SZ=4096;sheets=[];atlas={};lo={}
cur=None;x=y=rowh=0
def new():
    global cur,x,y,rowh
    cur=Image.new('RGBA',(SZ,SZ),(0,0,0,0));sheets.append(cur);x=y=rowh=0
def place(lst,dst,div):
    global x,y,rowh
    new()
    for k,im in lst:
        if div>1:im=im.resize((max(1,round(im.width/div)),max(1,round(im.height/div))),Image.LANCZOS)
        w,h=im.size
        if x+w>SZ:x=0;y+=rowh+2;rowh=0
        if y+h>SZ:new()
        cur.paste(im,(x,y));m=meta[k]
        dst[k]=[len(sheets)-1,x,y,w,h,round(m['ax']/div,1),round(m['ay']/div,1),round(m['res']/div,3)]
        x+=w+2;rowh=max(rowh,h)
place(items,atlas,1)
# 멀리서 볼 때 쓸 절반 크기 묶음(밉맵) — 해상도 배수 2 이상으로 그렸을 때만
if max(meta[k]['res'] for k,_ in items)>=5: place(items,lo,2)
names=[]
for n,s in enumerate(sheets):
    bb=s.getbbox();s=s.crop((0,0,SZ,bb[3]+1)) if bb else s
    f=f'sheet{n}.webp';s.save(f'{DST}/{f}','WEBP',quality=88,method=6);names.append(f)
open(f'{DST}/atlas.js','w').write('window.ATLAS='+json.dumps({'sheets':names,'s':atlas,'lo':lo},separators=(',',':'))+';')
print(len(atlas),'sprites',[(f,os.path.getsize(f'{DST}/{f}')//1024) for f in names])
