/* Kit POP : helper NUI commun. Vanilla JS, aucune dépendance. Ne pas modifier dans un script.
 *
 *   Pop.post(name, data)  -> Promise : appelle RegisterNUICallback(name) côté Lua
 *   Pop.on(action, fn)    -> fn(data) pour chaque SendNUIMessage({ action = ... })
 *   Pop.t(key, ...args)   -> texte traduit (%s / %d remplacés dans l'ordre)
 *   Pop.translate(root)   -> remplit les éléments [data-locale="clé"]
 *   Échap envoie 'close'.
 */
(function () {
  'use strict';

  var resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pop_base';
  var handlers = {};

  var Pop = {
    locale: {},

    post: function (name, data) {
      return fetch('https://' + resource + '/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data === undefined ? {} : data)
      })
        .then(function (r) { return r.json(); })
        .catch(function () { return null; });
    },

    on: function (action, fn) {
      (handlers[action] = handlers[action] || []).push(fn);
    },

    t: function (key) {
      var args = Array.prototype.slice.call(arguments, 1);
      var text = typeof Pop.locale[key] === 'string' ? Pop.locale[key] : String(key);
      return text.replace(/%[sd]/g, function (m) { return args.length ? String(args.shift()) : m; });
    },

    translate: function (root) {
      (root || document).querySelectorAll('[data-locale]').forEach(function (el) {
        el.textContent = Pop.t(el.getAttribute('data-locale'));
      });
    },

    setLocale: function (table) {
      Pop.locale = table || {};
      document.documentElement.dir = Pop.locale._rtl ? 'rtl' : 'ltr';
      Pop.translate();
    },

    setAccent: function (color) {
      if (typeof color === 'string' && /^#[0-9a-f]{3,8}$/i.test(color)) {
        document.documentElement.style.setProperty('--pop-accent', color);
      }
    },

    show: function (el, visible) {
      if (el) el.classList.toggle('is-visible', !!visible);
    }
  };

  window.Pop = Pop;

  window.addEventListener('message', function (e) {
    var data = e.data;
    if (!data || typeof data.action !== 'string') return;
    (handlers[data.action] || []).forEach(function (fn) { fn(data); });
  });

  window.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') Pop.post('close');
  });

  /* ---------------- HUD : prompt, progression, notifications ---------------- */

  function el(tag, className, parent) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (parent) parent.appendChild(node);
    return node;
  }

  var hud, prompt, progress, toasts;

  function buildHud() {
    hud = el('div', 'pop-hud', document.body);

    prompt = el('div', 'pop-panel pop-prompt pop-fade', hud);
    prompt.key = el('span', 'pop-key', prompt);
    prompt.label = el('span', '', prompt);
    prompt.count = el('span', 'pop-small pop-prompt-count', prompt);

    progress = el('div', 'pop-panel pop-progress pop-fade', hud);
    var head = el('div', 'pop-progress-head', progress);
    progress.label = el('span', '', head);
    progress.cancel = el('span', 'pop-small', head);
    var track = el('div', 'pop-progress-track', progress);
    progress.fill = el('div', 'pop-progress-fill', track);

    toasts = el('div', 'pop-toasts', hud);
  }

  Pop.on('pop:prompt', function (d) {
    if (d.show) {
      prompt.key.textContent = d.key || 'E';
      prompt.label.textContent = d.label || '';
      prompt.count.textContent = d.count > 1 ? d.index + '/' + d.count : '';
    }
    Pop.show(prompt, d.show);
  });

  Pop.on('pop:progress', function (d) {
    var fill = progress.fill;
    if (!d.show) {
      Pop.show(progress, false);
      return;
    }
    progress.label.textContent = d.label || '';
    progress.cancel.textContent = d.cancelKey ? '[' + d.cancelKey + '] ' + Pop.t('cancel') : '';
    fill.style.transition = 'none';
    fill.style.transform = 'scaleX(0)';
    void fill.offsetWidth; // force le recalcul avant de lancer la transition
    fill.style.transition = 'transform ' + Math.max(0, d.duration || 0) + 'ms linear';
    fill.style.transform = 'scaleX(1)';
    Pop.show(progress, true);
  });

  Pop.on('pop:notify', function (d) {
    while (toasts.children.length >= 3) toasts.removeChild(toasts.firstChild);
    var toast = el('div', 'pop-panel pop-toast pop-fade is-' + (d.type || 'info'), toasts);
    toast.textContent = d.message || '';
    requestAnimationFrame(function () { Pop.show(toast, true); });
    setTimeout(function () {
      Pop.show(toast, false);
      setTimeout(function () { if (toast.parentNode) toast.parentNode.removeChild(toast); }, 200);
    }, Math.max(1000, d.duration || 5000));
  });

  Pop.on('pop:locale', function (d) { Pop.setLocale(d.locale); });

  function init() {
    buildHud();
    // Demande la langue et la couleur au Lua (callback 'pop:ready' du bridge client).
    Pop.post('pop:ready').then(function (cfg) {
      if (!cfg) return;
      Pop.setAccent(cfg.accent);
      Pop.setLocale(cfg.locale);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
