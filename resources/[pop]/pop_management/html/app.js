// Variables globales
function GetParentResourceName() {
  return 'pop_management';
}

let currentCategory = 'sports'; // Catégorie par défaut (PDM)
let currentMaxPrice = 1000000; // Filtre prix par défaut
let currentSocietyData = null; // Données société (SecuroServ)
let pollingInterval = null;
let currentDashboard = 'securoserv'; // Par défaut SecuroServ
let localPlayerJob = null;

// Récupérer le job au chargement
fetch(`https://${GetParentResourceName()}/getPlayerJob`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({})
}).then(resp => resp.json()).then(data => {
  localPlayerJob = data.job;
  // Mise à jour de l'UI si nécessaire
  const gradeEl = document.getElementById('player-grade');
  if (gradeEl && localPlayerJob) gradeEl.innerText = localPlayerJob.toUpperCase();
}).catch(err => {
  console.error('Failed to get job:', err);
  localPlayerJob = 'unknown'; // Fail safe
});

// =========================================================================
// Bridge clavier natif <-> DUI inputs
// FiveM DUI ne reçoit pas d'events clavier (pas de SendDuiKeyDown natif).
// On intercepte le focus sur tout <input>/<textarea> texte, on ouvre le clavier
// natif GTA, et on réinjecte la valeur dans le champ qui l'a demandée.
// Opt-out : data-no-native-keyboard="true" sur l'élément.
// Titre custom : data-kbd-title="..." sur l'élément.
// =========================================================================
(function setupNativeKeyboardBridge() {
  const pendingRequests = new Map();
  let nextRequestSeq = 1;
  let lastTriggerTs = 0;

  function isEditableTextInput(el) {
    if (!el) return false;
    if (el.disabled || el.readOnly) return false;
    if (el.dataset && el.dataset.noNativeKeyboard === 'true') return false;
    if (el.tagName === 'TEXTAREA') return true;
    if (el.tagName !== 'INPUT') return false;
    const type = (el.getAttribute('type') || 'text').toLowerCase();
    return ['text', 'search', 'email', 'url', 'tel', 'number', 'password'].includes(type);
  }

  function ensureFieldId(el) {
    if (!el.id) el.id = `kbd-auto-${nextRequestSeq}`;
    return el.id;
  }

  function nativeValueSetter(el) {
    const proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    const desc = Object.getOwnPropertyDescriptor(proto, 'value');
    return desc && desc.set ? desc.set.bind(el) : (v) => { el.value = v; };
  }

  function openNativeKeyboardFor(el) {
    const now = Date.now();
    if (now - lastTriggerTs < 200) return; // debounce: focus events can fire rapidly
    lastTriggerTs = now;

    const fieldId = ensureFieldId(el);
    const requestId = `req-${nextRequestSeq++}-${now}`;
    pendingRequests.set(requestId, { fieldId });

    const title = (el.dataset && el.dataset.kbdTitle)
      || el.getAttribute('placeholder')
      || el.getAttribute('aria-label')
      || el.getAttribute('name')
      || 'Saisie';
    let maxLength = parseInt(el.getAttribute('maxlength'), 10);
    if (!Number.isFinite(maxLength) || maxLength <= 0) maxLength = 60;

    el.blur(); // release DOM focus, the native modal owns input now

    fetch(`https://${GetParentResourceName()}/openKeyboard`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        requestId,
        fieldId,
        title,
        defaultValue: el.value || '',
        maxLength,
      }),
    }).catch(() => {
      pendingRequests.delete(requestId);
    });
  }

  // Capture-phase: run before any framework handler. focusin bubbles, focus doesn't.
  document.addEventListener('focusin', (event) => {
    const target = event.target;
    if (!isEditableTextInput(target)) return;
    // Defer so we don't race with click/focus events still in flight.
    setTimeout(() => {
      if (document.activeElement === target) openNativeKeyboardFor(target);
    }, 0);
  }, true);

  // Touch (mouse click) also covers the case where focus was already on the element.
  document.addEventListener('mousedown', (event) => {
    const target = event.target;
    if (!isEditableTextInput(target)) return;
    if (document.activeElement === target) {
      openNativeKeyboardFor(target);
    }
  }, true);

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || data.action !== 'keyboardResult') return;
    if (!data.requestId && !data.fieldId) return; // legacy D8 event, handled elsewhere

    const pending = data.requestId ? pendingRequests.get(data.requestId) : null;
    if (data.requestId) pendingRequests.delete(data.requestId);

    if (data.cancelled) return;

    const fieldId = data.fieldId || (pending && pending.fieldId);
    if (!fieldId) return;
    const el = document.getElementById(fieldId);
    if (!el) return;

    const setter = nativeValueSetter(el);
    setter(data.value != null ? String(data.value) : '');
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  });
})();

// Stub: l'inputModal historique appelait toggleInputFocus() (jamais défini → throw).
// Le bridge clavier au-dessus gère le focus via le clavier natif, donc ce stub
// se contente d'éviter l'erreur.
function toggleInputFocus(_on) { /* no-op: native keyboard handles input now */ }

// Gestion du curseur virtuel DUI
const virtualCursor = document.getElementById('virtual-cursor');

document.addEventListener('mousemove', (e) => {
  if (virtualCursor) {
    virtualCursor.style.left = e.clientX + 'px';
    virtualCursor.style.top = e.clientY + 'px';
  }
});

// Mise à jour de l'heure dans la barre des tâches
function updateTime() {
  const now = new Date();
  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  const timeEl = document.getElementById('taskbar-time');
  if (timeEl) timeEl.textContent = `${hours}:${minutes}`;
}
updateTime();
setInterval(updateTime, 1000);

// Auto-type du mot de passe
function autoTypePassword() {
  const passInput = document.getElementById('pass-input');
  const btn = document.getElementById('enter-btn');
  const fullPass = "password123";
  let i = 0;

  if (btn) btn.disabled = true;

  const interval = setInterval(() => {
    if (passInput) passInput.value += fullPass[i];
    i++;
    if (i >= fullPass.length) {
      clearInterval(interval);
      setTimeout(transitionToDashboard, 400);
    }
  }, 80);
}

// Transition vers le dashboard
function transitionToDashboard() {
  const login = document.getElementById('login-screen');

  if (login) login.style.opacity = "0";

  setTimeout(() => {
    if (login) login.style.display = "none";

    // Afficher SecuroServ après login
    showDashboard('securoserv');
  }, 500);
}

// ─── Window manager ─────────────────────────────────────────────────────────
// Several apps can be open at once. Each window can be minimized / fullscreened
// independently. The taskbar reflects open / active / minimized state.

const APP_DASH_ID = {
  securoserv: 'dashboard-securoserv',
  pdm:        'dashboard-pdm',
  d8:         'dashboard-d8',
  gouv:       'dashboard-gouv',
  youtool:    'dashboard-youtool',
  ytjob:      'dashboard-ytjob'
};

const windowStates = {
  securoserv: { open: false, minimized: false, maximized: false, initialized: false },
  pdm:        { open: false, minimized: false, maximized: false, initialized: false },
  d8:         { open: false, minimized: false, maximized: false, initialized: false },
  gouv:       { open: false, minimized: false, maximized: false, initialized: false },
  youtool:    { open: false, minimized: false, maximized: false, initialized: false },
  ytjob:      { open: false, minimized: false, maximized: false, initialized: false }
};

let topZ = 100;
let focusedApp = null;

function getDash(appName) {
  return document.getElementById(APP_DASH_ID[appName]);
}

function focusWindow(appName) {
  const dash = getDash(appName);
  if (!dash || !windowStates[appName].open || windowStates[appName].minimized) return;
  topZ++;
  dash.style.zIndex = topZ;
  focusedApp = appName;
  currentDashboard = appName;
  updateTaskbar();
}

function updateTaskbar() {
  let anyFullscreen = false;
  document.querySelectorAll('.taskbar-icon').forEach(icon => {
    const app = icon.dataset.app;
    if (!app || !windowStates[app]) return;
    const s = windowStates[app];
    icon.classList.toggle('app-open',      s.open);
    icon.classList.toggle('app-minimized', s.minimized);
    icon.classList.toggle('app-active',    s.open && !s.minimized && focusedApp === app);

    if (s.open && !s.minimized && s.maximized) {
      anyFullscreen = true;
    }
  });

  const tb = document.querySelector('.taskbar');
  if (tb) {
    tb.classList.toggle('hide-fullscreen', anyFullscreen);
  }
}

function ensureAppInit(appName) {
  const s = windowStates[appName];
  if (s.initialized) return;
  s.initialized = true;
  if (appName === 'securoserv') {
    if (!pollingInterval) startPolling();
  } else if (appName === 'pdm') {
    initShop();
  } else if (appName === 'd8') {
    initD8();
  } else if (appName === 'gouv') {
    if (!pollingInterval) startGouvPolling();
  } else if (appName === 'youtool') {
    initYouTool();
  } else if (appName === 'ytjob') {
    initYTJob();
  }
}

function showDashboard(appName) {
  const dash = getDash(appName);
  if (!dash) return;
  dash.classList.remove('minimized');
  dash.classList.add('visible');
  windowStates[appName].open      = true;
  windowStates[appName].minimized = false;
  focusWindow(appName);
  ensureAppInit(appName);
}

function closeWindow(appName) {
  const dash = getDash(appName);
  if (!dash) return;
  dash.classList.remove('visible', 'minimized', 'fullscreen');
  const s = windowStates[appName];
  s.open = s.minimized = s.maximized = s.initialized = false;

  if (appName === 'securoserv') {
    stopPolling();
    // Reset login so next open requires password again
    const login    = document.getElementById('login-screen');
    const passInp  = document.getElementById('pass-input');
    const btn      = document.getElementById('enter-btn');
    if (passInp) passInp.value = '';
    if (btn)     btn.disabled  = false;
    if (login)   login.style.display = 'none';
  } else if (appName === 'gouv') {
    stopGouvPolling();
  } else if (appName === 'ytjob') {
    if (ytJobPolling) { clearInterval(ytJobPolling); ytJobPolling = null; }
  }

  if (focusedApp === appName) focusedApp = null;
  // Auto-focus another open window if any
  for (const name of Object.keys(windowStates)) {
    if (windowStates[name].open && !windowStates[name].minimized) {
      focusWindow(name);
      break;
    }
  }
  updateTaskbar();
}

function minimizeWindow(appName) {
  const dash = getDash(appName);
  if (!dash || !windowStates[appName].open) return;
  dash.classList.add('minimized');
  windowStates[appName].minimized = true;
  if (focusedApp === appName) focusedApp = null;
  updateTaskbar();
}

function restoreWindow(appName) {
  const dash = getDash(appName);
  if (!dash) return;
  dash.classList.remove('minimized');
  windowStates[appName].minimized = false;
  focusWindow(appName);
}

function toggleMaximize(appName) {
  const dash = getDash(appName);
  if (!dash) return;
  const max = !dash.classList.contains('fullscreen');
  dash.classList.toggle('fullscreen', max);
  windowStates[appName].maximized = max;
  if (max) focusWindow(appName);
  updateTaskbar();
}

// Click on a dashboard → bring to front
document.addEventListener('mousedown', (e) => {
  const dash = e.target.closest('[data-app]');
  if (!dash) return;
  // Ignore clicks on taskbar icons (they have their own handler)
  if (dash.classList.contains('taskbar-icon')) return;
  const app = dash.dataset.app;
  if (app && windowStates[app] && windowStates[app].open && !windowStates[app].minimized) {
    focusWindow(app);
  }
});

// ─── Window dragging ────────────────────────────────────────────────────────
// Click and hold on a .window-header (anywhere except traffic lights / address bar)
// then move the cursor to drag the window around. Disabled in fullscreen.

let dragState = null;

function setExplicitPosition(dash) {
  // Convert the centered (top:50% left:50% translate(-50%,-50%) scale(0.85)) layout
  // into explicit pixel top/left, preserving on-screen position.
  if (dash.classList.contains('dragged')) return;
  const rect = dash.getBoundingClientRect();
  dash.style.top  = rect.top  + 'px';
  dash.style.left = rect.left + 'px';
  dash.classList.add('dragged');
}

document.addEventListener('mousedown', (e) => {
  const header = e.target.closest('.window-header');
  if (!header) return;
  // Skip if click is on traffic light or address bar
  if (e.target.closest('.traffic-light')) return;
  if (e.target.closest('.browser-address-bar')) return;

  const dash = header.closest('[data-app]');
  if (!dash) return;
  if (dash.classList.contains('fullscreen')) return;

  setExplicitPosition(dash);
  const rect = dash.getBoundingClientRect();
  dragState = {
    dash:    dash,
    header:  header,
    offsetX: e.clientX - rect.left,
    offsetY: e.clientY - rect.top
  };
  header.classList.add('dragging');
  dash.style.transition = 'none';
  // Bring this window to front when we start moving it
  const app = dash.dataset.app;
  if (app) focusWindow(app);
});

document.addEventListener('mousemove', (e) => {
  if (!dragState) return;
  const dash    = dragState.dash;
  const headerH = 50;
  let nx = e.clientX - dragState.offsetX;
  let ny = e.clientY - dragState.offsetY;
  // Keep at least part of the header on screen (clamp to viewport)
  const w = dash.offsetWidth  * 0.85; // account for scale
  const h = dash.offsetHeight * 0.85;
  const minX = -w + 80;
  const maxX = window.innerWidth  - 80;
  const minY = 0;
  const maxY = window.innerHeight - headerH - 10;
  if (nx < minX) nx = minX;
  if (nx > maxX) nx = maxX;
  if (ny < minY) ny = minY;
  if (ny > maxY) ny = maxY;
  dash.style.left = nx + 'px';
  dash.style.top  = ny + 'px';
});

document.addEventListener('mouseup', () => {
  if (!dragState) return;
  dragState.header.classList.remove('dragging');
  dragState.dash.style.transition = '';
  dragState = null;
});

// Double-click on the header toggles maximize (classic OS behavior)
document.addEventListener('dblclick', (e) => {
  const header = e.target.closest('.window-header');
  if (!header) return;
  if (e.target.closest('.traffic-light')) return;
  if (e.target.closest('.browser-address-bar')) return;
  const dash = header.closest('[data-app]');
  if (!dash) return;
  const app = dash.dataset.app;
  if (app) toggleMaximize(app);
});

// const DEV_MODE = true; (géré dynamiquement ou temporairement en dur pour tester)
const DEV_MODE = true;

// Taskbar click: open, restore (if minimized), focus (if visible), or minimize (if already focused)
function openApp(appName) {
  if (!DEV_MODE) {
    if (appName === 'pdm' && localPlayerJob !== 'cardealer') return;
    if (appName === 'd8'  && localPlayerJob !== 'dynasty8')  return;
    if (appName === 'gouv' && localPlayerJob !== 'gouv') return;
    if (appName === 'ytjob' && localPlayerJob !== 'youtool') return;
  }

  const s = windowStates[appName];

  // Already open
  if (s.open) {
    if (s.minimized) { restoreWindow(appName); return; }
    // Visible: toggle minimize if it's already the focused app, else just focus
    if (focusedApp === appName) { minimizeWindow(appName); return; }
    focusWindow(appName);
    return;
  }

  // Not open yet — SecuroServ needs login flow
  if (appName === 'securoserv') {
    const login   = document.getElementById('login-screen');
    if (login) {
      const passInput = document.getElementById('pass-input');
      const btn       = document.getElementById('enter-btn');
      if (passInput) passInput.value = '';
      if (btn)       btn.disabled    = false;
      login.style.display = 'flex';
      setTimeout(() => { login.style.opacity = '1'; }, 10);
    }
    return;
  }

  // PDM / D8 open immediately
  showDashboard(appName);
}

// Gestion des clics sur les icônes de la taskbar
// Click listeners on taskbar icons are handled via onclick attributes in HTML calling openApp()


// --- LOGIQUE SECUROSERV ---

function startPolling() {
  requestSocietyData();
  // Eviter de créer plusieurs intervalles
  if (pollingInterval) clearInterval(pollingInterval);
  pollingInterval = setInterval(() => {
    if (currentDashboard === 'securoserv') {
      requestSocietyData();
    }
  }, 2000);
}

function stopPolling() {
  if (pollingInterval) {
    clearInterval(pollingInterval);
    pollingInterval = null;
  }
}

function requestSocietyData() {
  fetch(`https://${GetParentResourceName()}/requestSocietyData`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({})
  }).then(response => response.json())
    .then(data => {
      if (data && data.action === 'updateSocietyData') {
        // Si on reçoit le fallback "Chargement..." MAIS qu'on a déjà des données
        // réelles, on garde les vraies données (évite que le UI repasse en loading
        // à chaque cooldown serveur ou réponse en retard).
        const isLoadingShape = data.societyData && data.societyData.societyLabel === 'Chargement...';
        if (isLoadingShape && currentSocietyData && currentSocietyData.societyLabel && currentSocietyData.societyLabel !== 'Chargement...') {
          return;
        }
        currentSocietyData = data.societyData;
        updateSocietyDashboardUI();
      }
    }).catch(err => {
      // console.error('Erreur requête:', err);
    });
}

function updateSocietyDashboardUI() {
  if (!currentSocietyData) return;

  // Mettre à jour l'argent
  const moneyEl = document.getElementById('society-money');
  if (moneyEl) moneyEl.textContent = formatMoney(currentSocietyData.money);

  const moneyEl2 = document.getElementById('society-money-2');
  if (moneyEl2) moneyEl2.textContent = formatMoney(currentSocietyData.money);

  const orderLabelEl = document.getElementById('society-order-label');
  if (orderLabelEl && currentSocietyData.societyLabel) orderLabelEl.textContent = currentSocietyData.societyLabel;

  // Mettre à jour le nombre d'employés
  const empCountEl = document.getElementById('employee-count');
  if (empCountEl) empCountEl.textContent = currentSocietyData.employees ? currentSocietyData.employees.length : 0;

  // Mettre à jour le nom de l'entreprise
  const nameEl = document.getElementById('society-name');
  if (nameEl && currentSocietyData.societyLabel) nameEl.textContent = currentSocietyData.societyLabel;

  // Mettre à jour le grade du joueur (l'ID dans index.html est 'player-grade', pas 'player-grade-securoserv')
  const gradeEl = document.getElementById('player-grade') || document.getElementById('player-grade-securoserv');
  if (gradeEl) gradeEl.textContent = currentSocietyData.playerGradeLabel || '';

  // Mettre à jour la liste des employés
  updateEmployeeList();

  // Mettre à jour l'historique des transactions
  updateTransactionHistory();

  // Gérer l'affichage de l'onglet VÉHICULES selon la config
  const navVehicles = document.getElementById('nav-vehicles');
  if (navVehicles) {
    if (currentSocietyData.useTabInventoryKeys === true) {
      navVehicles.style.display = 'flex';
    } else {
      navVehicles.style.display = 'none';
      // Si l'utilisateur est actuellement sur l'onglet véhicules qui vient d'être caché
      if (navVehicles.classList.contains('active')) {
        switchTab('overview');
      }
    }
  }

  // Mettre à jour la liste des véhicules société
  updateSocietyVehicleList();

  // Mettre à jour la liste complète des transactions
  updateFullTransactionHistory();

  // Mettre à jour la liste des commandes
  renderOrders();
}

function updateEmployeeList() {
  const tbody = document.getElementById('employee-list');
  if (!tbody) return;
  tbody.innerHTML = '';

  if (!currentSocietyData.employees || currentSocietyData.employees.length === 0) {
    tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;">Aucun employé</td></tr>';
    return;
  }

  currentSocietyData.employees.forEach(employee => {
    const row = document.createElement('tr');
    const matricule = employee.matricule != null ? employee.matricule : '-';
    const codeCasier = employee.code_casier || '-';
    row.innerHTML = `
            <td>${employee.firstname} ${employee.lastname}</td>
            <td>Grade ${employee.job_grade} - ${employee.gradeLabel || ''}</td>
            <td>
                N°${matricule} - Code ${codeCasier}
                <button class="action-btn" onclick="setEmployeeLocker('${employee.identifier}', ${employee.matricule != null ? employee.matricule : 'null'}, '${employee.code_casier || ''}')">Modifier</button>
            </td>
            <td>
                <button class="action-btn" onclick="paySalary('${employee.identifier}')">Prime</button>
                <button class="action-btn promote-btn" onclick="promoteEmployee('${employee.identifier}', ${employee.job_grade})">Promouvoir</button>
                <button class="action-btn demote-btn" onclick="demoteEmployee('${employee.identifier}', ${employee.job_grade})">Rétrograder</button>
                <button class="action-btn promote-btn" onclick="generateEmployeeContract('${employee.identifier}')">Contrat</button>
                <button class="action-btn fire-btn" onclick="fireEmployee('${employee.identifier}')">Licencier</button>
            </td>
        `;
    tbody.appendChild(row);
  });
}

// Casier (pop_inventory) : matricule = numéro de casier de l'employé pour ce job,
// code_casier = code à 4 chiffres demandé pour ouvrir le casier d'un collègue.
function setEmployeeLocker(identifier, currentMatricule, currentCode) {
  showInputModal('Numéro de casier (matricule)', currentMatricule != null ? currentMatricule : '', (matricule) => {
    showInputModal('Code du casier (4 chiffres)', currentCode || '', (code) => {
      fetch(`https://${GetParentResourceName()}/setEmployeeLocker`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier, matricule: parseInt(matricule), code: String(code) })
      });
    }, 'text');
  });
}

// Génère un contrat de travail pour un employé via mt_printers.
// On retrouve l'employé dans currentSocietyData (déjà chargé) plutôt que
// de tout passer en onclick — évite les soucis d'escaping HTML.
function generateEmployeeContract(identifier) {
  console.log('[contract] click, identifier=', identifier);
  if (!currentSocietyData || !currentSocietyData.employees) {
    console.warn('[contract] no currentSocietyData.employees');
    return;
  }
  const employee = currentSocietyData.employees.find(e => e.identifier === identifier);
  if (!employee) {
    console.warn('[contract] employee not found for id', identifier);
    return;
  }
  console.log('[contract] sending fetch for', employee.firstname, employee.lastname);

  fetch(`https://${GetParentResourceName()}/generateEmployeeContract`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      identifier: employee.identifier,
      firstname:  employee.firstname,
      lastname:   employee.lastname,
      job_grade:  employee.job_grade,
      gradeLabel: employee.gradeLabel || '',
      societyLabel: currentSocietyData.societyLabel || '',
      // `os` est sandboxé côté client Lua FiveM → on prépare la date ici
      // (Date natif du navigateur) au format DD/MM/YYYY.
      date: (function () {
        const d = new Date();
        const pad = n => String(n).padStart(2, '0');
        return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()}`;
      })()
    })
  })
  .then(r => r.text())
  .then(t => console.log('[contract] fetch ok, response:', t))
  .catch(err => console.error('[contract] fetch failed:', err));
}


function updateTransactionHistory() {
  const tbody = document.getElementById('transaction-list');
  if (!tbody) return;
  tbody.innerHTML = '';

  if (!currentSocietyData.transactions || currentSocietyData.transactions.length === 0) {
    tbody.innerHTML = '<tr><td colspan="3" style="text-align:center;">Aucune transaction</td></tr>';
    return;
  }

  // Afficher les 5 dernières
  currentSocietyData.transactions.slice(0, 5).forEach(transaction => {
    const row = document.createElement('tr');
    const amountClass = transaction.amount > 0 ? 'positive' : 'negative';
    row.innerHTML = `
            <td>${transaction.player_name || 'Système'}</td>
            <td>${transaction.action}</td>
            <td class="${amountClass}">${transaction.amount > 0 ? '+' : ''}${formatMoney(transaction.amount)}</td>
        `;
    tbody.appendChild(row);
  });
}

function updateSocietyVehicleList() {
  const tbody = document.getElementById('vehicle-list');
  if (!tbody) return;
  tbody.innerHTML = '';

  if (!currentSocietyData.vehicles || currentSocietyData.vehicles.length === 0) {
    tbody.innerHTML = '<tr><td colspan="4" style="text-align:center; color: var(--text-dim);">Aucun véhicule assigné à cette société pour le moment.</td></tr>';
    return;
  }

  currentSocietyData.vehicles.forEach(vehicle => {
    // Récupérer le label si possible
    let label = vehicle.model;
    if (typeof carConfig !== 'undefined' && carConfig.cars) {
      const carInfo = carConfig.cars.find(c => c.model.toLowerCase() === (vehicle.model || '').toLowerCase());
      if (carInfo) label = carInfo.label;
    }

    const row = document.createElement('tr');
    row.innerHTML = `
            <td>${label || 'Inconnu'}</td>
            <td>${vehicle.plate || '...'}</td>
            <td>${vehicle.driver || 'Garage'}</td>
            <td><span style="color:#2ecc71">Disponible</span></td>
        `;
    tbody.appendChild(row);
  });
}


function updateFullTransactionHistory() {
  const tbodyFull = document.getElementById('transaction-list-full');
  if (!tbodyFull) return;
  tbodyFull.innerHTML = '';

  if (!currentSocietyData.transactions || currentSocietyData.transactions.length === 0) {
    tbodyFull.innerHTML = '<tr><td colspan="3" style="text-align:center;">Aucune transaction</td></tr>';
  } else {
    // Afficher les transactions les plus récentes en premier
    const transactions = [...currentSocietyData.transactions].reverse();

    transactions.forEach(transaction => {
      const row = document.createElement('tr');
      const amountClass = transaction.amount > 0 ? 'positive' : 'negative';
      row.innerHTML = `
          <td>${transaction.player_name || 'Système'}</td>
          <td>${transaction.action}</td>
          <td class="${amountClass}" style="text-align: right;">${transaction.amount > 0 ? '+' : ''}${formatMoney(transaction.amount)}</td>
        `;
      tbodyFull.appendChild(row);
    });
  }
}

// --- ACTIONS LOGIQUE SECUROSERV ---

function showInputModal(title, defaultValue, onConfirm, inputType) {
  const modal = document.getElementById('inputModal');
  const titleEl = document.getElementById('inputModalTitle');
  const inputEl = document.getElementById('inputModalInput');
  const confirmBtn = document.getElementById('inputModalConfirm');
  const cancelBtn = document.getElementById('inputModalCancel');

  // Nettoyage des anciens listeners pour éviter les doublons
  const newConfirmBtn = confirmBtn.cloneNode(true);
  const newCancelBtn = cancelBtn.cloneNode(true);
  const newInputEl = inputEl.cloneNode(true);

  confirmBtn.parentNode.replaceChild(newConfirmBtn, confirmBtn);
  cancelBtn.parentNode.replaceChild(newCancelBtn, cancelBtn);
  inputEl.parentNode.replaceChild(newInputEl, inputEl);

  titleEl.textContent = title;
  newInputEl.type = inputType === 'text' ? 'text' : 'number';
  newInputEl.value = defaultValue;
  modal.classList.add('active');
  newInputEl.focus();
  newInputEl.select();
  toggleInputFocus(true);

  const handleConfirm = () => {
    if (inputType === 'text') {
      const value = newInputEl.value.trim();
      if (value !== '') {
        onConfirm(value);
      }
      cleanup();
      return;
    }
    const value = parseInt(newInputEl.value);
    if (!isNaN(value) && value >= 0) {
      onConfirm(value);
    }
    cleanup();
  };

  const handleCancel = () => {
    cleanup();
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter') {
      handleConfirm();
    } else if (e.key === 'Escape') {
      handleCancel();
    }
  };

  const cleanup = () => {
    modal.classList.remove('active');
    newConfirmBtn.removeEventListener('click', handleConfirm);
    newCancelBtn.removeEventListener('click', handleCancel);
    newInputEl.removeEventListener('keydown', handleKeyDown);
    toggleInputFocus(false);
  };

  newConfirmBtn.addEventListener('click', handleConfirm);
  newCancelBtn.addEventListener('click', handleCancel);
  newInputEl.addEventListener('keydown', handleKeyDown);
}

// Remplace window.confirm() : un dialogue natif se fige et bloque toute interaction
// dans ce panneau (rendu via DUI/pop_duiengine, pas un vrai navigateur avec fenêtres).
function showConfirmModal(title, message, onConfirm) {
  const modal = document.getElementById('confirmModal');
  const titleEl = document.getElementById('confirmModalTitle');
  const messageEl = document.getElementById('confirmModalMessage');
  const confirmBtn = document.getElementById('confirmModalConfirm');
  const cancelBtn = document.getElementById('confirmModalCancel');

  const newConfirmBtn = confirmBtn.cloneNode(true);
  const newCancelBtn = cancelBtn.cloneNode(true);
  confirmBtn.parentNode.replaceChild(newConfirmBtn, confirmBtn);
  cancelBtn.parentNode.replaceChild(newCancelBtn, cancelBtn);

  titleEl.textContent = title;
  messageEl.textContent = message;
  modal.classList.add('active');

  const cleanup = () => {
    modal.classList.remove('active');
    newConfirmBtn.removeEventListener('click', handleConfirm);
    newCancelBtn.removeEventListener('click', handleCancel);
  };

  function handleConfirm() {
    cleanup();
    onConfirm();
  }

  function handleCancel() {
    cleanup();
  }

  newConfirmBtn.addEventListener('click', handleConfirm);
  newCancelBtn.addEventListener('click', handleCancel);
}

function showDepositModal() {
  showInputModal('Montant à déposer', 1000, (amount) => {
    fetch(`https://${GetParentResourceName()}/depositMoney`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ amount: parseInt(amount) })
    });
  });
}

function showWithdrawModal() {
  showInputModal('Montant à retirer', 1000, (amount) => {
    fetch(`https://${GetParentResourceName()}/withdrawMoney`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ amount: parseInt(amount) })
    });
  });
}

function orderCompanyCheckbook() {
  showConfirmModal("Commander un chéquier", "Commander un chéquier d'entreprise pour 1500$ ?", () => {
    fetch(`https://${GetParentResourceName()}/orderCompanyCheckbook`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });
  });
}

function paySalary(identifier) {
  showInputModal('Montant de la prime', 500, (amount) => {
    fetch(`https://${GetParentResourceName()}/paySalary`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: identifier,
        amount: parseInt(amount)
      })
    });
  });
}

function promoteEmployee(identifier, currentGrade) {
  fetch(`https://${GetParentResourceName()}/setGrade`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      identifier: identifier,
      grade: currentGrade + 1
    })
  });
}

function demoteEmployee(identifier, currentGrade) {
  if (currentGrade > 0) {
    fetch(`https://${GetParentResourceName()}/setGrade`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        identifier: identifier,
        grade: currentGrade - 1
      })
    });
  }
}

function fireEmployee(identifier) {
  fetch(`https://${GetParentResourceName()}/fireEmployee`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      identifier: identifier
    })
  });
}
function switchTab(tabName) {
  // Cacher tous les contenus
  document.querySelectorAll('.tab-content').forEach(tab => {
    tab.style.display = 'none';
  });

  // Retirer la classe active de tous les items NAV du dashboard SecuroServ
  document.querySelector('#dashboard-securoserv .sidebar').querySelectorAll('.nav-item').forEach(item => {
    item.classList.remove('active');
  });

  // Afficher le contenu sélectionné
  const targetTab = document.getElementById(tabName + '-tab');
  if (targetTab) targetTab.style.display = 'block';

  // Ajouter la classe active à l'item cliqué
  if (typeof event !== 'undefined' && event && event.target) {
    const navItem = event.target.closest('.nav-item');
    if (navItem) navItem.classList.add('active');
  }
}


// --- LOGIQUE PDM ---

function initShop() {
  console.log('Initialisation du shop...');
  renderCategories();
  renderCars(currentCategory);
}

function renderCategories() {
  const container = document.getElementById('category-list');
  if (!container) return;

  container.innerHTML = '';

  if (typeof carConfig === 'undefined') {
    container.innerHTML = '<div style="color:#0145D8; padding:20px;">Config manquante</div>';
    return;
  }

  carConfig.categories.forEach(cat => {
    const item = document.createElement('div');
    item.className = `nav-item ${cat.id === currentCategory ? 'active' : ''}`;
    item.textContent = cat.label;
    item.onclick = () => {
      currentCategory = cat.id;
      renderCategories(); // Re-render pour mettre à jour la classe active
      renderCars(cat.id);
    };
    container.appendChild(item);
  });
}

function updatePriceFilter(value) {
  currentMaxPrice = parseInt(value);
  const valEl = document.getElementById('price-filter-value');
  if (valEl) valEl.textContent = formatMoney(currentMaxPrice);
  renderCars(currentCategory);
}

function renderCars(categoryId) {
  const container = document.getElementById('vehicle-grid');
  const title = document.getElementById('page-title');
  if (!container) return;

  if (title && carConfig && carConfig.categories) {
    const cat = carConfig.categories.find(c => c.id === categoryId);
    if (cat) title.textContent = `CATALOGUE - ${cat.label.toUpperCase()}`;
  }

  container.innerHTML = '';

  const cars = carConfig.cars.filter(c => c.category === categoryId && c.price <= currentMaxPrice);

  if (cars.length === 0) {
    container.innerHTML = '<div style="grid-column: 1/-1; text-align:center; color:#888; margin-top:50px;">Aucun véhicule dans cette catégorie</div>';
    return;
  }

  cars.forEach(car => {
    const card = document.createElement('div');
    card.className = 'stat-card';
    card.style.padding = '0';
    card.style.overflow = 'hidden';
    card.style.display = 'flex';
    card.style.flexDirection = 'column';

    // ID unique pour le selecteur de couleur
    const uniqueId = `color-${car.model}`;

    card.innerHTML = `
            <div style="height: 140px; background: #222; overflow:hidden; position:relative;">
                <img src="${car.image}" style="width:100%; height:100%; object-fit:cover; transition: transform 0.3s;" onmouseover="this.style.transform='scale(1.1)'" onmouseout="this.style.transform='scale(1)'" onerror="this.src='pdm.png'">
                <div style="position:absolute; top:10px; right:10px; background:rgba(0,0,0,0.7); padding:4px 8px; border-radius:4px; font-size:12px; font-weight:bold; color:white;">
                    ${formatMoney(car.price)}
                </div>
            </div>
            <div style="padding: 15px; flex:1; display:flex; flex-direction:column;">
                <div style="color: white; font-weight:600; font-size:16px; margin-bottom:5px;">${car.label}</div>
                <div style="color: var(--text-dim); font-size:12px; margin-bottom:10px;">Modèle: ${car.model}</div>
                
                <div style="margin-bottom:15px;">
                    <label style="color:var(--text-dim); font-size:10px; font-weight:600; letter-spacing:1px; display:block; margin-bottom:6px;">COULEUR</label>
                    <select id="${uniqueId}" style="width:100%; background:rgba(255,255,255,0.05); border:1px solid rgba(255,255,255,0.1); color:white; padding:8px; border-radius:6px; outline:none; font-family:'Inter'; font-size:12px; cursor:pointer;">
                        <option value="black" style="color:black; background-color: #000;">Noir</option>
                        <option value="matteblack" style="color:white; background-color: #1c1c1c;">Noir Mat</option>
                        <option value="white" style="color:black; background-color: #fff;">Blanc</option>
                        <option value="grey" style="color:black; background-color: #888;">Gris</option>
                        <option value="silver" style="color:black; background-color: #C0C0C0;">Argent</option>
                        <option value="red" style="color:black; background-color: #c0392b;">Rouge</option>
                        <option value="blue" style="color:black; background-color: #2980b9;">Bleu</option>
                        <option value="green" style="color:black; background-color: #27ae60;">Vert</option>
                        <option value="yellow" style="color:black; background-color: #f1c40f;">Jaune</option>
                        <option value="orange" style="color:black; background-color: #e67e22;">Orange</option>
                        <option value="pink" style="color:black; background-color: #fd79a8;">Rose</option>
                        <option value="purple" style="color:black; background-color: #8e44ad;">Violet</option>
                        <option value="brown" style="color:white; background-color: #795548;">Marron</option>
                    </select>
                </div>

                <button class="action-btn" style="width:100%; margin-top:auto;" onclick="buyCar('${car.model}', ${car.price}, '${uniqueId}')">COMMANDER</button>
            </div>
        `;
    container.appendChild(card);
  });
}

let isProcessingPurchase = false;

function buyCar(model, price, colorElementId) {
  if (isProcessingPurchase) return;
  isProcessingPurchase = true;
  setTimeout(() => { isProcessingPurchase = false; }, 2000);

  const colorSelect = document.getElementById(colorElementId);
  const color = colorSelect ? colorSelect.value : 'black';

  console.log(`Commande de ${model} (${color}) pour ${price}$`);

  // Trouver la définition du véhicule pour vérifier s'il a un job assigné/targetJob
  let targetJob = null;
  if (typeof carConfig !== 'undefined' && carConfig.cars) {
    const carDef = carConfig.cars.find(c => c.model.toLowerCase() === model.toLowerCase());
    if (carDef && carDef.job) {
      targetJob = carDef.job;
    }
  }

  // Envoyer au client LUA
  fetch(`https://${GetParentResourceName()}/buyVehicle`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: model,
      price: price,
      color: color,
      targetJob: targetJob
    })
  });
}


// --- COMMUN ---

// Recevoir les données / Fermer
window.addEventListener('message', (event) => {
  const data = event.data;

  if (data.action === 'updateSocietyData') {
    currentSocietyData = data.societyData;
    if (currentDashboard === 'securoserv') {
      updateSocietyDashboardUI();
    }
    updateYouToolBalance();
  } else if (data.action === 'closeLaptop') {
    closeLaptop();
  } else if (data.action === 'scroll') {
    const visibleDashboard = (focusedApp && getDash(focusedApp) && getDash(focusedApp).classList.contains('visible') && !getDash(focusedApp).classList.contains('minimized') ? getDash(focusedApp) : document.querySelector('#dashboard-securoserv.visible:not(.minimized), #dashboard-pdm.visible:not(.minimized), #dashboard-d8.visible:not(.minimized)'));
    if (visibleDashboard) {
      const categoryList = visibleDashboard.querySelector('#category-list');
      const content = visibleDashboard.querySelector('.content');
      const mouseX = parseInt(document.getElementById('virtual-cursor').style.left) || 0;

      if (mouseX < 250 && categoryList) {
        categoryList.scrollTop += (data.delta || 0);
      } else if (content) {
        content.scrollTop += (data.delta || 0);
      }
    }
  }
});

// Formater l'argent
function formatMoney(amount) {
  return new Intl.NumberFormat('fr-FR', {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 0
  }).format(amount).replace('US', '').trim();
}
// --- LOGIQUE CLICK & DRAG SCROLL (TABLETTE) ---
let isDragging = false;
let startY = 0;
let startScrollTop = 0;
let dragTarget = null;

document.addEventListener('mousedown', function (e) {
  // IMPORTANT: Ne pas déclencher le scroll par drag si on clique sur un slider ou bouton
  if (e.target.id === 'price-range' || e.target.closest('button') || e.target.closest('select')) return;

  // Vérifier si on clique dans la zone de contenu d'un dashboard visible
  const visibleDashboard = (focusedApp && getDash(focusedApp) && getDash(focusedApp).classList.contains('visible') && !getDash(focusedApp).classList.contains('minimized') ? getDash(focusedApp) : document.querySelector('#dashboard-securoserv.visible:not(.minimized), #dashboard-pdm.visible:not(.minimized), #dashboard-d8.visible:not(.minimized)'));
  if (visibleDashboard) {
    const categoryList = visibleDashboard.querySelector('#category-list');
    const content = visibleDashboard.querySelector('.content');

    if (content && content.contains(e.target)) {
      isDragging = true;
      startY = e.clientY;
      startScrollTop = content.scrollTop;
      dragTarget = content;
    } else if (categoryList && categoryList.contains(e.target)) {
      isDragging = true;
      startY = e.clientY;
      startScrollTop = categoryList.scrollTop;
      dragTarget = categoryList;
    }
  }
});

document.addEventListener('mousemove', function (e) {
  if (!isDragging || !dragTarget) return;

  // Calculer le déplacement
  const deltaY = e.clientY - startY;

  // Appliquer le scroll (Tirer vers le haut fait descendre le contenu, comme sur tactile)
  // USER REQUEST: Inverser le sens
  // Mouse Down (Descendre souris) -> Delta positif -> ScrollTop diminue (Monte dans la page)
  dragTarget.scrollTop = startScrollTop - deltaY;
});


document.addEventListener('mouseup', function (e) {
    if (isDragging) {
    isDragging = false;
    dragTarget = null;
    // document.body.style.cursor = 'default';
  }
  
  // Fermer les suggestions D8 si on clique ailleurs
  const suggestions = document.getElementById('d8-suggestions');
  if (suggestions && !e.target.closest('#d8-tenant-search')) {
      suggestions.style.display = 'none';
  }
});
// Fermer le laptop
function closeLaptop() {
  fetch(`https://${GetParentResourceName()}/closeLaptop`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({})
  });
}

function renderOrders() {
  const container = document.getElementById('orders-list');
  if (!container) return;

  container.innerHTML = '';

  const hasDealershipOrders = currentSocietyData.orders && currentSocietyData.orders.length > 0;
  const hasYouToolOrders = currentSocietyData.youtoolOrders && currentSocietyData.youtoolOrders.length > 0;

  if (!hasDealershipOrders && !hasYouToolOrders) {
    container.innerHTML = '<div style="text-align:center; color:var(--text-dim); margin-top:50px;">Aucune commande en cours</div>';
    return;
  }

  // Temps en secondes
  const serverTime = currentSocietyData.serverTime || Math.floor(Date.now() / 1000);

  // 1. RENDER DEALERSHIP IMPORT ORDERS
  if (hasDealershipOrders) {
    const header = document.createElement('div');
    header.style.fontSize = '10px';
    header.style.textTransform = 'uppercase';
    header.style.letterSpacing = '1.5px';
    header.style.color = '#ff2e88'; // Orange Accent matching Import
    header.style.marginBottom = '12px';
    header.style.fontWeight = '800';
    header.style.opacity = '0.9';
    header.style.borderBottom = '1px solid rgba(255, 46, 136, 0.2)';
    header.style.paddingBottom = '4px';
    header.textContent = 'Importations Véhicules';
    container.appendChild(header);

    const totalDuration = (currentSocietyData.deliveryTime || 3600000) / 1000;

    currentSocietyData.orders.forEach(order => {
      let vehicleLabel = order.vehicle_model;
      if (typeof carConfig !== 'undefined' && carConfig.cars) {
        const vehicleInfo = carConfig.cars.find(c => c.model.toLowerCase() === (order.vehicle_model || '').toLowerCase());
        if (vehicleInfo) vehicleLabel = vehicleInfo.label;
      }

      const elapsed = serverTime - order.ordered_at;
      let progress = (elapsed / totalDuration) * 100;
      if (progress < 0) progress = 0;
      if (progress > 100) progress = 100;

      let statusLabel = 'EN TRANSIT';
      let statusColor = '#f39c12';
      let barColor = '#f39c12';

      if (order.status === 'ready' || progress >= 100) {
        if (order.status !== 'delivered') {
          progress = 100;
          statusLabel = 'ARRIVÉ AU PORT';
          statusColor = '#2ecc71';
          barColor = '#2ecc71';
        }
      }

      if (order.status === 'delivered') {
        progress = 100;
        statusLabel = 'LIVRÉ';
        statusColor = '#3498db';
        barColor = '#3498db';
      }

      const card = document.createElement('div');
      card.style.display = 'block';
      card.style.padding = '12px 15px';
      card.style.background = 'rgba(255,255,255,0.02)';
      card.style.border = '1px solid rgba(255,255,255,0.04)';
      card.style.borderRadius = '8px';
      card.style.marginBottom = '12px';

      card.innerHTML = `
          <div style="display:flex; justify-content:space-between; margin-bottom:8px; align-items:center;">
              <div style="font-weight:600; color:white; font-size:12px;">${vehicleLabel} <span style="font-size:10px; color:var(--text-dim); font-weight:400;">(${order.vehicle_color})</span></div>
              <div style="font-size:9px; background:${statusColor}; color:#1e1e1e; padding:2px 6px; border-radius:4px; font-weight:800; letter-spacing:0.5px;">${statusLabel}</div>
          </div>
          <div style="display:flex; justify-content:space-between; font-size:10px; color:var(--text-dim); margin-bottom:6px;">
              <span>Cmd #${order.id} • ${new Date(order.ordered_at * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
              <span>${Math.round(progress)}%</span>
          </div>
          <div style="background:rgba(255,255,255,0.08); height:5px; border-radius:3px; overflow:hidden;">
              <div style="height:100%; width:${progress}%; background:${barColor}; transition:width 0.5s;"></div>
          </div>
        `;

      container.appendChild(card);
    });
  }

  // 2. RENDER YOUTOOL B2B ORDERS
  if (hasYouToolOrders) {
    const header = document.createElement('div');
    header.style.fontSize = '10px';
    header.style.textTransform = 'uppercase';
    header.style.letterSpacing = '1.5px';
    header.style.color = '#3498db'; // Sleek blue for YouTool deliveries
    header.style.marginTop = hasDealershipOrders ? '20px' : '0px';
    header.style.marginBottom = '12px';
    header.style.fontWeight = '800';
    header.style.opacity = '0.9';
    header.style.borderBottom = '1px solid rgba(52, 152, 219, 0.2)';
    header.style.paddingBottom = '4px';
    header.textContent = 'Livraisons GoPostal';
    container.appendChild(header);

    currentSocietyData.youtoolOrders.forEach(order => {
      const elapsed = serverTime - order.created_at;
      const totalDuration = order.delivery_time - order.created_at;
      
      let progress = totalDuration > 0 ? (elapsed / totalDuration) * 100 : 100;
      if (progress < 0) progress = 0;
      if (progress > 100) progress = 100;

      let statusLabel = 'EXPÉDIÉ';
      let statusColor = '#ff2e88'; // Orange
      let barColor = '#ff2e88';

      if (order.status === 'ready' || progress >= 100) {
        if (order.status !== 'delivered' && order.status !== 'completed') {
          progress = 100;
          statusLabel = 'DISPONIBLE';
          statusColor = '#2ecc71'; // Green
          barColor = '#2ecc71';
        }
      }

      if (order.status === 'delivered' || order.status === 'completed') {
        progress = 100;
        statusLabel = 'LIVRÉ';
        statusColor = '#9b59b6'; // Purple for claimed/delivered
        barColor = '#9b59b6';
      }

      const card = document.createElement('div');
      card.style.display = 'block';
      card.style.padding = '12px 15px';
      card.style.background = 'rgba(255,255,255,0.02)';
      card.style.border = '1px solid rgba(255,255,255,0.04)';
      card.style.borderRadius = '8px';
      card.style.marginBottom = '12px';

      card.innerHTML = `
          <div style="display:flex; justify-content:space-between; margin-bottom:8px; align-items:center;">
              <div style="font-weight:600; color:white; font-size:12px;">${order.quantity}x ${order.item_label}</div>
              <div style="font-size:9px; background:${statusColor}; color:#1e1e1e; padding:2px 6px; border-radius:4px; font-weight:800; letter-spacing:0.5px;">${statusLabel}</div>
          </div>
          <div style="display:flex; justify-content:space-between; font-size:10px; color:var(--text-dim); margin-bottom:6px;">
              <span>Cmd #${order.id} • ${new Date(order.created_at * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
              <span>${Math.round(progress)}%</span>
          </div>
          <div style="background:rgba(255,255,255,0.08); height:5px; border-radius:3px; overflow:hidden;">
              <div style="height:100%; width:${progress}%; background:${barColor}; transition:width 0.5s;"></div>
          </div>
        `;

      container.appendChild(card);
    });
  }
}

let selectedTenantIdentifier = null;

function handleD8Search(value) {
    const suggestions = document.getElementById('d8-suggestions');
    if (!suggestions) return;

    if (!value || value.length < 2) {
        suggestions.style.display = 'none';
        return;
    }

    // Afficher un état de chargement
    suggestions.innerHTML = '<div style="padding:10px; color:#888; font-size:12px;">Recherche en cours...</div>';
    suggestions.style.display = 'block';

    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pop_management';
    
    fetch(`https://${resourceName}/getPlayersForSuggestion`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ search: value })
    })
    .then(resp => resp.json())
    .then(players => {
        renderD8Suggestions(players);
    })
    .catch(err => {
        console.error('D8 Search Error:', err);
        suggestions.innerHTML = '<div style="padding:10px; color:#ff5555; font-size:12px;">Erreur de connexion</div>';
    });
}

function renderD8Suggestions(players) {
    const container = document.getElementById('d8-suggestions');
    if (!container) return;

    container.innerHTML = '';
    if (players.length === 0) {
        container.style.display = 'none';
        return;
    }

    players.forEach(player => {
        const item = document.createElement('div');
        item.style.padding = '10px 15px';
        item.style.color = '#ccc';
        item.style.fontSize = '12px';
        item.style.cursor = 'pointer';
        item.style.borderBottom = '1px solid #333';
        item.textContent = player.name;
        item.onmouseover = () => { item.style.background = '#333'; item.style.color = 'white'; };
        item.onmouseout = () => { item.style.background = 'transparent'; item.style.color = '#ccc'; };
        item.onclick = () => selectD8Suggestion(player);
        container.appendChild(item);
    });

    container.style.display = 'block';
}

function selectD8Suggestion(player) {
    const input = document.getElementById('d8-tenant-search');
    const suggestions = document.getElementById('d8-suggestions');
    const confirmBtn = document.getElementById('d8-confirm-tenant');

    if (input) input.value = player.name;
    if (suggestions) suggestions.style.display = 'none';
    
    selectedTenantIdentifier = player.identifier;
    if (confirmBtn) confirmBtn.style.opacity = '1';
}

function confirmD8Tenant(propId) {
    if (!selectedTenantIdentifier) return;

    console.log(`Ajout du locataire ${selectedTenantIdentifier} à la propriété ${propId}`);
    
    // Pour l'instant, on fait juste une notification côté client
    // Dans une version complète, on enverrait une requête au serveur pour mettre à jour la DB
    fetch(`https://${GetParentResourceName()}/setD8Tenant`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
            propId: propId,
            identifier: selectedTenantIdentifier
        })
    });

    // Reset local state
    selectedTenantIdentifier = null;
    const confirmBtn = document.getElementById('d8-confirm-tenant');
    if (confirmBtn) confirmBtn.style.opacity = '0.5';
    
    // Mettre à jour le statut du bien localement (optionnel pour le visuel)
    const prop = d8Properties.find(p => p.id === propId);
    if (prop) prop.status = 'LOUÉ';
    
    setTimeout(() => {
        document.getElementById('d8-property-detail').style.display = 'none';
        document.getElementById('d8-property-grid').style.display = 'grid';
        renderD8Properties();
    }, 1000);
}

function openD8Keyboard(propId) {
    fetch(`https://${GetParentResourceName()}/openKeyboard`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ propId: propId })
    });
}

// Recevoir le résultat du clavier natif — chemin legacy Dynasty 8 (span cliquable, pas un <input>)
window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action !== 'keyboardResult') return;
    // Bridge générique (au-dessus) gère tout event qui porte fieldId/requestId.
    // Ici on ne traite QUE le legacy propId (D8) pour ne pas s'écrire dessus.
    if (data.fieldId || data.requestId) return;
    const nameDisplay = document.getElementById('d8-tenant-name');
    if (nameDisplay) nameDisplay.textContent = data.value;
    handleD8Search(data.value);
});

// --- LOGIQUE DYNASTY 8 ---

let d8Categories = [
    { id: 't1', label: 'Appt T1', icon: 'fa-building' },
    { id: 'luxe', label: 'Appt de Luxe', icon: 'fa-city' },
    { id: 'maison', label: 'Maison', icon: 'fa-house' },
    { id: 'villa', label: 'Villa', icon: 'fa-house-chimney-window' },
    { id: 'bureau', label: 'Bureau', icon: 'fa-briefcase' },
    { id: 'entrepot', label: 'Entrepôt', icon: 'fa-warehouse' }
];

let d8CurrentCategory = 'luxe';

// Propriétés D8 — tableau vide par défaut.
// Les biens sont définis dans Config.D8Zones (config.lua) et peuplés via d8LoadPropertiesFromZones().
let d8Properties = [];

function initD8() {
    renderD8Categories();
    renderD8Properties();
}

function renderD8Categories() {
    const list = document.getElementById('d8-category-list');
    if (!list) return;
    list.innerHTML = '';

    d8Categories.forEach(cat => {
        const item = document.createElement('div');
        item.className = `nav-item ${cat.id === d8CurrentCategory ? 'active' : ''}`;
        
        // Style spécifique D8 vert si actif
        if (cat.id === d8CurrentCategory) {
            item.style.background = '#0d5c2a';
            item.style.color = 'white';
        } else {
            item.style.background = 'transparent';
        }

        item.innerHTML = `<i class="fa-solid ${cat.icon}"></i> <span>${cat.label.toUpperCase()}</span>`;
        item.onclick = () => {
            d8CurrentCategory = cat.id;
            document.getElementById('d8-property-detail').style.display = 'none';
            document.getElementById('d8-property-grid').style.display = 'grid';
            renderD8Categories();
            renderD8Properties();
        };
        list.appendChild(item);
    });
}

function renderD8Properties() {
    const grid = document.getElementById('d8-property-grid');
    const title = document.getElementById('d8-page-title');
    if (!grid) return;

    const cat = d8Categories.find(c => c.id === d8CurrentCategory);
    title.textContent = `CATALOGUE - ${cat.label.toUpperCase()}`;

    grid.innerHTML = '';
    
    // Pour l'exemple on filtre
    const props = d8Properties.filter(p => p.cat === d8CurrentCategory);
    
    if (props.length === 0) {
        grid.innerHTML = '<div style="grid-column: 1/-1; text-align:center; color:#888; margin-top:50px;">Aucun bien dans cette catégorie</div>';
        return;
    }

    props.forEach(prop => {
        const card = document.createElement('div');
        card.className = 'stat-card';
        card.style.padding = '0';
        card.style.position = 'relative';
        card.style.background = '#2a2a2a';
        card.style.border = 'none';
        card.style.borderRadius = '8px';
        card.style.overflow = 'hidden';
        
        let statusHtml = '';
        if (prop.status === 'LOUÉ') {
            statusHtml = `<div style="position:absolute; top:12px; right:-12px; background:#c52622; color:white; padding:4px 20px; transform:rotate(15deg); font-weight:bold; font-size:10px; box-shadow:0 2px 5px rgba(0,0,0,0.5); z-index:10;">LOUÉ</div>`;
        }

        card.innerHTML = `
            <div style="height:140px; background:#000; overflow:hidden; position:relative;">
                <img src="${prop.image}" style="width:100%; height:100%; object-fit:cover;">
                ${statusHtml}
                <div style="position:absolute; bottom:5px; left:5px; background:rgba(255, 46, 136, 0.9); width:24px; height:24px; border-radius:50%; display:flex; align-items:center; justify-content:center; color:white;">
                    <i class="fa-solid fa-lightbulb" style="font-size:12px;"></i>
                </div>
            </div>
            <div style="padding:15px;">
                <div style="color:white; font-size:13px; font-weight:600;">${prop.name}</div>
                <div style="color:#888; font-size:10px; margin-bottom:15px;">${prop.address}</div>
                <button class="action-btn" style="width:100%; background:#0d5c2a; color:white; font-weight:bold; letter-spacing:1px; border-radius:4px;" onclick="showD8Detail(${prop.id})">INFOS</button>
            </div>
        `;
        grid.appendChild(card);
    });
}

function showD8Detail(propId) {
    const prop = d8Properties.find(p => p.id === propId);
    if (!prop) return;

    const grid = document.getElementById('d8-property-grid');
    const detail = document.getElementById('d8-property-detail');
    const title = document.getElementById('d8-page-title');
    
    grid.style.display = 'none';
    detail.style.display = 'block';
    
    title.textContent = `DÉTAILS DU BIEN - ${prop.name.toUpperCase()}`;
    
    // Reset state
    selectedTenantIdentifier = null;

    detail.innerHTML = `
        <div style="display:flex; gap:30px; animation: modalFadeIn 0.3s ease;">
            <div style="flex:1.2;">
                <img src="${prop.image}" style="width:100%; height:260px; object-fit:cover; border-radius:8px; box-shadow:0 10px 30px rgba(0,0,0,0.5);">
                
                <div style="margin-top:20px; display:flex; justify-content:space-between; align-items:flex-start;">
                    <div>
                        <div style="color:#888; font-size:12px; margin-bottom:5px;">VALEUR DU BIEN : <span style="color:white; font-weight:700; font-size:16px; margin-left:10px;">${formatMoney(prop.valeur)}</span></div>
                        <div style="color:#888; font-size:12px;">MONTANT LOYER : <span style="color:white; font-weight:700; font-size:16px; margin-left:10px;">${formatMoney(prop.loyer)} / Semaine</span></div>
                    </div>
                    
                    <div style="background:rgba(0,0,0,0.2); padding:12px 20px; border-radius:8px; display:flex; align-items:center; gap:15px; border:1px solid rgba(255,255,255,0.05);">
                        <span style="color:white; font-size:12px; font-weight:600;">Alerte Loyer Impayé</span>
                        <div style="background:#ff2e88; width:28px; height:28px; border-radius:50%; display:flex; align-items:center; justify-content:center; color:white; box-shadow:0 0 10px rgba(255, 46, 136, 0.5);">
                            <i class="fa-solid fa-check" style="font-size:14px;"></i>
                        </div>
                    </div>
                </div>

                <div style="margin-top:25px; display:flex; align-items:center; gap:15px; position:relative;">
                    <div style="color:#888; font-size:12px; font-weight:600; white-space:nowrap;">LOCATAIRE :</div>
                    <div style="flex:1; background:rgba(0,0,0,0.3); padding:10px 15px; border-radius:8px; border:1px solid rgba(255,255,255,0.1); color:#888; font-size:13px; display:flex; justify-content:space-between; align-items:center; cursor:pointer;" onclick="openD8Keyboard(${prop.id})">
                        <span id="d8-tenant-name">Rechercher...</span>
                        <i class="fa-solid fa-keyboard" style="font-size:12px;"></i>
                    </div>
                    <div id="d8-suggestions" style="display:none; position:absolute; top:100%; left:0; right:0; background:#222; border:1px solid #444; border-radius:0 0 8px 8px; z-index:1000; max-height:150px; overflow-y:auto; box-shadow:0 10px 20px rgba(0,0,0,0.5);">
                        <!-- Suggestions dynamiques -->
                    </div>
                    <div id="d8-confirm-tenant" style="background:#2ecc71; width:36px; height:36px; border-radius:50%; display:flex; align-items:center; justify-content:center; color:white; cursor:pointer; opacity:0.5;" onclick="confirmD8Tenant(${prop.id})">
                        <i class="fa-solid fa-check" style="font-size:18px;"></i>
                    </div>
                </div>

                <div style="margin-top:40px; background:rgba(0,0,0,0.3); padding:12px; color:#444; font-size:14px; font-family:monospace; border-radius:4px;">
                    N° ${prop.phone}
                </div>
            </div>

            <div style="flex:0.8;">
                <h2 style="color:white; margin:0; font-size:24px; font-weight:700;">${prop.name}</h2>
                <div style="color:#888; font-size:14px; margin-bottom:30px;">${prop.address}</div>
                
                <div style="display:grid; grid-template-columns: 1fr 1.2fr; gap:20px; background:rgba(255,255,255,0.02); padding:20px; border-radius:10px;">
                    <div>
                        <div style="color:#555; font-size:11px; font-weight:700; margin-bottom:5px;">CHAMBRE</div>
                        <div style="color:white; font-size:16px; font-weight:600;">: ${prop.chambres}</div>
                    </div>
                    <div>
                        <div style="color:#555; font-size:11px; font-weight:700; margin-bottom:5px;">SURFACE</div>
                        <div style="color:white; font-size:16px; font-weight:600;">: ${prop.surface} m²</div>
                    </div>
                    <div>
                        <div style="color:#555; font-size:11px; font-weight:700; margin-bottom:5px;">SALLE D'EAU</div>
                        <div style="color:white; font-size:16px; font-weight:600;">: ${prop.salleEau}</div>
                    </div>
                    <div>
                        <div style="color:#555; font-size:11px; font-weight:700; margin-bottom:5px;">VIE À VIE</div>
                        <div style="color:white; font-size:16px; font-weight:600;">: ${prop.vieAVie}</div>
                    </div>
                    <div>
                        <div style="color:#555; font-size:11px; font-weight:700; margin-bottom:5px;">EXTÉRIEUR</div>
                        <div style="color:white; font-size:16px; font-weight:600;">: ${prop.exterieur}</div>
                    </div>
                    <div>
                        <div style="color:#555; font-size:11px; font-weight:700; margin-bottom:5px;">STOCKAGE</div>
                        <div style="color:white; font-size:16px; font-weight:600;">: ${prop.stockage}</div>
                    </div>
                </div>

                <button class="action-btn" style="margin-top:40px; width:100%; background:#444; padding:12px; font-weight:700;" onclick="document.getElementById('d8-property-detail').style.display='none'; document.getElementById('d8-property-grid').style.display='grid'; renderD8Properties();">RETOUR AU CATALOGUE</button>
            </div>
        </div>

        <!-- Section coffre + clé (injectée dynamiquement) -->
        <div id="d8-chest-section" data-prop-id="${prop.id}" data-prop-name="${prop.name.replace(/"/g, '&quot;')}" style="margin-top:10px;"></div>
    `;

    // Charger les données coffre pour cette propriété
    loadD8PropertyData(prop.id, prop.name);

    setTimeout(() => {
        const input = document.getElementById('d8-tenant-search');
        if (input) input.focus();
    }, 100);
}

// --- LOGIQUE YOUTOOL ---

const youToolConfig = {
  categories: [
    { id: 'medical', label: 'Médical', icon: 'fa-kit-medical' },
    { id: 'restauration', label: 'Restauration', icon: 'fa-utensils' },
    { id: 'police', label: 'Maintien de l\'Ordre', icon: 'fa-shield-halved' },
    { id: 'meca', label: 'Mécanique Auto', icon: 'fa-wrench' },
    { id: 'vegatech', label: 'Vega Tech', icon: 'fa-microchip' },
    { id: 'divers', label: 'Divers', icon: 'fa-box' }
  ],
  items: [
    // Médical
    { model: 'aed', label: 'Défibrillateur (DAE)', price: 1500, category: 'medical', icon: 'img/aed.png', color: '#e74c3c', desc: 'Défibrillateur automatique externe pour premiers secours.' },
    { model: 'kitsoins', label: 'Kit de Soins Pro', price: 300, category: 'medical', icon: 'img/kitsoins.png', color: '#2ecc71', desc: 'Matériel médical d\'urgence complet.' },

    // Restauration
    { model: 'bouteille', label: 'Bouteille d\'eau (x5)', price: 15, category: 'restauration', icon: 'img/bouteille.png', color: '#3498db', desc: 'Bouteille d\'eau de source pour étancher la soif.' },
    { model: 'soda', label: 'Canette de Soda (x5)', price: 25, category: 'restauration', icon: 'img/soda.png', color: '#e67e22', desc: 'Canette de soda rafraîchissante sucrée.' },
    { model: 'cola', label: 'Canette de Cola (x5)', price: 25, category: 'restauration', icon: 'img/cola.png', color: '#c0392b', desc: 'Canette de cola pétillant classique.' },
    { model: 'hotdog', label: 'Hotdog Classique (x5)', price: 40, category: 'restauration', icon: 'img/hotdog.png', color: '#d35400', desc: 'Hotdog chaud avec moutarde et ketchup.' },

    // Maintien de l'Ordre
    { model: 'menottes', label: 'Menottes en acier', price: 250, category: 'police', icon: 'img/menottes.png', color: '#95a5a6', desc: 'Menottes réglementaires double verrouillage.' },
    { model: 'sabot', label: 'Sabot de blocage', price: 800, category: 'police', icon: 'img/clamp.png', color: '#f1c40f', desc: 'Sabot de Denver pour immobilisation de véhicules.' },
    { model: 'cle_sabot', label: 'Clé de sabot', price: 150, category: 'police', icon: 'img/carkeys.png', color: '#f39c12', desc: 'Clé de déverrouillage pour sabot de roue.' },
    { model: 'megaphone', label: 'Mégaphone Pro', price: 200, category: 'police', icon: 'img/megaphone.png', color: '#e67e22', desc: 'Amplificateur de voix haute puissance.' },
    { model: 'police_barrier', label: 'Barrière de Police', price: 90, category: 'police', icon: 'img/unknown.png', color: '#95a5a6', desc: 'Barrière mobile en métal galvanisé.' },
    { model: 'policevest', label: 'Gilet Pare-balles', price: 500, category: 'police', icon: 'img/policevest.png', color: '#34495e', desc: 'Gilet pare-balles tactique de police.' },
    { model: 'police_stormram', label: 'Bélier de Force', price: 1000, category: 'police', icon: 'img/unknown.png', color: '#7f8c8d', desc: 'Bélier d\'effraction tactique en acier.' },
    { model: 'radio', label: 'Radio portable', price: 120, category: 'police', icon: 'img/radio.png', color: '#34495e', desc: 'Radio émetteur-récepteur longue portée professionnelle.' },
    { model: 'pistol', label: 'Pistolet 9mm', price: 1200, category: 'police', icon: 'img/pistol.png', color: '#7f8c8d', desc: 'Arme de poing semi-automatique réglementaire.' },
    { model: 'smg', label: 'Mitraillette (SMG)', price: 2800, category: 'police', icon: 'img/smg.png', color: '#34495e', desc: 'Pistolet-mitrailleur automatique compact.' },
    { model: 'carabine', label: 'Carabine d\'assaut', price: 4500, category: 'police', icon: 'img/smg.png', color: '#2c3e50', desc: 'Fusil d\'assaut à haute précision et longue portée.' },
    { model: 'tazer', label: 'Taser tactique', price: 400, category: 'police', icon: 'img/tazer.png', color: '#f1c40f', desc: 'Dispositif de neutralisation électrique temporaire.' },
    { model: 'chargeur_pistol', label: 'Chargeur Pistolet', price: 60, category: 'police', icon: 'img/chargeurpistolet.png', color: '#7f8c8d', desc: 'Chargeur de rechange pour pistolet 9mm.' },
    { model: 'chargeur_smg', label: 'Chargeur SMG', price: 90, category: 'police', icon: 'img/chargeurmitraillette.png', color: '#34495e', desc: 'Chargeur pour pistolet-mitrailleur.' },
    { model: 'chargeur_fusil', label: 'Chargeur Carabine', price: 120, category: 'police', icon: 'img/chargeurfusil.png', color: '#2c3e50', desc: 'Chargeur de rechange pour fusil d\'assaut.' },
    { model: 'munitions_pistolet', label: 'Munitions 9mm (x50)', price: 45, category: 'police', icon: 'img/unknown.png', color: '#d35400', desc: 'Boîte de munitions de calibre 9mm.' },
    { model: 'munitions_smg', label: 'Munitions SMG (x50)', price: 60, category: 'police', icon: 'img/unknown.png', color: '#d35400', desc: 'Boîte de munitions pour SMG.' },
    { model: 'munitions_fusil', label: 'Munitions Fusil (x50)', price: 85, category: 'police', icon: 'img/unknown.png', color: '#d35400', desc: 'Boîte de munitions pour carabine.' },

    // Mécanique Auto & Outils
    { model: 'repakit', label: 'Kit de Réparation', price: 200, category: 'meca', icon: 'img/unknown.png', color: '#95a5a6', desc: 'Kit complet de réparation automobile pour mécaniciens.' },
    { model: 'jerry', label: 'Bidon d\'essence', price: 50, category: 'meca', icon: 'img/jerry.png', color: '#d35400', desc: 'Bidon d\'essence renforcé de 20L vide.' },
    { model: 'lampe', label: 'Lampe Torche', price: 30, category: 'meca', icon: 'img/lampe.png', color: '#f1c40f', desc: 'Lampe torche portative en aluminium.' },
    { model: 'radio', label: 'Radio portable', price: 120, category: 'meca', icon: 'img/radio.png', color: '#34495e', desc: 'Radio émetteur-récepteur longue portée.' },
    { model: 'pcb', label: 'Module pirate (PCB)', price: 1200, category: 'meca', icon: 'img/pcb.png', color: '#9b59b6', desc: 'Circuit de piratage électronique avancé.' },
    { model: 'tpe', label: 'Terminal de paiement (TPE)', price: 500, category: 'meca', icon: 'img/tpe.png', color: '#3498db', desc: 'Terminal de paiement électronique sans fil.' },
    { model: 'huile_moteur', label: 'Huile Moteur', price: 40, category: 'meca', icon: 'img/motoroil.png', color: '#d35400', desc: 'Bidon d\'huile moteur de synthèse haute performance.' },
    { model: 'batterie', label: 'Batterie de voiture', price: 150, category: 'meca', icon: 'img/carbattery.png', color: '#2980b9', desc: 'Batterie de démarrage 12V haute capacité.' },
    { model: 'pneu', label: 'Pneu neuf', price: 80, category: 'meca', icon: 'img/wheel.png', color: '#2c3e50', desc: 'Pneu toutes saisons renforcé.' },
    { model: 'freins', label: 'Kit de Freins', price: 90, category: 'meca', icon: 'img/brake.png', color: '#c0392b', desc: 'Disques et plaquettes de frein de rechange.' },
    { model: 'pieces_moteur', label: 'Pièces Moteur', price: 450, category: 'meca', icon: 'img/motorpart.png', color: '#7f8c8d', desc: 'Ensemble de pièces détachées pour bloc moteur.' },
    { model: 'pieces_transmission', label: 'Pièces Transmission', price: 380, category: 'meca', icon: 'img/transmissionpart.png', color: '#34495e', desc: 'Composants pour arbre et boîte de vitesses.' },
    { model: 'pieces_suspension', label: 'Pièces Suspension', price: 220, category: 'meca', icon: 'img/suspension.png', color: '#16a085', desc: 'Amortisseurs et pièces de suspension.' },
    { model: 'pieces_carrosserie', label: 'Pièces Carrosserie', price: 300, category: 'meca', icon: 'img/carpart.png', color: '#bdc3c7', desc: 'Éléments de carrosserie et panneaux extérieurs.' },
    // Vega Tech
    { model: 'composant_cassette', label: 'Composant de Cassette', price: 30, category: 'vegatech', icon: 'img/unknown.png', color: '#8e44ad', desc: 'Composants électroniques pour fabriquer des cassettes.' },
    { model: 'bande_magnetique', label: 'Bande Magnétique', price: 20, category: 'vegatech', icon: 'img/unknown.png', color: '#34495e', desc: 'Bande magnétique pour l\'enregistrement audio.' },
    { model: 'kit_reparation_vegatech', label: 'Kit de Réparation Vega Tech', price: 100, category: 'vegatech', icon: 'img/unknown.png', color: '#27ae60', desc: 'Kit de pièces et outils de précision Vega Tech.' },
    // Divers
    { model: 'pot', label: 'Pot de fleur', price: 50, category: 'divers', icon: 'img/pot.png', color: '#b48c5a', desc: 'Un pot en argile pour faire pousser des plantes.' }
  ]
};

let youToolCurrentCategory = 'medical';
let youToolSearchQuery = '';
let youToolQuantities = {}; // Stocke les quantités sélectionnées par modèle (sur les cartes)

// ── PANIER YOUTOOL ────────────────────────────────────────────────────────────
// youToolCart : Map model -> { item, qty }
let youToolCart = {};
let youToolCartOpen = false;

function getCartTotal() {
  let total = 0;
  let count = 0;
  for (const model in youToolCart) {
    const entry = youToolCart[model];
    total += entry.item.price * entry.qty;
    count += entry.qty;
  }
  return { total, count };
}

function updateCartBadge() {
  const badge = document.getElementById('yt-cart-badge');
  const btn   = document.getElementById('yt-cart-btn');
  if (!badge || !btn) return;
  const { count } = getCartTotal();
  badge.textContent = count;
  badge.style.display = count > 0 ? 'flex' : 'none';
  if (count > 0) {
    btn.classList.add('yt-cart-has-items');
  } else {
    btn.classList.remove('yt-cart-has-items');
  }
}

function renderYouToolCart() {
  const panel   = document.getElementById('yt-cart-panel');
  const list    = document.getElementById('yt-cart-list');
  const totalEl = document.getElementById('yt-cart-total');
  if (!panel || !list || !totalEl) return;

  list.innerHTML = '';
  const models = Object.keys(youToolCart);

  if (models.length === 0) {
    list.innerHTML = '<div class="yt-cart-empty"><i class="fa-solid fa-cart-shopping" style="font-size:28px;opacity:0.3;margin-bottom:10px;"></i><div>Panier vide</div></div>';
    totalEl.textContent = '0 $';
    return;
  }

  models.forEach(model => {
    const entry = youToolCart[model];
    const lineTotal = entry.item.price * entry.qty;

    // Image / icône
    let iconHtml = '';
    if (entry.item.icon && entry.item.icon.startsWith('fa-')) {
      iconHtml = `<i class="fa-solid ${entry.item.icon}" style="color:${entry.item.color || 'var(--accent)'}; font-size:22px;"></i>`;
    } else if (entry.item.icon) {
      let imgSrc = entry.item.icon;
      if (!imgSrc.startsWith('http') && !imgSrc.startsWith('nui://')) imgSrc = `nui://pop_inventory/html/${imgSrc}`;
      iconHtml = `<img src="${imgSrc}" style="width:32px;height:32px;object-fit:contain;">`;
    }

    const row = document.createElement('div');
    row.className = 'yt-cart-item';
    row.innerHTML = `
      <div class="yt-cart-item-icon">${iconHtml}</div>
      <div class="yt-cart-item-info">
        <div class="yt-cart-item-name" title="${entry.item.label}">${entry.item.label}</div>
        <div class="yt-cart-item-price">${formatMoney(entry.item.price)} / ut</div>
      </div>
      <div class="yt-cart-item-controls">
        <button class="youtool-qty-btn" onclick="cartAdjustQty('${model}', -1)">−</button>
        <span class="yt-cart-qty">${entry.qty}</span>
        <button class="youtool-qty-btn" onclick="cartAdjustQty('${model}', 1)">+</button>
      </div>
      <div class="yt-cart-item-total">${formatMoney(lineTotal)}</div>
      <button class="yt-cart-remove" onclick="removeFromYouToolCart('${model}')" title="Retirer"><i class="fa-solid fa-xmark"></i></button>
    `;
    list.appendChild(row);
  });

  const { total } = getCartTotal();
  totalEl.textContent = formatMoney(total);
}

function addToYouToolCart(model) {
  const item = youToolConfig.items.find(i => i.model === model);
  if (!item) return;

  const qty = youToolQuantities[model] || 1;

  if (youToolCart[model]) {
    youToolCart[model].qty = Math.min(youToolCart[model].qty + qty, 999);
  } else {
    youToolCart[model] = { item, qty };
  }

  // Animation de rebond du badge
  const btn = document.getElementById('yt-cart-btn');
  if (btn) {
    btn.classList.remove('yt-cart-bounce');
    void btn.offsetWidth; // reflow
    btn.classList.add('yt-cart-bounce');
  }

  updateCartBadge();
  if (youToolCartOpen) renderYouToolCart();
}

function removeFromYouToolCart(model) {
  delete youToolCart[model];
  updateCartBadge();
  renderYouToolCart();
}

function cartAdjustQty(model, delta) {
  if (!youToolCart[model]) return;
  youToolCart[model].qty = Math.max(1, Math.min(youToolCart[model].qty + delta, 999));
  updateCartBadge();
  renderYouToolCart();
}

function toggleYouToolCart() {
  const panel = document.getElementById('yt-cart-panel');
  if (!panel) return;
  youToolCartOpen = !youToolCartOpen;
  panel.classList.toggle('yt-cart-open', youToolCartOpen);
  if (youToolCartOpen) renderYouToolCart();
}

function checkoutYouToolCart() {
  if (isProcessingYouToolPurchase) return;
  const models = Object.keys(youToolCart);
  if (models.length === 0) return;

  isProcessingYouToolPurchase = true;
  setTimeout(() => { isProcessingYouToolPurchase = false; }, 2500);

  const items = models.map(model => ({
    model:    youToolCart[model].item.model,
    label:    youToolCart[model].item.label,
    quantity: youToolCart[model].qty,
    price:    youToolCart[model].item.price * youToolCart[model].qty
  }));

  const grandTotal = items.reduce((sum, i) => sum + i.price, 0);
  console.log(`[YouTool][Cart] Commande groupée de ${items.length} article(s) — total ${grandTotal}$`, items);

  fetch(`https://${GetParentResourceName()}/buyYouToolCart`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ items })
  }).then(r => r.json()).then(res => {
    if (res && res.ok) {
      // Vider le panier après succès
      youToolCart = {};
      updateCartBadge();
      renderYouToolCart();
    }
    // En cas d'erreur, le serveur envoie une notif via cr-laptop:notify
  }).catch(err => {
    console.error('[YouTool][Cart] fetch error:', err);
  });
}
// ── FIN PANIER ────────────────────────────────────────────────────────────────

function initYouTool() {
  console.log('Initialisation de YouTool...');
  
  // Toujours actualiser les fonds en ouvrant
  fetch(`https://${GetParentResourceName()}/requestSocietyData`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  }).then(resp => resp.json()).then(data => {
    if (data && data.action === 'updateSocietyData') {
      currentSocietyData = data.societyData;
      updateYouToolBalance();
    }
  }).catch(() => {});

  renderYouToolCategories();
  renderYouToolItems();
  updateYouToolBalance();
  updateCartBadge();
}

function updateYouToolBalance() {
  const balEl = document.getElementById('youtool-balance');
  if (!balEl) return;
  if (currentSocietyData) {
    balEl.textContent = formatMoney(currentSocietyData.money);
  } else {
    balEl.textContent = '0 $';
  }
}

function renderYouToolCategories() {
  const container = document.getElementById('youtool-category-list');
  if (!container) return;

  container.innerHTML = '';

  youToolConfig.categories.forEach(cat => {
    const item = document.createElement('div');
    item.className = `nav-item ${cat.id === youToolCurrentCategory ? 'active' : ''}`;
    
    // Style de surbrillance YouTool
    if (cat.id === youToolCurrentCategory) {
      item.style.background = '#ff2e88';
      item.style.color = 'white';
    } else {
      item.style.background = 'transparent';
    }

    item.innerHTML = `<i class="fa-solid ${cat.icon}"></i> <span>${cat.label}</span>`;
    item.onclick = (event) => {
      youToolCurrentCategory = cat.id;
      
      // Nettoyer la recherche lors du changement de catégorie
      const searchInput = document.getElementById('youtool-search');
      if (searchInput) {
        searchInput.value = '';
        youToolSearchQuery = '';
      }

      renderYouToolCategories();
      renderYouToolItems();
    };
    container.appendChild(item);
  });
}

function filterYouToolItems(query) {
  youToolSearchQuery = query.toLowerCase().trim();
  renderYouToolItems();
}

function renderYouToolItems() {
  const container = document.getElementById('youtool-item-grid');
  const title = document.getElementById('youtool-page-title');
  if (!container) return;

  // Mettre à jour le titre
  const cat = youToolConfig.categories.find(c => c.id === youToolCurrentCategory);
  if (title && cat) {
    title.textContent = `GOPOSTAL - ${cat.label.toUpperCase()}`;
  }

  container.innerHTML = '';

  // Filtrer les articles selon la catégorie et la recherche
  let filteredItems = youToolConfig.items.filter(item => item.category === youToolCurrentCategory);
  
  if (youToolSearchQuery !== '') {
    filteredItems = filteredItems.filter(item => 
      item.label.toLowerCase().includes(youToolSearchQuery) || 
      item.desc.toLowerCase().includes(youToolSearchQuery) ||
      item.model.toLowerCase().includes(youToolSearchQuery)
    );
  }

  if (filteredItems.length === 0) {
    container.innerHTML = '<div style="grid-column: 1/-1; text-align:center; color:#888; margin-top:50px;"><i class="fa-solid fa-circle-info" style="font-size:24px; margin-bottom:10px; display:block;"></i> Aucun article disponible</div>';
    return;
  }

  filteredItems.forEach(item => {
    const card = document.createElement('div');
    card.className = 'youtool-card';

    // Initialiser la quantité si non présente
    if (youToolQuantities[item.model] === undefined) {
      youToolQuantities[item.model] = 1;
    }

    const qty = youToolQuantities[item.model];
    const totalCost = item.price * qty;

    let iconHtml = '';
    if (item.icon && item.icon.startsWith('fa-')) {
      iconHtml = `<i class="youtool-card-icon ${item.icon}" style="color: ${item.color || 'var(--accent)'};"></i>`;
    } else if (item.icon) {
      let imgSrc = item.icon;
      if (!imgSrc.startsWith('http') && !imgSrc.startsWith('nui://')) {
        imgSrc = `nui://pop_inventory/html/${imgSrc}`;
      }
      iconHtml = `<img src="${imgSrc}" class="youtool-card-icon" style="max-width: 70px; max-height: 70px; object-fit: contain;">`;
    }

    card.innerHTML = `
      <div class="youtool-card-icon-container">
        ${iconHtml}
      </div>
      
      <div style="padding: 12px; flex: 1; display: flex; flex-direction: column; gap: 6px;">
        <div style="color: white; font-weight: 700; font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="${item.label}">${item.label}</div>
        <div style="color: var(--text-dim); font-size: 10px; line-height: 1.3; height: 26px; overflow: hidden; text-overflow: ellipsis; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical;">${item.desc}</div>
        
        <!-- Sélecteur de quantité & Prix total -->
        <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 6px; background: rgba(0,0,0,0.15); padding: 6px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.02);">
          <div style="display: flex; align-items: center; gap: 4px;">
            <button class="youtool-qty-btn" onclick="adjustYouToolQty('${item.model}', -1)">−</button>
            <input type="text" class="youtool-qty-input" id="qty-input-${item.model}" value="${qty}" readonly data-no-native-keyboard="true">
            <button class="youtool-qty-btn" onclick="adjustYouToolQty('${item.model}', 1)">+</button>
          </div>
          <div style="text-align: right;">
            <span style="font-size: 8px; color: var(--text-dim); display: block; text-transform: uppercase; font-weight: 600; letter-spacing: 0.5px;">TOTAL</span>
            <span id="total-${item.model}" style="color: #2ecc71; font-weight: 800; font-size: 12px;">${formatMoney(totalCost)}</span>
          </div>
        </div>

        <button class="youtool-order-btn" style="margin-top: 6px; background: #27ae60 !important; box-shadow: 0 4px 10px rgba(39,174,96,0.25);" onclick="addToYouToolCart('${item.model}')">
          <i class="fa-solid fa-basket-shopping"></i> AJOUTER AU PANIER
        </button>
      </div>
    `;
    container.appendChild(card);
  });
}

function adjustYouToolQty(model, delta) {
  let qty = youToolQuantities[model] || 1;
  qty += delta;
  
  if (qty < 1) qty = 1;
  if (qty > 100) qty = 100;
  
  youToolQuantities[model] = qty;

  // Mettre à jour l'input et le prix total de la carte sans re-render complet
  const input = document.getElementById(`qty-input-${model}`);
  const totalSpan = document.getElementById(`total-${model}`);
  
  const item = youToolConfig.items.find(i => i.model === model);
  if (input && totalSpan && item) {
    input.value = qty;
    totalSpan.textContent = formatMoney(item.price * qty);
  }
}

let isProcessingYouToolPurchase = false;

// --- LOGIQUE GOUV (ADMINISTRATION BC) ---
let currentGouvData = null;
let currentSectorSelected = '';

function startGouvPolling() {
  requestGouvData();
  if (pollingInterval) clearInterval(pollingInterval);
  pollingInterval = setInterval(() => {
    if (currentDashboard === 'gouv') {
      requestGouvData();
    }
  }, 2000);
}

function stopGouvPolling() {
  if (pollingInterval) {
    clearInterval(pollingInterval);
    pollingInterval = null;
  }
}

function requestGouvData() {
  fetch(`https://${GetParentResourceName()}/requestGouvData`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  }).then(resp => resp.json()).then(data => {
    if (data && data.action === 'updateGouvData') {
      currentGouvData = data.gouvData;
      updateGouvDashboardUI();
    }
  }).catch(err => console.error(err));
}

function switchGouvTab(tabName) {
  document.querySelectorAll('.gouv-tab').forEach(tab => {
    tab.style.display = 'none';
  });
  document.querySelectorAll('#dashboard-gouv .sidebar .nav-item').forEach(item => {
    item.classList.remove('active');
  });

  const targetTab = document.getElementById('gouv-' + tabName + '-tab');
  if (targetTab) targetTab.style.display = 'block';
  
  if(event && event.target) {
    const navItem = event.target.closest('.nav-item');
    if (navItem) navItem.classList.add('active');
  }
}

function updateGouvDashboardUI() {
  if (!currentGouvData) return;

  const gradeEl = document.getElementById('player-grade-gouv');
  if (gradeEl) gradeEl.textContent = currentGouvData.playerGradeLabel || 'Agent';

  // Toggle Mayor Menus
  const isMayor = currentGouvData.isBoss;
  document.getElementById('gouv-mayor-menus').style.display = isMayor ? 'block' : 'none';

  // Stats
  document.getElementById('gouv-money').textContent = formatMoney(currentGouvData.money);
  document.getElementById('gouv-money-2').textContent = formatMoney(currentGouvData.money);
  document.getElementById('gouv-employee-count').textContent = currentGouvData.employees ? currentGouvData.employees.length : 0;
  
  if (currentGouvData.tva !== undefined) {
    document.getElementById('gouv-tva-rate').textContent = currentGouvData.tva + '%';
    document.getElementById('gouv-tva-display').textContent = currentGouvData.tva + '%';
  }
  
  // Employees
  const empList = document.getElementById('gouv-employee-list');
  if (empList) {
    empList.innerHTML = '';
    if (currentGouvData.employees && currentGouvData.employees.length > 0) {
      currentGouvData.employees.forEach(emp => {
        empList.innerHTML += `
          <tr>
            <td>${emp.firstname} ${emp.lastname}</td>
            <td>${emp.gradeLabel || 'Grade ' + emp.job_grade}</td>
            <td>
                <button class="action-btn" onclick="paySalary('${emp.identifier}')">Prime</button>
                <button class="action-btn promote-btn" onclick="promoteEmployee('${emp.identifier}', ${emp.job_grade})">Promouvoir</button>
                <button class="action-btn demote-btn" onclick="demoteEmployee('${emp.identifier}', ${emp.job_grade})">Rétrograder</button>
                <button class="action-btn fire-btn" onclick="fireEmployee('${emp.identifier}')">Virer</button>
            </td>
          </tr>
        `;
      });
    } else {
      empList.innerHTML = '<tr><td colspan="3" style="text-align:center;">Aucun employé</td></tr>';
    }
  }

  // Vehicles
  const vehList = document.getElementById('gouv-vehicle-list');
  if (vehList) {
    vehList.innerHTML = '';
    if (currentGouvData.vehicles && currentGouvData.vehicles.length > 0) {
      currentGouvData.vehicles.forEach(veh => {
        vehList.innerHTML += `
          <tr>
            <td>${veh.model || 'Inconnu'}</td>
            <td>${veh.plate}</td>
            <td>${veh.driver || 'Garage'}</td>
            <td><span style="color:#2ecc71">Disponible</span></td>
          </tr>
        `;
      });
    } else {
      vehList.innerHTML = '<tr><td colspan="4" style="text-align:center;">Aucun véhicule.</td></tr>';
    }
  }

  // Update request list dynamically if we have a sector selected
  if (currentSectorSelected) {
    loadSectorRequests(currentSectorSelected);
  }

  // Populate available jobs in custom dropdown
  const optionsDiv = document.getElementById('subsidy-company-options');
  if (optionsDiv && currentGouvData.availableJobs) {
      optionsDiv.innerHTML = '';
      currentGouvData.availableJobs.forEach(job => {
          const opt = document.createElement('div');
          opt.className = 'subsidy-company-option';
          opt.style.padding = '10px';
          opt.style.cursor = 'pointer';
          opt.style.color = 'white';
          opt.style.fontSize = '13px';
          opt.style.borderBottom = '1px solid rgba(255,255,255,0.03)';
          opt.textContent = job.label + ' (' + job.name + ')';
          
          opt.onmouseover = () => { opt.style.background = 'rgba(255,255,255,0.05)'; };
          opt.onmouseout = () => { opt.style.background = 'transparent'; };
          
          opt.onclick = () => {
              document.getElementById('selected-company-label').textContent = job.label;
              document.getElementById('selected-company-label').style.color = 'white';
              document.getElementById('new-subsidy-entity').value = job.label;
              document.getElementById('new-subsidy-job').value = job.name;
              optionsDiv.style.display = 'none';
          };
          optionsDiv.appendChild(opt);
      });
  }
}

function promptGouvRecruit() {
  showInputModal('ID du joueur à recruter', '', (val) => {
    fetch(`https://${GetParentResourceName()}/recruitEmployee`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ targetId: val })
    });
  });
}

function promptGouvAddGrade() {
  fetch(`https://${GetParentResourceName()}/notify`, {
      method: 'POST',
      body: JSON.stringify({ message: "La gestion des grades se fait via le F6 ou menu admin." })
  });
}

function showGouvDepositModal() { showDepositModal(); }
function showGouvWithdrawModal() { showWithdrawModal(); }
function promptChangeTva() {
  const currentTva = (currentGouvData && currentGouvData.tva !== undefined) ? currentGouvData.tva : 20;
  showInputModal('Nouvelle TVA (%)', currentTva, (val) => {
    fetch(`https://${GetParentResourceName()}/changeTva`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ tva: val })
    });
    document.getElementById('gouv-tva-rate').textContent = val + '%';
    document.getElementById('gouv-tva-display').textContent = val + '%';
  });
}

function createWorkContract() {
  const name = document.getElementById('contract-name').value;
  const job = document.getElementById('contract-job').value;
  const salary = document.getElementById('contract-salary').value;
  if (!name || !job || !salary) return;
  fetch(`https://${GetParentResourceName()}/createWorkContract`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, job, salary })
  });
  document.getElementById('contract-name').value = '';
  document.getElementById('contract-job').value = '';
  document.getElementById('contract-salary').value = '';
}

function publishGouvNews() {
  const type = document.getElementById('publish-type').value;
  const title = document.getElementById('publish-title').value;
  const content = document.getElementById('publish-content').value;
  if(!title || !content) return;
  fetch(`https://${GetParentResourceName()}/publishGouvNews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type, title, content })
  });
  document.getElementById('publish-title').value = '';
  document.getElementById('publish-content').value = '';
}

function promptScheduleCouncil() {
    fetch(`https://${GetParentResourceName()}/scheduleCouncil`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}
function startCurrentCouncil() {
    fetch(`https://${GetParentResourceName()}/startCouncil`, { method: 'POST', body: JSON.stringify({}) });
}
function pauseCurrentCouncil() {
    fetch(`https://${GetParentResourceName()}/pauseCouncil`, { method: 'POST', body: JSON.stringify({}) });
}
function endCurrentCouncil() {
    fetch(`https://${GetParentResourceName()}/endCouncil`, { method: 'POST', body: JSON.stringify({}) });
}
function promptProposeOrdinance() {
    fetch(`https://${GetParentResourceName()}/notify`, {
        method: 'POST',
        body: JSON.stringify({ message: "Proposition d'ordonnance envoyée au Maire." })
    });
}
function loadSectorRequests(sector) {
    const isSwitching = (currentSectorSelected !== sector);
    currentSectorSelected = sector;
    
    // Highlight active card
    document.querySelectorAll('.gouv-sector-card').forEach(card => {
        if (card.getAttribute('onclick') && card.getAttribute('onclick').includes(`'${sector}'`)) {
            card.classList.add('active');
        } else {
            card.classList.remove('active');
        }
    });

    if(!sector) {
        document.getElementById('sector-requests-container').style.display = 'none';
        document.getElementById('gouv-my-sector').textContent = "Sélectionnez votre secteur";
        return;
    }
    document.getElementById('sector-requests-container').style.display = 'block';
    
    // Hide form by default ONLY when switching sectors
    if (isSwitching) {
        const form = document.getElementById('custom-subsidy-form');
        if (form) {
            form.style.display = 'none';
        }
        const toggleIcon = document.getElementById('subsidy-toggle-icon');
        const toggleText = document.getElementById('subsidy-toggle-text');
        if (toggleIcon) {
            toggleIcon.className = 'fa-solid fa-plus';
        }
        if (toggleText) {
            toggleText.textContent = 'Créer une subvention';
        }
    }
    
    const sectorLabels = {
        economie: 'Économie',
        services_publics: 'Services Publics',
        justice: 'Justice',
        culture: 'Culture & Événementiel',
        sante: 'Santé',
        social: 'Affaires Sociales'
    };
    document.getElementById('gouv-my-sector').textContent = sectorLabels[sector] || sector.toUpperCase();

    const tbody = document.getElementById('gouv-sector-requests');
    if (!tbody) return;

    tbody.innerHTML = '';
    
    const requests = (currentGouvData && currentGouvData.sectorRequests) ? currentGouvData.sectorRequests.filter(r => r.sector === sector) : [];

    if (requests.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" style="text-align:center; color: var(--text-dim);">Aucune demande pour ce secteur.</td></tr>';
        return;
    }

    requests.forEach(req => {
        let actionHtml = '';
        if (req.status === 'pending') {
            actionHtml = `
                <button class="action-btn promote-btn" onclick="grantSectorRequest(${req.id})"><i class="fa-solid fa-check"></i> Accorder</button>
                <button class="action-btn fire-btn" onclick="refuseSectorRequest(${req.id})"><i class="fa-solid fa-xmark"></i> Refuser</button>
            `;
        } else if (req.status === 'granted') {
            actionHtml = `<span style="color:#2ecc71; font-weight:700;"><i class="fa-solid fa-check"></i> ACCORDÉ</span>`;
        } else if (req.status === 'refused') {
            actionHtml = `<span style="color:#e74c3c; font-weight:700;"><i class="fa-solid fa-xmark"></i> REFUSÉ</span>`;
        }

        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td style="font-weight: 600; color: white;">${req.entity}</td>
            <td>${req.object}</td>
            <td style="color: #2ecc71; font-weight: 700;">${formatMoney(req.amount)}</td>
            <td>${actionHtml}</td>
        `;
        tbody.appendChild(tr);
    });
}

function grantSectorRequest(requestId) {
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pop_management';
    fetch(`https://${resourceName}/grantSubsidy`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId: requestId })
    });
}

function refuseSectorRequest(requestId) {
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pop_management';
    fetch(`https://${resourceName}/refuseSubsidy`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestId: requestId })
    });
}

function addGouvProperty() {
    fetch(`https://${GetParentResourceName()}/notify`, {
        method: 'POST',
        body: JSON.stringify({ message: "Système de propriété en cours de développement." })
    });
}

function submitCustomSubsidy() {
    const entity = document.getElementById('new-subsidy-entity').value.trim();
    const job = document.getElementById('new-subsidy-job').value.trim();
    const amount = parseInt(document.getElementById('new-subsidy-amount').value);
    const object = document.getElementById('new-subsidy-object').value.trim();
    const sector = currentSectorSelected;

    if (!sector) {
        showGouvNotify("Veuillez sélectionner un secteur d'activité ci-dessus avant de verser.");
        return;
    }

    if (!entity || !job || isNaN(amount) || amount <= 0 || !object) {
        showGouvNotify("Veuillez remplir correctement tous les champs du formulaire.");
        return;
    }

    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pop_management';
    fetch(`https://${resourceName}/createAndGrantSubsidy`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            sector: sector,
            entity: entity,
            job: job,
            amount: amount,
            object: object
        })
    }).then(() => {
        document.getElementById('new-subsidy-entity').value = '';
        document.getElementById('new-subsidy-job').value = '';
        document.getElementById('new-subsidy-amount').value = '';
        document.getElementById('new-subsidy-object').value = '';
        
        const selectLabel = document.getElementById('selected-company-label');
        if (selectLabel) {
            selectLabel.textContent = 'Choisir une entreprise...';
            selectLabel.style.color = '#888';
        }
        
        // Hide form after successful submit
        const form = document.getElementById('custom-subsidy-form');
        form.style.display = 'none';
        
        const toggleIcon = document.getElementById('subsidy-toggle-icon');
        const toggleText = document.getElementById('subsidy-toggle-text');
        if (toggleIcon) {
            toggleIcon.className = 'fa-solid fa-plus';
        }
        if (toggleText) {
            toggleText.textContent = 'Créer une subvention';
        }
    });
}

function toggleCustomSubsidyForm() {
    const form = document.getElementById('custom-subsidy-form');
    const toggleIcon = document.getElementById('subsidy-toggle-icon');
    const toggleText = document.getElementById('subsidy-toggle-text');
    
    if (form.style.display === 'none' || form.style.display === '') {
        form.style.display = 'block';
        if (toggleIcon) {
            toggleIcon.className = 'fa-solid fa-minus';
        }
        if (toggleText) {
            toggleText.textContent = 'Masquer le formulaire';
        }
    } else {
        form.style.display = 'none';
        if (toggleIcon) {
            toggleIcon.className = 'fa-solid fa-plus';
        }
        if (toggleText) {
            toggleText.textContent = 'Créer une subvention';
        }
    }
}

function showGouvNotify(message) {
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pop_management';
    fetch(`https://${resourceName}/notify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: message })
    });
}

function toggleCompanyDropdown() {
    const optionsDiv = document.getElementById('subsidy-company-options');
    if (optionsDiv) {
        optionsDiv.style.display = (optionsDiv.style.display === 'none' || optionsDiv.style.display === '') ? 'block' : 'none';
    }
}

document.addEventListener('click', (event) => {
    const dropdown = document.getElementById('subsidy-company-options');
    const selectBtn = document.getElementById('subsidy-company-select');
    if (dropdown && selectBtn && !selectBtn.contains(event.target) && !dropdown.contains(event.target)) {
        dropdown.style.display = 'none';
    }
});

// =========================================================================
// APP "LIVRAISONS YOUTOOL" (job youtool)
// Liste unifiée des commandes (véhicules + colis), validation par employé.
// =========================================================================
let ytJobPolling = null;

function initYTJob() {
  refreshYTJobOrders();
  if (ytJobPolling) clearInterval(ytJobPolling);
  ytJobPolling = setInterval(() => {
    if (windowStates.ytjob && windowStates.ytjob.open && !windowStates.ytjob.minimized) {
      refreshYTJobOrders();
    }
  }, 4000);
}

function refreshYTJobOrders() {
  fetch(`https://${GetParentResourceName()}/getYTJobOrders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  }).then(r => r.json()).then(orders => {
    renderYTJobOrders(Array.isArray(orders) ? orders : []);
  }).catch(() => renderYTJobOrders([]));
}

function escapeHtmlYT(s) {
  return String(s == null ? '' : s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
}

function renderYTJobOrders(orders) {
  const tbody = document.getElementById('ytjob-orders');
  if (!tbody) return;

  if (!orders.length) {
    tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:var(--text-dim);">Aucune commande en cours</td></tr>';
    return;
  }

  // Les commandes à valider (pending) en premier
  orders.sort((a, b) => (a.status === b.status) ? 0 : (a.status === 'pending' ? -1 : 1));

  tbody.innerHTML = orders.map(o => {
    const typeLabel = o.type === 'vehicle' ? '🚗 Véhicule' : '📦 Colis';
    const article = (o.qty > 1 ? o.qty + 'x ' : '') + o.label;
    let statusHtml, actionHtml;
    if (o.status === 'pending') {
      statusHtml = '<span style="color:#f39c12; font-weight:600;">À valider</span>';
      actionHtml = `<button class="action-btn promote-btn" onclick="validateYTOrder('${o.type}', ${o.id})">Valider</button>`;
    } else {
      statusHtml = '<span style="color:#2ecc71; font-weight:600;">Validée — en livraison</span>';
      actionHtml = '<span style="color:var(--text-dim); font-size:11px;">Attente retrait client</span>';
    }
    return `<tr>
      <td>${typeLabel}</td>
      <td>${escapeHtmlYT(o.customer)}</td>
      <td>${escapeHtmlYT(article)}</td>
      <td>${statusHtml}</td>
      <td>${actionHtml}</td>
    </tr>`;
  }).join('');
}

function validateYTOrder(type, id) {
  fetch(`https://${GetParentResourceName()}/validateYTOrder`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ type: type, id: id })
  }).then(() => {
    setTimeout(refreshYTJobOrders, 300);
  }).catch(() => {});
}
// =============================
// DYNASTY 8 — MLO / COFFRE / CLÉ
// =============================

// Zone D8 active (envoyée par le client Lua)
let d8ActiveZoneId   = null;
let d8ActiveZoneName = null;

// Écouter les messages de zone D8 du client Lua
window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'd8ZoneEnter') {
        d8ActiveZoneId   = data.zoneId;
        d8ActiveZoneName = data.zoneName;
        // Raffraîchir la fiche si elle est ouverte sur cette propriété
        refreshD8ChestSection();
    } else if (data.action === 'd8ZoneExit') {
        d8ActiveZoneId   = null;
        d8ActiveZoneName = null;
        refreshD8ChestSection();
    }
});

// Sectionajoute au bas de la fiche bien D8 (bouton coffre + clé)
function renderD8ChestSection(propId, propName, chestData) {
    const container = document.getElementById('d8-chest-section');
    if (!container) return;

    const isInThisZone = (d8ActiveZoneId === propId);
    const hasChest     = chestData && chestData.chest;

    let html = `<div style="margin-top:30px; border-top:1px solid rgba(255,255,255,0.07); padding-top:20px;">`;
    html += `<div style="color:#888; font-size:11px; font-weight:700; letter-spacing:1px; margin-bottom:12px;">GESTION DU BIEN</div>`;

    // --- CLÉ ---
    html += `<div style="display:flex; gap:10px; margin-bottom:12px; align-items:center;">
        <button class="action-btn" style="flex:1; background:#1a3a4a; color:#4fc3f7; font-weight:700; border:1px solid #4fc3f7; border-radius:4px; padding:10px;" onclick="d8GenerateKey(${propId}, '${propName.replace(/'/g,"\\'")}')">
            <i class="fa-solid fa-key" style="margin-right:6px;"></i>GÉNÉRER UNE CLÉ
        </button>
    </div>`;

    // --- COFFRE ---
    if (hasChest) {
        html += `<div style="display:flex; gap:10px; align-items:center; background:rgba(0,0,0,0.2); padding:12px; border-radius:6px; margin-bottom:10px;">
            <i class="fa-solid fa-box-open" style="color:#2ecc71; font-size:18px;"></i>
            <div style="flex:1;">
                <div style="color:white; font-size:13px; font-weight:600;">${chestData.chest.name}</div>
                <div style="color:#555; font-size:10px;">${chestData.chest.x.toFixed(1)}, ${chestData.chest.y.toFixed(1)}, ${chestData.chest.z.toFixed(1)}</div>
            </div>
            <button class="action-btn" style="background:#c0392b; color:white; font-size:11px; padding:6px 14px; border-radius:4px;" onclick="d8RemoveChest(${propId})">
                <i class="fa-solid fa-trash"></i>
            </button>
        </div>`;
    } else {
        if (isInThisZone) {
            html += `<button class="action-btn" id="d8-place-chest-btn" style="width:100%; background:#0d5c2a; color:white; font-weight:700; border-radius:4px; padding:11px;" onclick="d8OpenPlaceChestModal(${propId})">
                <i class="fa-solid fa-box" style="margin-right:6px;"></i>PLACER UN COFFRE ICI
            </button>`;
        } else {
            html += `<div style="color:#444; font-size:12px; text-align:center; padding:10px; border:1px dashed #333; border-radius:4px;">
                <i class="fa-solid fa-location-dot" style="margin-right:6px;"></i>Entrez dans le MLO pour placer un coffre
            </div>`;
        }
    }

    html += `</div>`;

    // Modal saisie nom coffre (injecté une seule fois)
    if (!document.getElementById('d8-chest-modal')) {
        const modal = document.createElement('div');
        modal.id = 'd8-chest-modal';
        modal.style.cssText = 'display:none; position:fixed; inset:0; background:rgba(0,0,0,0.7); z-index:9000; align-items:center; justify-content:center;';
        modal.innerHTML = `
            <div style="background:#1e1e1e; border:1px solid #333; border-radius:10px; padding:30px; width:320px;">
                <div style="color:white; font-size:16px; font-weight:700; margin-bottom:20px;">Nommer le coffre</div>
                <input id="d8-chest-name-input" type="text" placeholder="Ex: Rangement salon" data-kbd-title="Nom du coffre"
                    style="width:100%; padding:10px; background:#111; border:1px solid #444; border-radius:6px; color:white; font-size:14px; box-sizing:border-box; margin-bottom:20px;">
                <div style="display:flex; gap:10px;">
                    <button class="action-btn" style="flex:1; background:#444;" onclick="document.getElementById('d8-chest-modal').style.display='none'">ANNULER</button>
                    <button class="action-btn" id="d8-chest-confirm-btn" style="flex:1; background:#0d5c2a; font-weight:700;">CONFIRMER</button>
                </div>
            </div>`;
        document.body.appendChild(modal);
    }

    container.innerHTML = html;
}

let d8PlacingForPropId = null;

function d8OpenPlaceChestModal(propId) {
    d8PlacingForPropId = propId;
    const modal = document.getElementById('d8-chest-modal');
    const input = document.getElementById('d8-chest-name-input');
    const btn   = document.getElementById('d8-chest-confirm-btn');
    if (!modal || !input || !btn) return;
    input.value = '';
    btn.onclick = () => d8ConfirmPlaceChest();
    modal.style.display = 'flex';
    setTimeout(() => input.focus(), 100);
}

function d8ConfirmPlaceChest() {
    const name  = (document.getElementById('d8-chest-name-input')?.value || 'Coffre').trim() || 'Coffre';
    const modal = document.getElementById('d8-chest-modal');
    if (modal) modal.style.display = 'none';
    fetch(`https://${GetParentResourceName()}/d8PlaceChest`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: name })
    }).then(r => r.json()).then(res => {
        if (res && !res.ok) console.warn('[D8] PlaceChest:', res.reason);
        // Rafraîchir la section après placement
        setTimeout(() => loadD8PropertyData(d8PlacingForPropId, null), 800);
    }).catch(() => {});
}

function d8RemoveChest(propId) {
    showConfirmModal('Supprimer le coffre', 'Supprimer le coffre de cette propriété ?', () => {
        fetch(`https://${GetParentResourceName()}/d8RemoveChest`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ propertyId: propId })
        }).then(() => setTimeout(() => loadD8PropertyData(propId, null), 600)).catch(() => {});
    });
}

function d8GenerateKey(propId, propName) {
    fetch(`https://${GetParentResourceName()}/d8GenerateKey`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ propertyId: propId, propertyName: propName })
    }).catch(() => {});
}

function loadD8PropertyData(propId, propName) {
    fetch(`https://${GetParentResourceName()}/d8GetPropertyData`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ propertyId: propId })
    }).then(r => r.json()).then(data => {
        renderD8ChestSection(propId, propName || '', data);
    }).catch(() => renderD8ChestSection(propId, propName || '', {}));
}

function refreshD8ChestSection() {
    // Chercher si une fiche est ouverte et contient le container
    const section = document.getElementById('d8-chest-section');
    if (!section || !section.dataset.propId) return;
    loadD8PropertyData(parseInt(section.dataset.propId), section.dataset.propName || '');
}

// -------------------------------------------------------------
// YOUTOOL 3D LABELS (inspired by pop_medexam)
// -------------------------------------------------------------
window.addEventListener('message', (event) => {
    if (event.data.action === 'ytDraw3DLabels') {
        const container = document.getElementById('yt-3d-labels');
        if (!container) return;
        
        let html = '';
        if (event.data.labels) {
            event.data.labels.forEach(l => {
                if (l.onScreen) {
                    html += `<div class="yt-label" style="left: ${l.x * 100}vw; top: ${l.y * 100}vh;">
                                <i class="fas fa-box"></i> VOTRE COMMANDE
                             </div>`;
                }
            });
        }
        container.innerHTML = html;
    }
});