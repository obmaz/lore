"""Capture the real release UI using isolated, source-backed preview saves.

This does not modify real browser saves or add debug routes to the game.
Requires Playwright, Chromium and a local release server.
"""
import argparse
import json
import re
import shutil
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
from verify_web_browser import COMMAND, enable_semantics, resume

ROOT = Path(__file__).resolve().parents[1]


def capture(url, output):
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    fixture = json.loads((ROOT / 'test/fixtures/dos_new_game.json').read_text())
    data = json.loads((ROOT / 'assets/data/creation.json').read_text())
    party = fixture['party']
    save = dict(schemaVersion=2, slot=1, slotName='본 게임 데이타',
                timestamp='2026-10-08T00:00:00Z', mapId=6, mapTitle='CASTLE LORE',
                playerX=party['x'], playerY=party['y'], gold=party['gold'],
                food=party['food'], party=fixture['records'],
                flags={f'etc{i + 1}': v for i, v in enumerate(party['etc'])},
                etc={}, mapTiles=[], consumedScripts=[])
    errors = []
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=shutil.which('chromium'), args=['--no-sandbox'])

        def open_page(value=None, size=(390, 844)):
            context = browser.new_context(viewport=dict(width=size[0], height=size[1]))
            page = context.new_page()
            page.on('pageerror', lambda e: errors.append(str(e)))
            if value is not None:
                page.add_init_script('localStorage.setItem("flutter.lore_save_slot_1", ' +
                                     json.dumps(json.dumps(json.dumps(value, ensure_ascii=False))) + ');')
            page.goto(url)
            enable_semantics(page)
            page.wait_for_timeout(600)
            return page

        def shot(page, name):
            page.wait_for_timeout(300)
            page.screenshot(path=str(output / f'{name}.png'))
            print(f'Captured {name}', flush=True)

        page = open_page(save)
        shot(page, '01-start')
        page.get_by_role('button', name=re.compile('새로운 모험')).click()
        page.get_by_role('textbox').fill('Hero')
        next_button = data['texts']['Third'][10]
        page.get_by_role('button', name=next_button, exact=True).click()
        for question in data['questions']:
            page.get_by_role('button', name=question['options'][0]['text'], exact=True).click()
        print('Reached original point distribution', flush=True)
        # Original forty-point distribution: twenty agility, twenty accuracy.
        for index in (0, 1):
            for _ in range(20):
                label = data['texts']['Second'][index + 2].split()[0]
                page.get_by_role('button', name=re.compile(re.escape(label) + '.*올리기')).click()
        page.get_by_role('button', name=next_button, exact=True).click()
        page.get_by_text('8] 떠돌이', exact=True).click()
        page.get_by_role('button', name=next_button, exact=True).click()
        expect(page.get_by_text('동료 선택', exact=True)).to_be_visible()
        shot(page, '02-creation')
        page.context.close()

        page = open_page(save)
        page.get_by_role('button', name=re.compile('저장 불러오기')).click()
        expect(page.get_by_role('button', name='이전의 게임을 재개')).to_be_enabled()
        shot(page, '07-save')
        page.get_by_role('button', name='이전의 게임을 재개').click()
        page.wait_for_timeout(1000)
        shot(page, '03-exploration')
        page.get_by_role('button', name='상세', exact=True).click()
        page.get_by_role('button', name='장비', exact=True).click()
        shot(page, '06-party')
        page.get_by_role('button', name='닫기', exact=True).click()
        page.get_by_role('button', name='앱 설정', exact=True).click()
        shot(page, '08-settings')
        page.keyboard.press('Escape')
        for size, name in [((768, 1024), '09-ratio-3-4'), ((360, 780), '10-ratio-9-19-5')]:
            page.set_viewport_size(dict(width=size[0], height=size[1]))
            shot(page, name)
        for size, name in [
            ((844, 390), '11-landscape-fitted'),
            ((600, 600), '12-square-fitted'),
            ((360, 900), '13-tall-fitted'),
        ]:
            page.set_viewport_size(dict(width=size[0], height=size[1]))
            expect(page.get_by_role('button', name=COMMAND)).to_be_visible()
            shot(page, name)
        page.context.close()

        # Lord Ahn's existing talk at (51,28); no fabricated dialogue.
        value = dict(save, playerY=29)
        page = open_page(value)
        resume(page)
        page.keyboard.press('ArrowUp')
        expect(page.get_by_text('대화', exact=True)).to_be_visible()
        shot(page, '04-dialogue')
        page.context.close()

        # Existing Sphinx source event, same setup as boss_hp_override_ui_test.
        # Snapshot is the real T_DEN1 MAP; only the preview event cell is zeroed.
        raw = (ROOT / 'assets/maps/T_DEN1.MAP').read_bytes()
        tiles = list(raw[2:2 + raw[0] * raw[1]])
        tiles[(24 - 1) * raw[0] + 30 - 1] = 0
        value = dict(save, mapId=11, mapTitle='T_DEN1', playerX=30, playerY=25,
                     mapTiles=tiles, flags=dict(save['flags'], etc13=1, etc15=1, etc1=1))
        # Valid high-health preview records keep the UI in command-selection;
        # these illustrative values are not DOS parity evidence or app changes.
        value['party'] = json.loads(json.dumps(save['party']))
        for member in value['party']:
            if member['name']:
                member.update(endurance=30, battleLevel=30, hp=900,
                              mentality=10, magicLevel=30, sp=300)
        page = open_page(value)
        resume(page)
        page.keyboard.press('ArrowUp')
        for _ in range(20):
            command = page.get_by_role('button', name=re.compile('한 명의 적을 .*공격'))
            if command.count() and command.first.is_enabled():
                break
            page.keyboard.press('Enter')
            page.wait_for_timeout(500)
        expect(page.get_by_role('button', name=re.compile('한 명의 적을 .*공격')).first).to_be_visible()
        shot(page, '05-battle')
        browser.close()
    assert not errors, errors
    print('Real UI capture completed without browser errors.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', default='http://127.0.0.1:8785/lore/')
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/design/mobile-ui/implemented')
    args = parser.parse_args()
    capture(args.url, args.output)
