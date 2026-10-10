"""Validate the storyboard, instantiate shared quest forms and render reference-based prose."""
import argparse
import copy
import hashlib
import html
import json
from pathlib import Path

import jsonschema
from referencing import Registry, Resource

from materials import ROOT, load_materials, read
from characters import load_characters
from reference import COMMON, load_references, validate_claim
from story_continuity import CANON, context, context_for_routes, matches
from disclosure import public_ids, remap_ids
from text_refs import indexes, literals, render, validate_text, reject_fixed_names, source_ids, archival, validate_names

WRITING = ROOT/'writing'
BOARD = WRITING/'storyboard/series.json'
PILOT = WRITING/'quests/prologue.json'
TEXT_FIELDS = ('title','opening','goal','conflict','turn','ending','emotional_arc','bridge')
DEFAULT_ROUTE = ['enter_courtyard','visit_lord','hear_lord_intro','hear_lord_briefing']
READING = WRITING/'reading.json'


def reading_preview(key):
    from reading import load_reading
    catalog = read(READING)
    if key not in catalog['routes']:
        raise ValueError('unknown reading route: '+key)
    recipe = copy.deepcopy(catalog['routes'][key])
    recipe.setdefault('title',catalog['title'])
    story,memory,route = load_reading(recipe)
    result = preview_story(story,memory,route)
    if 'focus_nodes' in recipe:
        focus = recipe['focus_nodes']
        if not focus or len(set(focus))!=len(focus):
            raise ValueError('focused reading needs unique scene IDs')
        positions = [i for i,s in enumerate(result['sections']) if s['node_id'] in focus]
        seen = {result['sections'][i]['node_id'] for i in positions}
        if seen!=set(focus):
            raise ValueError('focused scene is not on the selected route')
        # Replaying a future route then hiding its paragraphs is not a unit preview.
        # The one permitted trailing section is the target of the final choice.
        if max(positions)<len(result['sections'])-2:
            raise ValueError('focused reading route continues beyond selected unit')
        result['sections'] = [result['sections'][i] for i in positions]
        result['open_questions'] = recipe.get('review_notes',[])
    result['reading_note'] = recipe['note']
    return result


def focus_episode(preview,unit,quest_id,packet_for,profiles=None,references=None):
    """Reuse prefix-rendered paragraphs, but replay the unit endpoint for its memory."""
    if len(preview['sections'])!=len(preview['route'])+1:
        raise ValueError('episode requires an unsliced reading path')
    focus = {quest_id+'/'+n for n in unit['node_ids']}
    positions = [i for i,s in enumerate(preview['sections']) if s['node_id'] in focus]
    if not positions or preview['sections'][max(positions)]['node_id']!=quest_id+'/'+unit['node_ids'][-1]:
        raise ValueError('episode endpoint is not on selected route')
    last = max(positions)
    end = last+int(preview['sections'][last]['selected_choice'] is not None)
    route = preview['route'][:end]
    packet = packet_for(route)
    profiles = profiles or load_characters()
    data = indexes(profiles,references or load_references())
    result = {**preview,'title':render(unit['title'],data,literals(),profiles,packet['disclosed_events']),
        'route':route,'sections':copy.deepcopy([preview['sections'][i] for i in positions]),
        'open_questions':['새 감각·동작·대화는 창작으로 표시한 미승인 초고다. 원문 부수 경로의 보류는 유지한다.'],
        'reading_note':'이 소편의 이전 기억은 유지하고 마지막 선택에서 멈춘 읽기본. '+preview['reading_note']}
    for key in ('knowledge','state','disclosed_events','needs_review'):
        result[key] = packet[key]
    return result


def episode_preview(unit_id,reading_key='first-journey'):
    from reading import load_reading
    plan = read(WRITING/'episodes/lore_menace.json')
    validate_episode_plan(plan)
    unit = next((u for u in plan['units'] if u['id']==unit_id),None)
    if unit is None or unit['status']!='revised_draft':
        raise ValueError('episode has not been written: '+unit_id)
    recipe = read(READING)['routes'][reading_key]
    story,memory,_ = load_reading(recipe)
    return focus_episode(reading_preview(reading_key),unit,Path(plan['quest_file']).stem,
                         context_for_routes(story,memory,read(CANON)))


def validate_episode_plan(plan,story=None):
    if plan['version']!=1 or plan['purpose']!='small_batch_authoring_not_game_runtime':
        raise ValueError('invalid episode plan')
    path = (WRITING/'quests'/plan['quest_file']).resolve()
    if not path.is_relative_to((WRITING/'quests').resolve()):
        raise ValueError('episode path escapes quests')
    story = story if story is not None else read(path)
    profiles = load_characters()
    data,raw = indexes(profiles,load_references()),literals()
    ids = [u['id'] for u in plan['units']]
    nodes = [n for u in plan['units'] for n in u['node_ids']]
    if not ids or len(ids)!=len(set(ids)) or len(nodes)!=len(set(nodes)):
        raise ValueError('duplicate or empty episode units/scenes')
    if set(nodes)!={n['id'] for n in story['nodes']}:
        raise ValueError('episode plan must assign each quest scene once')
    for u in plan['units']:
        if not u['node_ids'] or u['status'] not in ('outline','structural_draft','revised_draft'):
            raise ValueError('invalid episode scenes/status')
        low,high = u['target_chars']
        if not 0<low<=high:
            raise ValueError('invalid episode length target')
        validate_text(u['title'],data,raw); reject_fixed_names(u['title'],data)
        validate_claim({'field':'episode_plan','value':u['title'],'origin':u['origin'],
                        'status':'proposed','evidence':[],'metadata':u['metadata']},load_materials()[0])
    return {'units':len(ids),'revised_drafts':sum(u['status']=='revised_draft' for u in plan['units']),
            'note':'분량 목표와 구성 검사이지 문체 승인이나 모든 분기의 완성을 뜻하지 않는다.'}


def validate_board(board,data=None,profiles=None):
    catalog = load_materials()[0]
    profiles = profiles or load_characters(catalog)
    data = data or indexes(profiles,load_references(catalog),catalog)
    schema = read(WRITING/'storyboard.schema.json')
    story_schema = read(ROOT/'authoring/story.schema.json')
    common = read(COMMON)
    registry = Registry().with_resources([
        (schema['$id'],Resource.from_contents(schema)),(common['$id'],Resource.from_contents(common)),
        (story_schema['$id'],Resource.from_contents(story_schema)),
        ('https://lore.local/novel/authoring/story.schema.json',Resource.from_contents(story_schema))])
    jsonschema.Draft202012Validator(schema,registry=registry).validate(board)
    all_literals = literals(catalog)
    quests = {q['id']:q for q in read(ROOT/'materials/quests.json')['quests']}
    anchors = {q['id']+':'+m['id']:m for q in quests.values() for m in q.get('milestones',[])}
    arc_ids = [a['id'] for a in board['arcs']]
    if len(set(arc_ids))!=len(arc_ids):
        raise ValueError('duplicate storyboard arc')
    ids = [u['id'] for u in board['units']]
    quest_ids = [u['quest_id'] for u in board['units']]
    if len(ids)!=len(set(ids)) or len(quest_ids)!=len(set(quest_ids)):
        raise ValueError('duplicate storyboard unit')
    if board['kind']=='series' and set(quest_ids)!={q['id'] for q in quests.values() if q['kind']!='appendix'}:
        raise ValueError('series must account for all story quests without the common appendix')
    if any(i not in quests or quests[i]['kind']!='appendix' for i in board['appendices']):
        raise ValueError('invalid storyboard appendix')
    relation_ids = {r['id'] for p in profiles['characters'].values() for r in p['relationships']}
    def check_text(value):
        validate_text(value,data,all_literals)
        reject_fixed_names(value,data)
    check_text(board['title'])
    for arc in board['arcs']:
        check_text(arc['title']); check_text(arc['role'])
        validate_claim({'field':'arc','value':arc['role'],'origin':'authored','status':'proposed','evidence':[], 'metadata':arc['metadata']},catalog)
    for unit in board['units']:
        if unit['quest_id'] not in quests or unit['arc'] not in arc_ids:
            raise ValueError('unknown storyboard quest/arc')
        if not set(unit['source_anchors'])<=set(anchors):
            raise ValueError('unknown storyboard source anchor')
        if not set(unit['cast_candidates'])<=set(profiles['characters']):
            raise ValueError('unknown storyboard cast candidate')
        if not set(unit['branches'])<=relation_ids:
            raise ValueError('unknown storyboard relationship branch')
        if not set(unit['disclosure_candidates'])<=set(profiles['disclosure_checkpoints']):
            raise ValueError('unknown storyboard disclosure candidate')
        evidence = [e for a in unit['source_anchors'] for e in anchors[a]['evidence']]
        if board['kind']=='series':
            validate_claim({'field':'outline','value':unit['goal'],'origin':unit['origin'],'status':'proposed',
                            'evidence':evidence,'metadata':unit['metadata']},catalog)
            if set(unit['authored_fields'])!={'emotional_arc','bridge'}:
                raise ValueError('new emotional arcs and bridges must be marked authored')
        for field in TEXT_FIELDS:
            check_text(unit[field])
    return {'units':len(board['units']),'arcs':len(board['arcs']),'status':'outline','view':'author_only',
            'source_dialogue_complete':False,'condition_paths_verified':False}


def preview_story(story,continuity,route,profiles=None,references=None):
    profiles = profiles or load_characters()
    references = references or load_references()
    data,all_literals = indexes(profiles,references),literals()
    validate_names(data)
    if story['meta'].get('reference_text') is not True:
        raise ValueError('new writing drafts must enable reference_text')
    nodes = {n['id']:n for n in story['nodes']}
    packet_for = context_for_routes(story,continuity,read(CANON),profiles)
    sections = []
    key = story['entry_node']
    for prefix_length in range(len(route)+1):
        packet = packet_for(route[:prefix_length])
        disclosed = packet['disclosed_events']
        ids = public_ids(profiles,disclosed)
        def display(value):
            return render(value,data,all_literals,profiles,disclosed)
        blocks = []
        # Render the private source objects through disclosure, not remapped IDs.
        # The public packet may rename a hidden identity's reference ID itself.
        visible = [b for b in nodes[key]['blocks'] if b['kind']!='author_note' and matches(b['when'],packet['state'])]
        for block,public_block in zip(visible,packet['visible_blocks']):
            value = display(block['text'])
            origin = block['provenance']['origin']
            display_origin = 'source_adaptation' if origin=='source_exact' and value!=archival(block['text'],all_literals) else origin
            blocks.append({'id':public_block['id'],'speaker':display([{'ref':{'catalog':'characters','id':block['speaker']}}]) if block['speaker'] else None,
                           'text':value,'origin':origin,'display_origin':display_origin,'source_literal_ids':source_ids(block['text'])})
        selected = route[prefix_length] if prefix_length<len(route) else None
        sections.append({'node_id':packet['node_id'],'title':display(nodes[key]['title']),'blocks':blocks,
                         'selected_choice':remap_ids(selected,ids),'choices':[{'id':remap_ids(c['id'],ids),'label':display(c['label'])} for c in nodes[key]['choices'] if matches(c['when'],packet['state'])]})
        if selected:
            key = next(c['target'] for c in nodes[key]['choices'] if c['id']==selected)
    final = packet_for(route)
    return {'title':render(story['meta']['title'],data,all_literals,profiles,final['disclosed_events']),
            'status':story['meta']['status'],'provisional':True,'route':route,'sections':sections,
            'knowledge':final['knowledge'],'state':final['state'],'disclosed_events':final['disclosed_events'],
            'needs_review':final['needs_review'],'open_questions':story['open_questions']}


def html_doc(title,body):
    esc = html.escape
    return '<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+esc(title)+'</title>'+'''
<style>body{max-width:850px;margin:auto;padding:28px 20px;background:#f6f3eb;color:#25372e;font:17px/1.95 "Noto Sans CJK KR","Malgun Gothic",sans-serif;overflow-wrap:anywhere}h1{font-size:34px}h2{margin-top:48px;border-bottom:1px solid #b9c8bd}h3{font-size:18px}small,.note{font-size:13px;color:#627367}.notice{background:#e5ecdf;padding:15px}.quote{border-left:3px solid #66886e;padding:8px 18px;background:white}.metadata{font-size:12px;color:#617265}a{color:#27634c}button{font:inherit;padding:6px 12px}li{margin:5px 0}section{break-inside:auto}@page{size:A4;margin:18mm}@media print{body{padding:0;background:white;font-size:11px}button{display:none}h1{font-size:24px}h2,h3{break-after:avoid}p{orphans:3;widows:3}}</style>
'''+f'<h1>{esc(title)}</h1><button onclick="print()">인쇄 / PDF 저장</button>'+body+'</html>'


def export_documents(output,check=False):
    from validate_story_authoring import validate
    profiles = load_characters()
    refs = load_references()
    data,all_literals = indexes(profiles,refs),literals()
    validate_names(data)
    board = read(BOARD)
    validate_board(board,data,profiles)
    story,continuity = read(PILOT),read(PILOT.with_name('prologue.continuity.json'))
    validate(story)
    esc = html.escape
    display = lambda t:render(t,data,all_literals,author=True)
    body = '<p class="notice">작가 전용 · 전편 스포일러 포함. 보드의 감정선·연결은 창작 제안이고, 나머지도 원문 사건의 편집 해석입니다. 원작 조건이 집필 배열보다 우선합니다.</p>'
    body += '<p>단위 '+str(len(board['units']))+'개 · 퀘스트 연결·병렬 목표는 materials/quests.json의 route_edges를 참조합니다.</p>'
    labels = dict(title='제목',opening='시작 상황',goal='목표',conflict='갈등·분기 주의',turn='전환',ending='종료 상황',emotional_arc='감정선 · 창작 제안',bridge='연결 장면 · 창작 제안')
    for arc in board['arcs']:
        body += f'<h2>{esc(display(arc["title"]))}</h2><p>{esc(display(arc["role"]))}</p>'
        for unit in board['units']:
            if unit['arc']!=arc['id']: continue
            body += '<section><h3>'+esc(display(unit['title']))+'</h3>'
            body += ''.join(f'<p><strong>{esc(labels[k])}</strong><br>{esc(display(unit[k]))}</p>' for k in TEXT_FIELDS if k!='title')
            body += f'<p class="metadata">근거: {esc(", ".join(unit["source_anchors"]))}<br>조건부 관계: {esc(", ".join(unit["branches"]) or "없음")}<br>공개 후보: {esc(", ".join(unit["disclosure_candidates"]) or "별도 검토")}</p></section>'
    represented = {e for u in board['units'] for e in u['disclosure_candidates']}
    body += '<h2>공통 사건의 배치 검토</h2><p>다음 원문 공개 장면은 누락시키지 않고 실제 접근 조건을 확인한 뒤 퀘스트 사이에 배치합니다. 아직 자동 공개하거나 강제 순서를 붙이지 않습니다.</p><ul>'+''.join(f'<li>{esc(i)}</li>' for i in profiles['disclosure_checkpoints'] if i not in represented)+'</ul>'
    body += '<h2>미해결 사항</h2><ul>'+''.join(f'<li>{esc(q)}</li>' for q in board['open_questions'])+'</ul>'
    docs = {'storyboard.html':html_doc(display(board['title']),body)}
    previews = [('prologue.html',preview_story(story,continuity,DEFAULT_ROUTE,profiles,refs)),
                ('prologue-tavern.html',preview_story(story,continuity,['enter_courtyard','visit_tavern','remember_veteran',*DEFAULT_ROUTE[1:]],profiles,refs))]
    if READING.exists():
        previews += [(key+'.html',reading_preview(key)) for key in read(READING)['routes']]
        # Full-path paragraphs were rendered with each scene's own disclosure prefix.
        # Derive small reading units with a separate, bounded endpoint packet.
        from reading import load_reading
        foundation,memory,_ = load_reading(read(READING)['routes']['first-journey'])
        packet_for = context_for_routes(foundation,memory,read(CANON),profiles)
        plan = read(WRITING/'episodes/lore_menace.json')
        validate_episode_plan(plan)
        full = dict(previews)
        for unit in plan['units'][1:]:
            if unit['status']!='revised_draft': continue
            for suffix,key in [('', 'first-journey'),('-declined','first-journey-declined')]:
                previews.append((unit['id']+suffix+'.html',focus_episode(full[key+'.html'],unit,
                    Path(plan['quest_file']).stem,packet_for,profiles,refs)))
    for name,preview in previews:
        body = '<p class="notice">시범 원고 · 미승인. 창작 연결 서사와 원문 대사를 함께 배치했습니다. 원작 고유명은 현재 참조 표시명으로 각색해 보여 주며, 원문 기록은 JSON에 보존됩니다.</p>'
        if 'reading_note' in preview:
            body += '<p class="note">'+esc(preview['reading_note'])+'</p>'
        for section in preview['sections']:
            body += '<section><h2>'+esc(section['title'])+'</h2>'
            for block in section['blocks']:
                body += ('<p class="quote">'+(f'<small>{esc(block["speaker"])}</small><br>' if block['speaker'] else '')+esc(block['text'])+'</p>') if block['origin']=='source_exact' else '<p>'+esc(block['text'])+'</p>'
            if section['selected_choice']:
                chosen = next(c['label'] for c in section['choices'] if c['id']==section['selected_choice'])
                body += f'<p class="note">선택: {esc(chosen)}</p>'
            body += '</section>'
        body += '<h2>집필 메모</h2><ul>'+''.join(f'<li>{esc(q)}</li>' for q in preview['open_questions'])+'</ul>'
        docs[name] = html_doc(preview['title'],body)
    inputs = [BOARD,PILOT,PILOT.with_name('prologue.continuity.json'),ROOT/'characters/registry.json',ROOT/'reference/names.json',
              ROOT/'reference/terms.json',ROOT/'continuity/canon.json',ROOT/'writing/project.json',Path(__file__),ROOT/'tools/text_refs.py',
              ROOT/'tools/story_continuity.py',ROOT/'tools/disclosure.py',ROOT/'tools/validate_story_authoring.py',
              ROOT/'authoring/story.schema.json',WRITING/'storyboard.schema.json',
              *(ROOT/f'reference/{c}.json' for c in refs)]
    if READING.exists():
        inputs += [READING,ROOT/'tools/reading.py',ROOT/'continuity/continuity.schema.json']
        for name in sorted({p['file'] for r in read(READING)['routes'].values() for p in r['parts']}):
            path = WRITING/'quests'/name
            inputs += [path,path.with_name(path.stem+'.continuity.json')]
    inputs += sorted((WRITING/'episodes').glob('*.json'))
    manifest = {'version':1,'source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
                'artifacts':{name:hashlib.sha256(value.encode()).hexdigest() for name,value in docs.items()}}
    if check:
        if not (output/'manifest.json').is_file() or read(output/'manifest.json')!=manifest:
            raise ValueError('writing previews are stale; run writing.py export')
        for name,body in docs.items():
            if not (output/name).is_file() or (output/name).read_text(encoding='utf-8')!=body:
                raise ValueError('writing preview was edited or is missing: '+name)
    else:
        output.mkdir(parents=True,exist_ok=True)
        for name,body in docs.items():
            (output/name).write_text(body,encoding='utf-8')
        (output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return {'output':str(output),'artifacts':list(docs),'storyboard_units':len(board['units']),'checked':check}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['validate','preview','reading','episode','export','new-quest'])
    parser.add_argument('--story',type=Path,default=PILOT)
    parser.add_argument('--route',nargs='*',default=DEFAULT_ROUTE)
    parser.add_argument('--output',type=Path,default=WRITING/'previews')
    parser.add_argument('--quest-id')
    parser.add_argument('--reading-key',default='first-journey')
    parser.add_argument('--episode-id')
    parser.add_argument('--check',action='store_true',help='check generated previews without writing')
    args = parser.parse_args()
    if args.action=='validate':
        from validate_story_authoring import validate
        from story_continuity import validate as validate_continuity
        template = read(WRITING/'templates/quest.template.json')
        validate_names(indexes(load_characters(),load_references()))
        if any(s['meta'].get('reference_text') is not True for s in (template,read(PILOT))):
            raise ValueError('new writing drafts must enable reference_text')
        result = {'board':validate_board(read(BOARD)),'pilot':validate(read(PILOT)),
                  'storyboard_template':validate_board(read(WRITING/'templates/storyboard.template.json')),
                  'quest_template':validate(template),
                  'continuity_template_review':validate_continuity(template,read(WRITING/'templates/continuity.template.json'),read(CANON))}
        result['quests'] = {}
        for path in sorted((WRITING/'quests').glob('*.json')):
            if path.name.endswith('.continuity.json'): continue
            draft = read(path)
            if draft['meta'].get('reference_text') is not True:
                raise ValueError('new writing drafts must enable reference_text')
            result['quests'][path.stem] = {**validate(draft),'needs_review':validate_continuity(draft,read(path.with_name(path.stem+'.continuity.json')),read(CANON))}
        result['episodes'] = {p.stem:validate_episode_plan(read(p)) for p in sorted((WRITING/'episodes').glob('*.json'))}
        result['episode_template'] = validate_episode_plan(read(WRITING/'templates/episode.template.json'),template)
    elif args.action=='preview':
        result = preview_story(read(args.story),read(args.story.with_name(args.story.stem+'.continuity.json')),args.route)
    elif args.action=='reading':
        result = reading_preview(args.reading_key)
    elif args.action=='episode':
        if not args.episode_id: parser.error('episode needs --episode-id')
        result = episode_preview(args.episode_id,args.reading_key)
    elif args.action=='export':
        result = export_documents(args.output.resolve(),args.check)
    else:
        quests = {q['id'] for q in read(ROOT/'materials/quests.json')['quests'] if q['kind']!='appendix'}
        if args.quest_id not in quests:
            parser.error('new-quest needs a known --quest-id')
        target = WRITING/'quests'/f'{args.quest_id}.json'
        sidecar = target.with_name(target.stem+'.continuity.json')
        if target.exists() or sidecar.exists():
            parser.error('quest exists; refusing overwrite')
        value = copy.deepcopy(read(WRITING/'templates/quest.template.json'))
        value['meta'].update(id=args.quest_id+'_draft_v1',quest_id=args.quest_id)
        memory = copy.deepcopy(read(WRITING/'templates/continuity.template.json'))
        profiles = load_characters()
        memory.update(story_id=value['meta']['id'],canon_revision=read(CANON)['revision'],character_registry_revision=profiles['revision'])
        memory['contracts']['entry']['character_dependencies'][0]['revision'] = profiles['characters']['protagonist']['revision']
        target.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        sidecar.write_text(json.dumps(memory,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        result = {'created':[str(target),str(sidecar)],'status':'outline','continuity_contracts_must_be_written':True}
    print(json.dumps(result,ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
