"""Bind novel-facing speech and narrative to immutable source blocks, not a new graph."""
import copy
import re
import jsonschema

from materials import ROOT, read
from text_refs import validate_text, reject_fixed_names

PLAN = ROOT/'writing/interactive/prose-presentation.json'
SCHEMA = ROOT/'writing/interactive/presentation.schema.json'


def compile_presentation(story, data, all_literals, document=None):
    document = read(PLAN) if document is None else document
    jsonschema.Draft202012Validator(read(SCHEMA)).validate(document)
    nodes = {n['id']:n for n in story['nodes']}
    states = story['state_definitions']
    blocks = {b['id']:b for n in story['nodes'] for b in n['blocks']}
    groups, dialogues, seen = [], {}, set()
    # Short written prefixes may be compiled for authoring tests. A later chapter
    # is allowed only when its whole namespace is outside the compiled story.
    namespaces = {key.split('/')[0] for key in nodes}
    def present(key):
        return key in nodes or key.split('/')[0] in namespaces

    def check_editions(editions):
        for edition in editions.values():
            for spans in edition.values():
                plain = [s for s in spans if 'state' not in s]
                validate_text(plain, data, all_literals)
                reject_fixed_names(plain, data)
                for span in spans:
                    if 'state' not in span:continue
                    definition = states.get(span['state'])
                    if not definition:raise ValueError('presentation: unknown state')
                    if span.get('catalog'):
                        if definition['type']!='string':raise ValueError('presentation: actor state must be a string')
                    elif definition['type']!='integer' or span.get('particle'):
                        raise ValueError('presentation: only numeric state or referenced actors may be displayed')

    for group in document['groups']:
        if not present(group['node']):continue
        if group['node'] not in nodes:raise ValueError('presentation: unknown node')
        ids = group['block_ids']
        sequence = nodes[group['node']]['blocks']
        positions = [i for i,b in enumerate(sequence) if b['id'] in ids]
        if not positions or [sequence[i]['id'] for i in positions]!=ids or positions!=list(range(positions[0],positions[0]+len(ids))):
            raise ValueError('presentation: source group must be contiguous and ordered')
        selected = [blocks[key] for key in ids]
        if any(b['provenance']['origin']!='source_exact' for b in selected):
            raise ValueError('presentation: source group may only bind immutable source blocks')
        if any(b['when']!=selected[0]['when'] or b['speaker']!=selected[0]['speaker'] for b in selected):
            raise ValueError('presentation: cannot merge distinct conditions or speakers')
        if seen.intersection(ids):raise ValueError('presentation: duplicate source binding')
        seen.update(ids)
        if group['provenance']['source_block_ids']!=ids:raise ValueError('presentation: changed source scope')
        expected_origin = 'source_adaptation' if group['kind']=='narration' else 'authored'
        if group['provenance']['origin']!=expected_origin:raise ValueError('presentation: adaptation must be marked')
        if any(('body' in edition)!=(group['kind']=='narration') for edition in group['editions'].values()):
            raise ValueError('presentation: speech and inscriptions must preserve source text')
        check_editions(group['editions'])
        groups.append(copy.deepcopy(group))
    required = {key for key,b in blocks.items() if b['provenance']['origin']=='source_exact'}
    if seen!=required:raise ValueError('presentation: unmapped original source blocks')
    for key,entry in document['dialogues'].items():
        if key.split('/')[0] not in namespaces:continue
        block = blocks.get(key)
        if not block or block['provenance']['origin']!='authored' or entry['speaker']!=block['speaker']:
            raise ValueError('presentation: unknown or changed dialogue speaker')
        if entry['provenance']['origin']!='authored' or entry['provenance']['source_block_ids']!=[key]:
            raise ValueError('presentation: dialogue attribution must be marked')
        if any('body' in e for e in entry['editions'].values()):raise ValueError('presentation: cannot replace authored dialogue')
        check_editions(entry['editions'])
        dialogues[key] = copy.deepcopy(entry)
    if set(dialogues)!={key for key,b in blocks.items() if b['speaker'] and b['provenance']['origin']=='authored'}:
        raise ValueError('presentation: unmapped dialogue speakers')
    from script_overrides import compile_overrides
    replacements=compile_overrides(story,groups,data,all_literals)
    return {'revision':document['revision'],'policy':copy.deepcopy(document['policy']),
            'groups':groups,'dialogues':dialogues,'script_overrides':replacements}


def display_text(spans, state, payload, block_id=None):
    """Python counterpart of reader text(); verified against the actual browser."""
    from text_refs import particle
    def reference(ref):
        name=payload['labels'][ref['catalog']][ref['id']]
        return name+(particle(name,ref['particle'])if ref.get('particle')else '')
    if isinstance(spans,str):return spans
    result=[]
    for span in spans:
        if 'text' in span:result.append(span['text'])
        elif 'ref' in span:result.append(reference(span['ref']))
        elif 'state' in span:
            value=state[span['state']]
            result.append(reference({'catalog':span['catalog'],'id':value,**({'particle':span['particle']}if span.get('particle')else {})})if span.get('catalog')else str(value))
        else:
            source=span['source']
            raw=''.join(payload['literals'][i]for i in source['literal_ids'])
            edits=[(b['start'],b['end'],reference(b['ref']))for b in source['bindings']]
            for item in payload['insertions'].get(block_id,[]):
                if 'ref' in item:value=reference(item['ref'])
                elif 'state' in item:
                    value=state[item['state']]
                    value=reference({'catalog':item['state_ref_catalog'],'id':value,**({'particle':item['particle']}if item.get('particle')else {})})if item.get('state_ref_catalog')else str(value)
                else:value='['+item['placeholder']+']'
                edits.append((item['offset'],item['offset']+item.get('replace_length',0),value))
            offset=0;pieces=[]
            for start,end,value in sorted(edits,key=lambda e:(e[0],e[1])):
                pieces.extend([raw[offset:start],value]);offset=end
            result.append(''.join(pieces)+raw[offset:])
    return ''.join(result)


def section_paragraphs(node, visible_ids, state, payload):
    """Render just one already-replayed section, without subtitles or UI labels."""
    presentation=payload['presentation'];edition=payload['edition']
    groups={key:g for g in presentation['groups']for key in g['block_ids']}
    blocks={b['id']:b for b in node['blocks']}
    visible=set(visible_ids);paragraphs=[]
    quoted=lambda t:t.strip()if t.strip().startswith('“')and t.strip().endswith('”')else '“'+t.strip()+'”'
    for block in node['blocks']:
        if block['id'] not in visible or block['kind']=='author_note':continue
        key=block['id'];ids=[]
        if block['provenance']['origin']=='source_exact':
            group=groups[key]
            if key!=group['block_ids'][0]:continue
            ids=group['block_ids']
            if not set(ids)<=visible:raise ValueError('ebook: source group is partly hidden')
            rule=group['editions'][edition]
            replacement=presentation['script_overrides'].get(key,{}).get('writing_overrides',{}).get('text')
            if replacement is not None:content=display_text(replacement,state,payload)
            elif group['kind']=='narration':content=display_text(rule['body'],state,payload)
            else:
                sep=' 'if group['kind']=='inscription'else ''
                content=re.sub(r'\s+',' ',sep.join(display_text(blocks[i]['text'],state,payload,i)for i in ids)).strip()
            body=content if group['kind']=='narration'else quoted(content)
            body=display_text(rule['before'],state,payload)+body+display_text(rule['after'],state,payload)
        else:
            body=display_text(block['text'],state,payload,key)
            if block['speaker']:
                rule=presentation['dialogues'][key]['editions'][edition]
                body=display_text(rule['before'],state,payload)+quoted(body)+display_text(rule['after'],state,payload)
        paragraphs.extend({'block_id':key,'source_block_ids':ids,'text':p}for p in re.split(r'\n{2,}',body)if p.strip())
    return paragraphs
