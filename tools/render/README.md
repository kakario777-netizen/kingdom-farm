# 그림 만들기 (오픈소스 3D → 게임 스프라이트)

1. `.github/workflows/fetch-assets.yml` 가 `tools/asset-sources.txt` 의 CC0 에셋 팩을 받아 `assets-src/` 에 넣음
2. `python3 tools/render/manifest.py` — 어떤 모델을 어떤 색·배치로 그릴지 목록 생성
3. `python3 -m http.server 8765` (저장소 최상위에서) 후 `node tools/render/run.js tools/render/static.json` / `chars.json`
   - 머리 없는 크롬 + three.js 로 게임 시점(2:1 아이소, 30°)으로 렌더, 색 바꾸기·여러 모델 조립·그림자·갈색 테두리
4. `python3 tools/render/pack.py` → `game/sprites/sheet*.webp` + `atlas.js`

## 출처 (모두 CC0 1.0 — 자유 사용·수정·배포)
- Quaternius — Lowpoly Medieval Village Pack (opengameart.org/content/lowpoly-medieval-village-pack)
- Kenney — Castle Kit, Nature Kit, Fantasy Town Kit, Mini Characters (kenney.nl)
