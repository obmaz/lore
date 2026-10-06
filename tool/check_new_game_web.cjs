// Mobile creation -> Lord Ahn -> armoury -> Skeleton departure, against DOS bytes.
// Requires Playwright and Chromium. LORE_CHECK_URL selects the deployed/local build;
// LORE_CHROMIUM selects a Chromium executable (default /usr/bin/chromium).
// No synthetic save seed. Each invocation uses an empty browser context.
const {chromium}=require('playwright');
const fs=require('fs');
const path=require('path');
const root=path.resolve(__dirname,'..');
(async()=>{
const browser=await chromium.launch({executablePath:process.env.LORE_CHROMIUM||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const page=await browser.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
const errors=[];page.on('pageerror',e=>errors.push(e.message));
const data=JSON.parse(fs.readFileSync(path.join(root,'assets/data/creation.json')));
const fixture=JSON.parse(fs.readFileSync(path.join(root,'test/fixtures/dos_new_game.json')));
await page.goto(process.env.LORE_CHECK_URL||'http://127.0.0.1:8765/lore/');await page.waitForTimeout(1500);
await page.locator('flt-semantics-placeholder').evaluateAll(es=>es.forEach(e=>e.click()));
async function click(text){await page.getByText(text,{exact:true}).click();await page.waitForTimeout(100);}
async function next(){await click(data.texts.Third[10]);}
await click('1] 새로운 주인공을 생성 시킴');await page.getByRole('textbox').fill('Hero');await next();
for(const q of data.questions)await click(q.options[0].text);
for(const slot of [1,3])for(let i=0;i<20;i++){await page.getByRole('button').nth(slot).click();}
await next();await click('8] 떠돌이');await next();
await page.screenshot({path:'/tmp/lore-newgame-companions-mobile.png'});
for(const id of [1,3,5,7,7,5,3,1]){
 const c=data.characters[id-1];
 const row=page.getByRole('group',{name:new RegExp('^'+c.name+' ')});
 await row.getByRole('button',{name:data.texts.Fourth[2],exact:true}).click();
 await page.waitForTimeout(100);
}
await next();await page.waitForTimeout(1200);
const saves=await page.evaluate(()=>[1,2,3,4].map(n=>JSON.parse(JSON.parse(localStorage.getItem('flutter.lore_save_slot_'+n)))));
for(const s of saves){
 if(!require('util').isDeepStrictEqual(s.party,fixture.records))throw Error('DOS party mismatch '+JSON.stringify(s.party));
 if(s.mapId!==6||s.playerX!==51||s.playerY!==31||s.food!==20||s.gold!==2000)throw Error('DOS initial party state mismatch');
}
console.log('Actual mobile web creation and four saves match cold-start original DOS records');
for(const n of [3,1,1]){
 for(let i=0;i<n;i++){await page.keyboard.press('ArrowUp');await page.waitForTimeout(300);}
 await page.waitForTimeout(300);await page.keyboard.press('Enter');await page.waitForTimeout(500);
}
await page.keyboard.press('KeyG');await page.waitForTimeout(300);
await click('현재의 게임을 저장');await page.waitForTimeout(300);
await click('본 게임 데이타');await page.waitForTimeout(500);
const saved=await page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.lore_save_slot_1'))));
fs.writeFileSync('/tmp/lore-newgame-web-checkpoint.json',JSON.stringify(saved,null,2));
const q=fixture.firstQuest;
const equal=require('util').isDeepStrictEqual;
if(!equal(saved.party,q.records))throw Error('First quest DOS player mismatch');
if(!equal(saved.mapTiles,Array.from(Buffer.from(q.files['SAVE1.MAP'].hex,'hex').subarray(2))))throw Error('First quest DOS map mismatch');
const rawEtc=Array.from({length:100},(_,i)=>Number(saved.flags['etc'+(i+1)]||0));
if(!equal(rawEtc,q.party.etc))throw Error('First quest DOS raw etc mismatch');
if(saved.mapId!==q.party.mapId||saved.playerX!==q.party.x||saved.playerY!==q.party.y||saved.food!==q.party.food||saved.gold!==q.party.gold)throw Error('First quest DOS location/food/gold mismatch');
console.log('First quest: all six records, 100 etc bytes, position/food/gold and 10000 saved map cells match DOS');
await page.keyboard.press('Enter');await page.reload();await page.waitForTimeout(1500);
await page.locator('flt-semantics-placeholder').evaluateAll(es=>es.forEach(e=>e.click()));
await click('2] 이전의 게임을 재개 시킴');await page.getByText('이전의 게임을 재개',{exact:true}).first().click();await page.waitForTimeout(1200);
await page.keyboard.press('KeyG');await page.waitForTimeout(300);await click('현재의 게임을 저장');await click('본 게임 데이타');await page.waitForTimeout(400);
const reloaded=await page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.lore_save_slot_1'))));
for(const key of ['party','flags','etc','mapId','playerX','playerY','food','gold','mapTiles'])if(!equal(reloaded[key],saved[key]))throw Error('Reload/save changed '+key);
console.log('First quest reload and resave retain the same state');
await page.screenshot({path:'/tmp/lore-newgame-first-quest-web.png'});
const castle=fixture.castleRoute;
async function walk(route){
 for(const key of route){await page.keyboard.press('Arrow'+key);await page.waitForTimeout(150);}
}
async function save(){
 await page.keyboard.press('KeyG');await page.waitForTimeout(300);
 await click('현재의 게임을 저장');await click('본 게임 데이타');await page.waitForTimeout(400);
 return await page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.lore_save_slot_1'))));
}
function compare(capture,state,label){
 if(!equal(state.party,capture.records))throw Error(label+' DOS player mismatch');
 if(!equal(state.mapTiles,Array.from(Buffer.from(capture.files['SAVE1.MAP'].hex,'hex').subarray(2))))throw Error(label+' DOS map mismatch');
 const raw=Array.from({length:100},(_,i)=>Number(state.flags['etc'+(i+1)]||0));
 if(!equal(raw,capture.party.etc))throw Error(label+' DOS raw etc mismatch');
 const party=capture.party;
 if(state.mapId!==party.mapId||state.playerX!==party.x||state.playerY!==party.y||state.food!==party.food||state.gold!==party.gold)throw Error(label+' DOS location/food/gold mismatch');
 console.log(label+': six records, etc100 bytes and map10000 cells match original DOS');
}
await page.keyboard.press('Enter');await walk(castle.inputs.gateApproach);
await page.keyboard.press('ArrowDown');await page.waitForTimeout(400);await click('예.');await page.waitForTimeout(300);await page.keyboard.press('Enter');await page.waitForTimeout(400);
await walk(castle.inputs.armoryApproach);await page.waitForTimeout(600);
await page.keyboard.press('Enter');await page.waitForTimeout(400);
const armorySaved=await save();compare(castle.armory,armorySaved,'Armoury');
await page.keyboard.press('Enter');await page.waitForTimeout(400);
await page.keyboard.press('KeyG');await page.waitForTimeout(400);
await page.screenshot({path:'/tmp/lore-center-web-option-cancel.png'});
await page.getByText('난이도 조절',{exact:true}).waitFor();
await page.keyboard.press('Escape');await page.waitForTimeout(400);
if(await page.getByText('난이도 조절',{exact:true}).count())throw Error('GameOption Esc must close');
await page.keyboard.press('KeyG');await page.waitForTimeout(300);await click('현재의 게임을 저장');
await page.getByText('본 게임 데이타',{exact:true}).waitFor();
await page.keyboard.press('Escape');await page.waitForTimeout(400);
if(await page.getByText('본 게임 데이타',{exact:true}).count())throw Error('Save-slot Esc must close');
const cancelledSave=await page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.lore_save_slot_1'))));
if(!equal(cancelledSave,armorySaved))throw Error('Save-slot Esc wrote a save');
await page.keyboard.press('KeyR');await page.getByText('아무키나 누르십시오 ...').last().waitFor();
await page.keyboard.press('Escape');await page.waitForTimeout(400);
if(await page.getByText('아무키나 누르십시오 ...').count())throw Error('Rest Esc must end the key wait');
console.log('Actual mobile web: GameOption Esc, Save-slot Esc without writing, and Rest Esc pass; RNG parity is checked by native mobile fixtures');
await walk(castle.inputs.blessingApproach);
await page.keyboard.press('ArrowDown');await page.waitForTimeout(400);await page.keyboard.press('Enter');await page.waitForTimeout(300);
await walk(castle.inputs.exitApproach);await page.waitForTimeout(400);
const exitPrompt=page.getByText('여기서 나가기를 원합니까 ?',{exact:true});
await exitPrompt.waitFor();await page.keyboard.press('Escape');await page.waitForTimeout(400);
if(await exitPrompt.count())throw Error('Exit confirmation must close on Esc');
await page.keyboard.press('ArrowDown');await page.waitForTimeout(400);
await exitPrompt.waitFor();await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await page.waitForTimeout(400);
if(await exitPrompt.count())throw Error('Exit refusal must close the source Select');
await page.keyboard.press('ArrowDown');await page.waitForTimeout(400);
await exitPrompt.waitFor();await page.keyboard.press('Enter');await page.waitForTimeout(400);
console.log('Actual mobile web exit Select: Esc, arrow/Enter refusal, default Enter admission pass');
await page.keyboard.press('Enter');await page.waitForTimeout(400);await click('당신을 환영하오.');await page.waitForTimeout(500);
// Actual DOS retains this blank PressAnyKey after join, before flag/map load.
await page.getByText('아무키나 누르십시오 ...',{exact:true}).waitFor();
await page.screenshot({path:'/tmp/lore-newgame-skeleton-wait-web.png'});
await page.keyboard.press('Enter');await page.waitForTimeout(500);
const departure=await save();compare(castle.departure,departure,'Skeleton departure');
await page.keyboard.press('Enter');await page.reload();await page.waitForTimeout(1500);
await page.locator('flt-semantics-placeholder').evaluateAll(es=>es.forEach(e=>e.click()));
await click('2] 이전의 게임을 재개 시킴');await page.getByText('이전의 게임을 재개',{exact:true}).first().click();await page.waitForTimeout(1200);
const again=await save();compare(castle.departure,again,'Departure reload/save');
if(errors.length)throw Error(errors.join('\n'));
await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
