#!/usr/bin/env python3
"""Verify source pages and all four lords' mobile dialogue scripts."""
import argparse
import json
import re
import shutil
from pathlib import Path

from playwright.sync_api import expect, sync_playwright

from verify_jrpg_browser import ROOT, capture, open_saved_game

CONVERSATIONS = {
    'remains': (6, 63, 75, 50, 0, '아래로 이동', [
        '당신이 한 유골 앞에 섰을때 이상한 느낌과',
        '안녕하시오. 대담한 용사여.',
        '아참, 그리고 내가 죽기전에 여기에 뭔가를']),
    'lord': (6, 51, 29, 10, 0, '위로 이동', [
        '나는 Lord Ahn 이오.',
        '이 세계는 내가 통치하는 동안에는 무척 평화',
        'Necromancer 의 영향력은 이미 LORE 대륙까지']),
    'lord_reward': (6, 51, 29, 10, 4, '위로 이동', [
        '당신들의 성공을 축하하오 !!',
        '드디어 나는 당신들의 능력을 믿을수 있게 되']),
    'lastditch': (7, 38, 18, 13, 2, '위로 이동', [
        '당신의 성공에 경의를 표하오.',
        "이 성의 북동쪽에 'GROUND GATE' 라는것이 있"]),
    'gaia': (9, 42, 26, 14, 2, '위로 이동', [
        '오, 당신은 황금의 봉인을 찾았군요 !',
        '그러나, 이 대륙에는 아직 위험한 장소가 많']),
    'water': (10, 25, 19, 15, 2, '위로 이동', [
        'Hidra를 물리치다니 ... 대단한 능력이오.',
        '이번에는 대륙의 동쪽에 있는 LOCKUP 동굴속']),
}


def speech(page, text):
    # One rich paragraph now wraps at the viewport and uses corrected spacing.
    # Source characters and page order must still match independently of spaces.
    chars = re.sub(r'\s+', '', text)
    return page.get_by_text(re.compile(r'\s*'.join(map(re.escape, chars))))


def verify(url, output, conversation):
    fixture = json.loads((ROOT / 'test/fixtures/dos_first_field_battle.json').read_text())
    map_id, x, y, byte, stage, direction, lines = CONVERSATIONS[conversation]
    save = dict(schemaVersion=2, slot=1, slotName='본 게임 데이타',
                timestamp='2026-10-10T00:00:00Z', mapId=map_id, mapTitle='TOWN',
                playerX=x, playerY=y, gold=2000, food=100,
                party=fixture['initial']['records'], flags={'etc7': 0, f'etc{byte}': stage},
                etc={}, consumedScripts=[])
    output.mkdir(parents=True, exist_ok=True)
    results = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=shutil.which('chromium'),
                                             headless=True, args=['--no-sandbox'])
        try:
            for width, height in [(390, 844), (360, 480)]:
                context = browser.new_context(viewport=dict(width=width, height=height), has_touch=True)
                page = context.new_page()
                errors, failed_assets = [], []
                page.on('pageerror', lambda error: errors.append(str(error)))
                page.on('response', lambda response: failed_assets.append(response.url)
                        if response.status >= 400 and '/assets/' in response.url else None)
                page.add_init_script('localStorage.setItem("flutter.lore_save_slot_1", '
                                     + json.dumps(json.dumps(json.dumps(save, ensure_ascii=False))) + ');')
                page.goto(url)
                page.locator('flt-semantics-placeholder').wait_for(timeout=60000)
                page.locator('flt-semantics-placeholder').evaluate('(element) => element.click()')
                open_saved_game(page, output)
                expect(page.get_by_role('button', name=re.compile('당신의 명령을 고르시오'))).to_be_visible(timeout=20000)
                capture(page, output / f'field-before-dialogue-{width}.png')
                move = page.get_by_role('button', name=direction, exact=True)
                move_box = move.bounding_box()
                page.touchscreen.tap(move_box['x'] + move_box['width'] / 2,
                                     move_box['y'] + move_box['height'] / 2)
                for index, line in enumerate(lines):
                    expect(speech(page, line)).to_be_visible(timeout=20000)
                    if index:
                        expect(speech(page, lines[index - 1])).to_have_count(0)
                    expect(page.get_by_role('dialog')).to_have_count(1)
                    button = page.get_by_role('button', name='계속', exact=True)
                    expect(button).to_be_enabled()
                    box = button.bounding_box()
                    assert box['y'] + box['height'] <= height
                    capture(page, output / f'dialogue-page-{index + 1}-{width}.png')
                    page.touchscreen.tap(box['x'] + box['width'] / 2,
                                         box['y'] + box['height'] / 2)
                expect(page.get_by_role('button', name='계속', exact=True)).to_have_count(0)
                expect(page.get_by_role('dialog')).to_have_count(0)
                expect(page.get_by_role('button', name=re.compile('당신의 명령을 고르시오'))).to_be_visible()
                capture(page, output / f'dialogue-finished-{width}.png')
                assert not errors and not failed_assets, (errors, failed_assets)
                results.append(dict(width=width, height=height, conversation=conversation, pages=len(lines), completed=True))
                context.close()
        except Exception:
            capture(page, output / 'failure.png')
            raise
        finally:
            browser.close()
    (output / 'dialogue-browser-results.json').write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps(results))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', default='http://127.0.0.1:8785/lore/')
    parser.add_argument('--output', type=Path, default=ROOT / 'build/verification/dialogue')
    parser.add_argument('--conversation', choices=['all', *CONVERSATIONS], default='remains')
    args = parser.parse_args()
    if args.conversation == 'all':
        for conversation in CONVERSATIONS:
            verify(args.url, args.output / conversation, conversation)
    else:
        verify(args.url, args.output, args.conversation)
