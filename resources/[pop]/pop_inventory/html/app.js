(() => {
  const state = {
    containers: {},
    equipment: {},
    containerOrder: [],
    activeContainerId: null,
    activeContainerIsGround: false,
    ground: null,
  };

  let activeContainerId = null;
  let selected = null;
  let dragState = null;
  let pendingState = null;
  let dragPreview = null;
  let pointerDrag = null;
  let suppressClick = false;
  let draggingToGive = false;
  let weaponAttachmentsConfig = {};
  let attachmentItemsConfig = {};
  let activeAttachmentContext = null;
  const navStack = [];

  const openPanel = (panelId, options = {}) => {
    const panels = [
      'clothes-side', 'torso-grid-side', 'admin-hub-side', 
      'admin-items-side', 'admin-jobs-side', 'admin-weather-side', 'admin-vehicles-side', 'craft-side', 'shop-side', 'paint-side'
    ];
    
    const currentActive = panels.find(p => {
      const el = document.getElementById(p);
      return el && el.style.display === 'block';
    });

    if (currentActive && currentActive !== panelId && !options.isBack) {
      if (navStack[navStack.length - 1] !== currentActive) {
        navStack.push(currentActive);
      }
    }

    panels.forEach(p => {
      const el = document.getElementById(p);
      if (el) el.style.display = (p === panelId) ? 'block' : 'none';
    });
  };

  const goBack = () => {
    if (navStack.length > 0) {
      const prevPanel = navStack.pop();
      openPanel(prevPanel, { isBack: true });
    } else {
      openPanel('clothes-side', { isBack: true });
    }
  };

  const POINTER_DRAG_THRESHOLD = 4;

  const slotMap = { container: [], ground: [] };
  const iconMap = new Map();
  const iconMapTarget = new Map();
  const equipSlots = new Map();

  const capacityCurrentEl = document.getElementById('inventory-capacity-current');
  const capacityMaxEl = document.getElementById('inventory-capacity-max');
  const totalCurrentEl = document.getElementById('inventory-total-current');
  const totalMaxEl = document.getElementById('inventory-total-max');

  const parsePx = (styleText, prop) => {
    const match = styleText.match(new RegExp(`${prop}:\\s*(\\d+)px`));
    return match ? Number.parseInt(match[1], 10) : null;
  };

  const findEmptySlot = (container) => {
    if (!container) {
      return null;
    }
    const total = container.slots || 0;
    for (let i = 1; i <= total; i += 1) {
      if (!container.items || !container.items[i]) {
        return i;
      }
    }
    return null;
  };

  const ensureGroundContainer = () => {
    const slots = slotMap.ground.length || 0;
    if (!state.ground) {
      state.ground = {
        id: '__local_ground__',
        defId: 'ground',
        label: 'Ground',
        slots,
        maxWeight: 0,
        weight: 0,
        items: {},
      };
      return;
    }
    if (!state.ground.items) {
      state.ground.items = {};
    }
    if (!state.ground.slots) {
      state.ground.slots = slots;
    }
  };

  const setVisible = (visible) => {
    if (!document.body) return;
    document.body.style.display = visible ? 'flex' : 'none';

    if (!visible) {
      navStack.length = 0; // Clear stack on close
    }

    // Reset panels to default state to avoid overlaps
    openPanel('clothes-side', { isBack: true });
  };

  const postAction = (payload) => {
    fetch(`https://${GetParentResourceName()}/action`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload),
    });
  };

  const showInputModal = (title, defaultValue, onConfirm, inputType = 'number') => {
    const modal = document.getElementById('inputModal');
    const titleEl = document.getElementById('inputModalTitle');
    const inputEl = document.getElementById('inputModalInput');
    const confirmBtn = document.getElementById('inputModalConfirm');
    const cancelBtn = document.getElementById('inputModalCancel');

    inputEl.type = inputType;
    titleEl.textContent = title;
    inputEl.value = defaultValue;
    modal.classList.add('active');
    inputEl.focus();
    inputEl.select();

    const handleConfirm = () => {
      if (inputType === 'number') {
        const value = Number.parseInt(inputEl.value, 10);
        if (Number.isFinite(value) && value > 0) {
          onConfirm(value);
        }
      } else {
        const value = inputEl.value.trim();
        if (value.length > 0) {
          onConfirm(value.substring(0, 32)); // Limite à 32 caractères
        }
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
      confirmBtn.removeEventListener('click', handleConfirm);
      cancelBtn.removeEventListener('click', handleCancel);
      inputEl.removeEventListener('keydown', handleKeyDown);
    };

    confirmBtn.addEventListener('click', handleConfirm);
    cancelBtn.addEventListener('click', handleCancel);
    inputEl.addEventListener('keydown', handleKeyDown);
  };

  window.showInputModal = showInputModal;

  const clearSelection = () => {
    if (selected && selected.el) {
      selected.el.classList.remove('inv-selected');
    }
    selected = null;
  };

  const resolveEquipSlotEl = (event) => {
    const target = event && (event.currentTarget || event.target);
    if (!target) {
      return null;
    }
    if (target.dataset && target.dataset.equipSlot) {
      return target;
    }
    if (target.closest) {
      return target.closest('[data-equip-slot]');
    }
    return null;
  };

  const resolveEquipPayload = (event) => {
    const slotEl = resolveEquipSlotEl(event);
    if (!slotEl) {
      return null;
    }
    const slot = slotEl.dataset.equipSlot;
    if (!slot || !state.equipment[slot]) {
      return null;
    }
    return { fromType: 'equipment', slotIndex: slot, equipSlot: slot, item: state.equipment[slot] };
  };

  const queuePointerDrag = (payload, event) => {
    if (!event || event.button !== 0) {
      return;
    }
    if (dragState) {
      return;
    }
    pointerDrag = {
      payload,
      startX: event.clientX,
      startY: event.clientY,
      active: false,
    };
  };

  const startEquipDrag = (event) => {
    if (pointerDrag && pointerDrag.active) {
      event.preventDefault();
      return;
    }
    const payload = resolveEquipPayload(event);
    if (!payload) {
      event.preventDefault();
      return;
    }
    beginDrag(payload, event);
  };

  const queueEquipPointerDrag = (event) => {
    const payload = resolveEquipPayload(event);
    if (!payload) {
      return;
    }
    queuePointerDrag(payload, event);
  };

  const wireEquipMedia = (node) => {
    if (!node || node.dataset.equipWired === 'true') {
      return;
    }
    node.dataset.equipWired = 'true';
    const img = node.querySelector('img');
    if (img) {
      img.draggable = false;
    }
    node.setAttribute('draggable', 'true');
    node.addEventListener('dragstart', startEquipDrag);
    node.addEventListener('drag', (event) => {
      updateDragPreview(event);
    });
    node.addEventListener('dragend', endDrag);
    node.addEventListener('mousedown', queueEquipPointerDrag);
    node.addEventListener('contextmenu', handleEquipContext);
  };

  const classifySlots = () => {
    // 1. Ground slots are divs inside #ground-items-grid
    const groundSlots = Array.from(document.querySelectorAll('#ground-items-grid div'));

    // 2. Container slots are absolute positioned divs inside #full-ui-wrapper in the main inventory coords area
    const containerSlots = Array.from(document.querySelectorAll('#full-ui-wrapper div'))
      .map((el) => {
        const styleText = el.getAttribute('style') || '';
        return {
          el,
          left: parsePx(styleText, 'left'),
          top: parsePx(styleText, 'top'),
        };
      })
      .filter(({ left, top }) => left !== null && top !== null && left >= 379 && left <= 851 && top >= 88 && top <= 450)
      .sort((a, b) => (a.top - b.top) || (a.left - b.left))
      .map(({ el }) => el);

    slotMap.ground = groundSlots.map((el, index) => {
      el.dataset.zone = 'ground';
      el.dataset.slotIndex = (index + 1).toString();
      return el;
    });

    slotMap.container = containerSlots.map((el, index) => {
      el.dataset.zone = 'container';
      el.dataset.slotIndex = (index + 1).toString();
      return el;
    });
  };

  const initEquipSlots = () => {
    const slotDivs = Array.from(
      document.querySelectorAll('div[data-equip-slot]')
    );

    slotDivs.forEach((el) => {
      const name = (el.dataset.equipSlot || '').toLowerCase();
      if (!name) {
        return;
      }
      el.classList.add('equip-slot');
      equipSlots.set(name, el);
    });
  };

  // ── Soulignement (onglet) sous la catégorie ACTIVE (cliquée), posé sur la ligne ──
  const iconUnderline = document.getElementById('inv-icon-underline');
  const uiWrapper = document.getElementById('full-ui-wrapper');
  // Position horizontale absolue d'une icône dans le wrapper (somme des offsets).
  const absLeftInWrapper = (el) => {
    let left = 0;
    while (el && el !== uiWrapper) {
      left += el.offsetLeft;
      el = el.offsetParent;
    }
    return left;
  };
  const resetUnderline = () => {
    if (!iconUnderline) return;
    const active = document.querySelector('.icon-bar .icon.active:not(.locked)');
    if (active) {
      const OVER = 0; // pas de débordement — largeur exacte de l'icône
      iconUnderline.style.left = (absLeftInWrapper(active) - OVER) + 'px';
      iconUnderline.style.width = (active.offsetWidth + OVER * 2) + 'px';
      iconUnderline.style.opacity = '1';
    } else {
      iconUnderline.style.opacity = '0';
    }
  };

  const initIcons = () => {
    const icons = Array.from(document.querySelectorAll('.icon-bar .icon[data-section]'));
    icons.forEach((icon) => {
      const section = (icon.dataset.section || '').toLowerCase();
      if (section) {
        iconMap.set(section, icon);
      }
      icon.addEventListener('click', () => {
        if (icon.classList.contains('locked')) {
          return;
        }
        activeContainerId = icon.dataset.containerId || null;
        render();
      });

      icon.addEventListener('dragenter', (event) => {
        if (!dragState) return;
        event.preventDefault();
        if (icon.classList.contains('locked')) return;
        const targetContainerId = icon.dataset.containerId;
        if (targetContainerId && activeContainerId !== targetContainerId) {
          activeContainerId = targetContainerId;
          render();
        }
      });

      icon.addEventListener('dragover', (event) => {
        if (!dragState) return;
        event.preventDefault();
      });
    });

    const targetIcons = Array.from(document.querySelectorAll('.target-icon-bar .icon[data-section]'));
    targetIcons.forEach((icon) => {
      const section = (icon.dataset.section || '').toLowerCase();
      if (section) {
        iconMapTarget.set(section, icon);
      }
      icon.addEventListener('click', () => {
        if (icon.classList.contains('locked')) {
          return;
        }
        activeContainerId = icon.dataset.containerId || null;
        render();
      });
    });
  };

  const applyState = (nextState) => {
    clearSelection();

    const activeChanged = (nextState.activeContainerId !== state.activeContainerId);

    state.containers = nextState.containers || {};
    state.equipment = nextState.equipment || {};
    state.containerOrder = nextState.containerOrder || [];
    state.activeContainerId = nextState.activeContainerId || null;
    state.activeContainerIsGround = nextState.activeContainerIsGround || false;
    state.paintStock = nextState.paintStock || {};

    // Normaliser les items des containers (tableau → objet)
    Object.keys(state.containers).forEach((containerId) => {
      const container = state.containers[containerId];
      if (container && Array.isArray(container.items)) {
        const normalizedItems = {};
        container.items.forEach((item, index) => {
          normalizedItems[index + 1] = item;
        });
        container.items = normalizedItems;
      }
    });

    // Normaliser state.ground.items si c'est un tableau
    if (nextState.ground) {
      if (Array.isArray(nextState.ground.items)) {
        const normalizedItems = {};
        nextState.ground.items.forEach((item, index) => {
          normalizedItems[index + 1] = item;
        });
        nextState.ground.items = normalizedItems;
      }
      state.ground = nextState.ground;
    } else {
      state.ground = null;
    }

    if (activeChanged || !activeContainerId || (activeContainerId && !state.containers[activeContainerId] && !(state.ground && state.ground.id === activeContainerId))) {
      activeContainerId = state.activeContainerId || (state.containerOrder[0] && state.containerOrder[0].containerId) || null;
    }

    render();
  };

  const applyDragVisuals = () => {
    iconMap.forEach((icon) => icon.classList.remove('drag-hidden'));
    slotMap.container.forEach((slot) => slot.classList.remove('drag-disabled'));
    equipSlots.forEach((slotEl) => slotEl.classList.remove('dragging'));
    if (!dragState || dragState.fromType !== 'equipment') {
      return;
    }
    const icon = iconMap.get(dragState.equipSlot);
    if (icon) {
      icon.classList.add('drag-hidden');
    }
    const equipSlotEl = equipSlots.get(dragState.equipSlot);
    if (equipSlotEl) {
      equipSlotEl.classList.add('dragging');
    }
    const currentId = activeContainerId || state.activeContainerId;
    const entry = state.containerOrder.find((item) => item.defId === dragState.equipSlot);
    if (entry && currentId && currentId === entry.containerId) {
      slotMap.container.forEach((slot) => slot.classList.add('drag-disabled'));
    }
  };

  const beginDrag = (payload, event, isPointer = false) => {
    dragState = { ...payload, pointer: isPointer, originalContainerId: activeContainerId };
    if (!isPointer) {
      pointerDrag = null;
    } else if (pointerDrag) {
      pointerDrag.active = true;
    }
    createDragPreview(payload.item, event);
    if (event && event.dataTransfer) {
      event.dataTransfer.setData('text/plain', 'drag');
      event.dataTransfer.effectAllowed = 'move';
    }
    if (document.body) {
      document.body.classList.add('dragging');
    }
    applyDragVisuals();
  };

  const endDrag = (e) => {
    if (dragState) {
      const wasDraggingToGive = draggingToGive;
      const currentDrag = { ...dragState };

      if (!dragState.dropped && dragState.originalContainerId && activeContainerId !== dragState.originalContainerId) {
        activeContainerId = dragState.originalContainerId;
        render();
      }
      dragState = null;
      if (document.body) {
        document.body.classList.remove('dragging');
      }
      removeDragPreview();
      applyDragVisuals();

      const wrapper = document.getElementById('full-ui-wrapper');
      if (wrapper) {
        wrapper.style.visibility = 'visible';
        wrapper.style.opacity = '1';
      }
      document.body.style.backgroundColor = '';
      draggingToGive = false;

      if (wasDraggingToGive) {
        fetch(`https://${GetParentResourceName()}/confirmDraggingOut`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            fromContainerId: currentDrag.containerId || currentDrag.slotIndex,
            fromSlot: currentDrag.slotIndex,
            item: currentDrag.item,
            fromType: currentDrag.fromType
          })
        }).then(resp => resp.json()).then(data => {
          if (data && data.success) {
            postAction({ type: 'close' });
          } else {
            if (wrapper) {
              wrapper.style.visibility = 'visible';
              wrapper.style.opacity = '1';
            }
          }
        });
      } else {
        fetch(`https://${GetParentResourceName()}/stopDraggingOut`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({})
        });
      }
    }
    if (pointerDrag) {
      pointerDrag = null;
    }
  };

  const buildItemNode = (item, context) => {
    const node = document.createElement('div');
    node.className = 'inv-item';
    node.draggable = true;
    node.title = (item.meta && item.meta.description) || item.description || item.label || item.defId;

    if (item.gradientColor && context.zone !== 'ground') {
      node.style.setProperty('--gradient-color', item.gradientColor);
    }

    if (item.icon) {
      const img = document.createElement('img');
      img.src = item.icon;
      img.alt = item.label || item.defId;
      img.draggable = false;
      if (item.icon.endsWith('.svg')) {
        img.classList.add('inv-icon-svg');
      }
      node.appendChild(img);
    } else {
      node.textContent = item.label || item.defId;
    }

    if (item.qty && item.qty > 1) {
      const qty = document.createElement('div');
      qty.className = 'inv-qty';
      qty.textContent = item.qty;
      node.appendChild(qty);
    }

    const payload = {
      fromType: context.zone,
      containerId: context.containerId,
      slotIndex: context.slotIndex,
      equipSlot: item.equipSlot,
      item,
    };

    node.addEventListener('dragstart', (event) => {
      if (pointerDrag && pointerDrag.active) {
        event.preventDefault();
        return;
      }
      beginDrag(payload, event);
    });

    node.addEventListener('mousedown', (event) => {
      queuePointerDrag(payload, event);
    });

    node.addEventListener('drag', (event) => {
      updateDragPreview(event);
    });

    node.addEventListener('dragend', () => {
      endDrag();
    });

    return node;
  };

  const clearSlotItem = (slot) => {
    slot.classList.remove('has-item');
    slot.dataset.itemId = '';
    const existing = slot.querySelector('.inv-item');
    if (existing) {
      existing.remove();
    }
  };

  const isLongWeaponItem = (item) => {
    if (!item) return false;
    const res = (item.equipSlot === 'weapon_long' || 
                 (Array.isArray(item.tags) && item.tags.indexOf('weapon_long') >= 0) || 
                 item.defId === 'pistolet_peinture' || 
                 item.defId === 'smg' || 
                 item.defId === 'carabine');
    console.log('[POP_INVENTORY] isLongWeaponItem item=' + item.defId + ' result=' + res);
    return res;
  };

  const renderSlots = (slots, container) => {
    // Premier passage : réinitialiser l'affichage de toutes les cases
    slots.forEach((slotEl) => {
      slotEl.style.width = '79px';
      slotEl.style.height = '80px';
      slotEl.style.gridColumn = '';
      slotEl.style.gridRow = '';
      slotEl.style.display = '';
      slotEl.style.pointerEvents = 'auto';
      slotEl.dataset.covered = 'false';
    });

    const coveredSlots = new Set();
    const zone = slots[0] ? slots[0].dataset.zone : 'container';
    const COLS = zone === 'ground' ? 3 : 6;

    slots.forEach((slotEl, index) => {
      const slotIndex = Number.parseInt(slotEl.dataset.slotIndex, 10);
      
      if (coveredSlots.has(index)) {
        clearSlotItem(slotEl);
        slotEl.style.display = 'none';
        slotEl.style.pointerEvents = 'none';
        slotEl.dataset.covered = 'true';
        return;
      }

      clearSlotItem(slotEl);
      
      const effectiveSlots = zone === 'ground'
        ? slotMap.ground.length
        : (container && container.slots ? container.slots : 0);
        
      if (!container || slotIndex > effectiveSlots) {
        slotEl.dataset.disabled = zone === 'ground' ? 'false' : 'true';
        slotEl.style.display = '';
        slotEl.style.pointerEvents = zone === 'ground' ? 'auto' : 'none';
        return;
      }
      
      slotEl.dataset.disabled = 'false';
      slotEl.style.display = '';
      slotEl.style.pointerEvents = 'auto';
      
      const item = container.items && container.items[slotIndex];
      if (item) {
        const isDouble = isLongWeaponItem(item);
        const isStretcher = item.defId === 'brancard';
        
        if (isStretcher) {
          const cellWidth = zone === 'ground' ? 79 : 82;
          const cellHeight = 80;
          const gapX = zone === 'ground' ? 10 : 13;
          const gapY = zone === 'ground' ? 12 : 14;
          
          slotEl.style.width = (cellWidth * 3 + gapX * 2) + 'px';
          slotEl.style.height = (cellHeight * 4 + gapY * 3) + 'px';
          slotEl.style.gridColumn = 'span 3';
          slotEl.style.gridRow = 'span 4';
          
          coveredSlots.add(index + 1);
          coveredSlots.add(index + 2);
          
          coveredSlots.add(index + COLS);
          coveredSlots.add(index + COLS + 1);
          coveredSlots.add(index + COLS + 2);
          
          coveredSlots.add(index + COLS * 2);
          coveredSlots.add(index + COLS * 2 + 1);
          coveredSlots.add(index + COLS * 2 + 2);
          
          coveredSlots.add(index + COLS * 3);
          coveredSlots.add(index + COLS * 3 + 1);
          coveredSlots.add(index + COLS * 3 + 2);
        } else if (isDouble) {
          const width = zone === 'ground' ? '168px' : '173px';
          slotEl.style.width = width;
          slotEl.style.height = '80px';
          if (zone === 'ground') {
            slotEl.style.gridColumn = 'span 2';
          }
          coveredSlots.add(index + 1);
        } else {
          slotEl.style.width = '79px';
          slotEl.style.height = '80px';
          if (zone === 'ground') {
            slotEl.style.gridColumn = '';
          }
        }

        slotEl.dataset.itemId = item.id;
        slotEl.classList.add('has-item');
        slotEl.appendChild(
          buildItemNode(item, {
            zone,
            containerId: container.id,
            slotIndex,
          })
        );
      } else {
        slotEl.style.width = '79px';
        slotEl.style.height = '80px';
      }
    });
  };

  const getContainerByZone = (zone) => {
    if (zone === 'ground') {
      return state.ground;
    }
    if (zone === 'container') {
      const id = activeContainerId || state.activeContainerId;
      if (state.containers[id]) {
        return state.containers[id];
      }
      if (state.ground && state.ground.id === id) {
        return state.ground;
      }
      return null;
    }
    return null;
  };

  const handleSlotClick = (event) => {
    const slotEl = event.currentTarget;
    const zone = slotEl.dataset.zone;
    const slotIndex = Number.parseInt(slotEl.dataset.slotIndex, 10);
    if (selected && zone === 'ground' && selected.zone === 'container') {
      const fromContainer = state.containers && state.containers[selected.containerId];
      const item = fromContainer && fromContainer.items && fromContainer.items[selected.slotIndex];
      postAction({ type: 'drop', containerId: selected.containerId, slot: selected.slotIndex });
      clearSelection();
      return;
    }

    const container = getContainerByZone(zone);
    if (!container) {
      return;
    }

    const item = container.items && container.items[slotIndex];
    if (!selected) {
      if (item) {
        selected = { el: slotEl, zone, slotIndex, containerId: container.id };
        slotEl.classList.add('inv-selected');
      }
      return;
    }

    if (selected.el === slotEl) {
      clearSelection();
      return;
    }

    const from = selected;
    const to = { zone, slotIndex, containerId: container.id };

    if (from.zone === 'ground' && to.zone === 'container') {
      postAction({ type: 'pickup', slot: from.slotIndex });
      clearSelection();
      return;
    }

    postAction({
      type: 'move',
      fromContainerId: from.containerId,
      fromSlot: from.slotIndex,
      toContainerId: to.containerId,
      toSlot: to.slotIndex,
    });

    clearSelection();
  };

  const buildContextMenu = () => {
    const menu = document.createElement('div');
    menu.className = 'inv-context';
    document.body.appendChild(menu);

    const hideMenu = () => {
      menu.style.display = 'none';
      menu.innerHTML = '';
    };

    const addEntry = (label, handler, isTitle = false) => {
      if (isTitle) {
        const div = document.createElement('div');
        div.textContent = label;
        div.className = 'inv-context-title';
        menu.appendChild(div);
        return;
      }
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.textContent = label;
      btn.addEventListener('click', () => {
        hideMenu();
        handler();
      });
      menu.appendChild(btn);
    };

    const openMenu = (x, y, actions, title = null, subtitle = null) => {
      menu.innerHTML = '';
      if (title) {
        const div = document.createElement('div');
        div.textContent = title;
        div.className = 'inv-context-title';
        if (subtitle) {
          div.style.borderBottom = 'none';
        }
        menu.appendChild(div);
      }
      if (subtitle) {
        const sub = document.createElement('div');
        sub.textContent = subtitle;
        sub.className = 'inv-context-subtitle';
        menu.appendChild(sub);
      }
      actions.forEach((action) => addEntry(action.label, action.handler));
      menu.style.left = `${x}px`;
      menu.style.top = `${y}px`;
      menu.style.display = 'block';
    };

    document.addEventListener('click', hideMenu);
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') {
        hideMenu();
      }
    });

    return { openMenu, hideMenu };
  };

  const contextMenu = buildContextMenu();

  // ============================================================
  //  ACCESSOIRES D'ARMES (weapon attachments overlay)
  // ============================================================

  const hasAttachmentsConfig = (item) => {
    if (!item || !item.weaponHash) return false;
    const mapping = weaponAttachmentsConfig[item.weaponHash];
    return !!mapping && Object.keys(mapping).length > 0;
  };

  const getWeaponItemFromContext = (ctx) => {
    if (!ctx) return null;
    if (ctx.location === 'equipment') {
      return state.equipment[ctx.equipSlot] || null;
    }
    const container = state.containers[ctx.containerId];
    if (!container) return null;
    return container.items && container.items[ctx.slotIndex] || null;
  };

  // Dimensions de la vue (synchronisées avec le CSS #attachments-view)
  // L'arme est remontée (y=285) pour laisser la liste d'accessoires en bas.
  const ATT_VIEW = {
    width: 1318,
    height: 707,
    cellW: 82,
    cellH: 80,
    weaponCenter: { x: 659, y: 285 },
    weaponSize: { w: 520, h: 300 },
  };

  // Positions des accessoires par type, relatives au centre de l'arme.
  // - weaponPt = point sur l'arme où la ligne pointe (où se trouve l'accessoire physiquement)
  // - cellCenter = centre de la cellule de l'accessoire
  // L'arme étant horizontale (canon à droite), on dispose :
  //  scope au-dessus, barrel à droite (muzzle), flashlight sous le rail avant,
  //  grip en bas centre-avant, magazine en bas centre-arrière.
  const ATT_ANCHORS = {
    scope:      { weaponPt: { x:   0, y:  -85 }, cellCenter: { x:    0, y: -210 } },
    barrel:     { weaponPt: { x: 220, y:  -10 }, cellCenter: { x:  440, y:  -10 } },
    flashlight: { weaponPt: { x: 110, y:   50 }, cellCenter: { x:  255, y:  150 } },
    grip:       { weaponPt: { x:  30, y:   65 }, cellCenter: { x:   35, y:  205 } },
    magazine:   { weaponPt: { x: -60, y:   65 }, cellCenter: { x: -255, y:  150 } },
  };
  // Fallback si nouveau type de slot ajouté sans anchor défini : disposition radiale
  const ATT_FALLBACK_RADIUS = 330;
  const computeFallbackAnchor = (slotName, idx, total) => {
    const angle = (-Math.PI / 2) + (idx / total) * Math.PI * 2;
    const wPt = { x: Math.cos(angle) * 120, y: Math.sin(angle) * 90 };
    const cPt = { x: Math.cos(angle) * ATT_FALLBACK_RADIUS, y: Math.sin(angle) * 210 };
    return { weaponPt: wPt, cellCenter: cPt };
  };

  // Liste des componentHash GTA des accessoires ACTUELLEMENT attachés (pour la 3D).
  const getPreviewComponents = (item) => {
    if (!item) return [];
    const mapping = weaponAttachmentsConfig[item.weaponHash] || {};
    const attached = Object.assign({}, (item.meta && item.meta.attachments) || {});
    const out = [];
    Object.keys(mapping).forEach((slot) => {
      const def = mapping[slot];
      if (attached[slot] && def && def.componentHash && attached[slot] === def.item) {
        out.push(def.componentHash);
      }
    });
    return out;
  };

  const sendWeaponPreview = (route, body) => {
    fetch(`https://${GetParentResourceName()}/${route}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body || {}),
    });
  };

  const openAttachmentsView = (ctx) => {
    activeAttachmentContext = ctx;
    const view = document.getElementById('attachments-view');
    if (view) view.classList.add('is-open');
    // Masquer tout le fond de l'inventaire derrière la vue accessoires.
    const wrapper = document.getElementById('full-ui-wrapper');
    if (wrapper) wrapper.classList.add('attachments-active');
    // Retire le voile noir du body pour bien voir l'arme 3D derrière la NUI.
    document.body.classList.add('weapon-preview-active');
    renderAttachmentsView();
    // Démarre la prévisualisation 3D (objet arme + caméra) côté client.
    const item = getWeaponItemFromContext(ctx);
    if (item && item.weaponHash) {
      sendWeaponPreview('weaponPreviewStart', { weaponHash: item.weaponHash, components: getPreviewComponents(item) });
    }
  };

  const closeAttachmentsView = () => {
    activeAttachmentContext = null;
    const view = document.getElementById('attachments-view');
    if (view) view.classList.remove('is-open');
    const wrapper = document.getElementById('full-ui-wrapper');
    if (wrapper) wrapper.classList.remove('attachments-active');
    // Restaure le voile noir du body.
    document.body.classList.remove('weapon-preview-active');
    // Réaffiche l'image 2D et stoppe la 3D.
    const weaponImg = document.getElementById('attachments-weapon-img');
    if (weaponImg) weaponImg.style.display = '';
    sendWeaponPreview('weaponPreviewStop', {});
  };

  // ===== Glisser-souris pour tourner l'arme 3D (envoi batché 1x/frame) =====
  (() => {
    const dragLayer = document.getElementById('attachments-3d-drag');
    if (!dragLayer) return;
    const pv = { dragging: false, dx: 0, dy: 0 };
    dragLayer.addEventListener('mousedown', (e) => {
      pv.dragging = true; dragLayer.classList.add('dragging'); e.preventDefault();
    });
    window.addEventListener('mouseup', () => {
      pv.dragging = false; dragLayer.classList.remove('dragging');
    });
    window.addEventListener('mousemove', (e) => {
      if (!pv.dragging) return;
      pv.dx += e.movementX || 0;
      pv.dy += e.movementY || 0;
    });
    const tick = () => {
      if (activeAttachmentContext && (pv.dx || pv.dy)) {
        sendWeaponPreview('weaponPreviewRotate', { dx: pv.dx, dy: pv.dy });
        pv.dx = 0; pv.dy = 0;
      }
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  })();

  const refreshAttachmentsView = () => {
    if (!activeAttachmentContext) return;
    const item = getWeaponItemFromContext(activeAttachmentContext);
    if (!item) {
      closeAttachmentsView();
      return;
    }
    renderAttachmentsView();
  };

  const countAccessoriesAvailable = (defId) => {
    let total = 0;
    Object.values(state.containers || {}).forEach((container) => {
      Object.values(container.items || {}).forEach((it) => {
        if (it && it.defId === defId) {
          total += it.qty || 1;
        }
      });
    });
    return total;
  };

  // Construit une cellule "point d'attache" positionnée autour de l'arme.
  //  - attached : icône pleine de l'accessoire + ✓, clic = détacher
  //  - empty    : placeholder (icône fantôme + "+"), accepte le dépôt d'un accessoire
  const buildAttachmentCell = (opts) => {
    const cell = document.createElement('div');
    cell.className = 'attachments-cell';
    cell.style.left = (opts.cx - ATT_VIEW.cellW / 2) + 'px';
    cell.style.top = (opts.cy - ATT_VIEW.cellH / 2) + 'px';

    if (opts.attached) {
      cell.classList.add('attached');
      const wrap = document.createElement('div');
      wrap.className = 'attachments-cell-icon';
      const img = document.createElement('img');
      img.src = opts.iconSrc || 'img/unknown.webp';
      img.alt = opts.accessoryLabel || '';
      wrap.appendChild(img);
      cell.appendChild(wrap);

      const state = document.createElement('div');
      state.className = 'attachments-cell-state';
      state.textContent = '✓';
      cell.appendChild(state);
    } else {
      cell.classList.add('empty');
      // Icône fantôme de l'accessoire attendu, pour suggérer ce qui va là.
      const wrap = document.createElement('div');
      wrap.className = 'attachments-cell-icon';
      const img = document.createElement('img');
      img.src = opts.iconSrc || 'img/unknown.webp';
      img.alt = '';
      wrap.appendChild(img);
      cell.appendChild(wrap);

      const plus = document.createElement('div');
      plus.className = 'attachments-cell-plus';
      plus.textContent = '+';
      cell.appendChild(plus);
    }

    const lbl = document.createElement('div');
    lbl.className = 'attachments-cell-label';
    lbl.textContent = opts.slotLabel || '';
    cell.appendChild(lbl);

    if (opts.title) cell.title = opts.title;
    if (opts.onClick) cell.addEventListener('click', opts.onClick);

    if ((opts.acceptDefId || opts.acceptMagazine) && !opts.attached) {
      // Le slot chargeur accepte tout item magazine ; les autres slots, l'item exact.
      const accepts = (defId) => opts.acceptMagazine ? isMagazineDef(defId) : (defId === opts.acceptDefId);
      cell.addEventListener('dragover', (e) => {
        if (!dragState || !dragState.item) return;
        if (!accepts(dragState.item.defId)) return;
        e.preventDefault();
        cell.classList.add('drag-over');
      });
      cell.addEventListener('dragleave', () => cell.classList.remove('drag-over'));
      cell.addEventListener('drop', (e) => {
        e.preventDefault();
        cell.classList.remove('drag-over');
        if (!dragState || !dragState.item) return;
        if (!accepts(dragState.item.defId)) return;
        dragState.dropped = true;
        if (opts.onDrop) opts.onDrop(dragState.item.defId);
      });
    }

    return cell;
  };

  const getAnchorForSlot = (slotName, idx, total) => {
    return ATT_ANCHORS[slotName] || computeFallbackAnchor(slotName, idx, total);
  };

  const attachAccessory = (slotName, attachDefId) => {
    postAction({
      type: 'weapon_attach',
      weaponLocation: activeAttachmentContext.location,
      weaponContainerId: activeAttachmentContext.containerId,
      weaponSlot: activeAttachmentContext.slotIndex,
      equipSlot: activeAttachmentContext.equipSlot,
      attachmentSlot: slotName,
      attachDefId: attachDefId || null,
    });
  };

  // Un item est un chargeur s'il porte le tag 'magazine' (envoyé dans la vue d'item)
  // ou s'il est marqué isMagazine dans la config des accessoires.
  const itemHasMagazineTag = (it) => !!(it && Array.isArray(it.tags) && it.tags.indexOf('magazine') !== -1);
  const isMagazineDef = (defId) => {
    const d = attachmentItemsConfig[defId];
    return !!(d && d.isMagazine);
  };
  const listAvailableMagazines = () => {
    const counts = {};
    Object.values(state.containers || {}).forEach((container) => {
      Object.values(container.items || {}).forEach((it) => {
        if (it && (itemHasMagazineTag(it) || isMagazineDef(it.defId))) {
          counts[it.defId] = (counts[it.defId] || 0) + (it.qty || 1);
        }
      });
    });
    return counts;
  };

  const detachAccessory = (slotName) => {
    postAction({
      type: 'weapon_detach',
      weaponLocation: activeAttachmentContext.location,
      weaponContainerId: activeAttachmentContext.containerId,
      weaponSlot: activeAttachmentContext.slotIndex,
      equipSlot: activeAttachmentContext.equipSlot,
      attachmentSlot: slotName,
    });
  };

  // Liste en bas : accessoires compatibles présents dans l'inventaire du joueur.
  const renderInventoryList = (mapping, attached) => {
    const listRoot = document.getElementById('attachments-inventory-list');
    if (!listRoot) return;
    listRoot.innerHTML = '';

    let shown = 0;

    // Retrouve un item par defId dans l'inventaire (pour label/icône de secours).
    const findItemViewByDef = (defId) => {
      let found = null;
      Object.values(state.containers || {}).forEach((container) => {
        Object.values(container.items || {}).forEach((it) => {
          if (!found && it && it.defId === defId) found = it;
        });
      });
      return found;
    };

    // Ajoute une vignette "accessoire proposé" à la liste du bas.
    const addProposal = (slotName, slotLabel, defId, count) => {
      const fallback = findItemViewByDef(defId) || {};
      const accDef = attachmentItemsConfig[defId]
        || { label: fallback.label || defId, icon: fallback.icon };
      const cell = document.createElement('div');
      cell.className = 'attachments-inv-item';
      cell.title = 'Cliquer pour attacher (' + slotLabel + ')';

      const wrap = document.createElement('div');
      wrap.className = 'attachments-cell-icon';
      const img = document.createElement('img');
      img.src = accDef.icon || 'img/unknown.webp';
      img.alt = accDef.label || '';
      wrap.appendChild(img);
      cell.appendChild(wrap);

      if (count > 1) {
        const qty = document.createElement('div');
        qty.className = 'attachments-cell-qty';
        qty.textContent = count;
        cell.appendChild(qty);
      }

      const name = document.createElement('div');
      name.className = 'attachments-inv-item-name';
      name.textContent = accDef.label || defId;
      cell.appendChild(name);

      cell.addEventListener('click', () => attachAccessory(slotName, defId));
      listRoot.appendChild(cell);
      shown += 1;
    };

    Object.keys(mapping).forEach((slotName) => {
      const slotDef = mapping[slotName];
      if (attached[slotName]) return; // slot déjà occupé → pas proposable
      const slotLabel = slotDef.label || slotName;

      // Slot chargeur : on propose TOUS les chargeurs présents dans l'inventaire.
      if (slotName === 'magazine') {
        const mags = listAvailableMagazines();
        Object.keys(mags).forEach((defId) => addProposal(slotName, slotLabel, defId, mags[defId]));
        return;
      }

      const count = countAccessoriesAvailable(slotDef.item);
      if (count <= 0) return; // pas dans l'inventaire
      addProposal(slotName, slotLabel, slotDef.item, count);
    });

    if (shown === 0) {
      const empty = document.createElement('div');
      empty.className = 'attachments-inventory-empty';
      empty.textContent = 'Aucun accessoire compatible dans votre inventaire';
      listRoot.appendChild(empty);
    }
  };

  const renderAttachmentsView = () => {
    const view = document.getElementById('attachments-view');
    if (!view || !activeAttachmentContext) return;
    const item = getWeaponItemFromContext(activeAttachmentContext);
    if (!item) {
      closeAttachmentsView();
      return;
    }

    const title = document.getElementById('attachments-title');
    if (title) title.textContent = item.label || item.defId;

    // L'image 2D est masquée : c'est la prévisualisation 3D (objet monde) qui s'affiche
    // derrière la NUI. On garde l'élément (au cas où la 3D échoue / fermeture).
    const weaponImg = document.getElementById('attachments-weapon-img');
    if (weaponImg) {
      weaponImg.src = item.icon || 'img/unknown.webp';
      weaponImg.alt = item.label || '';
      weaponImg.style.display = 'none';
    }
    // Reflète en 3D les accessoires actuellement attachés (après attache/détache).
    sendWeaponPreview('weaponPreviewUpdate', { components: getPreviewComponents(item) });

    const cellsRoot = document.getElementById('attachments-cells');
    const linesRoot = document.getElementById('attachments-lines');
    if (!cellsRoot || !linesRoot) return;
    cellsRoot.innerHTML = '';
    linesRoot.innerHTML = '';

    const mapping = weaponAttachmentsConfig[item.weaponHash] || {};
    // Arme à puits de chargeur (pistol/smg/carabine) : la case "Chargeur" reflète
    // le chargeur réellement inséré dans le puits (item.magazine), pas un composant.
    const hasMagWell = !!item.containerId;
    const attached = Object.assign({}, (item.meta && item.meta.attachments) || {});
    if (hasMagWell) {
      attached.magazine = item.magazine ? item.magazine.defId : undefined;
    }
    const slotNames = Object.keys(mapping);
    const cx = ATT_VIEW.weaponCenter.x;
    const cy = ATT_VIEW.weaponCenter.y;

    slotNames.forEach((slotName, idx) => {
      const slotDef = mapping[slotName];
      const attachedDefId = attached[slotName];
      const isAttached = !!attachedDefId;
      const isMagazineSlot = slotName === 'magazine';
      const isMagWellSlot = isMagazineSlot && hasMagWell;
      // Icône affichée : si attaché, celle de l'item réellement attaché (peut différer
      // du chargeur par défaut pour le slot magazine) ; sinon l'icône suggérée du slot.
      const iconDefId = attachedDefId || slotDef.item;
      const accDef = (isMagWellSlot && item.magazine)
        ? { label: item.magazine.label, icon: item.magazine.icon }
        : (attachmentItemsConfig[iconDefId] || { label: iconDefId });
      const anchor = getAnchorForSlot(slotName, idx, slotNames.length);
      const cellCx = cx + anchor.cellCenter.x;
      const cellCy = cy + anchor.cellCenter.y;
      const weaponPx = cx + anchor.weaponPt.x;
      const weaponPy = cy + anchor.weaponPt.y;

      const cell = buildAttachmentCell({
        cx: cellCx,
        cy: cellCy,
        iconSrc: accDef.icon || 'img/unknown.webp',
        accessoryLabel: accDef.label || iconDefId,
        slotLabel: (slotDef.label || slotName),
        attached: isAttached,
        title: isAttached
          ? ((accDef.label || '') + ' — cliquer pour détacher')
          : ('Emplacement ' + (slotDef.label || slotName)),
        acceptDefId: slotDef.item,
        // Slot chargeur : accepte n'importe quel item taggé magazine.
        acceptMagazine: isMagazineSlot,
        onClick: () => {
          if (isAttached) detachAccessory(slotName);
        },
        onDrop: (droppedDefId) => attachAccessory(slotName, isMagazineSlot ? droppedDefId : undefined),
      });
      cellsRoot.appendChild(cell);

      // Trait SVG : du bord de la cellule (en direction de l'arme) jusqu'au point sur l'arme.
      const dx = weaponPx - cellCx;
      const dy = weaponPy - cellCy;
      const halfW = ATT_VIEW.cellW / 2;
      const halfH = ATT_VIEW.cellH / 2;
      const sx = dx !== 0 ? halfW / Math.abs(dx) : Infinity;
      const sy = dy !== 0 ? halfH / Math.abs(dy) : Infinity;
      const s = Math.min(sx, sy);
      const startX = cellCx + dx * s;
      const startY = cellCy + dy * s;

      const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
      line.setAttribute('x1', String(startX));
      line.setAttribute('y1', String(startY));
      line.setAttribute('x2', String(weaponPx));
      line.setAttribute('y2', String(weaponPy));
      if (isAttached) line.classList.add('filled');
      linesRoot.appendChild(line);

      const endpoint = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      endpoint.setAttribute('cx', String(weaponPx));
      endpoint.setAttribute('cy', String(weaponPy));
      endpoint.setAttribute('r', '3');
      endpoint.setAttribute('class', isAttached ? 'endpoint filled' : 'endpoint');
      linesRoot.appendChild(endpoint);
    });

    renderInventoryList(mapping, attached);
  };

  const handleSlotContext = (event) => {
    event.preventDefault();
    const slotEl = event.currentTarget;
    const zone = slotEl.dataset.zone;
    const slotIndex = Number.parseInt(slotEl.dataset.slotIndex, 10);
    const container = getContainerByZone(zone);
    if (!container) {
      return;
    }
    const item = container.items && container.items[slotIndex];
    if (!item) {
      return;
    }

    const actions = [];

    if (zone === 'ground') {
      actions.push({
        label: 'Prendre',
        handler: () => postAction({ type: 'pickup', slot: slotIndex }),
      });
    } else {
      if (item.equipSlot && !state.equipment[item.equipSlot]) {
        actions.push({
          label: 'Equiper',
          handler: () => postAction({ type: 'equip', containerId: container.id, slot: slotIndex }),
        });
      }
      actions.push({
        label: 'Deposer',
        handler: () => {
          let qty = item.qty;
          if (item.maxStack > 1 && item.qty > 1) {
            showInputModal('Quantité à déposer', item.qty, (inputQty) => {
              postAction({ type: 'drop', containerId: container.id, slot: slotIndex, qty: inputQty });
            });
            return;
          }
          postAction({ type: 'drop', containerId: container.id, slot: slotIndex, qty });
        },
      });
    }

    if (item.usable) {
      actions.push({
        label: item.defId === 'pistolet_peinture' ? 'Remplir' : (item.defId === 'pochonweed' ? 'Vendre' : 'Utiliser'),
        handler: () => postAction({ type: 'use', containerId: container.id, slot: slotIndex, fromType: zone }),
      });
    }

    if (item.isContainer) {
      const isOpen = state.containerOrder.some(e => e.containerId === item.containerId);
      if (isOpen) {
        actions.push({
          label: 'Fermer',
          handler: () => {
            postAction({ type: 'close', containerId: item.containerId });
          },
        });
      } else {
        actions.push({
          label: 'Ouvrir',
          handler: () => {
            postAction({ type: 'open', containerId: item.containerId });
          },
        });
      }
    }

    if (item.maxStack > 1 && item.qty > 1 && zone !== 'ground') {
      actions.push({
        label: 'Diviser',
        handler: () => {
          showInputModal('Quantité à séparer', 1, (qty) => {
            postAction({ type: 'split', containerId: container.id, slot: slotIndex, qty });
          });
        },
      });
    }

    if (zone !== 'ground' && hasAttachmentsConfig(item)) {
      actions.push({
        label: 'Accessoires',
        handler: () => openAttachmentsView({
          location: 'container',
          containerId: container.id,
          slotIndex,
        }),
      });
    }

    if (zone !== 'ground') {
      actions.push({
        label: 'Renommer',
        handler: () => {
          showInputModal('Renommer l\'item', item.label || '', (newLabel) => {
            postAction({ type: 'rename', containerId: container.id, slot: slotIndex, label: newLabel });
          }, 'text');
        },
      });
    }

    let menuTitle = item.label || item.defId;
    let subtitle = (item.meta && item.meta.description) || item.description || null;

    contextMenu.openMenu(event.clientX, event.clientY, actions, menuTitle, subtitle);
  };

  const handleEquipContext = (event) => {
    event.preventDefault();
    const slotEl = resolveEquipSlotEl(event);
    if (!slotEl) {
      return;
    }
    const slot = slotEl.dataset.equipSlot;
    if (!slot || !state.equipment[slot]) {
      return;
    }
    const item = state.equipment[slot];
    let menuTitle = item.label || item.defId;

    const actions = [
      {
        label: 'Retirer',
        handler: () => postAction({ type: 'unequip', slot }),
      },
      {
        label: 'Deposer',
        handler: () => {
          postAction({ type: 'drop', fromType: 'equipment', slot });
        },
      }
    ];

    if (item.usable) {
      actions.push({
        label: item.defId === 'pistolet_peinture' ? 'Remplir' : (item.defId === 'pochonweed' ? 'Vendre' : 'Utiliser'),
        handler: () => postAction({ type: 'use', fromType: 'equipment', slot: slot }),
      });
    }

    if (item.isContainer) {
      actions.push({
        label: 'Ouvrir',
        handler: () => postAction({ type: 'open', containerId: item.containerId }),
      });
    }

    if (hasAttachmentsConfig(item)) {
      actions.push({
        label: 'Accessoires',
        handler: () => openAttachmentsView({
          location: 'equipment',
          equipSlot: slot,
        }),
      });
    }

    actions.push({
      label: 'Renommer',
      handler: () => {
        showInputModal('Renommer l\'item', item.label || '', (newLabel) => {
          postAction({ type: 'rename', fromType: 'equipment', slot: slot, label: newLabel });
        }, 'text');
      },
    });

    let subtitle = (item.meta && item.meta.description) || item.description || null;
    contextMenu.openMenu(event.clientX, event.clientY, actions, menuTitle, subtitle);
  };

  const handleSlotDrop = (event) => {
    event.preventDefault();
    if (!dragState) {
      return;
    }
    const payload = dragState;
    const slotEl = event.currentTarget;
    const zone = slotEl.dataset.zone;
    const slotIndex = Number.parseInt(slotEl.dataset.slotIndex, 10);
    
    if (payload.fromType === 'admin') {
      if (zone === 'container') {
        fetch(`https://${GetParentResourceName()}/adminGiveItem`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ id: payload.item.id, qty: 1 }),
        });
      }
      endDrag();
      return;
    }

    if (payload.fromType === 'equipment' && zone !== 'ground') {
      endDrag();
      return;
    }

    if (zone === 'ground') {
      if (payload.fromType === 'container') {
        dragState.dropped = true;
        postAction({ type: 'drop', containerId: payload.containerId, slot: payload.slotIndex });
      } else if (payload.fromType === 'equipment') {
        dragState.dropped = true;
        postAction({ type: 'drop', fromType: 'equipment', slot: payload.slotIndex });
      }
      endDrag();
      return;
    }

    if (zone === 'container') {
      if (payload.fromType === 'ground') {
        const targetContainer = getContainerByZone('container');
        if (!targetContainer) {
          endDrag();
          return;
        }
        dragState.dropped = true;
        postAction({
          type: 'pickupToSlot',
          slot: payload.slotIndex,
          toContainerId: targetContainer.id,
          toSlot: slotIndex,
        });
        endDrag();
        return;
      }

      if (payload.fromType === 'equipment') {
        const targetContainer = getContainerByZone('container');
        if (!targetContainer) {
          endDrag();
          return;
        }
        dragState.dropped = true;
        postAction({
          type: 'unequipToSlot',
          slot: payload.slotIndex,
          toContainerId: targetContainer.id,
          toSlot: slotIndex,
        });
        endDrag();
        return;
      }

      if (payload.fromType === 'container') {
        const targetContainer = getContainerByZone('container');
        if (!targetContainer) {
          endDrag();
          return;
        }
        dragState.dropped = true;
        postAction({
          type: 'move',
          fromContainerId: payload.containerId,
          fromSlot: payload.slotIndex,
          toContainerId: targetContainer.id,
          toSlot: slotIndex,
        });
        endDrag();
        return;
      }
    }
  };

  const handleSlotDragOver = (event) => {
    if (!dragState) {
      return;
    }
    event.preventDefault();
  };

  const handleEquipDrop = (event) => {
    event.preventDefault();
    if (!dragState) {
      return;
    }
    const slotEl = resolveEquipSlotEl(event);
    if (!slotEl) {
      endDrag();
      return;
    }
    const equipSlot = slotEl.dataset.equipSlot;
    if (!equipSlot) {
      endDrag();
      return;
    }

    if (dragState.fromType === 'container' && dragState.item && dragState.item.equipSlot === equipSlot) {
      dragState.dropped = true;
      postAction({ type: 'equip', containerId: dragState.containerId, slot: dragState.slotIndex });
      endDrag();
      return;
    }

    if (dragState.fromType === 'ground' && dragState.item && dragState.item.equipSlot === equipSlot) {
      dragState.dropped = true;
      postAction({ type: 'pickupEquip', slot: dragState.slotIndex, equipSlot });
      endDrag();
      return;
    }

    if (dragState.fromType === 'equipment' && dragState.slotIndex === equipSlot) {
      endDrag();
      return;
    }

    endDrag();
  };

  const handleEquipDragOver = (event) => {
    if (!dragState) {
      return;
    }
    event.preventDefault();
  };

  const handlePointerMove = (event) => {
    if (!pointerDrag) {
      return;
    }
    if (!pointerDrag.active) {
      const dx = event.clientX - pointerDrag.startX;
      const dy = event.clientY - pointerDrag.startY;
      if (Math.abs(dx) < POINTER_DRAG_THRESHOLD && Math.abs(dy) < POINTER_DRAG_THRESHOLD) {
        return;
      }
      beginDrag(pointerDrag.payload, event, true);
      event.preventDefault();
      return;
    }
    updateDragPreview(event);

    // Switch category if hovering icon
    if (dragState) {
      const target = document.elementFromPoint(event.clientX, event.clientY);
      if (target && target.classList && target.classList.contains('icon')) {
        if (!target.classList.contains('locked')) {
          const targetContainerId = target.dataset.containerId;
          if (targetContainerId && activeContainerId !== targetContainerId) {
            activeContainerId = targetContainerId;
            render();
          }
        }
      }
    }

    event.preventDefault();
  };

  const handlePointerUp = (event) => {
    if (!pointerDrag) {
      if (draggingToGive && dragState) {
        endDrag();
      }
      return;
    }
    if (!pointerDrag.active) {
      pointerDrag = null;
      return;
    }

    const target = document.elementFromPoint(event.clientX, event.clientY);
    if (target && target.closest) {
      const slotEl = target.closest('[data-zone]');
      if (slotEl) {
        handleSlotDrop({ preventDefault: () => { }, currentTarget: slotEl });
      } else {
        const equipEl = target.closest('[data-equip-slot]');
        if (equipEl) {
          handleEquipDrop({ preventDefault: () => { }, currentTarget: equipEl });
        } else {
          endDrag();
        }
      }
    } else {
      endDrag();
    }

    pointerDrag = null;
    suppressClick = true;
    setTimeout(() => {
      suppressClick = false;
    }, 0);
  };

  const handleClickCapture = (event) => {
    if (!suppressClick) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    suppressClick = false;
  };

  const renderIcons = () => {
    const active = activeContainerId || state.activeContainerId;
    const containerOrder = dragState && dragState.fromType === 'equipment'
      ? state.containerOrder.filter((entry) => entry.defId !== dragState.equipSlot)
      : state.containerOrder;

    iconMap.forEach((icon, section) => {
      const entry = containerOrder.find((item) => item.defId === section && !item.isTarget);
      if (!entry) {
        icon.classList.add('locked');
        icon.classList.remove('active');
        icon.dataset.containerId = '';
        return;
      }
      icon.classList.remove('locked');
      icon.dataset.containerId = entry.containerId;
      icon.classList.toggle('active', entry.containerId === active);
    });

    const targetBar = document.querySelector('.target-icon-bar');
    const hasTarget = containerOrder.some(e => e.isTarget);
    if (targetBar) {
      targetBar.style.display = hasTarget ? 'flex' : 'none';
      if (hasTarget) {
        iconMapTarget.forEach((icon, section) => {
          const entry = containerOrder.find((item) => (item.isTarget && ("target_" + item.defId) === section));
          if (!entry) {
            icon.classList.add('locked');
            icon.classList.remove('active');
            icon.dataset.containerId = '';
            return;
          }
          icon.classList.remove('locked');
          icon.dataset.containerId = entry.containerId;
          icon.classList.toggle('active', entry.containerId === active);
        });
      }
    }

    resetUnderline();
  };

  const renderEquipment = () => {
    const equipmentView = { ...state.equipment };
    if (dragState && dragState.fromType === 'equipment' && dragState.equipSlot) {
      delete equipmentView[dragState.equipSlot];
    }

    equipSlots.forEach((el, slot) => {
      const item = equipmentView[slot];
      const equipped = !!item;
      el.classList.toggle('equipped', equipped);

      const backgroundImg = el.querySelector('img[src^="svg/"]');
      if (backgroundImg) {
        backgroundImg.style.display = equipped ? 'none' : 'block';
      }

      const existing = el.querySelector('.equip-item');
      if (equipped && item) {
        if (!existing) {
          const node = document.createElement('div');
          node.className = 'equip-item';
          if (item.gradientColor) {
            node.style.setProperty('--gradient-color', item.gradientColor);
          }
          if (item.icon) {
            const img = document.createElement('img');
            img.src = item.icon;
            img.alt = item.label || item.defId;
            img.draggable = false;
            if (item.icon.endsWith('.svg')) {
              img.classList.add('inv-icon-svg');
            }
            node.appendChild(img);
          } else {
            node.textContent = item.label || item.defId;
          }
          if (item.qty && item.qty > 1) {
            const qty = document.createElement('div');
            qty.className = 'inv-qty';
            qty.textContent = item.qty;
            node.appendChild(qty);
          }
          el.appendChild(node);
          wireEquipMedia(node);
        } else {
          if (item.gradientColor) {
            existing.style.setProperty('--gradient-color', item.gradientColor);
          }
          const img = existing.querySelector('img');
          if (img && item.icon) {
            img.src = item.icon;
            img.alt = item.label || item.defId;
            img.draggable = false;
          }
          wireEquipMedia(existing);
        }
      } else if (existing) {
        existing.remove();
      }
    });
  };

  const renderWeights = () => {
    const activeId = activeContainerId || state.activeContainerId;
    const activeContainer = state.containers[activeId] || (state.ground && state.ground.id === activeId ? state.ground : null);
    const current = activeContainer ? activeContainer.weight || 0 : 0;
    const max = activeContainer ? activeContainer.maxWeight || 0 : 0;

    if (capacityCurrentEl) {
      capacityCurrentEl.textContent = current.toFixed(1);
    }
    if (capacityMaxEl) {
      capacityMaxEl.textContent = `/${max.toFixed(1)}kg`;
    }

    let totalWeight = 0;
    let totalMax = 0;
    const containerOrder = dragState && dragState.fromType === 'equipment'
      ? state.containerOrder.filter((entry) => entry.defId !== dragState.equipSlot)
      : state.containerOrder;
    containerOrder.forEach((entry) => {
      const container = state.containers[entry.containerId];
      if (container) {
        totalWeight += container.weight || 0;
        totalMax += container.maxWeight || 0;
      }
    });

    if (totalCurrentEl) {
      totalCurrentEl.textContent = totalWeight.toFixed(1);
    }
    if (totalMaxEl) {
      totalMaxEl.textContent = `/${totalMax.toFixed(1)}kg`;
    }
  };

  const updateGroundTitle = () => {
    const titleEl = document.getElementById('ground-title');
    if (!titleEl) {
      return;
    }

    // Si activeContainerIsGround est true, on affiche "À proximité"
    // Si activeContainerIsGround est false et activeContainerId existe, c'est aussi un conteneur à proximité
    if (state.activeContainerIsGround) {
      titleEl.textContent = 'À proximité';
    } else if (state.activeContainerId) {
      titleEl.textContent = 'À proximité';
    } else {
      titleEl.textContent = 'À proximité';
    }
  };

  const render = () => {
    if (!activeContainerId) {
      activeContainerId = state.activeContainerId || null;
    }

    if (dragState && dragState.fromType === 'equipment') {
      const entry = state.containerOrder.find((item) => item.defId === dragState.equipSlot);
      if (entry && activeContainerId === entry.containerId) {
        activeContainerId = null;
      }
    }

    const container = state.containers[activeContainerId] || (state.ground && state.ground.id === activeContainerId ? state.ground : null);
    renderSlots(slotMap.container, container);
    renderSlots(slotMap.ground, state.ground);
    renderIcons();
    renderEquipment();
    renderWeights();
    updateGroundTitle();
    renderCraft();
    renderShop();
    window.dispatchEvent(new CustomEvent('inventoryUpdated'));
  };

  const createDragPreview = (item, event) => {
    removeDragPreview();
    if (!item) {
      return;
    }
    const preview = document.createElement('div');
    preview.className = 'drag-preview';

    if (item.icon) {
      const img = document.createElement('img');
      img.src = item.icon;
      img.alt = item.label || item.defId;
      if (item.icon.endsWith('.svg')) {
        img.classList.add('inv-icon-svg');
      }
      preview.appendChild(img);
    } else {
      preview.textContent = item.label || item.defId;
    }

    if (item.qty && item.qty > 1) {
      const qty = document.createElement('div');
      qty.className = 'inv-qty';
      qty.textContent = item.qty;
      preview.appendChild(qty);
    }

    document.body.appendChild(preview);
    dragPreview = preview;
    updateDragPreview(event);
  };

  const updateDragPreview = (event) => {
    if (!dragPreview || !event) {
      return;
    }
    dragPreview.style.left = `${event.clientX}px`;
    dragPreview.style.top = `${event.clientY}px`;

    const wrapper = document.getElementById('full-ui-wrapper');
    if (!draggingToGive && event.clientY < 180 && (!dragState || dragState.fromType !== 'admin')) {
      draggingToGive = true;
      if (wrapper) wrapper.style.visibility = 'hidden';
      document.body.style.backgroundColor = 'transparent';
      fetch(`https://${GetParentResourceName()}/startDraggingOut`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ item: dragState ? dragState.item : null })
      });
    }
  };

  const removeDragPreview = () => {
    if (dragPreview) {
      dragPreview.remove();
      dragPreview = null;
    }
  };

  const handleMessage = (event) => {
    const data = event.data || {};
    // ── Relais vers l'iframe coffre (standby_ui intégré comme module) ──
    // Les messages destinés au coffre arrivent enveloppés { _standby:true, msg:{...} }.
    // On affiche/masque l'iframe et on transmet le message interne tel quel.
    if (data._standby) {
      const frame = document.getElementById('standby-frame');
      if (frame) {
        const inner = data.msg || {};
        if (inner.action === 'open') {
          frame.style.display = 'block';
          document.body.style.display = 'flex';
          const wrapper = document.getElementById('full-ui-wrapper');
          if (wrapper) wrapper.style.display = 'none';
        } else if (inner.action === 'close') {
          frame.style.display = 'none';
          document.body.style.display = 'none';
          const wrapper = document.getElementById('full-ui-wrapper');
          if (wrapper) wrapper.style.display = 'block';
        }
        if (frame.contentWindow) {
          frame.contentWindow.postMessage(inner, '*');
        }
      }
      return;
    }
    if (data.action === 'open') {
      setVisible(true);
      const wrapper = document.getElementById('full-ui-wrapper');
      if (wrapper) wrapper.style.display = 'block';
      const frame = document.getElementById('standby-frame');
      if (frame) frame.style.display = 'none';
      if (data.weaponAttachments) {
        weaponAttachmentsConfig = data.weaponAttachments;
      }
      if (data.attachmentItems) {
        attachmentItemsConfig = data.attachmentItems;
      }
      const pagerBg = document.getElementById('pager-slot-bg');
      const pagerSlot = document.getElementById('pager-slot');
      if (pagerBg && pagerSlot) {
        if (data.enablePager) {
          pagerBg.style.display = 'block';
          pagerSlot.style.display = 'flex';
        } else {
          pagerBg.style.display = 'none';
          pagerSlot.style.display = 'none';
        }
      }
    } else if (data.action === 'close') {
      setVisible(false);
      clearSelection();
      closeAttachmentsView();
    } else if (data.action === 'state') {
      applyState(data.state || {});
      refreshAttachmentsView();
    } else if (data.action === 'craft_mode') {
      openCraftPanel(data.recipes || []);
    } else if (data.action === 'shop_mode') {
      openShopPanel(data.shopId, data.items || []);
    } else if (data.action === 'setAdminItems') {
      adminItemsData = Array.isArray(data.items) ? data.items : [];
      renderAdminItems(adminItemsData);
    } else if (data.action === 'setAdminAllowed') {
      // Menu admin retiré de l'inventaire : le bouton d'accès reste TOUJOURS masqué.
      adminIsAllowed = false;
      const btn = document.getElementById('btn-admin-items');
      if (btn) btn.style.display = 'none';
    } else if (data.action === 'setAdminJobs') {
      const raw = data.jobs;
      adminJobsData = Array.isArray(raw) ? raw : (raw && typeof raw === 'object' ? Object.values(raw) : []);
      console.log('[POP_INVENTORY][NUI] setAdminJobs raw type:', typeof raw, 'isArray:', Array.isArray(raw), '→ normalized to', adminJobsData.length, 'jobs');
      const searchInput = document.getElementById('admin-jobs-search');
      if (searchInput) searchInput.value = '';
      renderAdminJobs(adminJobsData);
    } else if (data.action === 'requestLockerCode') {
      const containerId = data.containerId;
      showInputModal('Code du casier', '', (code) => {
        postAction({ type: 'open', containerId, lockerCode: String(code) });
      }, 'text');
    }
  };

  const init = () => {
    classifySlots();
    initEquipSlots();
    initIcons();

    slotMap.container.forEach((slot) => {
      slot.addEventListener('click', handleSlotClick);
      slot.addEventListener('contextmenu', handleSlotContext);
      slot.addEventListener('dragover', handleSlotDragOver);
      slot.addEventListener('drop', handleSlotDrop);
    });

    slotMap.ground.forEach((slot) => {
      slot.addEventListener('click', handleSlotClick);
      slot.addEventListener('contextmenu', handleSlotContext);
      slot.addEventListener('dragover', handleSlotDragOver);
      slot.addEventListener('drop', handleSlotDrop);
    });

    equipSlots.forEach((slotEl) => {
      slotEl.addEventListener('contextmenu', handleEquipContext);
      slotEl.addEventListener('dragover', handleEquipDragOver);
      slotEl.addEventListener('drop', handleEquipDrop);
      slotEl.setAttribute('draggable', 'false');
    });

    const attachmentsCloseBtn = document.getElementById('attachments-close-btn');
    if (attachmentsCloseBtn) {
      attachmentsCloseBtn.addEventListener('click', closeAttachmentsView);
    }
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && activeAttachmentContext) {
        closeAttachmentsView();
      }
    });
    // Fermer la vue accessoires si l'utilisateur change de conteneur
    iconMap.forEach((icon) => {
      icon.addEventListener('click', () => {
        if (activeAttachmentContext) closeAttachmentsView();
      });
    });

    // Custom scrollbar synchronization for À proximité (ground-items-grid)
    const groundGrid = document.getElementById('ground-items-grid');
    const scrollThumb = document.getElementById('ground-scroll-thumb');
    const scrollRail = document.getElementById('ground-scroll-rail');

    if (groundGrid && scrollThumb) {
      const railTop = 88;
      const railHeight = 441;

      const updateThumbPosition = () => {
        const maxScroll = groundGrid.scrollHeight - groundGrid.clientHeight;
        const thumbHeight = scrollThumb.offsetHeight || 214;
        const maxThumbY = railTop + (railHeight - thumbHeight);
        if (maxScroll <= 0) {
          scrollThumb.style.top = `${railTop}px`;
          return;
        }
        const scrollRatio = groundGrid.scrollTop / maxScroll;
        const newY = railTop + scrollRatio * (maxThumbY - railTop);
        scrollThumb.style.top = `${newY}px`;
      };

      groundGrid.addEventListener('scroll', updateThumbPosition);
      window.addEventListener('resize', updateThumbPosition);
      window.addEventListener('inventoryUpdated', updateThumbPosition);

      let isDragging = false;
      let startY = 0;
      let startThumbTop = railTop;

      const onPointerMove = (e) => {
        if (!isDragging) return;
        const thumbHeight = scrollThumb.offsetHeight || 214;
        const maxThumbY = railTop + (railHeight - thumbHeight);
        const deltaY = e.clientY - startY;
        let newTop = startThumbTop + deltaY;
        if (newTop < railTop) newTop = railTop;
        if (newTop > maxThumbY) newTop = maxThumbY;
        
        scrollThumb.style.top = `${newTop}px`;

        const scrollRatio = (newTop - railTop) / (maxThumbY - railTop);
        const maxScroll = groundGrid.scrollHeight - groundGrid.clientHeight;
        groundGrid.scrollTop = scrollRatio * maxScroll;
      };

      const onPointerUp = () => {
        isDragging = false;
        document.removeEventListener('pointermove', onPointerMove);
        document.removeEventListener('pointerup', onPointerUp);
        document.body.style.userSelect = '';
      };

      scrollThumb.addEventListener('pointerdown', (e) => {
        isDragging = true;
        startY = e.clientY;
        startThumbTop = parseFloat(scrollThumb.style.top) || railTop;
        document.addEventListener('pointermove', onPointerMove);
        document.addEventListener('pointerup', onPointerUp);
        document.body.style.userSelect = 'none';
        e.preventDefault();
      });

      if (scrollRail) {
        scrollRail.addEventListener('pointerdown', (e) => {
          if (e.target === scrollThumb) return;
          const rect = scrollRail.getBoundingClientRect();
          const clickY = e.clientY - rect.top;
          const thumbHeight = scrollThumb.offsetHeight || 214;
          const maxThumbY = railTop + (railHeight - thumbHeight);
          
          let newTop = railTop + clickY - (thumbHeight / 2);
          if (newTop < railTop) newTop = railTop;
          if (newTop > maxThumbY) newTop = maxThumbY;

          scrollThumb.style.top = `${newTop}px`;
          const scrollRatio = (newTop - railTop) / (maxThumbY - railTop);
          const maxScroll = groundGrid.scrollHeight - groundGrid.clientHeight;
          groundGrid.scrollTop = scrollRatio * maxScroll;

          isDragging = true;
          startY = e.clientY;
          startThumbTop = newTop;
          document.addEventListener('pointermove', onPointerMove);
          document.addEventListener('pointerup', onPointerUp);
          document.body.style.userSelect = 'none';
          e.preventDefault();
        });
      }
    }
  };

  window.getInventoryItemCount = (itemDefId) => {
    // La peinture peut être DANS des pots (conteneurs imbriqués non chargés côté
    // client). Le serveur fournit le vrai stock dans state.paintStock.
    if (state.paintStock && Object.prototype.hasOwnProperty.call(state.paintStock, itemDefId)) {
      return state.paintStock[itemDefId] || 0;
    }
    let count = 0;
    Object.keys(state.containers).forEach((cid) => {
      const isTarget = state.containerOrder.some(e => e.containerId === cid && e.isTarget);
      if (isTarget) return;
      const container = state.containers[cid];
      if (container && container.items) {
        Object.values(container.items).forEach((item) => {
          if (item && item.defId === itemDefId) {
            count += (item.qty || 1);
          }
        });
      }
    });
    return count;
  };

  window.openPanel = openPanel;
  window.goBack = goBack;

  window.addEventListener('message', handleMessage);

  const btnChangeTorse = document.getElementById('btn-change-torse');
  const btnBackTorso = document.getElementById('btn-back-torso');
  const clothesSide = document.getElementById('clothes-side');
  const torsoGridSide = document.getElementById('torso-grid-side');

  if (btnChangeTorse) {
    btnChangeTorse.addEventListener('click', () => {
      fetch(`https://${GetParentResourceName()}/changeTorse`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      });
      if (clothesSide && torsoGridSide) {
        openPanel('torso-grid-side');
      }
    });
  }

  if (btnBackTorso) {
    btnBackTorso.addEventListener('click', goBack);
  }

  const torsoSlots = document.querySelectorAll('div[data-zone="torso-grid"]');
  torsoSlots.forEach((slot) => {
    slot.style.boxSizing = 'border-box';
    slot.style.transition = 'border 0.2s';
    slot.addEventListener('click', () => {
      torsoSlots.forEach(s => s.style.border = '');
      slot.style.border = '2px solid rgba(255, 255, 255, 0.8)';

      const index = slot.getAttribute('data-slot-index');
      if (index) {
        fetch(`https://${GetParentResourceName()}/selectTorso`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ index: parseInt(index, 10) }),
        });
      }
    });
  });

  // =============================================
  //  ADMIN : SÉLECTEUR D'ITEMS
  // =============================================
  let adminItemsData = [];
  let adminIsAllowed = false;

  const escapeHtml = (s) => String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

  const renderAdminItems = (list) => {
    const grid = document.getElementById('admin-items-grid');
    const counter = document.getElementById('admin-items-count');
    if (!grid) return;
    grid.innerHTML = '';
    list.forEach((it) => {
      const cell = document.createElement('div');
      // Taille 82x80 pour correspondre aux cases normales de l'inventaire
      cell.style.cssText = 'width:82px;height:80px;background:rgba(245,245,245,0.15);border-radius:2px;display:flex;align-items:center;justify-content:center;cursor:pointer;position:relative;transition:background-color 150ms ease;overflow:hidden;';
      cell.draggable = true;
      
      // On crée un conteneur inv-item pour réutiliser les styles CSS globaux (padding, centrage)
      const itemNode = document.createElement('div');
      itemNode.className = 'inv-item';
      itemNode.style.pointerEvents = 'none'; // Laisser la cellule gérer le drag

      const img = document.createElement('img');
      img.src = it.icon || '';
      img.style.width = '100%';
      img.style.height = '100%';
      img.style.objectFit = 'contain';
      img.onerror = () => { img.style.visibility = 'hidden'; };
      
      itemNode.appendChild(img);
      cell.appendChild(itemNode);

      const lbl = document.createElement('div');
      lbl.textContent = it.label || it.id;
      lbl.style.cssText = 'color:white;font-size:10px;font-family:Segoe UI,sans-serif;text-align:center;width:100%;padding:4px 2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;pointer-events:none;background:rgba(0,0,0,0.7);position:absolute;bottom:0;left:0;display:none;z-index:10;';
      cell.appendChild(lbl);

      cell.addEventListener('mouseenter', () => { 
        cell.style.backgroundColor = 'rgba(255,255,255,0.28)'; 
        lbl.style.display = 'block';
      });
      cell.addEventListener('mouseleave', () => { 
        cell.style.backgroundColor = 'rgba(245,245,245,0.15)'; 
        lbl.style.display = 'none';
      });

      cell.addEventListener('dragstart', (event) => {
        beginDrag({ fromType: 'admin', item: it }, event);
      });

      cell.addEventListener('click', () => giveAdminItem(it));

      grid.appendChild(cell);
    });
    if (counter) counter.textContent = list.length + ' item' + (list.length !== 1 ? 's' : '');
  };

  const filterAdminItems = (query) => {
    const q = String(query || '').trim().toLowerCase();
    if (!q) return renderAdminItems(adminItemsData);
    const filtered = adminItemsData.filter((it) =>
      (it.id || '').toLowerCase().includes(q) ||
      (it.label || '').toLowerCase().includes(q) ||
      (it.tags || []).some((t) => String(t).toLowerCase().includes(q))
    );
    renderAdminItems(filtered);
  };

  let pendingAdminItem = null;

  const closeAdminQty = () => {
    const overlay = document.getElementById('admin-qty-overlay');
    if (overlay) overlay.style.display = 'none';
    pendingAdminItem = null;
  };

  const confirmAdminQty = () => {
    if (!pendingAdminItem) return closeAdminQty();
    const input = document.getElementById('admin-qty-input');
    let qty = parseInt(input && input.value, 10);
    if (!qty || qty <= 0) qty = 1;
    if (qty > 1000) qty = 1000;
    const id = pendingAdminItem.id;
    closeAdminQty();
    fetch(`https://${GetParentResourceName()}/adminGiveItem`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: id, qty: qty }),
    });
  };

  const giveAdminItem = (item) => {
    pendingAdminItem = item;
    const overlay = document.getElementById('admin-qty-overlay');
    const sub = document.getElementById('admin-qty-sub');
    const input = document.getElementById('admin-qty-input');
    if (sub) sub.textContent = (item.label || item.id) + ' (' + item.id + ')';
    if (input) {
      input.value = '1';
      setTimeout(() => { input.focus(); input.select(); }, 30);
    }
    if (overlay) overlay.style.display = 'flex';
  };

  const renderAdminWeather = () => {
    const list = document.getElementById('admin-weather-list');
    if (!list) return;
    list.innerHTML = '';
    const weathers = [
      { id: 'EXTRASUNNY', label: 'Très Ensoleillé' },
      { id: 'CLEAR', label: 'Dégagé' },
      { id: 'NEUTRAL', label: 'Neutre' },
      { id: 'SMOG', label: 'Smog' },
      { id: 'FOGGY', label: 'Brouillard' },
      { id: 'OVERCAST', label: 'Couvert' },
      { id: 'CLOUDS', label: 'Nuageux' },
      { id: 'CLEARING', label: 'Éclaircies' },
      { id: 'RAIN', label: 'Pluie' },
      { id: 'THUNDER', label: 'Orage' },
      { id: 'SNOW', label: 'Neige' },
      { id: 'BLIZZARD', label: 'Blizzard' },
      { id: 'SNOWLIGHT', label: 'Neige Légère' },
      { id: 'XMAS', label: 'Noël' },
      { id: 'HALLOWEEN', label: 'Halloween' }
    ];

    weathers.forEach(w => {
      const div = document.createElement('div');
      div.className = 'admin-job-item'; // Réutilise le style des jobs
      div.innerHTML = `<div style="color:white; font-weight:600; font-size:14px; pointer-events:none;">${w.label}</div>`;
      div.addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/adminSetWeather`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ weather: w.id }),
        });
      });
      list.appendChild(div);
    });
  };

  // Wiring boutons modal (une seule fois)
  const adminQtyOk = document.getElementById('admin-qty-ok');
  const adminQtyCancel = document.getElementById('admin-qty-cancel');
  const adminQtyOverlay = document.getElementById('admin-qty-overlay');
  const adminQtyInput = document.getElementById('admin-qty-input');
  if (adminQtyOk) adminQtyOk.addEventListener('click', confirmAdminQty);
  if (adminQtyCancel) adminQtyCancel.addEventListener('click', closeAdminQty);
  if (adminQtyOverlay) adminQtyOverlay.addEventListener('click', (e) => { if (e.target === adminQtyOverlay) closeAdminQty(); });
  if (adminQtyInput) {
    adminQtyInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') { e.preventDefault(); confirmAdminQty(); }
      else if (e.key === 'Escape') { e.preventDefault(); closeAdminQty(); }
      e.stopPropagation();
    });
  }

  const btnAdminItems = document.getElementById('btn-admin-items');
  const btnBackAdminItems = document.getElementById('btn-back-admin-items');
  const adminItemsSide = document.getElementById('admin-items-side');
  const adminSearchInput = document.getElementById('admin-items-search');

  const adminHubSide = document.getElementById('admin-hub-side');
  const adminJobsSide = document.getElementById('admin-jobs-side');
  const btnBackAdminHub = document.getElementById('btn-back-admin-hub');
  const btnBackAdminJobs = document.getElementById('btn-back-admin-jobs');
  const btnHubClothes = document.getElementById('btn-hub-clothes');
  const btnHubItems = document.getElementById('btn-hub-items');
  const btnHubJobs = document.getElementById('btn-hub-jobs');
  const btnHubVehicles = document.getElementById('btn-hub-vehicles');
  const btnBackAdminVehicles = document.getElementById('btn-back-admin-vehicles');
  const btnAdminGiveKeys = document.getElementById('btn-admin-give-keys');
  const btnAdminShowVehicles = document.getElementById('btn-admin-show-vehicles');
  const btnHubPlayers = document.getElementById('btn-hub-players');
  const btnHubWeather = document.getElementById('btn-hub-weather');
  const adminJobsSearchInput = document.getElementById('admin-jobs-search');
  const btnBackAdminWeather = document.getElementById('btn-back-admin-weather');

  let adminJobsData = [];

  const toArray = v => Array.isArray(v) ? v : (v && typeof v === 'object' ? Object.values(v) : []);

  const renderAdminJobs = (jobs) => {
    const list = document.getElementById('admin-jobs-list');
    if (!list) return;
    list.innerHTML = '';
    const arr = toArray(jobs);
    console.log('[POP_INVENTORY][NUI] renderAdminJobs:', arr.length, 'jobs, raw:', JSON.stringify(jobs).slice(0, 200));
    if (arr.length === 0) {
      list.innerHTML = '<div style="color:rgba(255,255,255,0.5); padding:10px; font-style:italic; text-align:center;">Aucun job (liste vide)</div>';
      return;
    }
    try {
    arr.forEach(job => {
      if (!job || !job.name) return; // skip malformed
      const jobDiv = document.createElement('div');
      jobDiv.className = 'admin-job-item';
      const safeLabel = job.label || job.name;

      // Clic droit -> ouvre la modal de suppression
      jobDiv.addEventListener('contextmenu', (e) => {
        e.preventDefault();
        e.stopPropagation();
        if (job.name === 'unemployed') return; // safety : pas touchable
        document.getElementById('admin-delete-job-name').value = job.name;
        document.getElementById('admin-delete-job-sub').textContent = `${safeLabel} (${job.name})`;
        document.getElementById('admin-delete-job-overlay').style.display = 'flex';
      });

      jobDiv.innerHTML = `
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;">
          <div style="color:white; font-weight:600; font-size:14px; font-family:'Segoe UI', sans-serif;">
            ${safeLabel} <span style="color:rgba(255,255,245,0.4); font-size:11px; font-weight:400;">(${job.name})</span>
          </div>
          <div style="display:flex; gap:6px;">
            <div class="admin-job-action-btn admin-job-add-grade" data-job="${job.name}" data-label="${safeLabel}"
              style="cursor:pointer; background:rgba(0,180,120,0.25); border:1px solid rgba(0,180,120,0.4); border-radius:2px; padding:2px 6px; color:#fff; font-size:10px; font-weight:600; transition:background 0.2s;"
              title="Ajouter un Grade">+ Grade</div>
            <div class="admin-job-action-btn admin-job-add-money" data-job="${job.name}" data-label="${safeLabel}"
              style="cursor:pointer; background:rgba(0,120,240,0.25); border:1px solid rgba(0,120,240,0.4); border-radius:2px; padding:2px 6px; color:#fff; font-size:10px; font-weight:600; transition:background 0.2s;"
              title="Ajouter de l'argent">+ Argent</div>
          </div>
        </div>
      `;

      const gradesDiv = document.createElement('div');
      gradesDiv.style.cssText = 'display:flex; flex-wrap:wrap; gap:5px;';

      toArray(job.grades).forEach(grade => {
        if (!grade) return;
        const gradeBtn = document.createElement('div');
        gradeBtn.className = 'admin-grade-btn';
        gradeBtn.textContent = `${grade.label || grade.name || '?'} (${grade.grade})`;
        gradeBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          fetch(`https://${GetParentResourceName()}/adminSetJob`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ job: job.name, grade: grade.grade }),
          });
        });
        gradesDiv.appendChild(gradeBtn);
      });

      jobDiv.appendChild(gradesDiv);
      list.appendChild(jobDiv);
    });
    } catch (e) {
      console.error('[POP_INVENTORY][NUI] renderAdminJobs error:', e);
      list.innerHTML = '<div style="color:#ff7070; padding:10px;">Erreur rendu : ' + (e && e.message || e) + '</div>';
      return;
    }

    // Add click listeners to job action buttons
    document.querySelectorAll('.admin-job-add-grade').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const jobName = btn.getAttribute('data-job');
        const jobLabel = btn.getAttribute('data-label');
        
        document.getElementById('admin-add-grade-job').value = jobName;
        document.getElementById('admin-add-grade-title').textContent = `Ajouter un Grade - ${jobLabel}`;
        document.getElementById('admin-add-grade-level').value = 0;
        document.getElementById('admin-add-grade-name').value = '';
        document.getElementById('admin-add-grade-label').value = '';
        document.getElementById('admin-add-grade-salary').value = 100;
        
        document.getElementById('admin-add-grade-overlay').style.display = 'flex';
      });
    });

    document.querySelectorAll('.admin-job-add-money').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const jobName = btn.getAttribute('data-job');
        const jobLabel = btn.getAttribute('data-label');
        
        document.getElementById('admin-add-money-job').value = jobName;
        document.getElementById('admin-add-money-sub').textContent = `Entreprise : ${jobLabel} (${jobName})`;
        document.getElementById('admin-add-money-input').value = 10000;
        
        document.getElementById('admin-add-money-overlay').style.display = 'flex';
      });
    });
  };

  const filterAdminJobs = (query) => {
    const q = String(query || '').trim().toLowerCase();
    if (!q) return renderAdminJobs(adminJobsData);
    const filtered = adminJobsData.filter(j => 
      j.name.toLowerCase().includes(q) || 
      j.label.toLowerCase().includes(q)
    );
    renderAdminJobs(filtered);
  };

  if (adminJobsSearchInput) {
    adminJobsSearchInput.addEventListener('input', (e) => filterAdminJobs(e.target.value));
  }

  // Modals event handlers for jobs administration
  const btnAdminCreateJob = document.getElementById('btn-admin-create-job');
  if (btnAdminCreateJob) {
    btnAdminCreateJob.addEventListener('click', () => {
      document.getElementById('admin-create-job-name').value = '';
      document.getElementById('admin-create-job-label').value = '';
      document.getElementById('admin-create-job-overlay').style.display = 'flex';
    });
  }
  
  const btnCreateJobCancel = document.getElementById('admin-create-job-cancel');
  if (btnCreateJobCancel) {
    btnCreateJobCancel.addEventListener('click', () => {
      document.getElementById('admin-create-job-overlay').style.display = 'none';
    });
  }
  
  const btnCreateJobConfirm = document.getElementById('admin-create-job-confirm');
  if (btnCreateJobConfirm) {
    btnCreateJobConfirm.addEventListener('click', () => {
      const name = document.getElementById('admin-create-job-name').value.trim();
      const label = document.getElementById('admin-create-job-label').value.trim();
      
      if (!name || !label) return;
      
      fetch(`https://${GetParentResourceName()}/adminCreateJob`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: name, label: label }),
      }).then(() => {
        // Le serveur appelle sendUpdatedJobsList automatiquement après l'INSERT.
        // Pas de refresh manuel ici, sinon race condition : son SELECT peut lire
        // avant le commit et écraser la bonne liste avec une stale.
        document.getElementById('admin-create-job-overlay').style.display = 'none';
      });
    });
  }

  const btnAddGradeCancel = document.getElementById('admin-add-grade-cancel');
  if (btnAddGradeCancel) {
    btnAddGradeCancel.addEventListener('click', () => {
      document.getElementById('admin-add-grade-overlay').style.display = 'none';
    });
  }

  const btnAddGradeConfirm = document.getElementById('admin-add-grade-confirm');
  if (btnAddGradeConfirm) {
    btnAddGradeConfirm.addEventListener('click', () => {
      const job = document.getElementById('admin-add-grade-job').value;
      const level = parseInt(document.getElementById('admin-add-grade-level').value) || 0;
      const name = document.getElementById('admin-add-grade-name').value.trim();
      const label = document.getElementById('admin-add-grade-label').value.trim();
      const salary = parseInt(document.getElementById('admin-add-grade-salary').value) || 0;

      if (!job || !name || !label) return;

      fetch(`https://${GetParentResourceName()}/adminAddGrade`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ job: job, level: level, name: name, label: label, salary: salary }),
      }).then(() => {
        // Le serveur appelle sendUpdatedJobsList automatiquement après l'INSERT.
        document.getElementById('admin-add-grade-overlay').style.display = 'none';
      });
    });
  }

  const btnDeleteJobCancel = document.getElementById('admin-delete-job-cancel');
  if (btnDeleteJobCancel) {
    btnDeleteJobCancel.addEventListener('click', () => {
      document.getElementById('admin-delete-job-overlay').style.display = 'none';
    });
  }

  const btnDeleteJobConfirm = document.getElementById('admin-delete-job-confirm');
  if (btnDeleteJobConfirm) {
    btnDeleteJobConfirm.addEventListener('click', () => {
      const jobName = document.getElementById('admin-delete-job-name').value;
      if (!jobName) return;
      fetch(`https://${GetParentResourceName()}/adminDeleteJob`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ job: jobName }),
      }).then(() => {
        document.getElementById('admin-delete-job-overlay').style.display = 'none';
      });
    });
  }

  const btnAddMoneyCancel = document.getElementById('admin-add-money-cancel');
  if (btnAddMoneyCancel) {
    btnAddMoneyCancel.addEventListener('click', () => {
      document.getElementById('admin-add-money-overlay').style.display = 'none';
    });
  }

  const btnAddMoneyConfirm = document.getElementById('admin-add-money-confirm');
  if (btnAddMoneyConfirm) {
    btnAddMoneyConfirm.addEventListener('click', () => {
      const job = document.getElementById('admin-add-money-job').value;
      const amount = parseInt(document.getElementById('admin-add-money-input').value) || 0;

      if (!job || amount <= 0) return;

      fetch(`https://${GetParentResourceName()}/adminAddSocietyMoney`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ job: job, amount: amount }),
      }).then(() => {
        document.getElementById('admin-add-money-overlay').style.display = 'none';
      });
    });
  }

  if (btnAdminItems) {
    btnAdminItems.addEventListener('mouseenter', () => { btnAdminItems.style.backgroundColor = 'rgba(255,120,120,0.45)'; });
    btnAdminItems.addEventListener('mouseleave', () => { btnAdminItems.style.backgroundColor = 'rgba(255,90,90,0.28)'; });
    btnAdminItems.addEventListener('click', () => {
      if (adminHubSide) openPanel('admin-hub-side');
    });
  }

  if (btnBackAdminHub) {
    btnBackAdminHub.addEventListener('click', goBack);
  }

  if (btnHubClothes) {
    btnHubClothes.addEventListener('mouseenter', () => btnHubClothes.style.background = 'rgba(245,245,245,0.25)');
    btnHubClothes.addEventListener('mouseleave', () => btnHubClothes.style.background = 'rgba(245,245,245,0.15)');
    btnHubClothes.addEventListener('click', () => {
      fetch(`https://${GetParentResourceName()}/action`, { method: 'POST', body: JSON.stringify({ type: 'close' }) });
      fetch(`https://${GetParentResourceName()}/adminOpenClotheShop`, { method: 'POST', body: JSON.stringify({}) });
    });
  }

  if (btnHubItems) {
    btnHubItems.addEventListener('mouseenter', () => btnHubItems.style.background = 'rgba(245,245,245,0.25)');
    btnHubItems.addEventListener('mouseleave', () => btnHubItems.style.background = 'rgba(245,245,245,0.15)');
    btnHubItems.addEventListener('click', () => {
      openPanel('admin-items-side');
      renderAdminItems(adminItemsData);
      if (adminSearchInput) { adminSearchInput.value = ''; setTimeout(() => adminSearchInput.focus(), 30); }
      fetch(`https://${GetParentResourceName()}/adminRequestItems`, { method: 'POST', body: JSON.stringify({}) });
    });
  }

  if (btnHubJobs) {
    btnHubJobs.addEventListener('mouseenter', () => btnHubJobs.style.background = 'rgba(245,245,245,0.25)');
    btnHubJobs.addEventListener('mouseleave', () => btnHubJobs.style.background = 'rgba(245,245,245,0.15)');
    btnHubJobs.addEventListener('click', () => {
      openPanel('admin-jobs-side');
      fetch(`https://${GetParentResourceName()}/adminRequestJobs`, { method: 'POST', body: JSON.stringify({}) });
    });
  }

  const btnAdminRefreshJobs = document.getElementById('btn-admin-refresh-jobs');
  if (btnAdminRefreshJobs) {
    btnAdminRefreshJobs.addEventListener('mouseenter', () => { btnAdminRefreshJobs.style.backgroundColor = 'rgba(0,120,215,0.5)'; });
    btnAdminRefreshJobs.addEventListener('mouseleave', () => { btnAdminRefreshJobs.style.backgroundColor = 'rgba(0,120,215,0.3)'; });
    btnAdminRefreshJobs.addEventListener('click', () => {
      btnAdminRefreshJobs.style.transform = 'rotate(360deg)';
      btnAdminRefreshJobs.style.transition = 'transform 0.5s ease-in-out';
      setTimeout(() => {
        btnAdminRefreshJobs.style.transform = 'none';
        btnAdminRefreshJobs.style.transition = 'none';
      }, 500);
      fetch(`https://${GetParentResourceName()}/adminRequestJobs`, { method: 'POST', body: JSON.stringify({}) });
    });
  }

  if (btnHubVehicles) {
    btnHubVehicles.addEventListener('click', () => {
      openPanel('admin-vehicles-side');
    });
  }

  if (btnBackAdminVehicles) {
    btnBackAdminVehicles.addEventListener('click', goBack);
  }

  if (btnAdminGiveKeys) {
    btnAdminGiveKeys.addEventListener('mouseenter', () => btnAdminGiveKeys.style.background = 'rgba(245,245,245,0.20)');
    btnAdminGiveKeys.addEventListener('mouseleave', () => btnAdminGiveKeys.style.background = 'rgba(245,245,245,0.12)');
    btnAdminGiveKeys.addEventListener('click', () => {
      fetch(`https://${GetParentResourceName()}/adminGiveVehicleKeys`, { method: 'POST', body: JSON.stringify({}) });
    });
  }

  if (btnAdminShowVehicles) {
    btnAdminShowVehicles.addEventListener('mouseenter', () => btnAdminShowVehicles.style.background = 'rgba(245,245,245,0.20)');
    btnAdminShowVehicles.addEventListener('mouseleave', () => btnAdminShowVehicles.style.background = 'rgba(245,245,245,0.12)');
    btnAdminShowVehicles.addEventListener('click', () => {
      fetch(`https://${GetParentResourceName()}/adminToggleShowVehicles`, { method: 'POST', body: JSON.stringify({}) });
    });
  }

  const btnAdminShowCasings = document.getElementById('btn-admin-show-casings');
  if (btnAdminShowCasings) {
    btnAdminShowCasings.addEventListener('mouseenter', () => btnAdminShowCasings.style.background = 'rgba(245,245,245,0.20)');
    btnAdminShowCasings.addEventListener('mouseleave', () => btnAdminShowCasings.style.background = 'rgba(245,245,245,0.12)');
    btnAdminShowCasings.addEventListener('click', () => {
      fetch(`https://${GetParentResourceName()}/adminToggleShowCasings`, { method: 'POST', body: JSON.stringify({}) });
    });
  }

  if (btnHubPlayers) {
    btnHubPlayers.addEventListener('mouseenter', () => btnHubPlayers.style.background = 'rgba(245,245,245,0.25)');
    btnHubPlayers.addEventListener('mouseleave', () => btnHubPlayers.style.background = 'rgba(245,245,245,0.15)');
    btnHubPlayers.addEventListener('click', () => {
      console.log('Admin: Ouvrir menu personnages');
      fetch(`https://${GetParentResourceName()}/adminOpenPlayers`, { method: 'POST', body: JSON.stringify({}) });
    });
  }

  if (btnHubWeather) {
    btnHubWeather.addEventListener('mouseenter', () => btnHubWeather.style.background = 'rgba(245,245,245,0.25)');
    btnHubWeather.addEventListener('mouseleave', () => btnHubWeather.style.background = 'rgba(245,245,245,0.15)');
    btnHubWeather.addEventListener('click', () => {
      openPanel('admin-weather-side');
      renderAdminWeather();
    });
  }

  if (btnBackAdminWeather) {
    btnBackAdminWeather.addEventListener('click', goBack);
  }

  // ===== EASYTIME : contrôle de l'heure (onglet Météo) =====
  (() => {
    const display = document.getElementById('admin-time-display');
    const hourSlider = document.getElementById('admin-time-hour');
    const minSlider = document.getElementById('admin-time-minute');
    const hourVal = document.getElementById('admin-time-hour-val');
    const minVal = document.getElementById('admin-time-min-val');
    const segBtns = document.querySelectorAll('#admin-time-seg .et-seg-btn');
    if (!hourSlider || !minSlider) return;

    const state = { hour: 12, minute: 0, frozen: true };
    const pad = (n) => String(n).padStart(2, '0');
    // Remplit la piste du slider (variable CSS --p) jusqu'au pouce.
    const fill = (slider) => {
      const max = parseFloat(slider.max) || 1;
      slider.style.setProperty('--p', `${(parseFloat(slider.value) / max) * 100}%`);
    };
    const refresh = () => {
      if (display) display.textContent = `${pad(state.hour)}:${pad(state.minute)}`;
      if (hourVal) hourVal.textContent = `${state.hour} h`;
      if (minVal) minVal.textContent = `${pad(state.minute)} min`;
      fill(hourSlider);
      fill(minSlider);
      // Preset actif si l'heure correspond pile (et minute = 0).
      document.querySelectorAll('.admin-time-preset').forEach((el) => {
        el.classList.toggle('active', state.minute === 0 && parseInt(el.dataset.h, 10) === state.hour);
      });
    };
    const sendTime = () => {
      fetch(`https://${GetParentResourceName()}/adminSetTime`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ hour: state.hour, minute: state.minute }),
      });
    };

    // input -> MAJ affichage en direct ; change (relâché) -> envoi serveur (anti-spam).
    hourSlider.addEventListener('input', () => { state.hour = parseInt(hourSlider.value, 10) || 0; refresh(); });
    minSlider.addEventListener('input', () => { state.minute = parseInt(minSlider.value, 10) || 0; refresh(); });
    hourSlider.addEventListener('change', sendTime);
    minSlider.addEventListener('change', sendTime);

    document.querySelectorAll('.admin-time-preset').forEach((el) => {
      el.addEventListener('click', () => {
        state.hour = parseInt(el.dataset.h, 10) || 0;
        state.minute = 0;
        hourSlider.value = state.hour;
        minSlider.value = 0;
        refresh();
        sendTime();
      });
    });

    // Segmented control Figé / Réel.
    const applySeg = () => {
      segBtns.forEach((b) => {
        const isThis = (b.dataset.frozen === '1') === state.frozen;
        b.classList.toggle('active', isThis);
        b.classList.toggle('run', isThis && !state.frozen); // segment "Réel" actif -> vert
      });
    };
    segBtns.forEach((b) => {
      b.addEventListener('click', () => {
        const wantFrozen = b.dataset.frozen === '1';
        if (wantFrozen === state.frozen) return;
        state.frozen = wantFrozen;
        applySeg();
        fetch(`https://${GetParentResourceName()}/adminFreezeTime`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ frozen: state.frozen }),
        });
      });
    });

    applySeg();
    refresh();
  })();

  if (btnBackAdminJobs) {
    btnBackAdminJobs.addEventListener('click', goBack);
  }

  if (btnBackAdminItems) {
    btnBackAdminItems.addEventListener('click', goBack);
  }

  if (adminSearchInput) {
    adminSearchInput.addEventListener('input', (e) => filterAdminItems(e.target.value));
  }

  document.addEventListener('keydown', (event) => {
    // TAB (ou I) referme l'inventaire, comme il l'a ouvert — sauf pendant une saisie.
    const tag = (event.target && event.target.tagName) || '';
    const typing = tag === 'INPUT' || tag === 'TEXTAREA' || (event.target && event.target.isContentEditable);
    const isToggleKey = event.key === 'Tab' || ((event.key === 'i' || event.key === 'I') && !typing);
    if (isToggleKey && !event.repeat) {
      event.preventDefault();
      if (typing && event.key === 'Tab') event.target.blur();
      const sFrame = document.getElementById('standby-frame');
      if (sFrame && sFrame.style.display === 'block') {
        fetch(`https://${GetParentResourceName()}/standbyClose`, { method: 'POST' });
      }
      fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
      return;
    }
    if (event.key === 'Escape') {
      event.preventDefault();
      const sFrame = document.getElementById('standby-frame');
      if (sFrame && sFrame.style.display === 'block') {
        fetch(`https://${GetParentResourceName()}/standbyClose`, { method: 'POST' });
      }
      fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
    }
  });

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  document.addEventListener('mousemove', handlePointerMove, true);
  document.addEventListener('mouseup', handlePointerUp, true);
  document.addEventListener('click', handleClickCapture, true);

  document.addEventListener('dragover', (event) => {
    if (dragPreview) {
      updateDragPreview(event);
    }
    if (dragState && dragState.fromType === 'admin' && event.clientX < 1040) {
      event.preventDefault();
    }
  }, true);

  document.addEventListener('drop', (event) => {
    removeDragPreview();
    if (dragState && dragState.fromType === 'admin') {
      if (event.clientX < 1040) {
        fetch(`https://${GetParentResourceName()}/adminGiveItem`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ id: dragState.item.id, qty: 1 }),
        });
      }
      endDrag();
    }
  }, true);

  // ============================================================
  // CRAFT SYSTEM
  // ============================================================
  let craftRecipes = [];
  let craftRecipeIndex = 0;

  const craftSideEl = document.getElementById('craft-side');
  const btnBackCraft = document.getElementById('btn-back-craft');
  const craftItemImg = document.getElementById('craft-item-img');
  const craftItemName = document.getElementById('craft-item-name');
  const craftIngText = document.getElementById('craft-ingredients-text');
  const craftCounter = document.getElementById('craft-recipe-counter');
  const craftPrevBtn = document.getElementById('craft-prev');
  const craftNextBtn = document.getElementById('craft-next');
  const craftValidateBtn = document.getElementById('craft-btn-validate');
  const craftSlotEls = [
    document.getElementById('craft-slot-0'),
    document.getElementById('craft-slot-1'),
    document.getElementById('craft-slot-2'),
  ];

  const countIngredient = (defId) => {
    let count = 0;
    for (const container of Object.values(state.containers || {})) {
      for (const item of Object.values(container.items || {})) {
        if (item && item.defId === defId) count += (item.qty || 1);
      }
    }
    for (const item of Object.values(state.equipment || {})) {
      if (item && item.defId === defId) count += (item.qty || 1);
    }
    return count;
  };

  const renderCraft = () => {
    if (!craftSideEl || craftSideEl.style.display === 'none') return;
    if (!craftRecipes.length) return;
    const recipe = craftRecipes[craftRecipeIndex];

    if (craftCounter) craftCounter.textContent = `${craftRecipeIndex + 1} / ${craftRecipes.length}`;

    if (craftItemImg) {
      craftItemImg.src = recipe.output.icon ? `https://cfx-nui-pop_inventory/html/${recipe.output.icon}` : '';
    }
    if (craftItemName) {
      craftItemName.textContent = recipe.output.label || recipe.output.defId;
    }

    if (craftIngText) {
      const lines = (recipe.ingredients || []).map(ing => {
        const label = ing.label || ing.defId;
        const have = countIngredient(ing.defId);
        const color = have >= ing.qty ? 'rgba(160,240,160,0.9)' : 'rgba(255,140,140,0.9)';
        return `<span style="color:${color}">• ${label} x${ing.qty} (${have}/${ing.qty})</span>`;
      });
      craftIngText.innerHTML = lines.join('<br>');
    }

    craftSlotEls.forEach((el, i) => {
      if (!el) return;
      el.innerHTML = '';
      el.className = 'craft-slot';
      const ing = (recipe.ingredients || [])[i];
      if (!ing) return;

      const have = countIngredient(ing.defId);
      const hasEnough = have >= ing.qty;

      if (ing.icon) {
        const img = document.createElement('img');
        img.src = `https://cfx-nui-pop_inventory/html/${ing.icon}`;
        img.style.cssText = 'width:58px;height:58px;object-fit:contain;pointer-events:none;';
        el.appendChild(img);
      }
      const qtyEl = document.createElement('div');
      qtyEl.className = 'craft-qty';
      qtyEl.textContent = `${Math.min(have, ing.qty)}/${ing.qty}`;
      el.appendChild(qtyEl);

      el.classList.add(hasEnough ? 'has-item' : 'missing-item');
    });

    if (craftValidateBtn) {
      const canCraft = (recipe.ingredients || []).every(ing => countIngredient(ing.defId) >= ing.qty);
      craftValidateBtn.classList.toggle('craft-disabled', !canCraft);
    }
  };

  const openCraftPanel = (recipes) => {
    craftRecipes = recipes || [];
    craftRecipeIndex = 0;
    openPanel('craft-side');
    renderCraft();
  };

  const closeCraftPanel = () => {
    goBack();
  };

  if (btnBackCraft) {
    btnBackCraft.addEventListener('click', closeCraftPanel);
  }

  if (craftPrevBtn) {
    craftPrevBtn.addEventListener('click', () => {
      if (!craftRecipes.length) return;
      craftRecipeIndex = (craftRecipeIndex - 1 + craftRecipes.length) % craftRecipes.length;
      renderCraft();
    });
  }

  if (craftNextBtn) {
    craftNextBtn.addEventListener('click', () => {
      if (!craftRecipes.length) return;
      craftRecipeIndex = (craftRecipeIndex + 1) % craftRecipes.length;
      renderCraft();
    });
  }

  if (craftValidateBtn) {
    craftValidateBtn.addEventListener('click', () => {
      if (!craftRecipes.length) return;
      if (craftValidateBtn.classList.contains('craft-disabled')) return;
      const recipe = craftRecipes[craftRecipeIndex];
      fetch(`https://${GetParentResourceName()}/craft`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ recipeId: recipe.id }),
      });
    });
  }

  // ============================================================
  // SHOP SYSTEM
  // ============================================================
  let shopItems = [];
  let selectedShopItem = null;
  let shopCategory = "LTD";

  const shopSideEl = document.getElementById('shop-side');
  const btnBackShop = document.getElementById('btn-back-shop');
  const shopGridEl = document.getElementById('shop-items-grid');
  const shopTitleEl = document.getElementById('shop-title');
  const shopPurchasePanel = document.getElementById('shop-purchase-panel');
  const shopSelectedName = document.getElementById('shop-selected-name');
  const shopUnitPricelEl = document.getElementById('shop-selected-unit-price');
  const shopTotalPriceEl = document.getElementById('shop-selected-total-price');
  const shopTotalUnitEl = document.getElementById('shop-total-unit');
  const shopQtyInput = document.getElementById('shop-qty-input');
  const shopPaymentMethod = document.getElementById('shop-payment-method');
  const shopBuyBtn = document.getElementById('shop-btn-buy');

  const updateShopTotal = () => {
    if (!selectedShopItem) return;
    const qty = parseInt(shopQtyInput.value, 10) || 1;
    const totalDollars = qty * selectedShopItem.price;
    shopTotalPriceEl.textContent = totalDollars;
    if (shopTotalUnitEl) shopTotalUnitEl.textContent = '$';
  };

  const renderShop = () => {
    if (!shopSideEl || shopSideEl.style.display === 'none') return;
    
    if (shopTitleEl) shopTitleEl.textContent = shopCategory;
    shopGridEl.innerHTML = '';

    shopItems.forEach((item, index) => {
      const slot = document.createElement('div');
      slot.className = 'shop-item-slot';
      if (selectedShopItem && selectedShopItem.id === item.id) {
          slot.classList.add('selected');
      }

      const img = document.createElement('img');
      img.src = item.icon ? (item.icon.startsWith('http') ? item.icon : `https://cfx-nui-pop_inventory/html/${item.icon}`) : '';
      img.style.cssText = 'width:60px;height:60px;object-fit:contain;pointer-events:none;';
      slot.appendChild(img);

      const price = document.createElement('div');
      price.className = 'shop-item-price';
      price.textContent = `${item.price}$`;
      slot.appendChild(price);

      slot.addEventListener('click', () => {
        selectedShopItem = item;
        shopSelectedName.textContent = item.label || item.id;
        shopSelectedName.style.color = 'white';
        updateShopTotal();
        renderShop();
      });

      shopGridEl.appendChild(slot);
    });
  };

  const openShopPanel = (category, items) => {
    shopCategory = category || "Boutique";
    shopItems = items || [];
    selectedShopItem = null;
    shopQtyInput.value = 1;

    // Paiement : cash ou banque (plus de pesos sur le serveur)
    if (shopPaymentMethod) {
      shopPaymentMethod.value = 'cash';
    }

    if (shopSelectedName) {
      shopSelectedName.textContent = "Sélectionnez un article";
      shopSelectedName.style.color = "rgba(255,255,255,0.4)";
    }
    if (shopTotalPriceEl) {
      shopTotalPriceEl.textContent = "0";
    }
    if (shopTotalUnitEl) {
      shopTotalUnitEl.textContent = "$";
    }

    openPanel('shop-side');

    renderShop();
  };

  const closeShopPanel = () => {
    goBack();
  };

  if (btnBackShop) {
    btnBackShop.addEventListener('click', closeShopPanel);
  }

  if (shopQtyInput) {
    shopQtyInput.addEventListener('input', updateShopTotal);
  }

  if (shopPaymentMethod) {
    shopPaymentMethod.addEventListener('change', updateShopTotal);
  }

  if (shopBuyBtn) {
    shopBuyBtn.addEventListener('click', () => {
      if (!selectedShopItem) return;
      const qty = parseInt(shopQtyInput.value, 10) || 1;
      const method = shopPaymentMethod.value;
      
      fetch(`https://${GetParentResourceName()}/shopBuy`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
            shopId: shopCategory,
            itemId: selectedShopItem.id,
            qty: qty,
            paymentMethod: method
        }),
      });
    });
  }

})();
