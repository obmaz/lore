"""Optional authored adventures compiled around, never into, the core contract."""
import argparse
import copy
import hashlib
import html
import json
from collections import Counter
from functools import cached_property

import jsonschema
from referencing import Registry, Resource

from materials import ROOT, read
from branch_system import BranchSession, PLAN as CORE, TEMPLATE
from publication_flow import PublicationFlow, PLAN as CORE_FLOW
from reference import COMMON, validate_claim
from story_continuity import fingerprint

PLAN = ROOT/'writing/side-stories/series.json'
SCHEMA = ROOT/'writing/side-stories.schema.json'
READER = ROOT/'writing/side-stories/reader.js'
OUTPUT = ROOT/'writing/side-stories/generated'


class SideStorySession(BranchSession):
    def __init__(self, base=None, proposal=None):
        self.base = base or BranchSession()
        self.proposal = copy.deepcopy(read(PLAN) if proposal is None else proposal)
        schemas = [read(SCHEMA), read(COMMON), read(ROOT/'authoring/story.schema.json')]
        registry = Registry().with_resources((s['$id'], Resource.from_contents(s)) for s in schemas)
        registry = registry.with_resource('https://lore.local/novel/authoring/story.schema.json', Resource.from_contents(schemas[-1]))
        jsonschema.Draft202012Validator(schemas[0], registry=registry).validate(self.proposal)
        self.stories = self.proposal['stories']
        stable_equipment = {self.base.states[key]['initial']: key
            for holder, key in self.base.contract['equipment_states'].items()
            if holder in self.base.contract['core_members'] and self.base.states[key]['initial']}
        touched = {effect['state'] for decision in self.base.plan['decisions']
                   for option in decision['options'] for effect in option['effects']}
        touched.update(effect['state'] for rule in self.base.plan['unit_rules'].values() for effect in rule['effects'])
        if Counter(s['chapter_id'] for s in self.stories) != Counter({c['chapter_id']:2 for c in self.base.outline['chapters']}):
            raise ValueError('side stories must cover every chapter twice')
        if len({s['id'] for s in self.stories}) != len(self.stories):
            raise ValueError('duplicate side story ID')
        merged, outline = copy.deepcopy(self.base.plan), copy.deepcopy(self.base.outline)
        units = {u['id']:u for c in outline['chapters'] for u in c['units']}
        sequence = list(units)
        parallel = {k for g in self.base.groups.values() for b in g['blocks'] for k in b} | {g['entry'] for g in self.base.groups.values()}
        self.story_by_decision = {}
        self.approach_by_decision = {}
        for story in self.stories:
            validate_claim({'field':'side_story','value':story['title'],'origin':story['origin'],'status':story['status'],'evidence':[],'metadata':story['metadata']})
            texts=[story[field] for field in ('title','prompt','participate_label','participate','skip_label','skip','on_participate','on_skip')]
            if 'approach' in story:
                choices=story['approach']['options']
                if len({o['id'] for o in choices})!=2 or any(o['id']=='bypass' for o in choices):
                    raise ValueError('nested approach IDs must be unique and cannot use bypass')
                texts += [story['approach']['prompt'],*[o[field] for o in choices for field in ('label','body','reaction')]]
            for text in texts:
                self.base._text(text)
                for part in text:
                    ref = part.get('ref', {})
                    if ref.get('catalog') == 'equipment' and (ref['id'] not in stable_equipment or stable_equipment[ref['id']] in touched):
                        raise ValueError('side weapon prose needs review against current core equipment')
            anchor, target = story['anchor_unit'], story['reaction_unit']
            if anchor not in units or (target is not None and target not in units) or not anchor.startswith(story['chapter_id']+'/'):
                raise ValueError('side story has an unknown or foreign anchor')
            if anchor in parallel or (target is not None and sequence.index(target)<=sequence.index(anchor)) or units[anchor]['reading_next'] is None:
                raise ValueError('side story must rejoin a following main unit outside parallel blocks')
            meta = copy.deepcopy(story['metadata'])
            state, did = 'side.'+story['id'], 'side_'+story['id']
            if state in merged['state_definitions'] or any(d['id']==did for d in merged['decisions']):
                raise ValueError('side story collides with a core ID')
            self.story_by_decision[did] = story
            merged['state_definitions'][state] = {'type':'boolean','initial':False,'authority':'branch','description':story['title'],
                'reference_catalog':None,'values':None,'holder':None,'minimum':0,'maximum':1,'origin':'authored','metadata':meta}
            # The shared template supplies the existing decision shape. Only the
            # authored overlay changes; the canonical mandatory unit is intact.
            decision = copy.deepcopy(read(TEMPLATE)['decision'])
            decision.update(id=did,unit_id=anchor,prompt=story['prompt'],rejoin_before=units[anchor]['reading_next'],
                            source_section_refs=units[anchor]['source_section_refs'],origin='authored',metadata=meta)
            decision['options'] = []
            for mode, completed in [('take',True),('skip',False)]:
                body = 'participate' if completed else 'skip'
                prose=copy.deepcopy(story[body])
                if target is None and (not completed or 'approach' not in story):
                    prose += [{'text':'\n\n'}]+story['on_participate' if completed else 'on_skip']
                decision['options'].append({'id':did+'/'+mode,'label':story[body+'_label'],'body':prose,
                    'when':True,'participants':[],'effects':[{'state':state,'op':'set','value':completed,'origin':'authored','metadata':meta}],
                    'origin':'authored','metadata':meta})
                if target is not None and (not completed or 'approach' not in story):
                    merged['reactions'].append({'id':did+'_'+mode,'unit_id':target,'when':{'op':'eq','state':state,'value':completed},
                        'participants':[],'requires_units':[anchor],'text':story['on_participate' if completed else 'on_skip'],
                        'origin':'authored','metadata':meta})
            merged['decisions'].append(decision)
            if 'approach' in story:
                aid, memory = did+'_approach', state+'.approach'
                self.approach_by_decision[aid]=story
                merged['state_definitions'][memory]={**copy.deepcopy(merged['state_definitions'][state]),'description':story['approach']['prompt']}
                approach=copy.deepcopy(decision)
                approach.update(id=aid,prompt=story['approach']['prompt'],options=[])
                for index,option in enumerate(story['approach']['options']):
                    prose=copy.deepcopy(option['body'])
                    if target is None:prose += [{'text':'\n\n'}]+option['reaction']
                    approach['options'].append({'id':aid+'/'+option['id'],'label':option['label'],'body':prose,
                        'when':{'op':'eq','state':state,'value':True},'participants':[],
                        'effects':[{'state':memory,'op':'set','value':bool(index),'origin':'authored','metadata':meta}],
                        'origin':'authored','metadata':meta})
                    if target is not None:
                        merged['reactions'].append({'id':aid+'_'+option['id'],'unit_id':target,
                            'when':{'all':[{'op':'eq','state':state,'value':True},{'op':'eq','state':memory,'value':bool(index)}]},
                            'participants':[],'requires_units':[anchor],'text':option['reaction'],'origin':'authored','metadata':meta})
                # One available option is automatic in the existing core engine.
                # This bypass is a technical trace, never a reader question.
                approach['options'].append({'id':aid+'/bypass','label':[{'text':'자동 연결 · 참여하지 않은 곁가지'}],
                    'body':[{'text':'이 곁가지를 맡지 않은 일행은 해결 방법을 고르지 않고 원래 길을 잇는다.'}],
                    'when':{'op':'eq','state':state,'value':False},'participants':[],'effects':[],
                    'origin':'authored','metadata':meta})
                merged['decisions'].append(approach)
            unit = units[anchor]
            unit['branch'] = {'status':'deferred','mode':'candidate','variation_scope':story['title'],
                'rejoin_before':unit['reading_next'],'carry_keys':[state],'main_result_locked':True}
        merged['limits']['max_paths'] = max(512,merged['limits']['max_paths'])
        merged['limits']['max_manual_choices'] += len(self.stories)+len(self.approach_by_decision)
        merged['notes'].append('곁가지는 side.* 기억만 변경한다. 아래 컴파일 자료는 읽기 전용이며 원본은 side-stories/series.json이다. 전 조합은 열거하지 않고 상태 격리와 본줄기 투영, 대표 경로로 검사한다.')
        super().__init__(merged,outline,profiles=self.base.profiles,references=self.base.references)
        self.fingerprint = fingerprint({'runtime':self.fingerprint,'proposal':self.proposal,
            'side_engine':hashlib.sha256(ROOT.joinpath('tools/side_stories.py').read_bytes()).hexdigest(),
            'side_schema':hashlib.sha256(SCHEMA.read_bytes()).hexdigest()})
        self.publication_branch_path = OUTPUT/'runtime.plan.json'
        self.publication_flow_path = OUTPUT/'flow.plan.json'
        self.source_outline = self.base.outline

    @cached_property
    def core_routes(self):
        stack, routes = [[]], []
        while stack:
            route = stack.pop(); packet = self.base.replay(route)
            if packet['status']=='complete': routes.append(route)
            else: stack.extend([*route,o['id']] for o in packet['available_options'])
            if len(stack)+len(routes)>self.base.plan['limits']['max_paths']:
                raise ValueError('core route limit exceeded; no coverage claim')
        return routes

    def expand_route(self, core_route, mode='skip', overrides=None, approaches=None):
        if mode not in ('take','skip'): raise ValueError('unknown side mode')
        overrides = overrides or {}
        if not set(overrides)<=set(self.story_by_decision) or any(v not in ('take','skip') for v in overrides.values()):
            raise ValueError('unknown side override')
        approaches=approaches or {}
        if not set(approaches)<=set(self.approach_by_decision) or any(value not in {o['id'] for o in self.approach_by_decision[did]['approach']['options']} for did,value in approaches.items()):
            raise ValueError('unknown nested approach override')
        route, cursor = [], 0
        while True:
            packet = self.replay(route)
            if packet['status']=='complete':
                if cursor!=len(core_route): raise ValueError('unused core choices')
                return route
            did = packet['decision_id']
            if did in self.approach_by_decision:
                story=self.approach_by_decision[did]
                selected=did+'/'+approaches.get(did,story['approach']['options'][0]['id'])
            elif did in self.story_by_decision: selected = did+'/'+overrides.get(did,mode)
            else:
                if cursor>=len(core_route): raise ValueError('incomplete core route')
                selected=core_route[cursor]; cursor+=1
            if selected not in {o['id'] for o in packet['available_options']}: raise ValueError('unavailable expanded choice')
            route.append(selected)

    @cached_property
    def validation_routes(self):
        routes=[self.expand_route(route,mode) for route in self.core_routes for mode in ('take','skip')]
        mixed={did:'take' if i%2 else 'skip' for i,did in enumerate(self.story_by_decision)}
        routes.append(self.expand_route(read(CORE_FLOW)['linear_editions'][0]['manual_route'],overrides=mixed))
        for did,story in self.approach_by_decision.items():
            routes.append(self.expand_route(read(CORE_FLOW)['linear_editions'][0]['manual_route'],'take',
                approaches={did:story['approach']['options'][1]['id']}))
        return routes

    @staticmethod
    def main_history(packet):
        return [h for h in packet['history'] if not h.get('decision_id','').startswith('side_') and not h.get('id','').startswith('side_')]

    @cached_property
    def safety_report(self):
        # Exhaustive core paths, paired with all-take/all-skip, plus a mixed
        # witness. The algebraic product relies on the compiler's strict writes:
        # parent booleans, parent-gated approach booleans, and pure callbacks.
        witnessed_options=set()
        for route in self.validation_routes:
            packet=self.replay(route)
            witnessed_options.update(h['id'] for h in packet['history'] if h['kind'] in ('choice','automatic'))
            core_route=[key for key in route if not key.startswith('side_')]
            core=self.base.replay(core_route)
            if self.main_history(packet)!=core['history'] or packet['visited_units']!=core['visited_units'] or packet['completed_beats']!=core['completed_beats']:
                raise ValueError('side story changed the mandatory main history')
            if {k:packet['state'][k] for k in self.base.states}!=core['state']:
                raise ValueError('side story changed core party, inventory, knowledge or progress')
            for did,story in self.story_by_decision.items():
                chosen=next(h for h in packet['history'] if h.get('decision_id')==did)
                matches=[h for h in packet['history'] if h['kind']=='reaction' and (h['id'] in (did+'_take',did+'_skip') or h['id'].startswith(did+'_approach_'))]
                expected=did+'_'+chosen['id'].rsplit('/',1)[1]
                if 'approach' in story:
                    nested=next(h for h in packet['history'] if h.get('decision_id')==did+'_approach')
                    if chosen['id'].endswith('/take'):
                        if nested['kind']!='choice' or nested['id'].endswith('/bypass'):raise ValueError('nested choice missing under participation')
                        expected=nested['decision_id']+'_'+nested['id'].rsplit('/',1)[1]
                    elif nested['kind']!='automatic' or not nested['id'].endswith('/bypass'):
                        raise ValueError('nested story appeared under a skipped parent')
                if story['reaction_unit'] is None:
                    if matches:raise ValueError('self-contained story invented a later callback')
                elif len(matches)!=1 or matches[0]['id']!=expected or matches[0]['unit_id']!=story['reaction_unit']:
                    raise ValueError('side experience leaked, was omitted or used the wrong callback')
        if witnessed_options!={o['id'] for d in self.plan['decisions'] for o in d['options']}:
            raise ValueError('a declared option lacks a complete runtime witness')
        nested=len(self.approach_by_decision)
        return {'chapters':len({s['chapter_id'] for s in self.stories}),'side_stories':len(self.stories),
            'side_decisions':len(self.stories)+nested,'side_options':2*len(self.stories)+3*nested,
            'reader_side_options':2*len(self.stories)+2*nested,'nested_decisions':nested,'automatic_bypasses':nested,
            'self_contained_stories':sum(s['reaction_unit'] is None for s in self.stories),
            'cross_chapter_callbacks':sum(s['reaction_unit'] is not None and not s['reaction_unit'].startswith(s['chapter_id']+'/') for s in self.stories),
            'core_complete_paths':len(self.core_routes),'witness_paths_checked':len(self.validation_routes),
            'projected_complete_paths':len(self.core_routes)*2**(len(self.stories)-nested)*3**nested,'cartesian_paths_enumerated':False,
            'mechanical_main_projection_preserved':True,'validation_strategy':'isolated parent and gated approach booleans + exhaustive core projections + paired, mixed and each nested alternative witnesses',
            'all_declared_options_reachable':True,'prose_status':'draft','prose_approved':False,'public_reader_updated':False}

    def validate_paths(self):
        return self.safety_report


class SidePublicationFlow(PublicationFlow):
    def __init__(self, base=None, proposal=None):
        session=SideStorySession(base,proposal)
        plan=copy.deepcopy(read(CORE_FLOW))
        for did,s in session.story_by_decision.items():
            plan['decision_titles'][did]=s['title']
            for mode,label in [('take','참여한 경험'),('skip','지나친 경험')]:
                if s['reaction_unit'] is not None and (mode=='skip' or 'approach' not in s):
                    plan['reaction_titles'][did+'_'+mode]=[*s['title'],{'text':' · '+label}]
            if 'approach' in s:
                aid=did+'_approach'
                plan['decision_titles'][aid]=[*s['title'],{'text':' · 해결 방법'}]
                if s['reaction_unit'] is not None:
                    for option in s['approach']['options']:
                        plan['reaction_titles'][aid+'_'+option['id']]=[*s['title'],{'text':' · '},*option['label']]
        plan['linear_editions']=[{**edition,'id':edition['id']+'-sides-'+mode,
            'manual_route':session.expand_route(edition['manual_route'],mode),
            'note':edition['note']+' 곁가지 '+('참여' if mode=='take' else '거절')+'를 포함한 별도 편집 예시.'}
            for edition in plan['linear_editions'] for mode in ('take','skip')]
        plan['notes'].append('30개 곁가지와 5개 중첩 선택은 창작 초고다. 부모 참여 뒤에만 해결 방법을 고르고 지나친 경우 자동으로 본줄기를 잇는다. 전체 조합을 열거하지 않았으며 원작 해석·산문 의미·출판 승인은 자동 증명하지 않는다.')
        super().__init__(plan=plan,session=session)
        self.report['side_stories']=session.safety_report

    def timeline(self):
        timeline=super().timeline()
        for aid,story in self.session.approach_by_decision.items():
            group=timeline['groups'][aid]
            group['parent_group']='side_'+story['id']
            group['parent_option']=group['parent_group']+'/take'
            group['options']=[o for o in group['options'] if not o['id'].endswith('/bypass')]
            for chapter in timeline['chapters']:
                for row in chapter['rows']:
                    if row['kind']=='decision' and row['group_id']==aid:
                        row['cards']=[card for card in row['cards'] if not card['node_id'].endswith('/bypass')]
                    if row['kind']=='reaction':
                        for card in row['cards']:
                            prefix='reaction/'+aid+'_'
                            if card['node_id'].startswith(prefix):
                                oid=aid+'/'+card['node_id'][len(prefix):]
                                row['group_id']=aid
                                card['source_options']=[oid]
                                card['slot']=next(i for i,o in enumerate(group['options']) if o['id']==oid)
        for chapter in timeline['chapters']:
            rows=[]
            for row in chapter['rows']:
                if row['kind']=='reaction' and rows and rows[-1]['kind']=='reaction' and rows[-1]['unit_id']==row['unit_id'] and rows[-1]['group_id']==row['group_id']:
                    rows[-1]['cards'].extend(row['cards'])
                else:rows.append(row)
            chapter['rows']=rows
        used={row.get('group_id') for chapter in timeline['chapters'] for row in chapter['rows']}
        timeline['groups']={key:value for key,value in timeline['groups'].items() if key in used or not key.startswith('condition/')}
        return timeline

    def document(self):
        return super().document().replace('6결정 · 14선택지',f'{self.report["decisions"]}결정 · {self.report["options"]}선택지')


def reader_document(flow):
    from writing import html_doc
    session=flow.session
    core=session.base.replay(read(CORE_FLOW)['linear_editions'][0]['manual_route'])
    chapters=read(ROOT/'writing/storyboard/chapters.json')['chapters']
    data={'chapters':[{'id':c['id'],'number':c['number'],'title':session.display(c['title']),
        'units':[{'id':u['id'],'blocks':[h for h in core['history'] if h['unit_id']==u['id']]} for u in session.base.outline['chapters'][i]['units']]} for i,c in enumerate(chapters)],
        'stories':[{'id':s['id'],'chapter_id':s['chapter_id'],'anchor_unit':s['anchor_unit'],'reaction_unit':s['reaction_unit'],
            **{k:session.display(s[k]) for k in ('title','prompt','participate_label','participate','skip_label','skip','on_participate','on_skip')},
            **({'approach':{'prompt':session.display(s['approach']['prompt']),
                'options':[{**o,**{k:session.display(o[k]) for k in ('label','body','reaction')}} for o in s['approach']['options']]}} if 'approach' in s else {})} for s in session.stories]}
    payload=json.dumps(data,ensure_ascii=False,separators=(',',':')).replace('<','\\u003c').replace('>','\\u003e').replace('&','\\u0026').replace('\u2028','\\u2028').replace('\u2029','\\u2029')
    body='<p class="notice">작가용 · 전편 스포일러 · 각 장 2개 곁가지, 총 30개와 5개 중첩 선택은 창작 초고. 본줄기는 기존 종이책 예시 경로의 주요 내용이며 완성된 장편 본문·원문 대사 전체가 아닙니다. 기존 첫 장 독자 판본과 저장은 별도입니다.</p>'
    body+='<div class="toolbar"><button type="button" id="side-prev">이전 장</button><span id="side-progress"></span><button type="button" id="side-restart">처음부터</button></div><div id="side-content" aria-live="polite"></div><div id="side-choices"></div><button type="button" id="side-next" hidden>다음 장</button><script type="application/json" id="side-data">'+payload+'</script><script>'+READER.read_text(encoding='utf-8')+'</script>'
    return html_doc('전편 곁가지 모험 · 15장 선택 시범',body).replace('</style>','body{font-size:16px}button{font:inherit;padding:8px 12px;cursor:pointer}.toolbar{display:flex;gap:10px;align-items:center;flex-wrap:wrap}.side-story{border-left:3px solid #aa8640;padding-left:16px}.side-memory{border-left:3px solid #657d68;padding-left:16px}.side-badge{font-size:12px;color:#806029}#side-choices{display:grid;gap:10px;margin:16px 0}#side-next{margin-top:14px}[hidden]{display:none!important}</style>')


def export(check=False, flow=None):
    flow=flow or SidePublicationFlow()
    session=flow.session
    artifacts={'runtime.plan.json':session.plan,'flow.plan.json':flow.plan,'flow.graph.json':flow.graph,
        'linear-editions.json':flow.editions,'coverage.json':flow.report}
    texts={name:json.dumps(value,ensure_ascii=False,indent=2)+'\n' for name,value in artifacts.items()}
    texts.update({'flow.md':flow.markdown(),'flow.html':flow.document(),'side-adventures.html':reader_document(flow)})
    inputs=[PLAN,SCHEMA,READER,CORE,CORE_FLOW,ROOT/'writing/storyboard/chapter-subsections.json',ROOT/'writing/storyboard/chapters.json',
        ROOT/'tools/side_stories.py',ROOT/'tools/branch_system.py',ROOT/'tools/publication_flow.py',ROOT/'tools/text_refs.py',ROOT/'tools/story_continuity.py',
        ROOT/'writing/branches.schema.json',ROOT/'writing/publication.schema.json',TEMPLATE,COMMON,ROOT/'authoring/story.schema.json',
        ROOT/'characters/registry.json',ROOT/'reference/names.json',ROOT/'reference/terms.json',*[ROOT/f'reference/{c}.json' for c in session.references]]
    manifest={'version':1,'visibility':'author_only','source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
        'artifacts':{name:hashlib.sha256(value.encode()).hexdigest() for name,value in texts.items()}}
    path=OUTPUT/'manifest.json'
    if path.exists():
        for name,digest in read(path)['artifacts'].items():
            if name not in texts or not (OUTPUT/name).is_file() or hashlib.sha256((OUTPUT/name).read_bytes()).hexdigest()!=digest:
                raise ValueError('side output was manually edited; preserve before regeneration: '+name)
    elif any((OUTPUT/name).exists() for name in texts): raise ValueError('side output exists without manifest')
    if check:
        if not path.exists() or read(path)!=manifest: raise ValueError('side stories are stale; run writing.py export')
    else:
        OUTPUT.mkdir(parents=True,exist_ok=True)
        for name,value in texts.items(): (OUTPUT/name).write_text(value,encoding='utf-8')
        path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return {**session.safety_report,'checked':check}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['validate','export','replay']);parser.add_argument('--check',action='store_true')
    parser.add_argument('--core-route',nargs='*');parser.add_argument('--side-mode',choices=['take','skip'],default='skip')
    args=parser.parse_args()
    if args.action=='export': result=export(args.check)
    else:
        session=SideStorySession()
        result=session.validate_paths() if args.action=='validate' else session.replay(session.expand_route(args.core_route or read(CORE_FLOW)['linear_editions'][0]['manual_route'],args.side_mode))
    print(json.dumps(result,ensure_ascii=False,indent=2))
