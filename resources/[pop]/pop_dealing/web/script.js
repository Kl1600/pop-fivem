/* pop_dealing : pastille de vente et panneau de négociation. Vanilla JS, s'appuie sur web/kit/pop.js. */
(function () {
  'use strict';

  function $(id) { return document.getElementById(id); }

  function toInt(v, fallback) {
    var n = Math.round(Number(v));
    return isFinite(n) ? n : fallback;
  }

  var ui = {};

  // État de la pastille
  var status = { show: false, state: 'waiting', command: 'sell' };

  // État de la négociation
  var deal = {
    open: false,
    busy: false,
    session: 0,      // ignore les réponses d'une négociation précédente
    label: '',
    qty: 1,
    hint: 0,
    min: 0,
    max: 0,
    step: 1,
    price: 0,
    attempts: 0,
    maxAttempts: 0,
    feedback: ''     // clé de locale de la ligne de retour ('' = vide)
  };

  /* ---------------- Pastille ---------------- */

  function renderStatus() {
    ui.statusState.textContent = Pop.t(status.state === 'coming' ? 'hud_coming' : 'hud_waiting');
    ui.statusStop.textContent = Pop.t('hud_stop', status.command);
  }

  Pop.on('pop_dealing:status', function (d) {
    status.show = !!d.show;
    if (status.show) {
      status.state = d.state === 'coming' ? 'coming' : 'waiting';
      if (typeof d.command === 'string' && d.command !== '') status.command = d.command;
      renderStatus();
    }
    Pop.show(ui.status, status.show && !deal.open);
  });

  /* ---------------- Négociation ---------------- */

  function clampPrice(p) {
    return Math.min(deal.max, Math.max(deal.min, p));
  }

  function renderDeal() {
    ui.attempts.textContent = Pop.t('ui_attempts', deal.attempts, deal.maxAttempts);
    ui.qty.textContent = Pop.t('ui_qty', deal.qty, deal.label);
    ui.hint.textContent = Pop.t('money', deal.hint);
    ui.price.textContent = Pop.t('money', deal.price);
    ui.total.textContent = Pop.t('money', deal.price * deal.qty);
    ui.feedback.textContent = deal.feedback ? Pop.t(deal.feedback) : '';

    ui.minus.disabled = deal.busy || deal.price <= deal.min;
    ui.plus.disabled = deal.busy || deal.price >= deal.max;
    ui.propose.disabled = deal.busy;
    ui.refuse.disabled = deal.busy;
  }

  function changePrice(direction) {
    if (!deal.open || deal.busy) return;
    var next = clampPrice(deal.price + direction * deal.step);
    if (next === deal.price) return;
    deal.price = next;
    if (deal.feedback === 'ui_thinking') deal.feedback = '';
    renderDeal();
  }

  function propose() {
    if (!deal.open || deal.busy) return;
    var session = deal.session;
    var price = clampPrice(toInt(deal.price, deal.min));

    deal.busy = true;
    deal.feedback = 'ui_thinking';
    renderDeal();

    Pop.post('propose', { price: price }).then(function (result) {
      if (session !== deal.session || !deal.open) return;
      deal.busy = false;
      if (result && result.status === 'refused') {
        deal.attempts = Math.max(0, toInt(result.attempts, deal.attempts));
        deal.feedback = result.hint === 'too_high' ? 'deal_refused_high' : 'deal_refused_close';
      } else {
        // Autres statuts ou null : la fermeture vient du Lua (pop_dealing:close).
        deal.feedback = '';
      }
      renderDeal();
    });
  }

  function refuse() {
    if (!deal.open || deal.busy) return;
    deal.busy = true;
    renderDeal();
    Pop.post('refuse', {});
  }

  function closeDeal() {
    deal.open = false;
    deal.busy = false;
    deal.feedback = '';
    deal.session++;
    Pop.show(ui.deal, false);
  }

  Pop.on('pop_dealing:open', function (d) {
    deal.session++;
    deal.label = typeof d.label === 'string' ? d.label : '';
    deal.qty = Math.max(1, toInt(d.qty, 1));
    deal.hint = Math.max(0, toInt(d.hint, 0));
    deal.min = Math.max(0, toInt(d.min, 0));
    deal.max = Math.max(deal.min, toInt(d.max, deal.min));
    deal.step = Math.max(1, toInt(d.step, 1));
    deal.maxAttempts = Math.max(0, toInt(d.maxAttempts, 0));
    deal.attempts = Math.max(0, toInt(d.attempts, deal.maxAttempts));
    deal.price = clampPrice(deal.hint);
    deal.feedback = '';
    deal.busy = false;
    deal.open = true;

    renderDeal();
    Pop.show(ui.status, false);
    Pop.show(ui.deal, true);
  });

  Pop.on('pop_dealing:close', function () {
    closeDeal();
  });

  // Langue changée à chaud : le kit a déjà mis à jour Pop.locale et les [data-locale].
  Pop.on('pop:locale', function () {
    renderStatus();
    if (deal.open) renderDeal();
  });

  /* ---------------- Entrées ---------------- */

  window.addEventListener('keydown', function (e) {
    if (!deal.open) return;
    switch (e.key) {
      case 'ArrowLeft':
      case '-':
        e.preventDefault();
        changePrice(-1);
        break;
      case 'ArrowRight':
      case '+':
      case '=':
        e.preventDefault();
        changePrice(1);
        break;
      case 'Enter':
        e.preventDefault(); // évite un double déclenchement si un bouton a le focus
        propose();
        break;
    }
  });

  function init() {
    ui.status = $('status');
    ui.statusState = $('status-state');
    ui.statusStop = $('status-stop');

    ui.deal = $('deal');
    ui.attempts = $('deal-attempts');
    ui.qty = $('deal-qty');
    ui.hint = $('deal-hint');
    ui.price = $('deal-price');
    ui.total = $('deal-total');
    ui.feedback = $('deal-feedback');
    ui.minus = $('deal-minus');
    ui.plus = $('deal-plus');
    ui.propose = $('deal-propose');
    ui.refuse = $('deal-refuse');

    ui.minus.addEventListener('click', function () { changePrice(-1); });
    ui.plus.addEventListener('click', function () { changePrice(1); });
    ui.propose.addEventListener('click', propose);
    ui.refuse.addEventListener('click', refuse);
  }

  // script.js est chargé en fin de <body> : le DOM est prêt.
  init();
})();
