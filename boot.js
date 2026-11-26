/* Boot peripherals: telemetry, in-app feedback, first-run screen.

   Deliberately separate from the main bundle. It talks to the game only through
   `window.__sb` and `window.__track`, so it can be loaded after the app script
   (defer) without touching its closure. Keep it that way — the moment it needs
   a game variable, it belongs back in index.html.
*/
/* Playtest telemetry. Deliberately tiny and never in the way:
   - one row per event in telemetry_events (insert-only; RLS denies reads)
   - no PII beyond the auth id already on the wallet, plus a local anon id
   - every path wrapped: telemetry must never throw into the game */
(function(){
  var KEY='pd_anon_id';
  var anon=null;
  try{ anon=localStorage.getItem(KEY); }catch(_){}
  if(!anon){
    anon=(window.crypto && crypto.randomUUID) ? crypto.randomUUID() : 'a'+Date.now()+Math.random().toString(16).slice(2);
    try{ localStorage.setItem(KEY, anon); }catch(_){}
  }
  var uid=null;
  function track(name, meta){
    try{
      var s=window.__sb;
      if(!s) return;
      s.from('telemetry_events').insert({ user_id:uid, anon_id:anon, kind:'ui', name:String(name).slice(0,64), meta:meta||null }).then(function(){}, function(){});
    }catch(_){}
  }
  window.__track=track;
  try{
    var s=window.__sb;
    if(s && s.auth){
      s.auth.getSession().then(function(r){ uid = (r && r.data && r.data.session) ? r.data.session.user.id : null; }, function(){});
      s.auth.onAuthStateChange(function(_e, sess){ uid = (sess && sess.user) ? sess.user.id : null; });
    }
  }catch(_){}
  track('app_open', { w:window.innerWidth, h:window.innerHeight });
  window.addEventListener('error', function(e){
    track('js_error', { m:String(e.message||'').slice(0,200), f:String(e.filename||'').split('/').pop(), l:e.lineno });
  });
  window.addEventListener('unhandledrejection', function(e){
    var r=e.reason; track('js_rejection', { m:String((r && r.message) || r || '').slice(0,200) });
  });
  // Which screens actually get used — the cheapest funnel signal there is.
  document.addEventListener('click', function(ev){
    var t=ev.target && ev.target.closest ? ev.target.closest('.tab[data-tab]') : null;
    if(t) track('screen', { s:t.dataset.tab });
  }, true);

  /* ---- in-app feedback ------------------------------------------------
     Usage events answer "where". This answers "why". A tester who hits a wall
     will not write an email; they will close the tab. */
  var fbStyle=document.createElement('style');
  fbStyle.textContent=
    '#pd-fb-btn{position:fixed;right:16px;bottom:calc(16px + env(safe-area-inset-bottom));width:44px;height:44px;'+
    'border-radius:50%;z-index:9998;cursor:pointer;display:flex;align-items:center;justify-content:center;'+
    'background:rgba(12,14,22,.92);border:1px solid rgba(246,241,230,.22);color:#e8c46a;font-size:17px;line-height:1;'+
    'box-shadow:0 8px 22px -12px rgba(0,0,0,.9);backdrop-filter:blur(8px);}'+
    '#pd-fb-btn:hover{border-color:rgba(232,196,106,.55);}'+
    '#pd-fb-wrap{position:fixed;inset:0;z-index:9999;display:none;align-items:center;justify-content:center;'+
    'background:rgba(4,5,9,.74);padding:16px;}'+
    '#pd-fb-wrap.on{display:flex;}'+
    '#pd-fb-card{width:min(430px,100%);background:#14161f;border:1px solid rgba(246,241,230,.14);border-radius:16px;'+
    'padding:16px;font-family:inherit;color:#f6f1e6;box-shadow:0 30px 60px -30px rgba(0,0,0,.95);}'+
    '#pd-fb-card h3{margin:0 0 4px;font-size:16px;font-weight:700;}'+
    '#pd-fb-card p{margin:0 0 12px;font-size:12px;line-height:1.5;color:rgba(246,241,230,.62);}'+
    '#pd-fb-msg{width:100%;box-sizing:border-box;min-height:104px;resize:vertical;background:#0b0d14;'+
    'border:1px solid rgba(246,241,230,.16);border-radius:10px;padding:10px 12px;color:#f6f1e6;font:inherit;font-size:13px;}'+
    '#pd-fb-msg:focus{outline:none;border-color:rgba(232,196,106,.55);}'+
    '#pd-fb-row{display:flex;gap:8px;justify-content:flex-end;margin-top:12px;align-items:center;}'+
    '#pd-fb-note{margin-right:auto;font-size:11px;color:rgba(246,241,230,.5);}'+
    '#pd-fb-row button{font:inherit;font-size:12px;font-weight:700;padding:8px 14px;border-radius:9px;cursor:pointer;'+
    'border:1px solid rgba(246,241,230,.18);background:transparent;color:#f6f1e6;}'+
    '#pd-fb-send{background:#e8c46a;border-color:#e8c46a;color:#14100a;}'+
    '#pd-fb-send[disabled]{opacity:.5;cursor:default;}';
  document.head.appendChild(fbStyle);

  var wrap=document.createElement('div');
  wrap.id='pd-fb-wrap';
  wrap.innerHTML='<div id="pd-fb-card" role="dialog" aria-modal="true" aria-labelledby="pd-fb-title">'+
    '<h3 id="pd-fb-title">Send feedback</h3>'+
    '<p>Something broken, confusing, or missing? A sentence is enough.</p>'+
    '<textarea id="pd-fb-msg" maxlength="2000" placeholder="What happened?"></textarea>'+
    '<div id="pd-fb-row"><span id="pd-fb-note"></span>'+
    '<button type="button" id="pd-fb-cancel">Cancel</button>'+
    '<button type="button" id="pd-fb-send" disabled>Send</button></div></div>';
  document.body.appendChild(wrap);

  var btn=document.createElement('button');
  btn.type='button'; btn.id='pd-fb-btn'; btn.textContent='\u270E';
  btn.title='Send feedback'; btn.setAttribute('aria-label','Send feedback');
  document.body.appendChild(btn);

  var msg=wrap.querySelector('#pd-fb-msg');
  var send=wrap.querySelector('#pd-fb-send');
  var note=wrap.querySelector('#pd-fb-note');
  var busy=false;

  function activeScreen(){
    var s=document.querySelector('.screen.active');
    return s ? s.id : 'unknown';
  }
  function openFb(){ wrap.classList.add('on'); note.textContent=''; msg.value=''; send.disabled=true; setTimeout(function(){ msg.focus(); }, 40); track('feedback_open', null); }
  function closeFb(){ wrap.classList.remove('on'); }
  /* ---- first run ------------------------------------------------------
     A tester who lands with no context opens one pack and leaves. One screen,
     once, and it points at the single next action. */
  try{
    if(!localStorage.getItem('pd_seen_intro_v1')){
      var iStyle=document.createElement('style');
      iStyle.textContent=
        '#pd-intro{position:fixed;inset:0;z-index:9997;display:flex;align-items:center;justify-content:center;'+
        'background:radial-gradient(120% 90% at 50% 0%,rgba(30,34,52,.96),rgba(4,5,9,.97));padding:20px;}'+
        '#pd-intro-card{width:min(430px,100%);background:#14161f;border:1px solid rgba(246,241,230,.14);border-radius:18px;'+
        'padding:22px;color:#f6f1e6;box-shadow:0 40px 80px -40px #000;text-align:left;}'+
        '#pd-intro-kick{font-family:\'JetBrains Mono\',monospace;font-size:9.5px;letter-spacing:.22em;text-transform:uppercase;'+
        'color:#e8c46a;margin-bottom:8px;}'+
        '#pd-intro-card h2{margin:0 0 8px;font-family:Fraunces,serif;font-weight:900;font-size:24px;line-height:1.15;}'+
        '#pd-intro-card p{margin:0 0 10px;font-size:13px;line-height:1.55;color:rgba(246,241,230,.7);}'+
        '#pd-intro-card p b{color:#f6f1e6;}'+
        '#pd-intro-row{display:flex;flex-direction:column;gap:8px;margin-top:16px;}'+
        '#pd-intro-row button{font:inherit;font-size:13px;font-weight:700;padding:11px 14px;border-radius:10px;cursor:pointer;'+
        'border:1px solid rgba(246,241,230,.18);background:transparent;color:#f6f1e6;}'+
        '#pd-intro-go{background:#e8c46a;border-color:#e8c46a;color:#14100a;}';
      document.head.appendChild(iStyle);

      var introEl=document.createElement('div');
      introEl.id='pd-intro';
      introEl.setAttribute('role','dialog');
      introEl.setAttribute('aria-modal','true');
      introEl.setAttribute('aria-labelledby','pd-intro-title');
      introEl.innerHTML='<div id="pd-intro-card">'+
        '<div id="pd-intro-kick">Early playtest</div>'+
        '<h2 id="pd-intro-title">Welcome to PackDrop</h2>'+
        '<p>Open boosters, collect the cards you pull, and fill <b>binders</b> that other players can visit.</p>'+
        '<p>Everything here is still being built. If a screen confuses you or something breaks, tap the <b>pencil</b> in the corner and tell us \u2014 that is the most useful thing a tester can do.</p>'+
        '<div id="pd-intro-row">'+
        '<button type="button" id="pd-intro-go">Open my first pack</button>'+
        '<button type="button" id="pd-intro-skip">Look around first</button></div></div>';
      document.body.appendChild(introEl);
      track('intro_shown', null);

      function closeIntro(){
        try{ localStorage.setItem('pd_seen_intro_v1','1'); }catch(_){}
        introEl.remove();
      }
      document.getElementById('pd-intro-skip').addEventListener('click', closeIntro);
      document.addEventListener('keydown', function(e){
        if(e.key === 'Escape' && document.getElementById('pd-intro')) closeIntro();
      });
      document.getElementById('pd-intro-go').addEventListener('click', function(){
        track('intro_cta', null);
        closeIntro();
        var t=document.querySelector('.tab[data-tab="packs-screen"]');
        if(t) t.click();
      });
    }
  }catch(_){}

  btn.addEventListener('click', openFb);
  wrap.querySelector('#pd-fb-cancel').addEventListener('click', closeFb);
  wrap.addEventListener('click', function(e){ if(e.target===wrap) closeFb(); });
  document.addEventListener('keydown', function(e){ if(e.key==='Escape' && wrap.classList.contains('on')) closeFb(); });
  msg.addEventListener('input', function(){ send.disabled = msg.value.trim().length < 3 || busy; });

  send.addEventListener('click', function(){
    var text=msg.value.trim();
    if(text.length < 3 || busy) return;
    busy=true; send.disabled=true; note.textContent='Sending\u2026';
    var s=window.__sb;
    var done=function(ok){
      busy=false;
      if(ok){ note.textContent='Sent \u2014 thank you.'; track('feedback_sent', {len:text.length}); setTimeout(closeFb, 1100); }
      else { note.textContent='Could not send. Try again.'; send.disabled=false; }
    };
    if(!s){ done(false); return; }
    try{
      s.from('feedback').insert({ user_id:uid, anon_id:anon, screen:activeScreen(), message:text })
        .then(function(r){ done(!r || !r.error); }, function(){ done(false); });
    }catch(_){ done(false); }
  });
})();
