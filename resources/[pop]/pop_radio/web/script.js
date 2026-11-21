/* pop_radio : interface radio. Vanilla JS, s'appuie sur web/kit/pop.js (Pop.*). Aucun texte en dur. */
(function () {
  'use strict';

  var panel = document.getElementById('radio');
  var freqEl = document.getElementById('radio-freq');
  var input = document.getElementById('radio-input');
  var btnConnect = document.getElementById('radio-connect');
  var btnOff = document.getElementById('radio-off');
  var btnDown = document.getElementById('radio-vol-down');
  var btnUp = document.getElementById('radio-vol-up');
  var volEl = document.getElementById('radio-vol');

  var open = false;
  var busy = false;

  function toInt(value, fallback) {
    var n = Number(value);
    return isFinite(n) ? Math.floor(n) : fallback;
  }

  function setFrequency(freq) {
    var f = toInt(freq, 0);
    var off = f <= 0;
    freqEl.textContent = off ? Pop.t('off') : String(f);
    freqEl.classList.toggle('is-off', off);
    btnOff.disabled = off;
  }

  // Boutons volume (symboles − / +) : libellé accessible traduit.
  function labelVolume() {
    btnDown.setAttribute('aria-label', Pop.t('volume') + ' -');
    btnUp.setAttribute('aria-label', Pop.t('volume') + ' +');
  }

  function setVolume(volume) {
    var v = Math.max(0, Math.min(100, toInt(volume, 0)));
    volEl.textContent = v + '%';
  }

  function setBusy(state) {
    busy = state;
    btnConnect.disabled = state;
    btnOff.disabled = state || freqEl.classList.contains('is-off');
  }

  function show(visible) {
    open = visible;
    Pop.show(panel, visible);
    panel.setAttribute('aria-hidden', visible ? 'false' : 'true');
    if (!visible) {
      if (document.activeElement) document.activeElement.blur();
      setBusy(false);
    }
  }

  function connect() {
    if (!open || busy) return;
    var raw = input.value.trim();
    if (raw === '') { input.focus(); return; }
    var value = Number(raw);
    if (!isFinite(value)) { input.focus(); return; }
    // Le Lua valide (entier, plage, réservation) et notifie en cas d'échec.
    setBusy(true);
    Pop.post('pop_radio:join', { frequency: value }).then(function () { setBusy(false); });
  }

  function turnOff() {
    if (!open || busy) return;
    setBusy(true);
    Pop.post('pop_radio:leave', {}).then(function () { setBusy(false); });
  }

  function changeVolume(delta) {
    if (!open) return;
    Pop.post('pop_radio:volume', { delta: delta }).then(function (res) {
      if (res && typeof res.volume === 'number') setVolume(res.volume);
    });
  }

  btnConnect.addEventListener('click', connect);
  btnOff.addEventListener('click', turnOff);
  btnDown.addEventListener('click', function () { changeVolume(-10); });
  btnUp.addEventListener('click', function () { changeVolume(10); });

  input.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      connect();
    } else if (e.key === 'e' || e.key === 'E' || e.key === '+' || e.key === '-' || e.key === '.' || e.key === ',') {
      e.preventDefault(); // entiers uniquement
    }
  });

  // Échap : le kit envoie déjà Pop.post('close') ; on masque ici.
  window.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && open) show(false);
  });

  Pop.on('pop_radio:open', function (d) {
    var max = toInt(d.max, 0);
    var last = toInt(d.last, 0);
    if (max > 0) input.max = String(max); else input.removeAttribute('max');
    input.placeholder = Pop.t('frequency');
    input.value = last > 0 ? String(last) : '';
    Pop.translate(panel);
    labelVolume();
    setFrequency(d.frequency);
    setVolume(d.volume);
    setBusy(false);
    show(true);
    input.focus();
    input.select();
  });

  Pop.on('pop_radio:state', function (d) {
    if (d.frequency !== undefined) setFrequency(d.frequency);
    if (d.volume !== undefined) setVolume(d.volume);
  });

  Pop.on('pop_radio:close', function () {
    show(false);
  });

  // Changement de langue à chaud : placeholder et "OFF".
  Pop.on('pop:locale', function () {
    input.placeholder = Pop.t('frequency');
    labelVolume();
    if (freqEl.classList.contains('is-off')) freqEl.textContent = Pop.t('off');
  });
})();
