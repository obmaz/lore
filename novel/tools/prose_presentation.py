"""Bind novel-facing speech and narrative to immutable source blocks, not a new graph."""
import copy
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
    return {'revision':document['revision'],'policy':copy.deepcopy(document['policy']),
            'groups':groups,'dialogues':dialogues}
