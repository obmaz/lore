"""Exercise native-record save/reload on a locally served release in Chromium.

Requires Playwright and Chromium. This is app/storage smoke verification, not
continuous DOS campaign replay or original BGI pixel equivalence.
"""
import argparse
import json
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

ROOT = Path(__file__).resolve().parents[1]
COMMAND = '당신의 명령을 고르시오 ===>'


def enable_semantics(page):
    page.locator('flt-semantics-placeholder').wait_for(timeout=60000)
    page.locator('flt-semantics-placeholder').evaluate('(element) => element.click()')


def resume(page):
    page.get_by_role('button', name='2] 이전의 게임을 재개 시킴').click()
    button = page.get_by_role('button', name='이전의 게임을 재개').first
    expect(button).to_be_enabled(timeout=15000)
    button.click()
    expect(page.get_by_role('button', name=COMMAND)).to_be_visible(timeout=20000)
    page.wait_for_load_state('networkidle')
    # Font/image decoding and Flame's first frame follow cached network loads.
    page.wait_for_timeout(1000)


def read_save(page):
    # SharedPreferences web JSON-encodes its string values in localStorage.
    raw = page.evaluate('localStorage.getItem("flutter.lore_save_slot_1")')
    return json.loads(json.loads(raw))


def verify(url, output):
    fixture = json.loads((ROOT / 'test/fixtures/dos_new_game.json').read_text())
    party = fixture['party']
    save = dict(schemaVersion=2, slot=1, slotName='본 게임 데이타',
                timestamp='2026-10-07T00:00:00Z', mapId=party['mapId'],
                mapTitle='CASTLE LORE', playerX=party['x'], playerY=party['y'],
                gold=party['gold'], food=party['food'], party=fixture['records'],
                flags={f'etc{i+1}': value for i, value in enumerate(party['etc'])},
                etc={}, mapTiles=[], consumedScripts=[])
    # Cold-created DOS saves precede Set_All's Display_Condition. Apply the
    # original LORESUB.PAS:709-710 side effects to all six slots, including
    # the zero-HP Reserved slot, before comparing a screen's saved records.
    expected_party = json.loads(json.dumps(fixture['records']))
    for member in expected_party:
        if member['hp'] <= 0 and member['unconscious'] == 0:
            member['unconscious'] = 1
        threshold = (member['endurance'] * member['battleLevel'] + 32768) % 65536 - 32768
        if member['unconscious'] > threshold and member['dead'] == 0:
            member['dead'] = 1
    output.mkdir(parents=True, exist_ok=True)
    results = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True, args=['--no-sandbox'])
        try:
            for name, width, height in [('mobile_portrait', 390, 844), ('mobile_landscape', 844, 390), ('desktop', 1280, 900)]:
                context = browser.new_context(viewport=dict(width=width, height=height))
                page = context.new_page()
                errors, requests = [], []
                page.on('pageerror', lambda error: errors.append(str(error)))
                page.on('request', lambda request: requests.append(request.url))
                page.add_init_script('if (!localStorage.getItem("flutter.lore_save_slot_1")) localStorage.setItem("flutter.lore_save_slot_1", ' + json.dumps(json.dumps(json.dumps(save, ensure_ascii=False))) + ');')
                page.goto(url)
                enable_semantics(page)
                resume(page)
                page.keyboard.press('ArrowDown')
                page.keyboard.press('g')
                page.get_by_role('button', name='현재의 게임을 저장').click()
                page.get_by_role('button', name='본 게임 데이타', exact=True).click()
                page.wait_for_function('(y) => { const raw = localStorage.getItem("flutter.lore_save_slot_1"); return raw && JSON.parse(JSON.parse(raw)).playerY === y; }', arg=32, timeout=15000)
                current = read_save(page)
                assert (current['mapId'], current['playerX'], current['playerY']) == (6, 51, 32), current
                assert current['party'] == expected_party
                assert len(current['mapTiles']) == 10000
                assert current['gold'] == save['gold'] and current['food'] == save['food']
                page.keyboard.press('Escape')
                page.reload()
                enable_semantics(page)
                resume(page)
                page.keyboard.press('ArrowDown')
                page.keyboard.press('g')
                page.get_by_role('button', name='현재의 게임을 저장').click()
                page.get_by_role('button', name='본 게임 데이타', exact=True).click()
                page.wait_for_function('(y) => { const raw = localStorage.getItem("flutter.lore_save_slot_1"); return raw && JSON.parse(JSON.parse(raw)).playerY === y; }', arg=33, timeout=15000)
                restored = read_save(page)
                assert (restored['playerX'], restored['playerY']) == (51, 33)
                assert restored['party'] == current['party']
                assert restored['mapTiles'] == current['mapTiles']
                for _ in range(3):
                    if page.get_by_role('button', name=COMMAND).is_visible():
                        break
                    page.keyboard.press('Escape')
                    page.wait_for_timeout(100)
                expect(page.get_by_role('button', name=COMMAND)).to_be_visible(timeout=10000)
                assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth')
                assert not errors, errors
                screenshot = output / f'{name}.png'
                page.screenshot(path=str(screenshot))
                results.append(dict(viewport=name, size=[width, height], saved=[51, 32], reloaded_next_action=[51, 33], party_records_match_source_display_condition=True, map_snapshot_equal=True, page_errors=errors, wasm_requested=any('/main.dart.wasm' in r for r in requests), screenshot=str(screenshot.relative_to(ROOT))))
                context.close()
        finally:
            browser.close()
    report = dict(scope=__doc__.strip(), base_url=url, cases=results)
    (output / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(report, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', default='http://127.0.0.1:8765/lore/')
    parser.add_argument('--output', type=Path, default=ROOT / 'build/verification/browser')
    args = parser.parse_args()
    verify(args.url, args.output)
