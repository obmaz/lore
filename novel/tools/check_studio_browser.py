"""Exercise the offline author workspace; no hosting, game, or external requests."""
import argparse
import json
from pathlib import Path

from materials import ROOT


def check(screenshots=None):
    from playwright.sync_api import sync_playwright
    path=ROOT/'writing/studio/generated/index.html'
    report=[]
    with sync_playwright() as playwright:
        browser=playwright.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
        for width,height in [(390,844),(1280,900)]:
            page=browser.new_page(viewport={'width':width,'height':height})
            errors,requests=[],[]
            page.on('pageerror',lambda error:errors.append(str(error)))
            page.on('request',lambda request:requests.append(request.url))
            page.set_content(path.read_text(encoding='utf-8'))
            page.evaluate('document.fonts.ready')
            assert page.locator('#workspace').is_hidden()
            assert page.locator('#navigation button').count()==8
            assert page.locator('#navigation button:disabled').count()==8
            page.get_by_role('button',name='작가용 제작실 열기',exact=True).click()
            assert page.locator('#workspace').is_visible()
            assert page.locator('.stat').count()==4
            if screenshots:
                screenshots.mkdir(parents=True,exist_ok=True)
                page.screenshot(path=str(screenshots/f'studio-home-{width}.png'))
            def view(key):
                page.locator(f'#navigation [data-view="{key}"]').click()
                assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'),key+' overflows'
                assert page.locator('#view-title').is_visible()
            view('reading')
            frame=page.frame_locator('#document-frame')
            frame.locator('#choices button').first.wait_for()
            assert frame.locator('h1').count()==1
            assert frame.get_by_role('button').count()>0
            frame.locator('#choices button').first.click()
            assert not errors,errors
            page.locator('#document-select').select_option('menace-01.html')
            frame.locator('h2').first.wait_for()
            assert '돌아오겠다는 말' in frame.locator('body').inner_text()
            view('outline')
            page.locator('#chapter-select').select_option('chapter09')
            assert page.locator('.unit').count()==7
            view('graph')
            assert page.locator('#chapter-select').input_value()=='chapter09'
            assert page.locator('#chapter-diagram svg').count()==1
            if screenshots:
                page.screenshot(path=str(screenshots/f'studio-graph-{width}.png'))
            page.locator('#open-overview-graph').click()
            assert page.locator('#return-chapter-graph').is_visible()
            page.locator('#return-chapter-graph').click()
            view('branches')
            page.frame_locator('#document-frame').locator('h1').wait_for()
            assert '선택' in page.frame_locator('#document-frame').locator('body').inner_text()
            view('order')
            assert page.locator('[data-row-kind="main"]:visible').count()==88
            assert page.locator('[data-row-kind="choice"]:visible').count()==0
            page.locator('#order-detail').check()
            assert page.locator('[data-row-kind="choice"]:visible').count()>0
            page.locator('[data-row-kind="main"] [data-source]').first.click()
            assert '/main_content' in page.locator('#source-location').inner_text()
            assert page.locator('#source-content').inner_text().strip().startswith('[')
            page.locator('#source-whole').click()
            assert page.locator('#source-content').inner_text().strip().startswith('{')
            view('settings')
            assert page.locator('.setting').count()==53
            page.locator('#setting-search').fill('서진')
            assert page.locator('.setting').count()>=1
            page.locator('.setting>summary').filter(has_text='서진').first.click()
            assert page.get_by_text('창작 추가',exact=True).count()>0
            page.locator('#setting-search').fill('no-such-setting-123')
            assert page.locator('.empty').is_visible()
            page.locator('#setting-search').fill('')
            page.locator('#setting-category').select_option('equipment')
            assert page.locator('.setting').count()==24
            page.locator('#setting-search').fill('사냥 활')
            assert page.locator('.setting').count()==1
            page.locator('.setting>summary').first.click()
            page.locator('.setting [data-source]').first.click()
            assert 'reference/equipment.json' in page.locator('#source-location').inner_text()
            view('sources')
            page.locator('#source-select').select_option('reference/names.json')
            assert '서진' in page.locator('#source-content').inner_text()
            with page.expect_download() as download:
                page.locator('#download-json').click()
            assert download.value.suggested_filename=='names.json'
            assert not errors,errors
            assert not requests,requests
            assert page.get_by_role('button',name='인쇄 / PDF 저장').count()==0
            report.append({'width':width,'views':8,'external_requests':len(requests),'errors':len(errors),'reading_interaction':True,'source_json_download':True})
            page.close()
        browser.close()
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--screenshots',type=Path)
    args=parser.parse_args()
    print(json.dumps(check(args.screenshots),ensure_ascii=False,indent=2))
