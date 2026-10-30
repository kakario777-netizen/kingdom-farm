// 후보 모델 한눈에 보기
const { chromium } = require('playwright');const fs=require('fs');
(async()=>{const list=JSON.parse(process.argv[2]);const b=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});const p=await b.newPage();
p.on('pageerror',e=>console.log('PE',e.message));
await p.goto('http://127.0.0.1:8765/tools/render/render.html');await p.waitForFunction(()=>window.READY);
for(const s of list){const r=await p.evaluate(s=>window.renderModel(s),s);if(!r){console.log('EMPTY',s.id);continue}fs.writeFileSync(`/tmp/claude-0/sh/${s.id}.png`,Buffer.from(r.url.split(',')[1],'base64'))}
await b.close()})();
