#!/usr/bin/env python3
"""Exercise modern encounter -> automatic battle -> reward -> field in Chromium.

Uses a local synthetic high-level save for repeatable UI smoke coverage. It is
not DOS numeric parity evidence; native replay fixtures cover that separately.
"""
import argparse
import json
import re
import shutil
from pathlib import Path

from playwright.sync_api import expect, sync_playwright

ROOT = Path(__file__).resolve().parents[1]


def capture(page, path):
    # Semantics can precede the WASM canvas frame and font upload. Capture the
    # settled screen, not the transient blank frame after a route transition.
    page.wait_for_timeout(600)
    page.screenshot(path=str(path))


def open_saved_game(page, output):
    title_load = page.get_by_role('button', name='저장 불러오기', exact=True).or_(
        page.get_by_role('button', name='2] 이전의 게임을 재개 시킴', exact=True))
    # Main's source title animation accepts a skip key before showing choices.
    for _ in range(30):
        if title_load.count():
            break
        page.keyboard.press('ArrowLeft')
        page.wait_for_timeout(300)
    title_load.click()
    expect(page.get_by_role('button', name=re.compile('^본 게임 데이타'))).to_be_enabled()
    capture(page, output / f'title-save-{page.viewport_size["width"]}.png')
    page.get_by_role('button', name=re.compile('^본 게임 데이타')).click()


def verify(url, output):
    fixture = json.loads((ROOT / 'test/fixtures/dos_first_field_battle.json').read_text())
    party = fixture['initial']['records']
    for member in party:
        member.update(hp=500, sp=500, endurance=100, battleLevel=5,
                      magicLevel=5, accArms=20, accMagic=20, strength=80,
                      weaPower=30, mentality=50, agility=30, ac=10,
                      dead=0, unconscious=0, poison=0)
    flags = {f'etc{i+1}': value for i, value in enumerate(fixture['initial']['partyRecord']['etc'])}
    flags.update(etc7=1, etc8=5)
    save = dict(schemaVersion=2, slot=1, slotName='본 게임 데이타',
                timestamp='2026-10-08T00:00:00Z', mapId=1, mapTitle='GROUND1',
                playerX=20, playerY=19, gold=2000, food=100,
                party=party, flags=flags, etc={}, mapTiles=[42] * 10000,
                consumedScripts=[])
    output.mkdir(parents=True, exist_ok=True)
    results = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=shutil.which('chromium'),
                                              headless=True, args=['--no-sandbox'])
        try:
            for width, height in [(390, 844), (360, 480)]:
                context = browser.new_context(viewport=dict(width=width, height=height))
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
                expect(page.get_by_role('button', name='당신의 명령을 고르시오 ===>')).to_be_visible(timeout=20000)
                settings = page.get_by_role('button', name='앱 설정', exact=True)
                fullscreen = page.get_by_role('button', name='전체화면 전환', exact=True)
                assert settings.bounding_box()['x'] < fullscreen.bounding_box()['x']
                settings.click()
                expect(page.get_by_role('button', name='닫기', exact=True)).to_be_visible()
                expect(page.get_by_role('switch', name='소리', exact=True)).to_be_visible()
                page.get_by_role('button', name='닫기', exact=True).click()
                # The party hub combines status, equipment and exploration ESP.
                page.get_by_role('button', name=re.compile('일행의 건강 상태를 본다')).click()
                page.get_by_role('dialog').get_by_text('Genius Kie', exact=True).first.click()
                if height <= 500:
                    # Scroll Flutter's canvas, not only its accessibility DOM.
                    # Verify that the equipment tabs are reachable on 4:3 phones.
                    page.mouse.move(width / 2, height / 2)
                    page.mouse.wheel(0, 280)
                    page.wait_for_timeout(500)
                page.get_by_role('button', name='장비', exact=True).click()
                page.get_by_text('무기', exact=True).scroll_into_view_if_needed()
                expect(page.get_by_text('무기', exact=True)).to_be_visible()
                expect(page.get_by_text('방패', exact=True)).to_be_visible()
                capture(page, output / f'equipment-{width}.png')
                page.get_by_role('button', name='초감각', exact=True).click()
                page.get_by_role('button', name='초감각 사용', exact=True).click()
                expect(page.get_by_role('dialog').get_by_role('button', name=re.compile('^투시'))).to_be_visible()
                page.get_by_role('button', name='돌아가기', exact=True).click()
                expect(page.get_by_role('button', name='초감각 사용', exact=True)).to_be_visible()
                page.get_by_role('button', name='닫기', exact=True).click()
                page.wait_for_timeout(400)
                # Field popups must retain each parent, rather than exiting the
                # whole command on cancellation of a deeper choice.
                page.get_by_role('button', name=re.compile('당신의 명령을 고르시오')).click()
                dialog = page.get_by_role('dialog')
                dialog.get_by_role('button', name='마법을 사용한다', exact=True).click()
                dialog.get_by_role('button', name='Merlin', exact=True).click()
                dialog.get_by_role('button', name='치료 마법', exact=True).click()
                dialog.get_by_role('button', name=re.compile('^Hero')).click()
                expect(dialog.get_by_role('button', name='한명 치료', exact=True)).to_be_visible()
                capture(page, output / f'cure-child-{width}.png')
                dialog.get_by_role('button', name='돌아가기', exact=True).click()
                expect(dialog.get_by_role('button', name=re.compile('^Hero'))).to_be_visible()
                capture(page, output / f'cure-back-{width}.png')
                dialog.get_by_role('button', name='돌아가기', exact=True).click()
                expect(dialog.get_by_role('button', name='치료 마법', exact=True)).to_be_visible()
                dialog.get_by_role('button', name='돌아가기', exact=True).click()
                expect(dialog.get_by_role('button', name='Merlin', exact=True)).to_be_visible()
                dialog.get_by_role('button', name='돌아가기', exact=True).click()
                expect(dialog.get_by_role('button', name='게임 선택 상황', exact=True)).to_be_visible()
                dialog.get_by_role('button', name='닫기', exact=True).click()
                page.wait_for_timeout(400)
                page.get_by_role('button', name=re.compile('당신의 명령을 고르시오')).click()
                dialog.get_by_role('button', name='게임 선택 상황', exact=True).click()
                dialog.get_by_role('button', name='난이도 조절', exact=True).click()
                dialog.get_by_role('button', name='3 명의 적들', exact=True).click()
                dialog.get_by_role('button', name='돌아가기', exact=True).click()
                expect(dialog.get_by_role('button', name='3 명의 적들', exact=True)).to_be_visible()
                dialog.get_by_role('button', name='돌아가기', exact=True).click()
                expect(dialog.get_by_role('button', name='난이도 조절', exact=True)).to_be_visible()
                dialog.get_by_role('button', name='현재의 게임을 저장', exact=True).click()
                expect(dialog.get_by_role('button', name=re.compile('GROUND1 · 2026-10-08'))).to_be_visible()
                capture(page, output / f'save-metadata-{width}.png')
                dialog.get_by_role('button', name='돌아가기', exact=True).click()
                expect(dialog.get_by_role('button', name='현재의 게임을 저장', exact=True)).to_be_visible()
                dialog.get_by_role('button', name='돌아가기', exact=True).click()
                dialog.get_by_role('button', name='닫기', exact=True).click()
                engage = page.get_by_role('button', name='적과 교전한다', exact=True)
                for step in range(400):
                    if engage.count():
                        break
                    page.keyboard.press('ArrowRight' if step % 2 == 0 else 'ArrowLeft')
                    page.wait_for_timeout(60)
                expect(engage).to_be_visible(timeout=10000)
                expect(page.locator('[aria-label*="초원 · 적 진영"]')).to_have_count(0)
                expect(page.get_by_role('button', name=re.compile('현재 행동할 일행'))).to_have_count(0)
                page.wait_for_timeout(500)
                capture(page, output / f'encounter-{width}.png')
                engage.click()
                expect(page.get_by_role('button', name='1×', exact=True)).to_be_visible(timeout=10000)
                page.wait_for_timeout(1000)
                capture(page, output / f'battle-initial-{width}.png')
                (output / f'battle-semantics-{width}.html').write_text(page.content())
                expect(page.locator('[aria-label*="초원 · 적 진영"]')).to_have_count(0)
                expect(page.get_by_role('button', name=re.compile('현재 행동할 일행'))).to_have_count(1)
                expect(page.get_by_role('button', name=re.compile(r', 일행 [1-6], HP 500\/500'))).to_have_count(6)
                page.get_by_role('button', name='이번 전투 기록', exact=True).click()
                expect(page.get_by_text('아직 기록이 없습니다.', exact=True)).to_be_visible()
                expect(page.get_by_role('button', name='닫기', exact=True)).to_have_count(1)
                capture(page, output / f'empty-history-{width}.png')
                page.get_by_role('button', name='닫기', exact=True).click()
                selected = page.get_by_role('button', name=re.compile(', 공격 대상'))
                expect(selected).to_have_count(1)
                second = page.get_by_role('button', name=re.compile(', 적 2, HP'))
                selection_changed = False
                if second.count():
                    second.click()
                    expect(selected).to_have_accessible_name(re.compile(r', 적 2, HP'))
                    selection_changed = True
                    page.wait_for_timeout(250)
                # A cancelled picker must leave the current actor and target ready.
                page.keyboard.press('2')
                expect(page.get_by_role('dialog').get_by_role('button', name=re.compile('마법 화살'))).to_be_visible()
                capture(page, output / f'magic-picker-{width}.png')
                page.get_by_role('button', name='닫기', exact=True).click()
                expect(page.get_by_role('button', name=re.compile(', 현재 행동할 일행'))).to_have_count(1)
                # Choosing a later party slot must not skip earlier commands.
                third = page.get_by_role('button', name=re.compile(', 일행 3, HP'))
                third.click()
                expect(page.get_by_role('dialog').get_by_role('button', name='닫기', exact=True)).to_be_visible()
                capture(page, output / f'party-details-{width}.png')
                page.get_by_role('button', name='닫기', exact=True).click()
                expect(page.get_by_role('button', name=re.compile(', 현재 행동할 일행'))).to_have_accessible_name(re.compile(', 일행 3, HP'))
                page.keyboard.press('1')
                expect(page.get_by_role('button', name=re.compile(', 현재 행동할 일행'))).to_have_accessible_name(re.compile(', 일행 1, HP'))
                expect(third).to_have_accessible_name(re.compile('명령 준비 완료'))
                page.get_by_role('button', name='1×', exact=True).click()
                page.get_by_role('button', name='2×', exact=True).click()
                expect(page.get_by_role('button', name='4×', exact=True)).to_be_visible()
                capture(page, output / f'battle-{width}.png')
                result = page.get_by_role('button', name='탐험으로 돌아가기', exact=True)
                auto = page.get_by_role('button', name='일행 자동 공격', exact=True)
                for round_number in range(8):
                    if result.count():
                        break
                    expect(auto).to_be_enabled(timeout=30000)
                    page.keyboard.press('7')
                    page.wait_for_timeout(750)
                    if round_number == 0:
                        capture(page, output / f'action-{width}.png')
                    page.wait_for_timeout(6500)
                expect(result).to_be_visible(timeout=30000)
                capture(page, output / f'victory-{width}.png')
                expect(page.locator('[aria-label*="금화"]').or_(
                    page.get_by_text(re.compile('금화')))).not_to_have_count(0)
                result.click()
                expect(page.get_by_role('button', name='당신의 명령을 고르시오 ===>')).to_be_visible(timeout=20000)
                page.keyboard.press('g')
                page.get_by_role('button', name='게임을 마침', exact=True).or_(
                    page.get_by_text('게임을 마침', exact=True)).first.click()
                yes = re.compile(r'<<\s*예\s*>>')
                page.get_by_role('button', name=yes).or_(page.get_by_text(yes)).first.click()
                expect(page.get_by_role('button', name='저장 불러오기', exact=True)).to_be_visible(timeout=20000)
                capture(page, output / f'returned-title-{width}.png')
                assert not errors, errors
                assert not failed_assets, failed_assets
                results.append(dict(width=width, height=height, encounter=True,
                                    battle=True, victory=True, returned_to_field=True,
                                    target_selection_changed=selection_changed,
                                    battle_speed=4,
                                    header_buttons_swapped=True,
                                    empty_history_checked=True,
                                    app_settings_checked=True,
                                    popup_parent_navigation_checked=True,
                                    settings_partial_cancel_checked=True,
                                    cancelled_spell_keeps_actor=True,
                                    out_of_order_preparation_checked=True,
                                    returned_to_title=True,
                                    regional_backdrop='meadow',
                                    page_errors=errors, failed_assets=failed_assets))
                context.close()
        except Exception:
            page.screenshot(path=str(output / f'failure-{width}.png'))
            (output / f'failure-{width}.html').write_text(page.content())
            raise
        finally:
            browser.close()
    (output / 'results.json').write_text(json.dumps(results, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps(results, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', default='http://127.0.0.1:8785/lore/')
    parser.add_argument('--output', type=Path, default=ROOT / 'build/verification/jrpg-browser')
    args = parser.parse_args()
    verify(args.url, args.output)
