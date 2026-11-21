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

  function fmt(n) { return Number(n || 0).toLocaleString(); }
  function cur(name) { return Pop.t('currency_' + name); }

  function current() {
    for (var i = 0; i < offers.length; i++) {
      if (offers[i].id === selected) return offers[i];
    }
    return null;
  }

  function amount() {
    var n = Math.floor(Number(amountEl.value));
    return isFinite(n) && n > 0 ? n : 0;
  }

  function setStatus(text, ok) {
    statusEl.textContent = text || '';
    statusEl.classList.toggle('is-error', ok === false);
  }

  function update() {
    var o = current();
    var n = amount();
    var received = o ? Math.floor(n * o.rate) : 0;
    balanceEl.textContent = o ? Pop.t('ui_balance', fmt(o.balance)) : '';
    remainingEl.textContent = o ? Pop.t('ui_remaining', fmt(o.remaining)) : '';
    preview.textContent = o && received > 0 ? Pop.t('ui_receive', fmt(received), cur(o.to)) : '';
    confirmBtn.disabled = waiting || !o || received < 1 || n > o.remaining;
    maxBtn.disabled = waiting || !o;
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
    update();
  }

  function confirm() {
    var o = current();
    if (!o || confirmBtn.disabled) return;
    waiting = true;
    update();
    Pop.post('pop_exchange:exchange', { id: o.id, amount: amount() }).then(function (res) {
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
    amountEl.placeholder = Pop.t('ui_amount');
    setStatus('');
    Pop.translate(panel);
    renderOffers();
    Pop.show(panel, true);
    amountEl.focus();
  });

  Pop.on('pop_exchange:close', function () {
    Pop.show(panel, false);
    waiting = false;
  });

  amountEl.addEventListener('input', update);
  amountEl.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') confirm();
  });
  maxBtn.addEventListener('click', function () {
    var o = current();
    if (!o) return;
    amountEl.value = o.remaining > 0 ? String(o.remaining) : '';
    update();
  });
  confirmBtn.addEventListener('click', confirm);

  // Fermer : le kit envoie déjà 'close' sur Échap ; le bouton fait de même.
  document.getElementById('ex-close').addEventListener('click', function () {
    Pop.show(panel, false);
    Pop.post('close');
  });
  window.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') Pop.show(panel, false);
  });
})();
