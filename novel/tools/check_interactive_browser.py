"""Play real offline first-chapter choices on mobile/desktop; compare Python replay."""
import json

from interactive import Session
from materials import ROOT

INTRO=['prologue/enter_courtyard','prologue/visit_lord','prologue/hear_lord_intro',
       'prologue/hear_lord_briefing','prologue/first_quest_boundary/continue','lore_menace/receive_assignment']
ENDING=['lore_menace/walk_deeper','lore_menace/confirm_center','lore_menace/return_to_lore',
        'lore_menace/report_success','lore_menace/acknowledge_reward','lore_menace/hear_next_task','lore_menace/leave_audience']
CASES={
    'skip':[*INTRO,'lore_menace/leave_castle','i/threshold_yes','i/threshold_outside',
        'lore_menace/decline_skeleton','lore_menace/set_out','lore_menace/enter_menace',*ENDING],
    'three_visits':[*INTRO,'i/armory_first','i/armory_finish','i/armory_back','i/visit_streets','i/streets_repeat_hint',
        'i/street_second_back','i/visit_grave','i/grave_chest','i/grave_chest_back','i/threshold_yes','i/threshold_outside',
        'i/skeleton_ask','i/conversation_back','lore_menace/accept_skeleton','lore_menace/set_out','i/choose_role',
        'i/use_party_hunter','i/role_back_party_hunter','i/use_party_magician','i/role_enter_party_magician',
        'lore_menace/walk_deeper','lore_menace/confirm_center','i/cave_treasure','i/gold_2','i/gold_back_2',
        'i/shield_find','i/shield_protagonist','i/shield_back',*ENDING[2:]],
    'joe_stays':[*INTRO,'i/explore','i/visit_prison','i/prison_service','i/service_inside','i/accept_joe',
        'i/joe_quiet_exit','i/joe_quiet_back','i/visit_armory','i/armory_finish_joe','i/armory_back','i/depart_now',
        'i/threshold_yes','i/threshold_outside','lore_menace/decline_skeleton','lore_menace/set_out',
        'lore_menace/enter_menace',*ENDING],
    'joe_flees':[*INTRO,'i/explore','i/visit_prison','i/prison_request','i/accept_joe','i/joe_guard_exit',
        'i/guard_escape','i/guard_try_again','i/guard_repeat_win','i/guard_victory_back','i/depart_now',
        'i/threshold_no','i/threshold_reconsider','i/threshold_yes','i/threshold_outside','lore_menace/accept_skeleton',
        'lore_menace/set_out','lore_menace/enter_menace',*ENDING]
}


def assert_reading_position(page, index=-1):
    """New prose, not its trailing choices, gets scroll and keyboard focus."""
    position=page.evaluate('''index => {
        const sections=document.querySelectorAll('#manuscript section');
        const section=sections[index<0 ? sections.length+index : index];
        const top=section.getBoundingClientRect().top+scrollY;
        const limit=document.documentElement.scrollHeight-innerHeight;
        return {actual:scrollY,expected:Math.min(top,Math.max(0,limit)),
                focused:document.activeElement===section.querySelector('h2')};
    }''',index)
    assert position['focused'],position
    assert abs(position['actual']-position['expected'])<=2,position


def check():
    from playwright.sync_api import sync_playwright, expect
    session=Session()
    source=(ROOT/'writing/previews/chapter01-interactive.html').read_text()
    results=[]
    with sync_playwright() as playwright:
        browser=playwright.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
        for width,height in [(390,844),(1280,900)]:
            for name,steps in CASES.items():
                page=browser.new_page(viewport={'width':width,'height':height})
                errors,requests=[],[]
                page.on('pageerror',lambda e:errors.append(str(e)))
                page.on('request',lambda r:requests.append(r.url))
                page.set_content(source)
                page.locator('details summary').click()
                route=[]
                for step in steps:
                    first_new_section=page.locator('#manuscript section').count()
                    page.locator('button[data-choice="'+step+'"]').click()
                    assert_reading_position(page,first_new_section)
                    route,packet=session.choose(route,step)
                    current=page.locator('#manuscript section').last
                    for block in packet['visible_blocks']:
                        assert current.locator('p[data-block-id="'+block['id']+'"]').count()==1,(name,step,block['id'])
                    assert page.locator('#choices button').count()==len(packet['available_choices']),(name,step)
                    assert not errors,(name,step,errors)
                    assert page.evaluate('document.documentElement.scrollWidth<=innerWidth'),(name,step,'overflow')
                expected=session.replay(route)
                text=page.locator('#state').inner_text()
                assert '금화: '+str(expected['state']['event.gold']) in text,(name,text,expected['state']['event.gold'])
                if name=='three_visits':
                    assert page.locator('p[data-block-id="i/shield_equipped_words"]').inner_text()=='서진이 황금의 방패를 장착했다.'
                    assert '3/3곳' in text
                if name=='joe_stays':assert '매드 조' in text
                if name=='joe_flees':assert '매드 조' not in text
                assert not requests,requests
                # Download contains only a version-bound route; import reconstructs identical DOM.
                with page.expect_download() as info:page.locator('#save').click()
                download=info.value
                saved=json.loads(open(download.path(),encoding='utf-8').read())
                assert set(saved)=={'fingerprint','route'} and saved['route']==route
                page.locator('#restart').click()
                assert_reading_position(page,0)
                page.locator('#file').set_input_files({'name':'route.json','mimeType':'application/json','buffer':json.dumps(saved).encode()})
                expect(page.locator('#message')).to_have_text('경로를 검증하고 상태를 다시 계산했습니다.')
                assert_reading_position(page)
                assert page.locator('#state').inner_text()==text
                forged={**saved,'state':{'event.gold':999999}}
                page.locator('#file').set_input_files({'name':'forged.json','mimeType':'application/json','buffer':json.dumps(forged).encode()})
                expect(page.locator('#message')).to_contain_text('변조')
                assert page.locator('#state').inner_text()==text
                stale={**saved,'fingerprint':'outdated'}
                page.locator('#file').set_input_files({'name':'stale.json','mimeType':'application/json','buffer':json.dumps(stale).encode()})
                expect(page.locator('#message')).to_contain_text('다른 판본')
                page.locator('#back').click()
                assert_reading_position(page)
                assert page.locator('#choices button').count()>0
                assert not errors and not requests,(errors,requests)
                results.append({'case':name,'width':width,'choices_replayed':len(route),'network_requests':len(requests)})
                page.close()
        browser.close()
    return results


if __name__=='__main__':print(json.dumps(check(),ensure_ascii=False,indent=2))
