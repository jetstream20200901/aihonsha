/* AI本社：設定・連絡先の画面に、会社の画面と同じ左のメニューとデザイン（A・B・C）を付ける。
   使い方：<body data-page="settings"> に <script src="theme.js"></script> を置く。
   デザインは 設定.json の design（会社フォルダとつながっているとき）→ この画面で最後に選んだもの → A の順。 */
(function () {
  var page = document.body.getAttribute('data-page') || '';
  var NAV = [['dashboard.html#home', 'home', 'ホーム'], ['dashboard.html#decisions', 'decision', '判断すること'], ['dashboard.html#strategy', 'strategy', '戦略とPDCA'],
    ['dashboard.html#depts', 'depts', '部署'], ['dashboard.html#numbers', 'money', '数字'], ['dashboard.html#cash', 'cash', '資金繰り'], ['dashboard.html#minutes', 'minutes', '議事録'],
    ['dashboard.html#docs', 'docs', '書類'], ['dashboard.html#todo', 'todo', 'やること'], ['dashboard.html#requests', 'ai', '頼んだこと'], ['contacts.html', 'contacts', '連絡先'], ['settings.html', 'settings', '設定']];
  var side = document.createElement('aside'); side.className = 'side';
  side.innerHTML = '<div class="brand"><div class="logo">AI</div><span>AI本社</span></div><nav id="nav">' +
    NAV.map(function (n) { var on = (page === 'settings' && n[1] === 'settings') || (page === 'contacts' && n[1] === 'contacts');
      return '<a href="' + n[0] + '" class="' + (on ? 'on' : '') + '"><img class="ic" src="img/' + n[1] + '.png" alt=""><span class="lb">' + n[2] + '</span></a>'; }).join('') + '</nav>' +
    '<div class="sidefoot"><div class="design"><span>デザイン</span><button type="button" data-design="A" title="静かな経営室">A</button><button type="button" data-design="B" title="コマンドセンター">B</button><button type="button" data-design="C" title="AI社員チーム">C</button></div></div>';
  /* 今の中身を .main に入れ、左にメニューを置く */
  var app = document.createElement('div'); app.className = 'app';
  var main = document.createElement('main'); main.className = 'main';
  Array.prototype.slice.call(document.body.childNodes).forEach(function (n) { if (!(n.nodeType === 1 && (n.tagName === 'SCRIPT' || n.classList.contains('toast')))) main.appendChild(n); });
  app.appendChild(side); app.appendChild(main); document.body.insertBefore(app, document.body.firstChild);

  var apply = function (x) { x = /^[ABC]$/.test(x) ? x : 'A'; document.body.classList.remove('A', 'B', 'C'); document.body.classList.add(x);
    Array.prototype.forEach.call(document.querySelectorAll('[data-design]'), function (b) { b.classList.toggle('on', b.dataset.design === x); });
    var sel = document.querySelector('select[name="design"]'); if (sel && sel.value !== x) sel.value = x; };
  var saved = ''; try { saved = localStorage.getItem('aihonsha-design') || ''; } catch (e) {}
  apply(saved);
  window.aihonshaDesign = apply;

  /* 会社フォルダとつながっていれば、設定.json のデザインに合わせる。画面で選んだら 設定.json にも残す */
  var idb = function (fn) { return new Promise(function (ok) { try { var r = indexedDB.open('aihonsha', 1); r.onupgradeneeded = function () { r.result.createObjectStore('h'); };
    r.onsuccess = function () { var q = fn(r.result.transaction('h', 'readonly').objectStore('h')); q.onsuccess = function () { ok(q.result); }; q.onerror = function () { ok(null); }; }; r.onerror = function () { ok(null); }; } catch (e) { ok(null); } }); };
  var dir = function () { return idb(function (s) { return s.get('dir'); }).then(function (h) { return h && h.queryPermission({ mode: 'readwrite' }).then(function (p) { return p === 'granted' ? h : null; }); }).catch(function () { return null; }); };
  dir().then(function (h) { if (!h) return; return h.getFileHandle('設定.json').then(function (f) { return f.getFile(); }).then(function (f) { return f.text(); }).then(function (t) { var st = JSON.parse(t || '{}'); if (st.design) apply(st.design); }); }).catch(function () {});
  document.addEventListener('click', function (ev) {
    var b = ev.target.closest('[data-design]'); if (!b) return; var x = b.dataset.design;
    try { localStorage.setItem('aihonsha-design', x); } catch (e) {}
    apply(x);
    dir().then(function (h) { if (!h) return; return h.getFileHandle('設定.json').then(function (fh) { return fh.getFile().then(function (f) { return f.text(); }).then(function (t) {
      var st = JSON.parse(t || '{}'); st.design = x; return fh.createWritable().then(function (w) { return w.write(JSON.stringify(st, null, 1) + '\n').then(function () { return w.close(); }); }); }); }); }).catch(function () {});
  });
  document.addEventListener('change', function (ev) { if (ev.target.name === 'design') { try { localStorage.setItem('aihonsha-design', ev.target.value); } catch (e) {} apply(ev.target.value); } });
})();
