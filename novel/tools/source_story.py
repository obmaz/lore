"""Connect every packaged occurrence to prose, retaining conditional originals.

This is an author-only source edition, not a simulated playthrough. No Pascal is
executed and no original game files are read. The source snapshot is authoritative.
"""
import argparse
import copy
import hashlib
import html
import json
import re
from collections import Counter

import jsonschema
from referencing import Registry, Resource

from materials import ROOT, read, load_materials, validate_evidence
from characters import load_characters
from reference import COMMON, load_references, validate_claim
from text_refs import indexes, literals, validate_text, reject_fixed_names, render

PLAN = ROOT/'writing/storyboard/source-connected.plan.json'
SCHEMA = ROOT/'writing/source-connected.schema.json'
OUTPUT = ROOT/'writing/source-connected'
STORY_FILES = {'LORETALK.PAS', 'LORESPEC.PAS', 'LOREENT.PAS', 'LOREEND.PAS'}
FACILITY_RANGES = [(1015, 1040), (1156, 1634)]
INTRO_LETTER_RANGE = (11, 28)
INTRO_EVENT_RANGE = (221, 226)


def selected(source, selector):
    line = source.get('line', source.get('line_start'))
    end = source.get('line', source.get('line_end'))
    return (source['file'] == selector['file'] and
            selector['line_start'] <= line <= end <= selector['line_end'])


def source_indexes(catalog):
    raw = literals(catalog)
    events, scenes = {}, {}
    for unit in catalog['source_units']:
        for scene in unit['scenes']:
            scenes[scene['id']] = scene
            for event in scene['display_events']:
                key = event['statement_id']
                if key in events and events[key] != event:
                    raise ValueError('inconsistent source display event: '+key)
                events[key] = event
    return raw, events, scenes


def validate_plan(plan, catalog, data, raw):
    from writing import CHAPTERS
    schemas = [read(SCHEMA), read(COMMON), read(ROOT/'authoring/story.schema.json')]
    registry = Registry().with_resources([(s['$id'], Resource.from_contents(s)) for s in schemas] +
        [('https://lore.local/novel/authoring/story.schema.json', Resource.from_contents(schemas[-1]))])
    jsonschema.Draft202012Validator(schemas[0], registry=registry).validate(plan)
    central = read(CHAPTERS)
    ids = [c['id'] for c in central['chapters']]
    if (plan['version'] != 1 or plan['revision'] < 1 or plan['visibility'] != 'author_only'
            or plan['status'] != 'draft' or plan['purpose'] != 'source_first_connected_story_not_game_runtime'
            or plan['sequence_policy'] != 'editorial_linear_order_with_original_conditional_variants'
            or plan['priority'] != 'preserve_every_original_occurrence_and_display_event'
            or plan['chapters'] != 'storyboard/chapters.json'
            or plan['macro_stories'] != 'storyboard/chapter-stories.json'):
        raise ValueError('invalid source-first plan policy')
    def claim(row, value):
        validate_claim({'field':'source_connection', 'value':value, 'origin':row['origin'],
                        'status':'proposed', 'evidence':row.get('evidence', []),
                        'metadata':row['metadata']}, catalog)
    claim(plan, plan['purpose'])
    keys = [s['id'] for s in plan['sections']]
    if len(keys) != len(set(keys)):
        raise ValueError('duplicate connected section')
    seen = []
    files = {u['file']:len(u['original_source'].splitlines()) for u in catalog['source_units']}
    for section in plan['sections']:
        key = section['chapter_id']
        if key not in [*ids, 'temple_side_story', 'shared']:
            raise ValueError('unknown connected chapter')
        if key in ids and (not seen or seen[-1] != key): seen.append(key)
        claim(section, section['before'])
        for field in ('title', 'before', 'after'):
            validate_text(section[field], data, raw)
            reject_fixed_names(section[field], data)
        if not section['selectors']:
            raise ValueError('connected section needs source evidence')
        for selector in section['selectors']:
            if (set(selector) != {'file', 'line_start', 'line_end'} or selector['file'] not in files
                    or not 1 <= selector['line_start'] <= selector['line_end'] <= files[selector['file']]):
                raise ValueError('invalid connected source selector')
    if seen != ids:
        raise ValueError('connected story must preserve main chapter order')
    for finding in plan['findings']:
        claim(finding, finding['note'])
        validate_evidence(finding['evidence'], catalog)
    for rule in plan['binding_overrides']:
        validate_text([{'ref':rule['ref']}], data, raw)
        item = data[rule['ref']['catalog']][rule['ref']['id']]
        if rule['name'] != item.get('canonical_name', item.get('original_name', {})).get('value'):
            raise ValueError('binding override is not an original entity name')


def name_bindings(text, source, data, rules):
    """Bind canonical names, not invented meanings or an unspecified speaker.

Longest matches win. Original spellings not present in a dictionary are retained;
ambiguous matches are reported rather than silently deciding an entity's identity.
"""
    candidates = {}
    for category, items in data.items():
        for key, item in items.items():
            name = item.get('canonical_name', item.get('original_name', {})).get('value')
            if isinstance(name, str) and len(name) >= 2:
                candidates.setdefault(name, []).append({'catalog':category, 'id':key})
    bound, unresolved = [], []
    for name in sorted(candidates, key=lambda s:(-len(s), s)):
        pattern = re.escape(name) if not name.isascii() else r'(?<![A-Za-z])'+re.escape(name)+r'(?![A-Za-z])'
        for hit in re.finditer(pattern, text):
            start, end = hit.span()
            if any(a['start'] < end and start < a['end'] for a in bound): continue
            refs = candidates[name]
            matching = [r for r in rules if r['name'] == name and
                        ('file' not in r or selected(source, r))]
            if matching: ref = matching[-1]['ref']
            else:
                chars = [r for r in refs if r['catalog'] == 'characters']
                ref = chars[0] if len(chars) == 1 else refs[0] if len(refs) == 1 else None
            if ref is None:
                unresolved.append({'start':start, 'end':end, 'original_name':name, 'candidates':refs})
            else: bound.append({'start':start, 'end':end, 'ref':copy.deepcopy(ref)})
    return sorted(bound, key=lambda b:b['start']), unresolved


def compile_story(plan=None, profiles=None, references=None):
    catalog, snapshot = load_materials()
    plan = plan or read(PLAN)
    profiles, references = profiles or load_characters(catalog), references or load_references(catalog)
    data = indexes(profiles, references, catalog)
    raw, events, scenes = source_indexes(catalog)
    validate_plan(plan, catalog, data, raw)
    sections = [{**copy.deepcopy(s), 'records':[]} for s in plan['sections']]
    def owner(source):
        found = [s for s in sections if any(selected(source, r) for r in s['selectors'])]
        if len(found) > 1: raise ValueError('overlapping original source placements')
        return found[0] if found else None
    appendices = []
    def place(record, required=False):
        target = owner(record['source'])
        if target is None:
            if required: raise ValueError('unplaced original story script: '+record['id'])
            record['placement'] = 'system_appendix'
            appendices.append(record)
        else:
            record['placement'] = target['id']
            target['records'].append(record)
    covered = set()
    ordered_events = sorted(events.values(), key=lambda e:(e['source']['file'],e['source']['offset_start']))
    for event in ordered_events:
        ids = [l['id'] for l in raw.values() if l['statement_id'] == event['statement_id'] and
               l['source']['file'] == event['source']['file'] and
               event['source']['offset_start'] <= l['source']['offset_start'] < event['source']['offset_end']]
        # Empty strings and repeated fragments are distinct occurrences too.
        covered.update(ids)
        parts, unbound = [], []
        available = iter(ids)
        for part in event['parts']:
            if part['kind'] == 'literal':
                key = next(available, None)
                if key is None or raw[key]['text'] != part['text']:
                    raise ValueError('display parts disagree with source occurrences: '+event['statement_id'])
                binding, pending = name_bindings(part['text'], event['source'], data, plan['binding_overrides'])
                parts.append({'source':{'literal_ids':[key], 'bindings':binding}})
                unbound.extend(pending)
            elif part['source_expression'].lower() == 'player[1].name':
                parts.append({'ref':{'catalog':'characters', 'id':'protagonist'}})
            else:
                parts.append({'expression':part['source_expression']})
        if next(available, None) is not None:
            raise ValueError('unrepresented event occurrence: '+event['statement_id'])
        record = {'id':event['statement_id'], 'kind':'display_event',
                  'source':copy.deepcopy(event['source']), 'branch_context':copy.deepcopy(event['branch_context']),
                  'original':copy.deepcopy(event), 'literal_ids':ids, 'display_parts':parts,
                  'unresolved_name_bindings':unbound, 'origin':'source_exact', 'display_origin':'source_adaptation'}
        required = event['source']['file'] in STORY_FILES
        if event['source']['file'] == 'LORESUB.PAS':
            required = any(a <= event['source']['line_start'] <= b for a,b in FACILITY_RANGES)
        if event['source']['file'] == 'LOREHELP.PAS':
            required = INTRO_EVENT_RANGE[0] <= event['source']['line_start'] <= INTRO_EVENT_RANGE[1]
        place(record, required)
    for key, literal in raw.items():
        if key in covered: continue
        binding, pending = name_bindings(literal['text'], literal['source'], data, plan['binding_overrides'])
        record = {'id':key, 'kind':'literal_occurrence', 'source':copy.deepcopy(literal['source']),
                  'branch_context':copy.deepcopy(literal['branch_context']), 'original':copy.deepcopy(literal),
                  'literal_ids':[key], 'display_parts':[{'source':{'literal_ids':[key], 'bindings':binding}}],
                  'unresolved_name_bindings':pending, 'origin':'source_exact', 'display_origin':'source_adaptation'}
        intro = literal['source']['file'] == 'LOREHELP.PAS' and INTRO_LETTER_RANGE[0] <= literal['source']['line'] <= INTRO_LETTER_RANGE[1]
        place(record, required=intro)
    def position(record):
        return (record['source']['file'], record['source']['offset_start'])
    for section in sections:
        # Selector order is editorial; source occurrence order within a slice is not.
        section['records'].sort(key=lambda r:(next(i for i,s in enumerate(section['selectors']) if selected(r['source'],s)), *position(r)))
    appendices.sort(key=position)
    script_index = []
    for scene in scenes.values():
        targets = sorted({owner(raw[key]['source'])['id'] if owner(raw[key]['source']) else 'system_appendix'
                          for key in scene['text_occurrence_ids']})
        script_index.append({'id':scene['id'], 'source':scene['source'], 'maps':scene['maps'],
                             'entry_context':scene['entry_context'], 'original_source':scene['original_source'],
                             'state_changes':scene['state_changes'], 'calls':scene['calls'],
                             'literal_ids':scene['text_occurrence_ids'], 'placements':targets})
    records = [r for s in sections for r in s['records']] + appendices
    counts = Counter(key for r in records for key in r['literal_ids'])
    if set(counts) != set(raw) or any(n != 1 for n in counts.values()):
        raise ValueError('missing or duplicate original occurrence in connected edition')
    used_events = [r['id'] for r in records if r['kind'] == 'display_event']
    if len(used_events) != len(set(used_events)) or set(used_events) != set(events):
        raise ValueError('missing or duplicate original display event')
    report = {'source_files':snapshot['counts']['source_files'], 'literal_occurrences':len(raw),
              'display_events':len(events), 'source_scripts':len(scenes), 'connected_sections':len(sections),
              'main_chapters':len({s['chapter_id'] for s in sections if s['chapter_id'].startswith('chapter')}),
              'missing_literal_ids':[], 'missing_display_event_ids':[],
              'conditional_variants_preserved':True, 'single_playthrough_verified':False,
              'reader_prose_complete':False,
              'unresolved_name_bindings':sum(len(r['unresolved_name_bindings']) for r in records)}
    return {'version':1, 'revision':plan['revision'], 'visibility':'author_only', 'status':'draft',
            'purpose':plan['purpose'], 'sequence_policy':plan['sequence_policy'],
            'sections':sections, 'appendices':appendices, 'script_index':script_index,
            'findings':plan['findings'], 'notes':plan['notes'], 'coverage':report}


def validate_story(story, plan=None):
    expected = compile_story(plan)
    if story != expected:
        raise ValueError('source-connected edition differs: missing/changed original or connection; regenerate')
    return story['coverage']


def story_document(story=None):
    from writing import CHAPTERS, html_doc
    story = story or compile_story()
    profiles = load_characters()
    data, raw = indexes(profiles, load_references()), literals()
    def text(value): return html.escape(render(value, data, raw, profiles, author=True))
    def parts(value):
        return ''.join(html.escape('{{'+s['expression']+'}}') if 'expression' in s else text([s]) for s in value)
    central = {c['id']:c for c in read(CHAPTERS)['chapters']}
    body = '<p class="notice">작가 전용 · 전편 스포일러 · 원작 우선 연결 초고. 모든 조건부 원문을 보존한 자료이며 한 번의 플레이에서 전부 겪었다는 뜻은 아닙니다. 기존 선택소설을 대체하지 않습니다.</p>'
    body += '<p class="note">표시명은 참조 사전으로 적용한 각색이며 정확한 원문은 각 묶음의 펼치기에서 확인합니다. {{변수}}는 원작의 동적 자리입니다. 현재 동료·수치가 정해지지 않은 값을 임의로 채우지 않습니다.</p>'
    report = story['coverage']
    body += '<p>원문 발생 '+str(report['literal_occurrences'])+'개 · 출력 사건 '+str(report['display_events'])+'개 · 스크립트 '+str(report['source_scripts'])+'개 · 누락 0. 문체 완성·분기 실행 검증은 별도입니다.</p>'
    body += '<nav aria-label="연결 이야기 목차"><ul>'
    for key, chapter in central.items():
        body += '<li><a href="#'+key+'">제'+str(chapter['number'])+'장 · '+text(chapter['title'])+'</a></li>'
    body += '<li><a href="#temple_side_story">선택 성전</a></li><li><a href="#shared">공통 시설</a></li><li><a href="#appendix">전체 시스템·기술 원문 부록</a></li></ul></nav>'
    def records(rows):
        groups = []
        for row in rows:
            key = (row['kind'], row['source']['file'], row['branch_context'])
            if groups and groups[-1][0] == key: groups[-1][1].append(row)
            else: groups.append((key, [row]))
        result = ''
        for (kind, file, context), group in groups:
            result += '<p class="metadata">원작 조건: '+html.escape(json.dumps(context, ensure_ascii=False))+'</p>'
            result += '<div><p class="metadata">'+('원문 출력' if kind == 'display_event' else '원문 문구')+' · '+html.escape(file)+'</p>'
            result += '<blockquote style="white-space:pre-wrap;overflow-wrap:anywhere">'+'\n'.join(parts(row['display_parts']) for row in group)+'</blockquote>'
            exact = [{'id':row['id'], 'original':row['original'], 'literal_ids':row['literal_ids'],
                      'unresolved_name_bindings':row['unresolved_name_bindings']} for row in group]
            result += '<details><summary>보존 원문·조건·발생 ID '+str(len(group))+'개</summary><pre style="white-space:pre-wrap;overflow-wrap:anywhere">'+html.escape(json.dumps(exact,ensure_ascii=False,indent=2))+'</pre></details></div>'
        return result
    current = None
    for section in story['sections']:
        key = section['chapter_id']
        if key != current:
            if key in central:
                c = central[key]; title = '제'+str(c['number'])+'장 · '+text(c['title'])
            else: title = '선택 성전 · 원문 전체' if key == 'temple_side_story' else '공통 시설 · 조건별 원문'
            body += '<h2 id="'+html.escape(key)+'">'+title+'</h2>'; current = key
        body += '<section><h3>'+text(section['title'])+'</h3><p>'+text(section['before'])+'</p>'
        display = [r for r in section['records'] if section.get('show_literal_text', False) or r['kind'] == 'display_event' or r['original']['role'] in ('choice_label_or_prompt','display_text_fragment')]
        other = [r for r in section['records'] if r not in display]
        body += records(display)
        if other: body += '<details><summary>이 구간의 선언·빈 문구·기타 원문 '+str(len(other))+'개</summary>'+records(other)+'</details>'
        body += '<p>'+text(section['after'])+'</p></section>'
    body += '<h2 id="appendix">전체 시스템·기술 원문 부록</h2><p>전투·마법·휴식·생성/저장 UI, 표시 보조 함수, 파일명·제어용 문자열도 버리지 않았습니다. 이 기록을 특정 인물이 말하거나 실제로 모든 결과를 겪었다고 쓰지 않습니다.</p>'
    for file in sorted({r['source']['file'] for r in story['appendices']}):
        rows = [r for r in story['appendices'] if r['source']['file'] == file]
        body += '<details><summary>'+html.escape(file)+' · '+str(len(rows))+'개 기록</summary>'+records(rows)+'</details>'
    body += '<h2>복원한 원작 연결</h2><ul>'+''.join('<li>'+html.escape(f['note'])+'</li>' for f in story['findings'])+'</ul>'
    return html_doc('원작 전체 스크립트 · 15장 연결 초고', body)


def export(check=False):
    story = compile_story()
    artifacts = {'manuscript.json':json.dumps(story, ensure_ascii=False, indent=2)+'\n',
                 'coverage.json':json.dumps(story['coverage'], ensure_ascii=False, indent=2)+'\n'}
    inputs = [PLAN, SCHEMA, ROOT/'writing/storyboard/chapters.json', ROOT/'reference/terms.json',
              ROOT/'reference/names.json', ROOT/'characters/registry.json',
              *(ROOT/f'reference/{k}.json' for k in ('equipment','abilities','bestiary')),
              ROOT/'materials/manifest.json', ROOT/'materials/scripts.json', ROOT/'tools/text_refs.py',
              ROOT/'tools/source_story.py']
    manifest = {'version':1, 'source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
                'artifacts':{name:hashlib.sha256(body.encode()).hexdigest() for name,body in artifacts.items()}}
    path = OUTPUT/'generated-manifest.json'
    if path.exists():
        previous = read(path)
        for name, digest in previous['artifacts'].items():
            if name not in artifacts or not (OUTPUT/name).is_file() or hashlib.sha256((OUTPUT/name).read_bytes()).hexdigest() != digest:
                raise ValueError('source-connected output was manually edited; preserve it before regenerating: '+name)
    elif any((OUTPUT/name).exists() for name in artifacts):
        raise ValueError('source-connected output exists without a generation manifest')
    if check:
        if not path.exists() or read(path) != manifest:
            raise ValueError('source-connected output is stale; run source_story.py export')
    else:
        OUTPUT.mkdir(parents=True, exist_ok=True)
        for name, body in artifacts.items(): (OUTPUT/name).write_text(body, encoding='utf-8')
        path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    return {**story['coverage'], 'checked':check}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['validate','export'])
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.action == 'export': result = export(args.check)
    else: result = validate_story(read(OUTPUT/'manuscript.json'))
    print(json.dumps(result, ensure_ascii=False, indent=2))
