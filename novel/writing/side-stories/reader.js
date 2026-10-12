'use strict';
(() => {
  const data=JSON.parse(document.getElementById('side-data').textContent);
  const $=id=>document.getElementById(id);
  const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const paragraphs=value=>String(value).split(/\n\n+/).map(p=>'<p>'+escape(p)+'</p>').join('');
  let chapterIndex=0, choices={};
  function draw(){
    const chapter=data.chapters[chapterIndex];let text='<h2>'+escape('제'+chapter.number+'장 · '+chapter.title)+'</h2>',pending=null;
    for(const unit of chapter.units){
      for(const block of unit.blocks.filter(b=>['main','reaction'].includes(b.kind))){
        if(block.kind==='main')text+='<h3>'+escape(block.title)+'</h3>';
        text+=paragraphs(block.text);
      }
      for(const story of data.stories.filter(s=>s.reaction_unit===unit.id && Object.hasOwn(choices,s.id))){
        text+='<section class="side-memory" data-side-memory="'+escape(story.id)+'" data-mode="'+choices[story.id]+'"><p class="side-badge">곁가지의 후속 반응 · 창작 초고</p>'+paragraphs(story[choices[story.id]==='take'?'on_participate':'on_skip'])+'</section>';
      }
      for(const block of unit.blocks.filter(b=>['choice','automatic'].includes(b.kind)))text+=paragraphs(block.text);
      const story=data.stories.find(s=>s.anchor_unit===unit.id);
      if(story){
        text+='<section class="side-story" data-side-story="'+escape(story.id)+'"><p class="side-badge">선택 곁가지 · 창작 초고</p><h3>'+escape(story.title)+'</h3>'+paragraphs(story.prompt);
        if(!Object.hasOwn(choices,story.id)){pending=story;text+='</section>';break;}
        const mode=choices[story.id];
        text+='<p class="side-badge">선택: '+escape(story[mode==='take'?'participate_label':'skip_label'])+'</p>'+paragraphs(story[mode==='take'?'participate':'skip'])+'</section>';
      }
      for(const block of unit.blocks.filter(b=>b.kind==='outcome'))text+='<p class="core-outcome"><small>필수 본줄기 결과 · '+escape(block.text)+'</small></p>';
    }
    $('side-content').innerHTML=text;
    $('side-choices').innerHTML=pending?['take','skip'].map(mode=>'<button type="button" data-side-choice="'+mode+'" data-story="'+escape(pending.id)+'">'+escape(pending[mode==='take'?'participate_label':'skip_label'])+'</button>').join(''):'';
    $('side-next').hidden=!!pending||chapterIndex===data.chapters.length-1;
    $('side-prev').disabled=chapterIndex===0;
    $('side-progress').textContent=chapter.number+' / '+data.chapters.length+'장 · 곁가지 '+Object.keys(choices).length+'개 선택';
    if(!pending&&chapterIndex===data.chapters.length-1)$('side-content').insertAdjacentHTML('beforeend','<p class="notice" id="side-complete">모든 장의 필수 본줄기와 선택한 곁가지를 표시했습니다. 실제 읽음이나 본문·원문 전체의 출판 승인을 뜻하지 않습니다.</p>');
  }
  document.addEventListener('click',event=>{
    const button=event.target.closest('button');if(!button||button.disabled)return;
    if(button.dataset.sideChoice){
      const story=data.stories.find(s=>s.id===button.dataset.story&&s.chapter_id===data.chapters[chapterIndex].id);
      if(!story||Object.hasOwn(choices,story.id)||!['take','skip'].includes(button.dataset.sideChoice))return;
      choices[story.id]=button.dataset.sideChoice;draw();
      const scene=document.querySelector('[data-side-story="'+story.id+'"]');scene.scrollIntoView({block:'start',behavior:'instant'});
    }else if(button.id==='side-next'&&chapterIndex<data.chapters.length-1&&Object.hasOwn(choices,data.stories[chapterIndex].id)){chapterIndex++;draw();scrollTo({top:0,behavior:'instant'});}
    else if(button.id==='side-prev'){chapterIndex--;draw();scrollTo({top:0,behavior:'instant'});}
    else if(button.id==='side-restart'){chapterIndex=0;choices={};draw();scrollTo({top:0,behavior:'instant'});}
  });
  draw();
})();
