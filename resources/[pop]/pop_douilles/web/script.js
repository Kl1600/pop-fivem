/* pop_douilles : carte rapport balistique. Affichage seul, jamais de focus, aucun texte en dur. */
(function () {
  'use strict';

  var card = document.getElementById('casing-report');
  var fields = {
    caliber: document.getElementById('cr-caliber'),
    signature: document.getElementById('cr-signature'),
    time: document.getElementById('cr-time'),
    street: document.getElementById('cr-street'),
    count: document.getElementById('cr-count')
  };

  function text(value) {
    return (typeof value === 'string' || typeof value === 'number') ? String(value) : '';
  }

  Pop.on('pop_douilles:report', function (data) {
    if (data.show) {
      Pop.translate(card); // libellés à jour si la langue a changé
      fields.caliber.textContent = text(data.caliber) || Pop.t('caliber_unknown');
      fields.signature.textContent = text(data.signature);
      fields.time.textContent = text(data.time);
      fields.street.textContent = text(data.street) || Pop.t('street_unknown');
      fields.count.textContent = text(data.count) || '\u2014'; // nil → tiret cadratin
    }
    Pop.show(card, data.show);
  });
})();
