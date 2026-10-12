"""Structured, author-only subsection branches; no game or public-reader runtime."""
import argparse
import copy
import hashlib
import html
import json

import jsonschema
from referencing import Registry, Resource

from materials import ROOT, read, load_materials
from characters import load_characters
from reference import COMMON, load_references, validate_claim
from text_refs import indexes, literals, validate_text, reject_fixed_names, render
from story_continuity import matches, apply, fingerprint
from chapter_subsections import PLAN as OUTLINE, validate_subsections

PLAN = ROOT/'writing/branches/series.json'
SCHEMA = ROOT/'writing/branches.schema.json'
TEMPLATE = ROOT/'writing/templates/branch-decision.template.json'


class BranchSession:
    def __init__(self, plan=None, outline=None, profiles=None, references=None):
        self.plan, self.outline = copy.deepcopy(plan or read(PLAN)), copy.deepcopy(outline or read(OUTLINE))
        catalog, manifest = load_materials()
        self.profiles = profiles or load_characters(catalog)
        self.references = references or load_references(catalog)
        self.data, self.raw = indexes(self.profiles, self.references, catalog), literals(catalog)
        validate_subsections(self.outline, profiles=self.profiles, references=self.references)
        self.units = {u['id']: u for c in self.outline['chapters'] for u in c['units']}
        self.groups = {g['id']: g for c in self.outline['chapters'] for g in c['parallel_groups']}
        self.states = self.plan['state_definitions']
        self.contract = self.plan['party_contract']
        self._validate(catalog)
        self.decisions = {}
        for d in self.plan['decisions']:
            self.decisions.setdefault(d['unit_id'], []).append(d)
        self.orders = {o['decision_id']: o for o in self.plan['parallel_orders']}
        self.fingerprint = fingerprint({'plan': self.plan, 'outline': self.outline, 'profiles': self.profiles,
                                        'references': self.references, 'terms': self.data['terms'], 'materials': manifest,
                                        'engine_inputs': {p: hashlib.sha256(ROOT.joinpath(p).read_bytes()).hexdigest() for p in
                                            ('tools/branch_system.py', 'tools/story_continuity.py', 'tools/text_refs.py',
                                             'writing/branches.schema.json', 'writing/templates/branch-decision.template.json')}})

    def _text(self, value):
        validate_text(value, self.data, self.raw)
        reject_fixed_names(value, self.data)
        if not self.display(value).strip():
            raise ValueError('branch text must contain actual narrative')

    def display(self, value):
        return render(value, self.data, self.raw, self.profiles, author=True)

    def _value(self, key, value, member=False):
        if key not in self.states:
            raise ValueError('unknown branch state: '+key)
        d = self.states[key]
        kind = 'string' if member else d['type']
        valid = {'boolean': type(value) is bool, 'integer': type(value) is int,
                 'string': type(value) is str, 'string_set': type(value) is list and all(type(v) is str for v in value)}[kind]
        if not valid:
            raise ValueError('wrong state value type: '+key)
        if kind == 'integer' and not d['minimum'] <= value <= d['maximum']:
            raise ValueError('state value outside bounds: '+key)
        if kind == 'string_set' and (len(value) != len(set(value)) or not d['minimum'] <= len(value) <= d['maximum']):
            raise ValueError('invalid or out-of-bounds state set: '+key)
        values = value if kind == 'string_set' else [value]
        if d['values'] is not None and any(v not in d['values'] for v in values):
            raise ValueError('state value outside declared domain: '+key)
        if d['reference_catalog']:
            if kind not in ('string', 'string_set'):
                raise ValueError('reference state must contain IDs: '+key)
            if (member or kind == 'string_set') and '' in values:
                raise ValueError('empty reference ID in state set: '+key)
            if any(v not in self.data[d['reference_catalog']] for v in values if v != ''):
                raise ValueError('unknown reference-valued state: '+key)

    def _predicate(self, predicate):
        if type(predicate) is bool:
            return
        if 'all' in predicate or 'any' in predicate:
            for p in predicate.get('all', predicate.get('any')):
                self._predicate(p)
        elif 'not' in predicate:
            self._predicate(predicate['not'])
        else:
            key, op = predicate['state'], predicate['op']
            if key not in self.states:
                raise ValueError('unknown predicate state: '+key)
            kind = self.states[key]['type']
            if op in ('contains', 'not_contains'):
                if kind != 'string_set': raise ValueError('membership predicate needs a set')
                self._value(key, predicate['value'], member=True)
            elif op in ('gte', 'lte'):
                if kind != 'integer' or type(predicate['value']) is not int: raise ValueError('comparison needs an integer')
            else:
                self._value(key, predicate['value'])

    def _effects(self, effects, authority):
        for e in effects:
            key, op, value = e['state'], e['op'], e['value']
            if key not in self.states or self.states[key]['authority'] != authority:
                raise ValueError('effect writes an unknown or protected state: '+key)
            kind = self.states[key]['type']
            if op == 'set': self._value(key, value)
            elif op in ('add', 'remove'):
                if kind != 'string_set': raise ValueError('set effect needs a set')
                self._value(key, value, member=True)
            elif kind != 'integer' or type(value) is not int:
                raise ValueError('increment needs an integer')

    def _participants_valid(self, participants):
        for p in participants:
            if p['character_id'] not in self.data['characters']:
                raise ValueError('unknown participant')
            if p['equipment_id'] is not None and (p['equipment_id'] not in self.data['equipment'] or p['character_id'] not in self.contract['equipment_states']):
                raise ValueError('participant equipment has no declared holder')

    def _participants_present(self, participants, state):
        for p in participants:
            key = p['character_id']
            if key not in state[self.contract['members_state']]: return False
            if p['equipment_id'] is not None and state[self.contract['equipment_states'][key]] != p['equipment_id']: return False
        return True

    def _invariants(self, state):
        if set(state) != set(self.states): raise ValueError('state packet has undeclared fields')
        for key, value in state.items(): self._value(key, value)
        c = self.contract
        members, optional = set(state[c['members_state']]), state[c['optional_state']]
        expected = set(c['core_members']) | ({optional} if optional else set())
        if members != expected or optional and optional not in c['optional_candidates']:
            raise ValueError('current party and optional slot disagree')
        inventory = state[c['inventory_state']]
        for holder, key in c['equipment_states'].items():
            weapon = state[key]
            if weapon and (holder not in members or weapon not in inventory):
                raise ValueError('equipped item needs an active holder and owned inventory')

    def _commit(self, effects, state):
        candidate = copy.deepcopy(state)
        apply(effects, candidate)
        self._invariants(candidate)
        return candidate

    def _validate(self, catalog):
        schemas = [read(SCHEMA), read(COMMON), read(ROOT/'authoring/story.schema.json')]
        registry = Registry().with_resources((s['$id'], Resource.from_contents(s)) for s in schemas)
        registry = registry.with_resource('https://lore.local/novel/authoring/story.schema.json', Resource.from_contents(schemas[2]))
        validator = jsonschema.Draft202012Validator(schemas[0], registry=registry)
        validator.validate(self.plan)
        if self.plan['subsection_revision'] != self.outline['revision']:
            raise ValueError('branch system needs review against current subsection revision')
        def claim(row):
            validate_claim({'field': 'branch_system', 'value': True, 'origin': row['origin'], 'status': 'proposed', 'evidence': [], 'metadata': row['metadata']}, catalog)
        claim(self.plan)
        c = self.contract
        for key in (c['members_state'], c['optional_state'], c['inventory_state']):
            if key not in self.states: raise ValueError('party contract uses unknown state')
        if self.states[c['members_state']]['type'] != 'string_set' or self.states[c['optional_state']]['type'] != 'string' or self.states[c['inventory_state']]['type'] != 'string_set':
            raise ValueError('party contract has incompatible state types')
        if any(self.states[key]['reference_catalog'] != category for key, category in
               [(c['members_state'], 'characters'), (c['optional_state'], 'characters'), (c['inventory_state'], 'equipment')]):
            raise ValueError('party contract requires reference-valued states')
        if set(c['core_members']) & set(c['optional_candidates']) or any(k not in self.data['characters'] for k in [*c['core_members'], *c['optional_candidates']]):
            raise ValueError('invalid party reference contract')
        for holder, key in c['equipment_states'].items():
            if holder not in self.data['characters'] or key not in self.states or self.states[key]['holder'] != holder or self.states[key]['reference_catalog'] != 'equipment' or self.states[key]['type'] != 'string':
                raise ValueError('equipment holder contract differs from state definition')
        for key, d in self.states.items():
            claim(d); self._text(d['description']); self._value(key, d['initial'])
            if d['minimum'] > d['maximum']: raise ValueError('invalid state bounds')
            if d['authority'] == 'main' and d['initial'] not in (False, '', 0, []):
                raise ValueError('main state cannot start with future knowledge or reward')
            if d['holder'] is not None and c['equipment_states'].get(d['holder']) != key:
                raise ValueError('equipment state missing from holder contract')
        self._invariants({k: copy.deepcopy(d['initial']) for k, d in self.states.items()})
        bindings = {o['decision_id']: o for o in self.plan['parallel_orders']}
        if len(bindings) != len(self.plan['parallel_orders']) or len(bindings) != len(self.groups) or {o['group_id'] for o in bindings.values()} != set(self.groups):
            raise ValueError('parallel order must bind every independent group once')
        all_ids, decision_ids = set(), set()
        for d in self.plan['decisions']:
            claim(d); self._text(d['prompt'])
            if d['id'] in decision_ids: raise ValueError('duplicate decision')
            decision_ids.add(d['id'])
            if d['unit_id'] not in self.units: raise ValueError('decision has unknown subsection')
            u = self.units[d['unit_id']]
            if not set(d['source_section_refs']) <= set(u['source_section_refs']): raise ValueError('decision borrows another source section')
            if d['id'] in bindings:
                b = bindings[d['id']]
                g = self.groups[b['group_id']]
                if d['unit_id'] != g['entry'] or d['rejoin_before'] != g['exit']: raise ValueError('parallel decision has invalid entry or rejoin')
                if set(b['orders']) != {o['id'] for o in d['options']} or any(sorted(v) != list(range(len(g['blocks']))) for v in b['orders'].values()):
                    raise ValueError('parallel option must traverse every block exactly once')
            elif u['branch']['mode'] != 'candidate' or d['rejoin_before'] != u['branch']['rejoin_before']:
                raise ValueError('branch must rejoin next main subsection')
            for o in d['options']:
                claim(o); self._text(o['label']); self._text(o['body']); self._predicate(o['when']); self._participants_valid(o['participants']); self._effects(o['effects'], 'branch')
                for e in o['effects']: claim(e)
                if o['id'] in all_ids: raise ValueError('duplicate branch option')
                all_ids.add(o['id'])
            if len({fingerprint({'body': o['body'], 'effects': o['effects']}) for o in d['options']}) != len(d['options']):
                raise ValueError('meaningless duplicate branch outcomes')
        if not set(bindings) <= decision_ids: raise ValueError('parallel binding has unknown decision')
        for key, rule in self.plan['unit_rules'].items():
            claim(rule)
            if key not in self.units or not set(rule['source_section_refs']) <= set(self.units[key]['source_section_refs']): raise ValueError('unit rule has unknown or foreign source')
            self._predicate(rule['entry_when']); self._effects(rule['effects'], 'main')
            for e in rule['effects']: claim(e)
            if rule['content_override'] is not None: self._text(rule['content_override'])
            if rule.get('title_override') is not None: self._text(rule['title_override'])
        reaction_ids = set()
        for r in self.plan['reactions']:
            claim(r); self._text(r['text']); self._predicate(r['when']); self._participants_valid(r['participants'])
            if r['id'] in reaction_ids: raise ValueError('duplicate reaction')
            reaction_ids.add(r['id'])
            if r['unit_id'] not in self.units or not set(r['requires_units']) <= set(self.units) or r['unit_id'] in r['requires_units']:
                raise ValueError('reaction has invalid source dependency')
        example = read(TEMPLATE)
        if set(example) != {'version', 'purpose', 'decision'} or example['version'] != 1 or example['purpose'] != 'copy_decision_into_series_not_a_standalone_runtime': raise ValueError('invalid shared branch template')
        validator.evolve(schema=schemas[0]['properties']['decisions']['items']).validate(example['decision'])

    def replay(self, route):
        if type(route) is not list or len(route) > self.plan['limits']['max_manual_choices'] or any(type(x) is not str for x in route):
            raise ValueError('route must be bounded manual option IDs only')
        queue = list(self.units)
        state = {k: copy.deepcopy(d['initial']) for k, d in self.states.items()}
        visited, completed, history, automatic = [], set(), [], []
        cursor = 0
        def packet(decision=None, options=()):
            return {'visibility': 'author_only', 'prose': 'outline', 'status': 'waiting_choice' if decision else 'complete',
                    'fingerprint': self.fingerprint, 'route': list(route), 'state': copy.deepcopy(state), 'visited_units': list(visited),
                    'completed_beats': sorted(completed), 'history': copy.deepcopy(history), 'automatic_options': list(automatic),
                    'decision_id': decision['id'] if decision else None,
                    'available_options': [{'id': o['id'], 'label': self.display(o['label'])} for o in options]}
        for pos in range(len(queue)):
            key = queue[pos]
            u = self.units[key]
            if key in visited or not set(u['after']) <= set(visited): raise ValueError('main unit dependency or once-only rule violated')
            rule = self.plan['unit_rules'].get(key)
            if rule and not matches(rule['entry_when'], state): raise ValueError('main entry condition not satisfied: '+key)
            text = rule['content_override'] if rule and rule['content_override'] is not None else u['main_content']
            title = rule['title_override'] if rule and rule.get('title_override') is not None else u['title']
            history.append({'kind': 'main', 'unit_id': key, 'title': self.display(title), 'text': self.display(text)})
            if rule: state = self._commit(rule['effects'], state)
            for r in self.plan['reactions']:
                if r['unit_id'] == key and set(r['requires_units']) <= set(visited) and matches(r['when'], state) and self._participants_present(r['participants'], state):
                    history.append({'kind': 'reaction', 'unit_id': key, 'id': r['id'], 'text': self.display(r['text'])})
            for d in self.decisions.get(key, []):
                options = [o for o in d['options'] if matches(o['when'], state) and self._participants_present(o['participants'], state)]
                if not options: raise ValueError('branch dead end: '+d['id'])
                if len(options) == 1:
                    chosen = options[0]; automatic.append(chosen['id']); mode = 'automatic'
                elif cursor == len(route):
                    return packet(d, options)
                else:
                    chosen = next((o for o in options if o['id'] == route[cursor]), None)
                    if chosen is None: raise ValueError('unavailable, out-of-order or future option: '+route[cursor])
                    cursor += 1; mode = 'choice'
                state = self._commit(chosen['effects'], state)
                history.append({'kind': mode, 'unit_id': key, 'decision_id': d['id'], 'id': chosen['id'], 'text': self.display(chosen['body'])})
                if d['id'] in self.orders:
                    order = self.orders[d['id']]; g = self.groups[order['group_id']]
                    end = queue.index(g['exit'])
                    block_units = [n for block in g['blocks'] for n in block]
                    if set(queue[pos+1:end]) != set(block_units): raise ValueError('parallel block would skip a main unit')
                    queue[pos+1:end] = [n for i in order['orders'][chosen['id']] for n in g['blocks'][i]]
            history.append({'kind': 'outcome', 'unit_id': key, 'text': self.display(u['outcome'])})
            completed.update(u['completes_beats']); visited.append(key)
        if cursor != len(route): raise ValueError('route continues beyond story ending')
        if set(visited) != set(self.units) or len(visited) != len(self.units): raise ValueError('main subsection omitted or repeated')
        required = {b for c in self.outline['chapters'] for b in c['exit_requires_beats']}
        if completed != required: raise ValueError('story ending omitted required beats')
        return packet()

    def choose(self, route, option_id):
        current = self.replay(route)
        if option_id not in {o['id'] for o in current['available_options']}: raise ValueError('unavailable choice')
        result = [*route, option_id]
        return result, self.replay(result)

    def save(self, route):
        self.replay(route)
        return {'version': 1, 'fingerprint': self.fingerprint, 'route': list(route)}

    def restore(self, saved):
        if type(saved) is not dict or set(saved) != {'version', 'fingerprint', 'route'} or type(saved['version']) is not int or saved['version'] != 1 or saved['fingerprint'] != self.fingerprint:
            raise ValueError('incompatible or state-injecting save')
        return self.replay(saved['route'])

    def validate_paths(self):
        stack, leaves, seen_options = [[]], [], set()
        while stack:
            route = stack.pop()
            p = self.replay(route)
            seen_options.update(h['id'] for h in p['history'] if h['kind'] in ('choice', 'automatic'))
            if p['status'] == 'complete':
                leaves.append(route)
                if len(leaves) > self.plan['limits']['max_paths']: raise ValueError('path validation limit exceeded; no complete proof')
            else:
                stack.extend([*route, o['id']] for o in p['available_options'])
            if len(stack) + len(leaves) > self.plan['limits']['max_paths']: raise ValueError('path validation limit exceeded; no complete proof')
        expected = {o['id'] for d in self.plan['decisions'] for o in d['options']}
        if seen_options != expected: raise ValueError('unreachable branch option')
        candidate_units = {u['id'] for u in self.units.values() if u['branch']['mode'] == 'candidate'}
        bound = {d['unit_id'] for d in self.plan['decisions']}
        return {'main_units': len(self.units), 'decisions': len(self.plan['decisions']), 'options': len(expected), 'complete_paths': len(leaves),
                'required_beats': sum(len(c['exit_requires_beats']) for c in self.outline['chapters']), 'all_declared_options_reachable': True,
                'deferred_candidate_units': sorted(candidate_units-bound), 'execution': 'implemented', 'prose': 'outline',
                'dialogue_coverage': 'partial', 'public_reader_updated': False}


def branch_document(session=None):
    from writing import html_doc
    session = session or BranchSession()
    report = session.validate_paths()
    esc = html.escape
    body = '<p class="notice">작가 전용 · 전편 스포일러 · JSON 분기 구조는 실행 가능하지만 본문은 주요 내용 초안입니다. 기존 독자용 첫 장은 교체하지 않았습니다.</p>'
    body += '<p>'+str(report['main_units'])+'소단락 · '+str(report['decisions'])+'결정 · '+str(report['options'])+'선택 경로 · 검사한 완주 경로 '+str(report['complete_paths'])+'개.</p>'
    for d in session.plan['decisions']:
        body += '<section><h2>'+esc(d['id'])+' · '+esc(d['unit_id'])+'</h2><p>'+esc(session.display(d['prompt']))+'</p>'
        for o in d['options']:
            body += '<h3>'+esc(session.display(o['label']))+'</h3><p>'+esc(session.display(o['body']))+'</p><details><summary>JSON 조건·상태 변화</summary><pre>'+esc(json.dumps({k: o[k] for k in ('id', 'when', 'participants', 'effects')}, ensure_ascii=False, indent=2))+'</pre></details>'
        body += '<p class="metadata">필수 합류: '+esc(d['rejoin_before'])+'</p></section>'
    body += '<h2>선택 이후 반응</h2>'+''.join('<p>'+esc(r['unit_id'])+' · '+esc(session.display(r['text']))+'</p>' for r in session.plan['reactions'])
    body += '<h2>아직 미구현인 후보</h2><p>'+esc(', '.join(report['deferred_candidate_units']))+'</p>'
    body += '<h2>지킬 조건</h2><ul>'+''.join('<li>'+esc(s)+'</li>' for s in session.plan['notes'])+'</ul>'
    return html_doc('소단락 분기 시스템 · 구조와 선택 결과', body).replace('</style>', 'pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:12px}</style>')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['validate', 'replay'])
    parser.add_argument('--route', nargs='*', default=[])
    parser.add_argument('--summary', action='store_true')
    args = parser.parse_args()
    session = BranchSession()
    result = session.validate_paths() if args.action == 'validate' else session.replay(args.route)
    if args.summary: result.pop('history', None)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__': main()
