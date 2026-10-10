"""Compose the first-chapter authoring overlay; replay only validated choice IDs."""
import argparse
import copy
import hashlib
import html
import json

from materials import ROOT, read
from characters import load_characters
from reference import load_references
from reading import compile_reading
from story_continuity import CANON, context_for_routes, matches, validate
from text_refs import indexes, literals, render, source_ids, validate_text

OVERLAY = ROOT / 'writing/interactive/chapter01.json'
READER = ROOT / 'writing/interactive/reader.js'
SCHEMA = ROOT / 'writing/interactive/overlay.schema.json'


def compile_chapter(overlay=None):
    overlay = copy.deepcopy(overlay if overlay is not None else read(OVERLAY))
    import jsonschema
    jsonschema.Draft202012Validator(read(SCHEMA)).validate(overlay)
    pairs = []
    for name in overlay['quests']:
        path = (ROOT/'writing/quests'/name).resolve()
        if not path.is_relative_to((ROOT/'writing/quests').resolve()):
            raise ValueError('quest outside independent package')
        pairs.append((read(path),read(path.with_name(path.stem+'.continuity.json'))))
    story,memory = compile_reading(pairs)
    profiles = load_characters()
    story['meta'].update(id=overlay['id'],revision=overlay['revision'],title=overlay['title'])
    story['state_definitions'].update(overlay['state_definitions'])
    story['source_refs'].update(overlay['source_refs'])
    nodes = {n['id']:n for n in story['nodes']}
    for patch in overlay['patches']:
        node = nodes[patch['node']]
        node['blocks'] = [b for b in node['blocks'] if b['id'] not in patch.get('remove_blocks',[])]
        node['blocks'].extend(patch.get('append_blocks',[]))
        for block_id,changes in patch.get('blocks',{}).items():
            next(b for b in node['blocks'] if b['id']==block_id).update(changes)
        for choice_id,changes in patch.get('choices',{}).items():
            next(c for c in node['choices'] if c['id']==choice_id).update(changes)
        node['choices'].extend(patch.get('append_choices',[]))
    for node in overlay['nodes']:
        if node['id'] in nodes:
            raise ValueError('overlay replaces a whole base node')
        nodes[node['id']] = node
        story['nodes'].append(node)
    for node in story['nodes']:
        if node['handoff']:
            node['handoff']['carry_states'] = [k for k,d in story['state_definitions'].items() if d['scope']=='story']
        cast = memory['contracts'].get(node['id'],{}).get('cast',[{'character_id':'protagonist','when':True}])
        for key in overlay['party']:
            if key not in {c['character_id'] for c in cast}:
                cast.append({'character_id':key,'when':{'state':'companions.starting','op':'contains','value':key}})
        for key in ('skeleton','mad_joe'):
            if key not in {c['character_id'] for c in cast}:
                cast.append({'character_id':key,'when':{'state':'companions.optional_recruits','op':'contains','value':key}})
        for block in node['blocks']:
            if block['speaker']:
                member = next((c for c in cast if c['character_id']==block['speaker']),None)
                if member is None:
                    cast.append({'character_id':block['speaker'],'when':copy.deepcopy(block['when'])})
                elif member['when']!=block['when']:
                    member['when'] = {'any':[member['when'],copy.deepcopy(block['when'])]}
        contract = memory['contracts'].setdefault(node['id'],dict(before=True,after=True,must_include_block_ids=[],
            must_not_assert=['squad_whereabouts','lord_moral_judgment'],dependencies=[],continuity_notes=[],knowledge_required=[]))
        contract.update(cast=cast,character_dependencies=[{'character_id':c['character_id'],'revision':profiles['characters'][c['character_id']]['revision']} for c in cast],
            allowed_state_changes=sorted({e['state'] for c in node['choices'] for e in c['effects']}))
        contract['continuity_notes'].append('선택형 초고: 추가 동료·이동·연결 서사는 창작 제안. 증언은 경로 경험이며 세계의 진상이 아니다.')
        conditional = {r['block'] for r in overlay['conditional_required'] if r['node']==node['id']}
        contract['must_include_block_ids'] = [b for b in contract['must_include_block_ids'] if b not in conditional]
    memory.update(story_id=story['meta']['id'],story_revision=story['meta']['revision'],character_registry_revision=profiles['revision'])
    memory['event_templates'].extend(overlay['events'])
    story['coverage'] = coverage(story)
    validate(story,memory,read(CANON),profiles)
    choices = {c['id']:c for n in story['nodes'] for c in n['choices']}
    for rule in overlay['auto_rules']:
        if rule['node'] not in nodes or rule['choice'] not in {c['id'] for c in nodes[rule['node']]['choices']}:
            raise ValueError('invalid automatic transition')
        matches(rule['when'],{k:d['initial'] for k,d in story['state_definitions'].items()})
    data,ls = indexes(profiles,load_references()),literals()
    blocks = {b['id']:b for n in story['nodes'] for b in n['blocks']}
    for rule in overlay['conditional_required']:
        if rule['node'] not in nodes or rule['block'] not in {b['id'] for b in nodes[rule['node']]['blocks']}:
            raise ValueError('conditional required block missing')
        if rule['when']!=blocks[rule['block']]['when']:
            raise ValueError('conditional requirement differs from actual block condition')
    for key,inserts in overlay['display_insertions'].items():
        block = blocks[key]
        if len(block['text'])!=1 or 'source' not in block['text'][0]:
            raise ValueError('dynamic template must retain one archival source span')
        raw = ''.join(ls[i]['text'] for i in block['literal_ids'])
        for insertion in inserts:
            offset = insertion['offset']
            if not 0<=offset<=len(raw): raise ValueError('dynamic insertion outside source template')
            if any(b['start']<offset<b['end'] for b in block['text'][0]['source']['bindings']):
                raise ValueError('dynamic insertion inside a name binding')
            if 'ref' in insertion: validate_text([{'ref':insertion['ref']}],data,ls)
            elif 'state' in insertion:
                if insertion['state'] not in story['state_definitions']: raise ValueError('unknown template variable')
                if insertion.get('state_ref_catalog') and story['state_definitions'][insertion['state']]['type']!='string':
                    raise ValueError('reference-valued template variable must store an ID string')
            elif insertion.get('placeholder')!='호칭 미정': raise ValueError('unapproved unresolved variable placeholder')
            if insertion.get('replace_length',0):
                if insertion['replace_length']!=1 or raw[offset:offset+1]!='가' or insertion.get('particle')!='이/가':
                    raise ValueError('only the archived fixed subject particle may be adapted')
    return story,memory,overlay


def coverage(story):
    ls = literals()
    blocks,choices = {},{}
    for node in story['nodes']:
        for b in node['blocks']:
            for key in source_ids(b['text']): blocks.setdefault(key,[]).append(b['id'])
        for c in node['choices']:
            for key in source_ids(c['label']): choices.setdefault(key,[]).append(c['id'])
            if c.get('label_literal_id') and c['label_literal_id'] not in source_ids(c['label']):
                choices.setdefault(c['label_literal_id'],[]).append(c['id'])
    scoped = {key:l for key,l in ls.items() if any(r['file']==l['source']['file'] and r['line_start']<=l['source']['line']<=r['line_end'] for r in story['source_refs'].values())}
    dispositions = []
    for key,literal in scoped.items():
        included = key in blocks or key in choices
        dialogue = literal['role'] in ('display_text_fragment','choice_label_or_prompt','text_variable_fragment') and bool(literal['text'].strip())
        if dialogue and not included:
            raise ValueError('chapter dialogue omitted: '+key+' '+literal['text'])
        dispositions.append(dict(literal_id=key,handling='verbatim' if included else 'non_story',block_ids=blocks.get(key,[]),choice_ids=choices.get(key,[]),
            reason='조건별 보존 원문. 모든 경로에서 동시에 발생하지 않는다.' if included else '빈 레이아웃 문자열 또는 선언·제어·표시 서식. 실제 비어 있지 않은 대사는 제외하지 않는다.'))
    used_refs = {r for n in story['nodes'] for item in [*n['blocks'],*n['choices']] for r in item['provenance']['source_refs']}
    return dict(status='complete',required_source_refs=sorted(used_refs),deferred_source_refs=[],literal_dispositions=dispositions,
        notes='첫 챕터에 명시한 원문 범위의 정적 대사·선택 라벨 반영. 공유 상점/전투 UI와 후속 퀘스트 전체의 완성을 뜻하지 않음. 산문 의미와 원작 미확정 접근 조건은 편집 검토 필요.')


class Session:
    def __init__(self,overlay=None):
        self.story,self.memory,self.overlay = compile_chapter(overlay)
        self.packet_for = context_for_routes(self.story,self.memory,read(CANON))

    def replay(self,route):
        if not isinstance(route,list) or len(route)>160 or not all(isinstance(c,str) for c in route):
            raise ValueError('save must contain a bounded choice-ID route only')
        packet = self.packet_for(route)
        for section in [*packet['history'],{'node_id':packet['node_id'],'before':packet['state'],'visible_block_ids':[b['id'] for b in packet['visible_blocks']]}]:
            for rule in self.overlay['conditional_required']:
                if rule['node']==section['node_id'] and matches(rule['when'],section['before']) and rule['block'] not in section['visible_block_ids']:
                    raise ValueError('required branch dialogue hidden')
        return packet

    def choose(self,route,choice):
        packet = self.replay(route)
        if choice not in packet['available_choices']: raise ValueError('unavailable choice')
        route = [*route,choice]
        for _ in range(8):
            packet = self.replay(route)
            rules = [r for r in self.overlay['auto_rules'] if r['node']==packet['node_id'] and matches(r['when'],packet['state'])]
            if not rules: return route,packet
            if len(rules)!=1 or rules[0]['choice'] not in packet['available_choices']: raise ValueError('ambiguous automatic transition')
            route.append(rules[0]['choice'])
        raise ValueError('automatic transition cycle')


def documents():
    story,memory,overlay = compile_chapter()
    from writing import html_doc
    profiles = load_characters()
    data,ls = indexes(profiles,load_references()),literals()
    # Public labels only; never serialize the master cards/canon/future relationships.
    labels = {category:{key:render([{'ref':{'catalog':category,'id':key}}],data,ls,profiles,()) for key in keys} for category,keys in {
        'characters':set(overlay['party'])|{'protagonist','skeleton','mad_joe'}|{b['speaker'] for n in story['nodes'] for b in n['blocks'] if b['speaker']},
        'equipment':set(overlay['initial_equipment'].values())|{'weapon_0','weapon_1','shield_5'}}.items()}
    for n in story['nodes']:
        for t in [n['title'],*[b['text'] for b in n['blocks']],*[c[f] for c in n['choices'] for f in ('label','consequence')]]:
            for span in t:
                refs = [span['ref']] if 'ref' in span else [b['ref'] for b in span.get('source',{}).get('bindings',[])]
                for ref in refs:
                    labels.setdefault(ref['catalog'],{})[ref['id']] = render([{'ref':{'catalog':ref['catalog'],'id':ref['id']}}],data,ls,profiles,())
    used = {i for n in story['nodes'] for b in n['blocks'] for i in source_ids(b['text'])} | {i for n in story['nodes'] for c in n['choices'] for i in source_ids(c['label'])}
    payload = {'version':overlay['revision'],'entry':story['entry_node'],'initial':{k:d['initial'] for k,d in story['state_definitions'].items()},
        'nodes':story['nodes'],'labels':labels,'literals':{i:ls[i]['text'] for i in used},'events':memory['event_templates'],
        'auto_rules':overlay['auto_rules'],'insertions':overlay['display_insertions'],'party':overlay['party'],'equipment':overlay['initial_equipment'],
        'contracts':memory['contracts'],'conditional_required':overlay['conditional_required']}
    encoded = json.dumps(payload,ensure_ascii=False,sort_keys=True)
    payload['fingerprint'] = hashlib.sha256(encoded.encode()).hexdigest()
    safe = json.dumps(payload,ensure_ascii=False,sort_keys=True).replace('<','\\u003c').replace('&','\\u0026')
    body = '<p class="notice">첫 챕터 선택형 초고 · 기존 긴 원고를 이어 읽습니다. 선택한 경로만 본문에 표시됩니다. 원작 조건을 잇는 탐방 규칙·네 시작 동료는 집필용 추가입니다.</p><p><button id="back" type="button">한 선택 뒤로</button> <button id="restart" type="button">처음부터</button> <button id="save" type="button">경로 저장</button> <button id="load" type="button">경로 불러오기</button><input id="file" type="file" accept="application/json" hidden></p><p id="message" role="status"></p><details><summary>현재 동료·장비·경험</summary><div id="state"></div></details><div id="manuscript"></div><div id="choices" aria-label="이야기 선택"></div>'
    body += '<script type="application/json" id="chapter-data">'+safe+'</script><script>'+READER.read_text()+'</script>'
    page = html_doc('첫 챕터 · 선택하며 읽기',body).replace('</style>','button{max-width:100%;white-space:normal;overflow-wrap:anywhere;cursor:pointer;margin:4px;padding:10px}#choices{display:flex;flex-wrap:wrap}#state{overflow-wrap:anywhere}.selected{border-left:3px solid #977;padding-left:12px}@media print{#choices,button,#state{display:none}}</style>')
    report = {'version':1,'scope':overlay['scope'],'status':'draft','dialogue_coverage':story['coverage'],
        'nodes':[{'id':n['id'],'choices':[{'id':c['id'],'target':c['target'],'when':c['when'],'effects':c['effects'],'origin':c['provenance']['origin']} for c in n['choices']]} for n in story['nodes']],
        'auto_rules':overlay['auto_rules'],'limitations':['명시 범위 밖 공유 UI·후속 퀘스트 제외','선택형 이동/새 동료는 창작 제안','모든 산문의 의미·원작 접근 조건은 자동 검증 대상이 아님']}
    guide = '<p class="notice">작가 전용 · 분기와 선택 동료의 이탈 스포일러 포함.</p>'+''.join('<h2>'+html.escape(row['title'])+'</h2><p>'+html.escape(row['description'])+'</p>' for row in overlay['branch_guide'])
    guide += '<h2>원문 반영</h2><p>명시한 첫 챕터 범위 '+str(len(story['coverage']['literal_dispositions']))+'개 발생 기록. 상세 위치·본문/선택 ID는 chapter01-coverage.json을 참조합니다. 후속 퀘스트 전체의 완성을 주장하지 않습니다.</p>'
    return {'chapter01-interactive.html':page,'chapter01-branches.html':html_doc('첫 챕터 분기 안내 · 작가용',guide),
        'chapter01-coverage.json':json.dumps(report,ensure_ascii=False,indent=2)+'\n'}


if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--route',nargs='*',default=[])
    args = parser.parse_args()
    session = Session()
    packet = session.replay(args.route)
    print(json.dumps({'node':packet['node_id'],'state':packet['state'],'choices':packet['available_choices'],'needs_review':packet['needs_review']},ensure_ascii=False,indent=2))
