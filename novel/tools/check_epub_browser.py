"""Exercise the EPUB XHTML in a browser, not a claim of RIDI device support."""
import functools
import http.server
import json
import tempfile
import threading
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

from materials import ROOT,read
from ebook import OUTPUT
from epub_interactive import PLAN


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*args):pass


def check():
    from playwright.sync_api import sync_playwright,expect
    plan=read(PLAN);linear=read(OUTPUT/'report.json');reports=[]
    with tempfile.TemporaryDirectory(prefix='lore-epub-browser-')as directory:
        with zipfile.ZipFile(OUTPUT/plan['filename'])as book:book.extractall(directory)
        server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(QuietHandler,directory=directory))
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        url='http://127.0.0.1:'+str(server.server_port)+'/OEBPS/interactive.xhtml'
        try:
            with sync_playwright()as p:
                browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
                for width in [390,820,1280]:
                    context=browser.new_context(viewport={'width':width,'height':900});page=context.new_page();errors=[]
                    page.on('pageerror',lambda e:errors.append(str(e)))
                    page.goto(url);expect(page.locator('#runtime-status')).to_contain_text('선택 기능 작동')
                    assert page.locator('#epub-app').is_visible()
                    assert page.evaluate('document.contentType')=='application/xhtml+xml'
                    for decision in linear['decisions']:page.locator('[data-choice="'+decision['choice_id']+'"]').click()
                    assert page.locator('#choices button').count()==0
                    actual=page.locator('#manuscript p[data-block-id]').all_text_contents();expected=[]
                    for key in plan['chapter_ids']:
                        doc=ET.parse(Path(directory)/'OEBPS'/(''+key+'.xhtml'))
                        expected.extend(''.join(e.itertext())for e in doc.findall('.//{http://www.w3.org/1999/xhtml}main/{http://www.w3.org/1999/xhtml}p'))
                    assert actual==expected
                    assert page.locator('#manuscript section[data-story-role="main"]').count()==43
                    assert page.locator('#manuscript [data-block-id="gaia_evil_seal/joined_body"]').count()==0
                    assert page.locator('#manuscript [data-block-id="gaia_evil_seal/left_body"]').count()==0
                    assert page.locator('#manuscript blockquote,#manuscript small').count()==0
                    assert page.locator('#manuscript [data-chapter-cover]').count()==3
                    assert page.locator('#manuscript [data-chapter-cover] img').evaluate_all('(es)=>es.every(e=>e.complete&&e.naturalWidth===1024)')
                    assert page.evaluate('document.documentElement.scrollWidth<=innerWidth+2')
                    before=page.locator('#manuscript').inner_text();page.reload()
                    expect(page.locator('#choices')).to_contain_text('제3장 끝');assert before==page.locator('#manuscript').inner_text()
                    # A tampered record cannot bypass mandatory scenes or import state.
                    page.evaluate('''()=>{const d=JSON.parse(document.getElementById('chapter-data').textContent);localStorage.setItem('novel-epub-route:'+d.fingerprint,JSON.stringify({fingerprint:d.fingerprint,route:['gaia_evil_seal/aid_rigel']}));}''')
                    page.locator('#load').click();expect(page.locator('#message')).to_contain_text('이 경로에서는')
                    assert page.locator('#choices button').count()==0
                    page.locator('#restart').click();assert page.locator('#choices button').count()>1
                    page.locator('[data-choice="prologue/visit_lord"]').click();page.locator('#back').click()
                    assert page.locator('[data-choice="prologue/visit_lord"]').is_visible()
                    assert not errors,errors
                    reports.append({'width':width,'xhtml':True,'linear_text_match':len(actual),'mandatory_scenes':43,'save_reload':True,'tamper_rejected':True})
                    context.close()
                # Storage denial must not prevent stateful reading in the current session.
                context=browser.new_context();context.add_init_script("Storage.prototype.setItem=function(){throw Error('Storage blocked');};")
                page=context.new_page();page.goto(url);expect(page.locator('#runtime-status')).to_contain_text('저장이 제한')
                for _ in range(50):
                    buttons=page.locator('#choices button')
                    if not buttons.count():break
                    ids=buttons.evaluate_all('(es)=>es.map(e=>e.dataset.choice)')
                    preferences=['prologue/visit_lord','i/depart_now','lore_menace/decline_skeleton','lore_menace/enter_menace','lore_menace/return_to_lore','lastditch_pyramid/decline_polaris','lastditch_pyramid/equip_spear_party_hunter','lastditch_pyramid/separate_pressure','gaia_evil_seal/join_rigel']
                    key=next((i for i in preferences if i in ids),ids[0]);page.locator('[data-choice="'+key+'"]').click()
                assert page.locator('#choices button').count()==0
                assert page.locator('#manuscript section[data-story-role="main"]').count()==43
                assert page.locator('[data-block-id="gaia_evil_seal/joined_body"]').count()>0
                assert page.locator('[data-block-id="gaia_evil_seal/aided_body"]').count()==0
                assert page.locator('[data-block-id="gaia_evil_seal/left_body"]').count()==0
                context.close();reports.append({'storage_blocked':True,'alternate_join_route':True})
                context=browser.new_context(java_script_enabled=False);page=context.new_page();page.goto(url)
                assert page.locator('#epub-app').is_hidden()
                page.locator('a[href="chapter01.xhtml"]').click()
                expect(page.locator('h1')).to_contain_text('제1장')
                assert page.locator('main>p').count()>100
                context.close();reports.append({'scripts_blocked':True,'static_fallback':True})
                browser.close()
        finally:server.shutdown();server.server_close();thread.join()
    return {'browser_tests':reports,'ridi_device_tested':False}


if __name__=='__main__':print(json.dumps(check(),ensure_ascii=False,indent=2))
