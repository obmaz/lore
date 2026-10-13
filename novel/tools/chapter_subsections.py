"""Author-only subsection outlines; potential variations, not executable choices."""
import html

import jsonschema
from referencing import Registry, Resource

from materials import ROOT, read, load_materials
from characters import load_characters
from reference import COMMON, load_references, validate_claim
from text_refs import indexes, literals, validate_text, reject_fixed_names, render
from chapter_stories import STORIES, STAGES

PLAN = ROOT/'writing/storyboard/chapter-subsections.json'
SCHEMA = ROOT/'writing/chapter-subsections.schema.json'
TEMPLATE = ROOT/'writing/templates/chapter-subsections.template.json'


def validate_subsections(plan, chapters=None, macro=None, profiles=None, references=None):
    from writing import CHAPTERS
    chapters, macro = chapters or read(CHAPTERS), macro or read(STORIES)
    schemas = [read(SCHEMA), read(COMMON), read(ROOT/'authoring/story.schema.json')]
    registry = Registry().with_resources((s['$id'], Resource.from_contents(s)) for s in schemas)
    registry = registry.with_resource('https://lore.local/novel/authoring/story.schema.json', Resource.from_contents(schemas[2]))
    jsonschema.Draft202012Validator(schemas[0], registry=registry).validate(plan)
    if plan['macro_revision'] != macro['revision']:
        raise ValueError('subsections require review against current macro revision')
    central = {c['id']: c for c in chapters['chapters']}
    macro_rows = {c['chapter_id']: c for c in macro['chapters']}
    ids = [c['chapter_id'] for c in plan['chapters']]
    if len(ids) != len(set(ids)) or not set(ids) <= set(central):
        raise ValueError('duplicate or unknown subsection chapter')
    if plan['kind'] == 'series' and ids != list(central):
        raise ValueError('subsections must preserve all chapters in reading order')
    catalog = load_materials()[0]
    profiles, references = profiles or load_characters(catalog), references or load_references(catalog)
    data, raw = indexes(profiles, references, catalog), literals(catalog)
    validate_claim({'field': 'subsections', 'value': plan['notes'], 'origin': plan['origin'],
                    'status': 'proposed', 'evidence': [], 'metadata': plan['metadata']}, catalog)
    all_units = [u for c in plan['chapters'] for u in c['units']]
    unit_ids = [u['id'] for u in all_units]
    if len(unit_ids) != len(set(unit_ids)):
        raise ValueError('duplicate subsection id')
    following = {u['id']: all_units[i+1]['id'] if i+1 < len(all_units) else None
                 for i, u in enumerate(all_units)}
    for chapter in plan['chapters']:
        cid = chapter['chapter_id']
        parent, contract = macro_rows[cid], central[cid]
        index = list(central).index(cid)
        if chapter['inherit_continuity_from'] != f'storyboard/chapter-stories.json#/chapters/{index}':
            raise ValueError('subsection continuity must inherit its parent chapter')
        required = {b['id']: b for b in contract['required_beats']}
        if set(chapter['exit_requires_beats']) != set(required):
            raise ValueError('subsection exit omitted or borrowed required beat')
        nodes = {u['id']: u for u in chapter['units']}
        if any(not key.startswith(cid+'/') for key in nodes):
            raise ValueError('subsection id belongs to another chapter')
        completed = [b for u in nodes.values() for b in u['completes_beats']]
        if len(completed) != len(set(completed)) or set(completed) != set(required):
            raise ValueError('subsections must complete every required beat exactly once')
        sections = {s for u in nodes.values() for s in u['source_section_refs']}
        if sections != set(parent['source_section_refs']):
            raise ValueError('subsection source coverage differs from parent chapter')
        ancestors, visiting = {}, set()
        def predecessors(key):
            if key not in nodes:
                raise ValueError('unknown or cross-chapter subsection dependency')
            if key in visiting:
                raise ValueError('cyclic subsection dependency')
            if key not in ancestors:
                visiting.add(key)
                ancestors[key] = set(nodes[key]['after'])
                for prior in nodes[key]['after']:
                    ancestors[key].update(predecessors(prior))
                visiting.remove(key)
            return ancestors[key]
        owner = {b: u['id'] for u in nodes.values() for b in u['completes_beats']}
        for unit in nodes.values():
            prior = predecessors(unit['id'])
            if unit['reading_next'] != following[unit['id']]:
                raise ValueError('subsection reading link skips the next main unit')
            for beat in unit['completes_beats']:
                if any(owner[b] not in prior for b in required[beat]['after']):
                    raise ValueError('required beat completed before its prerequisite')
            branch = unit['branch']
            if branch['mode'] == 'candidate':
                if not branch['variation_scope'] or not branch['carry_keys'] or branch['rejoin_before'] != following[unit['id']] or branch['rejoin_before'] is None:
                    raise ValueError('branch candidate must describe variation, carry and next-unit rejoin')
            elif branch['variation_scope'] is not None or branch['rejoin_before'] is not None or branch['carry_keys']:
                raise ValueError('fixed subsection cannot pretend to have a branch')
            for value in [unit['title'], unit['entry'], unit['main_content'], unit['outcome'], *([branch['variation_scope']] if branch['variation_scope'] else [])]:
                validate_text(value, data, raw)
                reject_fixed_names(value, data)
            for value in unit.get('logic', {}).values():
                validate_text(value, data, raw)
                reject_fixed_names(value, data)
                if not value:
                    raise ValueError('subsection logic must describe a concrete goal and transition')
            validate_claim({'field': 'subsection', 'value': unit['main_content'], 'origin': unit['origin'],
                            'status': 'proposed', 'evidence': [], 'metadata': unit['metadata']}, catalog)
        groups = chapter['parallel_groups']
        expected = parent['parallel_beat_groups']
        if len(groups) != len(expected):
            raise ValueError('missing parallel subsection objectives')
        for group, beats in zip(groups, expected):
            flat = [key for block in group['blocks'] for key in block]
            if len(flat) != len(set(flat)) or not set([group['entry'], group['exit'], *flat]) <= set(nodes):
                raise ValueError('parallel group has invalid or repeated units')
            if group['entry'] in flat or group['exit'] in flat:
                raise ValueError('parallel entry and exit must be outside objective blocks')
            block_beats = [set(b for key in block for b in nodes[key]['completes_beats']) for block in group['blocks']]
            if len(block_beats) != len(beats) or any(len(b) != 1 for b in block_beats) or set.union(*block_beats) != set(beats):
                raise ValueError('parallel blocks must preserve each independent required objective')
            for block in group['blocks']:
                for key in block:
                    if not set(nodes[key]['after']) <= {group['entry'], *block} or group['entry'] not in predecessors(key):
                        raise ValueError('parallel objectives cannot depend on the other objective')
                if not set(block) <= predecessors(group['exit']):
                    raise ValueError('parallel exit must require both complete objective blocks')
        first, last = chapter['units'][0]['id'], chapter['units'][-1]['id']
        if nodes[first]['after'] or any(first not in predecessors(key) for key in nodes if key != first) or not (set(nodes)-{last}) <= predecessors(last):
            raise ValueError('subsection flow must connect every main unit from entry to exit')
    return {'chapters': len(ids), 'subsections': len(all_units), 'required_beats': sum(len(c['exit_requires_beats']) for c in plan['chapters']),
            'branch_candidates': sum(u['branch']['mode'] == 'candidate' for u in all_units),
            'branches_implemented': False, 'detailed_prose_complete': False, 'view': 'author_only'}


def subsection_document(plan=None, chapters=None, profiles=None, references=None):
    from writing import CHAPTERS, html_doc
    plan, chapters = plan or read(PLAN), chapters or read(CHAPTERS)
    profiles, references = profiles or load_characters(), references or load_references()
    report = validate_subsections(plan, chapters=chapters, profiles=profiles, references=references)
    data, raw = indexes(profiles, references), literals()
    display = lambda value: html.escape(render(value, data, raw, profiles, author=True))
    central = {c['id']: c for c in chapters['chapters']}
    body = '<p class="notice">작가 전용 · 전편 스포일러 · 소단락 주요 내용 초안. 이 문서는 원본 구성이며 일부 분기의 실행 정의는 <a href="branch-system.html">별도 JSON 분기 시스템</a>에 있습니다. 상세 본문은 아직 미완성입니다.</p>'
    body += f'<p>{report["chapters"]}장 · {report["subsections"]}소단락 · 분기 후보 {report["branch_candidates"]}곳. 필수 메인 결과를 유지하고 다음 소단락 전에 합류합니다.</p>'
    body += '<nav><ul>'+''.join('<li><a href="#'+html.escape(c['chapter_id'])+'">제'+str(central[c['chapter_id']]['number'])+'장 · '+display(central[c['chapter_id']]['title'])+'</a></li>' for c in plan['chapters'])+'</ul></nav>'
    for chapter in plan['chapters']:
        c = central[chapter['chapter_id']]
        body += '<h2 id="'+html.escape(c['id'])+'">제'+str(c['number'])+'장 · '+display(c['title'])+'</h2>'
        if chapter['parallel_groups']:
            body += '<p class="notice">이 장의 두 봉인 탐색은 모두 필수이며 순서는 자유입니다. 아래 배열은 현재 읽기 순서만 나타냅니다.</p>'
        for i, unit in enumerate(chapter['units'], 1):
            body += '<section id="'+html.escape(unit['id'].replace('/','-'))+'"><h3>'+str(c['number'])+'-'+str(i)+' · '+display(unit['title'])+'</h3>'
            body += '<p class="note">시작 · '+display(unit['entry'])+'</p><p>'+display(unit['main_content'])+'</p><p class="note">필수 결과 · '+display(unit['outcome'])+'</p>'
            if unit.get('logic'):
                body += '<dl>'+''.join('<dt>'+label+'</dt><dd>'+display(unit['logic'][key])+'</dd>'
                    for key,label in [('goal','목표'),('obstacle','장애 · 주의'),('next_reason','다음 행동의 이유')])+'</dl>'
            branch = unit['branch']
            body += '<details><summary>'+('분기 여지 · 아직 설계 전' if branch['mode']=='candidate' else '필수 흐름 · 분기 후보 없음')+'</summary>'
            if branch['mode'] == 'candidate':
                body += '<p>'+display(branch['variation_scope'])+'</p><p class="metadata">합류: '+html.escape(branch['rejoin_before'])+' · 인계 후보: '+html.escape(', '.join(branch['carry_keys']))+'</p>'
            body += '<p class="metadata">소단락: '+html.escape(unit['id'])+'<br>원문 구간: '+html.escape(', '.join(unit['source_section_refs']))+'<br>완료 사건: '+html.escape(', '.join(unit['completes_beats']) or '다음 핵심 사건을 잇는 과정')+'<br>논리 선행: '+html.escape(', '.join(unit['after']) or '앞 장의 인계를 받아 시작')+'</p></details></section>'
    body += '<h2>집필 규칙</h2><ul>'+''.join('<li>'+html.escape(s)+'</li>' for s in plan['notes'])+'</ul>'
    return html_doc('15장 소단락 · 주요 내용과 분기 경계', body)
