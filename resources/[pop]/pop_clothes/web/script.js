(() => {
  'use strict';

  const get = (id) => document.getElementById(id);
  const form = get('shop');
  const catalog = get('catalog');
  const buy = get('buy');
  const format = new Intl.NumberFormat();
  let selections = {};
  let prices = {};
  let currency = '';
  let saving = false;
  let version = 0;

  function option(parent, value, text) {
    const item = document.createElement('option');
    item.value = value;
    item.textContent = text;
    parent.append(item);
  }

  function money(amount) {
    return currency + ' ' + format.format(amount);
  }

  function updateTotal() {
    let total = 0;
    for (const [key, value] of Object.entries(selections)) total += prices[key][value];
    get('total').textContent = Pop.t('total', money(total));
    buy.disabled = saving || Object.keys(selections).length === 0;
  }

  function addCategory(category) {
    const row = document.createElement('label');
    const name = document.createElement('span');
    const select = document.createElement('select');
    name.textContent = Pop.t(category.id);
    prices[category.id] = Object.create(null);
    option(select, '', Pop.t(category.selected ? 'current' : 'keep'));
    for (const current of category.options) {
      if (current.id === category.selected) continue;
      prices[category.id][current.id] = current.price;
      option(select, current.id, Pop.t('option_price', Pop.t(current.label), money(current.price)));
    }
    select.addEventListener('change', () => {
      if (select.value) selections[category.id] = select.value;
      else delete selections[category.id];
      Pop.post('pop_clothes:preview', selections);
      updateTotal();
    });
    row.append(name, select);
    catalog.append(row);
  }

  Pop.on('pop_clothes:panel', (data) => {
    version += 1;
    Pop.show(form, !!data.show);
    if (!data.show) {
      const closing = version;
      setTimeout(() => { if (version === closing) form.hidden = true; }, 150);
      return;
    }
    form.hidden = false;
    saving = false;
    selections = Object.create(null);
    prices = Object.create(null);
    currency = data.currency;
    get('title').textContent = Pop.t(data.kind);
    catalog.replaceChildren();
    catalog.disabled = false;
    for (const category of data.categories || []) addCategory(category);
    updateTotal();
  });

  get('close').addEventListener('click', () => Pop.post('close'));
  for (const button of form.querySelectorAll('.rotate')) {
    button.addEventListener('click', () => Pop.post('pop_clothes:rotate', { direction: Number(button.dataset.direction) }));
  }
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (saving || !Object.keys(selections).length) return;
    const revision = version;
    saving = true;
    catalog.disabled = true;
    updateTotal();
    await Pop.post('pop_clothes:buy', selections);
    if (version !== revision) return;
    saving = false;
    catalog.disabled = false;
    updateTotal();
  });
})();
