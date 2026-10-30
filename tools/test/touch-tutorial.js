const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch();const ctx=await b.newContext({viewport:{width:832,height:384},deviceScaleFactor:3,hasTouch:true,isMobile:true});const p=await ctx.newPage();
const errs=[];p.on('pageerror',e=>errs.push(e.message));
await p.goto('http://127.0.0.1:8765/www/index.html',{waitUntil:'domcontentloaded'});await p.waitForTimeout(800);
const tapEl=async s=>{const r=await p.locator(s).boundingBox();await p.touchscreen.tap(r.x+r.width/2,r.y+r.height/2);await p.waitForTimeout(250)};
await tapEl('#goStart');await tapEl('#goName');await tapEl('#goPlay');await p.waitForTimeout(500);
const st=()=>p.evaluate(()=>({goal:S.goal,gold:S.gold,talk:!$('talk').hidden,sheet:!$('sheetBg').hidden,title:$('shTitle').textContent,lv:!$('lvup').hidden,hand:$('hand').hidden?null:[parseFloat($('hand').style.left)+8,parseFloat($('hand').style.top)],placing:typeof placing!=='undefined'?!!placing:null}));
for(let k=0;k<260&&(await p.evaluate(()=>S.goal))<8;k++){
  const s=await st();
  if(s.lv){await tapEl('#lvOk');continue}
  if(s.talk){await tapEl('#talkBtn');continue}
  if(s.sheet){const want={0:'[data-act="plant"][data-k="corn"]',1:'[data-act="plow"]',2:'[data-act="plant"][data-k="wheat"], [data-act="mojo"]',3:'[data-act="place"][data-k="pine"]',4:'[data-act="place"][data-k="cottage_o"]',7:'[data-act="place"][data-k="road_dirt"]',6:'[data-act="expand"]'}[s.goal];
    let sel=want;if(s.goal===3||s.goal===4||s.goal===7){const tab={3:'deco',4:'house',7:'road'}[s.goal];if(await p.locator(`[data-act="tab"][data-k="${tab}"]`).count())await tapEl(`[data-act="tab"][data-k="${tab}"]`)}
    const loc=p.locator(sel||'#shClose').first();const ok=await loc.count();console.log(k,'SHEET',s.title,'goal',s.goal,'pick',sel,ok?'':'(없음)');
    if(ok){await loc.scrollIntoViewIfNeeded();const r=await loc.boundingBox();await p.touchscreen.tap(r.x+r.width/2,r.y+r.height/2);await p.waitForTimeout(300)}else await tapEl('#shClose');continue}
  if(s.hand){console.log(k,'goal',s.goal,'gold',s.gold,'tap hand',s.hand.map(Math.round),'placing',s.placing);await p.touchscreen.tap(s.hand[0],s.hand[1]);await p.waitForTimeout(400);
    const s2=await st();if(JSON.stringify(s2)===JSON.stringify(s)){console.log('   → 반응 없음');if(s.goal===3&&!globalThis.dd){globalThis.dd=1;console.log('DBG',await p.evaluate(([x,y])=>{const rc=cv.getBoundingClientRect(),el=document.elementFromPoint(x,y);const t=goalTarget();return {el:el&&(el.id||el.className),target:t&&t.i,tt:t&&S.tiles[t.i].t,placing:JSON.stringify(placing),cost:placing&&BUILDS[placing]&&BUILDS[placing].cost,gold:S.gold,toast:$('toast').hidden?'':$('toast').textContent}},s.hand))}await p.screenshot({path:`stuck${k}.png`});
      if(s.goal===0||s.goal===2||s.goal===5){await p.evaluate(()=>{S.gt+=3600});await p.waitForTimeout(300)}}
    continue}
  if(s.goal===5){await p.evaluate(()=>{S.gt+=600});await p.waitForTimeout(300);continue}
  console.log(k,'no hand',JSON.stringify(s));await p.evaluate(()=>{S.gt+=600});await p.waitForTimeout(300)}
console.log('END',JSON.stringify(await st()),errs);await b.close()})();
