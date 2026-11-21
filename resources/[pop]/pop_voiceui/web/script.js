'use strict';

const panel = document.getElementById('voice');
const speaking = document.getElementById('speaking');
const radio = document.getElementById('radio');
const range = document.getElementById('range');

Pop.on('pop_voiceui:update', data => {
  speaking.hidden = data.radio;
  radio.hidden = !data.radio;
  range.hidden = typeof data.range !== 'string';
  if (!range.hidden) range.textContent = data.range;
  Pop.show(panel, data.show);
});

Pop.post('pop_voiceui_ready');
