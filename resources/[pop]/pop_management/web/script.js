/* pop_management : panneau patron, formulaire de facture, offre [E] / [X].
 * Textes : data-locale ou Pop.t uniquement. Données serveur : textContent uniquement.
 */
(function () {
  'use strict';

  var ARM_DELAY = 3000;
  var INCOMING = { deposit: true, invoice: true, add: true };
  var numberFormat = new Intl.NumberFormat();
  var distFormat = new Intl.NumberFormat(undefined, { maximumFractionDigits: 1 });

  function $(id) { return document.getElementById(id); }

  function el(tag, className, parent, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    if (parent) parent.appendChild(node);
    return node;
  }

  function clear(node) { while (node.firstChild) node.removeChild(node.firstChild); }
  function list(value) { return Array.isArray(value) ? value : []; }
  function money(n) { return Pop.t('money', numberFormat.format(Number(n) || 0)); }
  function isRtl() { return document.documentElement.dir === 'rtl'; }

  function fillPresets(select, presets, previous) {
    clear(select);
    var placeholder = el('option', '', select, Pop.t('amount'));
    placeholder.value = '';
    placeholder.disabled = true;
    list(presets).forEach(function (preset) {
      var option = el('option', '', select, money(preset.amount));
      option.value = preset.id;
    });
    select.value = previous || '';
    if (select.selectedIndex < 0) select.value = '';
  }

  function selectedPreset(select) {
    if (!select.value) select.focus();
    return select.value;
  }

  /* ---------------- Attente de réponse ---------------- */

  var pending = false;
  var invoiceHasPlayers = false;

  function setPending(on) {
    pending = on;
    document.querySelectorAll('[data-lock]').forEach(function (node) { node.disabled = on; });
    $('inv-send').disabled = on || !invoiceHasPlayers;
  }

  function send(name, payload) {
    if (pending) return Promise.resolve(null);
    setPending(true);
    return Pop.post(name, payload).then(function (res) {
      setPending(false);
      return res;
    });
  }

  function act(payload) {
    return send('pop_management:action', payload).then(function (res) { return !!(res && res.ok); });
  }

  /* ---------------- Confirmation en deux clics ---------------- */

  function disarm(btn) {
    if (!btn._armTimer) return;
    clearTimeout(btn._armTimer);
    btn._armTimer = null;
    btn.classList.remove('is-armed');
    btn.textContent = Pop.t(btn.getAttribute('data-locale'));
  }

  function arm(btn, run) {
    if (btn._armTimer) {
      disarm(btn);
      run();
      return;
    }
    btn._armTimer = setTimeout(function () { disarm(btn); }, ARM_DELAY);
    btn.classList.add('is-armed');
    btn.textContent = Pop.t('confirm');
  }

  function button(parent, key, onClick, extraClass) {
    var btn = el('button', 'mgmt-btn' + (extraClass ? ' ' + extraClass : ''), parent, Pop.t(key));
    btn.type = 'button';
    btn.setAttribute('data-locale', key);
    btn.setAttribute('data-lock', '');
    btn.disabled = pending;
    btn.addEventListener('click', onClick);
    return btn;
  }

  /* ---------------- Panneau patron ---------------- */

  var panel = $('mgmt-panel');
  var data = null;
  var activeTab = 'employees';

  function setTab(name) {
    activeTab = name;
    document.querySelectorAll('.mgmt-tab').forEach(function (tab) {
      tab.classList.toggle('is-active', tab.getAttribute('data-tab') === name);
    });
    $('mgmt-tab-employees').classList.toggle('pop-hidden', name !== 'employees');
    $('mgmt-tab-account').classList.toggle('pop-hidden', name !== 'account');
    showNearby(false);
  }

  function showNearby(visible) {
    $('mgmt-nearby').classList.toggle('pop-hidden', !visible);
    $('mgmt-staff').classList.toggle('pop-hidden', visible);
  }

  function nextGrade(grades, grade) {
    var best = null;
    grades.forEach(function (g) {
      if (g.grade > grade && (best === null || g.grade < best.grade)) best = g;
    });
    return best;
  }

  function hasLowerGrade(grades, grade) {
    return grades.some(function (g) { return g.grade < grade; });
  }

  function employeeRow(e, grades, myGrade, presets) {
    var li = el('li');
    var head = el('div', 'mgmt-emp', li);
    el('span', 'mgmt-dot' + (e.online ? ' is-online' : ''), head);
    var info = el('div', 'mgmt-grow', head);
    el('div', '', info, e.name || '');
    var meta = el('div', 'mgmt-meta pop-small', info);
    el('span', '', meta, e.gradeLabel || '');
    el('span', '', meta, Pop.t(e.online ? 'online' : 'offline'));
    if (e.me) el('span', 'pop-accent', meta, Pop.t('you'));

    if (e.me || !(e.grade < myGrade)) return li;

    var actions = el('div', 'mgmt-actions', li);
    var next = nextGrade(grades, e.grade);

    if (next && next.grade < myGrade) {
      button(actions, 'promote', function () { act({ action: 'promote', employeeId: e.id }); });
    }
    if (hasLowerGrade(grades, e.grade)) {
      button(actions, 'demote', function () { act({ action: 'demote', employeeId: e.id }); });
    }

    var payRow = null;
    if (e.online && list(presets).length) {
      button(actions, 'pay', function () {
        var open = payRow.classList.toggle('pop-hidden') === false;
        if (open) payInput.focus();
      });
      payRow = el('div', 'mgmt-inline pop-hidden', li);
      var payInput = el('select', 'mgmt-input', payRow);
      fillPresets(payInput, presets);
      payInput.setAttribute('aria-label', Pop.t('amount'));
      payInput.setAttribute('data-lock', '');
      payInput.disabled = pending;
      var submitPay = function () {
        var preset = selectedPreset(payInput);
        if (preset) act({ action: 'pay', employeeId: e.id, preset: preset });
      };
      button(payRow, 'confirm', submitPay);
    }

    var fireBtn = button(actions, 'fire', function () {
      arm(fireBtn, function () { act({ action: 'fire', employeeId: e.id }); });
    }, 'is-danger');

    return li;
  }

  function renderEmployees() {
    var employees = list(data.employees);
    var grades = list(data.grades);
    var myGrade = data.me ? data.me.grade : -1;
    $('mgmt-count').textContent = Pop.t('employees_count', employees.length);
    var ul = $('mgmt-employees');
    clear(ul);
    employees.forEach(function (e) {
      ul.appendChild(employeeRow(e, grades, myGrade, (data.presets || {}).bonus));
    });
  }

  function relativeTime(at) {
    var diff = Math.max(0, (Number(data.now) || 0) - (Number(at) || 0));
    if (diff < 60) return Pop.t('time_now');
    if (diff < 3600) return Pop.t('time_min', Math.floor(diff / 60));
    if (diff < 86400) return Pop.t('time_hour', Math.floor(diff / 3600));
    return Pop.t('time_day', Math.floor(diff / 86400));
  }

  function renderHistory() {
    var ul = $('mgmt-history');
    var history = list(data.history);
    clear(ul);
    if (!history.length) {
      el('li', 'pop-small', ul, Pop.t('history_empty'));
      return;
    }
    history.forEach(function (tx) {
      var li = el('li', '', ul);
      var incoming = INCOMING[tx.type] === true;

      var top = el('div', 'mgmt-line', li);
      el('span', '', top, Pop.t('tx_' + tx.type));
      el('span', 'mgmt-num ' + (incoming ? 'mgmt-in' : 'mgmt-out'), top,
        (incoming ? '+' : '−') + money(tx.amount));

      var bottom = el('div', 'mgmt-line pop-small', li);
      var who = el('span', '', bottom, tx.actor || '');
      if (tx.target) who.textContent += (isRtl() ? ' ← ' : ' → ') + tx.target;
      el('span', 'mgmt-num', bottom, relativeTime(tx.at));

      if (tx.note) el('div', 'pop-small', li, tx.note);
    });
  }

  function renderPanel() {
    var society = data.society || {};
    $('mgmt-society').textContent = society.label || society.name || '';
    $('mgmt-grade').textContent = (data.me && data.me.gradeLabel) || '';
    $('mgmt-balance').textContent = money(data.balance);
    var amount = $('mgmt-amount');
    fillPresets(amount, (data.presets || {}).transfer, amount.value);
    renderEmployees();
    renderHistory();
  }

  function resetPanel() {
    setTab('employees');
    $('mgmt-amount').value = '';
    disarm($('mgmt-withdraw'));
    setPending(false);
  }

  Pop.on('pop_management:panel', function (msg) {
    if (!msg.show) {
      Pop.show(panel, false);
      data = null;
      return;
    }
    var fresh = !panel.classList.contains('is-visible');
    if (fresh) resetPanel();
    data = msg.data || {};
    renderPanel();
    if (!fresh) {
      // Rafraîchissement après une action : on garde l'onglet actif.
      setTab(activeTab);
    }
    Pop.show(panel, true);
  });

  document.querySelectorAll('.mgmt-tab').forEach(function (tab) {
    tab.addEventListener('click', function () { setTab(tab.getAttribute('data-tab')); });
  });

  $('mgmt-close').addEventListener('click', function () { Pop.post('close'); });

  // Recrutement : liste des personnes proches.
  $('mgmt-recruit').addEventListener('click', function () {
    send('pop_management:nearby', {}).then(function (res) {
      if (!res || !data) return;
      var ul = $('mgmt-nearby-list');
      var players = list(res.players);
      clear(ul);
      if (!players.length) el('li', 'pop-small', ul, Pop.t('nearby_none'));
      players.forEach(function (p) {
        var li = el('li', '', ul);
        var pick = el('button', 'mgmt-pick', li);
        pick.type = 'button';
        pick.setAttribute('data-lock', '');
        el('span', '', pick, Pop.t('player_id', p.id));
        el('span', 'pop-small mgmt-num', pick, Pop.t('meters', distFormat.format(Number(p.dist) || 0)));
        pick.addEventListener('click', function () {
          act({ action: 'recruit', targetId: p.id }).then(function (ok) { if (ok) showNearby(false); });
        });
      });
      showNearby(true);
    });
  });

  $('mgmt-nearby-back').addEventListener('click', function () { showNearby(false); });

  // Compte : dépôt / retrait.
  function moveMoney(action) {
    var input = $('mgmt-amount');
    var preset = selectedPreset(input);
    if (!preset) return;
    act({ action: action, preset: preset }).then(function (ok) { if (ok) input.value = ''; });
  }

  $('mgmt-deposit').addEventListener('click', function () { moveMoney('deposit'); });
  $('mgmt-withdraw').addEventListener('click', function () {
    var btn = $('mgmt-withdraw');
    if (!selectedPreset($('mgmt-amount'))) return;
    arm(btn, function () { moveMoney('withdraw'); });
  });

  $('mgmt-amount').addEventListener('change', function () { disarm($('mgmt-withdraw')); });

  /* ---------------- Facture ---------------- */

  var invoice = $('mgmt-invoice');

  Pop.on('pop_management:invoice', function (msg) {
    if (!msg.show) {
      Pop.show(invoice, false);
      return;
    }
    var players = list(msg.players);
    var select = $('inv-target');
    clear(select);
    players.forEach(function (p) {
      var option = el('option', '', select, Pop.t('player_id', p.id));
      option.value = String(p.id);
    });
    invoiceHasPlayers = players.length > 0;
    select.classList.toggle('pop-hidden', !invoiceHasPlayers);
    $('inv-none').classList.toggle('pop-hidden', invoiceHasPlayers);

    $('inv-society').textContent = msg.society || '';
    var amount = $('inv-amount');
    fillPresets(amount, msg.presets);
    $('inv-note').value = '';

    setPending(false);
    Pop.show(invoice, true);
    if (invoiceHasPlayers) amount.focus();
  });

  function sendInvoice() {
    if (pending || !invoiceHasPlayers) return;
    var targetId = parseInt($('inv-target').value, 10);
    if (isNaN(targetId)) return;
    var preset = selectedPreset($('inv-amount'));
    if (!preset) return;
    var payload = { targetId: targetId, preset: preset };
    var note = $('inv-note').value.trim();
    if (note) payload.note = note.slice(0, 50);
    send('pop_management:sendInvoice', payload);
  }

  $('inv-send').addEventListener('click', sendInvoice);
  $('inv-cancel').addEventListener('click', function () { Pop.post('close'); });
  $('inv-note').addEventListener('keydown', function (e) { if (e.key === 'Enter') sendInvoice(); });

  /* ---------------- Offre [E] / [X] ---------------- */

  var offer = $('mgmt-offer');
  var offerFill = $('offer-fill');

  Pop.on('pop_management:offer', function (msg) {
    if (!msg.show) {
      Pop.show(offer, false);
      return;
    }
    var isInvoice = msg.kind === 'invoice';
    $('offer-title').textContent = Pop.t(isInvoice ? 'offer_invoice' : 'offer_recruit', msg.society || '');
    $('offer-line').textContent = isInvoice ? money(msg.amount) : Pop.t('offer_grade', msg.gradeLabel || '');
    var note = $('offer-note');
    note.textContent = isInvoice && msg.note ? msg.note : '';
    note.classList.toggle('pop-hidden', !note.textContent);
    $('offer-accept-key').textContent = msg.acceptKey || '';
    $('offer-refuse-key').textContent = msg.refuseKey || '';

    var seconds = Math.max(0, Number(msg.timeout) || 0);
    offerFill.style.transition = 'none';
    offerFill.style.transform = 'scaleX(1)';
    void offerFill.offsetWidth; // force le recalcul avant de lancer la transition
    offerFill.style.transition = 'transform ' + seconds + 's linear';
    offerFill.style.transform = 'scaleX(0)';

    Pop.show(offer, true);
  });

  setTab('employees');
  setPending(false);
})();
