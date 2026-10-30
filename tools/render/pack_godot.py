# out/*.png → godot/sprites/sheetN.png + atlas.json (고도용: 밉맵 번짐 막으려 여백 16px)
import json,os
from PIL import Image
OUT='tools/render/out';DST='godot/sprites';os.makedirs(DST,exist_ok=True)
meta=json.load(open(OUT+'/meta.json'))
items=[(k,Image.open(f'{OUT}/{k}.png')) for k in meta if os.path.exists(f'{OUT}/{k}.png') and not k.startswith('pv_')]
items.sort(key=lambda kv:-kv[1].height)
SZ=4096;PAD=16;sheets=[];atlas={}
cur=None;x=y=rowh=0
def new():
    global cur,x,y,rowh
    cur=Image.new('RGBA',(SZ,SZ),(0,0,0,0));sheets.append(cur);x=y=PAD;rowh=0
new()
for k,im in items:
    w,h=im.size
    if x+w+PAD>SZ:x=PAD;y+=rowh+PAD;rowh=0
    if y+h+PAD>SZ:new()
    cur.paste(im,(x,y));m=meta[k]
    atlas[k]=[len(sheets)-1,x,y,w,h,round(m['ax'],1),round(m['ay'],1),m['res']]
    x+=w+PAD;rowh=max(rowh,h)
for f in os.listdir(DST):
    if f.startswith('sheet') and f.endswith('.png'):os.remove(f'{DST}/{f}')
names=[]
for n,s in enumerate(sheets):
    f=f'sheet{n}.png';s.save(f'{DST}/{f}',optimize=True);names.append(f)
json.dump({'sheets':names,'s':atlas},open(f'{DST}/atlas.json','w'),separators=(',',':'))
print(len(atlas),'sprites',[(f,os.path.getsize(f'{DST}/{f}')//1024) for f in names])
