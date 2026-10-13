"""Read both public prose editions offline, including isolated route saves."""
import json
from materials import ROOT


def check():
    from playwright.sync_api import sync_playwright,expect
    reports=[]
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
            assert b['edition']=='B' and len(b['chapters'])==1
            assert a['fingerprint']!=b['fingerprint']
            assert '발밑에서 돌이 흔들렸다.' in frame.locator('#manuscript').inner_text()
            for _ in range(40):
                buttons=frame.locator('#choices button')
                if not buttons.count():break
                ids=buttons.evaluate_all('(es)=>es.map(e=>e.dataset.choice)')
                assert len(ids)>1,'single transitions should be automatic'
                preferred=['prologue/visit_lord','i/depart_now','lore_menace/accept_skeleton',
                           'lore_menace/enter_menace','lore_menace/return_to_lore']
                key=next((c for c in preferred if c in ids),ids[0])
                frame.locator(f'[data-choice="{key}"]').click()
            assert frame.locator('#choices button').count()==0
            assert '제1장 끝' in frame.locator('#choices').inner_text()
            assert '제2장 ·' not in frame.locator('#manuscript').inner_text()
            assert frame.locator('#manuscript').get_by_text('주인공',exact=True).count()==0
            # A route file is deliberately rejected by B even if IDs are shared.
            frame.locator('#file').set_input_files({'name':'A-route.json','mimeType':'application/json',
                'buffer':json.dumps({'fingerprint':a['fingerprint'],'route':[]}).encode()})
            expect(frame.locator('#message')).to_contain_text('다른 판본')
            assert frame.locator('#choices button').count()==0
            assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
            assert frame.locator('html').evaluate('(e)=>e.scrollWidth<=innerWidth')
            assert not errors,errors
            assert not requests,requests
            reports.append({'width':width,'A_chapters':3,'B_chapters':1,'B_complete':True,
                            'shared_choices':True,'cross_edition_save_rejected':True,'offline':True})
            page.close()
        browser.close()
    return reports


if __name__=='__main__':print(json.dumps(check(),ensure_ascii=False,indent=2))
