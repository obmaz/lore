"""Apply explicit prose layers to the same validated story, never to its graph."""
import copy
import hashlib
import json
import jsonschema
from materials import ROOT, read

STYLES=ROOT/'writing/styles.json'
VARIANT=ROOT/'writing/variants/B/chapter01.json'
SCHEMA=ROOT/'writing/variants/prose.schema.json'
BASE_FILES=('writing/quests/prologue.json','writing/quests/lore_menace.json','writing/interactive/chapter01.json')


def structure(story):
    result=copy.deepcopy(story)
    for n in result['nodes']:
        for b in n['blocks']:
            if b['provenance']['origin']=='authored':
                b['text']=[]
                b['provenance']['note']='prose layer'
    return result


def apply_variant(story,document=None):
    from validate_story_authoring import validate
    document=read(VARIANT) if document is None else document
    jsonschema.Draft202012Validator(read(SCHEMA)).validate(document)
    styles=read(STYLES)
    if document['style_revision']!=styles['profiles']['B']['revision']:
        raise ValueError('B style review is stale')
    expected={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in BASE_FILES}
    if document['base_source_sha256']!=expected:
        raise ValueError('B base prose/structure review is stale')
    result=copy.deepcopy(story)
    blocks={b['id']:b for n in result['nodes'] for b in n['blocks'] if b['provenance']['origin']=='authored'}
    if set(blocks)!=set(document['block_overrides']):
        raise ValueError('B must explicitly replace every authored block; no source or unknown blocks')
    for key,override in document['block_overrides'].items():
        block=blocks[key]
        if block['provenance']['source_refs']!=override['provenance']['source_refs']:
            raise ValueError('B may not change a block source scope')
        block['text']=copy.deepcopy(override['text'])
        block['provenance']=copy.deepcopy(override['provenance'])
    if structure(result)!=structure(story):raise ValueError('B may not change the common story graph')
    validate(result)
    return result


def compile_variant():
    from interactive_series import compile_series
    from story_continuity import validate, CANON
    from interactive import validate_main_story
    story,memory,overlay=compile_series(chapter_limit=1)
    story=apply_variant(story)
    validate(story,memory,read(CANON))
    validate_main_story(story,memory,overlay['main_story'])
    overlay['scope']='B · 실제 재집필한 1장. 2장 이후는 B 미집필이며 A로 자동 대체하지 않는다.'
    return story,memory,overlay


def validate_profiles():
    styles=read(STYLES)
    if styles['default_profile']!='A' or set(styles['profiles'])!={'A','B'}:
        raise ValueError('exactly two shared styles are required')
    a=styles['profiles']['A']
    if a['definition_ref']!='project.json#/style':raise ValueError('A must refer to the existing style')
    from interactive_series import PLAN
    chapters=['chapter01',*[c['chapter_id'] for c in read(PLAN)['chapters']]]
    if a['written_chapters']!=chapters or styles['profiles']['B']['written_chapters']!=['chapter01']:
        raise ValueError('style chapter availability differs from written prose')
    story,_,_=compile_variant()
    return {'profiles':['A','B'],'A_chapters':len(chapters),'B_chapters':1,
            'shared_graph':True,'B_authored_blocks':len(read(VARIANT)['block_overrides']),
            'source_quotes_unchanged':True,'status':'draft'}


if __name__=='__main__':print(json.dumps(validate_profiles(),ensure_ascii=False,indent=2))
