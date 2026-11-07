// 生成 App 图标。用法：node tool/icon/gen.js <A|B|C> .（需要 Playwright + Chromium、python3）
const {chromium}=require('playwright');const {execFileSync}=require('child_process');const fs=require('fs');const path=require('path');
const [k,repo]=process.argv.slice(2);
const svg=(layer,vb,rx)=>execFileSync('python3',['-c',`import icons;print(icons.build(${JSON.stringify(k)},${JSON.stringify(layer)},${JSON.stringify(vb||'0 0 108 108')},${rx==null?'None':rx}))`],{cwd:__dirname}).toString();
const res=path.join(repo,'android/app/src/main/res');
const dens={mdpi:1,hdpi:1.5,xhdpi:2,xxhdpi:3,xxxhdpi:4};
const jobs=[];
for(const [d,s] of Object.entries(dens)){
  for(const [n,l] of [['ic_launcher_foreground','fg'],['ic_launcher_background','bg'],['ic_launcher_monochrome','mono']])
    jobs.push([svg(l),108*s,`${res}/mipmap-${d}/${n}.png`]);
  jobs.push([svg('both','10 10 88 88',15),48*s,`${res}/mipmap-${d}/ic_launcher.png`]);
  jobs.push([svg('both','10 10 88 88',44),48*s,`${res}/mipmap-${d}/ic_launcher_round.png`]);
}
for(const s of [192,512]){
  jobs.push([svg('both','10 10 88 88',15),s,`${repo}/web/icons/Icon-${s}.png`]);
  jobs.push([svg('both'),s,`${repo}/web/icons/Icon-maskable-${s}.png`]);
}
jobs.push([svg('both','10 10 88 88',15),32,`${repo}/web/favicon.png`]);
const ios=`${repo}/ios/Runner/Assets.xcassets/AppIcon.appiconset`;
for(const f of fs.readdirSync(ios).filter(f=>f.endsWith('.png'))){
  const m=f.match(/-([\d.]+)x[\d.]+@(\d)x/);jobs.push([svg('both','10 10 88 88'),Math.round(parseFloat(m[1])*+m[2]),`${ios}/${f}`]);
}

(async()=>{const b=await chromium.launch();const p=await b.newPage();
for(const [s,px,out] of jobs){await p.setViewportSize({width:px,height:px});
 await p.setContent(`<html><body style="margin:0;background:transparent">${s.replace('width="100%" height="100%"',`width="${px}" height="${px}"`)}</body></html>`);
 await p.screenshot({path:out,omitBackground:!out.includes('AppIcon')});}
await b.close();console.log(jobs.length,'files');})();
