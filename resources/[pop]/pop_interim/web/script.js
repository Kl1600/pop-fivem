/* pop_interim : panneau de l'agence d'intérim. Sélection (étape 1) puis Confirmer (étape 2). */
(function () {
  'use strict';

  var panel = document.getElementById('interim');
  var currentEl = document.getElementById('interim-current');
  var list = document.getElementById('interim-list');
  var cooldownEl = document.getElementById('interim-cooldown');
  var confirmBtn = document.getElementById('interim-confirm');
  var resignBtn = document.getElementById('interim-resign');
  var closeBtn = document.getElementById('interim-close');

  var state = { open: false, jobs: [], current: null, selected: null, cooldown: 0, sending: false };
  var timer = null;
  var session = 0;

  function selectable() {
    return state.jobs.filter(function (j) { return !isCurrent(j.id); });
  }

  function isCurrent(id) {
    return !!(state.current && state.current.id === id);
  }

  function locked() {
    return state.sending || state.cooldown > 0;
  }

  function updateButtons() {
    confirmBtn.disabled = locked() || !state.selected;
    resignBtn.disabled = locked();
    resignBtn.classList.toggle('pop-hidden', !state.current || !!state.current.unemployed);
  }

  function renderCooldown() {
    if (state.cooldown > 0) {
      cooldownEl.textContent = Pop.t('cooldown', state.cooldown);
      cooldownEl.classList.remove('pop-hidden');
    } else {
      cooldownEl.classList.add('pop-hidden');
    }
  }

  function renderList() {
    list.textContent = '';
    state.jobs.forEach(function (job) {
      var li = document.createElement('li');
      li.className = 'interim-item';
      var row = document.createElement('div');
      row.className = 'interim-row';
      var name = document.createElement('span');
      name.textContent = Pop.t('job_' + job.id);
      row.appendChild(name);

      if (isCurrent(job.id)) {
        li.classList.add('is-current');
        var tag = document.createElement('span');
        tag.className = 'interim-tag';
        tag.textContent = Pop.t('ui_current_tag');
        row.appendChild(tag);
      }
      li.appendChild(row);

      if (state.selected === job.id) {
        li.classList.add('is-selected');
        var desc = document.createElement('span');
        desc.className = 'pop-small interim-desc';
        desc.textContent = Pop.t('job_' + job.id + '_desc');
        li.appendChild(desc);
      }

      li.addEventListener('click', function () { select(job.id); });
      list.appendChild(li);
    });
    var sel = list.querySelector('.is-selected');
    if (sel && sel.scrollIntoView) sel.scrollIntoView({ block: 'nearest' });
  }

  function render() {
    currentEl.textContent = Pop.t('ui_current', state.current ? state.current.label : '');
    renderList();
    renderCooldown();
    updateButtons();
  }

  function select(id) {
    if (isCurrent(id) || state.selected === id) return;
    state.selected = id;
    renderList();
    updateButtons();
  }

  function move(step) {
    var jobs = selectable();
    if (!jobs.length) return;
    var idx = -1;
    for (var i = 0; i < jobs.length; i++) {
      if (jobs[i].id === state.selected) { idx = i; break; }
    }
    idx = idx === -1 ? (step > 0 ? 0 : jobs.length - 1) : (idx + step + jobs.length) % jobs.length;
    select(jobs[idx].id);
  }

  function stopTimer() {
    if (timer) { clearInterval(timer); timer = null; }
  }

  function startTimer() {
    stopTimer();
    if (state.cooldown <= 0) return;
    timer = setInterval(function () {
      state.cooldown = Math.max(0, state.cooldown - 1);
      renderCooldown();
      updateButtons();
      if (state.cooldown === 0) stopTimer();
    }, 1000);
  }

  function hide() {
    session += 1;
    state.open = false;
    state.sending = false;
    stopTimer();
    Pop.show(panel, false);
  }

  function send(name, data) {
    if (locked()) return;
    var activeSession = session;
    state.sending = true;
    updateButtons();
    Pop.post(name, data).then(function (res) {
      if (session !== activeSession) return;
      state.sending = false;
      if (res && res.ok) {
        hide();
      } else {
        updateButtons();
      }
    });
  }

  function confirm() {
    if (!state.selected) return;
    send('pop_interim:select', { id: state.selected });
  }

  Pop.on('pop_interim:open', function (d) {
    state.jobs = Array.isArray(d.jobs) ? d.jobs : [];
    state.current = d.current || null;
    state.cooldown = Math.max(0, Math.floor(Number(d.cooldown) || 0));
    state.selected = null;
    state.sending = false;
    state.open = true;
    Pop.translate(panel);
    render();
    startTimer();
    Pop.show(panel, true);
  });

  Pop.on('pop_interim:close', hide);

  confirmBtn.addEventListener('click', confirm);
  resignBtn.addEventListener('click', function () { send('pop_interim:resign', {}); });
  closeBtn.addEventListener('click', function () {
    hide();
    Pop.post('close');
  });

  window.addEventListener('keydown', function (e) {
    if (!state.open) return;
    if (e.key === 'Escape') {
      hide(); // le kit envoie déjà 'close' au Lua
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      move(1);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      move(-1);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (!confirmBtn.disabled) confirm();
    }
  });
})();
