"""Reference-bound publishing trees and DAGs derived from the authoring JSON."""
import argparse
import copy
import hashlib
import html
import json
import textwrap
from collections import Counter
from pathlib import Path

import jsonschema
from referencing import Registry, Resource

from materials import ROOT, read
from reference import COMMON, validate_claim
from text_refs import validate_text, reject_fixed_names, validate_names
from branch_system import BranchSession, PLAN as BRANCHES
from chapter_subsections import PLAN as SUBSECTIONS

PLAN = ROOT/'writing/publication/flow.plan.json'
SCHEMA = ROOT/'writing/publication.schema.json'
OUTPUT = ROOT/'writing/publication/generated'
TEMPLATE = ROOT/'writing/templates/publication-flow.template.json'
CHAPTERS = ROOT/'writing/storyboard/chapters.json'


class PublicationFlow:
    def __init__(self, plan=None, session=None, chapters=None):
        self.plan = copy.deepcopy(plan or read(PLAN))
        self.session = session or BranchSession()
        validate_names(self.session.data)
        self.chapters = copy.deepcopy(chapters or read(CHAPTERS))
        if [c['id'] for c in self.chapters['chapters']] != [c['chapter_id'] for c in self.session.outline['chapters']]:
            raise ValueError('publication chapters differ from subsection contract')
        self.cp, self.up, self.bp, self.pp = [p.relative_to(ROOT).as_posix() for p in (CHAPTERS, SUBSECTIONS, BRANCHES, PLAN)]
        self.docs = {self.cp: self.chapters, self.up: self.session.outline, self.bp: self.session.plan, self.pp: self.plan}
        schemas = [read(SCHEMA), read(COMMON), read(ROOT/'authoring/story.schema.json')]
        registry = Registry().with_resources((s['$id'], Resource.from_contents(s)) for s in schemas)
        registry = registry.with_resource('https://lore.local/novel/authoring/story.schema.json', Resource.from_contents(schemas[-1]))
        jsonschema.Draft202012Validator(schemas[0], registry=registry).validate(self.plan)
        jsonschema.Draft202012Validator(schemas[0], registry=registry).validate(read(TEMPLATE))
        validate_claim({'field': 'publication_flow', 'value': self.plan['notes'], 'origin': self.plan['origin'],
                        'status': 'proposed', 'evidence': [], 'metadata': self.plan['metadata']})
        if set(self.plan['decision_titles']) != {d['id'] for d in self.session.plan['decisions']} or set(self.plan['reaction_titles']) != {r['id'] for r in self.session.plan['reactions']}:
            raise ValueError('flow captions must reference current decisions and reactions')
        for value in [*self.plan['labels'].values(), *self.plan['decision_titles'].values(), *self.plan['reaction_titles'].values()]:
            validate_text(value, self.session.data, self.session.raw)
            reject_fixed_names(value, self.session.data)
            if not self.session.display(value).strip(): raise ValueError('empty flow caption')
        edition_ids = [e['id'] for e in self.plan['linear_editions']]
        if len(edition_ids) != len(set(edition_ids)): raise ValueError('duplicate linear edition')
        self.unit_paths = {u['id']: f'/chapters/{i}/units/{j}' for i, c in enumerate(self.session.outline['chapters']) for j, u in enumerate(c['units'])}
        self.unit_numbers = {u['id']: f'{c["number"]}-{j+1}' for c, row in zip(self.chapters['chapters'], self.session.outline['chapters']) for j, u in enumerate(row['units'])}
        self.decision_paths = {d['id']: f'/decisions/{i}' for i, d in enumerate(self.session.plan['decisions'])}
        self.option_paths = {o['id']: f'/decisions/{i}/options/{j}' for i, d in enumerate(self.session.plan['decisions']) for j, o in enumerate(d['options'])}
        self.reaction_paths = {r['id']: f'/reactions/{i}' for i, r in enumerate(self.session.plan['reactions'])}
        self.variants = {o['id']: self.session.groups[b['group_id']] for b in self.session.plan['parallel_orders'] for o in next(d for d in self.session.plan['decisions'] if d['id']==b['decision_id'])['options']}
        self.nodes, self.edges, self.charts = [], [], []
        self.tree = []
        self.graph = self._build()
        self.editions = self._editions()
        self.report = self.validate()

    def ref(self, file, pointer):
        return {'file': file, 'pointer': pointer}

    def resolve(self, ref):
        if set(ref) != {'file', 'pointer'} or ref['file'] not in self.docs or not ref['pointer'].startswith('/'):
            raise ValueError('unsafe or unknown publication reference')
        value = self.docs[ref['file']]
        try:
            for key in ref['pointer'][1:].split('/'):
                key = key.replace('~1', '/').replace('~0', '~')
                value = value[int(key)] if isinstance(value, list) else value[key]
        except (KeyError, IndexError, ValueError, TypeError) as error:
            raise ValueError('unresolved publication reference') from error
        return value

    def rule_ref(self, unit_id, field):
        key = unit_id.replace('~', '~0').replace('/', '~1')
        return self.ref(self.bp, '/unit_rules/'+key+'/'+field)

    def heading(self, unit_id):
        rule = self.session.plan['unit_rules'].get(unit_id)
        return self.rule_ref(unit_id, 'title_override') if rule and rule.get('title_override') is not None else self.ref(self.up, self.unit_paths[unit_id]+'/title')

    def uid(self, unit_id, context=None, kind='unit'):
        return kind+'/'+unit_id+('@'+context if context else '')

    def node(self, key, kind, chapter, label_ref, prefix='', unit_id=None, context=None, **fields):
        row = {'id': key, 'kind': kind, 'chapter_id': chapter, 'unit_id': unit_id, 'context': context,
               'prefix': prefix, 'label_ref': label_ref, 'label_rich_text': copy.deepcopy(self.resolve(label_ref)),
               'status': 'outline', 'origin': 'authored', 'metadata': self.plan['metadata'], **fields}
        self.nodes.append(row)
        return key

    def edge(self, start, end, kind='read', guard_ref=None, label=None, negated=False):
        self.edges.append({'from': start, 'to': end, 'kind': kind, 'guard_ref': guard_ref, 'negated': negated,
                           'label_ref': self.ref(self.pp, '/labels/'+label) if label else None})

    def _unit(self, key, context=None, skip_decision=None):
        u = self.session.units[key]; chapter = key.split('/')[0]
        base = self.unit_paths[key]; number = self.unit_numbers[key]
        rule = self.session.plan['unit_rules'].get(key)
        main = self.node(self.uid(key, context), 'unit', chapter, self.heading(key), number+' · ', key, context,
                         content_ref=self.rule_ref(key, 'content_override') if rule and rule['content_override'] is not None else self.ref(self.up, base+'/main_content'),
                         state_rule_ref=self.rule_ref(key, 'entry_when') if rule else None,
                         effects_ref=self.rule_ref(key, 'effects') if rule else None,
                         candidate_status='deferred' if u['branch']['mode']=='candidate' and key not in self.session.decisions else 'bound' if key in self.session.decisions else 'none')
        tail = main
        for r in self.session.plan['reactions']:
            if r['unit_id'] != key: continue
            suffix = r['id']+('@'+context if context else '')
            rr = self.ref(self.bp, self.reaction_paths[r['id']])
            rn = self.node('reaction/'+suffix, 'reaction', chapter, self.ref(self.pp, '/reaction_titles/'+r['id']), '', key, context,
                           content_ref=self.ref(self.bp, self.reaction_paths[r['id']]+'/text'), guard_ref=rr)
            join = self.node('reaction-merge/'+suffix, 'reaction_merge', chapter, self.ref(self.pp, '/labels/reaction_merge'), '', key, context)
            self.edge(tail, rn, 'reaction', rr, 'available')
            self.edge(tail, join, 'reaction_skip', rr, 'not_applies', True)
            self.edge(rn, join, 'reaction')
            tail = join
        for d in self.session.decisions.get(key, []):
            if d['id'] == skip_decision: continue
            dn = self.node('decision/'+d['id'], 'decision', chapter, self.ref(self.pp, '/decision_titles/'+d['id']), '', key, context,
                           definition_ref=self.ref(self.bp, self.decision_paths[d['id']]), question_ref=self.ref(self.bp,self.decision_paths[d['id']]+'/prompt'), mode='choice_or_single_option_auto')
            self.edge(tail, dn)
            join = self.node('merge/'+d['id'], 'merge', chapter, self.ref(self.pp, '/labels/merge'), '', key, context,
                             declared_rejoin_ref=self.ref(self.bp, self.decision_paths[d['id']]+'/rejoin_before'))
            for o in d['options']:
                op = self.option_paths[o['id']]
                on = self.node('option/'+o['id'], 'option', chapter, self.ref(self.bp, op+'/label'), '', key, context,
                               content_ref=self.ref(self.bp, op+'/body'), guard_ref=self.ref(self.bp, op), effects_ref=self.ref(self.bp, op+'/effects'))
                self.edge(dn, on, 'choice', self.ref(self.bp, op), 'available')
                self.edge(on, join, 'merge')
            tail = join
        end = self.node(self.uid(key, context, 'outcome'), 'outcome', chapter, self.ref(self.pp, '/labels/result'), number+' · ', key, context,
                        content_ref=self.ref(self.up, base+'/outcome'), completes_beats=list(u['completes_beats']))
        self.edge(tail, end)
        return main, end

    def _parallel(self, group):
        key = group['entry']; cid = key.split('/')[0]
        binding = next(b for b in self.session.plan['parallel_orders'] if b['group_id']==group['id'])
        d = next(d for d in self.session.plan['decisions'] if d['id']==binding['decision_id'])
        # The entry result is per option, preventing cross-wiring between orders.
        start = self.node(self.uid(key), 'unit', cid, self.heading(key), self.unit_numbers[key]+' · ', key,
                          content_ref=self.ref(self.up, self.unit_paths[key]+'/main_content'), candidate_status='bound')
        dn = self.node('decision/'+d['id'], 'decision', cid, self.ref(self.pp, '/decision_titles/'+d['id']), '', key,
                       definition_ref=self.ref(self.bp, self.decision_paths[d['id']]), question_ref=self.ref(self.bp,self.decision_paths[d['id']]+'/prompt'), mode='choice_or_single_option_auto')
        self.edge(start, dn)
        join = self.node('merge/'+d['id'], 'parallel_merge', cid, self.ref(self.pp, '/labels/parallel_merge'), '', key,
                         declared_rejoin_ref=self.ref(self.bp, self.decision_paths[d['id']]+'/rejoin_before'), all_blocks_required=True)
        for o in d['options']:
            context = o['id']; op = self.option_paths[context]
            on = self.node('option/'+context, 'option', cid, self.ref(self.bp, op+'/label'), '', key, context,
                           content_ref=self.ref(self.bp, op+'/body'), guard_ref=self.ref(self.bp, op), effects_ref=self.ref(self.bp, op+'/effects'))
            self.edge(dn, on, 'choice', self.ref(self.bp, op), 'available')
            end = self.node(self.uid(key, context, 'outcome'), 'outcome', cid, self.ref(self.pp, '/labels/result'), self.unit_numbers[key]+' · ', key, context,
                            content_ref=self.ref(self.up, self.unit_paths[key]+'/outcome'), completes_beats=list(self.session.units[key]['completes_beats']))
            self.edge(on, end)
            for block_index in binding['orders'][context]:
                for unit_id in group['blocks'][block_index]:
                    first, last = self._unit(unit_id, context)
                    self.edge(end, first); end = last
            self.edge(end, join, 'merge')
        return start, join

    def _build(self):
        overview = []
        previous = None
        for i, (chapter, row) in enumerate(zip(self.chapters['chapters'], self.session.outline['chapters'])):
            cid = chapter['id']
            cn = self.node('chapter/'+cid, 'chapter', cid, self.ref(self.cp, f'/chapters/{i}/title'), f'제{chapter["number"]}장 · ')
            if overview: self.edge(overview[-1], cn, 'overview')
            overview.append(cn)
            self.tree.append({'chapter_id': cid, 'heading_ref': self.ref(self.cp, f'/chapters/{i}/title'), 'number': chapter['number'],
                              'children': [{'unit_id': u['id'], 'number': self.unit_numbers[u['id']], 'heading_ref': self.heading(u['id']),
                                            'decision_ids': [d['id'] for d in self.session.decisions.get(u['id'],[])],
                                            'candidate_deferred': u['branch']['mode']=='candidate' and u['id'] not in self.session.decisions}
                                           for u in row['units']]})
            before = len(self.nodes)
            group_entries = {g['entry']: g for g in row['parallel_groups']}
            hidden = {key for g in row['parallel_groups'] for block in g['blocks'] for key in block}
            local_last, local_entry = None, None
            for u in row['units']:
                if u['id'] in hidden: continue
                start, last = self._parallel(group_entries[u['id']]) if u['id'] in group_entries else self._unit(u['id'])
                if local_entry is None: local_entry = start
                if local_last: self.edge(local_last, start)
                local_last = last
            if previous: self.edge(previous, local_entry)
            previous = local_last
            self.charts.append({'id': cid, 'entry': local_entry, 'exit': local_last, 'node_ids': [n['id'] for n in self.nodes[before:]]})
        return {'version': 1, 'flow_revision':self.plan['revision'], 'status': 'draft', 'visibility': 'author_only', 'origin': 'authored', 'metadata': self.plan['metadata'],
                'entry': self.charts[0]['entry'], 'exit': self.charts[-1]['exit'], 'overview': overview,
                'tree': self.tree, 'charts': self.charts, 'nodes': self.nodes, 'edges': self.edges,
                'references': list(self.docs), 'sequence_policy': 'conditional_DAG_not_all_choices_on_one_route'}

    def _context(self, unit_id, selected):
        for choice, group in self.variants.items():
            if choice in selected and unit_id in {group['entry'], *(k for b in group['blocks'] for k in b)}: return choice
        return None

    def trace(self, packet):
        selected = {h['id'] for h in packet['history'] if h['kind'] in ('choice','automatic')}
        seq = []
        reactions = {key: [r['id'] for r in self.session.plan['reactions'] if r['unit_id']==key] for key in self.session.units}
        present = {h['id'] for h in packet['history'] if h['kind']=='reaction'}
        for h in packet['history']:
            key = h['unit_id']; context = self._context(key, selected)
            if h['kind']=='main':
                seq.append(self.uid(key, None if key in {g['entry'] for g in self.session.groups.values()} else context))
                for rid in reactions[key]:
                    suffix = rid+('@'+context if context else '')
                    if rid in present: seq.append('reaction/'+suffix)
                    seq.append('reaction-merge/'+suffix)
            elif h['kind'] in ('choice','automatic'):
                seq.extend(['decision/'+h['decision_id'], 'option/'+h['id']])
                if h['id'] not in self.variants: seq.append('merge/'+h['decision_id'])
            elif h['kind']=='outcome':
                seq.append(self.uid(key, context, 'outcome'))
                if context and key==self.variants[context]['blocks'][self.session.orders[next(d for d,b in self.session.orders.items() if b['group_id']==self.variants[context]['id'])]['orders'][context][-1]][-1]:
                    seq.append('merge/'+next(d for d,b in self.session.orders.items() if b['group_id']==self.variants[context]['id']))
        return seq

    def _editions(self):
        result = []
        for edition in self.plan['linear_editions']:
            p = self.session.replay(edition['manual_route'])
            if p['status'] != 'complete': raise ValueError('linear publication route must finish every main chapter')
            rows = []
            for i, h in enumerate(p['history'], 1):
                key = h['unit_id']; kind = h['kind']
                if kind=='main':
                    rule = self.session.plan['unit_rules'].get(key)
                    ref = self.rule_ref(key,'content_override') if rule and rule['content_override'] is not None else self.ref(self.up,self.unit_paths[key]+'/main_content')
                elif kind=='outcome': ref = self.ref(self.up,self.unit_paths[key]+'/outcome')
                elif kind=='reaction': ref = self.ref(self.bp,self.reaction_paths[h['id']]+'/text')
                else: ref = self.ref(self.bp,self.option_paths[h['id']]+'/body')
                rows.append({'position':i, 'kind':kind, 'unit_id':key, 'heading_ref':self.heading(key), 'content_ref':ref,
                             'choice_or_reaction_id':h.get('id'), 'page':None, 'prose_status':'outline'})
            result.append({'id':edition['id'], 'status':'proposed', 'note':edition['note'], 'manual_route':list(edition['manual_route']),
                           'runtime_fingerprint':p['fingerprint'], 'publication_approved':False, 'rows':rows,
                           'main_unit_order':p['visited_units'], 'completed_beats':p['completed_beats']})
        return {'version':1, 'visibility':'author_only', 'status':'draft', 'editions':result}

    def validate(self):
        ids = [n['id'] for n in self.nodes]
        if len(ids)!=len(set(ids)): raise ValueError('duplicate flow node')
        nodes = {n['id']:n for n in self.nodes}
        for n in self.nodes:
            if self.resolve(n['label_ref']) != n['label_rich_text']: raise ValueError('flow heading snapshot differs from source')
            for key, ref in n.items():
                if key.endswith('_ref') and ref is not None: self.resolve(ref)
        forward = {key:[] for key in ids}
        for e in self.edges:
            if e['from'] not in nodes or e['to'] not in nodes: raise ValueError('dangling flow edge')
            if e['guard_ref']: self.resolve(e['guard_ref'])
            forward[e['from']].append(e['to'])
        done, active = set(), set()
        def visit(key):
            if key in active: raise ValueError('flow graph contains a misleading cycle')
            if key in done: return
            active.add(key)
            for target in forward[key]: visit(target)
            active.remove(key); done.add(key)
        for key in ids: visit(key)
        expected = set(self.session.units)
        if {u['unit_id'] for c in self.tree for u in c['children']} != expected: raise ValueError('tree omitted a main subsection')
        pairs = {(e['from'],e['to']) for e in self.edges}
        stack, count, used = [[]], 0, set()
        influence = {}
        def state_keys(value):
            if isinstance(value, dict):
                return ({value['state']} if 'state' in value else set()) | set().union(*(state_keys(v) for v in value.values()))
            if isinstance(value, list): return set().union(*(state_keys(v) for v in value))
            return set()
        while stack:
            route = stack.pop(); p = self.session.replay(route)
            if p['status'] != 'complete':
                stack.extend([*route,o['id']] for o in p['available_options']); continue
            count += 1
            if count+len(stack)>self.session.plan['limits']['max_paths']: raise ValueError('flow path-check limit exceeded')
            seq = self.trace(p)
            if seq[0]!=self.graph['entry'] or seq[-1]!=self.graph['exit'] or any(pair not in pairs for pair in zip(seq,seq[1:])):
                raise ValueError('flow diagram differs from actual runtime path')
            used.update(seq)
            options = [h for h in p['history'] if h['kind'] in ('choice','automatic')]
            for r in self.session.plan['reactions']:
                target = 'reaction/'+r['id']
                if target not in seq: continue
                reads = state_keys(r['when'])
                if r['participants']: reads.add(self.session.contract['members_state'])
                reads.update(self.session.contract['equipment_states'][person['character_id']] for person in r['participants'] if person['equipment_id'] is not None)
                for h in options:
                    source = 'option/'+h['id']
                    effects = self.resolve(self.ref(self.bp,self.option_paths[h['id']]+'/effects'))
                    actors = {person['character_id'] for person in r['participants']}
                    touched = {e['state'] for e in effects if e['state']!=self.session.contract['members_state'] or e['op']=='set' or e['value'] in actors}
                    if source in seq and seq.index(source)<seq.index(target) and touched&reads:
                        influence.setdefault((source,target), {'from':source,'to':target,'kind':'influence','guard_ref':self.ref(self.bp,self.reaction_paths[r['id']]),
                                                              'negated':False,'label_ref':None,'witness_route':list(route)})
        runtime_nodes = {n['id'] for n in self.nodes if n['kind']!='chapter'}
        if used != runtime_nodes: raise ValueError('flow includes an unreachable or missing runtime node')
        for edge in influence.values():
            if (edge['from'],edge['to']) not in pairs: self.edges.append(edge)
        return {'chapters':len(self.tree), 'subsections':len(expected), 'decisions':len(self.session.plan['decisions']),
                'options':len(self.option_paths), 'runtime_paths_checked':count, 'nodes':len(self.nodes), 'edges':len(self.edges),
                'influence_links':len(influence), 'acyclic':True, 'publication_approved':False, 'visibility':'author_only'}

    def caption(self, node):
        caption=node['prefix']+self.session.display(node['label_rich_text'])
        if node.get('question_ref'):caption+='\n질문 · '+self.session.display(self.resolve(node['question_ref']))
        return caption

    def mermaid(self, keys):
        chosen = set(keys); nodes = {n['id']:n for n in self.nodes}
        safe = lambda key:'n'+hashlib.sha256(key.encode()).hexdigest()[:16]
        lines = ['flowchart TB']
        for key in keys:
            n = nodes[key]; label = html.escape(self.caption(n), quote=True).replace('\n',' ')
            shape = '{"'+label+'"}' if n['kind']=='decision' else '["'+label+'"]'
            lines.append('  '+safe(key)+shape)
        for e in self.edges:
            if e['from'] not in chosen or e['to'] not in chosen: continue
            arrow = '-.->' if e['kind'].startswith('reaction') or e['kind']=='influence' else '-->'
            label = '|'+html.escape(self.session.display(self.resolve(e['label_ref'])))+'|' if e['label_ref'] else ''
            lines.append('  '+safe(e['from'])+' '+arrow+label+' '+safe(e['to']))
        return '\n'.join(lines)

    def markdown(self):
        lines = ['# 전편 소제목 트리와 흐름도', '', '작가 전용 · 전편 스포일러 · 자동 생성 · 아직 출판 승인 전입니다.', '',
                 '실선은 읽기·선택·합류, 점선은 조건부 반응입니다. 선택 가능 조건은 원래 분기 JSON을 따릅니다.', '',
                 '## 장 전체 흐름', '', '```mermaid', self.mermaid(self.graph['overview']), '```', '', '## 소제목 트리', '', '```text']
        for c in self.tree:
            lines.append(f'제{c["number"]}장 · '+self.session.display(self.resolve(c['heading_ref'])))
            for u in c['children']:
                lines.append('  ├─ '+u['number']+' · '+self.session.display(self.resolve(u['heading_ref']))+(' [분기 후보·미구현]' if u['candidate_deferred'] else ''))
                for did in u['decision_ids']:
                    lines.append('  │   ├─ 결정: '+self.session.display(self.plan['decision_titles'][did]))
                    decision=next(d for d in self.session.plan['decisions'] if d['id']==did)
                    lines.append('  │   │   질문: '+self.session.display(decision['prompt']))
                    for option in next(d for d in self.session.plan['decisions'] if d['id']==did)['options']:
                        lines.append('  │   │   ├─ '+self.session.display(option['label']))
                    lines.append('  │   │   └─ '+('두 탐색 모두 수행한 뒤 합류' if did in self.session.orders else '다음 본줄기 전 합류'))
        lines.extend(['```', '', '트리는 소속이고 실행 순서가 아닙니다. 9장의 두 탐색은 어느 쪽이 먼저여도 둘 다 필수입니다.', ''])
        influence_nodes = list(dict.fromkeys(key for e in self.edges if e['kind']=='influence' for key in (e['from'],e['to'])))
        lines.extend(['## 선택과 후속 반응의 연결', '', '공유 상태와 실제 경로에서 함께 관찰된 연결입니다. 조건이 맞아야 반응이 나오며 유일한 원인의 증명은 아닙니다.', '',
                      '```mermaid',self.mermaid(influence_nodes),'```',''])
        for c, chart in zip(self.tree,self.charts):
            lines.extend([f'## 제{c["number"]}장 · '+self.session.display(self.resolve(c['heading_ref'])), '',
                          '```mermaid',self.mermaid(chart['node_ids']),'```',''])
        lines.extend(['## 선형 출판 순서표', '', '전체 선택지를 한 이야기로 합치지 않습니다. 아래는 지정한 예시 경로만의 실제 읽기 순서이며 페이지는 미정입니다.', ''])
        for e in self.editions['editions']:
            lines.extend(['### '+e['id'], '', e['note'], '', '수동 선택: '+' → '.join(e['manual_route']), '', '| 순서 | 소제목 | 소단락 ID | 페이지 |', '| --- | --- | --- | --- |'])
            for i,key in enumerate(e['main_unit_order'],1): lines.append(f'| {i} | '+self.unit_numbers[key]+' · '+self.session.display(self.resolve(self.heading(key))).replace('|','\\|')+' | `'+key+'` | 미정 |')
            lines.append('')
        lines.extend(['## 출판 전 확인', '', *['- '+s for s in self.plan['notes']], ''])
        return '\n'.join(lines)

    def svg(self, keys):
        chosen = set(keys); nodes = {n['id']:n for n in self.nodes if n['id'] in chosen}
        edges = [e for e in self.edges if e['from'] in chosen and e['to'] in chosen]
        indegree = Counter(e['to'] for e in edges); depth = {key:0 for key in keys}; pending = [key for key in keys if not indegree[key]]
        while pending:
            key = pending.pop(0)
            for e in edges:
                if e['from'] != key: continue
                depth[e['to']] = max(depth[e['to']],depth[key]+1); indegree[e['to']] -= 1
                if indegree[e['to']] == 0: pending.append(e['to'])
        levels = {}
        for key in keys: levels.setdefault(depth[key],[]).append(key)
        text_rows={key:[row for line in self.caption(nodes[key]).splitlines() for row in (textwrap.wrap(line,17) or [''])] for key in keys}
        box_heights={key:max(80,28+len(text_rows[key])*19) for key in keys}
        width = max(480,max(len(row) for row in levels.values())*312)
        top={};cursor=20
        for level,row in sorted(levels.items()):
            top[level]=cursor;cursor+=max(box_heights[key] for key in row)+48
        height=cursor
        positions = {key:(width/2+(j-(len(row)-1)/2)*312,top[level]) for level,row in levels.items() for j,key in enumerate(row)}
        esc = html.escape
        marker = 'arrow-'+hashlib.sha256('|'.join(keys).encode()).hexdigest()[:12]
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" role="img" aria-label="소제목과 분기 흐름도" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
               f'<defs><marker id="{marker}" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#607269"/></marker></defs>']
        for e in edges:
            x,y = positions[e['from']]; xx,yy = positions[e['to']]
            dashed = ' stroke-dasharray="5 4"' if e['kind'].startswith('reaction') or e['kind']=='influence' else ''
            bottom=y+box_heights[e['from']]
            out.append(f'<path d="M{x} {bottom} C{x} {bottom+24} {xx} {yy-24} {xx} {yy}" fill="none" stroke="#607269"{dashed} marker-end="url(#{marker})"/>')
        colors = {'decision':'#ffebbb','option':'#e5f0fd','merge':'#e0ebdf','parallel_merge':'#e0ebdf','reaction':'#eee6f4','reaction_merge':'#eee6f4','outcome':'#f2f1e9'}
        for key in keys:
            n = nodes[key]; x,y = positions[key]; caption = self.caption(n)
            fill = colors.get(n['kind'],'#fff')
            out.append(f'<g><title>{esc(caption)}</title><rect x="{x-140}" y="{y}" width="280" height="{box_heights[key]}" rx="8" fill="{fill}" stroke="#607269"/>')
            out.append(f'<text x="{x}" y="{y+25}" text-anchor="middle" fill="#25372e" font-size="15">')
            out.extend(f'<tspan x="{x}" dy="{0 if j==0 else 19}">{esc(line)}</tspan>' for j,line in enumerate(text_rows[key]))
            out.append('</text></g>')
        return ''.join(out)+'</svg>'

    def document(self):
        from writing import html_doc
        esc = html.escape
        body = '<p class="notice">작가 전용 · 전편 스포일러 · 출판 준비용 도식. 새 분기나 출판 승인이 아니라 현재 JSON의 연결입니다. 원문·장편 본문은 별도이며 페이지는 미정입니다.</p>'
        body += '<p>15장 · 88소단락 · 6결정 · 14선택지. 그래프는 조건에 따른 갈림과 합류, 트리는 소속을 나타냅니다. 넓은 그림은 좌우로 움직여 볼 수 있습니다.</p><nav><ul>'
        body += ''.join('<li><a href="#'+c['chapter_id']+'">제'+str(c['number'])+'장 · '+esc(self.session.display(self.resolve(c['heading_ref'])))+'</a></li>' for c in self.tree)+'</ul></nav>'
        body += '<h2>장 전체 흐름</h2><div class="flow-diagram">'+self.svg(self.graph['overview'])+'</div>'
        influence_nodes = list(dict.fromkeys(key for e in self.edges if e['kind']=='influence' for key in (e['from'],e['to'])))
        body += '<h2>선택과 후속 반응의 연결</h2><p>공유 상태와 실제 경로에서 관찰된 연결입니다. 조건이 맞을 때만 반응이 나타나며 유일한 원인의 증명은 아닙니다.</p><div class="flow-diagram">'+self.svg(influence_nodes)+'</div>'
        for c,chart in zip(self.tree,self.charts):
            body += '<h2 id="'+c['chapter_id']+'">제'+str(c['number'])+'장 · '+esc(self.session.display(self.resolve(c['heading_ref'])))+'</h2><ol>'
            for u in c['children']:
                body += '<li>'+esc(u['number']+' · '+self.session.display(self.resolve(u['heading_ref'])))+(' <small>분기 후보·미구현</small>' if u['candidate_deferred'] else '')+'</li>'
            body += '</ol><div class="flow-diagram">'+self.svg(chart['node_ids'])+'</div>'
        body += '<h2>종이책 경로의 편집 순서</h2><p>아래는 예시 경로입니다. 출판 경로·본문·페이지를 승인한 것이 아닙니다.</p>'
        for e in self.editions['editions']:
            body += '<h3>'+esc(e['id'])+'</h3><p>'+esc(e['note'])+'</p><ol>'
            body += ''.join('<li>'+esc(self.unit_numbers[key]+' · '+self.session.display(self.resolve(self.heading(key))))+'</li>' for key in e['main_unit_order'])+'</ol>'
        body += '<h2>범례와 조건</h2><p>푸른 상자는 선택 경로, 노란 상자는 결정, 녹색은 합류, 회색은 필수 결과, 보라는 조건부 반응입니다. 점선은 조건이 맞을 때의 문단이며 모든 반응을 함께 읽는 뜻이 아닙니다.</p><ul>'
        body += ''.join('<li>'+esc(s)+'</li>' for s in self.plan['notes'])+'</ul>'
        return html_doc('출판 구성 · 소제목 트리와 흐름도',body).replace('</style>','.flow-diagram{max-width:100%;overflow-x:auto;border:1px solid #b9c8bd;padding:8px;background:#fafafa}.flow-diagram svg{display:block;font-family:inherit}@media print{.flow-diagram{overflow:visible}.flow-diagram svg{max-width:100%;height:auto}}</style>')


def export(check=False, output=None, flow=None):
    flow = flow or PublicationFlow(); output = Path(output or OUTPUT)
    artifacts = {'flow.graph.json':json.dumps(flow.graph,ensure_ascii=False,indent=2)+'\n',
                 'linear-editions.json':json.dumps(flow.editions,ensure_ascii=False,indent=2)+'\n',
                 'flow.md':flow.markdown(), 'flow.html':flow.document(), 'coverage.json':json.dumps(flow.report,ensure_ascii=False,indent=2)+'\n'}
    inputs = [PLAN,SCHEMA,TEMPLATE,CHAPTERS,SUBSECTIONS,BRANCHES,ROOT/'tools/publication_flow.py',ROOT/'tools/branch_system.py',
              ROOT/'tools/chapter_subsections.py',ROOT/'tools/text_refs.py',ROOT/'tools/story_continuity.py',
              ROOT/'characters/registry.json',ROOT/'reference/names.json',ROOT/'reference/terms.json',
              *(ROOT/f'reference/{key}.json' for key in flow.session.references)]
    manifest = {'version':1,'source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
                'artifacts':{name:hashlib.sha256(body.encode()).hexdigest() for name,body in artifacts.items()}}
    path = output/'manifest.json'
    if path.exists():
        previous = read(path)
        for name,digest in previous['artifacts'].items():
            if name not in artifacts or not (output/name).is_file() or hashlib.sha256((output/name).read_bytes()).hexdigest()!=digest:
                raise ValueError('publication output was manually edited; preserve before regeneration: '+name)
    elif any((output/name).exists() for name in artifacts): raise ValueError('publication output exists without manifest')
    if check:
        if not path.exists() or read(path)!=manifest: raise ValueError('publication flow is stale; run publication_flow.py export')
    else:
        output.mkdir(parents=True,exist_ok=True)
        for name,body in artifacts.items(): (output/name).write_text(body,encoding='utf-8')
        path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return {**flow.report,'checked':check}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['validate','export'])
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    print(json.dumps(export(args.check) if args.action=='export' else PublicationFlow().report,ensure_ascii=False,indent=2))
