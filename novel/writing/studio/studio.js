'use strict';
(() => {
  const data = JSON.parse(document.getElementById('studio-data').textContent);
  const $ = id => document.getElementById(id);
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const defaults = {open:false, view:'overview', chapter:data.chapters[0].id, document:data.plan.default_document, category:'characters', query:'', item:'', tab:'', source:'writing/project.json', pointer:'', edition:data.editions[0].id, graphPanel:'diagram', graphOverview:false, graphZoom:'1', orderFull:false, timelinePaths:{}};
  const state = {...defaults};
  let routeIndex=0,lastHash='';
  let graphSelected='';
  const descriptions = {
    overview:'현재까지 작성된 원고와 구성, 설정을 한곳에서 확인합니다. 상세 본문과 구성 초안은 구분합니다.',
    reading:'첫 장 선택형 초고와 전편 곁가지 선택판, 기존 소편·기본 경로·원작 연결 판본을 구별해 읽습니다.',
    outline:'15장의 큰 이야기와 88개 소단락. 제목은 중앙 JSON을 참조하고 본문 완성 여부는 따로 표시합니다.',
    graph:'아래로 시간의 흐름을 따라 공통 본줄기와 선택별 조건부 문단을 비교합니다. 같은 높이는 대체 문단이며 모두 읽는 경로가 아닙니다.',
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
  function routeHash() {
    const params=new URLSearchParams();
    for(const key of ['chapter','document','category','query','item','tab','source','pointer','edition','graphPanel','graphZoom']) {
      if(state[key]!==defaults[key] && state[key]!=='') params.set(key,state[key]);
    }
    if(state.graphOverview)params.set('graphOverview','1');
    if(state.orderFull)params.set('orderFull','1');
    if(Object.keys(state.timelinePaths).length)params.set('lanes',JSON.stringify(state.timelinePaths));
    return '#/'+state.view+(params.size?'?'+params.toString():'');
  }
  function recordRoute(mode='push') {
    const hash=routeHash();
    if(mode==='none'){lastHash=location.hash;const back=$('studio-back');if(back)back.disabled=routeIndex===0;return;}
    if(mode==='push' && location.hash===hash)return;
    if(mode==='push')routeIndex+=1;
    history[mode==='replace'?'replaceState':'pushState']({studioIndex:routeIndex},'',hash);
    lastHash=location.hash;
    const back=$('studio-back');if(back)back.disabled=routeIndex===0;
  }
  function restoreRoute() {
    const [view,query='']=location.hash.replace(/^#\/?/,'').split('?');
    const params=new URLSearchParams(query);
    Object.assign(state,defaults,{open:true,view:view==='branches'?'graph':descriptions[view]?view:'overview'});
    if(['diagram','timeline','rules'].includes(params.get('graphPanel')))state.graphPanel=params.get('graphPanel');
    if(view==='branches')state.graphPanel='rules';
    if(data.chapters.some(c=>c.id===params.get('chapter')))state.chapter=params.get('chapter');
    if(data.documents.some(d=>d.id===params.get('document')))state.document=params.get('document');
    if(categoryNames[params.get('category')])state.category=params.get('category');
    state.query=(params.get('query')||'').slice(0,120);
    if(data.settings.some(r=>r.id===params.get('item')&&r.category===state.category))state.item=params.get('item');
    state.tab=(params.get('tab')||'').slice(0,60);
    if(Object.prototype.hasOwnProperty.call(data.sources,params.get('source')))state.source=params.get('source');
    state.pointer=params.get('pointer')||'';
    try{sourceValue(state.source,state.pointer);}catch{state.pointer='';}
    if(data.editions.some(e=>e.id===params.get('edition')))state.edition=params.get('edition');
    state.graphOverview=params.get('graphOverview')==='1';state.orderFull=params.get('orderFull')==='1';
    if(['0.75','1','1.25','1.5'].includes(params.get('graphZoom')))state.graphZoom=params.get('graphZoom');
    try{const lanes=JSON.parse(params.get('lanes')||'{}');if(lanes&&typeof lanes==='object'&&!Array.isArray(lanes))state.timelinePaths=Object.fromEntries(Object.entries(lanes).filter(([gid,oid])=>data.timeline.groups[gid]?.options.some(o=>o.id===oid)));}catch{state.timelinePaths={};}
    routeIndex=Number.isInteger(history.state?.studioIndex)?history.state.studioIndex:0;
  }
  function onHistory() {
    if(!state.open||location.hash===lastHash)return;
    restoreRoute();go(state.view,true,'none');
  }
  window.addEventListener('popstate',onHistory);
  window.addEventListener('hashchange',onHistory);
  function go(view,focus=true,historyMode='push') {
    if (!state.open || !descriptions[view]) return;
    state.view=view;
    if(view!=='settings')document.querySelector('.main').classList.remove('settings-detail-open');
    nav.querySelectorAll('button').forEach(b=>{if(b.dataset.view===view)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});
    if(innerWidth<=620){const active=nav.querySelector('[aria-current="page"]');nav.scrollTo({left:nav.scrollLeft+active.getBoundingClientRect().left-nav.getBoundingClientRect().left-8,behavior:'instant'});}
    $('view-title').textContent=data.plan.navigation.find(r=>r.id===view).label;
    $('view-description').textContent=descriptions[view];
    const content=$('view-content');
    if (view==='overview') {
      const cards=[['reading','현재 소설 읽기','첫 장의 최신 선택형 초고와 기존 소편·경로 판본을 읽습니다.'],['outline','큰 흐름부터 살펴보기','15장 큰 이야기와 소단락 주요 내용을 나란히 확인합니다.'],['graph','갈림과 합류 확인','장별 실행 그래프와 두 봉인의 순서, 후속 반응을 살펴봅니다.'],['settings','집필 설정 찾기','인물·직업·성향·관계·장비·마법과 추가 설정의 근거를 검색합니다.']];
      content.innerHTML=`<div class="stats"><div class="stat"><strong>${data.chapters.length}</strong><span>큰 장 · 구성 초안</span></div><div class="stat"><strong>${data.report.subsections}</strong><span>소단락 · 주요 내용 초안</span></div><div class="stat"><strong>${data.report.runtime_paths_checked}</strong><span>본줄기 투영·대표 검사 경로</span></div><div class="stat"><strong>${data.settings.filter(r=>r.category==='characters').length}</strong><span>인물 카드 · 작가용</span></div></div><div class="grid">${cards.map(([v,t,n])=>`<article class="card"><h3>${t}</h3><p>${n}</p><button type="button" class="button" data-view="${v}">열기 →</button>${v==='reading'?'<button type="button" class="button" data-view="reading" data-document="side-adventures.html">전편 곁가지 선택판 →</button>':''}</article>`).join('')}</div><h2 style="margin-top:28px">현재 집필 단계</h2><article class="card"><ol class="stage-list"><li>전편 큰 구성·큰 이야기·소단락 주요 내용: <span class="badge">초안</span></li><li>15장 원문 연결 판본: <span class="badge">원문 보존 · 조건별 자료 포함</span></li><li>전편 소단락 분기: <span class="badge">${data.report.decisions}결정 · ${data.report.options}선택지 · 곁가지 15개 포함</span></li><li>첫 장 선택형 본문과 기존 소편: <span class="badge">미승인 초고 · 판본별 구분</span></li><li>나머지 장의 상세 산문·최종 출판 경로·페이지: <span class="badge added">미완성 · 미정</span></li></ol></article><h3>자료를 수정할 때</h3><p class="notice">이 제작실은 읽기 전용입니다. 원본 JSON에서 수정한 뒤 <code>python3 tools/writing.py export</code>로 다시 생성합니다. 화면의 탐색과 독자 경로 선택은 Git 파일을 수정하지 않습니다.</p>`;
    } else if (view==='reading') {
      const chosen=state.document;
      const groups=[['interactive','최신 선택형 본문'],['prose','기존 소편 · 기본 경로'],['source','원작 원문 연결 판본'],['structure','작가용 구성 자료']];
      const options=groups.map(([g,t])=>`<optgroup label="${t}">${data.documents.filter(d=>d.group===g).map(d=>`<option value="${esc(d.id)}" ${d.id===chosen?'selected':''}>${esc(d.label)}</option>`).join('')}</optgroup>`).join('');
      content.innerHTML=`<div class="toolbar"><label for="document-select">읽을 판본</label><select id="document-select">${options}</select><button type="button" class="button" id="restart-document">현재 판본 처음부터</button></div><p class="notice" id="document-note"></p><iframe class="reader-frame" id="document-frame" title="소설 읽기" sandbox="allow-scripts allow-downloads"></iframe>`;
      openDocument(chosen);
    } else if (view==='outline') {
      content.innerHTML=chapterToolbar()+`<div class="split"><aside class="chapter-tree" aria-label="전체 장 목차">${data.chapters.map(c=>`<button type="button" data-chapter="${c.id}" aria-current="${c.id===state.chapter}">제${c.number}장 · ${esc(c.title)}<br><small>${c.units.length}소단락 · ${c.implementation==='runtime_bound'?'첫 장 독자 판본 별도':'상세 본문 미집필'}</small></button>`).join('')}</aside><section class="card"><span class="badge">큰 이야기 초고 · 상세 본문 아님</span><h2 style="margin-top:14px">제${chapter().number}장 · ${esc(chapter().title)}</h2>${chapter().story_html}${sourceButton({file:'writing/storyboard/chapter-stories.json',pointer:'/chapters/'+(chapter().number-1)})}</section></div><h2 style="margin-top:28px">소단락의 주요 내용</h2>${chapter().units.map(u=>`<details class="unit" id="${esc(u.unit_id.replace('/','-'))}"><summary>${esc(u.number+' · '+u.title)} ${u.decision_ids.length?'<span class="badge">구현 분기</span>':u.candidate_deferred?'<span class="badge added">분기 후보 · 미구현</span>':''}</summary><div class="unit-body">${u.html}${sourceButton(u.source_ref)}</div></details>`).join('')}`;
    } else if (view==='graph') {
      const panels=`<nav class="view-tabs" aria-label="분기 · 그래프 보기">${[['diagram','장별 분기 그래프'],['timeline','비교 타임라인'],['rules','조건 · 결과']].map(([id,label])=>`<button type="button" class="button" data-graph-panel="${id}" aria-pressed="${state.graphPanel===id}">${label}</button>`).join('')}</nav>`;
      const graphical=state.graphPanel==='diagram',overview=graphical&&state.graphOverview;
      const diagram=`<div class="toolbar graph-tools"><button type="button" class="button" data-view="outline">같은 장의 주요 내용</button>${graphical?`<button type="button" class="button" id="${overview?'return-chapter-graph':'open-overview-graph'}">${overview?'장별 그래프로 돌아가기':'전체 장 연결도'}</button><label for="graph-zoom">크기</label><select id="graph-zoom">${['0.75','1','1.25','1.5'].map(z=>`<option value="${z}" ${state.graphZoom===z?'selected':''}>${Number(z)*100}%</option>`).join('')}</select>`:''}</div><p class="view-hint">${graphical?'아래로 갈수록 다음 사건입니다. 박스를 누르면 본문·질문·선택 조건과 후속 영향을 확인할 수 있습니다. 보라색 영향선은 선택한 박스와 연결된 것만 표시합니다.':'왼쪽은 공통 진행, 오른쪽은 같은 시점의 선택별 문단입니다. 카드를 누르면 상세 정보와 연결된 결과가 표시됩니다.'}</p><div class="graph-workspace"><div class="${graphical?'diagram':'timeline-board'}" id="chapter-diagram">${graphical?(overview?data.overview_svg:chapter().svg):renderTimeline()}</div><section class="graph-selection" id="graph-selection" aria-label="선택한 그래프 상세" aria-live="polite" hidden></section></div>`;
      content.innerHTML=chapterToolbar()+panels+(state.graphPanel==='rules'?`<section id="branch-details" aria-label="이 장의 분기 조건과 결과">${chapter().branch_html}</section>`:diagram);
      content.querySelectorAll('svg [data-flow-node]').forEach(node=>{if(data.graph_details[node.dataset.flowNode]){node.setAttribute('role','button');node.setAttribute('tabindex','0');node.setAttribute('aria-pressed','false');}});
      applyGraphZoom();
      const canvas=$('chapter-diagram'),first=canvas?.querySelector('.flow-node[data-node-kind="unit"] rect, .flow-node[data-node-kind="chapter"] rect');
      if(first){canvas.scrollLeft=Math.max(0,(Number(first.getAttribute('x'))+Number(first.getAttribute('width'))/2)*Number(state.graphZoom)-canvas.clientWidth/2);}
      graphSelected='';applyTimelinePaths();
    } else if (view==='order') {
      const edition=data.editions.find(e=>e.id===state.edition);
      content.innerHTML=`<div class="toolbar"><label for="edition-select">편집 경로</label><select id="edition-select">${data.editions.map(e=>`<option value="${esc(e.id)}" ${e.id===state.edition?'selected':''}>${esc(e.id)}</option>`).join('')}</select></div><div class="edition-head"><strong>제안 경로 · 페이지 미정 · 미승인</strong><p>${esc(edition.note)}</p><small>${esc(edition.manual_route.join(' → '))}</small></div><div class="toolbar"><label for="order-detail"><input id="order-detail" type="checkbox"> 선택·조건부 반응·필수 결과까지 펼쳐 보기</label></div><div class="scroll-table"><table><thead><tr><th>순서</th><th>소제목</th><th>문단 역할</th><th>페이지</th><th>본문 참조</th></tr></thead><tbody>${edition.rows.map(r=>`<tr data-row-kind="${r.kind}" ${r.kind==='main'?'':'hidden'}><td>${r.position}</td><td>${esc(headingForUnit(r.unit_id))}</td><td>${esc(kindNames[r.kind])}${r.choice_or_reaction_id?'<br><small>'+esc(r.choice_or_reaction_id)+'</small>':''}</td><td>미정</td><td><button class="button small" data-source="${esc(r.content_ref.file)}" data-pointer="${esc(r.content_ref.pointer)}">문단 JSON</button></td></tr>`).join('')}</tbody></table></div>${sourceButton({file:'writing/publication/flow.plan.json',pointer:'/linear_editions'})}`;
      $('order-detail').checked=state.orderFull;content.querySelectorAll('[data-row-kind]').forEach(r=>r.hidden=!state.orderFull&&r.dataset.rowKind!=='main');
    } else if (view==='settings') {
      content.innerHTML=`<div class="toolbar setting-toolbar"><label for="setting-category">설정 종류</label><select id="setting-category">${Object.entries(categoryNames).map(([k,v])=>`<option value="${k}" ${k===state.category?'selected':''}>${v}</option>`).join('')}</select><input type="search" id="setting-search" aria-label="설정 검색" placeholder="이름 · 직업 · 성향 · ID 검색" value="${esc(state.query)}"><button type="button" class="button" id="clear-search">검색 지우기</button><span class="source-result" id="setting-count" aria-live="polite"></span></div><div class="settings-layout" id="settings-layout"><div class="setting-list" id="setting-results"></div><article class="setting-detail" id="setting-detail"></article></div><p class="view-hint">전편 작가용 정보입니다. 나이의 미상, 원작·증언·추론·창작 추가와 공개 시점을 구분합니다.</p>`;
      filterSettings();
    } else if (view==='sources') {
      content.innerHTML=`<p class="notice">이 화면은 파일을 저장하지 않습니다. 내려받은 JSON도 저장소에 자동 반영되지 않습니다. 원본 경로에서 수정·검증·재생성한 뒤 커밋해야 합니다.</p><div class="toolbar"><label for="source-select">원본 · 생성 구조</label><select id="source-select">${data.source_index.map(s=>`<option value="${esc(s.file)}" ${s.file===state.source?'selected':''}>${esc(s.file)} · ${esc(s.role)}</option>`).join('')}</select><button type="button" class="button" id="source-whole">파일 전체 보기</button><button type="button" class="button" id="download-json">현재 JSON 내려받기</button></div><p class="source-result" id="source-location"></p><pre class="json-pane" id="source-content"></pre><h3>집필·공개·참조 규칙</h3><details class="unit"><summary>작업 지침 펼치기</summary><div class="unit-body">${data.rules.map(r=>`<pre class="rules">${esc(r)}</pre>`).join('')}</div></details>`;
      updateSource();
    }
    recordRoute(historyMode);
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
    const old=$('document-frame'),fresh=old.cloneNode(false);
    fresh.removeAttribute('srcdoc');fresh.srcdoc=doc.html;
    old.replaceWith(fresh);
  }
  function applyGraphZoom(){const svg=$('chapter-diagram')?.querySelector('svg');if(svg){const box=svg.viewBox.baseVal;svg.style.width=box.width*Number(state.graphZoom)+'px';svg.style.height=box.height*Number(state.graphZoom)+'px';}}
  function excerpt(text,limit=130){const value=String(text).replace(/\s+/g,' ').trim(),head=Math.floor((limit-3)/2);return value.length<=limit?value:value.slice(0,head)+' … '+value.slice(-(limit-3-head));}
  function timelineCard(card,group){
    const info=data.graph_details[card.node_id],letters=card.source_options.map(id=>group.options.find(o=>o.id===id)?.letter).filter(Boolean);
    const path=card.source_options.length===1?card.source_options[0]:'';
    const condition=info.kind==='option'?'선택 뒤 문단':(letters.length?letters.join('·')+'에서 연결 · 실제 조건 충족 시':'상태·동행 조건 충족 시');
    const sequence=(card.parallel_sequence||[]).map(step=>{
      const main=data.graph_details[step.main_node_id],outcome=data.graph_details[step.outcome_node_id];
      return '<li>'+ (main?'<strong>'+esc(main.location+' · '+main.label)+'</strong><details><summary>주요 내용</summary><p>'+esc(main.body)+'</p>'+sourceButton(main.source_ref)+'</details>':'')+'<small>'+esc(excerpt(outcome.body,100))+'</small>'+(step.reaction_node_ids||[]).map(id=>timelineCard({node_id:id,source_options:[],slot:null},group)).join('')+'</li>';
    }).join('');
    return `<article class="timeline-cell tl-card" data-flow-node="${esc(card.node_id)}" data-select-node="${esc(card.node_id)}" tabindex="0" role="button" aria-label="${esc(info.label)}" data-path="${esc(path)}" data-source-options="${esc(JSON.stringify(card.source_options))}" data-group="${esc(group.id)}" data-slot="${card.slot??'shared'}" style="grid-column:${card.slot===null?'1 / -1':card.slot+1}"><span class="tl-condition">${letters.length?esc(letters.join('·'))+' · ':''}${esc(condition)}</span><strong class="tl-select">${esc(info.label)}</strong><p>${esc(excerpt(info.body))}</p>${sequence?'<p class="tl-parallel-note">두 목표 모두 필수 · 이 경로의 탐색 순서</p><ol class="tl-parallel-sequence">'+sequence+'</ol>':''}<details class="tl-body"><summary>전체 문단</summary><p>${esc(info.body)}</p>${sourceButton(info.source_ref)}</details></article>`;
  }
  function renderTimeline(){
    const timeline=data.timeline.chapters.find(c=>c.chapter_id===state.chapter);
    return '<div class="tl-heading"><span>시간 ↓ · 공통 본줄기</span><span>선택별 조건부 문단 · 같은 높이는 대체 내용</span></div>'+timeline.rows.map((row,index)=>{
      const location=headingForUnit(row.unit_id).split(' · ')[0];
      if(row.kind==='main'){
        const info=data.graph_details[row.node_id];
        return `<section class="timeline-row tl-main-row" data-time="${index}" data-unit="${esc(row.unit_id)}"><div class="tl-common"><span class="tl-time">${esc(location)}</span><details><summary>${esc(info.label)}</summary><p>${esc(info.body)}</p>${sourceButton(info.source_ref)}</details></div><div class="tl-stage-note">공통 본줄기 · 모든 경로에서 진행</div></section>`;
      }
      if(row.kind==='outcome'){
        const info=data.graph_details[row.node_id];
        return `<section class="timeline-row tl-outcome-row" data-time="${index}"><div class="tl-common"><details class="tl-outcome"><summary>공통 결과</summary><p>${esc(info.body)}</p>${sourceButton(info.source_ref)}</details></div><div class="tl-stage-note">공통 진행 · 다음 본줄기로</div></section>`;
      }
      const group=data.timeline.groups[row.group_id],count=Math.max(1,group.options.length);
      const nesting=group.parent_option?'<p class="tl-nesting">분기의 분기 · <button type="button" class="button small" data-flow-focus="option/'+esc(group.parent_option)+'">'+esc(data.timeline.groups[group.parent_group].title)+' 참여 경로</button>에서만 이어집니다. 지나침에서는 질문 없이 본줄기로 합류합니다.</p>':'';
      const tabs=group.options.length?'<div class="timeline-tabs" role="tablist" aria-label="'+esc(group.title)+' 경로 비교">'+group.options.map(o=>'<button type="button" role="tab" data-timeline-group="'+esc(group.id)+'" data-timeline-option="'+esc(o.id)+'" aria-selected="false">'+esc(o.letter+' · '+o.label)+'</button>').join('')+'</div>':'';
      return `<section class="timeline-row tl-conditional-row" data-time="${index}" data-choice-group="${esc(group.id)}"><div class="tl-common"><small>${row.kind==='decision'?(group.parent_option?'중첩 선택':'선택'):'후속 반응'}</small><span class="tl-time">${esc(location)}</span></div><div class="tl-comparison"><header><strong>${esc(group.title)}</strong>${nesting}<small>${row.kind==='reaction'?'앞선 '+esc(headingForUnit(group.anchor_unit).split(' · ')[0])+' 선택/상태와 연결 · 원래 조건 적용':''}</small>${row.kind==='decision'?'<p class="tl-question">질문 · '+esc(group.prompt)+'</p>':''}</header>${tabs}<div class="tl-variants" data-timeline-group="${esc(group.id)}" style="--paths:${count}">${row.cards.map(card=>timelineCard(card,group)).join('')}<p class="tl-empty" hidden>이 비교 경로에 연결된 문단은 없습니다. 다른 상태·동행 조건은 별도로 확인하세요.</p></div></div></section>`;
    }).join('');
  }
  function applyTimelinePaths(){
    document.querySelectorAll('.tl-variants').forEach(row=>{
      const group=data.timeline.groups[row.dataset.timelineGroup],selected=state.timelinePaths[group.id]||group.options[0]?.id||'';
      const cells=Array.from(row.children).filter(e=>e.classList.contains('timeline-cell'));
      cells.forEach(cell=>{const candidates=JSON.parse(cell.dataset.sourceOptions||'[]');cell.classList.toggle('is-current',!candidates.length||candidates.includes(selected));});
      row.querySelector('.tl-empty').hidden=cells.some(cell=>cell.classList.contains('is-current'));
    });
    document.querySelectorAll('[data-timeline-option]').forEach(tab=>{const g=data.timeline.groups[tab.dataset.timelineGroup];tab.setAttribute('aria-selected',String(tab.dataset.timelineOption===(state.timelinePaths[g.id]||g.options[0]?.id)));});
  }
  function setTimelinePath(gid,oid){
    if(!data.timeline.groups[gid]?.options.some(o=>o.id===oid))return;
    const board=$('chapter-diagram'),top=board?.scrollTop||0;
    state.timelinePaths={...state.timelinePaths,[gid]:oid};applyTimelinePaths();if(board)board.scrollTop=top;recordRoute('replace');
  }
  function selectGraphNode(key){
    const svg=$('chapter-diagram'),panel=$('graph-selection');if(!svg||!panel)return;
    const scroll={top:svg.scrollTop,left:svg.scrollLeft};
    graphSelected=key===graphSelected?'':key;
    const chosen=Array.from(svg.querySelectorAll('[data-flow-node]')).find(n=>n.dataset.flowNode===graphSelected);
    const preferred=chosen?.dataset.path||JSON.parse(chosen?.dataset.sourceOptions||'[]')[0];
    if(preferred){state.timelinePaths={...state.timelinePaths,[chosen.dataset.group]:preferred};applyTimelinePaths();}
    const related=new Set(graphSelected?[graphSelected]:[]),links=[];
    svg.classList.toggle('has-graph-selection',!!graphSelected);
    data.timeline.links.forEach(edge=>{
      const active=!!graphSelected&&[edge.from,edge.to].includes(graphSelected);
      if(active){related.add(edge.from);related.add(edge.to);links.push({id:edge.id,key:edge.from===graphSelected?edge.to:edge.from,direction:edge.from===graphSelected?'후속 결과':'앞선 선택'});}
    });
    svg.querySelectorAll('.flow-edge').forEach(edge=>{
      const active=!!graphSelected&&[edge.dataset.from,edge.dataset.to].includes(graphSelected);
      edge.classList.toggle('is-related',active);
      if(active){related.add(edge.dataset.from);related.add(edge.dataset.to);}
    });
    svg.querySelectorAll('[data-flow-node]').forEach(node=>{
      node.classList.toggle('is-related',related.has(node.dataset.flowNode));node.classList.toggle('is-selected',node.dataset.flowNode===graphSelected);
      node.setAttribute('aria-pressed',String(node.dataset.flowNode===graphSelected));
      node.querySelector('button[data-select-node]')?.setAttribute('aria-pressed',String(node.dataset.flowNode===graphSelected));
    });
    const info=data.graph_details[graphSelected];panel.hidden=!info;if(!info){panel.innerHTML='';svg.scrollTo(scroll);return;}
    const remote=info.chapter_id!==state.chapter;
    const targets=links.map(link=>{const target=data.graph_details[link.key];return target?'<button type="button" class="button small" data-flow-focus="'+esc(link.key)+'">'+esc(link.id+' · '+link.direction+' → '+target.location+' · '+target.label)+'</button>':'';}).join('');
    const labels={unit:'주요 이야기',decision:'질문과 선택',option:'선택 뒤 이야기',reaction:'조건부 후속 문단',outcome:'필수 결과',merge:'분기 합류',reaction_merge:'조건부 문단 합류',parallel_merge:'병렬 탐색 완료',chapter:'장별 구성'};
    const logic=Object.entries(info.logic||{}).map(([field,value])=>'<p><strong>'+esc({goal:'목표',obstacle:'장애 · 주의',next_reason:'다음 행동의 이유'}[field])+'</strong><br>'+esc(value)+'</p>').join('');
    panel.innerHTML=`<div class="graph-selection-head"><strong>${esc(info.location+' · '+info.label)}</strong><button type="button" class="button small" id="clear-graph-selection">닫기</button></div><small>${esc(labels[info.kind]||'연결 정보')}</small><div class="graph-selection-body">${info.body.split(/\n\n+/).map(p=>'<p>'+esc(p)+'</p>').join('')}${(info.options||[]).map(o=>'<p><button type="button" class="button small" data-flow-focus="option/'+esc(o.id)+'">'+esc(o.label)+'</button></p>').join('')}</div>${targets?'<div class="graph-related">'+targets+'</div>':''}${sourceButton(info.source_ref)}${Object.keys(info.rules).length?'<details><summary>조건 · 상태 변화 · 창작 표시</summary><pre>'+esc(JSON.stringify(info.rules,null,2))+'</pre></details>':''}${remote?'<button type="button" class="button small" data-chapter="'+esc(info.chapter_id)+'">해당 장 그래프 보기 →</button>':''}`;
    if(logic)panel.querySelector('.graph-selection-body').insertAdjacentHTML('beforeend',logic);
    svg.scrollTo(scroll);
  }
  function focusGraphNode(key){
    const info=data.graph_details[key];if(!info)return;
    if(info.chapter_id!==state.chapter){state.chapter=info.chapter_id;state.graphOverview=false;go('graph');}
    const diagram=$('chapter-diagram'),node=Array.from(diagram.querySelectorAll('[data-flow-node]')).find(n=>n.dataset.flowNode===key);
    if(!node)return;
    if(node.dataset.path)setTimelinePath(node.dataset.group,node.dataset.path);
    selectGraphNode(key);
    const box=diagram.getBoundingClientRect(),target=node.getBoundingClientRect();
    diagram.scrollTo({left:Math.max(0,diagram.scrollLeft+target.left-box.left-(diagram.clientWidth-target.width)/2),top:Math.max(0,diagram.scrollTop+target.top-box.top-(diagram.clientHeight-target.height)/2),behavior:'instant'});
    (node.matches('[tabindex]')?node:node.querySelector('[data-select-node]'))?.focus({preventScroll:true});
  }
  function filterSettings() {
    const query=state.query.trim().toLocaleLowerCase();
    const rows=data.settings.filter(r=>r.category===state.category && (!query||r.search.toLocaleLowerCase().includes(query)));
    $('setting-count').textContent=`${categoryNames[state.category]} · ${rows.length}개 표시`;
    $('setting-results').innerHTML=rows.map(r=>`<button type="button" class="setting-list-item" data-setting="${esc(r.id)}" aria-current="${r.id===state.item}"><strong>${esc(r.title)}</strong><span>${esc(r.original||r.id.split('/').pop())}</span></button>`).join('')||'<p class="empty">검색 결과가 없습니다. 다른 이름·ID·설정 종류로 찾아보세요.</p>';
    renderSetting();
  }
  function renderSetting() {
    const item=data.settings.find(r=>r.id===state.item&&r.category===state.category);
    $('settings-layout').classList.toggle('has-selection',!!item);
    document.querySelector('.main').classList.toggle('settings-detail-open',!!item);
    if(!item){$('setting-detail').innerHTML='<div class="detail-empty"><h2>목록에서 하나를 선택하세요</h2><p>기본 설정, 원작 근거, 관계·공개 정책을 나누어 읽을 수 있습니다.</p></div>';return;}
    const sections=item.sections||{'설정':item.html};const tabs=Object.keys(sections);
    if(!tabs.includes(state.tab))state.tab=tabs[0];
    $('setting-detail').innerHTML=`<header class="setting-detail-head"><button type="button" class="button small" id="setting-list-back">← 목록</button><div class="setting-identity"><h2>${esc(item.title)}</h2><p>${esc(item.original||'원어 이름 미상')} <span class="entry-id">${esc(item.id.split('/').pop())}</span></p></div><span class="badge">${esc(categoryNames[item.category])}</span></header><nav class="detail-tabs" aria-label="설정 상세">${tabs.map(t=>`<button type="button" class="button" data-setting-tab="${esc(t)}" aria-pressed="${t===state.tab}">${esc(t)}</button>`).join('')}</nav><div class="setting-content">${sections[state.tab]}</div>${sourceButton(item.source_ref)}`;
    $('setting-detail').querySelectorAll('.entry').forEach(e=>e.open=true);
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
    const svgNode=event.target.closest('svg [data-flow-node][role="button"]');
    if(svgNode){selectGraphNode(svgNode.dataset.flowNode);return;}
    if(event.target.closest('.tl-card')&&event.target.closest('summary,details')&&!event.target.closest('button'))return;
    const button=event.target.closest('button,[data-select-node]'); if (!button || (button.tagName==='BUTTON' && button.disabled)) return;
    if (button.id==='open-studio') {
      state.open=true; $('author-gate').hidden=true; $('workspace').hidden=false;nav.querySelectorAll('button').forEach(b=>{b.disabled=false;});restoreRoute();go(state.view,true,'replace');
    } else if (button.dataset.view) {if(button.dataset.document)state.document=button.dataset.document;if(button.dataset.graphPanel)state.graphPanel=button.dataset.graphPanel;go(button.dataset.view);}
    else if (button.dataset.chapter) {state.chapter=button.dataset.chapter;state.graphOverview=false;go(state.view);}
    else if (button.dataset.step) {state.chapter=data.chapters[chapter().number-1+Number(button.dataset.step)].id;state.graphOverview=false;go(state.view);}
    else if (button.dataset.source) {state.source=button.dataset.source;state.pointer=button.dataset.pointer||'';go('sources');}
    else if (button.id==='restart-document') openDocument(state.document);
    else if (button.id==='open-overview-graph') {state.graphOverview=true;go('graph');}
    else if (button.id==='return-chapter-graph') {state.graphOverview=false;go('graph');}
    else if (button.id==='clear-graph-selection') selectGraphNode(graphSelected);
    else if (button.dataset.flowFocus) focusGraphNode(button.dataset.flowFocus);
    else if (button.dataset.selectNode) selectGraphNode(button.dataset.selectNode);
    else if (button.dataset.timelineOption) setTimelinePath(button.dataset.timelineGroup,button.dataset.timelineOption);
    else if (button.dataset.graphPanel) {state.graphPanel=button.dataset.graphPanel;go('graph');}
    else if (button.dataset.setting) {state.item=button.dataset.setting;state.tab='';go('settings');}
    else if (button.dataset.settingTab) {state.tab=button.dataset.settingTab;renderSetting();recordRoute();}
    else if (button.id==='setting-list-back') {state.item='';state.tab='';go('settings');}
    else if (button.id==='clear-search') {state.query='';state.item='';state.tab='';$('setting-search').value='';filterSettings();recordRoute('replace');}
    else if (button.id==='studio-back') history.back();
    else if (button.id==='source-whole') {state.pointer='';updateSource();recordRoute();}
    else if (button.id==='download-json') download();
  });
  document.addEventListener('change', event => {
    const input=event.target;
    if(input.id==='chapter-select') {state.chapter=input.value;state.graphOverview=false;go(state.view);}
    else if(input.id==='document-select') {state.document=input.value;openDocument(state.document);recordRoute();}
    else if(input.id==='edition-select') {state.edition=input.value;go('order');}
    else if(input.id==='setting-category') {state.category=input.value;state.item='';state.tab='';state.query='';go('settings',false);}
    else if(input.id==='source-select') {state.source=input.value;state.pointer='';updateSource();recordRoute();}
    else if(input.id==='graph-zoom') {state.graphZoom=input.value;applyGraphZoom();recordRoute('replace');}
    else if(input.id==='order-detail') {state.orderFull=input.checked;document.querySelectorAll('[data-row-kind]').forEach(r=>{r.hidden=!input.checked && r.dataset.rowKind!=='main';});recordRoute('replace');}
  });
  document.addEventListener('input', event => {if(event.target.id==='setting-search') {state.query=event.target.value;state.item='';state.tab='';filterSettings();recordRoute('replace');}});
  document.addEventListener('keydown',event=>{
    const svgNode=event.target.closest('svg [data-flow-node][role="button"]');
    if(svgNode&&['Enter',' '].includes(event.key)){event.preventDefault();selectGraphNode(svgNode.dataset.flowNode);return;}
    const card=event.target.closest('[data-select-node].tl-card');
    if(card&&['Enter',' '].includes(event.key)&&event.target===card){event.preventDefault();selectGraphNode(card.dataset.selectNode);return;}
    const tab=event.target.closest('[data-timeline-option]');
    if(tab&&['ArrowLeft','ArrowRight'].includes(event.key)){
      event.preventDefault();const g=data.timeline.groups[tab.dataset.timelineGroup],index=g.options.findIndex(o=>o.id===tab.dataset.timelineOption),next=g.options[(index+(event.key==='ArrowRight'?1:g.options.length-1))%g.options.length];
      setTimelinePath(g.id,next.id);Array.from(tab.parentElement.querySelectorAll('button')).find(b=>b.dataset.timelineOption===next.id)?.focus();
    }else if(event.key==='Escape'&&graphSelected)selectGraphNode(graphSelected);
  });
})();
