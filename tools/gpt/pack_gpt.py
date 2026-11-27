# art/gpt/*.png (GPT로 만든 원본) → 고도용
#  - 월드 그림(건물·작물·장식·숲·주민·초상) → godot/sprites/sheetN.png + atlas.json + masks.json
#  - 화면 UI 그림 → godot/ui/g/<id>.png (투명 여백 잘라내고 쓰는 크기에 맞게 비율 그대로 축소)
# 원본 규칙: 땅 한 칸 마름모 가로 900px, 1024 높이 캔버스는 마름모 중심 y=775, 1536 높이는 y=1287 (가로 가운데 512)
import os, sys, json, math, base64, shutil
from PIL import Image
SRC = sys.argv[1] if len(sys.argv) > 1 else 'art/gpt'; DST = 'godot/sprites'; UID = 'godot/ui/g'
TILE = 96.0  # 고도 세상 단위로 땅 한 칸 가로폭 (W2*2)

def ground(im):
    return (512, 775) if im.height == 1024 else (512, 1287)

world = {}   # 키 -> (파일, 축소배율, 기준점(x,y) 원본좌표, res(원본px/세상단위))
def add(key, fid, s=0.5, anchor=None, tiles=1.0):
    world[key] = (fid, s, anchor, tiles)

for f in sorted(os.listdir(SRC)):
    fid = f[:-4]
    if fid.startswith('bld_') and fid not in ('bld_pic_frame', 'bld_bar_frame', 'bld_bar_fill'):
        k = fid[4:]
        if k.startswith('castle_'): add('castle' + k[-1], fid, 0.7, None, 2.0)
        else: add(k, fid)
    elif fid.startswith('deco_'):
        k = fid[5:]
        add('mailbox' if k == 'well' else k, fid)
    elif fid.startswith('crop_') and not fid.endswith('_icon'):
        k = fid.replace('_grow', '_1').replace('_ripe', '_2')
        add(k, fid)
    elif fid.startswith('plot_'):
        add('plot' if fid == 'plot_plowed' else fid, fid)
    elif fid.startswith('road_'):
        add(fid, fid, 0.4, 'road', 1440 / 900)
    elif fid.startswith('fence_'):
        add(fid, fid)
    elif fid.startswith('wild_'):
        add(fid, fid)
    elif fid.startswith('npc_') or fid.startswith('ruler_') or fid.startswith('animal_'):
        base = fid.split('_')[1]
        side = 'ur' if fid.endswith('_back') else 'dr'
        add('ch_%s_%s' % (base, side), fid, 0.3, 'feet', None)
    elif fid.startswith('face_'):
        add('pt_' + fid[5:], fid, 0.4, 'img', None)
    elif fid.startswith('pt_advisor'):
        add(fid, fid, 0.4, 'img', None)
    elif fid.startswith('crop_') and fid.endswith('_icon') or fid.startswith('item_'):
        add(fid, fid, 0.25, 'img', None)

def trim(im):
    b = im.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
    return im.crop(b), b

items = []
meta = {}
for key, (fid, s, anchor, tiles) in world.items():
    im = Image.open(f'{SRC}/{fid}.png').convert('RGBA')
    if anchor == 'feet': ax, ay = 512, 1490
    elif anchor == 'img': ax, ay = im.width / 2, im.height
    elif anchor == 'road': ax, ay = 768, 512
    else: ax, ay = ground(im)
    t, b = trim(im)
    t = t.resize((max(1, round(t.width * s)), max(1, round(t.height * s))), Image.LANCZOS)
    if tiles: res = 900 * s / (TILE * tiles)
    elif anchor == 'feet': res = 1300 * s / 58.0      # 주민 키 = 세상 58단위(땅 칸보다 조금 큼)
    else: res = 1.0
    meta[key] = {'ax': (ax - b[0]) * s, 'ay': (ay - b[1]) * s, 'res': round(res, 4)}
    items.append((key, t))

items.sort(key=lambda kv: -kv[1].height)
SZ = 4096; PAD = 16; sheets = []; atlas = {}
cur = None; x = y = rowh = 0
def new():
    global cur, x, y, rowh
    cur = Image.new('RGBA', (SZ, SZ), (0, 0, 0, 0)); sheets.append(cur); x = y = PAD; rowh = 0
new()
for k, im in items:
    w, h = im.size
    if x + w + PAD > SZ: x = PAD; y += rowh + PAD; rowh = 0
    if y + h + PAD > SZ: new()
    cur.paste(im, (x, y)); m = meta[k]
    atlas[k] = [len(sheets) - 1, x, y, w, h, round(m['ax'], 1), round(m['ay'], 1), m['res']]
    x += w + PAD; rowh = max(rowh, h)
imp0 = open(f'{DST}/sheet0.png.import').read() if os.path.exists(f'{DST}/sheet0.png.import') else (open('tools/gpt/sheet.import').read() if os.path.exists('tools/gpt/sheet.import') else None)
for f in os.listdir(DST):
    if f.startswith('sheet') and (f.endswith('.png') or f.endswith('.webp')): os.remove(f'{DST}/{f}')
names = []
for n, s in enumerate(sheets):
    f = f'sheet{n}.webp'; s.save(f'{DST}/{f}', quality=92, method=6); names.append(f)
    if imp0 and not os.path.exists(f'{DST}/{f}.import'):
        open(f'{DST}/{f}.import', 'w').write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]' + imp0.split('[params]')[1])
for f in os.listdir(DST):   # 남는 .import 정리
    if f.endswith('.import') and f[:-7] not in names: os.remove(f'{DST}/{f}')
json.dump({'sheets': names, 's': atlas}, open(f'{DST}/atlas.json', 'w'), separators=(',', ':'))
masks = {}
for k, im in items:
    res = meta[k]['res']; w = max(1, math.ceil(im.width / res)); h = max(1, math.ceil(im.height / res))
    a = im.getchannel('A').resize((w, h), Image.BILINEAR); px = a.load(); bits = bytearray((w * h + 7) // 8)
    for yy in range(h):
        for xx in range(w):
            if px[xx, yy] > 90: n = yy * w + xx; bits[n >> 3] |= 1 << (n & 7)
    masks[k] = [w, h, base64.b64encode(bytes(bits)).decode()]
json.dump(masks, open(f'{DST}/masks.json', 'w'), separators=(',', ':'))
print(len(atlas), 'world sprites', [(f, os.path.getsize(f'{DST}/{f}') // 1024) for f in names])

# ---------- 화면 UI ----------
os.makedirs(UID, exist_ok=True)
for f in os.listdir(UID):
    if f.endswith('.png') or f.endswith('.webp') or f.endswith('.import'): os.remove(f'{UID}/{f}')
BIG = ('win_', 'talk_box', 'bg_', 'loading_', 'logo_')
SMALL = ('ic_', 'item_', 'fx_', 'bubble_', 'dot_', 'tag_', 'arrow_')
n = 0
for f in sorted(os.listdir(SRC)):
    fid = f[:-4]
    if fid.startswith(('bld_', 'deco_', 'plot_', 'wild_', 'npc_', 'ruler_', 'animal_', 'face_', 'road_', 'fence_')) and fid not in ('bld_pic_frame', 'bld_bar_frame', 'bld_bar_fill'): continue
    if fid.startswith('crop_') and not fid.endswith('_icon'): continue
    im = Image.open(f'{SRC}/{f}').convert('RGBA')
    if not fid.startswith(('bg_', 'loading_', 'ground_')): im, _ = trim(im)
    tgt = 1536 if fid.startswith(('bg_', 'loading_')) else 1200 if fid.startswith(BIG) else (256 if fid.startswith(SMALL) or fid.endswith('_icon') else 640)
    sc = min(1.0, tgt / max(im.size))
    if sc < 1: im = im.resize((round(im.width * sc), round(im.height * sc)), Image.LANCZOS)
    im.save(f'{UID}/{fid}.webp', quality=90, method=6); n += 1
print(n, 'ui images')
