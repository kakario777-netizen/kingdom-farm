// game/game.html → www/index.html (앱용 완전한 HTML 문서로 감싸기)
const fs = require('fs');
let body = fs.readFileSync('game/game.html', 'utf8');
fs.mkdirSync('www', { recursive: true });
// 앱 안에서는 인터넷 없이도 글꼴이 나오도록, 받아둔 글꼴 파일이 있으면 그걸 씀
if (fs.existsSync('www/fonts/Jua-Regular.ttf')) {
  body = body.replace(/<link[^>]*fonts\.googleapis[^>]*>/,
    '<style>@font-face{font-family:"Jua";src:url(fonts/Jua-Regular.ttf) format("truetype");font-display:swap}</style>');
}
const html = `<!doctype html>
<html lang="ko"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
<style>*{box-sizing:border-box}html,body{margin:0}img{max-width:100%}[hidden]{display:none!important}
:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px);height:100%}</style>
</head><body>
${body}
</body></html>`;
fs.writeFileSync('www/index.html', html);
// 그림 묶음 복사
if (fs.existsSync('game/sprites')) { fs.mkdirSync('www/sprites', { recursive: true }); for (const f of fs.readdirSync('game/sprites')) fs.copyFileSync('game/sprites/' + f, 'www/sprites/' + f); }
console.log('www/index.html', html.length, 'bytes');
