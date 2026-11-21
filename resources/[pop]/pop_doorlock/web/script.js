/* pop_doorlock : NUI (prompt de porte, crochetage, éditeur admin). Vanilla JS, aucune dépendance.
 * Messages et callbacks : SPEC.md §5. Aucun texte en dur : tout passe par Pop.t / data-locale.
 * Le focus NUI et Échap sont gérés par le Lua et le kit.
 */
(function () {
  'use strict';

  // Valeurs par défaut d'un nouveau groupe (SPEC §8).
  var DEFAULTS = { locked: true, distance: 2.0, security: 2, alert: false, jobs: {}, key: false };
  var DIST_MIN = 1.0;
  var DIST_MAX = 5.0;
  var MAX_JOBS = 10;            // le serveur refuse au-delà
  var MAX_GRADE = 50;           // idem
  var MIN_SESSION_MS = 1100;    // le serveur refuse une session de moins de 1000 ms : on attend un peu avant d'envoyer
  var CONFIRM_MS = 3000;        // double clic de suppression

  function $(id) { return document.getElementById(id); }

  function num(v, def) {
    var n = Number(v);
    return isFinite(n) ? n : def;
  }

  function clamp(v, min, max) { return Math.min(max, Math.max(min, v)); }

  function node(tag, className, text) {
    var el = document.createElement(tag);
    if (className) el.className = className;
    if (text !== undefined) el.textContent = String(text);
    return el;
  }

  /* ============================== Prompt ============================== */

  var promptEl = $('prompt');
  var promptKey = $('prompt-key');
  var promptLabel = $('prompt-label');
  var iconLocked = $('icon-locked');
  var iconUnlocked = $('icon-unlocked');

  Pop.on('pop_doorlock:prompt', function (d) {
    if (!d.show) {
      Pop.show(promptEl, false);
      return;
    }
    var hasKey = typeof d.key === 'string' && d.key !== '';
    promptKey.textContent = hasKey ? d.key : '';
    promptKey.classList.toggle('pop-hidden', !hasKey);
    promptLabel.textContent = d.label == null ? '' : String(d.label);
    promptEl.classList.toggle('is-locked', !!d.locked);
    iconLocked.classList.toggle('pop-hidden', !d.locked);
    iconUnlocked.classList.toggle('pop-hidden', !!d.locked);
    Pop.show(promptEl, true);
  });

  /* ============================ Crochetage ============================ */

  var lpEl = $('lockpick');
  var lpZone = $('lp-zone');
  var lpCursor = $('lp-cursor');
  var lpDots = $('lp-dots');
  var lpKey = $('lp-key');

  var lp = {
    active: false, sent: false, raf: 0, timer: 0,
    hits: 2, zone: 0.2, speed: 0.8, time: 6000, key: 'E',
    done: 0, start: 0, zoneStart: 0
  };

  // Position du curseur (0 à 1) : allers-retours à `speed` par seconde.
  function cursorAt(now) {
    var p = ((now - lp.start) / 1000 * lp.speed) % 1;
    return p < 0.5 ? p * 2 : 2 - p * 2;
  }

  // Nouvelle zone à une position aléatoire, pas directement sous le curseur.
  function placeZone(cursor) {
    var start = 0;
    for (var i = 0; i < 12; i++) {
      start = Math.random() * (1 - lp.zone);
      if (Math.abs(start + lp.zone / 2 - cursor) > lp.zone / 2 + 0.15) break;
    }
    lp.zoneStart = start;
    lpZone.style.left = (start * 100) + '%';
    lpZone.style.width = (lp.zone * 100) + '%';
  }

  function renderDots() {
    lpDots.textContent = '';
    for (var i = 0; i < lp.hits; i++) {
      lpDots.appendChild(node('span', 'dl-dot' + (i < lp.done ? ' is-done' : '')));
    }
  }

  function lpStop() {
    lp.active = false;
    if (lp.raf) cancelAnimationFrame(lp.raf);
    if (lp.timer) clearTimeout(lp.timer);
    lp.raf = 0;
    lp.timer = 0;
  }

  function tick(now) {
    if (!lp.active) return;
    if (now - lp.start >= lp.time) {
      finish(false);
      return;
    }
    lpCursor.style.left = (cursorAt(now) * 100) + '%';
    lp.raf = requestAnimationFrame(tick);
  }

  // Envoie le résultat une seule fois, puis masque.
  function finish(success) {
    if (lp.sent) return;
    lp.sent = true;
    lp.active = false;
    if (lp.raf) cancelAnimationFrame(lp.raf);
    lp.raf = 0;
    lpEl.classList.add(success ? 'is-success' : 'is-fail');
    var wait = Math.max(0, MIN_SESSION_MS - (performance.now() - lp.start));
    lp.timer = setTimeout(function () {
      lp.timer = 0;
      Pop.show(lpEl, false);
      Pop.post('lockpickResult', { success: !!success });
    }, wait);
  }

  function press() {
    var pos = cursorAt(performance.now());
    if (pos >= lp.zoneStart && pos <= lp.zoneStart + lp.zone) {
      lp.done++;
      renderDots();
      if (lp.done >= lp.hits) finish(true);
      else placeZone(pos);
    } else {
      finish(false);
    }
  }

  Pop.on('pop_doorlock:lockpick', function (d) {
    lpStop();
    if (!d.show) {
      Pop.show(lpEl, false);
      return;
    }
    lp.hits = Math.round(clamp(num(d.hits, 2), 1, 10));
    lp.zone = clamp(num(d.zone, 0.2), 0.02, 0.9);
    lp.speed = clamp(num(d.speed, 0.8), 0.1, 5);
    lp.time = clamp(num(d.time, 6000), 1000, 60000);
    lp.key = typeof d.key === 'string' && d.key !== '' ? d.key.toUpperCase() : 'E';
    lp.done = 0;
    lp.sent = false;
    lp.start = performance.now();

    lpEl.classList.remove('is-success', 'is-fail');
    lpKey.textContent = lp.key;
    lpCursor.style.left = '0%';
    renderDots();
    placeZone(0);

    lp.active = true;
    Pop.show(lpEl, true);
    lp.raf = requestAnimationFrame(tick);
  });

  window.addEventListener('keydown', function (e) {
    if (!lp.active || e.repeat || typeof e.key !== 'string') return;
    if (e.key === ' ' || e.key === 'Spacebar' || e.key.toUpperCase() === lp.key) {
      e.preventDefault();
      press();
    }
  });

  /* ============================== Éditeur ============================= */

  var editorEl = $('editor');
  var views = { list: $('view-list'), detail: $('view-detail'), aim: $('view-aim') };
  var groupList = $('group-list');
  var listEmpty = $('list-empty');
  var detailTitle = $('detail-title');
  var form = $('form');
  var fLabel = $('f-label');
  var fLocked = $('f-locked');
  var fDistance = $('f-distance');
  var fAlert = $('f-alert');
  var fJobs = $('f-jobs');
  var fKey = $('f-key');
  var rowAlert = $('row-alert');
  var rowKey = $('row-key');
  var keyInfo = $('key-info');
  var btnGive = $('btn-give');
  var btnReset = $('btn-reset');
  var btnAddDoor = $('btn-add-door');
  var btnDelete = $('btn-delete');
  var doorList = $('door-list');
  var aimCount = $('aim-count');

  var ed = {
    open: false,      // panneau ouvert par /doorlock
    aim: false,       // mode visée en cours
    view: 'list',     // vue courante hors visée
    groups: [],
    keys: true,       // l'inventaire gère la metadata
    currentId: null,  // groupe affiché (null = nouveau)
    pending: false,
    confirm: false,
    confirmTimer: 0
  };

  function isGroup(g) { return g && typeof g === 'object' && typeof g.id === 'number'; }

  function findGroup(id) {
    for (var i = 0; i < ed.groups.length; i++) if (ed.groups[i].id === id) return ed.groups[i];
    return null;
  }

  function upsertGroup(g) {
    for (var i = 0; i < ed.groups.length; i++) {
      if (ed.groups[i].id === g.id) { ed.groups[i] = g; renderList(); return; }
    }
    ed.groups.push(g);
    renderList();
  }

  function removeGroup(id) {
    ed.groups = ed.groups.filter(function (g) { return g.id !== id; });
    renderList();
  }

  function showView(name) {
    Object.keys(views).forEach(function (k) { views[k].classList.toggle('pop-hidden', k !== name); });
    editorEl.classList.toggle('is-aim', name === 'aim');
    if (name !== 'aim') ed.view = name;
  }

  function refreshVisibility() {
    Pop.show(editorEl, ed.open || ed.aim);
  }

  /* ---- Liste ---- */

  function renderList() {
    groupList.textContent = '';
    var sorted = ed.groups.slice().sort(function (a, b) { return a.id - b.id; });
    listEmpty.classList.toggle('pop-hidden', sorted.length > 0);
    sorted.forEach(function (g) {
      var sec = clamp(Math.round(num(g.security, 2)), 0, 2);
      var row = node('button', 'dl-item');
      row.type = 'button';
      row.appendChild(node('span', 'pop-small dl-id', '#' + g.id));
      var name = node('span', 'dl-name', g.label || '');
      name.dir = 'auto';
      row.appendChild(name);
      var count = node('span', 'pop-small dl-id', Array.isArray(g.doors) ? g.doors.length : 0);
      count.title = Pop.t('editor_doors');
      row.appendChild(count);
      row.appendChild(node('span', 'dl-badge s' + sec, Pop.t('editor_security_' + sec)));
      row.addEventListener('click', function () { openDetail(findGroup(g.id)); });
      groupList.appendChild(row);
    });
  }

  /* ---- Détail ---- */

  function jobsToText(jobs) {
    if (!jobs || typeof jobs !== 'object') return '';
    return Object.keys(jobs).map(function (k) { return k + ':' + jobs[k]; }).join(', ');
  }

  // "police:0, sheriff:2" -> { police: 0, sheriff: 2 }. Entrées invalides ignorées ; "police" seul = grade 0.
  function parseJobs(text) {
    var out = {};
    var n = 0;
    String(text || '').split(',').forEach(function (part) {
      var bits = part.split(':');
      var name = bits[0].trim();
      var grade = bits.length > 1 ? bits[1].trim() : '0';
      if (n >= MAX_JOBS || bits.length > 2 || name === '') return;
      if (!/^[A-Za-z0-9_-]{1,32}$/.test(name) || !/^\d{1,2}$/.test(grade)) return;
      var g = parseInt(grade, 10);
      if (g > MAX_GRADE) return;
      if (!Object.prototype.hasOwnProperty.call(out, name)) n++;
      out[name] = g;
    });
    return out;
  }

  function getSecurity() {
    var checked = form.querySelector('input[name="security"]:checked');
    return checked ? Number(checked.value) : DEFAULTS.security;
  }

  function setSecurity(sec) {
    form.querySelectorAll('input[name="security"]').forEach(function (r) { r.checked = Number(r.value) === sec; });
    updateAlertState();
  }

  function updateAlertState() {
    var off = getSecurity() === 2;
    fAlert.disabled = off;
    rowAlert.classList.toggle('is-disabled', off);
  }

  function resetConfirm() {
    if (ed.confirmTimer) clearTimeout(ed.confirmTimer);
    ed.confirmTimer = 0;
    ed.confirm = false;
    btnDelete.classList.remove('is-confirm');
    btnDelete.textContent = Pop.t('editor_delete');
  }

  // Parties du détail qui viennent du serveur (portes, boutons de clé) : ne touche pas au formulaire en cours.
  function renderMeta(g) {
    detailTitle.textContent = g ? '#' + g.id : Pop.t('editor_new_group');
    var hasKey = !!(g && g.hasKey);
    btnGive.classList.toggle('pop-hidden', !hasKey);
    btnReset.classList.toggle('pop-hidden', !hasKey);
    btnAddDoor.disabled = !g;
    btnDelete.classList.toggle('pop-hidden', !g);

    doorList.textContent = '';
    var doors = g && Array.isArray(g.doors) ? g.doors : [];
    doors.forEach(function (door) {
      var row = node('div', 'dl-door');
      row.appendChild(node('span', 'pop-small dl-id', '#' + door.id));
      row.appendChild(node('span', 'dl-grow', Pop.t(door.double ? 'editor_door_double' : 'editor_door_single')));
      var rm = node('button', 'pop-button dl-ghost', Pop.t('editor_remove'));
      rm.type = 'button';
      rm.addEventListener('click', function () { removeDoor(door.id); });
      row.appendChild(rm);
      doorList.appendChild(row);
    });
  }

  function openDetail(g) {
    if (!isGroup(g)) g = null;
    ed.currentId = g ? g.id : null;
    resetConfirm();

    fLabel.value = g ? String(g.label || '') : '';
    fLocked.checked = g ? !!g.locked : DEFAULTS.locked;
    fDistance.value = String(g ? num(g.distance, DEFAULTS.distance) : DEFAULTS.distance);
    fDistance.min = String(DIST_MIN);
    fDistance.max = String(DIST_MAX);
    fAlert.checked = g ? !!g.alert : DEFAULTS.alert;
    fJobs.value = jobsToText(g ? g.jobs : DEFAULTS.jobs);
    fJobs.placeholder = Pop.t('editor_jobs_hint');
    fKey.checked = g ? !!g.hasKey : DEFAULTS.key;
    fKey.disabled = !ed.keys;
    rowKey.classList.toggle('is-disabled', !ed.keys);
    keyInfo.classList.toggle('pop-hidden', ed.keys);
    setSecurity(g ? clamp(Math.round(num(g.security, DEFAULTS.security)), 0, 2) : DEFAULTS.security);

    renderMeta(g);
    showView('detail');
  }

  function collectForm() {
    var sec = getSecurity();
    return {
      id: ed.currentId,
      label: fLabel.value.trim(),
      locked: !!fLocked.checked,
      distance: clamp(num(parseFloat(fDistance.value), DEFAULTS.distance), DIST_MIN, DIST_MAX),
      security: sec,
      alert: sec !== 2 && !!fAlert.checked,
      jobs: parseJobs(fJobs.value),
      key: !!fKey.checked
    };
  }

  /* ---- Appels au Lua (une requête à la fois) ---- */

  function call(name, data, onOk) {
    if (ed.pending) return;
    ed.pending = true;
    editorEl.classList.add('is-pending');
    Pop.post(name, data).then(function (res) {
      ed.pending = false;
      editorEl.classList.remove('is-pending');
      // Les erreurs sont notifiées par le Lua (pas de toast NUI).
      if (res && res.ok && onOk) onOk(res);
    });
  }

  function removeDoor(doorId) {
    call('editorRemoveDoor', { doorId: Number(doorId) }, function (res) {
      if (isGroup(res.group)) {
        upsertGroup(res.group);
        if (ed.currentId === res.group.id) renderMeta(res.group);
      }
    });
  }

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    call('editorSave', collectForm(), function (res) {
      if (!isGroup(res.group)) return;
      upsertGroup(res.group);
      openDetail(res.group);
    });
  });

  form.addEventListener('change', function (e) {
    if (e.target && e.target.name === 'security') updateAlertState();
  });

  $('btn-new').addEventListener('click', function () { openDetail(null); });

  $('btn-back').addEventListener('click', function () {
    resetConfirm();
    renderList();
    showView('list');
  });

  btnGive.addEventListener('click', function () {
    if (ed.currentId === null) return;
    call('editorGiveKey', { id: ed.currentId });
  });

  btnReset.addEventListener('click', function () {
    if (ed.currentId === null) return;
    call('editorResetKey', { id: ed.currentId }, function (res) {
      if (isGroup(res.group)) {
        upsertGroup(res.group);
        if (ed.currentId === res.group.id) renderMeta(res.group);
      }
    });
  });

  btnAddDoor.addEventListener('click', function () {
    if (ed.currentId === null || ed.pending) return;
    Pop.post('editorAddDoor', { id: ed.currentId });
  });

  btnDelete.addEventListener('click', function () {
    if (ed.currentId === null) return;
    if (!ed.confirm) {
      ed.confirm = true;
      btnDelete.classList.add('is-confirm');
      btnDelete.textContent = Pop.t('editor_confirm_delete');
      ed.confirmTimer = setTimeout(resetConfirm, CONFIRM_MS);
      return;
    }
    var id = ed.currentId;
    resetConfirm();
    call('editorDelete', { id: id }, function () {
      removeGroup(id);
      ed.currentId = null;
      showView('list');
    });
  });

  /* ---- Messages Lua ---- */

  Pop.on('pop_doorlock:editor', function (d) {
    resetConfirm();
    ed.aim = false;
    if (!d.show) {
      ed.open = false;
      refreshVisibility();
      return;
    }
    ed.open = true;
    ed.keys = d.keys !== false;
    ed.groups = Array.isArray(d.groups) ? d.groups.filter(isGroup) : [];
    ed.currentId = null;
    renderList();
    showView('list');
    refreshVisibility();
  });

  Pop.on('pop_doorlock:group', function (d) {
    if (!isGroup(d.group)) return;
    upsertGroup(d.group);
    // Même groupe déjà affiché : on garde le formulaire, on met à jour portes et clé.
    if (ed.view === 'detail' && ed.currentId === d.group.id) {
      renderMeta(d.group);
    } else {
      openDetail(d.group);
    }
    if (ed.aim) showView('aim');
  });

  Pop.on('pop_doorlock:groupRemoved', function (d) {
    var id = Number(d.id);
    removeGroup(id);
    // Retour à la liste seulement si le groupe supprimé est celui affiché (sinon on garde la vue en cours).
    if (ed.currentId === id && ed.view === 'detail') {
      ed.currentId = null;
      resetConfirm();
      showView('list');
    }
    if (ed.aim) showView('aim');
  });

  Pop.on('pop_doorlock:aim', function (d) {
    if (!d.show) {
      ed.aim = false;
      showView(ed.view);
      refreshVisibility();
      return;
    }
    var keys = d.keys || {};
    $('aim-key-select').textContent = keys.select || 'E';
    $('aim-key-confirm').textContent = keys.confirm || 'ENTER';
    $('aim-key-cancel').textContent = keys.cancel || 'X';
    aimCount.textContent = Pop.t('editor_aim_count', num(d.count, 0), num(d.max, 2));
    if (!ed.aim) {
      ed.aim = true;
      resetConfirm();
      showView('aim');
    }
    refreshVisibility();
  });
})();
