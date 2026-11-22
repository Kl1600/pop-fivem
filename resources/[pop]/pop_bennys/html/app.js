'use strict';

// ── State ─────────────────────────────────────────────────────────────────────
const S = {
  vehicle: null,
  itemCosts: {},
  itemDb: {},
  unknownIcon: '',
  cat: 'wheels',
  changes: {},
};

function resetChanges() {
  S.changes = {
    wheelType: null, wheelMod: null,
    bodyMods: {},
    engine: null, brakes: null, trans: null,
    susp: null, armor: null, turbo: null, xenon: null,
    neonColor: null, neons: {},
    winTint: null, plateStyle: null, plateText: null,
    livery: null, liverySystem: null, extras: {},
  };
}

// ── Constants ─────────────────────────────────────────────────────────────────
const CATS = [
  { id: 'wheels',  label: 'JANTES',      icon: 'fa-solid fa-dharmachakra' },
  { id: 'body',    label: 'CARROSSERIE', icon: 'fa-solid fa-car-side' },
  { id: 'perf',    label: 'PERFORMANCE', icon: 'fa-solid fa-gauge-high' },
  { id: 'neons',   label: 'NÉONS',       icon: 'fa-solid fa-lightbulb' },
  { id: 'windows', label: 'VITRES',      icon: 'fa-solid fa-circle-half-stroke' },
  { id: 'plate',   label: 'PLAQUE',      icon: 'fa-solid fa-id-card' },
  { id: 'liveries',label: 'LIVRÉE',      icon: 'fa-solid fa-paint-roller' },
  { id: 'extras',  label: 'EXTRAS',      icon: 'fa-solid fa-puzzle-piece' },
];

const WHEEL_TYPES = [
  'SPORT','MUSCLE','LOWRIDER','SUV','OFFROAD','TUNER','BIKE','HIGH END',"BENNY'S",'BESPOKE'
];

const TINTS = [
  { name:'AUCUNE',      bg:'rgba(180,210,255,.08)' },
  { name:'NOIR PUR',    bg:'rgba(0,0,0,.95)' },
  { name:'FUMÉ FONCÉ',  bg:'rgba(18,18,18,.82)' },
  { name:'FUMÉ CLAIR',  bg:'rgba(50,50,50,.55)' },
  { name:'STOCK',       bg:'rgba(180,210,180,.2)' },
  { name:'LIMOUSINE',   bg:'rgba(0,0,0,.88)' },
  { name:'VERT',        bg:'rgba(20,90,30,.65)' },
];

const BODY_MODS = [
  {t:0, l:'Aileron'},
  {t:1, l:'Pare-choc avant'},
  {t:2, l:'Pare-choc arrière'},
  {t:3, l:'Jupes latérales'},
  {t:4, l:'Échappement'},
  {t:6, l:'Grille'},
  {t:7, l:'Capot'},
  {t:8, l:'Aile gauche'},
  {t:9, l:'Aile droite'},
  {t:10,l:'Toit'},
];

const PERF_MODS = [
  {t:11, l:'Moteur',       lvls:['STOCK','LVL I','LVL II','LVL III','LVL IV'], tog:false},
  {t:12, l:'Freins',       lvls:['STOCK','RUE','SPORT','COURSE'], tog:false},
  {t:13, l:'Boîte',        lvls:['STOCK','RUE','SPORT','COURSE'], tog:false},
  {t:15, l:'Suspension',   lvls:['STOCK','ABAISSÉE','RUE','SPORT','COURSE'], tog:false},
  {t:16, l:'Blindage',     lvls:['STOCK','LVL I','LVL II','LVL III','LVL IV','LVL V'], tog:false},
  {t:18, l:'Turbo',        tog:true},
  {t:22, l:'Phares Xénon', tog:true},
];

const PLATE_STYLES = [
  {s:0, prev:'ABC 1234', bg:'#f5e4a0', col:'#1a1a1a', n:'JAUNE / NOIR'},
  {s:1, prev:'ABC 1234', bg:'#1a1a2e', col:'#c8c8ff', n:'BLEU NUIT'},
  {s:2, prev:'ABC 1234', bg:'#f5f5f5', col:'#1a1a1a', n:'BLANC / NOIR'},
  {s:3, prev:'ABC 1234', bg:'#1a1a1a', col:'#f5f5f5', n:'NOIR / BLANC'},
  {s:4, prev:'ABC 1234', bg:'#2d4a8a', col:'#a8c8e8', n:'BLEU CLAIR'},
  {s:5, prev:'YANKTON',  bg:'#f5e4a0', col:'#c84a1a', n:'YANKTON'},
];

const NEON_SIDES = ['Avant','Arrière','Gauche','Droite'];

// 80 presets (4 rows visible at once in 20-col grid)
const PRESETS = [
  // Grays
  [13,17,22],[26,26,26],[53,53,53],[83,83,83],[110,110,110],
  [145,145,145],[175,175,175],[200,200,200],[225,225,225],[255,255,255],
  // Reds
  [70,8,8],[120,12,12],[170,18,18],[210,28,28],[230,50,50],
  [245,90,80],[220,70,55],[195,55,40],[160,35,30],[110,20,20],
  // Oranges/Yellows
  [150,55,0],[200,78,0],[235,108,0],[255,138,0],[255,172,0],
  [252,212,0],[245,235,0],[225,215,15],[195,185,25],[155,150,15],
  // Greens
  [8,55,8],[18,95,18],[38,135,38],[58,165,58],[78,195,78],
  [95,195,95],[18,155,75],[0,125,75],[0,175,115],[0,195,145],
  // Blues
  [0,35,115],[10,58,155],[22,98,198],[38,128,218],[68,158,228],
  [115,188,242],[0,175,215],[0,148,198],[0,118,178],[0,95,155],
  // Purples/Pinks
  [48,8,78],[78,18,128],[108,38,168],[148,58,198],[178,88,218],
  [218,118,228],[238,138,198],[228,98,158],[208,58,128],[175,38,98],
  // Browns/Golds
  [58,28,8],[98,48,18],[138,78,28],[178,118,48],[198,148,68],
  [201,162,39],[188,148,58],[158,118,48],[118,88,38],[78,52,18],
  // Neons / Special
  [255,0,80],[255,0,190],[195,0,255],[95,0,255],[0,95,255],
  [0,255,255],[0,255,95],[95,255,0],[255,255,0],[255,95,0],
];

// ── Fetch helper ──────────────────────────────────────────────────────────────
function post(cb, data) {
  fetch(`https://${GetParentResourceName()}/${cb}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
}

// ── Coût en items ───────────────────────────────────────────────────────────────
// Catégories de coût affectées par les changements en cours -> [ [cat, multiplicateur] ].
function changedCategories() {
  const C = S.changes;
  const out = [];
  if (C.wheelType !== null || C.wheelMod !== null) out.push(['wheel', 1]);
  const bodyN = Object.keys(C.bodyMods).length;
  if (bodyN) out.push(['body', bodyN]);
  if ([C.engine,C.brakes,C.trans,C.susp,C.armor,C.turbo,C.xenon].some(v => v !== null)) out.push(['performance', 1]);
  if (C.neonColor || Object.keys(C.neons).length) out.push(['neon', 1]);
  if (C.winTint !== null) out.push(['window', 1]);
  if (C.plateStyle !== null || C.plateText !== null) out.push(['plate', 1]);
  if (C.livery !== null) out.push(['livery', 1]);
  const extraN = Object.keys(C.extras).length;
  if (extraN) out.push(['extra', extraN]);
  return out;
}

// Agrège les items requis sur tous les changements en cours -> [ {item, qty} ].
function computeRequiredItems() {
  const agg = {};
  for (const [cat, mult] of changedCategories()) {
    const recipe = (S.itemCosts && S.itemCosts[cat]) || [];
    for (const need of recipe) {
      if (!agg[need.item]) agg[need.item] = { item: need.item, qty: 0 };
      agg[need.item].qty += (need.qty || 0) * mult;
    }
  }
  return Object.values(agg);
}

function refreshCost() {
  const panel = document.getElementById('cost-panel');
  const applyBtn = document.getElementById('apply-btn');
  if (!panel) return;
  const items = computeRequiredItems();

  if (!items.length) {
    panel.innerHTML = `<div class="cost-empty">Aucune modification</div>`;
    if (applyBtn) applyBtn.classList.remove('disabled');
    return;
  }

  let affordable = true;
  panel.innerHTML = items.map(it => {
    const def = (S.itemDb && S.itemDb[it.item]) || {};
    const have = def.owned || 0;
    const ok = have >= it.qty;
    if (!ok) affordable = false;
    const icon = def.icon || S.unknownIcon;
    const label = def.label || it.item;
    const missing = def.exists === false ? ' title="Item introuvable dans l\'inventaire"' : '';
    return `
      <div class="cost-item ${ok ? 'ok' : 'no'}"${missing}>
        <img class="cost-icon" src="${icon}" onerror="this.onerror=null;this.src='${S.unknownIcon}'">
        <span class="cost-name">${label}</span>
        <span class="cost-qty">${have}/${it.qty}</span>
      </div>`;
  }).join('');

  if (applyBtn) applyBtn.classList.toggle('disabled', !affordable);
}

// ── Sidebar ───────────────────────────────────────────────────────────────────
function renderSidebar() {
  document.getElementById('categories').innerHTML = CATS.map(c => `
    <div class="cat-item ${S.cat === c.id ? 'active' : ''}" onclick="selectCat('${c.id}')" title="${c.label}">
      <i class="${c.icon}"></i>
    </div>`).join('');
}

function selectCat(id) { S.cat = id; renderSidebar(); renderContent(); post('focusCamera', { cat: id }); }

// ── Content router ────────────────────────────────────────────────────────────
function renderContent() {
  const el = document.getElementById('content');
  el.innerHTML = ({
    wheels:  renderWheels,
    body:    renderBody,
    perf:    renderPerf,
    neons:   renderNeons,
    windows:  renderWindows,
    plate:    renderPlate,
    liveries: renderLiveries,
    extras:   renderExtras,
  })[S.cat]();
}

// ── Color helpers (partagés : néons) ──────────────────────────────────────────
function swatchHtml(presets) {
  return presets.map(c =>
    `<div class="swatch" style="background:rgb(${c[0]},${c[1]},${c[2]})"
          onclick="swatchClick(this,${c[0]},${c[1]},${c[2]})"></div>`
  ).join('');
}

function rgbBoxHtml(id, r, g, b, onInput) {
  return `
  <div class="rgb-box">
    <div class="slider-row">
      <span class="sl-lbl">R</span>
      <input type="range" min="0" max="255" value="${r}" id="${id}-r" oninput="${onInput}">
      <span class="sl-val" id="${id}-r-v">${r}</span>
    </div>
    <div class="slider-row">
      <span class="sl-lbl">G</span>
      <input type="range" min="0" max="255" value="${g}" id="${id}-g" oninput="${onInput}">
      <span class="sl-val" id="${id}-g-v">${g}</span>
    </div>
    <div class="slider-row">
      <span class="sl-lbl">B</span>
      <input type="range" min="0" max="255" value="${b}" id="${id}-b" oninput="${onInput}">
      <span class="sl-val" id="${id}-b-v">${b}</span>
    </div>
    <div class="slider-row" style="margin-top:4px">
      <div class="color-preview" id="${id}-prev" style="background:rgb(${r},${g},${b})"></div>
    </div>
  </div>`;
}

// ── Wheels ────────────────────────────────────────────────────────────────────
function renderWheels() {
  const v = S.vehicle;
  const curType = S.changes.wheelType ?? v.wheelType ?? 0;
  const curMod  = S.changes.wheelMod  ?? v.wheelMod  ?? 0;
  const maxMod  = Math.max(0, (v.modCounts['23'] || 1) - 1);
  return `
    <div class="sec-title">TYPE</div>
    <div class="wtype-grid">
      ${WHEEL_TYPES.map((n,i) => `
        <div class="wtype-btn ${curType===i?'active':''}" onclick="selectWheelType(${i})">${n}</div>
      `).join('')}
    </div>
    <div class="sec-title">MODÈLE</div>
    <div class="row-item">
      <span class="row-label">Style de jante</span>
      <div class="stepper">
        <button class="step-btn" onclick="stepWheel(-1)" ${curMod<=0?'disabled':''}>−</button>
        <span class="step-val">${curMod+1} / ${maxMod+1}</span>
        <button class="step-btn" onclick="stepWheel(1)"  ${curMod>=maxMod?'disabled':''}>+</button>
      </div>
    </div>`;
}

function selectWheelType(t) {
  S.changes.wheelType = t; S.changes.wheelMod = 0;
  post('preview_wheel', {wheelType: t, modIndex: 0, customTires: false});
  refreshCost(); renderContent();
}
function stepWheel(d) {
  const v = S.vehicle;
  const max = Math.max(0, (v.modCounts['23']||1)-1);
  let c = S.changes.wheelMod ?? v.wheelMod ?? 0;
  c = Math.max(0, Math.min(max, c+d));
  S.changes.wheelMod = c;
  const type = S.changes.wheelType ?? v.wheelType ?? 0;
  post('preview_wheel', {wheelType: type, modIndex: c, customTires: false});
  refreshCost(); renderContent();
}

// ── Body ──────────────────────────────────────────────────────────────────────
function renderBody() {
  const v = S.vehicle;
  return `<div class="sec-title">CARROSSERIE</div>` +
    BODY_MODS.map(m => {
      const max = (v.modCounts[String(m.t)] || 0);
      const cur = S.changes.bodyMods[m.t] ?? (v.bodyMods?.[String(m.t)] ?? -1);
      return `
        <div class="row-item">
          <span class="row-label">${m.l}</span>
          <div class="stepper">
            <button class="step-btn" onclick="stepBody(${m.t},-1)" ${cur<=-1?'disabled':''}>−</button>
            <span class="step-val">${cur===-1?'STOCK':`${cur+1} / ${max}`}</span>
            <button class="step-btn" onclick="stepBody(${m.t},1)"  ${cur>=max-1?'disabled':''}>+</button>
          </div>
        </div>`;
    }).join('');
}
function stepBody(t, d) {
  const v = S.vehicle;
  const max = (v.modCounts[String(t)]||0)-1;
  let c = S.changes.bodyMods[t] ?? (v.bodyMods?.[String(t)] ?? -1);
  c = Math.max(-1, Math.min(max, c+d));
  S.changes.bodyMods[t] = c;
  post('preview_body', {modType:t, modIndex:c});
  refreshCost(); renderContent();
}

// ── Performance ───────────────────────────────────────────────────────────────
const PERF_KEY = {11:'engine',12:'brakes',13:'trans',15:'susp',16:'armor',18:'turbo',22:'xenon'};

function renderPerf() {
  const v = S.vehicle;
  return `<div class="sec-title">AMÉLIORATIONS</div>` +
    PERF_MODS.map(m => {
      const key = PERF_KEY[m.t];
      const cur = S.changes[key] ?? v[key] ?? (m.tog ? false : -1);
      if (m.tog) return `
        <div class="row-item" onclick="togglePerf(${m.t},'${key}')" style="cursor:pointer">
          <span class="row-label">${m.l}</span>
          <div class="toggle ${cur?'on':''}"></div>
        </div>`;
      return `
        <div class="row-item">
          <span class="row-label">${m.l}</span>
          <div class="levels">
            ${m.lvls.map((n,i) => `
              <div class="lvl-btn ${(cur+1)===i?'active':''}"
                   onclick="selectPerfLvl(${m.t},'${key}',${i-1})">${n}</div>
            `).join('')}
          </div>
        </div>`;
    }).join('');
}
function togglePerf(t, key) {
  const v = S.vehicle;
  const cur = S.changes[key] ?? v[key] ?? false;
  S.changes[key] = !cur;
  post('preview_performance', {modType:t, isToggle:true, value:!cur});
  refreshCost(); renderContent();
}
function selectPerfLvl(t, key, lvl) {
  S.changes[key] = lvl;
  post('preview_performance', {modType:t, isToggle:false, modIndex:lvl});
  refreshCost(); renderContent();
}

// ── Neons ─────────────────────────────────────────────────────────────────────
function renderNeons() {
  const v = S.vehicle;
  const nc = S.changes.neonColor || {r: v.nr||255, g: v.ng||0, b: v.nb||200};
  const neons = [0,1,2,3].map(i => S.changes.neons[i] ?? (v.neons?.[i] ?? false));
  return `
    <div class="sec-title">ACTIVATION</div>
    <div class="neon-grid">
      ${NEON_SIDES.map((n,i) => `
        <div class="row-item" onclick="toggleNeon(${i})" style="cursor:pointer">
          <span class="row-label">${n}</span>
          <div class="toggle ${neons[i]?'on':''}"></div>
        </div>`).join('')}
    </div>
    <div class="sec-title">COULEUR</div>
    <div class="color-grid neon-swatches">${swatchHtml(PRESETS.slice(70))}</div>
    ${rgbBoxHtml('nc', nc.r, nc.g, nc.b, 'onNeonRGB()')}`;
}
function toggleNeon(i) {
  const v = S.vehicle;
  const cur = S.changes.neons[i] ?? (v.neons?.[i] ?? false);
  S.changes.neons[i] = !cur;
  post('preview_neon', {type:'toggle', index:i, enabled:!cur});
  refreshCost(); renderContent();
}

// swatchClick : sélection de couleur depuis la grille de néons.
function swatchClick(el, r, g, b) {
  const grid = el.closest('.color-grid');
  if (grid && grid.classList.contains('neon-swatches')) {
    const nc = document.getElementById('nc-r');
    if (nc) {
      nc.value = r;
      document.getElementById('nc-g').value = g;
      document.getElementById('nc-b').value = b;
      onNeonRGB();
    }
  }
}

function onNeonRGB() {
  const r = +document.getElementById('nc-r').value;
  const g = +document.getElementById('nc-g').value;
  const b = +document.getElementById('nc-b').value;
  document.getElementById('nc-r-v').textContent = r;
  document.getElementById('nc-g-v').textContent = g;
  document.getElementById('nc-b-v').textContent = b;
  const prev = document.getElementById('nc-prev');
  if (prev) { prev.style.background = `rgb(${r},${g},${b})`; prev.style.boxShadow = `0 0 10px rgb(${r},${g},${b})`; }
  S.changes.neonColor = {r,g,b};
  post('preview_neon', {type:'color', r, g, b});
  refreshCost();
}

// ── Windows ───────────────────────────────────────────────────────────────────
function renderWindows() {
  const cur = S.changes.winTint ?? S.vehicle.winTint ?? 0;
  return `
    <div class="sec-title">TEINTE DES VITRES</div>
    <div class="tint-grid">
      ${TINTS.map((t,i) => `
        <div class="tint-btn ${cur===i?'active':''}" onclick="selectTint(${i})">
          <div class="tint-swatch" style="background:${t.bg}"></div>
          <div class="tint-name">${t.name}</div>
        </div>`).join('')}
    </div>`;
}
function selectTint(i) {
  S.changes.winTint = i;
  post('preview_window', {tint:i});
  refreshCost(); renderContent();
}

// ── Plate ─────────────────────────────────────────────────────────────────────
function renderPlate() {
  const v = S.vehicle;
  const curS = S.changes.plateStyle ?? v.plateStyle ?? 0;
  const curT = S.changes.plateText  ?? v.plateText  ?? '';
  return `
    <div class="sec-title">TEXTE</div>
    <input class="plate-input" maxlength="8" value="${curT}"
           placeholder="ABC 1234" readonly
           title="Le texte de la plaque ne se modifie pas ici">
    <div class="sec-title">STYLE</div>
    <div class="plate-styles">
      ${PLATE_STYLES.map(p => `
        <div class="ps-btn ${curS===p.s?'active':''}" onclick="selectPlateStyle(${p.s})">
          <div class="ps-preview" style="background:${p.bg};color:${p.col}">${p.prev}</div>
          <div class="ps-name">${p.n}</div>
        </div>`).join('')}
    </div>`;
}
function onPlateText(t) {
  S.changes.plateText = t.toUpperCase();
  post('preview_plate', {text: t.toUpperCase()});
  refreshCost();
}
function selectPlateStyle(s) {
  S.changes.plateStyle = s;
  post('preview_plate', {style:s});
  refreshCost(); renderContent();
}

// ── Liveries ──────────────────────────────────────────────────────────────────
// Système dédié (GetVehicleLiveryCount) prioritaire ; sinon livrées via mod 48.
function liveryInfo() {
  const v = S.vehicle;
  const dedicated = (v.liveryCount ?? -1) > 0;
  const system = dedicated ? 'livery' : 'mod';
  const count  = dedicated ? v.liveryCount : (Number(v.modCounts['48']) || 0);
  const min    = dedicated ? 0 : -1;                          // mod 48 : -1 = stock
  const orig   = dedicated ? (v.livery ?? 0) : (v.liveryMod ?? -1);
  return { dedicated, system, count, min, orig };
}

function renderLiveries() {
  const { count, min, orig } = liveryInfo();
  if (count <= 0) {
    return `<div class="sec-title">LIVRÉE</div>
      <div class="empty-note">Aucune livrée disponible pour ce véhicule.</div>`;
  }
  const cur = S.changes.livery ?? orig;
  const label = cur < 0 ? 'STOCK' : `${cur + 1} / ${count}`;
  return `
    <div class="sec-title">LIVRÉE</div>
    <div class="row-item">
      <span class="row-label">Motif</span>
      <div class="stepper">
        <button class="step-btn" onclick="stepLivery(-1)" ${cur<=min?'disabled':''}>−</button>
        <span class="step-val">${label}</span>
        <button class="step-btn" onclick="stepLivery(1)" ${cur>=count-1?'disabled':''}>+</button>
      </div>
    </div>`;
}
function stepLivery(d) {
  const { system, count, min, orig } = liveryInfo();
  let c = S.changes.livery ?? orig;
  c = Math.max(min, Math.min(count - 1, c + d));
  // Retour à l'état d'origine -> pas de coût.
  S.changes.livery = (c === orig) ? null : c;
  S.changes.liverySystem = system;
  post('preview_livery', { system, index: c });
  refreshCost(); renderContent();
}

// ── Extras ────────────────────────────────────────────────────────────────────
function renderExtras() {
  const extras = S.vehicle.extras || [];
  if (!extras.length) {
    return `<div class="sec-title">EXTRAS</div>
      <div class="empty-note">Aucun extra disponible pour ce véhicule.</div>`;
  }
  return `<div class="sec-title">ACCESSOIRES</div>` +
    extras.map(e => {
      const on = S.changes.extras[e.id] ?? e.on;
      return `
        <div class="row-item" onclick="toggleExtra(${e.id})" style="cursor:pointer">
          <span class="row-label">Extra ${e.id}</span>
          <div class="toggle ${on?'on':''}"></div>
        </div>`;
    }).join('');
}
function toggleExtra(id) {
  const orig = (S.vehicle.extras || []).find(e => e.id === id);
  const cur  = S.changes.extras[id] ?? (orig ? orig.on : false);
  const next = !cur;
  // Retour à l'état d'origine -> on retire le changement (pas de coût).
  if (orig && next === orig.on) delete S.changes.extras[id];
  else S.changes.extras[id] = next;
  post('preview_extra', { id, enabled: next });
  refreshCost(); renderContent();
}

// ── Menu controls ─────────────────────────────────────────────────────────────
function closeMenu() {
  post('close', {});
  document.getElementById('app').style.display = 'none';
}
function applyMods() {
  const applyBtn = document.getElementById('apply-btn');
  if (applyBtn && applyBtn.classList.contains('disabled')) return; // pas assez d'items
  post('apply', { items: computeRequiredItems() });
  document.getElementById('app').style.display = 'none';
}

// ── NUI message listener ──────────────────────────────────────────────────────
window.addEventListener('message', e => {
  const d = e.data;
  if (d.action === 'open') {
    S.vehicle     = d.vehicle;
    S.itemCosts   = d.itemCosts || {};
    S.itemDb      = d.itemDb || {};
    S.unknownIcon = d.unknownIcon || '';
    S.cat         = 'wheels';
    resetChanges();
    document.getElementById('vehicle-name').textContent =
      (d.vehicle.model || '—') + '  ·  ' + (d.vehicle.plate || '');
    document.getElementById('app').style.display = 'flex';
    refreshCost();
    renderSidebar();
    renderContent();
  } else if (d.action === 'close') {
    document.getElementById('app').style.display = 'none';
  }
});
