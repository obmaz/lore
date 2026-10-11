/* Offline reader: save only choice IDs; reconstruct state/knowledge by replay. */
(() => {
  'use strict';
  const data = JSON.parse(document.getElementById('chapter-data').textContent);
  const nodes = Object.fromEntries(data.nodes.map(n => [n.id, n]));
  const clone = value => JSON.parse(JSON.stringify(value));
  let route = [];
  const message = text => { document.getElementById('message').textContent = text; };
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
    return rules[0];
  }
  function replay(saved) {
    if (!Array.isArray(saved) || saved.length > 160 || saved.some(x => typeof x !== 'string')) throw Error('잘못된 경로');
    let key = data.entry;
    const state = clone(data.initial), events = [], knowledge = {}, sections = [];
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
      if (blocks.some(b => b.speaker && !cast.includes(b.speaker))) throw Error('없는 동료가 말하는 장면');
      const choices = node.choices.filter(c => matches(c.when, state));
      if (!choices.length && !['boundary', 'ending'].includes(node.kind)) throw Error('막힌 분기');
      sections.push({node, blocks, choices, state: clone(state), selected: saved[index]});
      if (index === saved.length) return {node, state, events, knowledge, sections};
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
    const e = document.createElement(tag); e.textContent = value;
    if (className) e.className = className;
    return e;
  }
  function readFromSection(index) {
    const sections = document.getElementById('manuscript').children;
    const section = index === undefined ? sections[sections.length - 1] : sections[index];
    section.querySelector('h2').focus({preventScroll:true});
    section.scrollIntoView({block:'start',behavior:'instant'});
  }
  function redraw() {
    const packet = replay(route), manuscript = document.getElementById('manuscript');
    manuscript.replaceChildren();
    for (const section of packet.sections) {
      const root = document.createElement('section');
      const heading = element('h2',text(section.node.title,section.state));
      heading.tabIndex = -1;
      root.append(heading);
      for (const b of section.blocks) {
        const p = element('p',text(b.text,section.state,b.id),b.provenance.origin === 'source_exact' ? 'quote' : '');
        p.dataset.blockId = b.id;
        if (b.speaker) p.prepend(element('small',data.labels.characters[b.speaker] || b.speaker),document.createElement('br'));
        root.append(p);
      }
      if (section.selected) root.append(element('p','선택: ' + text(section.choices.find(c => c.id === section.selected).label,section.state),'selected'));
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
          for (let count = 0; count < 8; count++) {
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
    info.append(element('p','탐방: ' + packet.state['event.city_visits'] + '/3곳 · 금화: ' + packet.state['event.gold']));
    for (const id of packet.state['companions.starting']) info.append(element('p',data.labels.characters[id] + ': ' + (data.labels.equipment[packet.state['event.weapon.' + id]] || '미정')));
    if (packet.state['event.slot6'] === 'mad_joe') info.append(element('p',data.labels.characters.mad_joe + ': ' + (data.labels.equipment[packet.state['event.weapon.mad_joe']] || '미정')));
    if (packet.state['event.shield_owner']) info.append(element('p','발견 방패 장착자: ' + data.labels.characters[packet.state['event.shield_owner']]));
    if (!current.choices.length) box.append(element('p','첫 챕터 끝. 선택한 동료·장비·경험은 다음 챕터 집필용 인계 상태로 보존됩니다. 다음 챕터 본문은 아직 없습니다.'));
    document.getElementById('back').disabled = !route.length;
  }
  document.getElementById('restart').addEventListener('click',() => { route = []; redraw(); message('처음부터 시작합니다.'); readFromSection(0); });
  document.getElementById('back').addEventListener('click',() => {
    const next = [...route]; next.pop();
    while (next.length && automatic(replay(next).node.id,replay(next).state)) next.pop();
    route = next; redraw(); message('직전 선택으로 돌아왔습니다. 상태도 경로에서 다시 계산했습니다.'); readFromSection();
  });
  document.getElementById('save').addEventListener('click',() => {
    const value = JSON.stringify({fingerprint:data.fingerprint,route},null,2), a = document.createElement('a');
    const url = URL.createObjectURL(new Blob([value],{type:'application/json'}));
    a.href = url; a.download = 'chapter01-route.json'; a.click(); URL.revokeObjectURL(url);
    message('경로만 저장했습니다. 동료·금화·지식을 임의 저장하지 않습니다.');
  });
  document.getElementById('load').addEventListener('click',() => document.getElementById('file').click());
  document.getElementById('file').addEventListener('change',async event => {
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
  redraw();
})();
