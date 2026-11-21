const exam   = document.getElementById('exam');
const labels = document.getElementById('labels');
const svg    = document.getElementById('lines');

// Décalage de l'étiquette par rapport au point d'ancrage (en px)
//  side: 'left' = l'étiquette part vers la gauche, 'right' vers la droite
const LAYOUT = {
  head:     { dx:  72, dy: -96, side: 'right' },
  torso:    { dx:  96, dy:   0, side: 'right' },
  rightArm: { dx:  84, dy: -12, side: 'right' },
  rightLeg: { dx:  84, dy:  16, side: 'right' },
  leftArm:  { dx:  84, dy: -12, side: 'left'  },
  leftLeg:  { dx:  84, dy:  16, side: 'left'  },
};

// Icône Font Awesome par zone du corps
const ICONS = {
  head:     'fa-solid fa-brain',
  torso:    'fa-solid fa-heart',
  leftArm:  'fa-solid fa-hand',
  rightArm: 'fa-solid fa-hand',
  leftLeg:  'fa-solid fa-shoe-prints',
  rightLeg: 'fa-solid fa-shoe-prints',
};

const nodes = {}; // key -> { node, label }

function ensureEls(key) {
  if (nodes[key]) return nodes[key];

  const node = document.createElement('div');
  node.className = 'node';

  const label = document.createElement('div');
  label.className = 'label';
  label.innerHTML =
    '<span class="name"><i class="' + (ICONS[key] || '') + '"></i><span class="txt"></span></span>' +
    '<span class="hp"><b></b> <small>santé</small></span>' +
    '<span class="bar"><i></i></span>';

  const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
  line.setAttribute('stroke', 'rgba(255,255,255,0.25)');
  line.setAttribute('stroke-width', '1');
  line.setAttribute('stroke-linecap', 'round');

  labels.appendChild(node);
  labels.appendChild(label);
  svg.appendChild(line);

  nodes[key] = { node, label, line };
  return nodes[key];
}

function setVisible(els, v) {
  const d = v ? '' : 'none';
  els.node.style.display = d;
  els.label.style.display = d;
  els.line.style.display = v ? '' : 'none';
}

function update(parts) {
  const W = window.innerWidth;
  const H = window.innerHeight;

  parts.forEach(p => {
    const els = ensureEls(p.key);

    if (!p.onScreen) { setVisible(els, false); return; }
    setVisible(els, true);

    const nx = p.x * W;
    const ny = p.y * H;
    const lay = LAYOUT[p.key] || { dx: 80, dy: 0, side: 'right' };

    // Point d'ancrage
    els.node.style.left = nx + 'px';
    els.node.style.top  = ny + 'px';

    // Étiquette
    const labelY = ny + lay.dy;
    let anchorX;
    els.label.classList.remove('align-right', 'sev-low', 'sev-med', 'sev-high', 'sev-crit');
    els.label.classList.add('sev-' + p.severity);

    if (lay.side === 'left') {
      anchorX = nx - lay.dx;
      els.label.style.left = anchorX + 'px';
      els.label.style.top  = labelY + 'px';
      els.label.style.transform = 'translate(-100%, -50%)';
      els.label.classList.add('align-right');
    } else {
      anchorX = nx + lay.dx;
      els.label.style.left = anchorX + 'px';
      els.label.style.top  = labelY + 'px';
      els.label.style.transform = 'translateY(-50%)';
    }

    els.node.className = 'node sev-' + p.severity;

    els.label.querySelector('.name .txt').textContent = p.label;
    els.label.querySelector('.hp b').textContent = p.hp + '%';
    els.label.querySelector('.bar > i').style.width = Math.max(0, Math.min(100, p.hp)) + '%';

    // Ligne de liaison
    els.line.setAttribute('x1', nx);
    els.line.setAttribute('y1', ny);
    els.line.setAttribute('x2', anchorX);
    els.line.setAttribute('y2', labelY);
  });
}

window.addEventListener('message', (e) => {
  const d = e.data;
  if (d.action === 'open') {
    exam.classList.remove('hidden');
  } else if (d.action === 'close') {
    exam.classList.add('hidden');
  } else if (d.action === 'update') {
    update(d.parts || []);
  }
});
