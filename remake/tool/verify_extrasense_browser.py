#!/usr/bin/env python3
"""Check the title fullscreen control and actual mobile ESP continuation."""
import argparse
import json
import re
import shutil
from pathlib import Path

from playwright.sync_api import expect, sync_playwright

from verify_jrpg_browser import ROOT, capture, open_saved_game


def reveal(page, button):
    # Flutter paints its scrollable in the canvas. Scroll that canvas rather
    # than changing only the hidden accessibility DOM's scroll position.
    for _ in range(12):
        rect = button.bounding_box()
        footer = page.get_by_role('button', name='닫기', exact=True).bounding_box()
        if rect and 105 <= rect['y'] and rect['y'] + rect['height'] <= footer['y']:
            break
        page.mouse.move(page.viewport_size['width'] / 2, footer['y'] / 2)
        page.mouse.wheel(0, 160 if rect['y'] + rect['height'] > footer['y'] else -160)
        page.wait_for_timeout(250)
    button.click()


def use_esp(page, kind):
    page.get_by_role('button', name=re.compile('일행의 건강 상태를 본다')).click()
    page.get_by_role('dialog').get_by_text('Merlin', exact=True).first.click()
    reveal(page, page.get_by_role('button', name='초감각', exact=True))
    reveal(page, page.get_by_role('button', name='초감각 사용', exact=True))
    page.get_by_role('dialog').get_by_role('button', name=re.compile('^' + kind)).click()


def verify(url, output):
    fixture = json.loads((ROOT / 'test/fixtures/dos_first_field_battle.json').read_text())
    party = fixture['initial']['records']
    for member in party:
        member.update(esp=100, espLevel=3)
    save = dict(schemaVersion=2, slot=1, slotName='본 게임 데이타',
                timestamp='2026-10-10T00:00:00Z', mapId=1, mapTitle='GROUND1',
                playerX=50, playerY=50, gold=2000, food=100,
                party=party, flags={'etc7': 1, 'etc8': 5}, etc={},
                mapTiles=[42] * 10000, consumedScripts=[])
    output.mkdir(parents=True, exist_ok=True)
    results = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=shutil.which('chromium'),
                                             headless=True, args=['--no-sandbox'])
        try:
            for width, height in [(390, 844), (360, 480)]:
                context = browser.new_context(viewport=dict(width=width, height=height))
                page = context.new_page()
                errors = []
                page.on('pageerror', lambda error: errors.append(str(error)))
                page.add_init_script('localStorage.setItem("flutter.lore_save_slot_1", '
                                     + json.dumps(json.dumps(json.dumps(save, ensure_ascii=False))) + ');')
                page.goto(url)
                page.locator('flt-semantics-placeholder').wait_for(timeout=60000)
                page.locator('flt-semantics-placeholder').evaluate('(element) => element.click()')
                fullscreen = page.get_by_role('button', name=re.compile('^전체화면 전환'))
                expect(fullscreen).to_be_visible(timeout=20000)
                original_y = fullscreen.bounding_box()['y']
                page.mouse.move(width / 2, height / 2)
                page.mouse.wheel(0, 240)
                page.wait_for_timeout(400)
                assert abs(fullscreen.bounding_box()['y'] - original_y) < 1
                capture(page, output / f'title-fullscreen-{width}.png')
                fullscreen.click()
                page.wait_for_function('document.fullscreenElement !== null')
                expect(fullscreen).to_be_enabled()
                fullscreen.click()
                page.wait_for_function('document.fullscreenElement === null')
                open_saved_game(page, output)
                expect(page.get_by_role('button', name=re.compile('당신의 명령을 고르시오'))).to_be_visible(timeout=20000)

                use_esp(page, '천리안')
                page.get_by_role('dialog').get_by_role('button', name='북쪽', exact=True).click()
                expect(page.get_by_role('button', name='다음 보기', exact=True)).to_be_visible()
                capture(page, output / f'clairvoyance-{width}.png')
                page.get_by_role('button', name='다음 보기', exact=True).click()
                page.get_by_role('button', name='보기 종료', exact=True).click()
                expect(page.get_by_role('button', name='다음 보기', exact=True)).to_have_count(0)

                use_esp(page, '투시')
                expect(page.get_by_text('투시 · 주변 지도 보기', exact=True)).to_be_visible()
                capture(page, output / f'see-through-{width}.png')
                page.get_by_role('button', name='탐험으로 돌아가기', exact=True).click()

                use_esp(page, '독심')
                expect(page.get_by_text(re.compile('인물을 만나 대화하세요'))).to_be_visible()
                capture(page, output / f'mind-read-{width}.png')
                page.get_by_role('button', name='탐험으로 돌아가기', exact=True).click()
                expect(page.get_by_role('button', name=re.compile('당신의 명령을 고르시오'))).to_be_visible()
                assert not errors, errors
                results.append(dict(width=width, height=height, title_fullscreen=True,
                                    fullscreen_toggle=True, fullscreen_pinned=True,
                                    clairvoyance_touch=True, see_through_touch=True,
                                    mind_read_feedback=True, page_errors=errors))
                context.close()
        except Exception:
            page.screenshot(path=str(output / f'failure-{width}.png'))
            (output / f'failure-{width}.html').write_text(page.content())
            raise
        finally:
            browser.close()
    (output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps(results))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', default='http://127.0.0.1:8785/lore/')
    parser.add_argument('--output', type=Path, default=ROOT / 'build/verification/extrasense-browser')
    args = parser.parse_args()
    verify(args.url, args.output)
