const app          = document.getElementById('app');
const toastEl      = document.getElementById('toast');
const unitCountEl  = document.getElementById('unit-count'); // peut être null si enlévé
const headerMatEl  = document.getElementById('header-matricule');
const deptNameEl   = document.getElementById('dept-name');
const notifList    = document.getElementById('notifications-list');
const ctxMenu      = document.getElementById('ctx');
const sitMenu      = document.getElementById('sit-menu');

const myCsText     = document.getElementById('my-callsign-text');
const myCsInput    = document.getElementById('my-callsign-input');
const mySit        = document.getElementById('my-situation');
const myId         = document.getElementById('my-id');
const myName       = document.getElementById('my-name');
const editCs       = document.getElementById('edit-callsign');
const confirmCs    = document.getElementById('confirm-callsign');
const pingLoc      = document.getElementById('ping-loc');
const openSit      = document.getElementById('open-situation');
const muteBtn      = document.getElementById('btn-mute');

// Matricule
const matBadge     = document.getElementById('mat-badge');
const matEl        = document.getElementById('my-matricule');
const editMat      = document.getElementById('edit-mat');
const matInput     = document.getElementById('mat-input');

// Patrouille
const patrolEmpty  = document.getElementById('patrol-empty');
const patrolForm   = document.getElementById('patrol-form');
const patrolActive = document.getElementById('patrol-active');
const btnNewPatrol = document.getElementById('btn-new-patrol');
const btnCancelPat = document.getElementById('btn-cancel-patrol');
const btnConfirmPat= document.getElementById('btn-confirm-patrol');
const btnEndPat    = document.getElementById('btn-end-patrol');
const inputType    = document.getElementById('patrol-type');
const inputCs      = document.getElementById('patrol-callsign');
const inputSector  = document.getElementById('patrol-sector');
const inputRadio   = document.getElementById('patrol-radio');
const patrolMeta   = document.getElementById('patrol-meta');

const searchInp    = document.getElementById('search-input');
const vehListEl    = document.getElementById('veh-list');
const citListEl    = document.getElementById('cit-list');

const state = {
  duty: false, muted: false,
  units: [], calls: [],
  callsign: '', situation: '10-8',
  matricule: '000',
  myId: '06', myName: 'Dev Blankaa',
  ctxCallId: null,
  wantedVehicles: [], wantedCitizens: [],
  dbVehicles: [], dbCitizens: [],
  situations: [],
  grades: [],
  patrol: null,   // { type, callsign, sector } | null
  deptName: 'Police',
  myGrade: '',
};

const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pop_police';
function send(name, data) {
  return fetch(`https://${RES}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {}),
  }).then(r => r.json()).catch(() => ({}));
}

// ===== Tabs =====
document.querySelectorAll('.tab').forEach(t => {
  t.addEventListener('click', () => {
    document.querySelectorAll('.tab').forEach(x => x.classList.remove('active'));
    document.querySelectorAll('.tab-panel').forEach(x => x.classList.remove('active'));
    t.classList.add('active');
    document.getElementById('tab-' + t.dataset.tab).classList.add('active');
  });
});

// ===== Header actions =====
function attemptRequestBackup(level, label) {
  if (!state.duty) {
    showToast("Vous devez être en service.");
    return;
  }
  
  const myPatrolId = state.patrol ? state.patrol.id : null;
  const myIdStr = String(state.myId);
  const alreadyActive = state.calls.some(c => {
    if (c.isGunshot) return false;
    if (String(c.requesterSrc) === myIdStr) return true;
    if (myPatrolId && c.patrol && c.patrol.id === myPatrolId) return true;
    return false;
  });

  if (alreadyActive) {
    showToast("Vous ou votre patrouille avez déjà un appel de renfort actif.");
    return;
  }

  send('requestBackup', { level, label });
}

document.getElementById('btn-backup-1').addEventListener('click', () => attemptRequestBackup(1, 'Backup Sud Niveau 1 demandé'));
document.getElementById('btn-backup-2').addEventListener('click', () => attemptRequestBackup(2, 'Backup Sud Niveau 2 demandé'));
document.getElementById('btn-backup-3').addEventListener('click', () => attemptRequestBackup(3, 'Backup Sud Niveau 3 demandé'));

muteBtn.addEventListener('click', () => {
  state.muted = !state.muted;
  muteBtn.classList.toggle('muted', state.muted);
  send('toggleMute', { state: state.muted });
});

document.addEventListener('keydown', e => { if (e.key === 'Escape' || e.code === 'Escape' || e.keyCode === 27) send('close'); });

// ===== Unités / situation / callsign =====
function applyDutyVisual() {
  document.querySelectorAll('#btn-duty').forEach(b => {
    b.classList.toggle('on', state.duty);
    b.textContent = state.duty ? 'En service' : 'Prendre service';
  });
  // Bloquer ou débloquer le bouton Patrouille selon le service
  const btnPat = document.getElementById('btn-new-patrol');
  if (btnPat) {
    btnPat.disabled = !state.duty;
    btnPat.style.opacity = state.duty ? '' : '0.38';
    btnPat.style.cursor  = state.duty ? '' : 'not-allowed';
    btnPat.title = state.duty ? '' : 'Prenez service avant de déclarer une patrouille';
  }
}
document.querySelectorAll('#btn-duty').forEach(b => {
  b.addEventListener('click', () => {
    // Bloquer la sortie de service si une patrouille est active
    if (state.duty && state.patrol) {
      const btn = b;
      const orig = btn.textContent;
      btn.textContent = 'Terminez la patrouille d\'abord';
      btn.style.color = '#e74c3c';
      setTimeout(() => { btn.textContent = orig; btn.style.color = ''; }, 2500);
      return;
    }
    state.duty = !state.duty;
    applyDutyVisual();
    send('toggleDuty', { state: state.duty });
    renderAgentsList();
  });
});

// ===== Matricule =====
function applyMatricule() {
  if (matEl) matEl.textContent = state.matricule || '000';
  if (headerMatEl) headerMatEl.textContent = state.matricule || '000';
  if (patrolMeta) updatePatrolMetaText();
}
function openMatEdit() {
  matInput.value = state.matricule || '';
  matInput.classList.remove('hidden');
  matInput.focus(); matInput.select();
}
function commitMat() {
  const v = (matInput.value || '').trim();
  if (v) {
    state.matricule = v;
    send('setMatricule', { matricule: v });
    applyMatricule();
  }
  matInput.classList.add('hidden');
}
editMat ?.addEventListener('click', openMatEdit);
matBadge?.addEventListener('click', openMatEdit);
matInput?.addEventListener('keyup', e => {
  if (e.key === 'Enter') commitMat();
  if (e.key === 'Escape') matInput.classList.add('hidden');
});
matInput?.addEventListener('blur', commitMat);

function updatePatrolMetaText() {
  if (!state.patrol) return;
  const sec = state.patrol.sector ? ` · ${escapeHtml(state.patrol.sector)}` : '';
  const typ = state.patrol.type   ? ` · ${escapeHtml(state.patrol.type)}`   : '';
  const mat = state.matricule ? `[MAT-${escapeHtml(state.matricule)}] ` : '';
  
  let html = `<div>${mat}${state.myId} - ${escapeHtml(state.myName)}${typ}${sec}</div>`;
  
  if (state.patrol.id) {
    const members = state.units.filter(u => u.patrol && u.patrol.id === state.patrol.id && String(u.src) !== String(state.myId));
    for (const m of members) {
      const mMat = m.matricule ? `[MAT-${escapeHtml(m.matricule)}] ` : '';
      html += `<div style="opacity: 0.8; margin-top: 4px;">${mMat}${m.src} - ${escapeHtml(m.name)}</div>`;
    }
  }
  
  patrolMeta.innerHTML = html;
}

// ===== Patrouille — 3 états =====
function renderPatrolState() {
  const has = !!state.patrol;
  patrolEmpty .classList.toggle('hidden', has);
  patrolActive.classList.toggle('hidden', !has);
  patrolForm  .classList.add('hidden');
  if (has) {
    state.callsign = state.patrol.callsign || state.callsign;
    myCsText.textContent = state.callsign;
    updatePatrolMetaText();
    applySituationVisual();
  }
}

btnNewPatrol.addEventListener('click', () => {
  if (!state.duty) {
    const orig = btnNewPatrol.innerHTML;
    btnNewPatrol.textContent = "Prenez service d'abord";
    btnNewPatrol.style.color = '#e74c3c';
    setTimeout(() => { btnNewPatrol.innerHTML = orig; btnNewPatrol.style.color = ''; }, 2500);
    return;
  }
  patrolEmpty.classList.add('hidden');
  patrolForm .classList.remove('hidden');
  inputType.value     = 'Solo';
  inputCs.value       = state.callsign || '';
  inputSector.value   = '';
  if (inputRadio) inputRadio.value = '';
  patrolSelectedVeh = null;
  const assignedVehStatus = document.getElementById('assigned-veh-status');
  if (assignedVehStatus) assignedVehStatus.textContent = 'Aucun';
  updateMembersSection('Solo');
  setTimeout(() => inputCs.focus(), 30);
});

// Mise à jour des slots agents quand le type change
inputType.addEventListener('change', () => updateMembersSection(inputType.value));

// Nombre d'agents par type (hors soi-même)
const PATROL_SIZES = { Lincoln: 0, Adam: 1, William: 3, 'Henry-01': 1, Marry: 0, David: 4 };
let selectedPatrolMembers = []; // Tableau contenant les IDs (ou null si emplacement libre)
let patrolSelectedVeh = null;

const btnAssignVeh = document.getElementById('btn-assign-veh');
if (btnAssignVeh) {
  btnAssignVeh.addEventListener('click', async () => {
    const res = await send('getVehicle');
    const statusEl = document.getElementById('assigned-veh-status');
    if (res && res.netId !== undefined && res.netId !== null) {
      patrolSelectedVeh = res.netId;
      if (statusEl) statusEl.textContent = res.name || 'Véhicule assigné';
    } else {
      patrolSelectedVeh = null;
      if (statusEl) statusEl.textContent = 'Aucun (hors véhicule)';
    }
  });
}

const patrolErrorMsg = document.getElementById('patrol-error-msg'); // Déclaré en haut !

function updateMembersSection(type) {
  const wrap = document.getElementById('patrol-members-wrap');
  if (!wrap) return;
  const count = PATROL_SIZES[type] ?? 0;
  
  // On crée un tableau avec X cases vides (null)
  selectedPatrolMembers = new Array(count).fill(null);
  if (patrolErrorMsg) patrolErrorMsg.classList.add('hidden');
  
  if (count === 0) {
    wrap.classList.add('hidden');
    return;
  }
  wrap.classList.remove('hidden');
  renderPatrolSlots();
}

function renderPatrolSlots() {
  const container = document.getElementById('patrol-members');
  const count = PATROL_SIZES[inputType.value] || 0;
  container.innerHTML = '';
  
  for (let i = 0; i < count; i++) {
    const srcStr = selectedPatrolMembers[i];
    const slot = document.createElement('div');
    slot.className = 'ph-agent-slot' + (srcStr ? ' filled' : '');
    
    if (srcStr) {
      // Un agent est déjà assigné à ce slot
      const u = state.units.find(x => String(x.src) === srcStr);
      slot.innerHTML = `
        <span class="slot-num">Agent ${i + 2}</span>
        <span class="slot-val" style="margin-top:2px;"><b style="color:#5ba3f5;">[${escapeHtml(u?.matricule || '000')}]</b> ${escapeHtml(u?.name || '')}</span>
        <button class="slot-remove" title="Retirer">×</button>
      `;
      slot.querySelector('.slot-remove').addEventListener('click', () => {
        selectedPatrolMembers[i] = null; // On vide le slot
        renderPatrolSlots();             // On rafraîchit
      });
    } else {
      // Le slot est libre : On affiche la barre de recherche intégrée
      slot.innerHTML = `
        <span class="slot-num">Agent ${i + 2}</span>
        <div class="slot-search-wrap">
          <input type="text" class="slot-search-input" placeholder="Rechercher nom/mat..." autocomplete="off" />
          <div class="slot-results hidden"></div>
        </div>
        <span></span>
      `;

      const inputEl = slot.querySelector('.slot-search-input');
      const resultsEl = slot.querySelector('.slot-results');

      // Logique de recherche propre à ce slot
      inputEl.addEventListener('input', () => {
        const q = inputEl.value.trim().toLowerCase();
        resultsEl.innerHTML = '';

        if (!q) { resultsEl.classList.add('hidden'); return; }

        const myIdStr = String(state.myId);
        
        // Filtre : En service, Pas moi, Pas déjà sélectionné dans un autre slot, Pas déjà en patrouille
        const available = state.units.filter(u => 
          u.duty !== false && 
          String(u.src) !== myIdStr && 
          !u.patrol &&
          !selectedPatrolMembers.includes(String(u.src)) &&
          ((u.name || '').toLowerCase().includes(q) || (u.matricule || '').toLowerCase().includes(q))
        );

        if (available.length === 0) {
          resultsEl.innerHTML = '<div style="padding:6px;color:#8fa8c8;font-size:10px;font-style:italic;">Aucun agent disponible...</div>';
        } else {
          // On limite à 4 résultats pour ne pas faire un menu déroulant trop long
          available.slice(0, 4).forEach(u => {
            const div = document.createElement('div');
            div.className = 'pa-result';
            div.innerHTML = `<span class="pa-result-mat">[${escapeHtml(u.matricule || '000')}]</span> ${escapeHtml(u.name || 'Inconnu')}`;
            
            div.addEventListener('mousedown', (e) => {
              e.preventDefault(); // Empêche le 'blur' de l'input avant l'exécution du clic
              selectedPatrolMembers[i] = String(u.src);
              renderPatrolSlots();
            });
            resultsEl.appendChild(div);
          });
        }
        resultsEl.classList.remove('hidden');
      });

      // Ferme le menu déroulant si on clique à côté
      inputEl.addEventListener('blur', () => setTimeout(() => resultsEl.classList.add('hidden'), 150));
    }
    container.appendChild(slot);
  }
}

btnCancelPat.addEventListener('click', () => {
  patrolForm .classList.add('hidden');
  patrolEmpty.classList.remove('hidden');
  if (patrolErrorMsg) patrolErrorMsg.classList.add('hidden');
});

btnConfirmPat.addEventListener('click', () => {
  // 1. Vérification du nombre d'agents : y a-t-il des slots encore vides (null) ?
  const missing = selectedPatrolMembers.filter(m => m === null).length;
  if (missing > 0) {
    if (patrolErrorMsg) {
      patrolErrorMsg.textContent = `Il manque ${missing} agent(s) pour former une patrouille ${inputType.value}.`;
      patrolErrorMsg.classList.remove('hidden');
    }
    return; // On bloque l'exécution
  }

  // 2. Vérification de l'indicatif
  const cs = (inputCs.value || '').trim();
  if (!cs) { 
    inputCs.focus(); 
    if (patrolErrorMsg) {
      patrolErrorMsg.textContent = "L'indicatif de la patrouille est obligatoire.";
      patrolErrorMsg.classList.remove('hidden');
    }
    return; 
  }

  if (patrolErrorMsg) patrolErrorMsg.classList.add('hidden');

  // 3. Création de la patrouille
  state.patrol = {
    type:     inputType.value,
    callsign: cs,
    sector:   (inputSector.value || '').trim(),
    radio:    (inputRadio ? inputRadio.value : '').trim(),
    members:  selectedPatrolMembers, // Le tableau est complet, sans aucun null !
    vehNet:   patrolSelectedVeh
  };
  
  state.callsign = cs;
  send('startPatrol', state.patrol);
  renderPatrolState();
  
  const radioLabel = document.getElementById('my-radio-label');
  if (radioLabel) radioLabel.textContent = state.patrol.radio ? `📻 ${state.patrol.radio}` : '';
  
  renderPatrolsList();
  renderAgentsList();
});
btnEndPat.addEventListener('click', () => {
  state.patrol = null;
  state.callsign = '';
  send('endPatrol');
  renderPatrolState();
  const radioLabel = document.getElementById('my-radio-label');
  if (radioLabel) radioLabel.textContent = '';
  renderPatrolsList();
  renderAgentsList();
});

// ===== Canal radio éditable (clic sur le label) =====
(function setupRadioEdit() {
  const radioLabel = document.getElementById('my-radio-label');
  const radioInput = document.getElementById('my-radio-input');
  if (!radioLabel || !radioInput) return;

  function openRadioEdit() {
    radioInput.value = (state.patrol && state.patrol.radio) || '';
    radioLabel.classList.add('hidden');
    radioInput.classList.remove('hidden');
    radioInput.focus(); radioInput.select();
  }
  function commitRadioEdit() {
    const val = radioInput.value.replace(/[^0-9.]/g, '').trim();
    radioInput.classList.add('hidden');
    radioLabel.classList.remove('hidden');
    if (state.patrol) {
      state.patrol.radio = val;
      radioLabel.textContent = val ? `📻 ${val}` : '';
      send('setRadio', { radio: val });
    }
    renderPatrolsList();
  }

  radioLabel.addEventListener('click', openRadioEdit);
  // Filtre : chiffres et points uniquement
  radioInput.addEventListener('keydown', e => {
    if (e.key === 'Enter') { commitRadioEdit(); return; }
    if (e.key === 'Escape') {
      radioInput.classList.add('hidden');
      radioLabel.classList.remove('hidden');
      return;
    }
    // Bloquer tout sauf chiffres, points, backspace, delete, flèches, tab
    if (!e.ctrlKey && !e.metaKey &&
        !/^[0-9.]$/.test(e.key) &&
        !['Backspace','Delete','ArrowLeft','ArrowRight','Tab','Home','End'].includes(e.key)) {
      e.preventDefault();
    }
  });
  radioInput.addEventListener('blur', commitRadioEdit);
})();


editCs?.addEventListener('click', () => {
  myCsInput.value = state.callsign;
  myCsText.classList.add('hidden');
  myCsInput.classList.remove('hidden');
  myCsInput.focus();
  myCsInput.select();
});
confirmCs?.addEventListener('click', () => {
  if (!myCsInput.classList.contains('hidden')) {
    state.callsign = (myCsInput.value || '').trim() || state.callsign;
    myCsText.textContent = state.callsign;
    myCsInput.classList.add('hidden');
    myCsText.classList.remove('hidden');
    send('setCallsign', { callsign: state.callsign });
  }
});
myCsInput?.addEventListener('keyup', e => { if (e.key === 'Enter') confirmCs?.click(); });

pingLoc?.addEventListener('click', () => send('pingLocation'));

// Situation menu (codes)
openSit.addEventListener('click', e => {
  e.stopPropagation();
  sitMenu.innerHTML = '';
  for (const s of state.situations) {
    const b = document.createElement('button');
    b.textContent = `${s.code} — ${s.label}`;
    b.addEventListener('click', () => {
      send('setSituation', { code: s.code });
      sitMenu.classList.add('hidden');
    });
    sitMenu.appendChild(b);
  }
  const r = openSit.getBoundingClientRect();
  sitMenu.style.left = Math.min(r.left, window.innerWidth - 280) + 'px';
  sitMenu.style.top  = (r.bottom + 4) + 'px';
  sitMenu.classList.remove('hidden');
});
mySit.addEventListener('click', e => { e.stopPropagation(); openSit.click(); });

function applySituationVisual() {
  mySit.textContent = state.situation || 'N/A';
  mySit.className = 'sit-pill';
  const c = (state.situation || '').toUpperCase();
  if (!c || c === 'N/A')        mySit.classList.add('na');
  else if (c.includes('CODE 2')) mySit.classList.add('c2');
  else if (c.includes('CODE 3')) mySit.classList.add('c3');
  else                            mySit.classList.add('c4');
}

// ===== Recherche : accordion + formulaires + DB =====

// --- État de recherche ---
const searchState = {
  veh: { loading: false, query: '', abortKey: '' },
  cit: { loading: false, query: '', abortKey: '' },
};

// Accordion toggle
document.querySelectorAll('.acc-head').forEach(h => {
  h.addEventListener('click', () => {
    const cat = h.dataset.cat;
    const body = document.querySelector(`.acc-body[data-body="${cat}"]`);
    body.classList.toggle('open');
    h.querySelector('.plus').textContent = body.classList.contains('open') ? '−' : '+';
  });
});

// --- Boutons d'action des formulaires (Ajouter un avis de recherche local) ---
document.querySelectorAll('[data-act]').forEach(btn => {
  btn.addEventListener('click', () => {
    const act = btn.dataset.act;
    const form = btn.closest('.add-form');
    if (act === 'add-veh') {
      const v = collectForm(form);
      if (v.plate || v.model) {
        send('addWantedVehicle', v);
        clearForm(form);
      }
    } else if (act === 'cancel-veh') {
      clearForm(form);
    } else if (act === 'add-cit') {
      const c = collectForm(form);
      if (c.name) {
        send('addWantedCitizen', c);
        clearForm(form);
      }
    } else if (act === 'cancel-cit') {
      clearForm(form);
    }
  });
});

function collectForm(form) {
  const out = {};
  form.querySelectorAll('.mini-in').forEach(i => { out[i.dataset.k] = (i.value || '').trim(); });
  return out;
}
function clearForm(form) { form.querySelectorAll('.mini-in').forEach(i => i.value = ''); }

// --- Lancer une recherche ---
const dbContainer = document.getElementById('db-search-container');
const dbResList = document.getElementById('db-res-list');

function launchSearch(query) {
  const q = (query || '').trim().toLowerCase();
  if (q.length < 2) {
    dbContainer.classList.add('hidden');
    state.dbVehicles = [];
    state.dbCitizens = [];
    searchState.veh.query = '';
    searchState.cit.query = '';
    searchState.veh.loading = false;
    searchState.cit.loading = false;
    renderDbResults();
    return;
  }

  dbContainer.classList.remove('hidden');

  // Recherche locale instantanée dans les avis de recherche
  state.localVehMatches = Object.values(state.wantedVehicles).filter(v =>
    (v.plate || '').toLowerCase().includes(q) ||
    (v.model || '').toLowerCase().includes(q)
  );
  state.localCitMatches = Object.values(state.wantedCitizens).filter(c =>
    (c.name || '').toLowerCase().includes(q)
  );

  // Recherche async dans la BDD principale (owned_vehicles, users)
  if (searchState.veh.query !== q) {
    searchState.veh.loading = true;
    searchState.veh.query = q;
    state.dbVehicles = [];
    send('searchVehicleDB', { query: q });
  }
  if (searchState.cit.query !== q) {
    searchState.cit.loading = true;
    searchState.cit.query = q;
    state.dbCitizens = [];
    send('searchCitizenDB', { query: q });
  }

  renderDbResults();
}

function cancelDbSearch() {
  searchState.veh.loading = false;
  searchState.veh.query = '';
  searchState.cit.loading = false;
  searchState.cit.query = '';
  searchInp.value = '';
  launchSearch('');
}

// --- Afficher les résultats (avis locaux + BDD) ---
function renderDbResults() {
  dbResList.innerHTML = '';

  const q = (searchInp.value || '').trim().toLowerCase();
  if (q.length < 2) return;

  const localVehs = state.localVehMatches || [];
  const localCits = state.localCitMatches || [];
  const dbVehs    = state.dbVehicles     || [];
  const dbCits    = state.dbCitizens     || [];
  const hasAny    = localVehs.length || localCits.length || dbVehs.length || dbCits.length;
  const loading   = searchState.veh.loading || searchState.cit.loading;

  // ---- Avis de recherche (résultats locaux, immédiats) ----
  if (localVehs.length > 0) {
    dbResList.insertAdjacentHTML('beforeend', `
      <div style="padding:5px 12px 3px;border-bottom:1px solid rgba(255,255,255,0.07);">
        <span style="font-size:10px;color:#e67e22;font-weight:600;letter-spacing:.5px;text-transform:uppercase;">Véhicules (${localVehs.length})</span>
      </div>`);;
    for (const v of localVehs) {
      const el = document.createElement('div');
      el.className = 'entry';
      el.innerHTML = `
        <div class="e-title" style="display:flex;align-items:center;gap:6px;">
          <svg viewBox="0 0 24 24" style="width:13px;height:13px;fill:currentColor;opacity:.6;flex-shrink:0"><path d="M5 11l1.5-4.5A2 2 0 0 1 8.4 5h7.2a2 2 0 0 1 1.9 1.5L19 11h1a1 1 0 0 1 1 1v4h-2v2a1 1 0 0 1-1 1h-1a1 1 0 0 1-1-1v-2H8v2a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-2H3v-4a1 1 0 0 1 1-1h1Zm2 0h10l-1-3H8l-1 3Z"/></svg>
          <b>${escapeHtml((v.plate || '').toUpperCase())}</b>
          <span class="e-sub" style="font-weight:400;margin-left:6px;">${escapeHtml(v.model || '')}</span>
        </div>
        ${v.note ? `<div class="e-desc" style="padding-left:19px;">${escapeHtml(v.note)}</div>` : ''}`;
      dbResList.appendChild(el);
    }
  }

  if (localCits.length > 0) {
    dbResList.insertAdjacentHTML('beforeend', `
      <div style="padding:5px 12px 3px;border-bottom:1px solid rgba(255,255,255,0.07);">
        <span style="font-size:10px;color:#e67e22;font-weight:600;letter-spacing:.5px;text-transform:uppercase;">Citoyens (${localCits.length})</span>
      </div>`);;
    for (const c of localCits) {
      const el = document.createElement('div');
      el.className = 'entry';
      el.innerHTML = `
        <div class="e-title" style="display:flex;align-items:center;gap:6px;">
          <svg viewBox="0 0 24 24" style="width:13px;height:13px;fill:currentColor;opacity:.6;flex-shrink:0"><path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm0 2c-3 0-9 1.5-9 4.5V21h18v-2.5c0-3-6-4.5-9-4.5Z"/></svg>
          <b>${escapeHtml((c.name || '').toUpperCase())}</b>
        </div>
        ${c.reason ? `<div class="e-desc" style="padding-left:19px;">${escapeHtml(c.reason)}</div>` : ''}`;
      dbResList.appendChild(el);
    }
  }

  // ---- BDD principale (owned_vehicles, users) ----
  if (loading) {
    dbResList.insertAdjacentHTML('beforeend', `
      <div class="entry" style="padding:8px 12px;">
        <div class="e-sub" style="display:flex;align-items:center;gap:8px;opacity:.5;">
          <svg viewBox="0 0 24 24" style="width:12px;height:12px;fill:currentColor;animation:spin 1s linear infinite"><path d="M12 4V2A10 10 0 0 0 2 12h2a8 8 0 0 1 8-8Z"/></svg>
          Recherche dans la base de données...
        </div>
      </div>`);
  } else {
    if (dbVehs.length > 0) {
      dbResList.insertAdjacentHTML('beforeend', `
        <div style="padding:5px 12px 3px;border-bottom:1px solid rgba(255,255,255,0.07);">
          <span style="font-size:10px;color:#8fa8c8;font-weight:600;letter-spacing:.5px;text-transform:uppercase;">BDD — Véhicules (${dbVehs.length})</span>
        </div>`);;
      for (const v of dbVehs) {
        const el = document.createElement('div');
        el.className = 'entry';
        el.innerHTML = `
          <div class="e-title" style="display:flex;align-items:center;gap:6px;">
            <svg viewBox="0 0 24 24" style="width:13px;height:13px;fill:currentColor;opacity:.6;flex-shrink:0"><path d="M5 11l1.5-4.5A2 2 0 0 1 8.4 5h7.2a2 2 0 0 1 1.9 1.5L19 11h1a1 1 0 0 1 1 1v4h-2v2a1 1 0 0 1-1 1h-1a1 1 0 0 1-1-1v-2H8v2a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-2H3v-4a1 1 0 0 1 1-1h1Zm2 0h10l-1-3H8l-1 3Z"/></svg>
            <b>${escapeHtml((v.plate || '').toUpperCase())}</b>
            <span class="e-sub" style="font-weight:400;margin-left:6px;">${escapeHtml(v.model || 'Inconnu')}</span>
          </div>`;
        dbResList.appendChild(el);
      }
    }
    if (dbCits.length > 0) {
      dbResList.insertAdjacentHTML('beforeend', `
        <div style="padding:5px 12px 3px;border-bottom:1px solid rgba(255,255,255,0.07);">
          <span style="font-size:10px;color:#8fa8c8;font-weight:600;letter-spacing:.5px;text-transform:uppercase;">BDD — Citoyens (${dbCits.length})</span>
        </div>`);;
      for (const c of dbCits) {
        const el = document.createElement('div');
        el.className = 'entry';
        el.innerHTML = `
          <div class="e-title" style="display:flex;align-items:center;gap:6px;">
            <svg viewBox="0 0 24 24" style="width:13px;height:13px;fill:currentColor;opacity:.6;flex-shrink:0"><path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm0 2c-3 0-9 1.5-9 4.5V21h18v-2.5c0-3-6-4.5-9-4.5Z"/></svg>
            <b>${escapeHtml((c.name || '').toUpperCase())}</b>
            ${c.dob ? `<span class="e-sub" style="font-weight:400;margin-left:6px;">né(e) le ${escapeHtml(c.dob)}</span>` : ''}
          </div>
          ${c.identifier ? `<div class="e-desc" style="padding-left:19px;">ID : ${escapeHtml(c.identifier)}</div>` : ''}`;
        dbResList.appendChild(el);
      }
    }
    if (!hasAny && !loading) {
      dbResList.innerHTML = '<div class="entry"><div class="e-sub" style="opacity:.5;text-align:center;">Aucun résultat</div></div>';
    }
  }
}



// --- Afficher les listes locales (Avis de recherche) ---
function renderWantedLists() {
  vehListEl.innerHTML = '';
  citListEl.innerHTML = '';
  const vehs = Object.values(state.wantedVehicles);
  if (vehs.length === 0) {
    vehListEl.innerHTML = '<div style="padding:10px; color:#aaa; font-style:italic;">(Aucun véhicule recherché)</div>';
  } else {
    for (const v of vehs) {
      const el = document.createElement('div');
      el.className = 'entry';
      el.innerHTML = `
        <div class="e-title" style="display:flex; justify-content:space-between; align-items:center;">
          <span style="display:flex;align-items:center;gap:6px;">
            <svg viewBox="0 0 24 24" style="width:14px;height:14px;fill:currentColor;opacity:.7"><path d="M5 11l1.5-4.5A2 2 0 0 1 8.4 5h7.2a2 2 0 0 1 1.9 1.5L19 11h1a1 1 0 0 1 1 1v4h-2v2a1 1 0 0 1-1 1h-1a1 1 0 0 1-1-1v-2H8v2a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-2H3v-4a1 1 0 0 1 1-1h1Zm2 0h10l-1-3H8l-1 3Z"/></svg>
            ${escapeHtml((v.plate || '').toUpperCase())}
          </span>
          <button class="mini confirm remove-wanted" data-type="veh" data-id="${v.id}" title="Marquer comme retrouvé">
            <svg viewBox="0 0 24 24"><path d="M9 16.2 4.8 12l-1.4 1.4L9 19l12-12-1.4-1.4Z"/></svg>
          </button>
        </div>
        <div class="e-sub">Modèle: ${escapeHtml(v.model || '')}</div>
        <div class="e-desc">${escapeHtml(v.note || '')}</div>`;
      vehListEl.appendChild(el);
    }
  }

  const cits = Object.values(state.wantedCitizens);
  if (cits.length === 0) {
    citListEl.innerHTML = '<div style="padding:10px; color:#aaa; font-style:italic;">(Aucun citoyen recherché)</div>';
  } else {
    for (const c of cits) {
      const el = document.createElement('div');
      el.className = 'entry';
      el.innerHTML = `
        <div class="e-title" style="display:flex; justify-content:space-between; align-items:center;">
          <span style="display:flex;align-items:center;gap:6px;">
            <svg viewBox="0 0 24 24" style="width:14px;height:14px;fill:currentColor;opacity:.7"><path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm0 2c-3 0-9 1.5-9 4.5V21h18v-2.5c0-3-6-4.5-9-4.5Z"/></svg>
            ${escapeHtml((c.name || '').toUpperCase())}
          </span>
          <button class="mini confirm remove-wanted" data-type="cit" data-id="${c.id}" title="Marquer comme retrouvé">
            <svg viewBox="0 0 24 24"><path d="M9 16.2 4.8 12l-1.4 1.4L9 19l12-12-1.4-1.4Z"/></svg>
          </button>
        </div>
        <div class="e-sub">Raison: ${escapeHtml(c.reason || '')}</div>
        <div class="e-desc">${escapeHtml(c.desc || '')}</div>`;
      citListEl.appendChild(el);
    }
  }
}

// Event listener global pour les boutons corbeille
document.addEventListener('click', e => {
  const btn = e.target.closest('.remove-wanted');
  if (!btn) return;
  const type = btn.dataset.type;
  const id = btn.dataset.id;
  if (type === 'veh') send('removeWantedVehicle', { id });
  else if (type === 'cit') send('removeWantedCitizen', { id });
});

// --- Barre de recherche globale (filtre local avec debounce) ---
let searchDebounce = null;
searchInp.addEventListener('input', () => {
  clearTimeout(searchDebounce);
  searchDebounce = setTimeout(() => {
    launchSearch(searchInp.value);
  }, 150);
});

// Petite fonction pour générer l'erreur au-dessus de l'appel
function showInlineCallError(callEl) {
  // Supprime une ancienne erreur si l'utilisateur spamme le clic
  const oldErr = callEl.previousElementSibling;
  if (oldErr && oldErr.classList.contains('call-inline-error')) oldErr.remove();

  // Crée le message d'erreur
  const err = document.createElement('div');
  err.className = 'call-inline-error';
  err.style = 'color: #e74c3c; font-size: 10px; text-align: center; background: rgba(231,76,60,0.1); padding: 4px; border-radius: 2px; margin-bottom: 2px; font-weight: 600;';
  err.textContent = "Vous devez être en patrouille pour accepter un appel.";
  
  // L'insère juste au-dessus de la ligne de l'appel
  callEl.parentNode.insertBefore(err, callEl);
  
  // Disparaît automatiquement après 3 secondes
  setTimeout(() => { if (err.parentNode) err.remove(); }, 3000);
}

function renderCalls() {
  notifList.innerHTML = '';
  const sorted = [...state.calls].sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
  
  if (sorted.length === 0) {
    notifList.innerHTML = '<div style="color: #c4c4c4; text-align: center; font-size: 11px; padding: 12px;">Aucune notification</div>';
    return;
  }

  const myIdStr = String(state.myId);

  for (const c of sorted) {
    const el = document.createElement('div');
    
    const isAssignedToAll = c.allAssigned;
    const isAcceptedByMe = c.accepted && c.accepted[myIdStr];
    const isAcceptedByOther = c.accepted && Object.keys(c.accepted).length > 0 && !isAcceptedByMe;

    let callClass = `call lvl-${c.level || 1}`;
    if (isAssignedToAll) callClass += ' accepted-all';
    else if (isAcceptedByMe) callClass += ' accepted-me';
    el.className = callClass;
    el.dataset.id = c.id;
    
    let titlePrefix = '';

    let iconHTML = '';
    if (isAssignedToAll || isAcceptedByMe) {
      // ➔ Remplacé : C'est maintenant une CROIX pour supprimer
      iconHTML = `<div class="ico action-remove" title="Supprimer la notification"><svg viewBox="0 0 24 24"><path d="M19 6.4 17.6 5 12 10.6 6.4 5 5 6.4 10.6 12 5 17.6 6.4 19 12 13.4 17.6 19 19 17.6 13.4 12Z" fill="#fff"/></svg></div>`;
    } else if (isAcceptedByOther) {
      // ➔ Reste identique : Bouclier indiquant qu'une autre unité est dessus
      iconHTML = `<div class="ico" title="Pris par une autre unité"><svg viewBox="0 0 24 24"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z" fill="#fff"/></svg></div>`;
    } else {
      // ➔ Reste identique : Bouton Check interactif pour accepter
      iconHTML = `<div class="ico action-accept" title="Cliquez pour accepter l'appel"><svg viewBox="0 0 24 24"><path d="M9 16.2 4.8 12l-1.4 1.4L9 19l12-12-1.4-1.4Z" fill="#fff"/></svg></div>`;
    }

    let requesterText = c.patrol ? (c.patrol.callsign || c.patrol) : (c.requesterName || '');

    let acceptedHTML = '';
    if (c.accepted && typeof c.accepted === 'object') {
      const accepters = Object.values(c.accepted).filter(v => typeof v === 'string');
      if (accepters.length > 0) {
        acceptedHTML = `<div style="display:flex; flex-wrap:wrap;">`;
        for (const name of accepters) {
          acceptedHTML += `
            <div class="accepted-pill" title="Patrouille ayant accepté l'appel">
              ${escapeHtml(name)}
            </div>
          `;
        }
        acceptedHTML += `</div>`;
      }
    }

    el.innerHTML = `
      ${iconHTML}
      <div class="meta">
        <div class="title">${titlePrefix}Backup n°${c.alertNum || '?'}</div>
        <div class="sub">Demandé par ${escapeHtml(requesterText)}</div>
        ${acceptedHTML}
      </div>
      <div class="ago" style="text-align: right;">
        ${c.dept ? `<div style="font-size:10px; opacity:0.8; margin-bottom:2px;">${escapeHtml(c.dept)}</div>` : ''}
        <div>${timeAgo(c.createdAt)}</div>
      </div>`;
      
    el.addEventListener('click', ev => {
      // [SÉCURITÉ] On bloque toute interaction (menu, boutons) si l'agent est hors service
      if (!state.duty) return;

      // 1. Si on a cliqué sur la CROIX (Supprimer)
      if (ev.target.closest('.action-remove')) {
        ev.stopPropagation();
        send('removeCall', { id: c.id });
        return;
      }

      // 2. Si on a cliqué sur le CHECK (Accepter)
      if (ev.target.closest('.action-accept')) {
        ev.stopPropagation(); 
        
        if (!state.patrol) {
          showInlineCallError(el); // Affichage de l'erreur au-dessus de l'appel
          return;
        }
        
        send('acceptCall', { id: c.id });
        return;
      }
      
      // 3. Si on a cliqué ailleurs (Menu contextuel)
      openCtx(ev, c.id);
    });
    
    notifList.appendChild(el);
  }
}

// ===== Menu contextuel (Mise à jour) =====
ctxMenu.querySelectorAll('button').forEach(b => {
  b.addEventListener('click', () => {
    const act = b.dataset.act;
    const id  = state.ctxCallId;
    ctxMenu.classList.add('hidden');
    
    if (act === 'assign-all')  send('assignAll',  { id });
    if (act === 'accept') {
      if (!state.patrol) {
        // Recherche l'élément HTML de l'appel pour afficher l'erreur au-dessus
        const callEl = document.querySelector(`.call[data-id="${id}"]`);
        if (callEl) showInlineCallError(callEl);
        else showToast("Vous devez être en patrouille pour accepter un appel.");
        return;
      }
      send('acceptCall', { id });
    }
    if (act === 'remove')      send('removeCall', { id });
    if (act === 'clear-all')   send('clearAll');
  });
});

function renderUnits() {
  const n = state.units.length;
  if (unitCountEl) unitCountEl.textContent = String(n).padStart(2, '0');
  const xxSpan = document.querySelector('#btn-units-icon span');
  if (xxSpan) xxSpan.textContent = String(n).padStart(2, '0');
  renderPatrolsList();
  renderAgentsList();
  updatePatrolMetaText();
}

function renderAgentsList() {
  const list    = document.getElementById('agents-list');
  const countEl = document.getElementById('agents-count');
  if (!list) return;
  list.innerHTML = '';

  // Inclure moi-même dans la liste (avec mes données locales)
  const me = {
    src: state.myId,
    id: state.myId,
    name: state.myName,
    matricule: state.matricule || '000',
    grade: state.myGrade || '',
    duty: state.duty,
    patrol: state.patrol,
    isMine: true,
  };
  // Exclure mon propre entrée du broadcast serveur pour éviter le doublon
  const myIdStr = String(state.myId);
  const myIdent = String(state.myIdentifier || 'none');
  const others = state.units.filter(u => 
    String(u.src) !== myIdStr && 
    String(u.id) !== myIdStr &&
    String(u.src) !== myIdent &&
    String(u.id) !== myIdent
  );
  const all = [me, ...others];
  if (countEl) countEl.textContent = all.length;

  const onDuty  = all.filter(u => u.duty !== false);
  const offDuty = all.filter(u => u.duty === false);

  function makeRow(u) {
    const isOn = u.duty !== false;
    const patrolName = u.patrol ? u.patrol.callsign : null;
    const row = document.createElement('div');
    row.className = 'agent-row';
    row.dataset.src = String(u.src || u.id || '');
    
    // Vérification du grade local pour l'affichage (côté NUI)
    const allowedGrades = ['Capitaine', 'Commandant', 'Commissaire'];
    const canManage = state.duty && allowedGrades.includes(state.myGrade);

    row.innerHTML = `
      <div class="agent-dot ${isOn ? 'on' : 'off'}"></div>
      <div class="agent-body">
        <div class="agent-name">${escapeHtml(u.name || '—')}</div>
        <div class="agent-sub">
          ${u.matricule ? `<span class="mat">[${escapeHtml(u.matricule)}]</span>` : ''}
          ${u.grade     ? `<span class="grade">${escapeHtml(u.grade)}</span>` : ''}
          ${patrolName  ? `<span class="patrol-tag">${escapeHtml(patrolName)}</span>` : ''}
        </div>
      </div>
      ${canManage ? `
      <button class="agent-edit-btn" title="Modifier grade / matricule">
        <svg viewBox="0 0 24 24"><path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25ZM20.71 7.04a1 1 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83Z"/></svg>
      </button>` : ''}`;
    return row;
  }

  if (onDuty.length > 0) {
    const sep = document.createElement('div');
    sep.className = 'agent-group-sep';
    sep.textContent = `En service — ${onDuty.length}`;
    list.appendChild(sep);
    onDuty.forEach(u => list.appendChild(makeRow(u)));
  }

  if (offDuty.length > 0) {
    const sep = document.createElement('div');
    sep.className = 'agent-group-sep';
    sep.textContent = `Hors service — ${offDuty.length}`;
    list.appendChild(sep);
    offDuty.forEach(u => list.appendChild(makeRow(u)));
  }

  if (all.length === 0) {
    list.innerHTML = '<div class="agent-group-sep" style="text-align:center;opacity:.4;">Aucun agent connecté</div>';
  }
}


// ===== Édition agent (grade / matricule) =====
let _agentEditSrc = null;

(function setupAgentEdit() {
  const agentsList = document.getElementById('agents-list');
  const FALLBACK_GRADES = ['Stagiaire','Agent','Brigadier','Inspecteur','Sergent','Lieutenant','Capitaine','Commandant','Commissaire'];

  agentsList.addEventListener('click', e => {
    const btn = e.target.closest('.agent-edit-btn');
    if (!btn) return;
    e.stopPropagation();
    const row = btn.closest('.agent-row');
    if (!row) return;
    const srcStr = row.dataset.src;

    const existing = agentsList.querySelector('.agent-edit-panel');
    if (existing) {
      existing.remove();
      if (_agentEditSrc === srcStr) { _agentEditSrc = null; return; }
    }
    _agentEditSrc = srcStr;

    const myIdStr = String(state.myId);
    let u;
    if (srcStr === myIdStr) {
      u = { src: srcStr, grade: state.myGrade, matricule: state.matricule, isMine: true };
    } else {
      u = state.units.find(x => String(x.src) === srcStr);
    }
    if (!u) return;

    const grades = state.grades.length ? state.grades : FALLBACK_GRADES;
    const opts = grades.map(g =>
      `<option value="${escapeHtml(g)}"${g === u.grade ? ' selected' : ''}>${escapeHtml(g)}</option>`
    ).join('');

    const panel = document.createElement('div');
    panel.className = 'agent-edit-panel';
    panel.innerHTML = `
      <div class="aep-row">
        <span class="aep-lbl">Grade</span>
        <select class="aep-grade">${opts}</select>
      </div>
      <div class="aep-row">
        <span class="aep-lbl">Matricule</span>
        <input class="aep-mat" value="${escapeHtml(u.matricule || '')}" maxlength="8" placeholder="ex: 748" />
      </div>
      <div class="aep-actions">
        <button class="mini confirm aep-save" title="Enregistrer">
          <svg viewBox="0 0 24 24"><path d="M9 16.2 4.8 12l-1.4 1.4L9 19l12-12-1.4-1.4Z"/></svg>
        </button>
        <button class="mini cancel aep-cancel" title="Annuler">
          <svg viewBox="0 0 24 24"><path d="M19 6.4 17.6 5 12 10.6 6.4 5 5 6.4 10.6 12 5 17.6 6.4 19 12 13.4 17.6 19 19 17.6 13.4 12Z"/></svg>
        </button>
      </div>`;

    row.after(panel);

    panel.querySelector('.aep-save').addEventListener('click', () => {
      const grade = panel.querySelector('.aep-grade').value;
      const mat   = (panel.querySelector('.aep-mat').value || '').trim();
      if (srcStr === myIdStr) {
        state.myGrade = grade;
        if (mat) { state.matricule = mat; applyMatricule(); }
      }
      send('editAgent', { targetSrc: srcStr, grade, matricule: mat });
      panel.remove();
      _agentEditSrc = null;
      renderAgentsList();
    });

    panel.querySelector('.aep-cancel').addEventListener('click', () => {
      panel.remove();
      _agentEditSrc = null;
    });
  });
})();

function renderPatrolsList() {
  const list = document.getElementById('patrols-list');
  const countEl = document.getElementById('patrol-count');
  if (!list) return;
  list.innerHTML = '';

  const groups = {};

  // Traiter mes unités et collègues par patrouille
  for (const u of [
    ...(state.patrol ? [{ src: state.myId, name: state.myName, patrol: state.patrol, situation: state.situation }] : []),
    ...state.units.filter(x => x.patrol)
  ]) {
    // FIX : Regroupement strict par l'indicatif (Callsign) pour éviter les doublons ID vs Callsign
    const pid = (u.patrol.callsign || '').trim().toUpperCase();

    if (!groups[pid]) {
      groups[pid] = { patrol: u.patrol, situation: u.situation, members: [] };
    }
    if (!groups[pid].members.includes(u.name)) {
      groups[pid].members.push(u.name);
    }
  }

  const patrolList = Object.values(groups);
  if (countEl) countEl.textContent = patrolList.length;

  if (patrolList.length === 0) {
    list.innerHTML = '<div class="entry"><div class="e-sub" style="opacity:.5;text-align:center;">Aucune patrouille active</div></div>';
    return;
  }

  for (const g of patrolList) {
    const p = g.patrol;
    const sit = g.situation;
    const names = g.members.join(' · ');

    const el = document.createElement('div');
    el.className = 'entry';
    el.innerHTML = `
      <div class="e-title" style="display:flex;align-items:center;justify-content:space-between;">
        <span style="display:flex;align-items:center;gap:8px;">
          <span class="sit-pill ${getSitClass(sit)}" style="font-size:10px;padding:2px 6px;">${escapeHtml(sit || 'N/A')}</span>
          <b>${escapeHtml(p.callsign || '—')}</b>
          <span class="e-sub" style="font-size:10px;">${escapeHtml(p.type || '')}</span>
        </span>
        ${p.radio ? `<span style="font-size:10px;color:#8fa8c8;">📻 ${escapeHtml(p.radio)}</span>` : ''}
      </div>
      <div class="e-desc" style="display:flex;gap:12px;opacity:.8;margin-top:4px;">
        ${names ? `<span>${escapeHtml(names)}</span>` : ''}
        ${p.sector ? `<span style="opacity:.6;">· ${escapeHtml(p.sector)}</span>` : ''}
      </div>`;
    list.appendChild(el);
  }
}

function getSitClass(sit) {
  const c = (sit || '').toUpperCase();
  if (!c || c === 'N/A') return 'na';
  if (c.includes('CODE 2')) return 'c2';
  if (c.includes('CODE 3')) return 'c3';
  return 'c4';
}


function openCtx(ev, callId) {
  ev.stopPropagation();
  state.ctxCallId = callId;
  ctxMenu.classList.remove('hidden');
  const x = Math.min(ev.clientX, window.innerWidth  - 270);
  const y = Math.min(ev.clientY, window.innerHeight - 200);
  ctxMenu.style.left = x + 'px';
  ctxMenu.style.top  = y + 'px';
}
document.addEventListener('click', () => {
  ctxMenu.classList.add('hidden');
  sitMenu.classList.add('hidden');
});
ctxMenu.addEventListener('click', e => e.stopPropagation());
sitMenu.addEventListener('click', e => e.stopPropagation());


// ===== Helpers =====
function escapeHtml(s) {
  return String(s || '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  })[c]);
}
function timeAgo(ts) {
  if (!ts) return '';
  const s = Math.max(0, Math.floor(Date.now() / 1000) - ts);
  if (s < 60)   return 'à l\'instant';
  if (s < 3600) return `il y a ${Math.floor(s / 60)} min`;
  return `il y a ${Math.floor(s / 3600)} h`;
}

// Déclaration des nouveaux éléments (à mettre en haut de ton script.js)
const toastRightEl   = document.getElementById('toast');
const toastRightText = document.getElementById('toast-text');
const inMenuToastEl  = document.getElementById('in-menu-toast');

let toastT;
function showToast(msg) {
  clearTimeout(toastT);

  // On vérifie si la tablette est ouverte
  const isMenuOpen = !app.classList.contains('hidden');

  if (isMenuOpen) {
    // 1. Tablette ouverte : On affiche dans la bannière interne
    inMenuToastEl.innerHTML = `
      <svg viewBox="0 0 24 24" style="width:14px;height:14px;fill:#c4c4c4;"><path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2Zm1 15h-2v-2h2Zm0-4h-2V7h2Z"/></svg>
      ${escapeHtml(msg)}
    `;
    inMenuToastEl.classList.remove('hidden');
    toastRightEl.classList.remove('show'); // On cache l'externe au cas où

    toastT = setTimeout(() => {
      inMenuToastEl.classList.add('hidden');
    }, 4000);
  } else {
    // 2. Tablette fermée : On affiche le toast externe à droite
    inMenuToastEl.classList.add('hidden');
    toastRightText.textContent = msg;
    toastRightEl.classList.add('show');

    toastT = setTimeout(() => {
      toastRightEl.classList.remove('show');
    }, 4000);
  }
}

// ===== Header retro80 =====
let _retroClockTimer = null;

function setupRetroHeader() {
  if (document.getElementById('retro-clock')) return;
  const ab = document.querySelector('.actionbar');
  if (!ab) return;

  // 1. Sous-ligne dans dept-block
  ab.querySelector('.dept-block')?.insertAdjacentHTML('beforeend',
    `<div class="retro-dept-sub">
      <span class="r-cs" id="r-cs">----</span>
      <span class="r-sit" id="r-sit">10-8</span>
      <span class="r-units" id="r-units">0 UNIT.</span>
    </div>`);

  // 2. Titre système dans header-center
  ab.querySelector('.header-center')?.insertAdjacentHTML('afterbegin',
    `<div class="retro-sys-title">* * *  L.A.P.D.  DISPATCH TERMINAL  * * *</div>`);

  // 3. Horloge insérée juste AVANT .bk-group (aucun déplacement)
  const bk = ab.querySelector('.bk-group');
  if (bk) {
    bk.insertAdjacentHTML('beforebegin',
      `<div id="retro-clock">
        <span class="retro-clock-date"></span>
        <span class="retro-clock-time"></span>
      </div>`);
    function tick() {
      const n = new Date(), p = v => String(v).padStart(2,'0');
      const cd = ab.querySelector('.retro-clock-date');
      const ct = ab.querySelector('.retro-clock-time');
      if (cd) cd.textContent = `${p(n.getDate())}/${p(n.getMonth()+1)}/${n.getFullYear()}`;
      if (ct) ct.textContent = `${p(n.getHours())}:${p(n.getMinutes())}:${p(n.getSeconds())}`;
    }
    clearInterval(_retroClockTimer);
    tick();
    _retroClockTimer = setInterval(tick, 1000);
  }

  // 4. Labels sur les boutons renfort
  [['btn-backup-1','NVL1'],['btn-backup-2','NVL2'],['btn-backup-3','URGC']].forEach(([id,lbl]) => {
    const b = document.getElementById(id);
    if (b && !b.querySelector('.bk-lbl'))
      b.insertAdjacentHTML('beforeend', `<span class="bk-lbl">${lbl}</span>`);
  });

  // 5. Ouvrir tous les accordéons
  document.querySelectorAll('.acc-body').forEach(body => {
    body.classList.add('open');
    const h = document.querySelector(`.acc-head[data-cat="${body.dataset.body}"]`);
    if (h) { const p = h.querySelector('.plus'); if (p) p.textContent = '−'; }
  });
}

function updateRetroHeader() {
  const cs = document.getElementById('r-cs');
  const sit = document.getElementById('r-sit');
  const units = document.getElementById('r-units');
  if (cs)    cs.textContent    = state.callsign  || '----';
  if (sit)   sit.textContent   = state.situation || '10-8';
  if (units) units.textContent = (state.units.filter(u => u.duty !== false).length + (state.duty ? 1 : 0)) + ' UNIT.';
}

// ===== Bridge =====
window.addEventListener('message', (ev) => {
  const d = ev.data || {};
  switch (d.action) {
    case 'open':
      app.classList.remove('hidden');

      // Application du thème AVANT toute autre action
      app.classList.toggle('retro80', d.theme === 'retro80');
      
      // Données de démonstration pour le thème retro80 (s'effacent au 1er sync)
      if (d.theme === 'retro80') {
        const now = Math.floor(Date.now() / 1000);
        state.units = [
          { src:'10', name:'MARTIN Jean',   grade:'Sergent',    matricule:'102', callsign:'ALPHA-1',   situation:'10-8',   duty:true, patrol:{type:'Solo', callsign:'ALPHA-1',   sector:'Centre-Ville',  radio:'2.1'} },
          { src:'11', name:'DUPONT Marie',  grade:'Agent',      matricule:'215', callsign:'BRAVO-2',   situation:'10-6',   duty:true, patrol:null },
          { src:'12', name:'LEROY Pierre',  grade:'Lieutenant', matricule:'089', callsign:'CHARLIE-3', situation:'CODE 3', duty:true, patrol:{type:'Duo',  callsign:'CHARLIE-3', sector:'Quartier Nord', radio:'3.5'} },
          { src:'13', name:'GARCIA Sofia',  grade:'Capitaine',  matricule:'047', callsign:'DELTA-4',   situation:'10-23',  duty:true, patrol:{type:'GAV',  callsign:'DELTA-GAV', sector:'Boulevard Est'} },
          { src:'14', name:'BERNARD Paul',  grade:'Brigadier',  matricule:'318', callsign:'ECHO-5',    situation:'10-8',   duty:true, patrol:null },
          { src:'15', name:'ROUX Isabelle', grade:'Inspecteur', matricule:'451', callsign:'FOXT-6',    situation:'10-80',  duty:true, patrol:{type:'K9',   callsign:'FOXT-K9',   sector:'Autoroute S.',  radio:'4.0'} },
          { src:'16', name:'PETIT Marc',    grade:'Stagiaire',  matricule:'620', callsign:'GOLF-7',    situation:'10-8',   duty:false, patrol:null },
        ];
        state.calls = [
          { id:1, level:3, label:'CODE 3 — POURSUITE ARMÉE AXE NORD',        callsign:'CHARLIE-3', requesterName:'LEROY Pierre',  createdAt: now - 95 },
          { id:2, level:2, label:'RENFORT — ACCIDENT CORPOREL RUE PRINCIPALE', callsign:'ALPHA-1',   requesterName:'MARTIN Jean',   createdAt: now - 420 },
          { id:3, level:1, label:'ASSISTANCE — PERSONNE SUSPECTE BLVD EST',   callsign:'DELTA-4',   requesterName:'GARCIA Sofia',  createdAt: now - 1200 },
          { id:4, level:2, label:'RENFORT — RIXE DEVANT LE MOTEL SUNSET',      callsign:'BRAVO-2',   requesterName:'DUPONT Marie',  createdAt: now - 2700 },
        ];
        state.wantedVehicles = [
          { id:1, plate:'ABC-123', model:'Ford Maverick',    note:'Beige — suspect armé' },
          { id:2, plate:'XYZ-789', model:'Dodge Charger',    note:'Vol à main armée' },
          { id:3, plate:'DEF-456', model:'Pontiac Firebird', note:'Plaques volées' },
        ];
        state.wantedCitizens = [
          { id:1, name:'JONES Thomas', reason:'Mandat darrestation', desc:'Homme brun, 1m80, veste noire' },
          { id:2, name:'WALSH Kevin',  reason:'Vol aggravé',         desc:'Tatoué cou — dangereux' },
        ];
        renderUnits(); renderCalls(); renderWantedLists();
        setupRetroHeader(); updateRetroHeader();
      }

      // Mise à jour de l'état général
      state.duty       = !!d.duty;
      state.muted      = !!d.muted;
      state.situations = d.situations || [];
      
      if (d.deptName && deptNameEl) {
        state.deptName = d.deptName;
        deptNameEl.textContent = d.deptName;
      }
      if (d.grades && d.grades.length) state.grades = d.grades;
      
      // Informations sur mon personnage
      if (d.me) {
        state.callsign  = d.me.callsign  || state.callsign;
        state.situation = d.me.situation || state.situation;
        state.matricule = d.me.matricule || state.matricule;
        state.myId      = String(d.me.id || state.myId);
        state.myName    = d.me.name || state.myName;
        state.myGrade   = d.me.grade     || state.myGrade;
        state.patrol    = d.me.patrol || null;
        
        myCsText.textContent = state.callsign;
        if (myId) myId.textContent  = state.myId;
        if (myName) myName.textContent = state.myName;
        
        applyMatricule();
        applySituationVisual();
        renderPatrolState();
      }
      
      muteBtn.classList.toggle('muted', state.muted);
      applyDutyVisual();
      
      // On force l'actualisation de la liste des agents
      renderAgentsList(); 
      break;
    case 'close':
      app.classList.add('hidden');
      ctxMenu.classList.add('hidden');
      sitMenu.classList.add('hidden');
      break;
    case 'duty':
      state.duty = !!d.duty; applyDutyVisual(); renderAgentsList();
      break;
    case 'myProfile':
      if (d.matricule) { state.matricule = d.matricule; applyMatricule(); }
      if (d.grade)     { state.myGrade   = d.grade; }
      if (d.identifier){ state.myIdentifier = d.identifier; }
      
      // AJOUT : Mise à jour de ma patrouille si je suis assigné par un collègue
      if (d.patrol !== undefined) {
        state.patrol = d.patrol;
        if (d.patrol) state.callsign = d.patrol.callsign;
        renderPatrolState();
      }
      
      renderAgentsList();
      break;
    case 'vehicleResults':
      if (searchState.veh.loading) {
        searchState.veh.loading = false;
        state.dbVehicles = d.results || [];
        renderDbResults();
      }
      break;
    case 'citizenResults':
      if (searchState.cit.loading) {
        searchState.cit.loading = false;
        state.dbCitizens = d.results || [];
        renderDbResults();
      }
      break;
    case 'syncWanted':
      state.wantedVehicles = d.vehicles || [];
      state.wantedCitizens = d.citizens || [];
      renderWantedLists();
      break;
    case 'syncSituation':
      state.situation = d.code;
      applySituationVisual();
      break;
    case 'syncRadio':
      if (state.patrol) {
        state.patrol.radio = d.radio;
        const radioLabel = document.getElementById('my-radio-label');
        if (radioLabel) radioLabel.textContent = d.radio ? `📻 ${d.radio}` : '';
      }
      renderPatrolsList();
      break;
    case 'units':
      state.units = d.units || []; renderUnits();
      if (app.classList.contains('retro80')) updateRetroHeader();
      break;
    case 'calls':
      state.calls = d.calls || []; renderCalls();
      break;
    case 'sync':
      state.units = d.units || []; state.calls = d.calls || [];
      renderUnits(); renderCalls();
      break;
    case 'newBackup':
      if (app.classList.contains('hidden')) {
        showFloatingNotification(d.call);
      }
      break;
    case 'notifyAcceptance':
      if (app.classList.contains('hidden')) {
        showMapNotification(d.call, d.accepterName);
      }
      break;
    case 'toast':
      showToast(d.text || '');
      break;
  }
});

document.addEventListener('focusin', e => {
  if (['INPUT', 'TEXTAREA'].includes(e.target.tagName)) {
    send('keepInput', { keep: false });
  }
});

document.addEventListener('focusout', e => {
  if (['INPUT', 'TEXTAREA'].includes(e.target.tagName)) {
    send('keepInput', { keep: true });
  }
});

function showFloatingNotification(c) {
  const container = document.getElementById('floating-notifications');
  if (!container) return;

  const el = document.createElement('div');
  const isAssignedToAll = c.allAssigned;
  const myIdStr = String(state.myId);
  const isAcceptedByMe = c.accepted && c.accepted[myIdStr];
  const isAcceptedByOther = c.accepted && Object.keys(c.accepted).length > 0 && !isAcceptedByMe;

  let callClass = `call lvl-${c.level || 1}`;
  if (isAssignedToAll) callClass += ' accepted-all';
  else if (isAcceptedByMe) callClass += ' accepted-me';
  el.className = callClass;

  let titlePrefix = '';
  
  let iconHTML = '';
  if (isAssignedToAll || isAcceptedByMe) {
    iconHTML = `<div class="ico"><svg viewBox="0 0 24 24"><path d="M19 6.4 17.6 5 12 10.6 6.4 5 5 6.4 10.6 12 5 17.6 6.4 19 12 13.4 17.6 19 19 17.6 13.4 12Z" fill="#fff"/></svg></div>`;
  } else if (isAcceptedByOther) {
    iconHTML = `<div class="ico"><svg viewBox="0 0 24 24"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z" fill="#fff"/></svg></div>`;
  } else {
    iconHTML = `<div class="ico"><svg viewBox="0 0 24 24"><path d="M9 16.2 4.8 12l-1.4 1.4L9 19l12-12-1.4-1.4Z" fill="#fff"/></svg></div>`;
  }

  let requesterText = c.patrol ? (c.patrol.callsign || c.patrol) : (c.requesterName || '');

  let acceptedHTML = '';
  if (c.accepted && typeof c.accepted === 'object') {
    const accepters = Object.values(c.accepted).filter(v => typeof v === 'string');
    if (accepters.length > 0) {
      acceptedHTML = `<div style="display:flex; flex-wrap:wrap; margin-top:4px;">`;
      for (const name of accepters) {
        acceptedHTML += `
          <div class="accepted-pill" title="Patrouille ayant accepté l'appel">
            ${escapeHtml(name)}
          </div>
        `;
      }
      acceptedHTML += `</div>`;
    }
  }

  el.innerHTML = `
    ${iconHTML}
    <div class="meta">
      <div class="title">${titlePrefix}Backup n°${c.alertNum || '?'}</div>
      <div class="sub">Demandé par ${escapeHtml(requesterText)}</div>
      ${acceptedHTML}
    </div>
    <div class="ago" style="text-align: right;">
      ${c.dept ? `<div style="font-size:10px; opacity:0.8; margin-bottom:2px;">${escapeHtml(c.dept)}</div>` : ''}
      à l'instant
    </div>
  `;

  container.appendChild(el);

  setTimeout(() => {
    el.classList.add('fade-out');
    setTimeout(() => el.remove(), 400);
  }, 5000);
}

function showMapNotification(c, accepterName) {
  const container = document.getElementById('floating-notifications');
  if (!container) return;

  const el = document.createElement('div');
  let callClass = `call lvl-${c.level || 1} accepted-me`;
  el.className = callClass;

  let titlePrefix = '';
  let iconHTML = `<div class="ico"><svg viewBox="0 0 24 24"><path d="M19 6.4 17.6 5 12 10.6 6.4 5 5 6.4 10.6 12 5 17.6 6.4 19 12 13.4 17.6 19 19 17.6 13.4 12Z" fill="#fff"/></svg></div>`;
  
  let requesterText = c.patrol ? (c.patrol.callsign || c.patrol) : (c.requesterName || '');

  let acceptedHTML = `
    <div style="display:flex; flex-wrap:wrap;">
      <div class="accepted-pill" title="Patrouille ayant accepté l'appel">
        ${escapeHtml(accepterName || 'Une unité')}
      </div>
    </div>
  `;

  el.innerHTML = `
    ${iconHTML}
    <div class="meta">
      <div class="title">${titlePrefix}Backup n°${c.alertNum || '?'} accepté</div>
      <div class="sub">Émis par ${escapeHtml(requesterText)}</div>
      ${acceptedHTML}
    </div>
    <div class="ago" style="text-align: right;">
      ${c.dept ? `<div style="font-size:10px; opacity:0.8; margin-bottom:2px;">${escapeHtml(c.dept)}</div>` : ''}
      à l'instant
    </div>
  `;

  container.appendChild(el);

  setTimeout(() => {
    el.classList.add('fade-out');
    setTimeout(() => el.remove(), 400);
  }, 8000);
}
