// Exercise the real web build in isolated browser contexts. No production saves.
// LORE_CHECK_URL and LORE_CHROMIUM override the local URL / browser executable.
const {chromium} = require('playwright');
const fs = require('fs');
const path = require('path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const out = path.join(root, 'build', 'graphics-web-check');
fs.mkdirSync(out, {recursive: true});
const fixture = JSON.parse(fs.readFileSync(path.join(root,
  'test/fixtures/dos_new_game.json'), 'utf8'));
const seed = JSON.stringify({
  schemaVersion: 2, slot: 1, slotName: '본 게임 데이타',
  timestamp: '1993-01-01T00:00:00.000Z', mapId: 6,
  mapTitle: 'CASTLE LORE', playerX: 51, playerY: 31, gold: 2000, food: 20,
  party: fixture.records, flags: {}, etc: {}, consumedScripts: [],
  mapTiles: [...fs.readFileSync(path.join(root, 'assets/maps/TOWN1.MAP')).subarray(2)],
});

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.LORE_CHROMIUM || '/usr/bin/chromium',
    headless: true, args: ['--no-sandbox'],
  });
  try {
    for (const [name, width, height] of [
      ['desktop', 1280, 800], ['mobile', 390, 844], ['landscape', 844, 390],
    ]) {
      const context = await browser.newContext({
        viewport: {width, height}, isMobile: name !== 'desktop',
        hasTouch: name !== 'desktop', deviceScaleFactor: 1,
      });
      await context.addInitScript(({seed}) => {
        if (!localStorage.getItem('flutter.lore_save_slot_1')) {
          localStorage.setItem('flutter.lore_save_slot_1', JSON.stringify(seed));
        }
      }, {seed});
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      await page.goto(process.env.LORE_CHECK_URL || 'http://127.0.0.1:8765/');
      async function enableSemantics() {
        await page.locator('flt-semantics-placeholder').waitFor({state: 'attached'});
        await page.locator('flt-semantics-placeholder').evaluateAll(
          es => es.forEach(e => e.click()));
      }
      async function resume() {
        await enableSemantics();
        await page.getByText('또다른 지식의 성전 원본 오프닝',{exact:true}).waitFor({timeout:60000});
        await page.locator('flutter-view').click({position:{x:20,y:20}});
        await page.keyboard.press('Enter'); // Source title key poll skips the letter.
        await page.getByText('2] 이전의 게임을 재개 시킴', {exact: true}).click();
        await page.getByText('이전의 게임을 재개', {exact: true}).first().click();
        await page.getByRole('button', {name: '앱 설정', exact: true}).waitFor();
        await page.waitForTimeout(750);
      }
      async function openSettings() {
        await page.getByRole('button', {name: '앱 설정', exact: true}).click();
        await page.getByText('그래픽 스킨', {exact: true}).waitFor();
      }
      async function choose(label, id) {
        await page.getByRole('button', {name: new RegExp('^' + label)}).first().click();
        await page.waitForFunction(id =>
          localStorage.getItem('flutter.lore_graphics_skin') === JSON.stringify(id), id);
      }
      await resume();
      const before = await page.evaluate(() =>
        localStorage.getItem('flutter.lore_save_slot_1'));
      await page.screenshot({path: path.join(out, `${name}-original.png`)});
      const full = await page.getByRole('button', {name: '전체화면 전환', exact: true})
        .boundingBox();
      const app = await page.getByRole('button', {name: '앱 설정', exact: true})
        .boundingBox();
      assert(full && app, 'Both presentation controls are visible');
      if (Math.abs(app.x - full.x) < 1) {
        assert(app.y >= full.y + full.height - 1);
      } else {
        assert(app.x >= full.x + full.width - 1);
      }
      await openSettings();
      await page.screenshot({path: path.join(out, `${name}-settings-before.png`)});
      await page.keyboard.press('ArrowDown');
      await page.keyboard.press('KeyG');
      await page.keyboard.press('Space');
      await choose('크리스털 판타지', 'crystal');
      await page.screenshot({path: path.join(out, `${name}-settings.png`)});
      await page.getByRole('button', {name: '설정 닫기', exact: true}).click();
      await page.getByText('그래픽 스킨', {exact: true}).waitFor({state: 'hidden'});
      await page.screenshot({path: path.join(out, `${name}-crystal.png`)});
      assert.equal(await page.evaluate(() =>
        localStorage.getItem('flutter.lore_save_slot_1')), before,
        'Changing skins must not write a game save');

      await page.reload();
      await resume();
      await openSettings();
      const selected = page.getByRole('button', {name: /^크리스털 판타지/}).first();
      assert.equal(await selected.getAttribute('aria-current'), 'true',
        'Crystal skin is selected after reloading');
      await choose('원작 그래픽', 'original');
      await page.keyboard.press('Escape');
      await page.getByText('그래픽 스킨', {exact: true}).waitFor({state: 'hidden'});
      assert.equal(await page.evaluate(() =>
        localStorage.getItem('flutter.lore_save_slot_1')), before);
      assert.deepEqual(errors, []);
      console.log(`${name}: toolbar placement, PNG skin switch, persistence, ` +
        'Escape and unchanged save passed');
      await context.close();
    }
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
