'use strict';
(() => {
  const data=JSON.parse(document.getElementById('side-data').textContent);
  const $=id=>document.getElementById(id);
  const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const paragraphs=value=>String(value).split(/\n\n+/).map(p=>'<p>'+escape(p)+'</p>').join('');
  let chapterIndex=0, choices={}, approaches={}, pending=null;
  function draw(){
    const chapter=data.chapters[chapterIndex];let text='<h2>'+escape('제'+chapter.number+'장 · '+chapter.title)+'</h2>';
    pending=null;
    units:for(const unit of chapter.units){
      for(const block of unit.blocks.filter(b=>['main','reaction'].includes(b.kind))){
        if(block.kind==='main')text+='<h3>'+escape(block.title)+'</h3>';
        text+=paragraphs(block.text);
      }
      for(const story of data.stories.filter(s=>s.reaction_unit===unit.id && Object.hasOwn(choices,s.id))){
        const mode=choices[story.id], approach=story.approach?.options.find(o=>o.id===approaches[story.id]);
        const body=mode==='skip'?story.on_skip:approach?approach.reaction:story.on_participate;
        text+='<section class="side-memory" data-side-memory="'+escape(story.id)+'" data-mode="'+mode+'" data-approach="'+escape(approach?.id||'')+'"><p class="side-badge">앞선 선택이 이어지는 장면 · 창작 초고</p>'+paragraphs(body)+'</section>';
      }
      for(const block of unit.blocks.filter(b=>['choice','automatic'].includes(b.kind)))text+=paragraphs(block.text);
      for(const story of data.stories.filter(s=>s.anchor_unit===unit.id)){
        text+='<section class="side-story" data-side-story="'+escape(story.id)+'"><p class="side-badge">선택 곁가지 · 창작 초고</p><h3>'+escape(story.title)+'</h3>'+paragraphs(story.prompt);
        if(!Object.hasOwn(choices,story.id)){pending={story,kind:'entry'};text+='</section>';break units;}
        const mode=choices[story.id];
        text+='<p class="side-badge">선택: '+escape(story[mode==='take'?'participate_label':'skip_label'])+'</p>'+paragraphs(story[mode==='take'?'participate':'skip']);
        if(mode==='take'&&story.approach){
          text+='<div class="side-approach" data-side-approach="'+escape(story.id)+'"><p class="side-badge">이 만남의 다음 선택</p>'+paragraphs(story.approach.prompt);
          const selected=story.approach.options.find(o=>o.id===approaches[story.id]);
          if(!selected){pending={story,kind:'approach'};text+='</div></section>';break units;}
          text+='<p class="side-badge">선택: '+escape(selected.label)+'</p>'+paragraphs(selected.body)+'</div>';
          if(story.reaction_unit===null)text+=paragraphs(selected.reaction);
        }
        if(story.reaction_unit===null&&(mode==='skip'||!story.approach))text+=paragraphs(mode==='take'?story.on_participate:story.on_skip);
        text+='</section>';
      }
      for(const block of unit.blocks.filter(b=>b.kind==='outcome'))text+='<p class="core-outcome"><small>필수 본줄기 결과 · '+escape(block.text)+'</small></p>';
    }
    $('side-content').innerHTML=text;
    const options=!pending?[]:pending.kind==='entry'?['take','skip'].map(id=>({id,label:pending.story[id==='take'?'participate_label':'skip_label']})):pending.story.approach.options;
    $('side-choices').innerHTML=options.map(o=>'<button type="button" data-side-choice="'+escape(o.id)+'" data-choice-kind="'+pending.kind+'" data-story="'+escape(pending.story.id)+'">'+escape(o.label)+'</button>').join('');
    $('side-next').hidden=!!pending||chapterIndex===data.chapters.length-1;
    $('side-prev').disabled=chapterIndex===0;
    $('side-progress').textContent=chapter.number+' / '+data.chapters.length+'장';
    if(!pending&&chapterIndex===data.chapters.length-1)$('side-content').insertAdjacentHTML('beforeend','<p class="notice" id="side-complete">모든 장의 필수 본줄기와 선택한 곁가지를 표시했습니다. 실제 읽음이나 본문·원문 전체의 출판 승인을 뜻하지 않습니다.</p>');
  }
  document.addEventListener('click',event=>{
    const button=event.target.closest('button');if(!button||button.disabled)return;
    if(button.dataset.sideChoice){
      if(!pending||button.dataset.story!==pending.story.id||button.dataset.choiceKind!==pending.kind)return;
      const {story,kind}=pending, selected=button.dataset.sideChoice;
      if(kind==='entry'){
        if(Object.hasOwn(choices,story.id)||!['take','skip'].includes(selected))return;
        choices[story.id]=selected;
      }else{
        if(choices[story.id]!=='take'||Object.hasOwn(approaches,story.id)||!story.approach.options.some(o=>o.id===selected))return;
        approaches[story.id]=selected;
      }
      draw();
      document.querySelector('[data-side-'+(kind==='approach'?'approach':'story')+'="'+story.id+'"]').scrollIntoView({block:'start',behavior:'instant'});
    }else if(button.id==='side-next'&&!pending&&chapterIndex<data.chapters.length-1){chapterIndex++;draw();scrollTo({top:0,behavior:'instant'});}
    else if(button.id==='side-prev'&&chapterIndex>0){chapterIndex--;draw();scrollTo({top:0,behavior:'instant'});}
    else if(button.id==='side-restart'){chapterIndex=0;choices={};approaches={};draw();scrollTo({top:0,behavior:'instant'});}
  });
  draw();
})();
