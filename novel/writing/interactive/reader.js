/* Offline reader: save only choice IDs; reconstruct state/knowledge by replay. */
(() => {
  'use strict';
  const data = JSON.parse(document.getElementById('chapter-data').textContent);
  const epub = data.runtime?.target === 'epub';
  const create = tag => document.createElementNS('http://www.w3.org/1999/xhtml',tag);
  const nodes = Object.fromEntries(data.nodes.map(n => [n.id, n]));
  const presentation = data.presentation;
  const mainCover=document.getElementById('book-cover-image');
  mainCover.src=data.covers.images.main.src;
  mainCover.alt=data.covers.images.main.alt;
  const sourceGroups = new Map(presentation.groups.flatMap(g => g.block_ids.map(id => [id, g])));
  const clone = value => JSON.parse(JSON.stringify(value));
  let route = [];
  const message = text => { document.getElementById('message').textContent = text; };
  const storageKey = 'novel-epub-route:' + data.fingerprint;
  let storageAvailable = false;
  function storedRoute() {
    const raw=localStorage.getItem(storageKey);
    if (!raw) throw Error('저장한 선택 기록이 없습니다.');
    if (raw.length>32768) throw Error('저장 기록이 너무 큽니다.');
    const saved=JSON.parse(raw);
    if (Object.keys(saved).sort().join(',')!=='fingerprint,route'||saved.fingerprint!==data.fingerprint) throw Error('다른 판본 또는 변조된 저장 기록입니다.');
    const packet=replay(saved.route);
    if (automatic(packet.node.id,packet.state)) throw Error('자동 진행이 누락된 저장 경로입니다.');
    return [...saved.route];
  }
  function persist() {
    if (!epub||!storageAvailable) return;
    try { localStorage.setItem(storageKey,JSON.stringify({fingerprint:data.fingerprint,route})); }
    catch (_) { storageAvailable=false;document.getElementById('runtime-status').textContent='선택 기능 작동 · 이 리더에서는 기록 저장이 제한됩니다. 책을 닫으면 진행이 사라질 수 있습니다.'; }
  }
  function matches(p, state) {
    if (typeof p === 'boolean') return p;
    if (p.all) return p.all.every(x => matches(x, state));
    if (p.any) return p.any.some(x => matches(x, state));
    if (p.not) return !matches(p.not, state);
    if (!(p.state in state)) throw Error('알 수 없는 상태');
    const value = state[p.state];
    switch (p.op) {
      case 'eq': return JSON.stringify(value) === JSON.stringify(p.value);
      case 'ne': return JSON.stringify(value) !== JSON.stringify(p.value);
      case 'gte': return value >= p.value;
      case 'lte': return value <= p.value;
      case 'contains': return value.includes(p.value);
      case 'not_contains': return !value.includes(p.value);
      default: throw Error('알 수 없는 조건');
    }
  }
  function apply(effects, state) {
    for (const e of effects) {
      if (!(e.state in state)) throw Error('잘못된 상태 변경');
      if (e.op === 'set') state[e.state] = clone(e.value);
      else if (e.op === 'increment') state[e.state] += e.value;
      else if (e.op === 'add') { if (!state[e.state].includes(e.value)) state[e.state].push(e.value); }
      else if (e.op === 'remove') state[e.state] = state[e.state].filter(x => x !== e.value);
      else throw Error('알 수 없는 효과');
    }
  }
  function automatic(node, state) {
    const rules = data.auto_rules.filter(r => r.node === node && matches(r.when, state));
    if (rules.length > 1) throw Error('자동 진행 충돌');
    if (rules[0]) return rules[0];
    const choices=nodes[node].choices.filter(c=>matches(c.when,state));
    return choices.length===1 ? {choice:choices[0].id,reason:''} : undefined;
  }
  function replay(saved) {
    if (!Array.isArray(saved) || saved.length > 160 || saved.some(x => typeof x !== 'string')) throw Error('잘못된 경로');
    let key = data.entry;
    const state = clone(data.initial), events = [], knowledge = {}, sections = [], mainStory = [], decisions=new Set();
    for (let index = 0; index <= saved.length; index++) {
      const node = nodes[key], contract = data.contracts[key];
      if (!node || !matches(node.entry_when, state) || !matches(contract.before, state)) throw Error('접근할 수 없는 장면');
      for (const item of contract.knowledge_required) {
        if (!(knowledge[item.character_id] || []).includes(item.fact_id)) throw Error('아직 듣지 않은 정보를 요구하는 장면');
      }
      const cast = contract.cast.filter(c => matches(c.when, state)).map(c => c.character_id);
      const blocks = node.blocks.filter(b => b.kind !== 'author_note' && matches(b.when, state));
      for (const rule of data.conditional_required.filter(r => r.node === key && matches(r.when,state))) {
        if (!blocks.some(b => b.id === rule.block)) throw Error('필수 원작 대사가 숨겨진 분기');
      }
      if (contract.must_include_block_ids.some(id => !blocks.some(b => b.id === id))) throw Error('필수 장면 누락');
      const checkpoint = data.main_story.findIndex(r => r.node === key);
      if (checkpoint >= 0 && !mainStory.includes(key)) {
        if (checkpoint !== mainStory.length) throw Error('필수 본줄기를 건너뛴 경로');
        if (data.main_story[checkpoint].required_block_ids.some(id => !blocks.some(b => b.id === id))) throw Error('첫 방문 필수 본문 누락');
        mainStory.push(key);
      }
      if (['boundary', 'ending'].includes(node.kind) && mainStory.length !== data.main_story.length) throw Error('필수 본줄기 전에 끝나는 경로');
      if (blocks.some(b => b.speaker && !cast.includes(b.speaker))) throw Error('없는 동료가 말하는 장면');
      const choices = node.choices.filter(c => matches(c.when, state));
      if(choices.length>1&&!automatic(key,state)){
        const fork=key+'|'+choices.map(c=>c.id).sort().join('|');
        if(decisions.has(fork))throw Error('같은 분기로 돌아가 다른 선택을 수집할 수 없습니다.');
        decisions.add(fork);
      }
      if (!choices.length && !['boundary', 'ending'].includes(node.kind)) throw Error('막힌 분기');
      sections.push({node, blocks, choices, state: clone(state), selected: saved[index]});
      if (index === saved.length) return {node, state, events, knowledge, sections, mainStory};
      const choice = choices.find(c => c.id === saved[index]);
      if (!choice) throw Error('이 경로에서는 할 수 없는 선택');
      const auto = automatic(key, state);
      if (auto && auto.choice !== choice.id) throw Error('필수 자동 진행을 건너뛴 경로');
      apply(choice.effects, state);
      if (!matches(contract.after, state)) throw Error('장면 후 조건 불일치');
      for (const event of data.events.filter(e => e.trigger_choice === choice.id && matches(e.when === undefined ? true : e.when, state))) {
        if (events.includes(event.id) || event.requires_events.some(id => !events.includes(id))) throw Error('사건 순서 불일치');
        events.push(event.id);
        for (const gain of event.knowledge_gained) {
          knowledge[gain.character_id] ||= [];
          if (!knowledge[gain.character_id].includes(gain.fact_id)) knowledge[gain.character_id].push(gain.fact_id);
        }
      }
      key = choice.target;
    }
  }
  function reference(ref) {
    const name = data.labels[ref.catalog]?.[ref.id];
    if (!name) throw Error('찾을 수 없는 참조');
    if (!ref.particle) return name;
    const code = name.codePointAt(name.length - 1) - 0xac00, jong = code % 28;
    if (code < 0 || code >= 11172) throw Error('조사를 붙일 수 없는 이름');
    const pair = ref.particle.split('/');
    return name + (jong && !(ref.particle === '으로/로' && jong === 8) ? pair[0] : pair[1]);
  }
  function text(spans, state, blockId) {
    if (typeof spans === 'string') return spans;
    return spans.map(span => {
      if ('text' in span) return span.text;
      if (span.ref) return reference(span.ref);
      if (span.state) {
        if (!(span.state in state)) throw Error('찾을 수 없는 서술 상태');
        return span.catalog ? reference({catalog:span.catalog,id:state[span.state],...(span.particle?{particle:span.particle}:{})}) : String(state[span.state]);
      }
      const source = span.source, raw = Array.from(source.literal_ids.map(id => data.literals[id]).join(''));
      const edits = source.bindings.map(b => ({start:b.start, end:b.end, value:reference(b.ref)}));
      for (const insert of data.insertions[blockId] || []) {
        const value = insert.ref ? reference(insert.ref) : insert.state ? (insert.state_ref_catalog ? reference({catalog:insert.state_ref_catalog,id:state[insert.state],...(insert.particle ? {particle:insert.particle} : {})}) : String(state[insert.state])) : '[' + insert.placeholder + ']';
        edits.push({start:insert.offset, end:insert.offset + (insert.replace_length || 0), value});
      }
      edits.sort((a,b) => a.start - b.start || a.end - b.end);
      let result = '', offset = 0;
      for (const edit of edits) { result += raw.slice(offset,edit.start).join('') + edit.value; offset = edit.end; }
      return result + raw.slice(offset).join('');
    }).join('');
  }
  function element(tag, value, className) {
    const e = create(tag); e.textContent = value;
    if (className) e.className = className;
    return e;
  }
  function readFromSection(index) {
    const sections = document.getElementById('manuscript').children;
    const section = index === undefined ? sections[sections.length - 1] : sections[index];
    if (!section) return;
    section.tabIndex=-1;
    try {section.focus({preventScroll:true});section.scrollIntoView({block:'start',behavior:'instant'});} catch (_) { /* A paginated EPUB host may manage focus/scroll itself. */ }
  }
  function quoted(body) {
    const value=body.trim();
    return value.startsWith('“')&&value.endsWith('”') ? value : '“'+value+'”';
  }
  function appendProse(root, body, blockId, sourceBlocks) {
    for (const paragraph of body.split(/\n{2,}/)) {
      const p=element('p',paragraph);
      p.dataset.blockId=blockId;
      if(sourceBlocks)p.dataset.sourceBlocks=JSON.stringify(sourceBlocks);
      root.append(p);
    }
  }
  function redraw() {
    for(let count=0;count<data.nodes.length;count++){
      const current=replay(route),auto=automatic(current.node.id,current.state);
      if(!auto)break;
      route.push(auto.choice);
      if(count===data.nodes.length-1)throw Error('자동 진행 반복');
    }
    const packet = replay(route), manuscript = document.getElementById('manuscript');
    manuscript.replaceChildren();
    let priorChapter=null;
    for (const section of packet.sections) {
      const root = create('section');
      root.dataset.nodeId=section.node.id;
      root.dataset.storyRole=data.main_story.some(r=>r.node===section.node.id)?'main':'optional';
      root.setAttribute('aria-label',text(section.node.title,section.state));
      const chapter=data.chapters?.find(c=>c.prefixes.some(prefix=>section.node.id.startsWith(prefix)));
      if(chapter&&chapter.id!==priorChapter){
        if(priorChapter)root.append(element('h2','제'+Number(chapter.id.slice(7))+'장 · '+text(chapter.title,section.state)));
        const art=data.covers.images[chapter.id];
        if(art){
          const figure=create('figure'),img=create('img');
          figure.className='chapter-cover';figure.dataset.chapterCover=chapter.id;
          img.src=art.src;img.alt=art.alt;img.width=art.width;img.height=art.height;
          figure.append(img);root.append(figure);
        }
        priorChapter=chapter.id;
      }
      for (const b of section.blocks) {
        if(b.provenance.origin==='source_exact'){
          const group=sourceGroups.get(b.id);
          if(!group||group.node!==section.node.id)throw Error('서사에 연결되지 않은 원문');
          if(group.block_ids[0]!==b.id)continue;
          const originals=group.block_ids.map(id=>section.blocks.find(block=>block.id===id));
          if(originals.some(block=>!block))throw Error('서로 다른 조건의 대사를 합칠 수 없습니다.');
          const edition=group.editions[data.edition];
          // Joining happens only in the reading view. Literal IDs, raw strings,
          // bindings and branch conditions remain in the immutable story data.
          const source=originals.map(block=>text(block.text,section.state,block.id)).join(group.kind==='inscription'?' ':'').replace(/\s+/g,' ').trim();
          const replacement=presentation.script_overrides[b.id]?.writing_overrides.text;
          const content=replacement?text(replacement,section.state):group.kind==='narration'?text(edition.body,section.state):source;
          const body=group.kind==='narration'?content:quoted(content);
          appendProse(root,text(edition.before,section.state)+body+text(edition.after,section.state),b.id,group.block_ids);
        }else{
          let body=text(b.text,section.state,b.id);
          if(b.speaker){
            const entry=presentation.dialogues[b.id];
            if(!entry||entry.speaker!==b.speaker)throw Error('서사에 연결되지 않은 화자');
            const edition=entry.editions[data.edition];
            body=text(edition.before,section.state)+quoted(body)+text(edition.after,section.state);
          }
          appendProse(root,body,b.id);
        }
      }
      if (section.selected && !automatic(section.node.id,section.state)) root.append(element('p','선택: ' + text(section.choices.find(c => c.id === section.selected).label,section.state),'selected'));
      manuscript.append(root);
    }
    const current = packet.sections.at(-1), box = document.getElementById('choices');
    box.replaceChildren();
    for (const choice of current.choices) {
      const button = element('button',text(choice.label,packet.state));
      button.type = 'button'; button.dataset.choice = choice.id;
      button.addEventListener('click',() => {
        try {
          const firstNewSection = route.length + 1;
          const next = [...route,choice.id]; let notice = '';
          for (let count = 0; count < data.nodes.length; count++) {
            const p = replay(next), auto = automatic(p.node.id,p.state);
            if (!auto) { route = next; redraw(); message(notice); readFromSection(firstNewSection); return; }
            next.push(auto.choice); notice = auto.reason;
          }
          throw Error('자동 진행 반복');
        } catch (e) { message(e.message); }
      });
      box.append(button);
    }
    const info = document.getElementById('state'); info.replaceChildren();
    const companions = [...packet.state['companions.starting'],...packet.state['companions.optional_recruits']];
    info.append(element('p','동행: ' + companions.map(id => data.labels.characters[id] || id).join(', ')));
    info.append(element('p','성 안에서 들른 곳: ' + packet.state['event.city_visits'] + ' · 금화: ' + packet.state['event.gold']));
    for (const id of packet.state['companions.starting']) info.append(element('p',data.labels.characters[id] + ': ' + (data.labels.equipment[packet.state['event.weapon.' + id]] || '미정')));
    if (companions.includes('mad_joe')) info.append(element('p',data.labels.characters.mad_joe + ': ' + (data.labels.equipment[packet.state['event.weapon.mad_joe']] || '미정')));
    if (packet.state['event.shield_owner']) info.append(element('p','발견 방패 장착자: ' + data.labels.characters[packet.state['event.shield_owner']]));
    for(const id of ['protagonist','skeleton','polaris']){
      if(id!=='protagonist'&&!companions.includes(id))continue;
      const weapon=packet.state['event.weapon.'+id];
      if(weapon)info.append(element('p',data.labels.characters[id]+': '+(data.labels.equipment[weapon]||'미정')));
    }
    if(packet.state['event.chapter02.spear_owner'])info.append(element('p',data.labels.terms.oedipus_spear+': '+data.labels.characters[packet.state['event.chapter02.spear_owner']]));
    if (!current.choices.length) box.append(element('p',`제${data.chapters.length}장 끝. 선택한 동료·장비·경험은 다음 장으로 인계됩니다. ${data.chapters.length+1}장 이후는 이 판본에서 아직 집필 전이며, 전편 개요와 분기 미리보기는 제작 자료입니다.`));
    document.getElementById('back').disabled = !packet.sections.some(s=>s.selected&&!automatic(s.node.id,s.state));
    persist();
  }
  document.getElementById('restart').addEventListener('click',() => { route = []; redraw(); message('처음부터 시작합니다.'); readFromSection(0); });
  document.getElementById('back').addEventListener('click',() => {
    const next = [...route]; next.pop();
    while (next.length && automatic(replay(next).node.id,replay(next).state)) next.pop();
    route = next; redraw(); message('직전 선택으로 돌아왔습니다. 상태도 경로에서 다시 계산했습니다.'); readFromSection();
  });
  document.getElementById('save').addEventListener('click',() => {
    if(epub){persist();message(storageAvailable?'선택 기록을 이 리더의 저장소에 보관했습니다. 계정·기기간 동기화는 아닙니다.':'이 리더에서는 선택 기록 저장이 제한됩니다. 현재 읽기는 계속할 수 있습니다.');return;}
    const value = JSON.stringify({fingerprint:data.fingerprint,route},null,2), a = document.createElement('a');
    const url = URL.createObjectURL(new Blob([value],{type:'application/json'}));
    a.href = url; a.download = 'novel-route.json'; a.click(); URL.revokeObjectURL(url);
    message('경로만 저장했습니다. 동료·금화·지식을 임의 저장하지 않습니다.');
  });
  document.getElementById('load').addEventListener('click',() => {
    if(!epub){document.getElementById('file').click();return;}
    try {route=storedRoute();redraw();message('선택 기록을 검증해 불러왔습니다.');readFromSection();}catch(e){message(e.message);}
  });
  document.getElementById('file')?.addEventListener('change',async event => {
    try {
      const file = event.target.files[0]; if (!file || file.size > 32768) throw Error('저장 파일이 너무 큽니다.');
      const saved = JSON.parse(await file.text());
      if (Object.keys(saved).sort().join(',') !== 'fingerprint,route' || saved.fingerprint !== data.fingerprint) throw Error('다른 판본 또는 변조된 저장 파일입니다.');
      const packet = replay(saved.route);
      if (automatic(packet.node.id,packet.state)) throw Error('자동 진행이 누락된 저장 경로입니다.');
      route = [...saved.route]; redraw(); message('경로를 검증하고 상태를 다시 계산했습니다.'); readFromSection();
    } catch (e) { message(e.message); }
    event.target.value = '';
  });
  if(epub){
    let notice='';
    try {const probe=storageKey+':probe';localStorage.setItem(probe,'1');localStorage.removeItem(probe);storageAvailable=true;
      if(localStorage.getItem(storageKey))route=storedRoute();
    }catch(e){notice='저장 기록을 복원하지 못했습니다. '+e.message;}
    try {
      redraw();
      document.getElementById('epub-app').hidden=false;
      document.getElementById('runtime-status').textContent=storageAvailable?'선택 기능 작동 · 선택 기록은 이 리더에 자동 저장됩니다. 계정·기기간 동기화는 아닙니다.':'선택 기능 작동 · 이 리더에서는 기록 저장이 제한됩니다. 책을 닫으면 진행이 사라질 수 있습니다.';
      if(notice)message(notice);
    }catch(e){document.getElementById('runtime-status').textContent='이 리더에서는 선택 기능을 실행하지 못했습니다. 아래의 일반 본문 또는 웹 B안을 이용해 주세요. '+e.message;}
  }else redraw();
})();
