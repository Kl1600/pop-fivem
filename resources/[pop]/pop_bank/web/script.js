/* pop_bank : interface. Tous les textes viennent des locales (Pop.t). */
(function () {
  'use strict';

  var $ = function (id) { return document.getElementById(id); };

  var panel = $('bank');
  var title = $('bank-title');
  var balance = $('bank-balance');
  var cash = $('bank-cash');
  var account = $('bank-account');
  var tabTransfer = $('tab-transfer');
  var form = $('bank-form');
  var target = $('bank-target');
  var amount = $('bank-amount');
  var submit = $('bank-submit');
  var status = $('bank-status');
  var history = $('bank-history');
  var tabs = document.querySelectorAll('.bank-tab');

  var current = 'deposit';
  var isAtm = false;
  var pending = false;

  function money(n) {
    return Pop.t('money', (Number(n) || 0).toLocaleString());
  }

  function pad(n) { return n < 10 ? '0' + n : String(n); }

  function formatDate(time) {
    var d = new Date((Number(time) || 0) * 1000);
    return d.toLocaleDateString() + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes());
  }

  function setStatus(message, ok) {
    status.textContent = message || '';
    status.classList.toggle('is-error', ok === false);
  }

  function selectTab(name) {
    if (name === 'transfer' && isAtm) name = 'deposit';
    current = name;
    tabs.forEach(function (t) { t.classList.toggle('is-active', t.getAttribute('data-tab') === name); });
    target.classList.toggle('pop-hidden', name !== 'transfer');
    setStatus('');
  }

  function renderHistory(list) {
    history.textContent = '';
    if (!Array.isArray(list) || list.length === 0) {
      var empty = document.createElement('div');
      empty.className = 'pop-small';
      empty.textContent = Pop.t('ui_no_history');
      history.appendChild(empty);
      return;
    }
    list.forEach(function (op) {
      var row = document.createElement('div');
      row.className = 'bank-item';

      var info = document.createElement('div');
      info.className = 'bank-item-info';
      var label = document.createElement('span');
      label.textContent = Pop.t('history_' + op.type);
      info.appendChild(label);
      var meta = document.createElement('span');
      meta.className = 'pop-small';
      meta.textContent = (op.other ? op.other + ' · ' : '') + formatDate(op.time);
      info.appendChild(meta);

      var incoming = op.type === 'deposit' || op.type === 'transfer_in';
      var value = document.createElement('span');
      value.className = 'bank-item-amount' + (incoming ? ' is-in' : '');
      value.textContent = (incoming ? '+' : '−') + money(op.amount);

      row.appendChild(info);
      row.appendChild(value);
      history.appendChild(row);
    });
  }

  function render(data) {
    if (!data) return;
    balance.textContent = money(data.bank);
    cash.textContent = money(data.cash);
    if (data.account) {
      account.textContent = Pop.t('ui_account', data.account);
      account.classList.remove('pop-hidden');
    } else {
      account.classList.add('pop-hidden');
    }
    renderHistory(data.history);
  }

  function open(data) {
    data = data || {};
    isAtm = !!data.atm;
    title.setAttribute('data-locale', isAtm ? 'ui_title_atm' : 'ui_title');
    Pop.translate(panel);
    tabTransfer.classList.toggle('pop-hidden', isAtm);
    target.placeholder = Pop.t('ui_target_hint');
    amount.placeholder = Pop.t('ui_amount');
    target.value = '';
    amount.value = '';
    pending = false;
    submit.disabled = false;
    selectTab('deposit');
    render(data);
    Pop.show(panel, true);
    amount.focus();
  }

  function hide() {
    Pop.show(panel, false);
    if (document.activeElement) document.activeElement.blur();
  }

  function send() {
    if (pending) return;
    var payload = { amount: Math.floor(Number(amount.value) || 0) };
    if (current === 'transfer') payload.target = target.value.trim().slice(0, 64);
    pending = true;
    submit.disabled = true;
    Pop.post('pop_bank:' + current, payload).then(function (res) {
      pending = false;
      submit.disabled = false;
      if (!res) {
        setStatus(Pop.t('error'), false);
        return;
      }
      setStatus(res.message, !!res.ok);
      render(res.data);
      if (res.ok) amount.value = '';
    });
  }

  tabs.forEach(function (t) {
    t.addEventListener('click', function () { selectTab(t.getAttribute('data-tab')); });
  });

  document.querySelectorAll('.bank-chip').forEach(function (chip) {
    chip.addEventListener('click', function () {
      amount.value = chip.getAttribute('data-amount');
      amount.focus();
    });
  });

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    send();
  });

  $('bank-close').addEventListener('click', function () {
    hide();
    Pop.post('close');
  });

  // Échap : le kit prévient déjà le Lua ('close').
  window.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') hide();
  });

  Pop.on('pop_bank:open', function (msg) { open(msg.data); });
  Pop.on('pop_bank:close', hide);
})();
