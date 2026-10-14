"""Package the shared B choice reader in EPUB 3, with a static reading fallback."""
import hashlib
import html
import io
import json
import uuid
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

from materials import ROOT, read
from ebook import XHTML, payload_from_page, validate_epub, xhtml

PLAN=ROOT/'writing/ebooks/interactive.plan.json'
READER=ROOT/'writing/interactive/reader.js'
NS={'o':'http://www.idpf.org/2007/opf','h':XHTML}


def assemble(page, linear_book, linear_report):
    plan=read(PLAN);payload=payload_from_page(page)
    name='lore-B-chapters01-03-interactive-epub3.epub'
    if (plan['version']!=1 or plan['edition']!='B' or plan['status']!='experimental'
        or plan['format']!='EPUB3_scripted_choice_sample' or plan['package_version']!='3.0'
        or plan['filename']!=name or plan['public_path']!='/novel/downloads/'+name
        or plan['chapter_ids']!=[c['id']for c in payload['chapters']]
        or plan['storage']!='optional_local_storage_choice_ids_replayed'
        or plan['fallback']!='existing_validated_linear_B_route'
        or plan['ridi_support']!='unverified_no_device_test'
        or not plan['metadata']['addition'] or plan['metadata']['status']!='proposed'):
        raise ValueError('interactive ebook: unreviewed scope, output or compatibility claim')
    original_fingerprint=payload['fingerprint'];reader=READER.read_bytes()
    payload['fingerprint']=hashlib.sha256(json.dumps([original_fingerprint,plan,hashlib.sha256(reader).hexdigest()],sort_keys=True).encode()).hexdigest()
    payload['runtime']={'target':'epub','storage':'optional_local_storage_choice_ids_replayed'}
    for key,image in payload['covers']['images'].items():
        # Use manifest resources instead of data URLs in reading-system sandboxes.
        image['src']='images/cover-'+key+'.jpg'
    with zipfile.ZipFile(io.BytesIO(linear_book))as archive:members={n:archive.read(n)for n in archive.namelist()}
    title=payload['covers']['title'];esc=html.escape
    note='<main><h1>EPUB 3.0 선택형 시험본 · B안 1~3장</h1><p><a href="interactive.xhtml">선택하며 읽기 시작</a></p><p>선택 기록·동료·장비·조건부 본문은 스크립트를 지원하는 리더에서만 작동합니다. 기록 저장도 리더 정책에 따라 제한됩니다. 리디 앱에서의 실제 작동은 아직 확인하지 못했습니다.</p><p>선택 기능이 작동하지 않으면 <a href="chapter01.xhtml">일반 본문 읽기</a> 또는 <a href="https://obmaz.github.io/lore/novel/?edition=B">웹 B안</a>을 이용해 주세요. 일반 본문은 별도로 검증한 하나의 대표 경로이며 다른 선택 결과를 섞지 않았습니다.</p><p>리더 목차·페이지 넘기기로 일반 본문에 이동하는 것은 선택의 결과가 아닙니다. 선택형 진행은 한 문서 안에서 처리합니다.</p><p>초고이며 정사·출판 승인본이 아닙니다. A/B 공용 표지의 외형·건축·도구는 생성형 시각화 제안입니다. 포함된 데이터에서 다른 분기를 찾아볼 수 있으므로 스포일러 보안/암호화 기능은 아닙니다.</p></main>'
    members['OEBPS/reading-note.xhtml']=xhtml('선택형 시험본 안내',note).encode()
    body='<main><h1>'+esc(title)+' · B안 선택형</h1><p id="runtime-status" role="status">선택 기능은 이 리더의 스크립트 지원이 필요합니다. 아래에 선택 본문과 버튼이 나타나지 않으면 일반 본문 또는 웹을 이용해 주세요.</p><p><a href="chapter01.xhtml">일반 본문으로 읽기</a> · <a href="https://obmaz.github.io/lore/novel/?edition=B">웹 B안</a></p>'
    first_heading=''.join(ET.fromstring(members['OEBPS/chapter01.xhtml']).find('.//h:h1',NS).itertext())
    body+='<div id="epub-app" hidden="hidden"><figure class="chapter-art"><img id="book-cover-image" src="images/cover-main.jpg" alt="'+esc(payload['covers']['images']['main']['alt'])+'"/></figure><h2>'+esc(first_heading)+'</h2>'
    body+='<div class="reader-controls"><button type="button" id="back">이전 선택 되돌리기</button><button type="button" id="restart">처음부터</button><button type="button" id="save">경로 저장</button><button type="button" id="load">저장 불러오기</button></div><p id="message" role="status"></p><div id="manuscript"></div><div id="choices" aria-label="이야기 선택"></div><details><summary>동료·장비 확인</summary><div id="state"></div></details></div></main>'
    raw=json.dumps(payload,ensure_ascii=False,separators=(',',':')).replace('&','\\u0026').replace('<','\\u003c').replace('>','\\u003e')
    body+='<script id="chapter-data" type="application/json">'+raw+'</script><script type="text/javascript" src="reader.js"></script>'
    members['OEBPS/interactive.xhtml']=xhtml(title+' · 선택형 시험본',body).encode()
    members['OEBPS/reader.js']=reader
    members['OEBPS/styles.css']+=b'\n[hidden]{display:none!important}#choices{display:flex;flex-direction:column;gap:.5em;margin:1.5em 0}button{font:inherit;white-space:normal;text-align:left;padding:.6em .8em;border:1px solid #64796e;border-radius:.25em;color:inherit;background:transparent}.reader-controls{display:flex;flex-wrap:wrap;gap:.4em}.reader-controls button{font-size:.85em}.selected{font-size:.85em;color:#536859}section{scroll-margin-top:1em}details{margin:1em 0}#runtime-status{font-size:.9em}\n'
    opf=ET.fromstring(members['OEBPS/package.opf']);manifest=opf.find('o:manifest',NS);spine=opf.find('o:spine',NS)
    ET.SubElement(manifest,'{'+NS['o']+'}item',{'id':'interactive','href':'interactive.xhtml','media-type':'application/xhtml+xml','properties':'scripted'})
    ET.SubElement(manifest,'{'+NS['o']+'}item',{'id':'reader-js','href':'reader.js','media-type':'text/javascript'})
    # Listed for direct access, but skipped by ordinary next-page navigation.
    spine.insert(2,ET.Element('{'+NS['o']+'}itemref',{'idref':'interactive','linear':'no'}))
    identity='urn:uuid:'+str(uuid.uuid5(uuid.NAMESPACE_URL,payload['fingerprint']))
    metadata=opf.find('o:metadata',NS)
    metadata.find('{http://purl.org/dc/elements/1.1/}identifier').text=identity
    metadata.find('{http://purl.org/dc/elements/1.1/}title').text=title+' · B안 · EPUB 3.0 선택형 시험본'
    members['OEBPS/package.opf']=ET.tostring(opf,encoding='utf-8',xml_declaration=True)
    nav=[('cover.xhtml',title),('reading-note.xhtml','선택형 시험본 안내'),('interactive.xhtml','선택하며 읽기 · 1~3장')]
    for key in plan['chapter_ids']:
        heading=''.join(ET.fromstring(members['OEBPS/'+key+'.xhtml']).find('.//h:h1',NS).itertext())
        nav.append((key+'.xhtml','일반 본문 · '+heading))
    members['OEBPS/nav.xhtml']=xhtml('목차','<nav epub:type="toc" id="toc"><h1>목차</h1><ol>'+''.join('<li><a href="'+href+'">'+esc(label)+'</a></li>'for href,label in nav)+'</ol></nav>').encode()
    ncx='<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="'+identity+'"/></head><docTitle><text>'+esc(title)+'</text></docTitle><navMap>'
    ncx+=''.join('<navPoint id="nav'+str(i)+'" playOrder="'+str(i)+'"><navLabel><text>'+esc(label)+'</text></navLabel><content src="'+href+'"/></navPoint>'for i,(href,label)in enumerate(nav,1))+'</navMap></ncx>'
    members['OEBPS/toc.ncx']=ncx.encode()
    buffer=io.BytesIO()
    with zipfile.ZipFile(buffer,'w')as archive:
        for filename,content in members.items():
            info=zipfile.ZipInfo(filename,(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_STORED if filename=='mimetype'else zipfile.ZIP_DEFLATED
            info.create_system=3;info.external_attr=0o100644<<16;archive.writestr(info,content)
    book=buffer.getvalue();validate_epub(book)
    report={'version':1,'edition':'B','status':'experimental','format':plan['format'],'package_version':'3.0','filename':name,
            'scope':plan['chapter_ids'],'reader_fingerprint':original_fingerprint,'epub_fingerprint':payload['fingerprint'],
            'shared_runtime':'writing/interactive/reader.js','branch_state_data_included':True,'required_main_scenes':len(payload['main_story']),
            'fallback_route':linear_report['decisions'],'storage':'optional; replay validated choice IDs, no state import',
            'ridi_device_tested':False,'canonical_or_approved':False,'all_paths_rendered_or_proven':False,
            'compatibility_note':'EPUB 3.0 package validation is not proof of scripting/storage support in RIDI or another reader.'}
    return book,report
