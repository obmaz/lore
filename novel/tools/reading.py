"""Compile quest JSON into a draft reading path without resetting story memory."""
import copy

from materials import ROOT, read
from story_continuity import CANON, validate


def compile_reading(parts):
    """Parts are trusted local story/continuity pairs; no imported save/knowledge blobs."""
    if not parts:
        raise ValueError('reading needs at least one quest')
    canon = read(CANON)
    pairs = []
    for story,memory in parts:
        validate(story,memory,canon)
        if story['meta'].get('reference_text') is not True:
            raise ValueError('reading requires reference-based drafts')
        pairs.append((copy.deepcopy(story),copy.deepcopy(memory)))
    base,continuity = copy.deepcopy(pairs[0])
    base['meta'].update(id='reading_'+'_'.join(s['meta']['id'] for s,_ in pairs),status='draft',revision=1)
    base.update(source_refs={},state_definitions={},nodes=[],open_questions=[])
    base['coverage'].update(status='partial',required_source_refs=[],deferred_source_refs=[],literal_dispositions=[],notes='파생 읽기본. 승인 원고가 아니며 원문 완성을 주장하지 않는다.')
    continuity.update(story_id=base['meta']['id'],story_revision=1,contracts={},event_templates=[],threads=[])
    continuity['review'].update(status='draft',issues=[],approved_story_revision=None,approved_canon_revision=None,approved_input_hashes=None)
    prior = None
    for index,(story,memory) in enumerate(pairs):
        prefix = story['meta']['quest_id']+'/'
        ref_ids = {key:prefix+key for key in story['source_refs']}
        nodes = {n['id']:prefix+n['id'] for n in story['nodes']}
        blocks = {b['id']:prefix+b['id'] for n in story['nodes'] for b in n['blocks']}
        choices = {c['id']:prefix+c['id'] for n in story['nodes'] for c in n['choices']}
        events = {e['id']:prefix+e['id'] for e in memory['event_templates']}
        def refs(values): return [ref_ids[key] for key in values]
        def provenance(p): p['source_refs'] = refs(p['source_refs'])
        if prior:
            previous,previous_memory,previous_nodes,previous_choices = prior
            boundaries = [n for n in previous['nodes'] if n['handoff'] and n['handoff']['quest_id']==story['meta']['quest_id']]
            if len(boundaries)!=1:
                raise ValueError('reading needs one explicit handoff to the next quest')
            old = boundaries[0]
            handoff = old['handoff']
            if handoff['entry_node']!=story['entry_node']:
                raise ValueError('handoff entry differs from next quest entry')
            shared = set(previous['state_definitions']) & set(story['state_definitions'])
            if shared!=set(handoff['carry_states']):
                raise ValueError('shared states must match explicit handoff; no implicit memory reset')
            for key in shared:
                a,b = previous['state_definitions'][key],story['state_definitions'][key]
                if a['scope']!='story' or b['scope']!='story' or a['type']!=b['type']:
                    raise ValueError('incompatible handoff state: '+key)
            merged = next(n for n in base['nodes'] if n['id']==previous_nodes[old['id']])
            merged.update(kind='merge',handoff=None)
            merged['choices'] = [{'id':previous_nodes[old['id']]+'/continue','label':[{'text':'다음 이야기로 이어간다'}],
                'when':True,'target':nodes[story['entry_node']],'effects':[],'branch_kind':'navigation',
                'consequence':[{'text':'앞선 선택의 상태·지식·사건을 초기화하지 않는다.'}],
                'provenance':{'origin':'authored','source_refs':[],'note':'집필 파일 경계 연결용 파생 선택. 게임 선택지가 아니다.'}}]
        for key,value in story['state_definitions'].items():
            if key not in base['state_definitions']:
                value = copy.deepcopy(value); provenance(value['provenance']); base['state_definitions'][key] = value
        base['source_refs'].update({ref_ids[k]:v for k,v in story['source_refs'].items()})
        for original in story['nodes']:
            node = copy.deepcopy(original)
            node['id'] = nodes[node['id']]; provenance(node['provenance'])
            node['editorial']['source_refs'] = refs(node['editorial']['source_refs'])
            for b in node['blocks']: b['id'] = blocks[b['id']]; provenance(b['provenance'])
            for c in node['choices']:
                c['id'],c['target'] = choices[c['id']],nodes[c['target']]
                provenance(c['provenance'])
                for effect in c['effects']: provenance(effect['provenance'])
            base['nodes'].append(node)
        if index==0: base['entry_node'] = nodes[story['entry_node']]
        for key,contract in memory['contracts'].items():
            contract = copy.deepcopy(contract)
            contract['must_include_block_ids'] = [blocks[b] for b in contract['must_include_block_ids']]
            continuity['contracts'][nodes[key]] = contract
        for e in memory['event_templates']:
            e = copy.deepcopy(e)
            e['id'],e['trigger_choice'] = events[e['id']],choices[e['trigger_choice']]
            e['source_refs'],e['requires_events'] = refs(e['source_refs']),[events[k] for k in e['requires_events']]
            continuity['event_templates'].append(e)
        for thread in memory['threads']:
            thread = copy.deepcopy(thread); thread['id'] = prefix+thread['id']
            if thread['resolution_event']: thread['resolution_event'] = events[thread['resolution_event']]
            continuity['threads'].append(thread)
        base['open_questions'] += story['open_questions']
        continuity['review']['issues'] += memory['review']['issues']
        coverage = story['coverage']
        base['coverage']['required_source_refs'] += refs(coverage['required_source_refs'])
        base['coverage']['deferred_source_refs'] += [{**d,'ref':ref_ids[d['ref']]} for d in coverage['deferred_source_refs']]
        for d in coverage['literal_dispositions']:
            base['coverage']['literal_dispositions'].append({**d,'block_ids':[blocks[b] for b in d['block_ids']], 'choice_ids':[choices[c] for c in d['choice_ids']]})
        prior = story,memory,nodes,choices
    if len({d['literal_id'] for d in base['coverage']['literal_dispositions']})!=len(base['coverage']['literal_dispositions']):
        raise ValueError('overlapping source dispositions between quests; assign each occurrence once')
    validate(base,continuity,canon)
    return base,continuity


def load_reading(recipe):
    pairs = []
    route = []
    for index,part in enumerate(recipe['parts']):
        path = (ROOT/'writing/quests'/part['file']).resolve()
        if not path.is_relative_to((ROOT/'writing/quests').resolve()):
            raise ValueError('reading path escapes writing/quests')
        story = read(path)
        pairs.append((story,read(path.with_name(path.stem+'.continuity.json'))))
        prefix = story['meta']['quest_id']+'/'
        route += [prefix+c for c in part['route']]
        if index<len(recipe['parts'])-1:
            # Replay/validate proves the previous route actually reaches the link.
            from story_continuity import context
            p,m = compile_reading(pairs)
            packet = context(p,m,read(CANON),route)
            if not packet['handoff_packet']:
                raise ValueError('reading route does not reach a quest handoff')
            route.append(packet['node_id']+'/continue')
    story,memory = compile_reading(pairs)
    if 'title' in recipe: story['meta']['title'] = copy.deepcopy(recipe['title'])
    story['meta']['summary'] = [{'text':'도입부터 첫 탐사 성공 보고와 다음 지역의 부탁까지 이어 읽는 미승인 초고.'}]
    return story,memory,route
