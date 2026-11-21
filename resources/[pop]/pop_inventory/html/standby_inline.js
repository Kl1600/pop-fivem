// =============================================================================
//  Coffre / conteneur distant (ex standby_ui) — JS fusionne dans pop_inventory.
//  L'iframe a ete supprimee : ce script s'execute dans le meme document que app.js,
//  et tout est scope au sous-arbre #standby-root pour eviter les collisions avec
//  l'inventaire principal (CSS + DOM : data-equip-slot, slots, etc.).
// =============================================================================
(function () {
  'use strict';

  const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pop_inventory';

  // Wrapper qui contient TOUT le HTML du coffre. Tant qu'il n'existe pas, on attend.
  let root = document.getElementById('standby-root');
  if (!root) {
    // Le script peut etre charge avant que le DOM ne soit pret : on retente.
    document.addEventListener('DOMContentLoaded', () => {
      root = document.getElementById('standby-root');
      if (root) bootstrap();
    });
    return;
  }
  bootstrap();

  function bootstrap() {
    let currentConfig = {};
    let currentState = {};
    let currentContainerOrder = [];
    let currentSection = null;
    let lastStateString = null;
    let standbyContainerId = null;
    let dragState = null;
    let ghostEl = null;

    const isOpen = () => root.style.display && root.style.display !== 'none';

    // -- Messages depuis app.js (ex postMessage de l'iframe ; maintenant meme window) --
    window.addEventListener('message', function (event) {
      const data = event.data;
      if (!data || typeof data !== 'object') return;

      if (data.action === 'open') {
        root.style.display = 'flex';
        updateInventoryView();
      } else if (data.action === 'close') {
        root.style.display = 'none';
        fetch(`https://${RES}/saveState`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ state: currentState })
        });
        lastStateString = null;
      } else if (data.action === 'config') {
        currentConfig = data.items || {};
        if (data.containerOrder) currentContainerOrder = data.containerOrder;
        if (currentState && currentState.equipment) {
          refreshIconBar();
        }
      } else if (data.action === 'state') {
        const newStateString = JSON.stringify(data.state || {});
        if (newStateString === lastStateString) return; // anti-clignotement
        lastStateString = newStateString;

        currentState = data.state || {};
        if (currentState.standbyContainerId) {
          standbyContainerId = currentState.standbyContainerId;
        }
        refreshIconBar();
        updateInventoryView();
        renderLeftSlots();
        renderWeaponSlots();
      }
    });

    // Escape : ne fait QUE fermer le coffre, et seulement si le coffre est ouvert
    // (sinon ca interfererait avec l'inventaire principal).
    document.addEventListener('keydown', function (e) {
      if (e.key !== 'Escape') return;
      if (!isOpen()) return;
      fetch(`https://${RES}/standbyClose`, { method: 'POST' });
      fetch(`https://${RES}/saveState`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ state: currentState })
      });
    });

    // -- Helpers --
    const capacityMaxEl = root.querySelector('#inventory-capacity-max');

    const getItemAtSlot = (items, slotIdx) => {
      if (!items) return null;
      if (Array.isArray(items)) return items[slotIdx - 1] || null;
      return items[slotIdx] || items[slotIdx.toString()] || null;
    };

    const parsePx = (styleText, prop) => {
      const match = styleText.match(new RegExp(`${prop}:\\s*(\\d+)px`));
      return match ? Number.parseInt(match[1], 10) : null;
    };

    // CRITIQUE : tous les querySelectorAll sont scopes a `root` -> aucune collision
    // avec les 102 divs equivalents de l'inventaire principal.
    const allSlotDivs = Array.from(
      root.querySelectorAll('div[style*="background: rgba(245, 245, 245, 0.15)"][style*="width: 79px"][style*="height: 79px"]')
    ).map((el) => {
      const styleText = el.getAttribute('style') || '';
      return { el, left: parsePx(styleText, 'left') || 0, top: parsePx(styleText, 'top') || 0 };
    });

    const storageSlots = allSlotDivs
      .filter(({ el, left, top }) => left >= 660 && left <= 1200 && top >= 140 && top <= 520 && !el.dataset.equipSlot)
      .sort((a, b) => (a.top - b.top) || (a.left - b.left))
      .map(({ el }) => el);

    const leftSlots = allSlotDivs
      .filter(({ el }) => el.closest('#standby-items-grid'))
      .sort((a, b) => (a.top - b.top) || (a.left - b.left))
      .map(({ el }) => el);

    const weaponSlotEl = root.querySelector('div[data-equip-slot="weapon_long"]');
    const pistolSlotEl = root.querySelector('div[data-equip-slot="weapon_pistol"]');
    const tazerSlotEl = root.querySelector('div[data-equip-slot="weapon_tazer"]');

    const renderWeaponSlots = () => {
      const eq = currentState.equipment;

      if (weaponSlotEl) {
        weaponSlotEl.innerHTML = '';
        if (eq && eq.weapon_long) {
          const def = currentConfig[eq.weapon_long.defId];
          if (def) {
            const img = document.createElement('img');
            img.src = `https://cfx-nui-pop_inventory/html/${def.icon}`;
            img.style.width = '165px';
            img.style.height = '70px';
            img.style.objectFit = 'contain';
            img.style.pointerEvents = 'none';
            weaponSlotEl.appendChild(img);
          }
        }
      }
      if (pistolSlotEl) {
        pistolSlotEl.innerHTML = '';
        if (eq && eq.weapon_pistol) {
          const def = currentConfig[eq.weapon_pistol.defId];
          if (def) {
            const img = document.createElement('img');
            img.src = `https://cfx-nui-pop_inventory/html/${def.icon}`;
            img.style.width = '68px';
            img.style.height = '68px';
            img.style.objectFit = 'contain';
            img.style.pointerEvents = 'none';
            pistolSlotEl.appendChild(img);
          }
        }
      }
      if (tazerSlotEl) {
        tazerSlotEl.innerHTML = '';
        if (eq && eq.weapon_tazer) {
          const def = currentConfig[eq.weapon_tazer.defId];
          if (def) {
            const img = document.createElement('img');
            img.src = `https://cfx-nui-pop_inventory/html/${def.icon}`;
            img.style.width = '68px';
            img.style.height = '68px';
            img.style.objectFit = 'contain';
            img.style.pointerEvents = 'none';
            tazerSlotEl.appendChild(img);
          }
        }
      }
    };

    const refreshIconBar = () => {
      const iconBar = root.querySelector('.icon-bar');
      if (!iconBar) return;

      let sectionsToRender = [];

      if (currentState.containerOrder && currentState.containerOrder.length > 0) {
        sectionsToRender = currentState.containerOrder.map(entry => {
          const def = currentConfig[entry.defId];
          if (!def) return null;
          return {
            key: entry.defId,
            def: def,
            containerId: entry.containerId,
            stats: def.container || { slots: 10, maxWeight: 10 }
          };
        }).filter(s => s !== null);
      }

      if (sectionsToRender.length === 0 && currentState.equipment) {
        const order = currentContainerOrder.length ? currentContainerOrder : ['panta', 'hoddie', 'backpack', 'briefcase', 'wallet', 'kevlar', 'cardboard_box'];
        order.forEach(slot => {
          const eqItem = currentState.equipment[slot];
          if (eqItem && eqItem.containerId) {
            const defId = eqItem.defId;
            const def = currentConfig[defId];
            if (def && def.container) {
              sectionsToRender.push({
                key: slot,
                def: def,
                containerId: eqItem.containerId,
                stats: def.container
              });
            }
          }
        });
      }

      iconBar.innerHTML = '';

      sectionsToRender.forEach(sec => {
        const localSvgs = ['panta', 'hoddie', 'backpack', 'briefcase', 'wallet', 'kevlar', 'pants', 'trousers', 'cardboard_box', 'box'];
        const map = {
          'panta': 'panta', 'pants': 'panta',
          'hoddie': 'hoddie', 'hoodie': 'hoddie',
          'backpack': 'backpack', 'briefcase': 'briefcase',
          'wallet': 'wallet', 'kevlar': 'kevlar',
          'cardboard_box': 'box'
        };

        let iconSrc = `https://cfx-nui-pop_inventory/html/${sec.def.icon}`;
        if (map[sec.key] || localSvgs.includes(sec.key)) {
          const svg = map[sec.key] || sec.key;
          iconSrc = `svg/${svg}.svg`; // chemin relatif a index.html (= html/svg/)
        }

        const img = document.createElement('img');
        img.className = 'icon';
        img.src = iconSrc;
        img.title = (sec.def && sec.def.label) ? sec.def.label : sec.key;
        img.dataset.section = sec.key;
        img.dataset.containerId = sec.containerId;
        img.dataset.slots = sec.stats.slots;
        img.dataset.capacity = sec.stats.maxWeight;

        img.onerror = () => {
          if (iconSrc.includes('svg/')) img.src = `https://cfx-nui-pop_inventory/html/${sec.def.icon}`;
        };

        img.onclick = () => applySectionFromIcon(img);
        if (currentSection === sec.key) img.classList.add('active');
        iconBar.appendChild(img);
      });

      const hasActive = iconBar.querySelector('.icon.active');
      if (!hasActive && iconBar.firstChild) {
        applySectionFromIcon(iconBar.firstChild);
      } else if (hasActive) {
        applySectionFromIcon(hasActive);
      } else if (sectionsToRender.length === 0) {
        storageSlots.forEach(s => s.innerHTML = '');
        if (capacityMaxEl) capacityMaxEl.textContent = '/0kg';
      }
    };

    const updateInventoryView = () => {
      const activeIcon = root.querySelector('.icon-bar .icon.active');
      if (activeIcon) applySectionFromIcon(activeIcon);
    };

    const applySectionFromIcon = (icon) => {
      if (!icon) return;

      const allIcons = root.querySelectorAll('.icon-bar .icon');
      allIcons.forEach(el => el.classList.toggle('active', el === icon));

      currentSection = icon.dataset.section;
      const containerId = icon.dataset.containerId;
      const slotsInfos = parseInt(icon.dataset.slots, 10) || 0;
      const maxWeight = parseFloat(icon.dataset.capacity) || 0;

      const container = (containerId && currentState.containers) ? currentState.containers[containerId] : null;

      storageSlots.forEach((slot, index) => {
        const isDisabled = index >= slotsInfos;
        slot.style.display = '';
        slot.style.opacity = isDisabled ? '0.35' : '';
        slot.dataset.disabled = isDisabled ? 'true' : 'false';
        slot.style.pointerEvents = isDisabled ? 'none' : 'auto';
        slot.innerHTML = '';

        if (!isDisabled && container && container.items) {
          const slotIdx = index + 1;
          const item = getItemAtSlot(container.items, slotIdx);
          if (item) {
            const def = currentConfig[item.defId];
            if (def) {
              const img = document.createElement('img');
              img.src = `https://cfx-nui-pop_inventory/html/${def.icon}`;
              img.style.width = '100%';
              img.style.height = '100%';
              img.style.objectFit = 'contain';
              img.style.position = 'absolute';
              img.style.top = '0';
              img.style.left = '0';
              slot.appendChild(img);
              if (item.qty > 1) {
                const qty = document.createElement('span');
                qty.innerText = `x${item.qty}`;
                qty.style.position = 'absolute';
                qty.style.bottom = '4px';
                qty.style.right = '6px';
                qty.style.color = 'white';
                qty.style.fontSize = '12px';
                qty.style.fontWeight = 'bold';
                qty.style.textShadow = '1px 1px 0 #000';
                qty.style.pointerEvents = 'none';
                slot.appendChild(qty);
              }
            }
          }
        }
      });

      if (capacityMaxEl && Number.isFinite(maxWeight)) {
        let currentW = (container && container.weight) ? container.weight.toFixed(1) : '0.0';
        const currentSpan = capacityMaxEl.previousElementSibling;
        if (currentSpan) currentSpan.textContent = currentW;
        capacityMaxEl.textContent = `/${maxWeight}kg`;
      }
    };

    const renderItemInSlot = (slot, item) => {
      slot.innerHTML = '';
      if (!item) return;
      const def = currentConfig[item.defId];
      if (!def) return;
      const img = document.createElement('img');
      img.src = `https://cfx-nui-pop_inventory/html/${def.icon}`;
      img.style.width = '100%';
      img.style.height = '100%';
      img.style.objectFit = 'contain';
      img.style.position = 'absolute';
      img.style.top = '0';
      img.style.left = '0';
      img.style.pointerEvents = 'none';
      slot.appendChild(img);
      if (item.qty > 1) {
        const qty = document.createElement('span');
        qty.innerText = `x${item.qty}`;
        qty.style.position = 'absolute';
        qty.style.bottom = '4px';
        qty.style.right = '6px';
        qty.style.color = 'white';
        qty.style.fontSize = '12px';
        qty.style.fontWeight = 'bold';
        qty.style.textShadow = '1px 1px 0 #000';
        qty.style.pointerEvents = 'none';
        slot.appendChild(qty);
      }
    };

    const renderLeftSlots = () => {
      const container = currentState.standbyContainer;
      const maxSlots = container ? (container.slots || 100) : 100;
      const weightEl = root.querySelector('div[style*="left: 0px"][style*="top: 60px"] span:first-child');
      const maxWeightEl = root.querySelector('div[style*="left: 0px"][style*="top: 60px"] span:nth-child(2)');
      leftSlots.forEach((slot, index) => {
        const isDisabled = index >= maxSlots;
        slot.style.display = '';
        slot.style.opacity = isDisabled ? '0.35' : '';
        slot.dataset.disabled = isDisabled ? 'true' : 'false';
        slot.style.pointerEvents = isDisabled ? 'none' : 'auto';
        slot.innerHTML = '';
        if (!isDisabled && container && container.items) {
          const slotIdx = index + 1;
          const item = getItemAtSlot(container.items, slotIdx);
          if (item) renderItemInSlot(slot, item);
        }
      });
      if (container && weightEl && maxWeightEl) {
        weightEl.textContent = container.weight ? container.weight.toFixed(1) : '0.0';
        maxWeightEl.textContent = `/${container.maxWeight || 50}kg`;
      }
    };

    const findSlotItem = (slotEl, side) => {
      if (side === 'right') {
        const activeIcon = root.querySelector('.icon-bar .icon.active');
        if (!activeIcon) return null;
        const containerId = activeIcon.dataset.containerId;
        const container = (containerId && currentState.containers) ? currentState.containers[containerId] : null;
        if (!container || !container.items) return null;
        const slotIdx = storageSlots.indexOf(slotEl) + 1;
        const item = getItemAtSlot(container.items, slotIdx);
        return item ? { item, containerId, slotIdx } : null;
      } else if (side === 'left') {
        if (!standbyContainerId || !currentState.standbyContainer || !currentState.standbyContainer.items) return null;
        const slotIdx = leftSlots.indexOf(slotEl) + 1;
        const item = getItemAtSlot(currentState.standbyContainer.items, slotIdx);
        return item ? { item, containerId: standbyContainerId, slotIdx } : null;
      } else if (side === 'equipment') {
        const equipSlot = slotEl.dataset.equipSlot;
        const item = currentState.equipment ? currentState.equipment[equipSlot] : null;
        return item ? { item, equipSlot } : null;
      }
    };

    const getContainerById = (containerId) => {
      if (containerId && containerId === standbyContainerId) return currentState.standbyContainer;
      return (currentState.containers && currentState.containers[containerId]) || null;
    };
    const firstFreeSlot = (containerId, maxSlots) => {
      const container = getContainerById(containerId);
      const items = (container && container.items) ? container.items : {};
      for (let i = 1; i <= (maxSlots || 0); i++) {
        if (!getItemAtSlot(items, i)) return i;
      }
      return -1;
    };
    const quickTransfer = (slotEl, side) => {
      const info = findSlotItem(slotEl, side);
      if (!info || info.equipSlot) return;
      let toContainerId, toMax;
      if (side === 'left') {
        const activeIcon = root.querySelector('.icon-bar .icon.active');
        if (!activeIcon) return;
        toContainerId = activeIcon.dataset.containerId;
        toMax = parseInt(activeIcon.dataset.slots, 10) || 0;
      } else if (side === 'right') {
        toContainerId = standbyContainerId;
        toMax = (currentState.standbyContainer && currentState.standbyContainer.slots) || 100;
      } else {
        return;
      }
      if (!toContainerId) return;
      const toSlot = firstFreeSlot(toContainerId, toMax);
      if (toSlot < 0) return;
      fetch(`https://${RES}/standbyAction`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: 'move',
          fromContainerId: info.containerId,
          fromSlot: info.slotIdx,
          toContainerId: toContainerId,
          toSlot: toSlot
        })
      });
    };

    const setupDrag = (slotEl, side) => {
      slotEl.style.pointerEvents = 'auto';
      slotEl.addEventListener('contextmenu', (e) => {
        e.preventDefault();
        if (side === 'left' || side === 'right') quickTransfer(slotEl, side);
      });
      slotEl.addEventListener('mousedown', (e) => {
        if (e.button !== 0) return;
        const info = findSlotItem(slotEl, side);
        if (!info) return;
        e.preventDefault();
        dragState = {
          fromSide: side,
          fromContainerId: info.containerId,
          fromSlot: info.slotIdx,
          equipSlot: info.equipSlot,
          item: info.item
        };
        ghostEl = document.createElement('div');
        ghostEl.style.position = 'fixed';
        ghostEl.style.width = '74px';
        ghostEl.style.height = '74px';
        ghostEl.style.pointerEvents = 'none';
        ghostEl.style.zIndex = '9999';
        ghostEl.style.opacity = '0.8';
        const def = currentConfig[info.item.defId];
        if (def) {
          const img = document.createElement('img');
          img.src = `https://cfx-nui-pop_inventory/html/${def.icon}`;
          img.style.width = '100%';
          img.style.height = '100%';
          img.style.objectFit = 'contain';
          ghostEl.appendChild(img);
        }
        ghostEl.style.left = (e.clientX - 37) + 'px';
        ghostEl.style.top = (e.clientY - 37) + 'px';
        document.body.appendChild(ghostEl);
      });
    };

    document.addEventListener('mousemove', (e) => {
      if (ghostEl) {
        ghostEl.style.left = (e.clientX - 37) + 'px';
        ghostEl.style.top = (e.clientY - 37) + 'px';
      }
    });

    document.addEventListener('mouseup', (e) => {
      if (!dragState) return;
      if (ghostEl) { ghostEl.remove(); ghostEl = null; }

      const targetEl = document.elementFromPoint(e.clientX, e.clientY);
      let toSide = null;
      let toSlotIdx = -1;
      let toEquipSlot = null;

      // Pour eviter les collisions avec les data-equip-slot de l'inventaire principal,
      // on ne reconnait un drop sur 'equipment' QUE si la cible est dans #standby-root.
      const leftIdx = leftSlots.indexOf(targetEl);
      const rightIdx = storageSlots.indexOf(targetEl);
      const equipTarget = (targetEl && root.contains(targetEl)) ? targetEl.closest('[data-equip-slot]') : null;

      if (leftIdx >= 0) { toSide = 'left'; toSlotIdx = leftIdx + 1; }
      else if (rightIdx >= 0) { toSide = 'right'; toSlotIdx = rightIdx + 1; }
      else if (equipTarget && root.contains(equipTarget)) { toSide = 'equipment'; toEquipSlot = equipTarget.dataset.equipSlot; }

      if (toSide) {
        if ((toSide === 'left' || toSide === 'right') && toSlotIdx <= 0) {
          dragState = null;
          return;
        }

        let toContainerId;
        if (toSide === 'left') {
          toContainerId = standbyContainerId;
        } else if (toSide === 'right') {
          const activeIcon = root.querySelector('.icon-bar .icon.active');
          toContainerId = activeIcon ? activeIcon.dataset.containerId : (currentState.activeContainerId || null);
        }

        if (dragState.fromSide === 'equipment' && toSide !== 'equipment') {
          fetch(`https://${RES}/standbyAction`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              type: 'unequipToSlot',
              equipSlot: dragState.equipSlot,
              toContainerId: toContainerId,
              toSlot: toSlotIdx
            })
          });
        } else if (toSide === 'equipment' && dragState.fromSide !== 'equipment') {
          fetch(`https://${RES}/standbyAction`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              type: 'equip',
              fromContainerId: dragState.fromContainerId,
              fromSlot: dragState.fromSlot
            })
          });
        } else if (toSide !== 'equipment' && dragState.fromSide !== 'equipment') {
          if (toContainerId && (dragState.fromContainerId !== toContainerId || dragState.fromSlot !== toSlotIdx)) {
            fetch(`https://${RES}/standbyAction`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                type: 'move',
                fromContainerId: dragState.fromContainerId,
                fromSlot: dragState.fromSlot,
                toContainerId: toContainerId,
                toSlot: toSlotIdx
              })
            });
          }
        }
      }
      dragState = null;
    });

    // CRITIQUE : ces queries sont scopees a `root` -> on n'attache PAS de drag aux
    // [data-equip-slot] de l'inventaire principal (qui a sa propre logique dans app.js).
    storageSlots.forEach(s => setupDrag(s, 'right'));
    leftSlots.forEach(s => setupDrag(s, 'left'));
    root.querySelectorAll('[data-equip-slot]').forEach(el => setupDrag(el, 'equipment'));
  }
})();
