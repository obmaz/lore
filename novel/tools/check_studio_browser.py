"""Exercise the offline author workspace; no hosting, game, or external requests."""
import argparse
import json
from pathlib import Path

from materials import ROOT


def check(screenshots=None,bundle=None):
    from playwright.sync_api import sync_playwright
    path=Path(bundle) if bundle else ROOT/'writing/studio/generated/index.html'
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
            page.locator('#document-select').select_option('side-adventures.html')
            frame.locator('#side-choices button').first.wait_for()
            side_data = json.loads(frame.locator('#side-data').text_content())
            assert len(side_data['stories']) == 30
            assert frame.locator('#side-next').is_hidden()
            # Revealing a hidden navigation button cannot bypass the private choice gate.
            frame.locator('#side-next').evaluate('(e)=>{e.hidden=false;e.click()}')
            assert frame.locator('#side-progress').inner_text().startswith('1 / 15')
            modes, approaches = {}, {}
            for index, chapter in enumerate(side_data['chapters']):
                assert frame.locator('#side-progress').inner_text().startswith(str(index+1)+' / 15')
                while frame.locator('#side-choices button').count():
                    buttons=frame.locator('#side-choices button')
                    assert buttons.count()==2
                    sid=buttons.first.get_attribute('data-story')
                    story=next(s for s in side_data['stories'] if s['id']==sid)
                    assert story['chapter_id']==chapter['id']
                    kind=buttons.first.get_attribute('data-choice-kind')
                    if kind=='entry':
                        mode='take' if 'approach' in story or len(modes)%2==0 else 'skip'
                        frame.locator(f'[data-side-choice="{mode}"]').click()
                        modes[sid]=mode
                        scene=frame.locator(f'[data-side-story="{sid}"]')
                        assert story['participate' if mode=='take' else 'skip'][:40] in scene.inner_text()
                        if mode=='skip':assert frame.locator(f'[data-side-approach="{sid}"]').count()==0
                    else:
                        assert modes[sid]=='take'
                        frame.locator('#side-next').evaluate('(e)=>{e.hidden=false;e.click()}')
                        assert frame.locator('#side-progress').inner_text().startswith(str(index+1)+' / 15')
                        option=story['approach']['options'][len(approaches)%2]
                        frame.locator(f'[data-side-choice="{option["id"]}"]').click()
                        approaches[sid]=option['id']
                        assert option['body'][:40] in frame.locator(f'[data-side-approach="{sid}"]').inner_text()
                assert frame.locator('#side-choices button').count() == 0
                assert frame.locator('.core-outcome').count() > 0
                for remembered in side_data['stories']:
                    if remembered['reaction_unit'].startswith(chapter['id']+'/') and remembered['id'] in modes:
                        memory = frame.locator(f'[data-side-memory="{remembered["id"]}"]')
                        assert memory.get_attribute('data-mode') == modes[remembered['id']]
                        text = remembered['on_participate' if modes[remembered['id']] == 'take' else 'on_skip']
                        if remembered['id'] in approaches:
                            text=next(o['reaction'] for o in remembered['approach']['options'] if o['id']==approaches[remembered['id']])
                            assert memory.get_attribute('data-approach')==approaches[remembered['id']]
                        assert text[:40] in memory.inner_text()
                if index < 14: frame.locator('#side-next').click()
            assert frame.locator('#side-complete').is_visible()
            assert frame.locator('#side-next').is_hidden()
            frame.locator('#side-prev').click()
            assert frame.locator('#side-choices button').count() == 0
            frame.locator('#side-restart').click()
            assert frame.locator('#side-progress').inner_text() == '1 / 15장 · 곁가지 0개 선택 · 해결 방법 0개'
            assert frame.locator('[data-side-memory]').count() == 0
            assert frame.locator('#side-choices button').count() == 2
            # All-skip traversal never asks for a nested method or invents its memory.
            for index in range(15):
                while frame.locator('#side-choices button').count():
                    assert frame.locator('#side-choices button').first.get_attribute('data-choice-kind')=='entry'
                    frame.locator('[data-side-choice="skip"]').click()
                assert frame.locator('[data-side-approach]').count()==0
                assert all(v=='skip' for v in frame.locator('[data-side-memory]').evaluate_all('(es)=>es.map(e=>e.dataset.mode)'))
                if index<14:frame.locator('#side-next').click()
            assert frame.locator('#side-complete').is_visible()
            view('outline')
            page.locator('#chapter-select').select_option('chapter09')
            assert page.locator('.unit').count()==7
            view('graph')
            assert page.locator('#chapter-select').input_value()=='chapter09'
            assert page.locator('[data-graph-panel="diagram"]').get_attribute('aria-pressed')=='true'
            for index in range(1,16):
                page.locator('#chapter-select').select_option(f'chapter{index:02}')
                assert page.locator('#chapter-diagram svg').count()==1
                assert page.locator('#chapter-diagram [data-node-kind="decision"]').count()>=2
                canvas=page.locator('#chapter-diagram').bounding_box()
                first=page.locator('#chapter-diagram [data-node-kind="unit"] rect').first.bounding_box()
                assert first['x']<canvas['x']+canvas['width'] and first['x']+first['width']>canvas['x']
                node=page.locator('#chapter-diagram [data-node-kind="decision"]').first
                node.focus();page.keyboard.press('Enter')
                assert page.locator('#graph-selection').is_visible()
                assert page.locator('#graph-selection .graph-selection-body').inner_text().strip()
                assert page.locator('#graph-selection [data-flow-focus]').count()>=2
                assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
                page.keyboard.press('Escape')
                assert page.locator('#graph-selection').is_hidden()
                main=page.locator('#chapter-diagram [data-node-kind="unit"]').first
                main.locator('rect').click()
                assert '목표' in page.locator('#graph-selection').inner_text()
                assert '다음 행동의 이유' in page.locator('#graph-selection').inner_text()
                page.keyboard.press('Escape')
            page.locator('#chapter-select').select_option('chapter09')
            if screenshots:page.screenshot(path=str(screenshots/f'studio-chapter-graph-{width}.png'))
            page.locator('[data-graph-panel="timeline"]').click()
            assert page.locator('#chapter-diagram svg').count()==0
            assert '질문' in page.locator('#chapter-diagram').inner_text()
            assert '두 봉인을 모두 풀어야 한다' in page.locator('#chapter-diagram').inner_text()
            assert '늪 속 장치가 있는 동굴부터 찾는다' in page.locator('#chapter-diagram').inner_text()
            assert page.locator('.tl-parallel-sequence').count()==2
            assert page.locator('#chapter-diagram .flow-edge').count()==0
            assert page.locator('[data-flow-node="reaction/side_return_knots_take"]').count()==0
            pair=page.locator('.tl-variants[data-timeline-group="side_return_knots"]')
            a=pair.locator('[data-path="side_return_knots/take"]')
            b=pair.locator('[data-path="side_return_knots/skip"]')
            if width==390:
                assert a.is_visible() and not b.is_visible()
                tabs=pair.locator('..').locator('.timeline-tabs')
                tabs.locator('[data-timeline-option="side_return_knots/take"]').focus()
                page.keyboard.press('ArrowRight')
                assert b.is_visible() and not a.is_visible()
                assert tabs.locator('[data-timeline-option="side_return_knots/skip"]').get_attribute('aria-selected')=='true'
                page.keyboard.press('ArrowLeft')
                assert a.is_visible() and not b.is_visible()
            else:
                assert a.is_visible() and b.is_visible()
                assert abs(a.bounding_box()['y']-b.bounding_box()['y'])<1
                assert a.bounding_box()['x']!=b.bounding_box()['x']
            assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
            node=a
            node.focus()
            scroll=page.locator('#chapter-diagram').evaluate('(e)=>[e.scrollTop,e.scrollLeft]')
            route=page.url
            page.keyboard.press('Enter')
            assert node.get_attribute('aria-pressed')=='true'
            assert page.locator('#chapter-diagram .timeline-cell.is-related').count()==1
            assert page.url==route
            assert page.locator('#chapter-diagram').evaluate('(e)=>[e.scrollTop,e.scrollLeft]')==scroll
            target=page.locator('#graph-selection [data-flow-focus="reaction/side_return_knots_take"]')
            assert '10-1' in target.inner_text()
            target.click()
            assert page.locator('#chapter-select').input_value()=='chapter10'
            assert page.locator('[data-select-node="reaction/side_return_knots_take"]').get_attribute('aria-pressed')=='true'
            assert '후속 반응' in page.locator('#chapter-diagram').inner_text()
            page.locator('#graph-selection [data-flow-focus="option/side_return_knots/take"]').click()
            assert page.locator('#chapter-select').input_value()=='chapter09'
            assert node.get_attribute('aria-pressed')=='true'
            assert page.locator('#graph-selection .graph-selection-body').inner_text().strip()
            page.locator('#graph-selection [data-source]').click()
            assert 'runtime.plan.json' in page.locator('#source-location').inner_text()
            page.go_back()
            page.locator('#chapter-diagram').wait_for()
            assert page.locator('#graph-selection').is_hidden()
            node=page.locator('#chapter-diagram [data-select-node="option/side_return_knots/take"]')
            node.focus();page.keyboard.press(' ')
            assert node.get_attribute('aria-pressed')=='true'
            page.keyboard.press('Escape')
            assert node.get_attribute('aria-pressed')=='false'
            assert page.locator('#graph-selection').is_hidden()
            assert page.locator('.branch-questions').count()==0
            assert page.get_by_role('heading',name='이 장의 질문과 선택',exact=True).count()==0
            if screenshots:
                page.screenshot(path=str(screenshots/f'studio-graph-{width}.png'))
            page.locator('[data-graph-panel="diagram"]').click()
            page.locator('#open-overview-graph').click()
            assert page.locator('#return-chapter-graph').is_visible()
            page.locator('#return-chapter-graph').click()
            page.locator('[data-graph-panel="rules"]').click()
            assert page.locator('#chapter-select').input_value()=='chapter09'
            assert page.locator('#branch-details .branch-rule').count()==3
            assert page.locator('#chapter-diagram').count()==0
            page.locator('.branch-rule>summary').first.click()
            assert '두 봉인을 모두 풀어야 한다' in page.locator('#branch-details').inner_text()
            assert page.locator('.branch-option').count()==6
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
            assert page.locator('#branch-details .branch-rule').count()==5
            page.locator('#chapter-select').select_option('chapter02')
            assert page.locator('#branch-details .branch-rule').count()==2
            assert '무너진 제빵소의 마지막 자루' in page.locator('#branch-details').inner_text()
            page.locator('[data-graph-panel="timeline"]').click()
            assert page.locator('#chapter-select').input_value()=='chapter02'
            page.locator('#chapter-select').select_option('chapter01')
            nested=page.locator('[data-choice-group="side_gate_lantern_approach"]')
            assert nested.count()==2 # question stage and the later two-way memory stage
            assert all(nested.nth(i).locator('.tl-card').count()==2 for i in range(2))
            assert page.locator('[data-flow-node$="/bypass"]').count()==0
            assert '참여 경로' in nested.first.inner_text()
            nested.first.locator('.tl-nesting [data-flow-focus]').click()
            assert page.locator('[data-select-node="option/side_gate_lantern/take"]').get_attribute('aria-pressed')=='true'
            if screenshots:page.screenshot(path=str(screenshots/f'studio-nested-{width}.png'))
            page.keyboard.press('Escape')
            page.locator('#chapter-select').select_option('chapter02')
            if width==390:
                package=json.loads(page.locator('#studio-data').text_content())
                shared=next((c,r,card) for c in package['timeline']['chapters'] for r in c['rows'] if r['kind']=='reaction' for card in r['cards'] if 0<len(card['source_options'])<len(package['timeline']['groups'][r['group_id']]['options']))
                c,r,card=shared;group=package['timeline']['groups'][r['group_id']]
                page.locator('#chapter-select').select_option(c['chapter_id'])
                outside=next(o['id'] for o in group['options'] if o['id'] not in card['source_options'])
                buttons=page.locator('.timeline-tabs').filter(has=page.locator(f'[data-timeline-group="{group["id"]}"]'))
                buttons.first.locator(f'[data-timeline-option="{outside}"]').click()
                assert not page.locator(f'[data-flow-node="{card["node_id"]}"]').is_visible()
                buttons.first.locator(f'[data-timeline-option="{card["source_options"][0]}"]').click()
                assert page.locator(f'[data-flow-node="{card["node_id"]}"]').is_visible()
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
            report.append({'width':width,'views':7,'external_requests':len(requests),'errors':len(errors),'reading_interaction':True,'side_chapters_checked':15,'side_memory_checked':True,'side_next_gate':True,'source_json_download':True,'browser_back_forward':True,'comparison_timeline':True,'no_default_edges':True,'mobile_path_tabs':True,'parallel_orders_preserved':True,'cross_chapter_actual_timing':True,'graph_link_focus':True,'unified_branch_details':True,'legacy_branch_bookmark':True,'compact_type':True,'dense_basic_height':basic_height,'evidence_keyboard_toggle':True})
            page.close()
        browser.close()
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--screenshots',type=Path)
    parser.add_argument('--bundle',type=Path)
    args=parser.parse_args()
    print(json.dumps(check(args.screenshots,args.bundle),ensure_ascii=False,indent=2))
