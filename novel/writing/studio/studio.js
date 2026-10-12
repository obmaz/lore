'use strict';
(() => {
  const data = JSON.parse(document.getElementById('studio-data').textContent);
  const $ = id => document.getElementById(id);
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const state = {open:false, view:'overview', chapter:data.chapters[0].id, document:data.plan.default_document, category:'characters', query:'', source:'writing/project.json', pointer:'', edition:data.editions[0].id};
  const descriptions = {
    overview:'현재까지 작성된 원고와 구성, 설정을 한곳에서 확인합니다. 상세 본문과 구성 초안은 구분합니다.',
    reading:'최신 첫 장 선택형 초고, 기존 소편, 기본 경로, 원작 연결 판본을 같은 화면에서 읽습니다.',
    outline:'15장의 큰 이야기와 88개 소단락. 제목은 중앙 JSON을 참조하고 본문 완성 여부는 따로 표시합니다.',
    graph:'본줄기 → 선택별 이야기 → 합류 → 필수 결과. 넓은 그림은 좌우로 움직여 볼 수 있습니다.',
    branches:'현재 구현된 6개 결정·14개 선택지와 합류·조건·상태 변화. 기존 첫 장 독자 판본과는 별도 구조입니다.',
    order:'실제 선택 경로에서 뽑은 편집 순서입니다. 정사·출판 승인·페이지 확정이 아닌 예시입니다.',
    settings:'인물, 관계, 무기, 마법과 공개 시점. 원작·증언·추론·창작 추가의 표시를 함께 확인합니다.',
    sources:'조회 중인 내용의 실제 JSON과 작업 규칙입니다. 수정·저장은 원본 파일에서 하고 화면은 재생성합니다.'
  };
  const categoryNames = {characters:'인물 카드',relationships:'인물 관계',equipment:'무기 · 방어구',abilities:'마법 · 기술',bestiary:'적 · 보스 템플릿',terms:'세계 · 지명',checkpoints:'공개 시점 · 복선 정책'};
  const kindNames = {main:'주요 이야기',outcome:'필수 결과',choice:'선택 뒤 이야기',automatic:'자동 연결 이야기',reaction:'조건부 후속 반응'};
  const nav = $('navigation');
  nav.innerHTML = data.plan.navigation.map((r,i) => `<button type="button" class="nav-button" data-view="${esc(r.id)}" disabled><span class="nav-number">${String(i+1).padStart(2,'0')}</span>${esc(r.label)}</button>`).join('');
  const chapter = () => data.chapters.find(c => c.id===state.chapter);
  const chapterOptions = () => data.chapters.map(c=>`<option value="${c.id}" ${c.id===state.chapter?'selected':''}>제${c.number}장 · ${esc(c.title)}</option>`).join('');
  const chapterToolbar = () => `<div class="toolbar"><label for="chapter-select">살펴볼 장</label><select id="chapter-select">${chapterOptions()}</select><button class="button" data-step="-1" ${chapter().number===1?'disabled':''}>이전 장</button><button class="button" data-step="1" ${chapter().number===data.chapters.length?'disabled':''}>다음 장</button></div>`;
  const sourceButton = ref => `<div class="source-note"><span>${esc(ref.file)}${esc(ref.pointer||'')}</span><button type="button" class="button small" data-source="${esc(ref.file)}" data-pointer="${esc(ref.pointer||'')}">원본 JSON 보기</button></div>`;
  function sourceValue(file,pointer='') {
    let value=data.sources[file];
    if (value===undefined) throw new Error('없는 자료입니다.');
    if (pointer) {
      if (!pointer.startsWith('/')) throw new Error('잘못된 참조입니다.');
      for (const key of pointer.slice(1).split('/').map(k=>k.replace(/~1/g,'/').replace(/~0/g,'~'))) {
        if (value===null || typeof value!=='object' || !Object.prototype.hasOwnProperty.call(value,key)) throw new Error('없는 참조입니다.');
        value=value[key];
      }
    }
    return value;
  }
  function headingForUnit(key) {
    for (const c of data.chapters) { const u=c.units.find(u=>u.unit_id===key); if (u) return `${u.number} · ${u.title}`; }
    return key;
  }
  function go(view,focus=true) {
    if (!state.open || !descriptions[view]) return;
    state.view=view;
    nav.querySelectorAll('button').forEach(b=>{if(b.dataset.view===view)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});
    $('view-title').textContent=data.plan.navigation.find(r=>r.id===view).label;
    $('view-description').textContent=descriptions[view];
    const content=$('view-content');
    if (view==='overview') {
      const cards=[['reading','현재 소설 읽기','첫 장의 최신 선택형 초고와 기존 소편·경로 판본을 읽습니다.'],['outline','큰 흐름부터 살펴보기','15장 큰 이야기와 소단락 주요 내용을 나란히 확인합니다.'],['graph','갈림과 합류 확인','장별 실행 그래프와 두 봉인의 순서, 후속 반응을 살펴봅니다.'],['settings','집필 설정 찾기','인물·직업·성향·관계·장비·마법과 추가 설정의 근거를 검색합니다.']];
      content.innerHTML=`<div class="stats"><div class="stat"><strong>${data.chapters.length}</strong><span>큰 장 · 구성 초안</span></div><div class="stat"><strong>${data.report.subsections}</strong><span>소단락 · 주요 내용 초안</span></div><div class="stat"><strong>${data.report.runtime_paths_checked}</strong><span>전편 구조 검사 경로</span></div><div class="stat"><strong>${data.settings.filter(r=>r.category==='characters').length}</strong><span>인물 카드 · 작가용</span></div></div><div class="grid">${cards.map(([v,t,n])=>`<article class="card"><h3>${t}</h3><p>${n}</p><button type="button" class="button" data-view="${v}">열기 →</button></article>`).join('')}</div><h2 style="margin-top:28px">현재 집필 단계</h2><article class="card"><ol class="stage-list"><li>전편 큰 구성·큰 이야기·소단락 주요 내용: <span class="badge">초안</span></li><li>15장 원문 연결 판본: <span class="badge">원문 보존 · 조건별 자료 포함</span></li><li>전편 소단락 분기: <span class="badge">6결정 · 14선택지 · 구조 검사 완료</span></li><li>첫 장 선택형 본문과 기존 소편: <span class="badge">미승인 초고 · 판본별 구분</span></li><li>나머지 장의 상세 산문·최종 출판 경로·페이지: <span class="badge added">미완성 · 미정</span></li></ol></article><h3>자료를 수정할 때</h3><p class="notice">이 제작실은 읽기 전용입니다. 원본 JSON에서 수정한 뒤 <code>python3 tools/writing.py export</code>로 다시 생성합니다. 화면의 탐색과 독자 경로 선택은 Git 파일을 수정하지 않습니다.</p>`;
    } else if (view==='reading' || view==='branches') {
      const chosen=view==='branches'?'branch-system.html':state.document;
      const groups=[['interactive','최신 선택형 본문'],['prose','기존 소편 · 기본 경로'],['source','원작 원문 연결 판본'],['structure','작가용 구성 자료']];
      const options=groups.map(([g,t])=>`<optgroup label="${t}">${data.documents.filter(d=>d.group===g).map(d=>`<option value="${esc(d.id)}" ${d.id===chosen?'selected':''}>${esc(d.label)}</option>`).join('')}</optgroup>`).join('');
      content.innerHTML=(view==='reading'?`<div class="toolbar"><label for="document-select">읽을 판본</label><select id="document-select">${options}</select><button type="button" class="button" id="restart-document">현재 판본 처음부터</button></div>`:'')+`<p class="notice" id="document-note"></p><iframe class="reader-frame" id="document-frame" title="${view==='branches'?'분기 구조와 조건':'소설 읽기'}" sandbox="allow-scripts allow-downloads"></iframe>`;
      openDocument(chosen);
    } else if (view==='outline') {
      content.innerHTML=chapterToolbar()+`<div class="split"><aside class="chapter-tree" aria-label="전체 장 목차">${data.chapters.map(c=>`<button type="button" data-chapter="${c.id}" aria-current="${c.id===state.chapter}">제${c.number}장 · ${esc(c.title)}<br><small>${c.units.length}소단락 · ${c.implementation==='runtime_bound'?'첫 장 독자 판본 별도':'상세 본문 미집필'}</small></button>`).join('')}</aside><section class="card"><span class="badge">큰 이야기 초고 · 상세 본문 아님</span><h2 style="margin-top:14px">제${chapter().number}장 · ${esc(chapter().title)}</h2>${chapter().story_html}${sourceButton({file:'writing/storyboard/chapter-stories.json',pointer:'/chapters/'+(chapter().number-1)})}</section></div><h2 style="margin-top:28px">소단락의 주요 내용</h2>${chapter().units.map(u=>`<details class="unit" id="${esc(u.unit_id.replace('/','-'))}"><summary>${esc(u.number+' · '+u.title)} ${u.decision_ids.length?'<span class="badge">구현 분기</span>':u.candidate_deferred?'<span class="badge added">분기 후보 · 미구현</span>':''}</summary><div class="unit-body">${u.html}${sourceButton(u.source_ref)}</div></details>`).join('')}`;
    } else if (view==='graph') {
      content.innerHTML=chapterToolbar()+`<div class="toolbar"><button type="button" class="button" data-view="outline">같은 장의 주요 내용</button><button type="button" class="button" id="open-overview-graph">전체 장 연결도</button></div><p class="notice">실선은 읽기·선택·합류, 점선은 조건부 반응 또는 관찰된 후속 영향입니다. 모든 선택지를 한 경로에서 읽는 뜻은 아닙니다. 9장은 두 탐색을 어느 순서에서든 모두 마친 뒤 합류합니다.</p><div class="diagram" id="chapter-diagram">${chapter().svg}</div>${sourceButton({file:'writing/publication/generated/flow.graph.json',pointer:''})}`;
    } else if (view==='order') {
      const edition=data.editions.find(e=>e.id===state.edition);
      content.innerHTML=`<div class="toolbar"><label for="edition-select">편집 경로</label><select id="edition-select">${data.editions.map(e=>`<option value="${esc(e.id)}" ${e.id===state.edition?'selected':''}>${esc(e.id)}</option>`).join('')}</select></div><div class="edition-head"><strong>제안 경로 · 페이지 미정 · 미승인</strong><p>${esc(edition.note)}</p><small>${esc(edition.manual_route.join(' → '))}</small></div><div class="toolbar"><label for="order-detail"><input id="order-detail" type="checkbox"> 선택·조건부 반응·필수 결과까지 펼쳐 보기</label></div><div class="scroll-table"><table><thead><tr><th>순서</th><th>소제목</th><th>문단 역할</th><th>페이지</th><th>본문 참조</th></tr></thead><tbody>${edition.rows.map(r=>`<tr data-row-kind="${r.kind}" ${r.kind==='main'?'':'hidden'}><td>${r.position}</td><td>${esc(headingForUnit(r.unit_id))}</td><td>${esc(kindNames[r.kind])}${r.choice_or_reaction_id?'<br><small>'+esc(r.choice_or_reaction_id)+'</small>':''}</td><td>미정</td><td><button class="button small" data-source="${esc(r.content_ref.file)}" data-pointer="${esc(r.content_ref.pointer)}">문단 JSON</button></td></tr>`).join('')}</tbody></table></div>${sourceButton({file:'writing/publication/flow.plan.json',pointer:'/linear_editions'})}`;
    } else if (view==='settings') {
      content.innerHTML=`<p class="notice">전편 인물·정체·관계가 표시됩니다. 나이 등 미상 값은 추정하지 않습니다. 카드의 공개 시점과 복선은 독자 공개 정책이며, 등장인물이 이미 아는 사실이 아닙니다.</p><div class="toolbar"><label for="setting-category">설정 종류</label><select id="setting-category">${Object.entries(categoryNames).map(([k,v])=>`<option value="${k}" ${k===state.category?'selected':''}>${v}</option>`).join('')}</select><input type="search" id="setting-search" aria-label="설정 검색" placeholder="이름·직업·성향·ID·내용 검색" value="${esc(state.query)}"></div><p class="source-result" id="setting-count" aria-live="polite"></p><div class="setting-list" id="setting-results"></div>`;
      filterSettings();
    } else if (view==='sources') {
      content.innerHTML=`<p class="notice">이 화면은 파일을 저장하지 않습니다. 내려받은 JSON도 저장소에 자동 반영되지 않습니다. 원본 경로에서 수정·검증·재생성한 뒤 커밋해야 합니다.</p><div class="toolbar"><label for="source-select">원본 · 생성 구조</label><select id="source-select">${data.source_index.map(s=>`<option value="${esc(s.file)}" ${s.file===state.source?'selected':''}>${esc(s.file)} · ${esc(s.role)}</option>`).join('')}</select><button type="button" class="button" id="source-whole">파일 전체 보기</button><button type="button" class="button" id="download-json">현재 JSON 내려받기</button></div><p class="source-result" id="source-location"></p><pre class="json-pane" id="source-content"></pre><h3>집필·공개·참조 규칙</h3><details class="unit"><summary>작업 지침 펼치기</summary><div class="unit-body">${data.rules.map(r=>`<pre class="rules">${esc(r)}</pre>`).join('')}</div></details>`;
      updateSource();
    }
    if (focus) {
      $('view-title').focus({preventScroll:true});
      const gap=innerWidth<=620?document.querySelector('.sidebar').offsetHeight+16:16;
      window.scrollTo({top:Math.max(0,$('workspace').getBoundingClientRect().top+window.scrollY-gap),behavior:'instant'});
    }
  }
  function openDocument(id) {
    const doc=data.documents.find(d=>d.id===id);
    if (!doc) return;
    $('document-note').textContent=doc.note+' · '+doc.source_ref+' · 원고를 수정하지 않는 조회 화면';
    $('document-frame').srcdoc=doc.html;
  }
  function filterSettings() {
    const query=state.query.trim().toLocaleLowerCase();
    const rows=data.settings.filter(r=>r.category===state.category && (!query||r.search.toLocaleLowerCase().includes(query)));
    $('setting-count').textContent=`${categoryNames[state.category]} · ${rows.length}개 표시`;
    $('setting-results').innerHTML=rows.map(r=>`<details class="setting"><summary>${esc(r.title)} <small>${esc(r.original)}</small></summary><div class="setting-content">${r.html}${sourceButton(r.source_ref)}</div></details>`).join('')||'<p class="empty">검색 결과가 없습니다. 다른 이름·ID·설정 종류로 찾아보세요.</p>';
    $('setting-results').querySelectorAll('.entry').forEach(e=>{e.open=true;});
  }
  function updateSource() {
    $('source-location').textContent=state.source+(state.pointer?' #'+state.pointer:' · 파일 전체');
    try { $('source-content').textContent=JSON.stringify(sourceValue(state.source,state.pointer),null,2); }
    catch(error) { $('source-content').textContent=error.message; }
  }
  function download() {
    const value=sourceValue(state.source,state.pointer);
    const blob=new Blob([JSON.stringify(value,null,2)+'\n'],{type:'application/json;charset=utf-8'});
    const url=URL.createObjectURL(blob); const a=document.createElement('a');a.href=url;
    a.download=state.source.split('/').pop().replace('.json',state.pointer?'.excerpt.json':'.json');
    a.click(); setTimeout(()=>URL.revokeObjectURL(url),1000);
  }
  document.addEventListener('click', event => {
    const button=event.target.closest('button'); if (!button || button.disabled) return;
    if (button.id==='open-studio') {
      state.open=true; $('author-gate').hidden=true; $('workspace').hidden=false;nav.querySelectorAll('button').forEach(b=>{b.disabled=false;});go('overview');
    } else if (button.dataset.view) go(button.dataset.view);
    else if (button.dataset.chapter) {state.chapter=button.dataset.chapter;go(state.view);}
    else if (button.dataset.step) {state.chapter=data.chapters[chapter().number-1+Number(button.dataset.step)].id;go(state.view);}
    else if (button.dataset.source) {state.source=button.dataset.source;state.pointer=button.dataset.pointer||'';go('sources');}
    else if (button.id==='restart-document') openDocument(state.document);
    else if (button.id==='open-overview-graph') { $('chapter-diagram').innerHTML=data.overview_svg;button.textContent='장별 그래프로 돌아가기';button.id='return-chapter-graph'; }
    else if (button.id==='return-chapter-graph') go('graph');
    else if (button.id==='source-whole') {state.pointer='';updateSource();}
    else if (button.id==='download-json') download();
  });
  document.addEventListener('change', event => {
    const input=event.target;
    if(input.id==='chapter-select') {state.chapter=input.value;go(state.view);}
    else if(input.id==='document-select') {state.document=input.value;openDocument(state.document);}
    else if(input.id==='edition-select') {state.edition=input.value;go('order');}
    else if(input.id==='setting-category') {state.category=input.value;filterSettings();}
    else if(input.id==='source-select') {state.source=input.value;state.pointer='';updateSource();}
    else if(input.id==='order-detail') document.querySelectorAll('[data-row-kind]').forEach(r=>{r.hidden=!input.checked && r.dataset.rowKind!=='main';});
  });
  document.addEventListener('input', event => {if(event.target.id==='setting-search') {state.query=event.target.value;filterSettings();}});
})();
