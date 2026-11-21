'use strict';

const element = id => document.getElementById(id);
const vitals = ['health', 'armor', 'hunger', 'thirst'];

function meter(id, value) {
  const row = element(id);
  row.hidden = !Number.isFinite(value);
  if (!row.hidden) row.querySelector('meter').value = value;
}

Pop.on('pop_hud:update', data => {
  const vehicle = data.visible && Number.isFinite(data.speed);
  const clock = element('clock');
  clock.hidden = typeof data.clock !== 'string';
  if (!clock.hidden) clock.textContent = data.clock;
  for (const id of vitals) meter(id, data[id]);
  Pop.show(element('vitals'), data.visible && (!clock.hidden || vitals.some(id => !element(id).hidden)));
  if (vehicle) {
    element('speed').textContent = data.speed;
    element('kmh').hidden = data.unit === 'mph';
    element('mph').hidden = data.unit !== 'mph';
    meter('fuel', data.fuel);
  }
  Pop.show(element('vehicle'), vehicle);
});

Pop.post('pop_hud_ready');
