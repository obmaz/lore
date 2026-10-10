"""Render read-only, self-contained reference documents from the novel JSON package."""
import argparse
import hashlib
import html
import json
from pathlib import Path

from characters import load_characters
from materials import ROOT, load_materials, read
from reference import load_references
from story_continuity import CANON, DEFAULT, context

TEMPLATE = ROOT / "tools/reference.template.html"
OUTPUT = ROOT / "exports"
LABELS = {
    "writing_name":"집필 이름 · 추가 설정", "korean_name":"한국어 음역",
    "age":"나이", "gender":"성별", "species":"종족", "occupation":"직업",
    "appearance":"외모", "alignment":"윤리적 성향", "temperament":"성향",
    "voice":"말투", "goal":"목표", "story_role":"원작 역할", "recruitment":"영입",
    "reference_usage":"참조 사용 범위", "prophecy_testimony":"예언서의 설명",
    "original_combat_parameters":"원작 전투 수치", "mechanical_scope":"수치의 적용 범위",
    "effect":"효과", "conditions":"조건·제약", "game_index":"게임 인덱스",
    "price":"가격", "power":"위력", "class_restriction":"직업 제한",
    "source_event":"직접 사건", "testimony":"인물의 증언", "document_claim":"문서의 설명",
    "inferred":"해석·추론", "authored":"창작", "source_exact":"원작 그대로",
    "source_adaptation":"원작 요약", "unknown":"미상", "confirmed":"확인됨",
    "proposed":"검토 전 제안", "minor":"일반 스포일러", "major":"중요 스포일러",
    "interpretation":"추론 추가", "new_setting":"창작 추가", "transliteration":"음역 추가",
    "weapon":"무기", "shield":"방패", "armor":"갑옷", "direct_attack":"직접 공격",
    "indirect_attack":"간접 공격", "healing":"회복", "phenomenal":"현상 마법",
    "supernatural":"초자연력", "equipment":"무기·방어구", "abilities":"마법·기술",
    "bestiary":"적 템플릿", "strength":"힘", "mentality":"정신력", "endurance":"인내력",
    "resistance":"저항력", "agility":"민첩성", "accuracy_arms":"무기 명중",
    "accuracy_magic":"마법 명중", "armor_class":"방어 수치", "special":"특수 수치",
    "cast_level":"시전 수치", "special_cast_level":"특수 시전 수치", "level":"레벨",
}


def esc(value):
    return html.escape(str(value), quote=True)


def label(value):
    return esc(LABELS.get(value,value))


def value_html(value):
    if value is None:
        return '<span class="muted">미상</span>'
    if isinstance(value, dict):
        return '<dl class="values">'+''.join(f'<div><dt>{label(k)}</dt><dd>{value_html(v)}</dd></div>' for k,v in value.items())+'</dl>'
    if isinstance(value, list):
        return '<ul>'+''.join(f'<li>{value_html(v)}</li>' for v in value)+'</ul>'
    return esc(value)


def evidence_html(items):
    return ', '.join(esc(f"{e['file']} #{e['record_index']}" if 'record_index' in e else
                        f"{e['file']}:{e['line_start']}–{e['line_end']}") for e in items) or '근거 없음'


def claim_html(claim):
    meta = claim['metadata']
    badge = LABELS.get(meta['kind'],meta['kind']) if meta['addition'] else LABELS.get(claim['origin'],claim['origin'])
    return (f'<div class="claim"><div>{value_html(claim.get("value"))}</div>'
            f'<small><span class="badge {"added" if meta["addition"] else ""}">{esc(badge)}</span> '
            f'{label(claim.get("status","confirmed"))} · {evidence_html(claim.get("evidence",[]))}</small>'
            f'<div class="meta-note">{esc(meta["note"])}</div></div>')


def claim_table(claims):
    if not claims:
        return '<p class="muted">이 공개 범위에 전달할 정보 없음.</p>'
    return '<table><tbody>'+''.join(f'<tr><th scope="row">{label(c["field"])}</th><td>{claim_html(c)}</td></tr>' for c in claims)+'</tbody></table>'


def title_of(profile):
    if profile.get('writing_name',{}).get('value'):
        return profile['writing_name']['value']
    name = profile.get('korean_name')
    return (name.get('value') if isinstance(name,dict) else name) or profile['display_name']


def relation_html(relation, names, checkpoints=None):
    rows = [('상대',names.get(relation['target'],relation['target'])),
            ('관계 유형',relation['relation_type']), ('근거 구분',LABELS.get(relation['truth_type'],relation['truth_type'])),
            ('내용',relation['description']), ('경로 조건',relation['branch_condition'])]
    if relation['claimant']:
        rows.append(('증언자',names.get(relation['claimant'],relation['claimant'])))
    if checkpoints is not None:
        d = relation['disclosure']
        rows += [('스포일러',LABELS[d['spoiler']]),('공개 체크포인트',d['after_events'])]
    body = '<dl class="relation">'+''.join(f'<div><dt>{esc(k)}</dt><dd>{value_html(v)}</dd></div>' for k,v in rows)+'</dl>'
    body += claim_html(dict(relation,field='relationship',value=relation['description']))
    if checkpoints is not None:
        hints = relation['disclosure']['foreshadowing']
        if hints:
            body += '<h4>허용 복선</h4>' + ''.join(
                f'<p class="muted">허용 시점: {esc(", ".join(h["after_events"]))}</p>{claim_html(h["claim"])}' for h in hints)
    return body


def character_html(key, profile, names, checkpoints=None):
    master = checkpoints is not None
    original = profile['canonical_name']['value'] if master else profile['original_name']
    title = profile['display_name'] if master and '(사칭자)' in profile['display_name'] else title_of(profile)
    header = f'{esc(title)} <small>{esc(original or "원어 이름 미상")}</small>'
    body = claim_table(list(profile['biography'].values()))
    if master:
        body = claim_table([*([profile['writing_name']] if 'writing_name' in profile else []),profile['korean_name']])+body
    body += '<h4>원작 정보</h4>'+claim_table(profile['source_facts'])
    for field, title in [('traits','성향'),('speech','말투'),('goals','목표')]:
        body += f'<h4>{title}</h4>'+claim_table(profile['writing'][field])
    if master:
        body += '<h4>집필 경계</h4>'+value_html(profile['writing']['boundaries'])
        body += f'<p>{esc(profile["writing"]["notes"])}</p>'
        body += '<h4>공개 정책 · 편집자가 추가한 해석</h4>'
        body += value_html({'공개용 이름':profile['disclosure']['public_display_name'],
                            '공개용 ID':profile['disclosure']['public_id'],
                            '인물 정보 공개 후':profile['disclosure']['after_events'],
                            '원작 정보 필드별 공개':profile['disclosure']['fact_after']})
    if profile['relationships']:
        body += '<h4>관계</h4>'+''.join(relation_html(r,names,checkpoints) for r in profile['relationships'])
    if not master and profile['foreshadowing']:
        body += '<h4>허용된 복선 · 검토 전 제안</h4>'+''.join(claim_html(c) for c in profile['foreshadowing'])
    if any(profile['resource_refs'].values()):
        body += '<h4>장비·기술·적 템플릿 참조 ID</h4>'+value_html(profile['resource_refs'])
    return f'<details class="entry" id="character-{esc(key)}"><summary>{header}</summary><div class="entry-body">{body}</div></details>'


def section(key,title,body):
    return f'<section id="{esc(key)}"><h2>{esc(title)}</h2>{body}</section>'


def references_html(references):
    result = ''
    for category, document in references.items():
        entries = ''
        for key,item in document['items'].items():
            entries += (f'<details class="entry" id="resource-{esc(key)}"><summary>{esc(item.get("writing_name",item["korean_name"])["value"])} '
                        f'<small>{esc(item["original_name"]["value"])} · {label(item["category"])}</small></summary>'
                        f'<div class="entry-body">{claim_table([*([item["writing_name"]] if "writing_name" in item else []),item["original_name"],item["korean_name"],*item["claims"]])}</div></details>')
        result += section(category,LABELS[category],entries or '<p class="muted">현재 경로에서 공개된 참조 없음.</p>')
    return result


def documents(route):
    catalog, material_manifest = load_materials()
    profiles = load_characters(catalog)
    references = load_references(catalog)
    packet = context(read(DEFAULT),read(DEFAULT.with_name('prologue.continuity.json')),read(CANON),route,profiles)
    public_names = {k:title_of(p) for k,p in packet['character_profiles'].items()}
    safe = '<p class="notice">선택한 초안 경로의 공개 정보만 담은 잠정 미리보기입니다. 완성·승인된 소설이 아닙니다.</p>'
    safe += f'<p>경로: {esc(" → ".join(route) or "시작")}<br>공개 사건: {esc(", ".join(packet["disclosed_events"]) or "없음")}</p>'
    safe += section('characters','현재 장면의 인물', ''.join(character_html(k,p,public_names) for k,p in packet['character_profiles'].items()))
    safe_refs = {c:{'items':items} for c,items in packet['writing_references'].items()}
    safe += references_html(safe_refs)

    names = {k:title_of(p) for k,p in profiles['characters'].items()}
    checkpoints = profiles['disclosure_checkpoints']
    author = '<p class="notice danger">작가 전용 · 전편 스포일러 포함. 증언은 진상 확정이 아니며, 관계 공개는 영입·지식 습득을 자동 확정하지 않습니다.</p>'
    author += '<p>원문 전체 대사·코드 발췌는 이 설정집에 싣지 않습니다. 원문은 materials/ JSON에 그대로 보존되어 있습니다. 이 문서는 설정 요약이며 소설 원고가 아닙니다.</p>'
    quests = read(ROOT/'materials/quests.json')
    quest_names = {q['id']:q['title'] for q in quests['quests']}
    flow = '<p class="muted">편집용 흐름입니다. 권장 순서·강제 조건·병렬 목표를 구분하며, 목록 순서를 강제 플레이 순서로 해석하지 않습니다.</p>'
    flow += '<ol>'+''.join(f'<li><strong>{esc(q["title"])}</strong><small> {esc(q["id"])}</small></li>' for q in quests['quests'])+'</ol>'
    flow += '<table><thead><tr><th>출발</th><th>다음</th><th>연결·조건</th><th>근거</th></tr></thead><tbody>'
    for edge in quests['route_edges']:
        starts = edge['from'] if isinstance(edge['from'],list) else [edge['from']]
        flow += (f'<tr><td>{esc(" + ".join(quest_names[i] for i in starts))}</td><td>{esc(quest_names[edge["to"]])}</td>'
                 f'<td>{esc(edge["kind"])}<br>{esc(edge.get("condition",edge.get("state","")))}<br>{esc(edge.get("note",""))}</td>'
                 f'<td>{evidence_html(edge["evidence"])}</td></tr>')
    author += section('flow','퀘스트 흐름',flow+'</tbody></table>')
    author += section('characters','인물 카드', ''.join(character_html(k,p,names,checkpoints) for k,p in profiles['characters'].items()))
    relations = [r for p in profiles['characters'].values() for r in p['relationships'] if not r['id'].endswith(':reverse')]
    graph = ''
    for key,p in profiles['characters'].items():
        for r in p['relationships']:
            if not r['id'].endswith(':reverse'):
                graph += f'<details class="entry"><summary>{esc(names[key])} → {esc(names[r["target"]])} <small>{esc(r["relation_type"])}</small></summary><div class="entry-body">{relation_html(r,names,checkpoints)}</div></details>'
    author += section('relationships','관계 목록 · 역방향 중복 제외',graph)
    author += references_html(references)
    author += section('checkpoints','공개 체크포인트 · 편집 해석',claim_table([dict(c,field=key) for key,c in checkpoints.items()]))
    counts = {'characters':len(profiles['characters']), 'relationships':len(relations),
              'directed_links':sum(len(p['relationships']) for p in profiles['characters'].values()),
              **{c:len(d['items']) for c,d in references.items()},'quests':len(quests['quests'])}
    inputs = [ROOT/'characters/registry.json', *(ROOT/f'reference/{c}.json' for c in references),
              ROOT/'materials/quests.json', ROOT/'materials/manifest.json',DEFAULT,
              DEFAULT.with_name('prologue.continuity.json'),CANON,Path(__file__),TEMPLATE]
    sources = {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    manifest = {'version':1,'character_registry_revision':profiles['revision'],'route':route,
                'counts':counts,'source_sha256':sources,'material_counts':material_manifest['counts']}
    stamp = f'인물 목록 revision {profiles["revision"]} · 읽기 전용 · JSON 변경은 반영 후 재생성 필요'
    template = TEMPLATE.read_text(encoding='utf-8')
    def render(full):
        return (template.replace('@@TITLE@@','LORE 집필 설정집' if full else 'LORE 공개 범위 미리보기')
                .replace('@@STAMP@@',esc(stamp)).replace('@@SAFE@@',safe)
                .replace('@@AUTHOR_CONTROL@@','<label class="author-switch"><input type="checkbox" id="author-mode"> 작가용 전체 설정 열기 · 스포일러 포함</label>' if full else '<p>이 파일에는 작가 전용 비공개 데이터가 포함되지 않습니다.</p>')
                .replace('@@AUTHOR_TEMPLATE@@',f'<template id="author-content">{author}</template>' if full else ''))
    return {'reference.html':render(True),'reference-safe.html':render(False)},manifest


def make_pdf(page_path,pdf_path):
    # Optional export dependency; reading HTML/PDF needs no Python/browser server.
    from playwright.sync_api import sync_playwright
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
        try:
            page = browser.new_page()
            # Managed browsers may disallow file:// navigation. Supply this one
            # generated document as content, without changing browser policy.
            page.set_content(page_path.read_text(encoding='utf-8'))
            page.locator('#author-mode').check()
            page.evaluate('preparePrint()')
            page.evaluate('document.fonts.ready')
            page.pdf(path=str(pdf_path),format='A4',print_background=True,prefer_css_page_size=True)
        finally:
            browser.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=OUTPUT)
    parser.add_argument('--route',nargs='*',default=['enter_courtyard','visit_lord'])
    parser.add_argument('--pdf',action='store_true',help='also export the author-only, spoiler-containing PDF (Playwright + /usr/bin/chromium)')
    parser.add_argument('--check',action='store_true',help='verify committed documents against current JSON without writing')
    args = parser.parse_args()
    docs,manifest = documents(args.route)
    output = args.output.resolve()
    manifest_path = output/'manifest.json'
    if args.check:
        saved = read(manifest_path)
        if any(saved.get(k)!=v for k,v in manifest.items()):
            raise ValueError('reference snapshot is stale; regenerate HTML and PDF')
        for name,body in docs.items():
            if (output/name).read_text(encoding='utf-8')!=body:
                raise ValueError(f'reference output differs: {name}')
        if saved.get('pdf_sha256') and hashlib.sha256((output/'reference-author.pdf').read_bytes()).hexdigest()!=saved['pdf_sha256']:
            raise ValueError('PDF snapshot differs')
    else:
        if (output/'reference-author.pdf').exists() and not args.pdf:
            raise ValueError('existing PDF must be regenerated too; use --pdf or a different output directory')
        output.mkdir(parents=True,exist_ok=True)
        for name,body in docs.items():
            (output/name).write_text(body,encoding='utf-8')
        if args.pdf:
            make_pdf(output/'reference.html',output/'reference-author.pdf')
            manifest['pdf_sha256'] = hashlib.sha256((output/'reference-author.pdf').read_bytes()).hexdigest()
        manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'output':str(output),'checked':args.check,**manifest['counts']},ensure_ascii=False))


if __name__=='__main__':
    main()
