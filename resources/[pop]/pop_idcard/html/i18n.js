// Traductions de l'interface (POP). Les textes viennent du Lua (GetLocaleTable via le
// callback 'pop:ready' du bridge, ou un message { action = 'locale', data = ... }).
// Usage : <span data-i18n="cle"></span>, et T('cle', valeur1, ...) dans le JS.
(function () {
  var RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pop';
  var table = {};

  function T(key) {
    var args = Array.prototype.slice.call(arguments, 1);
    var text = typeof table[key] === 'string' ? table[key] : String(key);
    return text.replace(/%[sd]/g, function (m) { return args.length ? String(args.shift()) : m; });
  }

  function apply(root) {
    (root || document).querySelectorAll('[data-i18n]').forEach(function (el) {
      el.textContent = T(el.getAttribute('data-i18n'));
    });
    (root || document).querySelectorAll('[data-i18n-placeholder]').forEach(function (el) {
      el.setAttribute('placeholder', T(el.getAttribute('data-i18n-placeholder')));
    });
    (root || document).querySelectorAll('[data-i18n-title]').forEach(function (el) {
      el.setAttribute('title', T(el.getAttribute('data-i18n-title')));
    });
  }

  function setLocale(t) {
    table = t || {};
    document.documentElement.dir = table._rtl ? 'rtl' : 'ltr';
    document.documentElement.classList.toggle('is-rtl', !!table._rtl);
    apply();
    document.dispatchEvent(new CustomEvent('i18n:ready'));
  }

  window.T = T;
  window.I18n = { apply: apply, set: setLocale, get: function () { return table; } };

  window.addEventListener('message', function (e) {
    if (e.data && e.data.action === 'locale') setLocale(e.data.data);
  });

  function init() {
    fetch('https://' + RES + '/pop:ready', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: '{}'
    }).then(function (r) { return r.json(); }).then(function (cfg) {
      if (cfg && cfg.locale) setLocale(cfg.locale);
    }).catch(function () {});
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
