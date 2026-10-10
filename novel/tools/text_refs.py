"""Structured prose references. Immutable source text and renameable display are separate."""
import re

from materials import ROOT, load_materials, read
from disclosure import project_character
from reference import validate_claim, schema_validator


def load_terms(catalog=None):
    data = read(ROOT/'reference/terms.json')
    schema_validator(ROOT/'reference/terms.schema.json').validate(data)
    for item in data['items'].values():
        validate_claim(item['original_name'],catalog)
        validate_claim(item['korean_name'],catalog)
    return data


def indexes(profiles,references,catalog=None):
    return {'characters':profiles['characters'],**{c:d['items'] for c,d in references.items()},
            'terms':load_terms(catalog)['items']}


def validate_names(data):
    """Do not render a stale compiled alias after its single edit source changes."""
    names = read(ROOT/'reference/names.json')
    schema_validator(ROOT/'reference/names.schema.json').validate(names)
    for category in ('characters','equipment','abilities','bestiary'):
        compiled = {key:item['writing_name'] for key,item in data[category].items() if 'writing_name' in item}
        if names[category]!=compiled:
            raise ValueError('compiled writing names are stale; run tools/build_reference.py: '+category)


def literals(catalog=None):
    return {l['id']:l for u in (catalog or load_materials()[0])['source_units'] for l in u['literals']}


def name_of(item):
    return (item.get('writing_name',{}).get('value') or item.get('korean_name',{}).get('value')
            or item.get('display_name') or item.get('original_name',{}).get('value'))


def particle(name,pair):
    if not name:
        raise ValueError('empty reference display name')
    tail = ord(name[-1])-0xAC00
    if not 0<=tail<11172:
        raise ValueError('Korean particle needs a Hangul ending; write an explicit grammatical phrase')
    jong = tail%28
    first,second = pair.split('/')
    return first if jong and not (pair=='으로/로' and jong==8) else second


def resolve(ref,data,profiles=None,reveals=(),author=False):
    catalog,key = ref['catalog'],ref['id']
    if catalog not in data or key not in data[catalog]:
        raise ValueError(f'unknown text reference: {catalog}/{key}')
    if catalog=='characters' and not author:
        if profiles is None:
            raise ValueError('reader reference needs disclosure context')
        item = project_character(profiles,key,reveals)
        name = item.get('writing_name',{}).get('value') or item['display_name']
        # Use the phonetic Korean label instead of legacy English editorial titles.
        if 'writing_name' not in item and item['korean_name']:
            name = item['korean_name']
    else:
        name = name_of(data[catalog][key])
    if not isinstance(name,str) or not name:
        raise ValueError(f'unnamed reference: {catalog}/{key}')
    return name+(particle(name,ref['particle']) if 'particle' in ref else '')


def source_text(source,all_literals):
    try:
        return ''.join(all_literals[i]['text'] for i in source['literal_ids'])
    except KeyError as error:
        raise ValueError(f'unknown source literal: {error.args[0]}') from error


def archival(text,all_literals):
    if isinstance(text,str):
        return text
    result = ''
    for span in text:
        if 'text' in span:
            result += span['text']
        elif 'source' in span:
            result += source_text(span['source'],all_literals)
        else:
            raise ValueError('exact source quotation cannot contain a free-standing name reference')
    return result


def refs_in(text):
    if isinstance(text,str):
        return []
    return [span['ref'] for span in text if 'ref' in span]+[
        b['ref'] for span in text if 'source' in span for b in span['source']['bindings']]


def source_ids(text):
    if isinstance(text,str):
        return []
    return [i for span in text if 'source' in span for i in span['source']['literal_ids']]


def validate_text(text,data,all_literals,require_bindings=False):
    for ref in refs_in(text):
        resolve(ref,data,author=True)
    if isinstance(text,str):
        return
    for span in text:
        if 'source' not in span:
            continue
        source = span['source']
        raw = source_text(source,all_literals)
        positions = [(all_literals[i]['source']['file'],all_literals[i]['source']['offset_start']) for i in source['literal_ids']]
        if len({p[0] for p in positions})!=1 or any(a[1]>=b[1] for a,b in zip(positions,positions[1:])):
            raise ValueError('source fragments must preserve original file and occurrence order')
        previous = 0
        for binding in source['bindings']:
            start,end = binding['start'],binding['end']
            if not previous<=start<end<=len(raw):
                raise ValueError('overlapping or invalid source name binding')
            item = data[binding['ref']['catalog']][binding['ref']['id']]
            canonical = item.get('canonical_name',item.get('original_name',{})).get('value')
            aliases = {canonical,item.get('korean_name',{}).get('value')}
            if raw[start:end] not in aliases or 'particle' in binding['ref']:
                raise ValueError('source name binding does not match original entity name')
            previous = end
        if require_bindings:
            labels = {name for items in data.values() for item in items.values()
                      for name in (item.get('canonical_name',item.get('original_name',{})).get('value'),
                                   item.get('korean_name',{}).get('value'))
                      if isinstance(name,str) and len(name)>=2}
            for name in labels:
                pattern = re.escape(name) if not name.isascii() else r'(?<![A-Za-z])'+re.escape(name)+r'(?![A-Za-z])'
                for hit in re.finditer(pattern,raw):
                    if not any(b['start']<=hit.start() and hit.end()<=b['end'] for b in source['bindings']):
                        raise ValueError('unbound source entity name; add a display reference: '+name)


def render(text,data,all_literals,profiles=None,reveals=(),author=False):
    validate_text(text,data,all_literals)
    if isinstance(text,str):
        return text
    result = ''
    for span in text:
        if 'text' in span:
            result += span['text']
        elif 'ref' in span:
            result += resolve(span['ref'],data,profiles,reveals,author)
        else:
            source = span['source']
            raw = source_text(source,all_literals)
            cursor = 0
            for b in source['bindings']:
                result += raw[cursor:b['start']]+resolve(b['ref'],data,profiles,reveals,author)
                cursor = b['end']
            result += raw[cursor:]
    return result


def reject_fixed_names(text,data):
    """New authored prose must not duplicate mutable labels; source records are exempt."""
    plain = text if isinstance(text,str) else ''.join(s['text'] for s in text if 'text' in s)
    for catalog in data.values():
        for item in catalog.values():
            labels = {item.get('writing_name',{}).get('value'),item.get('korean_name',{}).get('value'),
                      item.get('canonical_name',item.get('original_name',{})).get('value')}
            for name in labels:
                if not isinstance(name,str) or len(name)<2:
                    continue
                pattern = re.escape(name) if not name.isascii() else r'(?<![A-Za-z])'+re.escape(name)+r'(?![A-Za-z])'
                if re.search(pattern,plain):
                    raise ValueError(f'fixed entity name in new prose; use a reference: {name}')
