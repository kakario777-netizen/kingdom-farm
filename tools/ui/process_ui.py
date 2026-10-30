# Kenney UI Pack · RPG 확장 · 게임 아이콘(CC0) → 말랑 왕국 UI 이미지로 가공
# 색 바꾸기(색조·밝기), 갈색 테두리, 눌림 상태, 아이콘 외곽선
import numpy as np, os
from PIL import Image, ImageFilter
A='assets-src/';D='game/ui/';os.makedirs(D,exist_ok=True)
INK=(107,65,40)
def rgb2hsv(a):
    r,g,b=a[...,0],a[...,1],a[...,2];mx=a[...,:3].max(-1);mn=a[...,:3].min(-1);d=mx-mn+1e-9
    h=np.where(mx==r,((g-b)/d)%6,np.where(mx==g,(b-r)/d+2,(r-g)/d+4))/6;s=np.where(mx>0,d/(mx+1e-9),0);return h,s,mx
def hsv2rgb(h,s,v):
    i=np.floor(h*6)%6;f=h*6-np.floor(h*6);p=v*(1-s);q=v*(1-f*s);t=v*(1-(1-f)*s)
    r=np.choose(i.astype(int),[v,q,p,p,t,v]);g=np.choose(i.astype(int),[t,v,v,q,p,p]);b=np.choose(i.astype(int),[p,p,t,v,v,q]);return np.stack([r,g,b],-1)
def recolor(im,hue=None,sat=1,val=1,shift=0):
    a=np.asarray(im).astype(float)/255;h,s,v=rgb2hsv(a)
    if hue is not None:h=np.full_like(h,hue/360)
    h=(h+shift/360)%1;s=np.clip(s*sat,0,1);v=np.clip(v*val,0,1)
    out=np.concatenate([hsv2rgb(h,s,v),a[...,3:]],-1);return Image.fromarray((out*255).astype(np.uint8),'RGBA')
def outline(im,w=3,col=INK,pad=4):
    big=Image.new('RGBA',(im.width+pad*2,im.height+pad*2),(0,0,0,0));big.paste(im,(pad,pad))
    al=big.split()[3].point(lambda v:255 if v>100 else 0).filter(ImageFilter.MaxFilter(w*2+1))
    ol=Image.new('RGBA',big.size,col+(255,));ol.putalpha(al);ol.alpha_composite(big);return ol
def L(p):return Image.open(A+p).convert('RGBA')
UP='ui-pack/PNG/'
# 버튼 (깊이 있는 광택 버튼 / 눌림 = 깊이 없는 광택)
BTN={'yellow':('Yellow',None,1,1),'pink':('Red',338,.62,1.08),'mint':('Green',158,.75,1.05),'white':('Grey',36,.12,1.04),'purple':('Blue',262,.6,1.0),'red':('Red',None,1,1)}
for name,(src,hue,sat,val) in BTN.items():
    for kind,fn in [('','button_rectangle_depth_gloss'),('_down','button_rectangle_gloss')]:
        im=L(f'{UP}{src}/Default/{fn}.png')
        if kind=='_down':c=Image.new('RGBA',(192,64));c.paste(im,(0,64-im.height));im=c
        if hue is not None:im=recolor(im,hue,sat,val)
        outline(im,3).save(f'{D}btn_{name}{kind}.png')
    r=L(f'{UP}{src}/Default/button_round_depth_gloss.png');r=recolor(r,hue,sat,val) if hue is not None else r;outline(r,3).save(f'{D}round_{name}.png')
# 판넬(양피지) — 따뜻한 크림색으로
for name,src,sh,sat,val in [('panel','ui-rpg/PNG/panel_beigeLight.png',0,1.05,1.06),('panel_dark','ui-rpg/PNG/panel_beige.png',0,1.1,1.05),('inset','ui-rpg/PNG/panelInset_beigeLight.png' if os.path.exists(A+'ui-rpg/PNG/panelInset_beigeLight.png') else 'ui-rpg/PNG/panelInset_beige.png',0,.9,1.1),('wood','ui-rpg/PNG/panel_brown.png',0,1.1,1.05)]:
    outline(recolor(L(src),shift=sh,sat=sat,val=val),3).save(f'{D}{name}.png')
# 진행 막대
for name,src in [('bar_back','barBack_horizontal'),('bar_green','barGreen_horizontal'),('bar_yellow','barYellow_horizontal')]:
    parts=[L(f'ui-rpg/PNG/{src}{s}.png') for s in ('Left','Mid','Right')]
    w=parts[0].width+parts[1].width*4+parts[2].width;c=Image.new('RGBA',(w,18));x=0
    for p in [parts[0]]+[parts[1]]*4+[parts[2]]:c.paste(p,(x,0));x+=p.width
    c.save(f'{D}{name}.png')
# 별(레벨)
outline(L(f'{UP}Yellow/Default/star.png'),3).save(f'{D}star.png')
# 아이콘: 흰 아이콘 + 갈색 외곽선
GI='game-icons/Game icons (base)/PNG/White/2x/';GX='game-icons/PNG/White/2x/'
for name,src in {'shop':GI+'shoppingBasket.png','wrench':GI+'wrench.png','zin':GI+'zoomIn.png','zout':GI+'zoomOut.png','zfit':GI+'zoomDefault.png','close':GI+'cross.png','trophy':GI+'trophy.png','home':GI+'home.png','check':GI+'checkmark.png','star_i':GI+'star.png','next':GI+'next.png','gear':GI+'gear.png','basket2':GI+'shoppingCart.png','coin_i':GX+'coin.png','gem_i':GX+'diamond.png','flag_i':GX+'flag.png'}.items():
    im=L(src);outline(im,4,col=(74,44,28)).save(f'{D}ic_{name}.png')
print(sorted(os.listdir(D)))
