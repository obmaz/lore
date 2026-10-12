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
        for width,height in [(390,844),(820,900),(1280,900)]:
            page=browser.new_page(viewport={'width':width,'height':height})
            errors,requests=[],[]
            page.on('pageerror',lambda error:errors.append(str(error)))
            page.on('request',lambda request:requests.append(request.url))
            page.set_content(path.read_text(encoding='utf-8'))
            page.evaluate('document.fonts.ready')
            assert page.locator('#workspace').is_hidden()
            assert page.locator('#navigation button').count()==7
            assert page.locator('#navigation button:disabled').count()==7
            assert page.locator('#navigation [data-view="branches"]').count()==0
            page.get_by_role('button',name='작가용 제작실 열기',exact=True).click()
            assert page.locator('#workspace').is_visible()
            assert page.locator('.stat').count()==4
            assert page.locator('#view-title').evaluate('(e)=>parseFloat(getComputedStyle(e).fontSize)')<=24
            assert page.locator('#navigation button').first.evaluate('(e)=>parseFloat(getComputedStyle(e).fontSize)')<=13
            if width==390:
                assert page.locator('#navigation button').first.bounding_box()['height']>=44
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
            page.go_back()
            page.wait_for_function('document.getElementById("document-select")?.value === "chapter01-interactive.html"')
            page.go_forward()
            page.wait_for_function('document.getElementById("document-select")?.value === "menace-01.html"')
            view('outline')
            page.locator('#chapter-select').select_option('chapter09')
            assert page.locator('.unit').count()==7
            view('graph')
            assert page.locator('#chapter-select').input_value()=='chapter09'
            assert page.locator('#chapter-diagram svg').count()==1
            assert '질문' in page.locator('#chapter-diagram svg').text_content()
            assert '두 봉인을 모두 풀어야 한다' in page.locator('#chapter-diagram svg').text_content()
            assert '늪 속 장치가 있는 동굴부터 찾는다' in page.locator('#chapter-diagram svg').text_content()
            assert page.locator('.branch-questions').count()==0
            assert page.get_by_role('heading',name='이 장의 질문과 선택',exact=True).count()==0
            if screenshots:
                page.screenshot(path=str(screenshots/f'studio-graph-{width}.png'))
            page.locator('#open-overview-graph').click()
            assert page.locator('#return-chapter-graph').is_visible()
            page.locator('#return-chapter-graph').click()
            page.locator('[data-graph-panel="rules"]').click()
            assert page.locator('#chapter-select').input_value()=='chapter09'
            assert page.locator('#branch-details .branch-rule').count()==1
            assert page.locator('#chapter-diagram').count()==0
            page.locator('.branch-rule>summary').first.click()
            assert '두 봉인을 모두 풀어야 한다' in page.locator('#branch-details').inner_text()
            assert page.locator('.branch-option').count()==2
            assert '두 목표를 모두 마친 뒤 합류' in page.locator('#branch-details').inner_text()
            page.locator('.branch-rule [data-source]').first.click()
            assert '/decisions/' in page.locator('#source-location').inner_text()
            page.go_back()
            page.locator('[data-graph-panel="rules"][aria-pressed="true"]').wait_for()
            assert page.locator('#chapter-select').input_value()=='chapter09'
            if screenshots:page.screenshot(path=str(screenshots/f'studio-branch-details-{width}.png'))
            page.go_back()
            page.locator('#chapter-diagram').wait_for()
            page.go_forward()
            page.locator('#branch-details').wait_for()
            page.locator('#chapter-select').select_option('chapter01')
            assert page.locator('#branch-details .branch-rule').count()==2
            page.locator('#chapter-select').select_option('chapter02')
            assert page.locator('#branch-details .branch-rule').count()==0
            assert '이 장에는 구현된 선택이 없습니다' in page.locator('#branch-details').inner_text()
            page.locator('[data-graph-panel="diagram"]').click()
            assert page.locator('#chapter-select').input_value()=='chapter02'
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
            assert page.locator('.setting-list-item').count()==53
            page.locator('#setting-search').fill('서진')
            assert page.locator('.setting-list-item').count()>=1
            page.locator('[data-setting="characters/protagonist"]').click()
            assert page.locator('.setting-detail-head h2').inner_text()=='서진'
            assert page.locator('.setting-detail-head h2').evaluate('(e)=>parseFloat(getComputedStyle(e).fontSize)')<=22
            assert page.locator('.fact-value').first.evaluate('(e)=>parseFloat(getComputedStyle(e).fontSize)')==14
            assert page.get_by_text('창작 추가',exact=True).count()>0
            page.locator('[data-setting-tab="원작 정보"]').click()
            page.go_back()
            page.locator('[data-setting-tab="핵심 설정"][aria-pressed="true"]').wait_for()
            if screenshots:page.screenshot(path=str(screenshots/f'studio-character-{width}.png'))
            page.locator('#setting-list-back').click()
            page.locator('#setting-search').fill('매드 조')
            page.locator('[data-setting="characters/mad_joe"]').click()
            basic=page.locator('.fact-grid').first
            assert basic.locator('.fact-card').count()==7
            basic_height=round(basic.bounding_box()['height'],1)
            assert basic_height<=360,('short facts waste vertical space',width,basic_height)
            assert all(h<=60 for h in basic.locator('.fact-card').evaluate_all('(es)=>es.map(e=>e.getBoundingClientRect().height)'))
            assert page.locator('.setting-detail-head').bounding_box()['height']<=90
            assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'),'dense settings overflow'
            assert basic.locator('[data-field="age"] .fact-status').inner_text()==''
            evidence=basic.locator('[data-field="age"] .fact-evidence')
            evidence.locator('summary').focus()
            page.keyboard.press('Enter')
            assert evidence.locator('.fact-evidence-body').is_visible()
            assert '검토 상태: 미상' in evidence.inner_text()
            assert '근거 없음' in evidence.inner_text()
            evidence.locator('summary').click()
            assert not evidence.locator('.fact-evidence-body').is_visible()
            if screenshots:page.screenshot(path=str(screenshots/f'studio-dense-settings-{width}.png'))
            page.locator('[data-setting-tab="관계 · 공개"]').click()
            assert '공개 정책' in page.locator('.setting-content').inner_text()
            page.locator('[data-setting-tab="핵심 설정"]').click()
            page.locator('#setting-list-back').click()
            page.locator('#setting-search').fill('no-such-setting-123')
            assert page.locator('.empty').is_visible()
            page.locator('#setting-search').fill('')
            page.locator('#setting-category').select_option('equipment')
            assert page.locator('.setting-list-item').count()==24
            page.locator('#setting-search').fill('사냥 활')
            assert page.locator('.setting-list-item').count()==1
            page.locator('.setting-list-item').first.click()
            page.locator('.setting-detail [data-source]').first.click()
            assert 'reference/equipment.json' in page.locator('#source-location').inner_text()
            page.go_back()
            page.locator('.setting-detail-head h2').wait_for()
            assert page.locator('.setting-detail-head h2').inner_text()=='사냥 활'
            assert page.locator('#setting-search').input_value()=='사냥 활'
            page.go_forward()
            page.locator('#source-content').wait_for()
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
            deep=browser.new_page(viewport={'width':width,'height':height})
            deep.set_content(path.read_text(encoding='utf-8'))
            deep.evaluate('location.hash="#/settings?category=equipment&item=equipment%2Fstory_bow"')
            deep.locator('#open-studio').click()
            assert deep.locator('.setting-detail-head h2').inner_text()=='사냥 활'
            assert deep.locator('#setting-category').input_value()=='equipment'
            deep.close()
            legacy=browser.new_page(viewport={'width':width,'height':height})
            legacy.set_content(path.read_text(encoding='utf-8'))
            legacy.evaluate('location.hash="#/branches?chapter=chapter09"')
            legacy.locator('#open-studio').click()
            assert legacy.locator('[data-graph-panel="rules"][aria-pressed="true"]').is_visible()
            assert legacy.locator('#chapter-select').input_value()=='chapter09'
            assert '#/graph?' in legacy.url
            legacy.close()
            report.append({'width':width,'views':7,'external_requests':len(requests),'errors':len(errors),'reading_interaction':True,'source_json_download':True,'browser_back_forward':True,'graph_questions':True,'unified_branch_details':True,'legacy_branch_bookmark':True,'compact_type':True,'dense_basic_height':basic_height,'evidence_keyboard_toggle':True})
            page.close()
        browser.close()
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--screenshots',type=Path)
    args=parser.parse_args()
    print(json.dumps(check(args.screenshots),ensure_ascii=False,indent=2))
