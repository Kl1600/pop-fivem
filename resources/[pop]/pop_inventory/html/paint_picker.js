/* ============================================================
   PISTOLET A PEINTURE - Selecteur de couleur (Addon Inventaire)
   Remplace la section vêtements dans l'inventaire pop_inventory.
   ============================================================ */
(function () {
  function resName() {
    return (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pop_inventory';
  }
  function post(name, data) {
    const url = `https://${resName()}/${name}`;
    console.log("[PAINT_PICKER] Fetching NUI callback:", url, JSON.stringify(data));
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {})
    })
    .then(resp => console.log("[PAINT_PICKER] Fetch response status:", resp.status))
    .catch((err) => {
      console.error("[PAINT_PICKER] Fetch error:", err);
    });
  }

  const paintSide = document.getElementById('paint-side');
  const clothesSide = document.getElementById('clothes-side');
  const torsoSide = document.getElementById('torso-grid-side');
  const adminSide = document.getElementById('admin-hub-side');
  
  const backBtn = document.getElementById('btn-back-paint');
  const gridEl = document.getElementById('paint-items-grid');
  
  const detailsPanel = document.getElementById('paint-details-panel');
  const selectedName = document.getElementById('paint-selected-name');
  const costRed = document.getElementById('paint-cost-red');
  const costYellow = document.getElementById('paint-cost-yellow');
  const costBlue = document.getElementById('paint-cost-blue');
  const applyBtn = document.getElementById('paint-btn-apply');

  let colorsList = [];
  let selectedColor = null;

  // Catégorisation des couleurs
  function categorize(colors) {
    const categories = {
      metallic: [],
      red: [],
      green: [],
      blue: [],
      special: []
    };

    for (const c of colors) {
      const idx = c.index;
      if (idx >= 0 && idx <= 14) {
        categories.metallic.push(c);
      } else if (idx >= 27 && idx <= 38) {
        categories.red.push(c);
      } else if (idx === 88 || idx === 89 || (idx >= 39 && idx <= 59)) {
        categories.green.push(c);
      } else if (idx >= 61 && idx <= 82) {
        categories.blue.push(c);
      } else {
        categories.special.push(c);
      }
    }
    return categories;
  }

  const scrollThumb = document.getElementById('paint-scroll-thumb');
  const scrollRail = document.getElementById('paint-scroll-rail');

  function updateThumbPosition() {
    if (!gridEl || !scrollThumb) return;
    const railTop = 88;
    const railHeight = 441;
    const maxScroll = gridEl.scrollHeight - gridEl.clientHeight;
    const thumbHeight = scrollThumb.offsetHeight || 214;
    const maxThumbY = railTop + (railHeight - thumbHeight);
    if (maxScroll <= 0) {
      scrollThumb.style.top = `${railTop}px`;
      return;
    }
    const scrollRatio = gridEl.scrollTop / maxScroll;
    const newY = railTop + scrollRatio * (maxThumbY - railTop);
    scrollThumb.style.top = `${newY}px`;
  }

  if (gridEl && scrollThumb) {
    gridEl.addEventListener('scroll', updateThumbPosition);
    window.addEventListener('resize', updateThumbPosition);
    window.addEventListener('inventoryUpdated', updateThumbPosition);

    let isDragging = false;
    let startY = 0;
    let startThumbTop = 88;

    const onPointerMove = (e) => {
      if (!isDragging) return;
      const railTop = 88;
      const railHeight = 441;
      const thumbHeight = scrollThumb.offsetHeight || 214;
      const maxThumbY = railTop + (railHeight - thumbHeight);
      const deltaY = e.clientY - startY;
      let newTop = startThumbTop + deltaY;
      if (newTop < railTop) newTop = railTop;
      if (newTop > maxThumbY) newTop = maxThumbY;
      
      scrollThumb.style.top = `${newTop}px`;

      const scrollRatio = (newTop - railTop) / (maxThumbY - railTop);
      const maxScroll = gridEl.scrollHeight - gridEl.clientHeight;
      gridEl.scrollTop = scrollRatio * maxScroll;
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
      startThumbTop = parseFloat(scrollThumb.style.top) || 88;
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
        const railTop = 88;
        const railHeight = 441;
        const thumbHeight = scrollThumb.offsetHeight || 214;
        const maxThumbY = railTop + (railHeight - thumbHeight);
        
        let newTop = railTop + clickY - (thumbHeight / 2);
        if (newTop < railTop) newTop = railTop;
        if (newTop > maxThumbY) newTop = maxThumbY;

        scrollThumb.style.top = `${newTop}px`;
        const scrollRatio = (newTop - railTop) / (maxThumbY - railTop);
        const maxScroll = gridEl.scrollHeight - gridEl.clientHeight;
        gridEl.scrollTop = scrollRatio * maxScroll;

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

  // Rendu des couleurs dans la grille (flat, sans catégorie)
  function render() {
    if (!gridEl) return;
    gridEl.innerHTML = '';

    colorsList.forEach(c => {
      const slot = document.createElement('div');
      slot.className = 'paint-item-slot';
      slot.title = `${c.name} (R:${c.cr} J:${c.cj} B:${c.cb})`;

      if (selectedColor && selectedColor.index === c.index) {
        slot.classList.add('selected');
      }

      const bubble = document.createElement('div');
      bubble.className = 'color-bubble';
      bubble.style.background = `rgb(${c.r}, ${c.g}, ${c.b})`;
      slot.appendChild(bubble);

      slot.addEventListener('click', () => {
        selectedColor = c;
        
        // Mettre à jour la classe selected sur le DOM
        const allSlots = gridEl.querySelectorAll('.paint-item-slot');
        allSlots.forEach(s => s.classList.remove('selected'));
        slot.classList.add('selected');

        updateSelectedDetails();
      });

      gridEl.appendChild(slot);
    });

    // Recalculate scrollbar thumb size and position
    setTimeout(updateThumbPosition, 50);
  }

  function updateSelectedDetails() {
    if (!selectedColor) {
      if (selectedName) {
        selectedName.textContent = 'Sélectionnez une peinture';
        selectedName.style.color = 'rgba(255,255,255,0.4)';
      }
      if (costRed) costRed.innerHTML = `0 <span style="font-size: 9px; color: rgba(255,255,255,0.4); font-weight: normal;">/ 0</span>`;
      if (costYellow) costYellow.innerHTML = `0 <span style="font-size: 9px; color: rgba(255,255,255,0.4); font-weight: normal;">/ 0</span>`;
      if (costBlue) costBlue.innerHTML = `0 <span style="font-size: 9px; color: rgba(255,255,255,0.4); font-weight: normal;">/ 0</span>`;
      if (applyBtn) {
        applyBtn.style.opacity = '0.5';
        applyBtn.style.cursor = 'not-allowed';
        applyBtn.style.background = '#777777';
      }
      return;
    }
    
    const c = selectedColor;
    if (selectedName) {
      selectedName.textContent = c.name;
      selectedName.style.color = 'white';
    }

    // Récupérer le stock du joueur via la fonction globale de app.js
    const ownedRed = window.getInventoryItemCount ? window.getInventoryItemCount('peinture_rouge') : 0;
    const ownedYellow = window.getInventoryItemCount ? window.getInventoryItemCount('peinture_jaune') : 0;
    const ownedBlue = window.getInventoryItemCount ? window.getInventoryItemCount('peinture_bleue') : 0;

    console.log("[PAINT_PICKER] Selected:", c.name, "Cost: R=" + c.cr + ", J=" + c.cj + ", B=" + c.cb);
    console.log("[PAINT_PICKER] Owned stocks: R=" + ownedRed + ", J=" + ownedYellow + ", B=" + ownedBlue);

    if (costRed) {
      costRed.innerHTML = `${c.cr} <span style="font-size: 9px; color: ${ownedRed >= c.cr ? 'rgba(255,255,255,0.6)' : '#ff5252'}; font-weight: normal;">/ ${ownedRed}</span>`;
    }
    if (costYellow) {
      costYellow.innerHTML = `${c.cj} <span style="font-size: 9px; color: ${ownedYellow >= c.cj ? 'rgba(255,255,255,0.6)' : '#ff5252'}; font-weight: normal;">/ ${ownedYellow}</span>`;
    }
    if (costBlue) {
      costBlue.innerHTML = `${c.cb} <span style="font-size: 9px; color: ${ownedBlue >= c.cb ? 'rgba(255,255,255,0.6)' : '#ff5252'}; font-weight: normal;">/ ${ownedBlue}</span>`;
    }

    const canPaint = (ownedRed >= c.cr && ownedYellow >= c.cj && ownedBlue >= c.cb);
    console.log("[PAINT_PICKER] canPaint evaluated as:", canPaint);
    if (applyBtn) {
      if (canPaint) {
        applyBtn.style.opacity = '1.0';
        applyBtn.style.cursor = 'pointer';
        applyBtn.style.background = '#5695C8';
      } else {
        applyBtn.style.opacity = '0.5';
        applyBtn.style.cursor = 'not-allowed';
        applyBtn.style.background = '#777777';
      }
    }
  }

  function open(data) {
    if (document.body) {
      document.body.style.display = 'flex';
    }
    if (window.openPanel) {
      window.openPanel('paint-side');
    } else {
      if (clothesSide) clothesSide.style.display = 'none';
      if (torsoSide) torsoSide.style.display = 'none';
      if (adminSide) adminSide.style.display = 'none';
      if (paintSide) paintSide.style.display = 'block';
    }
    
    colorsList = data.colors || [];
    selectedColor = null;
    updateSelectedDetails();

    render();
    setTimeout(updateThumbPosition, 100);
  }

  function close() {
    if (window.openPanel) {
      window.openPanel('clothes-side');
    } else {
      if (paintSide) paintSide.style.display = 'none';
      if (clothesSide) clothesSide.style.display = 'block';
    }
    selectedColor = null;
  }

  // Clic sur le bouton de retour
  if (backBtn) {
    backBtn.addEventListener('click', () => {
      close();
      post('paintClose', {});
    });
  }

  // Clic sur le bouton appliquer
  if (applyBtn) {
    applyBtn.addEventListener('click', () => {
      if (!selectedColor) return;
      // IMPORTANT : capturer l'index AVANT close() (close remet selectedColor à null).
      const idx = selectedColor.index;
      close();
      post('paintSelect', { index: idx });
    });
  }

  // Touche Échap pour fermer (uniquement si le panneau peinture est affiché)
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && paintSide && paintSide.style.display === 'block') {
      close();
      post('paintClose', {});
    }
  });

  // Écoute de l'événement de mise à jour de l'inventaire pour actualiser le stock en temps réel
  window.addEventListener('inventoryUpdated', () => {
    if (paintSide && paintSide.style.display === 'block') {
      updateSelectedDetails();
    }
  });

  window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    if (d.action === 'paintOpen') {
      open(d);
    } else if (d.action === 'paintClose') {
      close();
    }
  });
})();
