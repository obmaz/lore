"""Offline browser QA for generated writing documents; no hosting or game build."""
import argparse
import json
from pathlib import Path

from materials import ROOT


def check(output):
    from playwright.sync_api import sync_playwright
    results = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
        for width,height in [(390,844),(1280,900)]:
            for name in ['storyboard.html','prologue.html','prologue-tavern.html']:
                page = browser.new_page(viewport={'width':width,'height':height})
                errors,requests = [],[]
                page.on('pageerror',lambda error:errors.append(str(error)))
                page.on('request',lambda request:requests.append(request.url))
                page.set_content((ROOT/'writing/previews'/name).read_text(encoding='utf-8'))
                page.evaluate('document.fonts.ready')
                assert not errors and not requests,(errors,requests)
                assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'),name+' overflows'
                assert page.locator('h1').count()==1
                assert page.get_by_role('button',name='인쇄 / PDF 저장').count()==1
                if output:
                    output.mkdir(parents=True,exist_ok=True)
                    page.screenshot(path=str(output/f'{name}-{width}.png'))
                results.append({'file':name,'width':width,'sections':page.locator('h2').count(),'network_requests':len(requests)})
                page.close()
        browser.close()
    return results


if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--screenshots',type=Path)
    args = parser.parse_args()
    print(json.dumps(check(args.screenshots),ensure_ascii=False,indent=2))
