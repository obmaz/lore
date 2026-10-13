"""Join only written chapters, preserving prior choices and story-scoped memory."""
import copy

from materials import ROOT, read
from reading import compile_reading
from story_continuity import CANON, context_for_routes, matches, validate

PLAN = ROOT / 'writing/interactive/series.json'


def compile_series():
    from interactive import compile_chapter, coverage, validate_main_story
    story, memory, overlay = compile_chapter()
    plan = read(PLAN)
    if plan['style_revision'] != read(ROOT/'writing/project.json')['style']['revision']:
        raise ValueError('written series style review is stale')
    if plan['branch_policy_ref'] != 'writing/project.json#/branch_policy':
        raise ValueError('written series must use the common branch policy')
    overlay = copy.deepcopy(overlay)
    overlay['chapters'] = [{'id':'chapter01', 'prefixes':['prologue/', 'lore_menace/', 'i/'],
                            'title':copy.deepcopy(story['meta']['title'])}]
    overlay['display_groups'] = {}
    prior_quest = 'lore_menace'
    for chapter, name in zip(plan['chapters'], plan['quest_files'], strict=True):
        path = (ROOT/'writing/quests'/name).resolve()
        if not path.is_relative_to(ROOT/'writing/quests') or chapter['quest_file'] != path.relative_to(ROOT).as_posix():
            raise ValueError('written chapter path is outside the package or mismatched')
        part, part_memory = compile_reading([(read(path), read(path.with_name(path.stem+'.continuity.json')))])
        shared = set(story['state_definitions']) & set(part['state_definitions'])
        if shared != set(chapter['shared_states']):
            raise ValueError('written chapter needs an explicit shared-state contract')
        for key in shared:
            a, b = story['state_definitions'][key], part['state_definitions'][key]
            if a['type'] != b['type'] or a['scope'] != 'story' or b['scope'] != 'story':
                raise ValueError('incompatible chapter memory: '+key)
        boundary = next(n for n in story['nodes'] if n['id'] == prior_quest+'/next_quest_boundary')
        if boundary['handoff']['quest_id'] != chapter['quest_id']:
            raise ValueError('written chapter differs from the original handoff')
        boundary.update(kind='merge', handoff=None)
        boundary['choices'] = [{'id':prior_quest+'/next_quest_boundary/continue',
            'label':[{'text':'다음 장으로 이어진다'}], 'when':True,
            'target':part['entry_node'], 'effects':[], 'branch_kind':'navigation',
            'consequence':[{'text':'앞 장의 선택과 동료·장비·경험을 그대로 이어간다.'}],
            'provenance':{'origin':'authored','source_refs':[],
                          'note':'추가: 실제 집필한 장 사이의 자동 연결. 게임 선택지가 아니다.'}}]
        for key, value in part['state_definitions'].items():
            if key not in shared:
                story['state_definitions'][key] = value
        for field in ('source_refs',):
            if set(story[field]) & set(part[field]):
                raise ValueError('duplicate chapter source reference')
            story[field].update(part[field])
        old_nodes = {n['id'] for n in story['nodes']}
        if old_nodes & {n['id'] for n in part['nodes']}:
            raise ValueError('duplicate written chapter node')
        story['nodes'].extend(part['nodes'])
        story['open_questions'].extend(part['open_questions'])
        memory['contracts'].update(part_memory['contracts'])
        memory['event_templates'].extend(part_memory['event_templates'])
        memory['threads'].extend(part_memory['threads'])
        assigned = [key for unit in chapter['units'] for key in unit['node_ids']]
        if len(assigned) != len(set(assigned)) or set(assigned) != {n['id'] for n in part['nodes']}:
            raise ValueError('written chapter units must assign each node exactly once')
        overlay['display_groups'].update({key:unit['unit_id'] for unit in chapter['units'] for key in unit['node_ids']})
        overlay['main_story']['required_scenes'].extend(chapter['main_story'])
        overlay['main_story']['guard_states'].extend(chapter['guard_states'])
        board = read(ROOT/'writing/storyboard/chapters.json')
        title = next(c['title'] for c in board['chapters'] if c['id']==chapter['chapter_id'])
        overlay['chapters'].append({'id':chapter['chapter_id'], 'prefixes':[chapter['quest_id']+'/'], 'title':title})
        prior_quest = chapter['quest_id']
    story['meta'].update(id='written_series', revision=plan['revision'])
    memory.update(story_id=story['meta']['id'], story_revision=story['meta']['revision'])
    overlay['display_insertions'].update(plan['display_insertions'])
    from text_refs import literals, validate_text, indexes
    from reference import load_references
    from characters import load_characters
    raw=literals()
    blocks={b['id']:b for n in story['nodes'] for b in n['blocks']}
    data=indexes(load_characters(),load_references())
    for key, inserts in plan['display_insertions'].items():
        block=blocks[key]
        if len(block['text'])!=1 or 'source' not in block['text'][0]:
            raise ValueError('dynamic chapter text must retain its source span')
        template=''.join(raw[i]['text'] for i in block['literal_ids'])
        for item in inserts:
            offset=item['offset']
            if not 0<=offset<=len(template):
                raise ValueError('chapter insertion outside archival text')
            if any(b['start']<offset<b['end'] for b in block['text'][0]['source']['bindings']):
                raise ValueError('chapter insertion overlaps a source name binding')
            if 'ref' in item:
                validate_text([{'ref':item['ref']}],data,raw)
            elif item.get('state') not in story['state_definitions'] or story['state_definitions'][item['state']]['type']!='string':
                raise ValueError('chapter name variable must be a declared string ID')
            if item.get('replace_length',0) and (item['replace_length']!=1 or template[offset:offset+1]!='가' or item.get('particle')!='이/가'):
                raise ValueError('only the archived fixed subject particle may be adapted')
    overlay['scope'] = '실제 집필한 1~2장. 전편 15장 개요·선택 시범은 별도 제작 자료.'
    for node in story['nodes']:
        if node['handoff']:
            node['handoff']['carry_states'] = [k for k,d in story['state_definitions'].items() if d['scope']=='story']
    story['coverage'] = coverage(story)
    story['coverage']['notes'] = '실제 집필한 장에 명시한 정적 대사·선택 라벨의 발생별 반영표. 모든 분기의 동시 발생이나 공유 UI·미집필 장의 산문 완성을 뜻하지 않는다. 산문 의미는 별도 편집 검토 대상이다.'
    validate(story, memory, read(CANON))
    validate_main_story(story, memory, overlay['main_story'])
    return story, memory, overlay


class SeriesSession:
    def __init__(self):
        self.story, self.memory, self.overlay = compile_series()
        self.packet_for = context_for_routes(self.story, self.memory, read(CANON))

    def replay(self, route):
        from interactive import check_main_story_route
        if not isinstance(route, list) or len(route)>160 or any(not isinstance(c,str) for c in route):
            raise ValueError('save must contain bounded choice IDs only')
        packet = self.packet_for(route)
        sections = [*packet['history'], {'node_id':packet['node_id'], 'before':packet['state'],
                                       'visible_block_ids':[b['id'] for b in packet['visible_blocks']]}]
        packet['main_story'] = check_main_story_route(self.story, self.overlay['main_story'], sections)
        nodes = {n['id']:n for n in self.story['nodes']}
        seen = set()
        for section in sections:
            key, state = section['node_id'], section['before']
            available = tuple(sorted(c['id'] for c in nodes[key]['choices'] if matches(c['when'],state)))
            forced = any(r['node']==key and matches(r['when'],state) for r in self.overlay['auto_rules'])
            rules = [r for r in self.overlay['auto_rules'] if r['node']==key and matches(r['when'],state)]
            if len(rules)>1 or rules and section.get('choice_id',rules[0]['choice'])!=rules[0]['choice']:
                raise ValueError('required automatic transition bypassed')
            for requirement in self.overlay['conditional_required']:
                if requirement['node']==key and matches(requirement['when'],state) and requirement['block'] not in section['visible_block_ids']:
                    raise ValueError('required branch dialogue hidden')
            if len(available)>1 and not forced:
                fork=(key,available)
                if fork in seen:
                    raise ValueError('same decision cannot be collected twice')
                seen.add(fork)
        return packet

    def advance(self, route):
        route = list(route)
        for _ in self.story['nodes']:
            packet = self.replay(route)
            rules = [r for r in self.overlay['auto_rules'] if r['node']==packet['node_id'] and matches(r['when'],packet['state'])]
            if len(rules)>1:
                raise ValueError('ambiguous automatic transition')
            choice = rules[0]['choice'] if rules else packet['available_choices'][0] if len(packet['available_choices'])==1 else None
            if choice is None:
                return route, packet
            if choice not in packet['available_choices']:
                raise ValueError('unavailable automatic transition')
            route.append(choice)
        raise ValueError('automatic transition cycle')

    def choose(self, route, choice):
        if choice not in self.replay(route)['available_choices']:
            raise ValueError('unavailable choice')
        return self.advance([*route,choice])
