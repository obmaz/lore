"""Author-only macro stories; reference the chapter contract, never replace prose."""
import html

import jsonschema
from referencing import Registry, Resource

from materials import ROOT, read, load_materials
from characters import load_characters
from reference import COMMON, load_references, validate_claim
from text_refs import indexes, literals, validate_text, reject_fixed_names, render

STORIES = ROOT/'writing/storyboard/chapter-stories.json'
SCHEMA = ROOT/'writing/chapter-stories.schema.json'
TEMPLATE = ROOT/'writing/templates/chapter-stories.template.json'
STAGES = ('opening', 'escalation', 'turning_point', 'ending')


def validate_stories(draft, chapters=None, profiles=None, references=None):
    from writing import CHAPTERS
    chapters = chapters if chapters is not None else read(CHAPTERS)
    schema, common, story_schema = read(SCHEMA), read(COMMON), read(ROOT/'authoring/story.schema.json')
    registry = Registry().with_resources([
        (s['$id'], Resource.from_contents(s)) for s in (schema, common, story_schema)] + [
        ('https://lore.local/novel/authoring/story.schema.json', Resource.from_contents(story_schema))])
    jsonschema.Draft202012Validator(schema, registry=registry).validate(draft)
    catalog = load_materials()[0]
    profiles = profiles or load_characters(catalog)
    data, raw = indexes(profiles, references or load_references(catalog), catalog), literals(catalog)
    def text(value):
        validate_text(value, data, raw)
        reject_fixed_names(value, data)
    def authored(row, value):
        validate_claim({'field':'macro_story', 'value':value, 'origin':row['origin'],
                        'status':'proposed', 'evidence':[], 'metadata':row['metadata']}, catalog)
    text(draft['premise']); authored(draft, draft['premise'])
    central = {c['id']:c for c in chapters['chapters']}
    source_sections = {s['id']:s['chapter_id'] for s in read(ROOT/'writing/storyboard/source-connected.plan.json')['sections']}
    ids = [c['chapter_id'] for c in draft['chapters']]
    if len(ids)!=len(set(ids)) or not set(ids)<=set(central):
        raise ValueError('macro story has duplicate or unknown chapter references')
    if draft['kind']=='series' and ids!=list(central):
        raise ValueError('macro story must preserve all chapters in reading order')
    act_ids = [a['id'] for a in draft['acts']]
    assigned = [key for a in draft['acts'] for key in a['chapter_ids']]
    if len(act_ids)!=len(set(act_ids)) or assigned!=ids:
        raise ValueError('macro acts must assign each chapter once in reading order')
    for act in draft['acts']:
        text(act['summary'])
        if any(central[key]['arc']!=act['id'] for key in act['chapter_ids']):
            raise ValueError('macro act disagrees with chapter contract')
    parallel = [e['from'] for e in read(ROOT/'materials/quests.json')['route_edges']
                if e['kind']=='required_all_state_gate' and isinstance(e['from'],list)]
    for index, row in enumerate(draft['chapters']):
        chapter = central[row['chapter_id']]
        if any(source_sections.get(key) != row['chapter_id'] for key in row['source_section_refs']):
            raise ValueError('macro story has unknown or cross-chapter source section')
        beats = {b['id']:b for b in chapter['required_beats']}
        if set(row['beat_refs'])!=set(beats):
            raise ValueError('macro story omitted or borrowed a required beat')
        next_id = ids[index+1] if index+1<len(ids) else None
        if row['handoff']['next_chapter']!=next_id:
            raise ValueError('macro causal handoff must lead to the next chapter')
        groups = []
        for objectives in parallel:
            if set(objectives)<=set(chapter['unit_ids']):
                groups.append({b['id'] for b in beats.values()
                               if any(a.split(':',1)[0] in objectives for a in b['source_anchors'])})
        actual = [set(g) for g in row['parallel_beat_groups']]
        if len(actual)!=len(groups) or any(g not in actual for g in groups):
            raise ValueError('macro story must preserve both flexible-order objectives')
        for value in [*row['story'].values(), row['dramatic_question'], row['emotional_change'],
                      row['handoff']['reason'], *row['continuity_limits']]:
            text(value)
        authored(row, row['story'])
    return {'chapters':len(ids), 'story_paragraphs':len(ids)*len(STAGES),
            'required_beats':sum(len(r['beat_refs']) for r in draft['chapters']),
            'status':'draft', 'view':'author_only', 'branches_designed':False,
            'detailed_prose_complete':False}


def story_document(draft=None, chapters=None):
    from writing import CHAPTERS, html_doc
    draft, chapters = draft or read(STORIES), chapters or read(CHAPTERS)
    profiles, references = load_characters(), load_references()
    validate_stories(draft, chapters, profiles, references)
    data, raw = indexes(profiles, references), literals()
    display = lambda value: html.escape(render(value, data, raw, profiles, author=True))
    central = {c['id']:c for c in chapters['chapters']}
    body = '<p class="notice">작가 전용 · 전편 스포일러 · 미승인 큰 줄거리 초고. 분기와 상세 본문은 다음 단계입니다. 독자용 소설에 통째로 공개하지 않습니다.</p>'
    body += '<h2>전편을 잇는 이야기</h2><p>'+display(draft['premise'])+'</p>'
    for act in draft['acts']:
        body += '<p class="note">'+html.escape(act['id'])+' · '+display(act['summary'])+'</p>'
    for row in draft['chapters']:
        chapter = central[row['chapter_id']]
        body += '<section><h2>제'+str(chapter['number'])+'장 · '+display(chapter['title'])+'</h2>'
        body += '<p class="note">필수 메인 · 큰 줄거리 초고 · '+html.escape(row['chapter_id'])+'</p>'
        body += '<h3>이 장의 질문</h3><p>'+display(row['dramatic_question'])+'</p><h3>큰 이야기</h3>'
        body += ''.join('<p>'+display(row['story'][stage])+'</p>' for stage in STAGES)
        body += '<h3>겪고 난 뒤의 변화</h3><p>'+display(row['emotional_change'])+'</p>'
        body += '<h3>다음 장으로 이어지는 이유</h3><p>'+display(row['handoff']['reason'])+'</p>'
        body += '<details><summary>집필 시 지킬 조건</summary><ul>'+''.join('<li>'+display(v)+'</li>' for v in row['continuity_limits'])+'</ul><p class="metadata">필수 사건 참조: '+html.escape(', '.join(row['beat_refs']))+'</p><p class="metadata">원문 연결 구간: '+html.escape(', '.join(row['source_section_refs']))+'</p></details></section>'
    body += '<h2>이번 구성에서 다듬은 점</h2><ul>'+''.join('<li>'+html.escape(v)+'</li>' for v in draft['refinement_notes'])+'</ul>'
    body += '<h2>다음 작업과 보류점</h2><ul>'+''.join('<li>'+html.escape(v)+'</li>' for v in draft['open_questions'])+'</ul>'
    return html_doc('15장 큰 이야기 · 집필 구성 초고', body)
