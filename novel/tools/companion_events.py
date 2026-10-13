"""Validate author-only companion join scenes."""
import json

import jsonschema

from materials import ROOT, read

SOURCE = ROOT / 'writing/companion-events/series.json'
SCHEMA = ROOT / 'writing/companion-events/schema.json'


def validate(source=None):
    source = source or read(SOURCE)
    jsonschema.Draft202012Validator(read(SCHEMA)).validate(source)
    characters = read(ROOT / 'characters/registry.json')['characters']
    equipment = read(ROOT / 'reference/equipment.json')['items']
    units = {s['id'] for c in read(ROOT / 'writing/storyboard/chapter-subsections.json')['chapters']
             for s in c['units']}
    expected = {'party_woodcutter', 'party_hunter', 'party_cook', 'party_magician', 'skeleton', 'spica'}
    seen = set()
    for event in source['events']:
        companion = event['companion_ref']['id']
        if companion not in expected or companion in seen:
            raise ValueError('companion event must cover each companion exactly once: ' + companion)
        seen.add(companion)
        if companion not in characters:
            raise ValueError('unknown companion reference: ' + companion)
        item = event['equipment_ref']
        if item is not None and item['id'] not in equipment:
            raise ValueError('unknown equipment reference: ' + item['id'])
        if event['unit_id'] not in units:
            raise ValueError('event is outside the chapter plan: ' + event['unit_id'])
        if event['join_trigger']['state'] not in ('party.members', 'party.optional'):
            raise ValueError('companion event must be join-gated: ' + event['id'])
        if event['main_state_writes']:
            raise ValueError('companion event cannot write main state: ' + event['id'])
        if event['origin'] != 'authored' or event['status'] != 'proposed' or not event['metadata']['addition']:
            raise ValueError('companion event metadata must mark authored additions: ' + event['id'])
    if seen != expected:
        raise ValueError('missing companion event(s): ' + ', '.join(sorted(expected-seen)))
    return {'events': len(source['events']), 'companions': sorted(seen), 'status': 'outline',
            'main_state_writes': 0}
