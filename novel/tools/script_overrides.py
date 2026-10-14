"""Resolve a novel-only script layer while preserving archived source occurrences."""
import copy
import hashlib
import jsonschema
from materials import ROOT, read
from text_refs import source_ids, archival, validate_text, reject_fixed_names

PLAN=ROOT/'writing/script-overrides/registry.json'
SCHEMA=ROOT/'writing/script-overrides/overrides.schema.json'


def compile_overrides(story, groups, data, all_literals, document=None):
    document=read(PLAN) if document is None else document
    jsonschema.Draft202012Validator(read(SCHEMA)).validate(document)
    blocks={b['id']:b for n in story['nodes']for b in n['blocks']}
    group_index={g['block_ids'][0]:g for g in groups}
    namespaces={n['id'].split('/')[0]for n in story['nodes']}
    result={}
    for key,entry in document['overrides'].items():
        if key.split('/')[0] not in namespaces:continue
        group=group_index.get(key)
        if not group or entry['source_block_ids']!=group['block_ids']:
            raise ValueError('script override: unknown group or changed source scope')
        ids=[i for block in entry['source_block_ids']for i in source_ids(blocks[block]['text'])]
        original=''.join(archival(blocks[block]['text'],all_literals)for block in entry['source_block_ids'])
        if ids!=entry['source_literal_ids'] or hashlib.sha256(original.encode()).hexdigest()!=entry['source_sha256']:
            raise ValueError('script override: source review is stale')
        text=entry['writing_overrides']['text']
        if text is not None:
            validate_text(text,data,all_literals)
            reject_fixed_names(text,data)
            if any(word in ''.join(s.get('text','')for s in text)for word in ['게임','프로그래머','(Y/n)']):
                raise ValueError('script override: game terminology remains in novel text')
        result[key]=copy.deepcopy(entry)
    return result
