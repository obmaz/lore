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
from export_reference import character_html, claim_table, relation_html, title_of, value_html, LABELS, evidence_html
from text_refs import validate_names

PLAN = ROOT/'writing/studio/studio.plan.json'
SCHEMA = ROOT/'writing/studio/studio.schema.json'
TEMPLATE = ROOT/'writing/studio/shell.html'
SCRIPT = ROOT/'writing/studio/studio.js'
OUTPUT = ROOT/'writing/studio/generated'
PREVIEWS = ROOT/'writing/previews'
VIEWS = ('overview', 'reading', 'outline', 'graph', 'branches', 'order', 'settings', 'sources')


def readable_claims(claims):
    rows=[]
    for claim in claims:
        meta=claim['metadata'];kind=meta['kind'] if meta['addition'] else claim.get('origin','unknown')
        label=LABELS.get(claim['field'],claim['field'])
        rows.append('<article class="fact-card"><h4>'+html.escape(label)+'</h4><div class="fact-value">'+value_html(claim.get('value'))+'</div>'
                    '<div class="fact-status"><span class="badge'+(' added' if meta['addition'] else '')+'">'+html.escape(LABELS.get(kind,kind))+'</span> '
                    +html.escape(LABELS.get(claim.get('status','confirmed'),claim.get('status','confirmed')))+'</div>'
                    '<details class="fact-evidence"><summary>근거와 편집 메모</summary><p>'+evidence_html(claim.get('evidence',[]))+'</p><p>'+html.escape(meta['note'])+'</p></details></article>')
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


def build(docs=None, publication=None, plan=None):
    plan = plan or read(PLAN)
    validate_plan(plan)
    docs = docs if docs is not None else verify_previews()
    docs = {name:body for name,body in docs.items() if name.endswith('.html')}
    if plan['default_document'] not in docs: raise ValueError('unknown studio default document')
    required = {'chapter01-interactive.html', 'source-connected.html', 'branch-system.html', 'first-journey.html'}
    if not required <= set(docs): raise ValueError('studio missing required reading documents')
    publication = publication or PublicationFlow()
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
        units = []
        for child in tree['children']:
            key = child['unit_id']; unit = session.units[key]
            rule = session.plan['unit_rules'].get(key)
            text = rule['content_override'] if rule and rule['content_override'] is not None else unit['main_content']
            content = '<h4>시작 상황</h4><p>'+display(unit['entry'])+'</p><h4>주요 이야기</h4><p>'+display(text)+'</p>'
            content += '<h4>필수 결과</h4><p>'+display(unit['outcome'])+'</p>'
            content += '<small>필수 사건: '+esc(', '.join(unit['completes_beats']) or '다음 사건으로 연결')+'</small>'
            units.append({**child, 'title':session.display(publication.resolve(child['heading_ref'])), 'html':content,
                          'source_ref':{'file':publication.up,'pointer':publication.unit_paths[key]}})
        chapters.append({'id':cid, 'number':tree['number'], 'title':session.display(publication.resolve(tree['heading_ref'])),
                         'implementation':central['implementation'], 'story_html':story_html, 'units':units,
                         'decisions':[{'id':d['id'],'title':session.display(publication.plan['decision_titles'][d['id']]),'prompt':session.display(d['prompt']),
                                       'source_ref':{'file':publication.bp,'pointer':publication.decision_paths[d['id']]},
                                       'options':[{'id':o['id'],'label':session.display(o['label'])} for o in d['options']]}
                                      for d in session.plan['decisions'] if d['unit_id'].split('/')[0]==cid],
                         'svg':publication.svg(chart['node_ids']), 'source_ref':tree['heading_ref']})
    documents = []
    reading_labels = {
        'chapter01-interactive.html':'첫 장 · 최신 선택형 초고',
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
        if name=='chapter01-interactive.html': group, note = 'interactive', '최신 첫 장 선택형 초고 · 전편 분기와 별도'
        elif name=='source-connected.html': group, note = 'source', '15장 원문 연결 판본 · 조건부 원문·기술 부록 포함'
        label = reading_labels.get(name,title+(' · 동행 거절 경로' if '-declined' in name else ' · 주점 방문 경로' if '-tavern' in name else ''))
        documents.append({'id':name,'title':title,'label':label,'group':group,'note':note,'source_ref':'writing/previews/'+name,'html':body})
    names = {key:title_of(p) for key,p in session.profiles['characters'].items()}
    checkpoints = session.profiles['disclosure_checkpoints']
    settings = []
    for key, profile in session.profiles['characters'].items():
        body = character_html(key,profile,names,checkpoints)
        title = profile['display_name'] if '(사칭자)' in profile['display_name'] else names[key]
        settings.append({'id':'characters/'+key, 'category':'characters', 'title':title,
                         'original':profile['canonical_name']['value'] or '', 'html':body,
                         'sections':{'핵심 설정':readable_claims([*([profile['writing_name']] if 'writing_name' in profile else []),profile['korean_name'],*profile['biography'].values()])
                                     +''.join('<h3>'+heading+'</h3>'+readable_claims(profile['writing'][field]) for field,heading in [('traits','성향'),('speech','말투'),('goals','목표')])
                                     +'<h3>장비·기술 참조</h3>'+value_html(profile['resource_refs']),
                                     '원작 정보':readable_claims(profile['source_facts']),
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
                    'writing/storyboard/chapter-stories.json',publication.up,publication.bp,publication.pp,
                    'writing/storyboard/source-connected.plan.json','writing/interactive/chapter01.json',
                    'characters/registry.json','reference/names.json','reference/terms.json','continuity/canon.json',
                    *[f'reference/{key}.json' for key in session.references], PLAN.relative_to(ROOT).as_posix(),
                    *[p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'writing/episodes').glob('*.json'))],
                    *[p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'writing/quests').glob('*.json'))]]
    sources = {path:read(package_path(path)) for path in source_paths}
    sources['writing/publication/generated/flow.graph.json'] = publication.graph
    sources['writing/publication/generated/linear-editions.json'] = publication.editions
    sources['writing/publication/generated/coverage.json'] = publication.report
    source_index = [{'file':path, 'role':'생성물 · 직접 편집 금지' if '/generated/' in path else 'JSON 원본 · 파일에서 수정'} for path in sources]
    data = {'version':1,'status':'draft','visibility':'author_only','source_policy':plan['source_policy'],
            'origin':'authored','metadata':plan['metadata'],'plan':plan,'report':publication.report,
            'chapters':chapters,'documents':documents,'settings':settings,'editions':publication.editions['editions'],
            'overview_svg':publication.svg(publication.graph['overview']), 'sources':sources,'source_index':source_index,
            'rules':[(ROOT/'AGENTS.md').read_text(encoding='utf-8'),(ROOT/'writing/AGENTS.md').read_text(encoding='utf-8'),(ROOT/'characters/AGENTS.md').read_text(encoding='utf-8')]}
    return data


def document(data):
    # JSON is inert data, including embedded HTML. Never permit a closing script
    # tag from a source caption/document to break into the parent runtime.
    payload = json.dumps(data,ensure_ascii=False,separators=(',',':')).replace('<','\\u003c').replace('>','\\u003e').replace('&','\\u0026').replace('\u2028','\\u2028').replace('\u2029','\\u2029')
    return TEMPLATE.read_text(encoding='utf-8').replace('@@TITLE@@',html.escape(data['plan']['title'])).replace('@@PAYLOAD@@',payload).replace('@@SCRIPT@@',SCRIPT.read_text(encoding='utf-8'))


def export(check=False, output=None, docs=None, publication=None):
    data = build(docs,publication)
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
