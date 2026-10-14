"""Export a deterministic, validated B reading route as a reflowable EPUB 3."""
import argparse
import base64
import hashlib
import html
import io
import json
import re
import uuid
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

from materials import ROOT, read
from cover_art import PLAN as COVERS, load_covers, cover_inputs
from prose_presentation import display_text, section_paragraphs

PLAN=ROOT/'writing/ebooks/ebook.plan.json'
OUTPUT=ROOT/'writing/ebooks/generated'
XHTML='http://www.w3.org/1999/xhtml'


def payload_from_page(page):
    match=re.search(r'id="chapter-data">(.*?)</script>',page,re.S)
    if not match:raise ValueError('ebook: missing reader data')
    payload=json.loads(match[1])
    if payload['edition']!='B':raise ValueError('ebook: only B prose is selected')
    return payload


def linear_route(session, plan):
    route,packet=session.advance([]);decisions=[]
    while packet['available_choices']:
        if len(decisions)>80:raise ValueError('ebook: route did not terminate')
        key=next((c for c in plan['manual_preferences']if c in packet['available_choices']),packet['available_choices'][0])
        decisions.append({'node_id':packet['node_id'],'choice_id':key})
        route,packet=session.choose(route,key)
    if not packet['main_story']['complete']:raise ValueError('ebook: required main story is incomplete')
    return route,packet,decisions


def xhtml(title, body):
    return '<?xml version="1.0" encoding="UTF-8"?><html xmlns="'+XHTML+'" xmlns:epub="http://www.idpf.org/2007/ops" lang="ko" xml:lang="ko"><head><title>'+html.escape(title)+'</title><link rel="stylesheet" type="text/css" href="styles.css"/></head><body>'+body+'</body></html>'


def assemble(page, context=None):
    from prose_variants import VariantSession
    from story_continuity import CANON,context_for_routes
    plan=read(PLAN);payload=payload_from_page(page)
    if plan['version']!=1 or plan['edition']!='B' or plan['status']!='draft' or plan['format']!='EPUB3_reflowable_linear_sample':
        raise ValueError('ebook: wrong edition or publication stage')
    if plan['filename']!='lore-B-chapters01-03.epub' or plan['public_path']!='/novel/downloads/'+plan['filename']:
        raise ValueError('ebook: unsafe output filename')
    if context is None:session=VariantSession()
    else:
        story,memory,overlay,provided=context
        if provided!=payload:raise ValueError('ebook: cached reader differs from the supplied context')
        session=VariantSession.__new__(VariantSession)
        session.story,session.memory,session.overlay=story,memory,overlay
        session.packet_for=context_for_routes(story,memory,read(CANON))
    if session.story['nodes']!=payload['nodes']:raise ValueError('ebook: prose differs from compiled B')
    chapters=payload['chapters']
    if [c['id']for c in chapters]!=plan['chapter_ids']:raise ValueError('ebook: written chapter scope changed; review the route')
    all_choices={c['id']for n in session.story['nodes']for c in n['choices']}
    if len(set(plan['manual_preferences']))!=len(plan['manual_preferences'])or not set(plan['manual_preferences'])<=all_choices:
        raise ValueError('ebook: unknown or duplicate preferred choice')
    route,packet,decisions=linear_route(session,plan)
    sections=[*packet['history'],{'node_id':packet['node_id'],'before':packet['state'],'visible_block_ids':[b['id']for b in packet['visible_blocks']]}]
    nodes={n['id']:n for n in payload['nodes']}
    texts={c['id']:[]for c in chapters};seen_sources=[];seen_blocks=[]
    for section in sections:
        chapter=next(c for c in chapters if section['node_id'].startswith(tuple(c['prefixes'])))
        paragraphs=section_paragraphs(nodes[section['node_id']],section['visible_block_ids'],section['before'],payload)
        texts[chapter['id']].extend(paragraphs)
        seen_blocks.extend(section['visible_block_ids'])
        seen_sources.extend(i for p in paragraphs for i in p['source_block_ids'])
    required_sources={b['id']for s in sections for b in nodes[s['node_id']]['blocks']if b['id']in s['visible_block_ids']and b['provenance']['origin']=='source_exact'}
    if set(seen_sources)!=required_sources:raise ValueError('ebook: chosen source content was omitted')
    covers=load_covers();esc=html.escape
    title=payload['covers']['title'];subtitle=payload['covers']['subtitle']
    identity='urn:uuid:'+str(uuid.uuid5(uuid.NAMESPACE_URL,json.dumps([payload['fingerprint'],route,plan],ensure_ascii=False,sort_keys=True)))
    members={'mimetype':b'application/epub+zip',
        'META-INF/container.xml':b'<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>'}
    css='body{font-family:serif;line-height:1.75;margin:5%;color:#25372e}p{margin:.65em 0;orphans:3;widows:3}h1{font-size:1.8em;margin:1.2em 0}img{max-width:100%;height:auto}.cover{text-align:center}.cover img{max-height:85vh;width:auto}.chapter-art{text-align:center;margin:1em 0 2em}.chapter-art img{max-width:75%;max-height:70vh;width:auto}a{color:#27634c}.edition-note{font-size:.9em}nav ol{line-height:2}'
    members['OEBPS/styles.css']=css.encode()
    items=[('style','styles.css','text/css',''),('cover','cover.xhtml','application/xhtml+xml',''),('note','reading-note.xhtml','application/xhtml+xml',''),('nav','nav.xhtml','application/xhtml+xml','nav'),('ncx','toc.ncx','application/x-dtbncx+xml','')]
    spine=['cover','note'];nav=[('cover.xhtml',title),('reading-note.xhtml','이 판본에 관하여')]
    members['OEBPS/cover.xhtml']=xhtml(title,'<main class="cover" epub:type="cover"><h1>'+esc(title)+'</h1><p>'+esc(subtitle)+'</p><img src="images/cover-main.jpg" alt="'+esc(payload['covers']['images']['main']['alt'])+'"/></main>').encode()
    note='<main class="edition-note"><h1>이 판본에 관하여</h1><p>B안 · 1~3장 본문 초고입니다. 공용 표지 네 장을 포함합니다.</p><p>웹의 선택형 소설에서 한 대표 경로를 실제로 재생해 선형 전자책으로 묶었습니다. 다른 갈래를 섞지 않았으며 정사나 최종 출판 승인본은 아닙니다.</p><p>원문은 보존하고, 소설용 스크립트 대체본을 우선 적용했습니다. 소단락 제목·화자 이름표·게임 상태창은 본문에 없습니다.</p><p>표지의 외형·건축·봉인 형태는 생성형 시각화 초안이며 원작 확정 설정이 아닙니다.</p><p>다른 선택 경로는 <a href="https://obmaz.github.io/lore/novel/?edition=B">웹 B안</a>에서 읽을 수 있습니다.</p></main>'
    members['OEBPS/reading-note.xhtml']=xhtml('이 판본에 관하여',note).encode()
    chapter_counts={}
    for chapter in chapters:
        key=chapter['id'];heading='제'+str(int(key[7:]))+'장 · '+display_text(chapter['title'],packet['state'],payload)
        art=covers['images'][key];name=Path(art['file']).name
        body='<main><h1>'+esc(heading)+'</h1><figure class="chapter-art"><img src="images/'+name+'" alt="'+esc(payload['covers']['images'][key]['alt'])+'"/></figure>'
        body+=''.join('<p>'+esc(p['text'])+'</p>'for p in texts[key])+'</main>'
        members['OEBPS/'+key+'.xhtml']=xhtml(heading,body).encode()
        items.append((key,key+'.xhtml','application/xhtml+xml',''));spine.append(key);nav.append((key+'.xhtml',heading))
        chapter_counts[key]={'paragraphs':len(texts[key]),'characters':sum(len(p['text'])for p in texts[key])}
    for key,image in covers['images'].items():
        name=Path(image['file']).name
        members['OEBPS/images/'+name]=(ROOT/image['file']).read_bytes()
        items.append(('image-'+key,'images/'+name,'image/jpeg','cover-image'if key=='main'else ''))
    nav_body='<nav epub:type="toc" id="toc"><h1>목차</h1><ol>'+''.join('<li><a href="'+href+'">'+esc(label)+'</a></li>'for href,label in nav)+'</ol></nav>'
    nav_body+='<nav epub:type="landmarks" hidden="hidden"><h2>책의 구성</h2><ol><li><a epub:type="cover" href="cover.xhtml">표지</a></li><li><a epub:type="bodymatter" href="chapter01.xhtml">본문</a></li></ol></nav>'
    members['OEBPS/nav.xhtml']=xhtml('목차',nav_body).encode()
    ncx='<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="'+identity+'"/></head><docTitle><text>'+esc(title)+'</text></docTitle><navMap>'
    ncx+=''.join('<navPoint id="nav'+str(i)+'" playOrder="'+str(i)+'"><navLabel><text>'+esc(label)+'</text></navLabel><content src="'+href+'"/></navPoint>'for i,(href,label)in enumerate(nav,1))+'</navMap></ncx>'
    members['OEBPS/toc.ncx']=ncx.encode()
    manifest=''.join('<item id="'+id+'" href="'+href+'" media-type="'+mime+'"'+(' properties="'+prop+'"'if prop else '')+'/>'for id,href,mime,prop in items)
    package='<?xml version="1.0" encoding="UTF-8"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id" xml:lang="ko"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="book-id">'+identity+'</dc:identifier><dc:title>'+esc(title+' · B안 · 1~3장')+'</dc:title><dc:language>ko</dc:language><dc:creator>'+esc(plan['creator'])+'</dc:creator><meta property="dcterms:modified">'+esc(plan['modified'])+'</meta><meta name="cover" content="image-main"/></metadata><manifest>'+manifest+'</manifest><spine toc="ncx">'+''.join('<itemref idref="'+key+'"/>'for key in spine)+'</spine></package>'
    members['OEBPS/package.opf']=package.encode()
    buffer=io.BytesIO()
    with zipfile.ZipFile(buffer,'w')as archive:
        for name,body in members.items():
            info=zipfile.ZipInfo(name,(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_STORED if name=='mimetype'else zipfile.ZIP_DEFLATED
            info.create_system=3;info.external_attr=0o100644<<16
            archive.writestr(info,body)
    book=buffer.getvalue();validate_epub(book)
    report={'version':1,'edition':'B','status':'draft','format':plan['format'],'filename':plan['filename'],
            'scope':plan['chapter_ids'],'route':route,'decisions':decisions,'route_note':plan['route_note'],
            'chapters':chapter_counts,'required_main_scenes':len(packet['main_story']['seen_scenes']),
            'chosen_source_blocks':sorted(required_sources),'source_content_preserved_for_selected_route':True,
            'all_alternative_paths_included':False,'script_override_ids':sorted(set(payload['presentation']['script_overrides'])&set(seen_blocks)),
            'shared_cover_files':[i['file']for i in covers['images'].values()],
            'reader_fingerprint':payload['fingerprint'],'canonical_or_approved':False}
    return book,report


def validate_epub(book):
    with zipfile.ZipFile(io.BytesIO(book))as archive:
        names=archive.namelist()
        if names[0]!='mimetype' or archive.getinfo('mimetype').compress_type!=zipfile.ZIP_STORED or archive.read('mimetype')!=b'application/epub+zip':
            raise ValueError('ebook: invalid uncompressed mimetype entry')
        if len(set(names))!=len(names) or any(Path(n).is_absolute()or '..'in Path(n).parts for n in names):raise ValueError('ebook: unsafe archive path')
        for name in names:
            if name.endswith(('.xhtml','.xml','.opf','.ncx')):ET.fromstring(archive.read(name))
        opf=ET.fromstring(archive.read('OEBPS/package.opf'));ns={'o':'http://www.idpf.org/2007/opf'}
        items={i.attrib['id']:i.attrib for i in opf.findall('o:manifest/o:item',ns)}
        for item in items.values():
            if 'OEBPS/'+item['href'] not in names:raise ValueError('ebook: missing manifest asset')
        for item in opf.findall('o:spine/o:itemref',ns):
            if item.attrib['idref']not in items:raise ValueError('ebook: missing spine document')
        if sum('nav'in i.get('properties','').split()for i in items.values())!=1:raise ValueError('ebook: requires one navigation document')
    return {'valid_package':True,'members':len(names)}


def export(check=False, page=None, context=None):
    source=ROOT/'writing/previews/chapter01-web.html'
    if page is None:
        preview=read(ROOT/'writing/previews/manifest.json')
        for relative,digest in preview['source_sha256'].items():
            candidate=(ROOT/relative).resolve()
            if not candidate.is_relative_to(ROOT):raise ValueError('ebook: reader source escapes novel')
            if hashlib.sha256(candidate.read_bytes()).hexdigest()!=digest:
                raise ValueError('ebook: reader inputs changed; run writing.py export first')
        if hashlib.sha256(source.read_bytes()).hexdigest()!=preview['artifacts'][source.name]:
            raise ValueError('ebook: B reader was manually edited')
    page=source.read_text()if page is None else page
    book,report=assemble(page,context)
    from epub_interactive import assemble as choice_assemble, PLAN as CHOICE_PLAN, READER
    choice_book,choice_report=choice_assemble(page,book,report)
    choice_name=read(CHOICE_PLAN)['filename'];choice_body=json.dumps(choice_report,ensure_ascii=False,indent=2)+'\n'
    name=read(PLAN)['filename'];body=json.dumps(report,ensure_ascii=False,indent=2)+'\n'
    inputs=[PLAN,Path(__file__),ROOT/'tools/prose_presentation.py',CHOICE_PLAN,ROOT/'tools/epub_interactive.py',READER,*cover_inputs()]
    manifest={'version':1,'edition':'B','public_path':read(PLAN)['public_path'],
              'public_downloads':{name:read(PLAN)['public_path'],choice_name:read(CHOICE_PLAN)['public_path']},
              'source_sha256':{source.relative_to(ROOT).as_posix():hashlib.sha256(page.encode()).hexdigest(),**{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()for p in inputs}},
              'artifacts':{name:hashlib.sha256(book).hexdigest(),'report.json':hashlib.sha256(body.encode()).hexdigest(),
                           choice_name:hashlib.sha256(choice_book).hexdigest(),'interactive-report.json':hashlib.sha256(choice_body.encode()).hexdigest()}}
    path=OUTPUT/'manifest.json'
    if path.is_file():
        previous=read(path)
        for filename,digest in previous['artifacts'].items():
            if filename not in (name,'report.json',choice_name,'interactive-report.json'):raise ValueError('ebook: unknown or unsafe owned output')
            target=OUTPUT/filename
            if not target.is_file()or hashlib.sha256(target.read_bytes()).hexdigest()!=digest:raise ValueError('ebook output was manually edited; preserve before regeneration')
        for filename in (name,'report.json',choice_name,'interactive-report.json'):
            if filename not in previous['artifacts']and (OUTPUT/filename).exists():raise ValueError('ebook output exists without ownership manifest')
    elif (OUTPUT/name).exists():raise ValueError('ebook output exists without ownership manifest')
    manifest_body=json.dumps(manifest,ensure_ascii=False,indent=2)+'\n'
    if check:
        if not path.is_file()or path.read_text()!=manifest_body or (OUTPUT/name).read_bytes()!=book or (OUTPUT/'report.json').read_text()!=body or not (OUTPUT/choice_name).is_file()or (OUTPUT/choice_name).read_bytes()!=choice_book or not (OUTPUT/'interactive-report.json').is_file()or (OUTPUT/'interactive-report.json').read_text()!=choice_body:
            raise ValueError('ebook is stale; run writing.py export')
    else:
        OUTPUT.mkdir(parents=True,exist_ok=True)
        (OUTPUT/name).write_bytes(book);(OUTPUT/'report.json').write_text(body);path.write_text(manifest_body)
        (OUTPUT/choice_name).write_bytes(choice_book);(OUTPUT/'interactive-report.json').write_text(choice_body)
    return {'filename':name,'chapters':len(report['scope']),'main_scenes':report['required_main_scenes'],'sha256':manifest['artifacts'][name],'bytes':len(book),'checked':check,
            'interactive':{'filename':choice_name,'sha256':manifest['artifacts'][choice_name],'bytes':len(choice_book),'ridi_device_tested':False}}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    print(json.dumps(export(check=args.check),ensure_ascii=False,indent=2))
