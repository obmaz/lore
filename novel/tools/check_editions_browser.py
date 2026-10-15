"""Read both public prose editions offline, including isolated route saves."""
import json
import zipfile
from xml.etree import ElementTree as ET
from materials import ROOT
from prose_variants import load_series


def check():
    from playwright.sync_api import sync_playwright,expect
    reports=[]
    count=len(load_series()['chapters'])
    with sync_playwright() as p:
        browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
        for width,height in [(390,844),(820,900),(1280,900)]:
            page=browser.new_page(viewport={'width':width,'height':height})
            errors,requests=[],[]
            page.on('pageerror',lambda e:errors.append(str(e)))
            page.on('request',lambda r:requests.append(r.url))
            page.set_content((ROOT/'writing/previews/novel-reader.html').read_text())
            assert page.locator('#edition-select option').count()==2
            frame=page.frame_locator('#edition-frame')
            frame.locator('#choices button').first.wait_for()
            a=json.loads(frame.locator('#chapter-data').text_content())
            assert a['edition']=='A' and len(a['chapters'])==3
            page.locator('#edition-select').select_option('B')
            frame=page.frame_locator('#edition-frame')
            frame.locator('#choices button').first.wait_for()
            b=json.loads(frame.locator('#chapter-data').text_content())
            assert b['edition']=='B' and len(b['chapters'])==count
            assert a['fingerprint']!=b['fingerprint']
            assert '발밑에서 돌이 흔들렸다.' in frame.locator('#manuscript').inner_text()
            for _ in range(40):
                buttons=frame.locator('#choices button')
                if not buttons.count():break
                ids=buttons.evaluate_all('(es)=>es.map(e=>e.dataset.choice)')
                assert len(ids)>1,'single transitions should be automatic'
                preferred=['prologue/visit_lord','i/depart_now','lore_menace/accept_skeleton',
                           'lore_menace/enter_menace','lore_menace/return_to_lore',
                           'lastditch_pyramid/accept_polaris','lastditch_pyramid/replace_for_polaris',
                           'lastditch_pyramid/replace_skeleton','lastditch_pyramid/equip_spear_party_hunter',
                           'lastditch_pyramid/separate_pressure','gaia_evil_seal/aid_rigel']
                key=next((c for c in preferred if c in ids),ids[0])
                frame.locator(f'[data-choice="{key}"]').click()
            assert frame.locator('#choices button').count()==0
            assert f'제{count}장 끝' in frame.locator('#choices').inner_text()
            assert frame.locator('[data-block-id="i/return_boar_no_shield"]').count()>0
            assert frame.locator('[data-block-id="i/return_boar_gold"]').count()==0
            assert frame.locator('[data-block-id="i/return_boar_axe_prepared"]').count()==0
            assert f'제{count+1}장 ·' not in frame.locator('#manuscript').inner_text()
            if count>=2:assert '성벽이 보이지 않았다.' in frame.locator('[data-block-id="lastditch_pyramid/arrival_body"]').first.inner_text()
            if count>=3:
                assert '벽이 있어야 할 곳에 하늘이 보였다.' in frame.locator('[data-block-id="gaia_evil_seal/ruins_body"]').first.inner_text()
                assert '식량을 꺼냈다.' in frame.locator('[data-block-id="gaia_evil_seal/aided_body"]').first.inner_text()
                assert frame.locator('[data-block-id="gaia_evil_seal/joined_body"]').count()==0
                assert frame.locator('[data-block-id="gaia_evil_seal/left_body"]').count()==0
            assert frame.locator('#manuscript').get_by_text('주인공',exact=True).count()==0
            assert frame.locator('#manuscript h2').count()==count-1,'only later chapter titles belong in the manuscript'
            assert frame.locator('#manuscript .quote, #manuscript blockquote, #manuscript small').count()==0
            assert frame.locator('#manuscript section[data-story-role="main"]').count()==len(b['main_story'])
            shown=frame.locator('#manuscript [data-source-blocks]').evaluate_all('(es)=>es.flatMap(e=>JSON.parse(e.dataset.sourceBlocks))')
            assert 'lastditch_pyramid/request_444' in shown and 'lastditch_pyramid/request_452' in shown
            assert 'gaia_evil_seal/rigel_605' in shown and 'gaia_evil_seal/rigel_610' in shown
            assert '성주가 입을 열었다. “' in frame.locator('[data-block-id="lastditch_pyramid/request_443"]').inner_text()
            assert '신의 축복' in frame.locator('[data-block-id="gaia_evil_seal/aid_result_643"]').inner_text()
            assert '[EXP' not in frame.locator('#manuscript').inner_text()
            assert '[ EXP' not in frame.locator('#manuscript').inner_text()
            # A route file is deliberately rejected by B even if IDs are shared.
            frame.locator('#file').set_input_files({'name':'A-route.json','mimeType':'application/json',
                'buffer':json.dumps({'fingerprint':a['fingerprint'],'route':[]}).encode()})
            expect(frame.locator('#message')).to_contain_text('다른 판본')
            assert frame.locator('#choices button').count()==0
            # Repeat the same route through A: its prose stays distinct while
            # chapter structure and source presentation obey the same policy.
            page.locator('#edition-select').select_option('A')
            frame=page.frame_locator('#edition-frame')
            frame.locator('#choices button').first.wait_for()
            assert frame.locator('#manuscript h2, #manuscript small, #manuscript .quote').count()==0
            for _ in range(40):
                buttons=frame.locator('#choices button')
                if not buttons.count():break
                ids=buttons.evaluate_all('(es)=>es.map(e=>e.dataset.choice)')
                key=next((c for c in preferred if c in ids),ids[0])
                frame.locator(f'[data-choice="{key}"]').click()
                # The beginning of the new prose, not a removed subtitle or
                # trailing choices, receives keyboard focus after every choice.
                assert frame.locator('body').evaluate('()=>document.activeElement.matches("#manuscript section")')
            assert frame.locator('#choices button').count()==0
            assert frame.locator('#manuscript h2').count()==2
            assert frame.locator('#manuscript h2').evaluate_all('(es)=>es.every(e=>/^제[23]장 · /.test(e.textContent))')
            assert frame.locator('#manuscript .quote, #manuscript blockquote, #manuscript small').count()==0
            assert frame.locator('#manuscript section[data-story-role="main"]').count()==43
            assert frame.locator('[data-block-id^="i/return_boar_"]').count()==0
            assert frame.locator('#manuscript p[data-block-id]').evaluate_all('(es)=>es.every(e=>e.textContent.trim())')
            assert '일행을 보며 말했다. “' in frame.locator('[data-block-id="lastditch_pyramid/request_443"]').inner_text()
            assert frame.locator('#book-cover-image').evaluate('(e)=>e.complete&&e.naturalWidth===1024')
            assert frame.locator('#manuscript [data-chapter-cover]').count()==3
            assert frame.locator('#manuscript [data-chapter-cover] img').evaluate_all('(es)=>es.every(e=>e.complete&&e.naturalWidth===1024)')
            assert '새로운 여정' in frame.locator('[data-block-id="prologue/lord_intro_dialogue"]').inner_text()
            assert '이 게임' not in frame.locator('#manuscript').inner_text()
            assert page.locator('#download-b-epub').get_attribute('download')=='lore-B-chapters01-03.epub'
            if width==1280:
                report=json.loads((ROOT/'writing/ebooks/generated/report.json').read_text())
                page.locator('#edition-select').select_option('B')
                frame=page.frame_locator('#edition-frame')
                frame.locator('#choices button').first.wait_for()
                for decision in report['decisions']:
                    frame.locator('[data-choice="'+decision['choice_id']+'"]').click()
                assert frame.locator('#choices button').count()==0
                actual=frame.locator('#manuscript p[data-block-id]').all_text_contents()
                expected=[]
                with zipfile.ZipFile(ROOT/'writing/ebooks/generated/lore-B-chapters01-03.epub')as book:
                    for key in ['chapter01','chapter02','chapter03']:
                        doc=ET.fromstring(book.read('OEBPS/'+key+'.xhtml'))
                        expected.extend(''.join(p.itertext())for p in doc.findall('.//{http://www.w3.org/1999/xhtml}main/{http://www.w3.org/1999/xhtml}p'))
                assert actual==expected,'EPUB paragraphs must match the real B web route exactly'
                # Read real choices again: shield ownership and armory preparation
                # must control the browser's prose as well as Python replay.
                for town,owner in [('armory','protagonist'),('armory','party_woodcutter'),('tavern','cancel'),('tavern',None)]:
                    frame.locator('#restart').click()
                    choices=['prologue/visit_lord','i/explore','i/visit_'+town,
                             'lore_menace/decline_skeleton','lore_menace/enter_menace',
                             'i/cave_treasure' if owner else 'lore_menace/return_to_lore',
                             'i/shield_'+(owner or 'cancel')]
                    for _ in range(30):
                        if frame.locator('[data-block-id="i/return_boar_arrive"]').count():break
                        ids=frame.locator('#choices button').evaluate_all('(es)=>es.map(e=>e.dataset.choice)')
                        assert ids,'chapter-one encounter must be reachable'
                        key=next((c for c in choices if c in ids),ids[0])
                        frame.locator('[data-choice="'+key+'"]').click()
                    assert frame.locator('[data-block-id="i/return_boar_arrive"]').count()>0
                    visible=lambda key:frame.locator('[data-block-id="i/return_boar_'+key+'"]').count()>0
                    shield=owner not in (None,'cancel')
                    assert visible('no_shield')== (not shield)
                    assert visible('shield_after')==shield
                    if shield:assert visible('shield_'+owner)
                    assert visible('gold')== (owner is not None)
                    assert visible('axe')== (owner!='party_woodcutter')
                    assert visible('axe_prepared')== (town=='armory' and owner!='party_woodcutter')
                    assert not frame.locator('#manuscript').get_by_text('대답이 조금 작았다.',exact=True).count()
            assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
            assert frame.locator('html').evaluate('(e)=>e.scrollWidth<=innerWidth')
            assert not errors,errors
            assert not requests,requests
            reports.append({'width':width,'A_chapters':3,'B_chapters':count,'B_complete':True,
                            'shared_choices':True,'cross_edition_save_rejected':True,'offline':True,
                            'chapter_titles_only':True,'natural_attribution_both_editions':True,
                            'shared_covers':True,'script_overrides':True,'epub_browser_text_match':width==1280,
                            'chapter01_equipment_prose_routes':4 if width==1280 else 1,'A_no_encounter_or_empty_paragraphs':True})
            page.close()
        browser.close()
    return reports


if __name__=='__main__':print(json.dumps(check(),ensure_ascii=False,indent=2))
