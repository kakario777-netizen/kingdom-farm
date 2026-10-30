// 목록(json)을 렌더해서 tools/render/out/<id>.png + meta.json
const { chromium } = require('playwright');const fs=require('fs');
(async()=>{const list=JSON.parse(fs.readFileSync(process.argv[2]));const only=process.argv[3]?new RegExp(process.argv[3]):null;
fs.mkdirSync('tools/render/out',{recursive:true});const metaF='tools/render/out/meta.json';const meta=fs.existsSync(metaF)?JSON.parse(fs.readFileSync(metaF)):{};
const b=await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});const p=await b.newPage();
p.on('pageerror',e=>console.log('PE',e.message));
await p.goto('http://127.0.0.1:8765/tools/render/render.html');await p.waitForFunction(()=>window.READY);
let n=0;for(const s of list){if(only&&!only.test(s.id))continue;const r=await p.evaluate(s=>window.renderModel(s),s);
  if(!r){console.log('EMPTY',s.id);continue}fs.writeFileSync(`tools/render/out/${s.id}.png`,Buffer.from(r.url.split(',')[1],'base64'));
  meta[s.id]={w:r.w,h:r.h,ax:r.ax,ay:r.ay,res:r.res};n++;if(n%40===0){console.log(n);fs.writeFileSync(metaF,JSON.stringify(meta))}}
fs.writeFileSync(metaF,JSON.stringify(meta));console.log('done',n);await b.close()})();
