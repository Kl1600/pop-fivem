(() => {
  'use strict';

  const byId = id => document.getElementById(id);
  const panel = byId('document');
  let expiry;

  function hide() {
    clearTimeout(expiry);
    Pop.show(panel, false);
  }

  function field(id, value, row) {
    byId(id).textContent = value || '';
    if (row) byId(row).classList.toggle('pop-hidden', !value);
  }

  Pop.on('pop_passport:card', ({ document: card, duration }) => {
    if (!card) return;
    clearTimeout(expiry);
    field('variant', Pop.t('document_' + card.variant));
    field('name', card.name);
    field('serial', card.serial);
    field('birth', card.birthDate, 'birth-row');
    field('sex', card.sex && Pop.t('document_' + card.sex), 'sex-row');
    field('issued', card.issuedAt);
    field('expiry', card.expiresAt, 'expiry-row');
    Pop.show(panel, true);
    expiry = setTimeout(hide, duration);
  });
  Pop.on('pop_passport:hide', hide);
})();
