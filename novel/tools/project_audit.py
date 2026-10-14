"""Classify package files and record observable internal consumers, not runtime proof."""
import argparse
import ast
import json
from collections import Counter

from materials import ROOT, read

OUTPUT=ROOT/'docs/project-map.json'


def classify(path):
    if path=='docs/project-map.json':return 'generated_inventory'
    if path.endswith('AGENTS.md'):return 'agent_policy'
    if path.endswith('README.md'):return 'usage_documentation'
    if path.endswith('.schema.json'):return 'schema'
    if path.startswith('authoring/examples/'):return 'verification_example'
    if path.startswith('writing/templates/'):return 'shared_template'
    if path.startswith('writing/covers/') and path.endswith('.jpg'):return 'authored_cover_asset'
    if path.startswith('materials/'):return 'immutable_source_snapshot'
    if path in ('characters/registry.json','reference/equipment.json','reference/abilities.json','reference/bestiary.json','reference/generated_manifest.json'):return 'compiled_reference'
    if path.startswith(('exports/','writing/previews/','writing/source-connected/')) or '/generated/' in path:return 'generated_reading'
    if path.startswith('tools/'):return 'tool'
    if path.startswith('tests/'):return 'test'
    if path in ('requirements.txt','.gitignore','writing/studio/publication.json'):return 'configuration'
    if path.startswith(('writing/interactive/','writing/studio/','writing/side-stories/','writing/ebooks/')) and path.endswith(('.js','.html')):return 'ui_source'
    if path.endswith('.json') and path.startswith(('reference/','characters/','continuity/','writing/')):return 'editable_authoring_input'
    return 'unclassified'


def audit():
    paths=sorted(set(p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*') if p.is_file()
                     and not any(s in ('__pycache__','.git') for s in p.parts) and p.suffix not in ('.pyc','.pyo'))|{'docs/project-map.json'})
    consumers={path:[] for path in paths}
    def add(path,kind,owner):
        row={'kind':kind,'file':owner}
        if path in consumers and row not in consumers[path]:consumers[path].append(row)
    for name in ('materials/manifest.json','reference/generated_manifest.json','exports/manifest.json','writing/previews/manifest.json','writing/publication/generated/manifest.json','writing/side-stories/generated/manifest.json','writing/studio/generated/manifest.json','writing/ebooks/generated/manifest.json'):
        if not (ROOT/name).is_file():continue
        document=read(ROOT/name)
        for path in document.get('source_sha256',{}):add(path,'input_hash_guard',name)
        base=ROOT if name=='reference/generated_manifest.json' else (ROOT/name).parent
        for path in document.get('artifacts',{}):add(base.joinpath(path).relative_to(ROOT).as_posix(),'output_hash_guard',name)
    for source in paths:
        path=ROOT/source
        if not path.is_file() or not source.endswith(('.md','.py','.schema.json')):continue
        text=path.read_text(encoding='utf-8')
        for target in paths:
            if target!=source and (target in text or (ROOT/target).name in text):add(target,'static_mention_not_runtime_proof',source)
        if source.endswith('.py'):
            for node in ast.walk(ast.parse(text)):
                names=[node.module] if isinstance(node,ast.ImportFrom) else [a.name for a in node.names] if isinstance(node,ast.Import) else []
                for name in names:
                    if name:add('tools/'+name+'.py','python_import',source)
    rows=[]
    for path in paths:
        role=classify(path)
        if role=='test':add(path,'test_discovery','python -m unittest discover -s tests')
        if role=='tool' and '__main__' in (ROOT/path).read_text(encoding='utf-8'):add(path,'cli_entrypoint',path)
        if role=='generated_inventory':add(path,'inventory_output','tools/project_audit.py')
        rows.append({'file':path,'role':role,'consumers':consumers[path],'automatic_deletion':False})
    return {'version':1,'origin':'authored','metadata':{'addition':True,'kind':'new_setting','note':'추가: 관리용 파일 역할과 관찰된 소비자 지도. 정적 언급·해시 확인만으로 모든 런타임 접근이나 삭제 가능성을 증명하지 않는다.','knowledge_policy':'author_reference_not_character_knowledge'},
            'source_policy':{'external_game_required':False,'full_original_text':'materials/scripts.json#/source_units/*/original_source','source_file_fields':'internal_origin_keys'},
            'counts':dict(sorted(Counter(r['role'] for r in rows).items())),
            'cleanup':{'preserved_examples':'authoring/examples/','old_example_location':'authoring/drafts/','deleted_original_materials':[]},
            'unclassified':[r['file'] for r in rows if r['role']=='unclassified'],'review_required':[r['file'] for r in rows if not r['consumers']], 'files':rows}


def export(check=False):
    data=audit()
    if data['unclassified']:raise ValueError('unclassified project files: '+', '.join(data['unclassified']))
    body=json.dumps(data,ensure_ascii=False,indent=2)+'\n'
    if check:
        if not OUTPUT.is_file() or OUTPUT.read_text(encoding='utf-8')!=body:raise ValueError('project map is stale; run project_audit.py export')
    else:
        OUTPUT.parent.mkdir(parents=True,exist_ok=True);OUTPUT.write_text(body,encoding='utf-8')
    return {'files':len(data['files']),'counts':data['counts'],'review_required':data['review_required'],'checked':check}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['export','validate']);parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    print(json.dumps(export(args.check) if args.action=='export' else audit(),ensure_ascii=False,indent=2))
