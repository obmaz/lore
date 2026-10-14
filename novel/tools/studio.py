"""Bundle existing authoring outputs into one offline, author-only workspace."""
import argparse
import hashlib
import html
import json
import re
from pathlib import Path

import jsonschema

from materials import ROOT, read
from publication_flow import PublicationFlow
from export_reference import character_html, claim_table, relation_html, title_of, value_html, LABELS, evidence_html, writing_claims
from text_refs import validate_names

PLAN = ROOT/'writing/studio/studio.plan.json'
SCHEMA = ROOT/'writing/studio/studio.schema.json'
TEMPLATE = ROOT/'writing/studio/shell.html'
SCRIPT = ROOT/'writing/studio/studio.js'
OUTPUT = ROOT/'writing/studio/generated'
PREVIEWS = ROOT/'writing/previews'
VIEWS = ('overview', 'reading', 'outline', 'graph', 'order', 'settings', 'sources')


def chapter_branch_details(publication, chapter_id):
    """Read-only, chapter-filtered details from the same plan as the graph."""
    session = publication.session
    esc = html.escape
    display = lambda value: esc(session.display(value))
    belongs = lambda key: key.split('/')[0] == chapter_id
    def heading(key):
        return esc(publication.unit_numbers[key]+' · '+session.display(publication.resolve(publication.heading(key))))
    def source(pointer):
        return '<div class="source-note"><button type="button" class="button small" data-source="'+esc(publication.bp)+'" data-pointer="'+esc(pointer)+'">원본 JSON 보기</button></div>'
    def raw(value, label='조건·상태 변화 · 추가 메타데이터'):
        return '<details class="rule-json"><summary>'+label+'</summary><pre>'+esc(json.dumps(value,ensure_ascii=False,indent=2))+'</pre></details>'
    decisions = [d for d in session.plan['decisions'] if belongs(d['unit_id'])]
    reactions = [(i,r) for i,r in enumerate(session.plan['reactions']) if belongs(r['unit_id'])]
    body = '<p class="notice">이 장의 '+str(len(decisions))+'개 결정 · '+str(sum(len(d['options']) for d in decisions))+'개 선택 · '+str(len(reactions))+'개 후속 반응. 집필 추가 · 주요 내용 초안이며 원작의 확정 사실이나 승인된 장편 본문이 아닙니다.</p>'
    for d in decisions:
        side = d['id'].startswith('side_')
        body += '<details class="unit branch-rule"><summary>'+display(publication.plan['decision_titles'][d['id']])+(' <span class="badge added">선택 곁가지 · 창작 초고</span>' if side else '')+' <small>'+heading(d['unit_id'])+'</small></summary><div class="unit-body"><p>'+display(d['prompt'])+'</p>'
        for o in d['options']:
            body += '<section class="branch-option"><h4>'+display(o['label'])+'</h4><p>'+display(o['body'])+'</p>'
            body += raw({k:o[k] for k in ('id','when','participants','effects','origin','metadata')})+'</section>'
        body += '<p class="merge-note">필수 합류: '+heading(d['rejoin_before'])+'</p>'
        orders = [o for o in session.plan['parallel_orders'] if o['decision_id']==d['id']]
        if orders:
            body += '<p>탐색 순서만 달라집니다. 두 목표를 모두 마친 뒤 합류합니다.</p>'+raw(orders,'병렬 목표 순서 JSON')
        body += source(publication.decision_paths[d['id']])
        if side:
            story=session.story_by_decision.get(d['id']) or session.approach_by_decision[d['id']]
            index=next(i for i,s in enumerate(session.stories) if s['id']==story['id'])
            body += '<div class="source-note"><button type="button" class="button small" data-source="writing/side-stories/series.json" data-pointer="/stories/'+str(index)+('/approach' if d['id'] in session.approach_by_decision else '')+'">곁가지 집필 원본 JSON</button></div>'
        body += '</div></details>'
    if not decisions:
        body += '<p class="muted">이 장에는 구현된 선택이 없습니다. 필수 본줄기를 따라 진행합니다.</p>'
    if reactions:
        body += '<h2>조건부 후속 반응</h2>'
        for i,r in reactions:
            body += '<details class="unit branch-reaction"><summary>'+heading(r['unit_id'])+' <small>'+esc(r['id'])+'</small></summary><div class="unit-body"><p>'+display(r['text'])+'</p>'
            body += raw({k:r[k] for k in ('when','participants','requires_units','origin','metadata')})+source('/reactions/'+str(i))+'</div></details>'
    rules = [(key,r) for key,r in session.plan['unit_rules'].items() if belongs(key)]
    if rules:
        body += '<details class="unit"><summary>본줄기 진입 조건 · 필수 상태 변화</summary><div class="unit-body">'
        for key,r in rules:
            body += '<h4>'+heading(key)+'</h4>'+raw(r)+source('/unit_rules/'+key.replace('~','~0').replace('/','~1'))
        body += '</div></details>'
    deferred = [u for u in session.units.values() if belongs(u['id']) and u['branch']['mode']=='candidate' and not any(d['unit_id']==u['id'] for d in decisions)]
    if deferred:
        body += '<details class="unit"><summary>분기 후보 · 아직 미구현</summary><div class="unit-body"><ul>'+''.join('<li>'+heading(u['id'])+'</li>' for u in deferred)+'</ul></div></details>'
    body += '<details class="unit"><summary>공통 분기 규칙 · 동행 · 장비 · 상태 정의</summary><div class="unit-body"><ul>'+''.join('<li>'+esc(note)+'</li>' for note in session.plan['notes'])+'</ul>'
    body += raw({k:session.plan[k] for k in ('party_contract','state_definitions')},'공통 계약과 초기 상태 JSON')+source('/party_contract')+'</div></details>'
    return body


def readable_claims(claims):
    rows=[]
    for claim in claims:
        meta=claim['metadata'];kind=meta['kind'] if meta['addition'] else claim.get('origin','unknown')
        label=LABELS.get(claim['field'],claim['field'])
        value=claim.get('value');kind_label=LABELS.get(kind,kind)
        status_label=LABELS.get(claim.get('status','confirmed'),claim.get('status','confirmed'))
        narrative_fields={'appearance','personality','temperament','voice','goal','story_role','recruitment','conditions','effect','reference_usage','prophecy_testimony','mechanical_scope'}
        long_value=isinstance(value,(dict,list)) or isinstance(value,str) and (len(value)>24 or '\n' in value or claim['field'] in narrative_fields)
        # Unknown/null is already visible as the value. Keep its full provenance
        # in the disclosure instead of repeating "미상" three times in the row.
        badges='' if kind=='unknown' and value is None else '<span class="badge'+(' added' if meta['addition'] else '')+'">'+html.escape(kind_label)+'</span>'
        if badges and status_label!=kind_label:
            badges+='<span class="claim-status">'+html.escape(status_label)+'</span>'
        rows.append('<article class="fact-card'+(' fact-long' if long_value else '')+'" data-field="'+html.escape(claim['field'])+'"><h4>'+html.escape(label)+'</h4><div class="fact-value">'+value_html(value)+'</div>'
                    '<div class="fact-status">'+badges+'</div>'
                    '<details class="fact-evidence"><summary aria-label="'+html.escape(label)+' · 근거와 편집 메모" title="근거와 편집 메모">근거</summary><div class="fact-evidence-body">'
                    '<p>분류: '+html.escape(kind_label)+' · 검토 상태: '+html.escape(status_label)+'</p><p>'+evidence_html(claim.get('evidence',[]))+'</p><p>'+html.escape(meta['note'])+'</p></div></details></article>')
    return '<div class="fact-grid">'+''.join(rows)+'</div>' if rows else '<p class="empty">등록된 정보가 없습니다. 미상을 추정해서 채우지 않습니다.</p>'


def validate_plan(plan=None):
    plan = plan or read(PLAN)
    jsonschema.Draft202012Validator(read(SCHEMA)).validate(plan)
    if [r['id'] for r in plan['navigation']] != list(VIEWS):
        raise ValueError('studio navigation must list each supported view once')
    return {'views':len(VIEWS),'visibility':'author_only','status':'read_only_snapshot'}


def package_path(relative):
    path = (ROOT/relative).resolve()
    if not path.is_relative_to(ROOT.resolve()) or Path(relative).is_absolute():
        raise ValueError('studio reference escapes novel: '+relative)
    return path


def verify_previews():
    manifest = read(PREVIEWS/'manifest.json')
    for relative, digest in manifest['source_sha256'].items():
        if hashlib.sha256(package_path(relative).read_bytes()).hexdigest() != digest:
            raise ValueError('studio input is stale: '+relative+'; run writing.py export')
    docs = {}
    for name, digest in manifest['artifacts'].items():
        if Path(name).name != name: raise ValueError('unsafe preview name')
        path = PREVIEWS/name
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError('studio preview was manually edited: '+name)
        if path.suffix == '.html': docs[name] = path.read_text(encoding='utf-8')
    return docs


def build(docs=None, publication=None, plan=None, side_publication=None):
    plan = plan or read(PLAN)
    validate_plan(plan)
    docs = docs if docs is not None else verify_previews()
    docs = {name:body for name,body in docs.items() if name.endswith('.html')}
    if plan['default_document'] not in docs: raise ValueError('unknown studio default document')
    required = {'chapter01-interactive.html', 'side-adventures.html', 'source-connected.html', 'branch-system.html'}
    if not required <= set(docs): raise ValueError('studio missing required reading documents')
    publication = publication or PublicationFlow()
    core_publication = publication
    from side_stories import SidePublicationFlow, PLAN as SIDE_PLAN, OUTPUT as SIDE_OUTPUT
    publication = side_publication or SidePublicationFlow(base=core_publication.session)
    session = publication.session
    validate_names(session.data)
    esc = html.escape
    display = lambda value: esc(session.display(value))
    macro = read(ROOT/'writing/storyboard/chapter-stories.json')
    stories = {r['chapter_id']:r for r in macro['chapters']}
    stage_labels = {'opening':'시작', 'escalation':'갈등과 진행', 'turning_point':'전환', 'ending':'마무리'}
    chapters = []
    for tree, chart in zip(publication.tree, publication.charts):
        cid = tree['chapter_id']; central = next(c for c in publication.chapters['chapters'] if c['id']==cid)
        story = stories[cid]
        story_html = '<h3>이 장의 질문</h3><p>'+display(story['dramatic_question'])+'</p>'
        story_html += ''.join('<h3>'+label+'</h3><p>'+display(story['story'][key])+'</p>' for key,label in stage_labels.items())
        story_html += '<h3>변화와 다음 장</h3><p>'+display(story['emotional_change'])+'</p><p>'+display(story['handoff']['reason'])+'</p>'
        story_html += '<details><summary>연속성 주의</summary><ul>'+''.join('<li>'+display(v)+'</li>' for v in story['continuity_limits'])+'</ul></details>'
        sides=[s for s in session.stories if s['chapter_id']==cid]
        story_html += '<p class="notice">선택 곁가지 · 창작 초고: '+' / '.join(display(side['title'])+(' · 중첩 선택 포함' if 'approach' in side else '') for side in sides)+'<br>참여/거절과 해결 방법 후 같은 본줄기에 합류하며 후속 반응만 달라집니다. <button type="button" class="button small" data-view="graph" data-graph-panel="rules">분기 내용 보기</button></p>'
        units = []
        for child in tree['children']:
            key = child['unit_id']; unit = session.units[key]
            rule = session.plan['unit_rules'].get(key)
            text = rule['content_override'] if rule and rule['content_override'] is not None else unit['main_content']
            content = '<h4>시작 상황</h4><p>'+display(unit['entry'])+'</p><h4>주요 이야기</h4><p>'+display(text)+'</p>'
            content += '<h4>필수 결과</h4><p>'+display(unit['outcome'])+'</p>'
            if unit.get('logic'):
                content += ''.join('<h4>'+label+'</h4><p>'+display(unit['logic'][field])+'</p>'
                                  for field,label in [('goal','목표'),('obstacle','장애 · 주의'),('next_reason','다음 행동의 이유')])
            content += '<small>필수 사건: '+esc(', '.join(unit['completes_beats']) or '다음 사건으로 연결')+'</small>'
            units.append({**child, 'title':session.display(publication.resolve(child['heading_ref'])), 'html':content,
                          'source_ref':{'file':publication.up,'pointer':publication.unit_paths[key]}})
        chapters.append({'id':cid, 'number':tree['number'], 'title':session.display(publication.resolve(tree['heading_ref'])),
                         'implementation':central['implementation'], 'story_html':story_html, 'units':units,
                         'decisions':[{'id':d['id'],'title':session.display(publication.plan['decision_titles'][d['id']]),'prompt':session.display(d['prompt']),
                                       'source_ref':{'file':publication.bp,'pointer':publication.decision_paths[d['id']]},
                                       'options':[{'id':o['id'],'label':session.display(o['label'])} for o in d['options']]}
                                      for d in session.plan['decisions'] if d['unit_id'].split('/')[0]==cid],
                         'branch_html':chapter_branch_details(publication,cid),
                         'svg':publication.svg(chart['node_ids']), 'source_ref':tree['heading_ref']})
    documents = []
    reading_labels = {
        'chapter01-interactive.html':f'A · 1~{sum(c["implementation"]=="runtime_bound" for c in chapters)}장 초고',
        'chapter01-web.html':'B · '+('1~'+str(len(read(ROOT/'writing/styles.json')['profiles']['B']['written_chapters']))+'장' if len(read(ROOT/'writing/styles.json')['profiles']['B']['written_chapters'])>1 else '1장')+' 초고',
        'novel-reader.html':'A/B 통합 독서 화면',
        'side-adventures.html':'전편 15장 · 곁가지 모험 선택 시범',
        'source-connected.html':'전편 15장 · 원작 원문 연결 판본',
        'first-journey.html':'도입부터 첫 임무 끝까지 · 동행 수락',
        'first-journey-declined.html':'도입부터 첫 임무 끝까지 · 동행 거절',
        'first-journey-tavern.html':'주점 방문 후 첫 임무 · 동행 수락',
        'first-journey-tavern-declined.html':'주점 방문 후 첫 임무 · 동행 거절',
        'prologue.html':'도입부 · 성주 직행',
        'prologue-tavern.html':'도입부 · 주점 방문'
    }
    for name, body in sorted(docs.items()):
        match = re.search(r'<title>(.*?)</title>', body, re.S)
        title = html.unescape(match.group(1)) if match else name
        group = 'prose' if name.startswith(('menace-', 'prologue', 'first-journey')) else 'structure'
        note = '보존 기본 경로 · 초고' if group=='prose' else '작가용 구성 · 상세 본문과 구별'
        if name=='chapter01-interactive.html': group, note = 'interactive', '현재 문체 A로 집필한 본문'
        elif name=='chapter01-web.html':group,note='interactive','빠른 호흡의 B 문체로 재집필한 본문 · 구성과 선택은 A의 동일 장과 공통'
        elif name=='side-adventures.html': group, note = 'interactive', '15장 곁가지 선택판 · 본줄기 기본 경로의 주요 내용 + 창작 모험 초고'
        elif name=='source-connected.html': group, note = 'source', '15장 원문 연결 판본 · 조건부 원문·기술 부록 포함'
        label = reading_labels.get(name,title+(' · 동행 거절 경로' if '-declined' in name else ' · 주점 방문 경로' if '-tavern' in name else ''))
        documents.append({'id':name,'title':title,'label':label,'group':group,'note':note,'source_ref':'writing/previews/'+name,'html':body})
        documents[-1]['reader_edition']=name in ('chapter01-interactive.html','chapter01-web.html')
        documents[-1]['branch_preview']=name=='side-adventures.html'
    names = {key:title_of(p) for key,p in session.profiles['characters'].items()}
    checkpoints = session.profiles['disclosure_checkpoints']
    settings = []
    for key, profile in session.profiles['characters'].items():
        body = character_html(key,profile,names,checkpoints)
        title = profile['display_name'] if '(사칭자)' in profile['display_name'] else names[key]
        settings.append({'id':'characters/'+key, 'category':'characters', 'title':title,
                         'original':profile['canonical_name']['value'] or '', 'html':body,
                         'sections':{'핵심 설정':'<h3>소설용 설정 · 대체값 우선</h3>'+readable_claims(writing_claims(profile))
                                     +readable_claims([profile['biography'][f] for f in ('gender','occupation','alignment')])
                                     +''.join('<h3>'+heading+'</h3>'+readable_claims(profile['writing'][field]) for field,heading in [('speech','말투'),('goals','목표')])
                                     +'<h3>장비·기술 참조</h3>'+value_html(profile['resource_refs']),
                                     '원작 정보':'<h3>원작 이름 · 기존 카드</h3>'+readable_claims([dict(profile['canonical_name'],field='original_name'),profile['korean_name'],*profile['biography'].values()])
                                      +readable_claims(profile['source_facts'])+readable_claims(profile['writing']['traits']),
                                     '관계 · 공개':''.join(relation_html(r,names,checkpoints) for r in profile['relationships'])
                                      +'<h3>공개 정책</h3>'+value_html({'독자에게 보이는 이름':profile['disclosure']['public_display_name'],'공개용 ID':profile['disclosure']['public_id'],'정보가 열리는 사건':profile['disclosure']['after_events']})
                                      +'<details class="fact-evidence"><summary>필드별 상세 공개 조건 · 원본 정책</summary>'+value_html(profile['disclosure'])+'</details>'
                                      +'<h3>집필 경계</h3>'+value_html(profile['writing']['boundaries'])+'<p>'+html.escape(profile['writing']['notes'])+'</p>'},
                         'source_ref':{'file':'characters/registry.json','pointer':'/characters/'+key},
                         'search':names[key]+' '+key+' '+re.sub('<[^>]+>',' ',html.unescape(body))})
    for category, document in session.references.items():
        for key, item in document['items'].items():
            title = item.get('writing_name',item['korean_name'])['value']
            body = claim_table([*([item['writing_name']] if 'writing_name' in item else []),item['original_name'],item['korean_name'],*item['claims']])
            settings.append({'id':category+'/'+key, 'category':category, 'title':title,
                             'original':item['original_name']['value'], 'html':body,
                             'sections':{'설정':readable_claims([*([item['writing_name']] if 'writing_name' in item else []),item['original_name'],item['korean_name'],*item['claims']])},
                             'source_ref':{'file':f'reference/{category}.json','pointer':'/items/'+key},
                             'search':title+' '+key+' '+re.sub('<[^>]+>',' ',html.unescape(body))})
    for key, profile in session.profiles['characters'].items():
        for relation in profile['relationships']:
            # Preserve distinct testimonies/claims between the same people.
            # Only explicitly generated reverse links are duplicates.
            if relation['id'].endswith(':reverse'): continue
            body = relation_html(relation,names,checkpoints)
            title = names[key]+' → '+names[relation['target']]
            settings.append({'id':'relationships/'+relation['id'], 'category':'relationships', 'title':title,
                             'original':relation['relation_type'], 'html':body, 'source_ref':{'file':'characters/registry.json','pointer':'/characters/'+key+'/relationships'},
                             'search':title+' '+re.sub('<[^>]+>',' ',html.unescape(body))})
    for key, item in session.data['terms'].items():
        body = claim_table([item['original_name'],item['korean_name']])
        settings.append({'id':'terms/'+key,'category':'terms','title':item['korean_name']['value'],
                         'original':item['original_name']['value'],'html':body,
                         'source_ref':{'file':'reference/terms.json','pointer':'/items/'+key},'search':key+' '+re.sub('<[^>]+>',' ',html.unescape(body))})
    for key, checkpoint in checkpoints.items():
        body = claim_table([dict(checkpoint,field=key)])
        settings.append({'id':'checkpoints/'+key,'category':'checkpoints','title':key,'original':'편집용 공개 정책', 'html':body,
                         'source_ref':{'file':'characters/registry.json','pointer':'/disclosure_checkpoints/'+key},'search':key+' '+re.sub('<[^>]+>',' ',html.unescape(body))})
    source_paths = ['writing/project.json','writing/reading.json','writing/storyboard/series.json',publication.cp,
                    'writing/storyboard/chapter-stories.json',publication.up,publication.bp,publication.pp,core_publication.bp,core_publication.pp,
                    'writing/storyboard/source-connected.plan.json','writing/storyboard/causal-review.json','writing/interactive/chapter01.json','writing/interactive/episodes.json','writing/interactive/series.json','writing/interactive/prose-presentation.json',
                    'writing/script-overrides/registry.json','writing/covers/manifest.json','writing/ebooks/ebook.plan.json','writing/ebooks/generated/report.json','characters/registry.json','reference/names.json','reference/terms.json','continuity/canon.json',
                    *[f'reference/{key}.json' for key in session.references], PLAN.relative_to(ROOT).as_posix(),
                    *[p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'writing/episodes').glob('*.json'))],
                    *[p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'writing/quests').glob('*.json'))]]
    sources = {path:read(package_path(path)) for path in source_paths}
    sources['writing/publication/generated/flow.graph.json'] = core_publication.graph
    sources['writing/publication/generated/linear-editions.json'] = core_publication.editions
    sources['writing/publication/generated/coverage.json'] = core_publication.report
    sources[SIDE_PLAN.relative_to(ROOT).as_posix()] = publication.session.proposal
    for name in ('runtime.plan.json','flow.plan.json','flow.graph.json','linear-editions.json','coverage.json'):
        sources[(SIDE_OUTPUT/name).relative_to(ROOT).as_posix()] = read(SIDE_OUTPUT/name)
    source_index = [{'file':path, 'role':'생성물 · 직접 편집 금지' if '/generated/' in path else 'JSON 원본 · 파일에서 수정'} for path in sources]
    sources['writing/styles.json']=read(ROOT/'writing/styles.json')
    from prose_variants import SERIES,load_series
    variant_paths=[SERIES.relative_to(ROOT).as_posix(),*[c['file'] for c in load_series()['chapters']]]
    sources.update({path:read(package_path(path)) for path in variant_paths})
    source_index.extend({'file':path,'role':'JSON 원본 · 파일에서 수정'} for path in ['writing/styles.json',*variant_paths])
    graph_details={}
    for node in publication.nodes:
        content_ref=node.get('content_ref') or node.get('question_ref') or node['label_ref']
        rule=publication.resolve(node['guard_ref']) if node.get('guard_ref') else {}
        if node.get('definition_ref'):
            rule=publication.resolve(node['definition_ref'])
        body=session.display(publication.resolve(content_ref))
        if node['kind'] in ('merge','reaction_merge','parallel_merge'):
            body={'merge':'각 선택의 이야기가 이 지점에서 같은 본줄기로 이어집니다.',
                  'reaction_merge':'조건에 맞는 후속 문단을 읽거나 건너뛴 뒤 같은 진행으로 이어집니다.',
                  'parallel_merge':'두 탐색을 모두 완료한 뒤 다음 본줄기로 이어집니다.'}[node['kind']]
        elif node['kind']=='chapter':
            body=session.display(stories[node['chapter_id']]['dramatic_question'])
        graph_details[node['id']]={'label':session.display(node['label_rich_text']),
            'chapter_id':node['chapter_id'],'kind':node['kind'],'location':publication.unit_numbers.get(node['unit_id'],'제'+str(next(c['number'] for c in chapters if c['id']==node['chapter_id']))+'장'),
            'body':body,'source_ref':content_ref,
            'options':[{'id':o['id'],'label':session.display(o['label'])} for o in rule.get('options',[]) if not o['id'].endswith('/bypass')],
            'rules':{k:rule[k] for k in ('when','participants','requires_units','effects','rejoin_before','origin','metadata') if k in rule}}
        if node['kind']=='unit':
            graph_details[node['id']]['logic']={k:session.display(v) for k,v in session.units[node['unit_id']].get('logic',{}).items()}
        if node['kind'] in ('decision','option'):
            did=node['id'].split('/')[1]
            side=session.story_by_decision.get(did) or session.approach_by_decision.get(did)
            if side:
                graph_details[node['id']]['follow_up_unit']=side['reaction_unit']
    data = {'version':1,'status':'draft','visibility':'author_only','source_policy':plan['source_policy'],
            'origin':'authored','metadata':plan['metadata'],'plan':plan,'report':publication.report,
            'chapters':chapters,'documents':documents,'settings':settings,'editions':[*core_publication.editions['editions'],*publication.editions['editions']],
            'overview_svg':publication.svg(publication.graph['overview']), 'sources':sources,'source_index':source_index,'graph_details':graph_details,
            'timeline':{**publication.graph['timeline'],'groups':{gid:{**g,'title':session.display(publication.resolve(g['title_ref'])),
                'prompt':session.display(publication.resolve(g['prompt_ref'])) if g['prompt_ref'] else '',
                'options':[{**o,'label':session.display(publication.resolve(o['label_ref']))} for o in g['options']]}
                for gid,g in publication.graph['timeline']['groups'].items()}},
            'rules':[(ROOT/'AGENTS.md').read_text(encoding='utf-8'),(ROOT/'writing/AGENTS.md').read_text(encoding='utf-8'),(ROOT/'characters/AGENTS.md').read_text(encoding='utf-8')]}
    return data


def document(data):
    # JSON is inert data, including embedded HTML. Never permit a closing script
    # tag from a source caption/document to break into the parent runtime.
    payload = json.dumps(data,ensure_ascii=False,separators=(',',':')).replace('<','\\u003c').replace('>','\\u003e').replace('&','\\u0026').replace('\u2028','\\u2028').replace('\u2029','\\u2029')
    return TEMPLATE.read_text(encoding='utf-8').replace('@@TITLE@@',html.escape(data['plan']['title'])).replace('@@PAYLOAD@@',payload).replace('@@SCRIPT@@',SCRIPT.read_text(encoding='utf-8'))


def export(check=False, output=None, docs=None, publication=None, side_publication=None):
    data = build(docs,publication,side_publication=side_publication)
    output = Path(output or OUTPUT)
    artifacts = {'index.html':document(data)}
    paths = [PLAN,SCHEMA,TEMPLATE,SCRIPT,Path(__file__),ROOT/'tools/export_reference.py',ROOT/'tools/publication_flow.py',
             ROOT/'AGENTS.md',ROOT/'writing/AGENTS.md',ROOT/'characters/AGENTS.md',PREVIEWS/'manifest.json',
             *[package_path(row['source_ref']) for row in data['documents']],
             *[package_path(row['file']) for row in data['source_index']]]
    manifest = {'version':1,'visibility':'author_only','source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
                'artifacts':{name:hashlib.sha256(body.encode()).hexdigest() for name,body in artifacts.items()}}
    path = output/'manifest.json'
    if path.exists():
        previous = read(path)
        for name,digest in previous['artifacts'].items():
            if name not in artifacts or not (output/name).is_file() or hashlib.sha256((output/name).read_bytes()).hexdigest()!=digest:
                raise ValueError('studio output was manually edited; preserve before regeneration: '+name)
    elif any((output/name).exists() for name in artifacts): raise ValueError('studio output exists without manifest')
    if check:
        if not path.exists() or read(path)!=manifest: raise ValueError('studio is stale; run writing.py export')
    else:
        output.mkdir(parents=True,exist_ok=True)
        for name,body in artifacts.items(): (output/name).write_text(body,encoding='utf-8')
        path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return {'output':str(output),'visibility':'author_only','documents':len(data['documents']),'chapters':len(data['chapters']),
            'settings':len(data['settings']),'source_jsons':len(data['sources']),'checked':check}


if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['export','validate'])
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    result = export(check=args.check) if args.action=='export' else {k:v for k,v in build().items() if k in ('version','status','visibility','report')}
    print(json.dumps(result,ensure_ascii=False,indent=2))
