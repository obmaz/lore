#!/usr/bin/env python3
"""Exercise the complete mobile creation flow in the release WASM canvas."""
import argparse
import json
import re
import shutil
from pathlib import Path

from playwright.sync_api import expect, sync_playwright

from verify_jrpg_browser import ROOT, capture


def tap(page, control):
    expect(control).to_be_enabled()
    rect = control.bounding_box()
    page.touchscreen.tap(rect['x'] + rect['width'] / 2,
                         rect['y'] + rect['height'] / 2)
    page.wait_for_timeout(80)


def reveal(page, control):
    for _ in range(30):
        footer = page.get_by_role('button', name=re.compile('^(이전|시작 화면)$')).bounding_box()
        # Flutter omits fully clipped children from its accessibility tree.
        rect = control.bounding_box() if control.count() else None
        if rect and 86 <= rect['y'] and rect['y'] + rect['height'] <= footer['y']:
            # Test mobile taps on the canvas, without desktop tooltip hover.
            tap(page, control)
            return
        page.mouse.move(page.viewport_size['width'] / 2, (86 + footer['y']) / 2)
        page.mouse.wheel(0, 130 if rect is None or rect['y'] + rect['height'] > footer['y'] else -130)
        page.wait_for_timeout(120)
    raise AssertionError(f'Control unreachable: {control}')


def verify(url, output):
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
                page.goto(url)
                page.locator('flt-semantics-placeholder').wait_for(timeout=60000)
                page.locator('flt-semantics-placeholder').evaluate('(element) => element.click()')
                page.get_by_text('새로운 모험', exact=True).click()
                expect(page.get_by_role('textbox')).to_be_visible(timeout=20000)
                reveal(page, page.get_by_role('textbox'))
                page.get_by_role('textbox').fill('별빛 영웅')
                reveal(page, page.get_by_role('button', name=re.compile('^여성')))
                capture(page, output / f'creation-name-{width}.png')
                tap(page, page.get_by_role('button', name='성향 알아보기', exact=True))
                capture(page, output / f'creation-question-{width}.png')
                data = json.loads((ROOT / 'assets/data/creation.json').read_text())
                answers = [1] + [0] * 9
                first_answer = re.sub(r'^\s*\d+\]\s*', '', data['questions'][0]['options'][0]['text'])
                reveal(page, page.get_by_role('button', name=first_answer, exact=True))
                tap(page, page.get_by_role('button', name='이전', exact=True))
                expect(page.get_by_text('질문 1 / 10', exact=True)).to_be_visible()
                for index, answer in enumerate(answers):
                    text = re.sub(r'^\s*\d+\]\s*', '', data['questions'][index]['options'][answer]['text'])
                    text = re.sub(r'\s+', ' ', text).strip()
                    reveal(page, page.get_by_role('button', name=text, exact=True))
                expect(page.get_by_text('능력치 배분', exact=True)).to_be_visible()
                for ability in ['민첩성', '정확성']:
                    plus = page.get_by_role('button', name=re.compile('^' + ability + ' 늘리기'))
                    reveal(page, plus)
                    for _ in range(19):
                        reveal(page, plus)
                    expect(plus).to_be_disabled()
                page.mouse.move(width / 2, height / 2)
                page.mouse.wheel(0, -2000)
                capture(page, output / f'creation-stats-{width}.png')
                tap(page, page.get_by_role('button', name='직업 선택하기', exact=True))
                capture(page, output / f'creation-classes-{width}.png')
                reveal(page, page.get_by_role('button', name=re.compile('^떠돌이')))
                tap(page, page.get_by_role('button', name='동료 선택하기', exact=True))
                capture(page, output / f'creation-companions-{width}.png')
                reveal(page, page.get_by_role('button', name=re.compile(r'^Hercules\b(?! 능력)')))
                reveal(page, page.get_by_role('button', name=re.compile('^Hercules 능력 보기')))
                capture(page, output / f'creation-profile-{width}.png')
                tap(page, page.get_by_role('button', name='돌아가기', exact=True))
                expect(page.get_by_text('선택한 동료 1 / 4', exact=True)).to_be_visible()
                reveal(page, page.get_by_role('button', name=re.compile(r'^Hercules\b(?! 능력)')))
                for name in ['Betelgeuse', 'Merlin', 'Titan', 'Hercules']:
                    reveal(page, page.get_by_role('button', name=re.compile('^' + name + r'\b(?! 능력)')))
                tap(page, page.get_by_role('button', name='모험 시작하기', exact=True))
                expect(page.get_by_role('button', name=re.compile('당신의 명령을 고르시오'))).to_be_visible(timeout=20000)
                raw = page.evaluate('localStorage.getItem("flutter.lore_save_slot_1")')
                saved = json.loads(json.loads(raw))
                members = saved['party']
                names = [member['name'] for member in members]
                assert names == ['별빛 영웅', 'Hercules', 'Titan', 'Merlin', 'Betelgeuse', ''], names
                assert members[0]['agility'] == 20 and members[0]['accArms'] == 20
                assert not errors and not failed_assets, (errors, failed_assets)
                results.append(dict(width=width, height=height, completed=True, source_slot_order=True))
                context.close()
        except Exception:
            capture(page, output / 'failure.png')
            raise
        finally:
            browser.close()
    (output / 'creation-browser-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(results, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', default='http://127.0.0.1:8785/lore/')
    parser.add_argument('--output', type=Path, default=ROOT / 'build/verification/creation')
    args = parser.parse_args()
    verify(args.url, args.output)
