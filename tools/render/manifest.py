# 3D 모델 → 게임 스프라이트 목록 (모두 CC0 에셋)
import json
MV='../../assets-src/medieval-village/Medieval Village Pack - Dec 2020/'
B=MV+'Buildings/OBJ/';PR=MV+'Props/OBJ/'
NK='../../assets-src/nature-kit/Models/GLTF format/'
CK='../../assets-src/castle-kit/Models/GLB format/'
FT='../../assets-src/fantasy-town/Models/GLB format/'
MC='../../assets-src/mini-characters/Models/GLB format/'
L=[]
def add(i,parts,**kw):L.append(dict(id=i,parts=parts,**kw))
def bld(i,model,fit=.95,**rc):add(i,[{'src':B+model+'.obj','recolor':rc}],fit=fit)
R='RoofTiles';RR='RoofTiles_Red'
# 집·가게
bld('cottage_o','House_1',**{R:'#ff8a3c'})
bld('cottage_b','House_2',**{R:'#9a5f3a','Beige':'#ead3b2'})
bld('cottage_s','House_1',**{R:'#f2cf5b','Plaster':'#fff8ea'})
bld('tailor','House_2',**{R:'#a678e8','Beige':'#fff0fa'})
bld('school','Bell_Tower',.85,**{R:'#3f6fb0'})
bld('lumber','Sawmill')
bld('guild','Inn',**{RR:'#d94a44'})
bld('bakery','House_2',**{R:'#ff8fb5','Beige':'#fff1e6'})
add('hotdog',[{'src':PR+'MarketStand_1.obj','recolor':{RR:'#ffa630'}},{'src':PR+'Barrel.obj','pos':[.9,0,.7],'scale':.8},{'src':PR+'Crate.obj','pos':[-.9,0,.8],'scale':.7}],fit=.9)
bld('smith','Blacksmith')
bld('stables','Stable')
bld('cobbler','House_1',**{R:'#3fbf98'})
bld('tavern','Inn',**{RR:'#c9773f'})
bld('candle','House_2',**{R:'#ff6f9f','Beige':'#ffe6ee'})
bld('jewelry','House_1',**{R:'#4fb0f0','Plaster':'#eef6ff'})
add('emporium',[{'stack':[CK+'tower-hexagon-base.glb',CK+'tower-hexagon-mid.glb',CK+'tower-hexagon-roof.glb'],'pos':[0,0],'tint':'#e6d8ff'}],fit=.7)
# 특수 건물
bld('windmill','Mill')
add('wizard',[{'stack':[CK+'tower-hexagon-base.glb',CK+'tower-hexagon-mid.glb',CK+'tower-hexagon-mid.glb',CK+'tower-hexagon-roof.glb'],'pos':[0,0],'tint':'#d8c8ff'}],fit=.62)
add('watch',[{'stack':[CK+'tower-square-base.glb',CK+'tower-square-mid-windows.glb',CK+'tower-square-mid.glb',CK+'tower-square-top-roof-high.glb'],'pos':[0,0]}],fit=.6)
add('barn',[{'src':B+'Stable.obj','recolor':{R:'#8a3a35','Beige':'#e8554e'}},{'src':PR+'Hay.obj','pos':[1.6,0,1.4],'scale':1.2}],fit=.95)
add('quarry',[{'src':NK+'stone_largeA.glb','pos':[-.2,0,-.1]},{'src':NK+'stone_largeC.glb','pos':[.25,0,-.2]},{'src':NK+'stone_tallB.glb','pos':[0,0,-.35],'scale':.9},{'src':PR+'Crate.obj','pos':[.3,0,.35],'scale':.18},{'src':NK+'stone_smallA.glb','pos':[-.3,0,.3]},{'src':NK+'log_stack.glb','pos':[-.35,0,.05],'scale':.6}],fit=.9)
# 장식
for k,m in {'pine':'tree_pineRoundA','fir':'tree_pineTallA_detailed','oak':'tree_oak','ash':'tree_default','maple':'tree_oak_fall','firefly':'tree_fat_darkh','willow':'tree_detailed'}.items():
    add(k,[{'src':NK+m+'.glb'}],fit=.72)
def bed(k,fl):
    pos=[(-.17,-.15),(.15,-.17),(0,.02),(-.16,.17),(.17,.15),(.02,-.2),(-.2,0),(.2,0)]
    add(k,[{'src':NK+'crops_dirtSingle.glb','pos':[0,0,0],'scale':.7}]+[{'src':NK+fl[n%len(fl)]+'.glb','pos':[x,0,z],'scale':.8,'rotY':n*47} for n,(x,z) in enumerate(pos)],fit=.82)
bed('tulip',['flower_redA','flower_yellowB','flower_purpleC'])
bed('rose',['flower_redA','flower_redB','flower_redC'])
bed('lily',['flower_yellowA','flower_yellowB','flower_yellowC'])
bed('orchid',['flower_purpleA','flower_purpleB','flower_purpleC'])
add('lamp',[{'src':FT+'lantern.glb'}],height=1.0)
add('banner',[{'src':CK+'flag-banner-long.glb'}],height=1.1)
add('mailbox',[{'src':PR+'Well.obj'}],fit=.65)
add('picnic',[{'src':PR+'Gazebo.obj'}],fit=.8)
add('fountain',[{'src':FT+'fountain-round-detail.glb'}],fit=.85)
for k,m in {'st_knight':'statue_head','st_teacher':'statue_column','st_wizard':'statue_obelisk','st_dragon':'statue_ring'}.items():
    add(k,[{'src':NK+m+'.glb'}],fit=.55)
# 야생
for k,m in {'wpine':'tree_pineRoundB','woak':'tree_default_dark','wrock':'stone_largeB','wbush':'plant_bushLarge','wpine2':'tree_pineSmallC','woak2':'tree_small','wlog':'log_stackLarge','wmush':'mushroom_redGroup'}.items():
    add(k,[{'src':NK+m+'.glb'}],fit=.6 if k[1]!='r' else .5)
# 작물: 한 칸에 네 포기
P4=[(-.22,-.22),(.22,-.22),(-.22,.22),(.22,.22)]
def crop(k,s1,s2,rc1=None,rc2=None,extra2=None):
    for st,(m,rc) in {1:(s1,rc1),2:(s2,rc2)}.items():
        parts=[]
        for (x,z) in P4:
            parts.append({'src':NK+m+'.glb','pos':[x,0,z],'scale':.42,'recolor':rc or {}})
            if st==2 and extra2:parts.append({'src':NK+extra2[0]+'.glb','pos':[x+.06,0,z+.06],'scale':.3,'recolor':extra2[1]})
        add(f'crop_{k}_{st}',parts,noCenter=True)
add('crop_sprout',[{'src':NK+'crops_leafsStageA.glb','pos':[x,0,z],'scale':.3} for x,z in P4],noCenter=True)
add('plot',[{'src':NK+'crops_dirtDoubleRow.glb','scale':.5}],fit=.92,noShadow=True)
crop('corn','crops_cornStageB','crops_cornStageD')
crop('wheat','crops_wheatStageA','crops_wheatStageB')
crop('oats','crops_wheatStageA','crops_wheatStageB',rc2={'corn':'#f3e2b0','colorYellow':'#f3e2b0'})
crop('rice','crops_wheatStageA','crops_wheatStageB',rc2={'corn':'#eef2c0','colorYellow':'#eef2c0'})
crop('carrot','crops_leafsStageA','crop_carrot')
crop('onion','crops_leafsStageA','crop_turnip',rc2={'stone':'#c98ce8','colorWhite':'#c98ce8'})
crop('radish','crops_leafsStageA','crop_turnip',rc2={'stone':'#ff7fa8','colorWhite':'#ff7fa8'})
crop('potato','crops_leafsStageA','crop_turnip',rc2={'stone':'#c99a5b','colorWhite':'#c99a5b'})
crop('pumpkin','crops_leafsStageB','crop_pumpkin')
crop('squash','crops_leafsStageB','crop_pumpkin',rc2={'colorTan':'#b8dc5a'})
crop('melon','crops_leafsStageB','crop_melon')
crop('pineapple','crops_leafsStageB','crop_pumpkin',rc2={'colorTan':'#ffcf3c'})
for k,col in {'berry':'flower_redC','tomato':'flower_redA','peppers':'flower_redB','eggplant':'flower_purpleA','cotton':'flower_yellowA'}.items():
    crop(k,'crops_leafsStageA','crops_leafsStageB',extra2=(col,{'colorYellow':'#ffffff'} if k=='cotton' else {}))
for k,col in {'lettuce':'#a6e67e','broccoli':'#3fa34d','cauliflower':'#f0e6ff','artichoke':'#7cc78a'}.items():
    crop(k,'crops_leafsStageA','crops_leafsStageB',rc2={'leafsGreen':col,'grass':col})
for k in ['beans','peas','asparagus']:
    crop(k,'crops_bambooStageA','crops_bambooStageB',rc1={'grass':'#7fd45a','leafsGreen':'#7fd45a'},rc2={'grass':'#6cc04a','leafsGreen':'#6cc04a'})
# 성 4단계 (Castle Kit 조립)
def castle(tier):
    corner='tower-hexagon' if tier>=3 else 'tower-square'
    mids={1:1,2:2,3:2,4:3}[tier]
    cs=[CK+f'{corner}-base.glb']+[CK+(f'{corner}-mid.glb')]*mids+[CK+(f'{corner}-roof.glb' if corner=='tower-hexagon' else 'tower-square-top-roof.glb')]
    parts=[{'stack':cs,'pos':[x,z],'scale':1.35 if corner=='tower-hexagon' else 1} for x in(-1.1,1.1) for z in(-1.1,1.1)]
    keep=[CK+'tower-square-base-color.glb',CK+'tower-square-mid-windows.glb']+[CK+'tower-square-mid.glb']*(tier-1)+[CK+('tower-square-top-roof-high-windows.glb' if tier>=2 else 'tower-square-top-roof-high.glb')]
    parts.append({'stack':keep,'pos':[0,-.1],'scale':1.35})
    for (x,z,r) in [(0,-1.1,0),(0,1.1,0),(-1.1,0,90),(1.1,0,90)]:
        parts.append({'src':CK+('gate.glb' if (x,z)==(0,1.1) else 'wall.glb'),'pos':[x,0,z],'rotY':r})
    if tier>=4:parts+= [{'src':CK+'flag-banner-long.glb','pos':[-.55,0,1.25]},{'src':CK+'flag-banner-long.glb','pos':[.55,0,1.25]}]
    add(f'castle{tier}',parts,fit=1.9,W=1500,H=1700,Ha=1350)
for t in (1,2,3,4):castle(t)
# 연못·그리핀 둥지·드래곤 굴 (네이처 키트 조각 조립)
add('pond',[{'src':NK+'ground_riverOpen.glb'},{'src':NK+'lily_large.glb','pos':[-0.15, 0.02, 0.1],'scale':0.9},{'src':NK+'lily_small.glb','pos':[0.2, 0.02, -0.1]},{'src':NK+'lily_small.glb','pos':[0.05, 0.02, 0.25],'rotY':60},{'src':NK+'stone_smallA.glb','pos':[0.42, 0, 0.3]},{'src':NK+'stone_smallC.glb','pos':[-0.4, 0, -0.35]},{'src':NK+'plant_bushSmall.glb','pos':[0.4, 0, -0.4]},{'src':NK+'log.glb','pos':[-0.42, 0, 0.38],'scale':0.8,'rotY':30}],fit=0.95)
add('griffin',[{'src':NK+'stone_tallA.glb','pos':[0, 0, 0],'scale':1.2},{'src':NK+'stone_tallB.glb','pos':[0.3, 0, 0.25],'scale':0.9},{'src':NK+'campfire_logs.glb','pos':[-0.25, 0, 0.3],'scale':1.0},{'src':NK+'plant_bush.glb','pos':[-0.35, 0, -0.2]},{'src':NK+'stone_smallB.glb','pos':[0.35, 0, -0.3]}],fit=0.8)
add('dragon',[{'src':NK+'cliff_cave_stone.glb','scale':1.0},{'src':NK+'campfire_stones.glb','pos':[0.15, 0, 0.55],'scale':0.8},{'src':NK+'stone_largeA.glb','pos':[-0.5, 0, 0.4],'scale':0.6},{'src':NK+'mushroom_redGroup.glb','pos':[0.5, 0, 0.45]}],fit=0.9)
json.dump(L,open('tools/render/static.json','w'),ensure_ascii=False,indent=0)
# 캐릭터: 오른쪽아래(dr)·오른쪽위(ur) 방향, 걷기 8·쉬기 2·인사 4
C={}
for key,model in {'farmer':'male-f','baker':'female-b','knight':'male-c','maid':'female-e','wizard':'female-a','merchant':'male-d','girl':'female-f','grandpa':'male-b','catkid':'female-c','bookworm':'male-a','carpenter':'male-e','laundry':'female-d'}.items():
    for d,rot in {'dr':90,'ur':180}.items():
        for anim,n in {'walk':8,'idle':2,'emote-yes':4}.items():
            for f in range(n):
                C.setdefault('list',[]).append(dict(id=f'ch_{key}_{d}_{anim}{f}',parts=[{'src':MC+f'character-{model}.glb'}],noCenter=True,anim={'clip':anim,'t':f/n},rotY=rot,height=.62,res=2.5,W=400,H=420,Ha=360,outline=3))

json.dump(C['list'],open('tools/render/chars.json','w'))
print(len(L),'static',len(C['list']),'char frames')
