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
            assert page.locator('#workspace').is_visible()
            assert page.locator('#navigation button').count()==7
            assert page.locator('#navigation button:disabled').count()==0
            assert page.locator('#navigation [data-view="branches"]').count()==0
            assert page.locator('#open-studio').count()==0
            assert page.locator('#writing-style').count()==1
            page.locator('#writing-style summary').click()
            assert '골격 단계' in page.locator('#writing-style').inner_text()
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
            assert page.locator('#document-select option').count()==2
            # Real prose is a single forward book, not the fifteen-chapter prototype.
            book=json.loads(frame.locator('#chapter-data').text_content())
            assert [c['id'] for c in book['chapters']]==['chapter01','chapter02','chapter03']
            chosen=[]
            for _ in range(40):
                buttons=frame.locator('#choices button')
                if not buttons.count():break
                assert buttons.count()>1,'single-path confirmation should be automatic'
                ids=buttons.evaluate_all('(es)=>es.map(e=>e.dataset.choice)')
                preferred=['prologue/visit_lord','i/depart_now','lore_menace/decline_skeleton',
                           'lore_menace/enter_menace','lore_menace/return_to_lore',
                           'lastditch_pyramid/accept_polaris','lastditch_pyramid/equip_spear_party_hunter',
                           'lastditch_pyramid/separate_pressure','gaia_evil_seal/aid_rigel']
                key=next((c for c in preferred if c in ids),ids[0])
                assert key not in chosen,'a completed fork became available again'
                chosen.append(key)
                frame.locator(f'#choices [data-choice="{key}"]').click()
                assert not errors,errors
            assert frame.locator('#choices button').count()==0
            assert '제3장 끝' in frame.locator('#choices').inner_text()
            assert '제2장 · 모래 아래의 오래된 적' in frame.locator('#manuscript').inner_text()
            assert frame.locator('[data-block-id="lastditch_pyramid/arrival_body"]').count()>4
            assert frame.locator('[data-block-id="lastditch_pyramid/battle_spear_party_hunter"]').count()==1
            assert frame.locator('[data-block-id="lastditch_pyramid/battle_weapon_party_hunter"]').count()==0
            assert frame.locator('[data-block-id="lastditch_pyramid/skeleton_present_4"]').count()==0
            frame.locator('details summary').click()
            assert '폴라리스' in frame.locator('#state').inner_text()
            # B shares the first chapter's source and choices, not later A prose.
            page.locator('#document-select').select_option('chapter01-web.html')
            frame=page.frame_locator('#document-frame')
            frame.locator('#choices button').first.wait_for()
            web=json.loads(frame.locator('#chapter-data').text_content())
            assert web['edition']=='B'
            from prose_variants import load_series
            assert [c['id'] for c in web['chapters']]==[c['chapter_id'] for c in load_series()['chapters']]
            assert '발밑에서 돌이 흔들렸다.' in frame.locator('#manuscript').inner_text()
            assert '소설 본문 · B ·' in frame.locator('.notice').inner_text()
            assert not errors,errors
            view('graph')
            page.locator('[data-graph-panel="preview"]').click()
            frame=page.frame_locator('#branch-preview-frame')
            frame.locator('#side-choices button').first.wait_for()
            page.go_back()
            page.locator('#chapter-diagram').wait_for()
            page.go_forward()
            page.locator('#branch-preview-frame').wait_for()
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
                    if (remembered['reaction_unit'] or '').startswith(chapter['id']+'/') and remembered['id'] in modes:
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
            assert frame.locator('#side-progress').inner_text() == '1 / 15장'
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
            page.locator('[data-graph-panel="diagram"]').click()
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
            assert page.locator('[data-graph-panel="timeline"]').count()==0
            assert page.get_by_role('button',name='같은 장의 주요 내용',exact=True).count()==0
            node=page.locator('#chapter-diagram [data-flow-node="option/side_return_knots/take"]')
            node.focus();page.keyboard.press('Enter')
            assert node.get_attribute('aria-pressed')=='true'
            divider=page.locator('#graph-divider')
            assert divider.is_visible()
            before=page.locator('#graph-selection').bounding_box()
            bar=divider.bounding_box()
            page.mouse.move(bar['x']+bar['width']/2,bar['y']+bar['height']/2)
            page.mouse.down()
            if width>900:
                page.mouse.move(bar['x']-180,bar['y']+bar['height']/2,steps=10)
            else:
                page.mouse.move(bar['x']+bar['width']/2,bar['y']-60,steps=10)
            page.mouse.up()
            if width>900:
                assert page.locator('#graph-selection').bounding_box()['width']>before['width']+100
                assert divider.get_attribute('aria-orientation')=='vertical'
            else:
                assert page.locator('#chapter-diagram').bounding_box()['height']<320
                assert divider.get_attribute('aria-orientation')=='horizontal'
            divider.focus();value=int(divider.get_attribute('aria-valuenow'))
            page.keyboard.press('ArrowLeft' if width>900 else 'ArrowUp')
            assert int(divider.get_attribute('aria-valuenow'))<value
            saved=divider.get_attribute('aria-valuenow')
            page.locator('#chapter-select').select_option('chapter08')
            page.locator('#chapter-diagram [data-node-kind="decision"]').first.focus();page.keyboard.press('Enter')
            assert page.locator('#graph-divider').get_attribute('aria-valuenow')==saved
            page.locator('#chapter-select').select_option('chapter09')
            node=page.locator('#chapter-diagram [data-flow-node="option/side_return_knots/take"]')
            node.focus();page.keyboard.press('Enter')
            route=page.url
            target=page.locator('#graph-selection [data-flow-focus="reaction/side_return_knots_take"]')
            assert '10-1' in target.inner_text()
            target.click()
            assert page.locator('#chapter-select').input_value()=='chapter10'
            assert page.locator('#chapter-diagram [data-flow-node="reaction/side_return_knots_take"]').get_attribute('aria-pressed')=='true'
            page.locator('#graph-selection [data-flow-focus="option/side_return_knots/take"]').click()
            assert page.locator('#chapter-select').input_value()=='chapter09'
            page.locator('#graph-selection [data-source]').click()
            assert 'runtime.plan.json' in page.locator('#source-location').inner_text()
            page.go_back()
            page.locator('#chapter-diagram').wait_for()
            assert page.locator('#graph-selection').is_hidden()
            node=page.locator('#chapter-diagram [data-flow-node="option/side_return_knots/take"]')
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
            page.locator('[data-graph-panel="diagram"]').click()
            page.locator('#chapter-select').select_option('chapter01')
            nested=page.locator('#chapter-diagram [data-flow-node="decision/side_gate_lantern_approach"]')
            assert nested.count()==1
            nested.focus();page.keyboard.press('Enter')
            assert page.locator('#graph-selection [data-flow-focus^="option/side_gate_lantern_approach/"]').count()==2
            if screenshots:page.screenshot(path=str(screenshots/f'studio-nested-{width}.png'))
            page.keyboard.press('Escape')
            page.locator('#chapter-select').select_option('chapter13')
            alternatives=page.locator('#chapter-diagram .flow-node[data-exclusive-group]:not([data-exclusive-group=""]) [y]').evaluate_all('''(es)=>es.filter(e=>e.tagName.toLowerCase()==='rect').map(e=>({id:e.parentNode.dataset.flowNode,group:e.parentNode.dataset.exclusiveGroup,x:+e.getAttribute('x'),y:+e.getAttribute('y')}))''')
            stair=[n for n in alternatives if n['id'].startswith('reaction/side_loose_stair')]
            assert len(stair)==3
            assert len({n['y'] for n in stair})==1
            assert len({n['x'] for n in stair})==3
            assert len({n['group'] for n in stair})==1
            page.locator('#chapter-diagram [data-flow-node="'+stair[0]['id']+'"]').focus()
            page.keyboard.press('Enter')
            assert page.locator('#graph-selection').is_visible()
            if screenshots:page.screenshot(path=str(screenshots/f'studio-exclusive-{width}.png'))
            page.keyboard.press('Escape')
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
            assert set(basic.locator('.fact-card').evaluate_all('(es)=>es.map(e=>e.dataset.field)'))=={'name','age','appearance','species','personality','origin','settings'}
            basic_height=round(basic.bounding_box()['height'],1)
            short_heights=basic.locator('.fact-card:not(.fact-long)').evaluate_all('(es)=>es.map(e=>e.getBoundingClientRect().height)')
            assert sum(short_heights)<=360,('short facts waste vertical space',width,short_heights)
            assert all(h<=60 for h in short_heights)
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
            deep.locator('.setting-detail-head h2').wait_for()
            assert deep.locator('.setting-detail-head h2').inner_text()=='사냥 활'
            assert deep.locator('#setting-category').input_value()=='equipment'
            deep.close()
            legacy=browser.new_page(viewport={'width':width,'height':height})
            legacy.set_content(path.read_text(encoding='utf-8'))
            legacy.evaluate('location.hash="#/branches?chapter=chapter09"')
            legacy.locator('#branch-details').wait_for()
            assert legacy.locator('[data-graph-panel="rules"][aria-pressed="true"]').is_visible()
            assert legacy.locator('#chapter-select').input_value()=='chapter09'
            legacy.close()
            lord=browser.new_page(viewport={'width':width,'height':height})
            lord.set_content(path.read_text(encoding='utf-8'))
            lord.evaluate('location.hash="#/settings?item=characters%2Flord_ahn"')
            lord.locator('#setting-detail h2').wait_for()
            assert lord.locator('#setting-detail h2').inner_text()=='동욱'
            assert 'Lord Ahn' in lord.locator('.setting-identity').inner_text()
            assert '소설용 이름' in lord.locator('.setting-content').inner_text()
            assert lord.locator('.setting-content [data-field="age"]').count()==1
            assert '출신' in lord.locator('.setting-content').inner_text()
            lord.close()
            report.append({'width':width,'views':7,'external_requests':len(requests),'errors':len(errors),'reading_interaction':True,'side_chapters_checked':15,'side_memory_checked':True,'side_next_gate':True,'source_json_download':True,'browser_back_forward':True,'resizable_graph_details':True,'direct_entry':True,'shared_style':True,'parallel_orders_preserved':True,'cross_chapter_actual_timing':True,'graph_link_focus':True,'unified_branch_details':True,'legacy_branch_bookmark':True,'compact_type':True,'dense_basic_height':basic_height,'evidence_keyboard_toggle':True})
            page.close()
        browser.close()
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--screenshots',type=Path)
    parser.add_argument('--bundle',type=Path)
    args=parser.parse_args()
    print(json.dumps(check(args.screenshots,args.bundle),ensure_ascii=False,indent=2))
