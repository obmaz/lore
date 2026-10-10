"""Optional Chromium QA for the read-only reference documents; no game/server needed."""
import argparse
import json
from pathlib import Path

from playwright.sync_api import sync_playwright

from materials import ROOT


def verify(output, screenshots=None):
    cases = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
        try:
            for width,height in [(390,844),(1280,900)]:
                page = browser.new_page(viewport={'width':width,'height':height})
                errors,requests = [],[]
                page.on('pageerror',lambda error:errors.append(str(error)))
                page.on('request',lambda request:requests.append(request.url))
                page.set_content((output/'reference.html').read_text(encoding='utf-8'))
                assert page.locator('#content #character-lord_ahn').count()==1
                assert page.locator('#content #character-false_necromancer').count()==0
                assert not page.locator('#author-mode').is_checked()
                assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
                page.locator('#author-mode').check()
                assert page.locator('#content #character-false_necromancer').count()==1
                assert page.locator('#content #characters details.entry').count()==49
                assert page.locator('#content #relationships details.entry').count()==35
                assert page.locator('#content #abilities details.entry').count()==45
                assert page.locator('#content #bestiary details.entry').count()==75
                page.locator('#search').fill('마법 화살')
                assert page.locator('#content details.entry[hidden]').count()>0
                page.evaluate('preparePrint()')
                assert page.locator('#content details.entry:not([open])').count()==0
                assert page.locator('#content details.entry[hidden]').count()==0
                page.evaluate('dispatchEvent(new Event("afterprint"))')
                assert page.locator('#content details.entry[hidden]').count()>0
                page.locator('#search').fill('')
                page.locator('#expand').click()
                assert page.locator('#content details.entry:not([open])').count()==0
                assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
                page.locator('#collapse').click()
                assert page.locator('#content details.entry[open]').count()==0
                page.locator('#author-mode').uncheck()
                assert page.locator('#content #character-false_necromancer').count()==0
                page.close()
                page = browser.new_page(viewport={'width':width,'height':height})
                page.on('pageerror',lambda error:errors.append(str(error)))
                page.on('request',lambda request:requests.append(request.url))
                page.set_content((output/'reference-safe.html').read_text(encoding='utf-8'))
                assert page.locator('template').count()==0
                assert page.locator('#author-mode').count()==0
                assert 'world_prophecy' not in page.content()
                assert not requests,requests
                assert not errors,errors
                if screenshots is not None:
                    screenshots.mkdir(parents=True,exist_ok=True)
                    page.screenshot(path=str(screenshots/f'preview-{width}.png'),full_page=True)
                cases.append({'viewport':[width,height],'checks':'initial projection, author toggle, counts, search, print reset, responsive layout, no network, no page errors'})
                page.close()
        finally:
            browser.close()
    return cases


if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT/'exports')
    parser.add_argument('--screenshots',type=Path,help='optional QA images outside the reference snapshots')
    args = parser.parse_args()
    print(json.dumps(verify(args.output.resolve(),args.screenshots),ensure_ascii=False,indent=2))
