/* pop_exchange : panneau de change. Le Lua et le serveur décident ; ici on affiche et on envoie id + montant. */
(function () {
  'use strict';

  var panel = document.getElementById('exchange');
  var list = document.getElementById('ex-offers');
  var balanceEl = document.getElementById('ex-balance');
  var remainingEl = document.getElementById('ex-remaining');
  var amountEl = document.getElementById('ex-amount');
  var maxBtn = document.getElementById('ex-max');
  var preview = document.getElementById('ex-preview');
  var confirmBtn = document.getElementById('ex-confirm');
  var statusEl = document.getElementById('ex-status');

  var offers = [];
  var selected = null; // id
  var waiting = false;
  var session = 0;

  function fmt(n) { return Number(n || 0).toLocaleString(); }
  function cur(name) { return Pop.t('currency_' + name); }

  function current() {
    for (var i = 0; i < offers.length; i++) {
      if (offers[i].id === selected) return offers[i];
    }
    return null;
  }

  function amount(o) {
    if (!o) return 0;
    if (amountEl.value === 'max') return o.remaining;
    var preset = (o.presets || []).find(function (entry) { return entry.id === amountEl.value; });
    return preset ? preset.amount : 0;
  }

  function renderPresets() {
    var o = current();
    var prev = amountEl.value;
    amountEl.replaceChildren(new Option(Pop.t('ui_amount'), ''));
    (o && o.presets || []).forEach(function (preset) {
      amountEl.add(new Option(fmt(preset.amount), preset.id));
    });
    if (o && o.remaining > 0) amountEl.add(new Option(Pop.t('ui_max') + ' (' + fmt(o.remaining) + ')', 'max'));
    amountEl.value = Array.from(amountEl.options).some(function (item) { return item.value === prev; }) ? prev : '';
  }

  function setStatus(text, ok) {
    statusEl.textContent = text || '';
    statusEl.classList.toggle('is-error', ok === false);
  }

  function update() {
    var o = current();
    var n = amount(o);
    var received = o ? Math.floor(n * o.rate) : 0;
    balanceEl.textContent = o ? Pop.t('ui_balance', fmt(o.balance)) : '';
    remainingEl.textContent = o ? Pop.t('ui_remaining', fmt(o.remaining)) : '';
    preview.textContent = o && received > 0 ? Pop.t('ui_receive', fmt(received), cur(o.to)) : '';
    confirmBtn.disabled = waiting || !o || received < 1 || n > o.remaining;
    maxBtn.disabled = waiting || !o || o.remaining < 1;
  }

  function renderOffers() {
    list.textContent = '';
    if (!current()) selected = offers.length ? offers[0].id : null;
    offers.forEach(function (o) {
      var row = document.createElement('div');
      row.className = 'ex-offer' + (o.id === selected ? ' is-selected' : '');
      var title = document.createElement('span');
      title.textContent = cur(o.from) + ' → ' + cur(o.to);
      var rate = document.createElement('span');
      rate.className = 'pop-small';
      rate.textContent = Pop.t('ui_rate', '1', cur(o.from), Number(o.rate).toLocaleString(), cur(o.to));
      row.appendChild(title);
      row.appendChild(rate);
      row.addEventListener('click', function () {
        if (selected === o.id) return;
        selected = o.id;
        amountEl.value = '';
        setStatus('');
        renderOffers();
      });
      list.appendChild(row);
    });
    renderPresets();
    update();
  }

  function confirm() {
    var o = current();
    if (!o || confirmBtn.disabled) return;
    var activeSession = session;
    waiting = true;
    update();
    Pop.post('pop_exchange:exchange', { id: o.id, preset: amountEl.value }).then(function (res) {
      if (session !== activeSession) return;
      waiting = false;
      if (!res) { update(); return; }
      if (Array.isArray(res.offers)) offers = res.offers;
      if (res.ok) amountEl.value = '';
      setStatus(res.message, !!res.ok);
      renderOffers();
    });
  }

  Pop.on('pop_exchange:open', function (d) {
    offers = Array.isArray(d.offers) ? d.offers : [];
    selected = null;
    waiting = false;
    amountEl.value = '';
    amountEl.setAttribute('aria-label', Pop.t('ui_amount'));
    setStatus('');
    Pop.translate(panel);
    renderOffers();
    Pop.show(panel, true);
    amountEl.focus();
  });

  function hide() {
    session += 1;
    Pop.show(panel, false);
    waiting = false;
  }

  Pop.on('pop_exchange:close', hide);

  amountEl.addEventListener('change', update);
  amountEl.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') confirm();
  });
  maxBtn.addEventListener('click', function () {
    var o = current();
    if (!o) return;
    amountEl.value = o.remaining > 0 ? 'max' : '';
    update();
  });
  confirmBtn.addEventListener('click', confirm);

  // Fermer : le kit envoie déjà 'close' sur Échap ; le bouton fait de même.
  document.getElementById('ex-close').addEventListener('click', function () {
    hide();
    Pop.post('close');
  });
  window.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') hide();
  });
})();
