"""Apply explicit prose layers to the same validated story, never to its graph."""
import copy
import hashlib
import json
import jsonschema
from materials import ROOT, read

STYLES=ROOT/'writing/styles.json'
VARIANT=ROOT/'writing/variants/B/chapter01.json'
SCHEMA=ROOT/'writing/variants/prose.schema.json'
SERIES=ROOT/'writing/variants/B/series.json'
SERIES_SCHEMA=ROOT/'writing/variants/series.schema.json'
BASE_FILES=('writing/quests/prologue.json','writing/quests/lore_menace.json','writing/interactive/chapter01.json')


def structure(story):
    result=copy.deepcopy(story)
    for n in result['nodes']:
        for b in n['blocks']:
            if b['provenance']['origin']=='authored':
                b['text']=[]
                b['provenance']['note']='prose layer'
    return result


def chapter_sources(chapter_id):
    if chapter_id=='chapter01':return BASE_FILES,('prologue/','lore_menace/','i/')
    from interactive_series import PLAN
    part=next((c for c in read(PLAN)['chapters'] if c['chapter_id']==chapter_id),None)
    if part is None:raise ValueError('B chapter has no common written structure')
    return (part['quest_file'],part['continuity_file'],PLAN.relative_to(ROOT).as_posix()),(part['quest_id']+'/',)


def load_series():
    plan=read(SERIES)
    jsonschema.Draft202012Validator(read(SERIES_SCHEMA)).validate(plan)
    expected=['chapter'+str(i+1).zfill(2) for i in range(len(plan['chapters']))]
    if [c['chapter_id'] for c in plan['chapters']]!=expected:
        raise ValueError('B chapters must be a contiguous, unique written prefix')
    if plan['style_revision']!=read(STYLES)['profiles']['B']['revision']:
        raise ValueError('B series style review is stale')
    for c in plan['chapters']:
        if c['file']!='writing/variants/B/'+c['chapter_id']+'.json':
            raise ValueError('B manuscript must use the stable chapter path')
        chapter_sources(c['chapter_id'])
        document=read(ROOT/c['file'])
        if document['chapter_id']!=c['chapter_id'] or document['chapter_limit']!=expected.index(c['chapter_id'])+1:
            raise ValueError('B chapter identity differs from its index')
    return plan


def variant_inputs():
    return [STYLES,SCHEMA,SERIES,SERIES_SCHEMA,*(ROOT/c['file'] for c in load_series()['chapters'])]


def apply_variant(story,document=None,*,validate_result=True):
    from validate_story_authoring import validate
    document=read(VARIANT) if document is None else document
    jsonschema.Draft202012Validator(read(SCHEMA)).validate(document)
    styles=read(STYLES)
    if document['style_revision']!=styles['profiles']['B']['revision']:
        raise ValueError('B style review is stale')
    files,prefixes=chapter_sources(document['chapter_id'])
    expected={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in files}
    if document['base_source_sha256']!=expected:
        raise ValueError('B base prose/structure review is stale')
    result=copy.deepcopy(story)
    blocks={b['id']:b for n in result['nodes'] if n['id'].startswith(prefixes)
            for b in n['blocks'] if b['provenance']['origin']=='authored'}
    if set(blocks)!=set(document['block_overrides']):
        raise ValueError('B must explicitly replace every authored block; no source or unknown blocks')
    for key,override in document['block_overrides'].items():
        block=blocks[key]
        if block['provenance']['source_refs']!=override['provenance']['source_refs']:
            raise ValueError('B may not change a block source scope')
        block['text']=copy.deepcopy(override['text'])
        block['provenance']=copy.deepcopy(override['provenance'])
    if structure(result)!=structure(story):raise ValueError('B may not change the common story graph')
    if validate_result:validate(result)
    return result


def compile_variant(chapter_limit=None):
    from interactive_series import compile_series
    from story_continuity import validate, CANON
    from interactive import validate_main_story
    plan=load_series()
    count=len(plan['chapters']) if chapter_limit is None else chapter_limit
    if not isinstance(count,int) or isinstance(count,bool) or not 1<=count<=len(plan['chapters']):
        raise ValueError('unknown written B chapter limit')
    story,memory,overlay=compile_series(chapter_limit=count)
    for chapter in plan['chapters'][:count]:
        story=apply_variant(story,read(ROOT/chapter['file']),validate_result=False)
    validate(story,memory,read(CANON))
    validate_main_story(story,memory,overlay['main_story'])
    scope=f'1~{count}장' if count>1 else '1장'
    overlay['scope']=f'B · 실제 재집필한 {scope}. {count+1}장 이후는 B 미집필이며 A로 자동 대체하지 않는다.'
    return story,memory,overlay


def validate_profiles():
    styles=read(STYLES)
    if styles['default_profile']!='A' or set(styles['profiles'])!={'A','B'}:
        raise ValueError('exactly two shared styles are required')
    a=styles['profiles']['A']
    if a['definition_ref']!='project.json#/style':raise ValueError('A must refer to the existing style')
    from interactive_series import PLAN
    chapters=['chapter01',*[c['chapter_id'] for c in read(PLAN)['chapters']]]
    plan=load_series()
    written=[c['chapter_id'] for c in plan['chapters']]
    if a['written_chapters']!=chapters or styles['profiles']['B']['written_chapters']!=written:
        raise ValueError('style chapter availability differs from written prose')
    story,_,_=compile_variant()
    return {'profiles':['A','B'],'A_chapters':len(chapters),'B_chapters':len(written),
            'shared_graph':True,'B_authored_blocks':sum(len(read(ROOT/c['file'])['block_overrides']) for c in plan['chapters']),
            'source_quotes_unchanged':True,'status':'draft'}


from interactive_series import SeriesSession


class VariantSession(SeriesSession):
    """Reuse the common forward-only replay, party constraints and save checks."""
    def __init__(self,chapter_limit=None):
        from story_continuity import CANON,context_for_routes
        self.story,self.memory,self.overlay=compile_variant(chapter_limit)
        self.packet_for=context_for_routes(self.story,self.memory,read(CANON))


if __name__=='__main__':print(json.dumps(validate_profiles(),ensure_ascii=False,indent=2))
