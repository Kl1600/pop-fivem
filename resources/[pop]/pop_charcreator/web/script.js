(() => {
  'use strict';

  const get = (id) => document.getElementById(id);
  const form = get('character');
  const model = get('model');
  const fields = get('appearance');
  const spawn = get('spawn');
  let limits = {};
  let appearance = {};
  let previewTimer;
  let sending = false;
  let version = 0;

  function option(parent, id, key) {
    const item = document.createElement('option');
    item.value = id;
    item.textContent = Pop.t(key);
    parent.append(item);
  }

  function queuePreview() {
    clearTimeout(previewTimer);
    previewTimer = setTimeout(() => Pop.post('pop_charcreator:preview', appearance), 120);
  }

  function showAppearance() {
    const next = { model: model.value };
    fields.replaceChildren();
    for (const rule of limits[model.value] || []) {
      const label = document.createElement('label');
      const name = document.createElement('span');
      const out = document.createElement('output');
      const slider = document.createElement('input');
      name.textContent = Pop.t(rule.key);
      name.append(out);
      slider.type = 'range';
      slider.min = rule.min;
      slider.max = rule.max;
      const value = appearance[rule.key];
      next[rule.key] = Number.isInteger(value) ? Math.max(rule.min, Math.min(rule.max, value)) : rule.default;
      slider.value = next[rule.key];
      out.textContent = slider.value;
      slider.addEventListener('input', () => {
        appearance[rule.key] = Number(slider.value);
        out.textContent = slider.value;
        queuePreview();
      });
      label.append(name, slider);
      fields.append(label);
    }
    appearance = next;
  }

  Pop.on('pop_charcreator:panel', (data) => {
    version += 1;
    clearTimeout(previewTimer);
    const shown = Boolean(data.show);
    Pop.show(form, shown);
    if (!shown) {
      const closing = version;
      setTimeout(() => { if (version === closing) form.hidden = true; }, 150);
      return;
    }
    form.hidden = false;
    limits = data.limits;
    appearance = data.profile;
    model.replaceChildren();
    option(model, 'mp_m_freemode_01', 'model_male');
    option(model, 'mp_f_freemode_01', 'model_female');
    model.value = appearance.model;
    get('first').value = appearance.firstName || '';
    get('last').value = appearance.lastName || '';
    const birth = get('birth');
    birth.min = data.birth.min;
    birth.max = data.birth.max;
    birth.value = appearance.dateOfBirth || '';
    spawn.replaceChildren();
    const spawns = Array.isArray(data.spawns) ? data.spawns : [];
    for (const place of spawns) option(spawn, place.id, place.label);
    get('spawn-label').hidden = !spawns.length;
    if (spawns.some((place) => place.id === data.defaultSpawn)) spawn.value = data.defaultSpawn;
    get('fields').disabled = false;
    get('save').disabled = false;
    sending = false;
    showAppearance();
  });

  model.addEventListener('change', () => { showAppearance(); queuePreview(); });
  get('close').addEventListener('click', () => Pop.post('close'));
  for (const button of form.querySelectorAll('.rotate')) {
    button.addEventListener('click', () => Pop.post('pop_charcreator:rotate', { direction: Number(button.dataset.direction) }));
  }
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (sending) return;
    const revision = version;
    const profile = {
      ...appearance, firstName: get('first').value, lastName: get('last').value, dateOfBirth: get('birth').value,
    };
    const selectedSpawn = spawn.value || undefined;
    sending = true;
    get('fields').disabled = true;
    get('save').disabled = true;
    await Pop.post('pop_charcreator:save', { profile, spawn: selectedSpawn });
    if (revision !== version) return;
    sending = false;
    get('fields').disabled = false;
    get('save').disabled = false;
  });
})();
