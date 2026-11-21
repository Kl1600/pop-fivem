(function () {
    const root         = document.getElementById('root');
    const card         = root.querySelector('.deal-card');
    const elIcon       = document.getElementById('deal-icon');
    const elTitle      = document.getElementById('deal-title');
    const elBadge      = document.getElementById('deal-badge');
    const elQty        = document.getElementById('deal-qty');
    const elHint       = document.getElementById('deal-hint');
    const elTotal      = document.getElementById('deal-total');
    const elPrice      = document.getElementById('deal-price-input');
    const elPriceDisp  = document.getElementById('deal-price-display');
    const elGaugeFill  = document.getElementById('deal-gauge-fill');
    const elGaugeMark  = document.getElementById('deal-gauge-mark');
    const elGaugeMin   = document.getElementById('deal-gauge-min');
    const elGaugeMax   = document.getElementById('deal-gauge-max');
    const elAttempts   = document.getElementById('deal-attempts');
    const elAttemptsMax = document.getElementById('deal-attempts-max');
    const elFeedback   = document.getElementById('deal-feedback');
    const btnPropose   = card.querySelector('.deal-btn.accept');
    const btnRefuse    = card.querySelector('.deal-btn.refuse');

    // Bornes de la jauge en multiplicateur du prix marché
    const GAUGE_MIN_MULT = 0.5;
    const GAUGE_MAX_MULT = 2.0;

    let currentId  = null;
    let currentQty = 1;
    let hintUnit   = 0;
    let gaugeMin   = 1;
    let gaugeMax   = 1;

    function post(name, data) {
        const rn = window.GetParentResourceName ? GetParentResourceName() : 'pop_dealing';
        fetch(`https://${rn}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    function updateTotal() {
        const v = Math.max(0, parseInt(elPrice.value, 10) || 0);
        elPriceDisp.textContent = '$' + v;
        elTotal.textContent     = '$' + (v * currentQty);
        // remplissage de la jauge
        const pct = gaugeMax > gaugeMin
            ? Math.min(1, Math.max(0, (v - gaugeMin) / (gaugeMax - gaugeMin)))
            : 0;
        elGaugeFill.style.width = (pct * 100) + '%';
    }

    function setupGauge(hint) {
        gaugeMin = Math.max(1, Math.floor(hint * GAUGE_MIN_MULT));
        gaugeMax = Math.max(gaugeMin + 1, Math.ceil(hint * GAUGE_MAX_MULT));
        elPrice.min = gaugeMin;
        elPrice.max = gaugeMax;
        elPrice.value = hint;
        elGaugeMin.textContent = '$' + gaugeMin;
        elGaugeMax.textContent = '$' + gaugeMax;
        // position du marqueur "marché"
        const markPct = gaugeMax > gaugeMin ? (hint - gaugeMin) / (gaugeMax - gaugeMin) : 0.5;
        elGaugeMark.style.left = (markPct * 100) + '%';
    }

    function setFeedback(text, kind) {
        elFeedback.textContent = text || '';
        elFeedback.classList.remove('refuse', 'accept');
        if (kind) elFeedback.classList.add(kind);
    }

    function setLocked(locked) {
        btnPropose.disabled = locked;
        btnRefuse.disabled  = locked;
        elPrice.disabled    = locked;
    }

    function show(offer) {
        currentId  = offer.id;
        currentQty = offer.qty || 1;
        hintUnit   = offer.hintUnit || 0;

        elIcon.className   = offer.icon || 'fas fa-cannabis';
        elTitle.textContent = offer.label || 'Drogue';
        elBadge.textContent = 'DEAL';
        elQty.textContent   = 'x' + currentQty;
        elHint.textContent  = '$' + hintUnit;
        setupGauge(hintUnit);
        updateTotal();
        elAttempts.textContent = offer.attemptsLeft;
        elAttemptsMax.textContent = offer.maxAttempts;
        setFeedback('');
        setLocked(false);

        root.classList.remove('hidden');
        card.classList.remove('closing', 'shake');
    }

    function hide() {
        if (currentId === null) return;
        currentId = null;
        card.classList.add('closing');
        setTimeout(() => {
            root.classList.add('hidden');
            card.classList.remove('closing');
            setFeedback('');
        }, 250);
    }

    btnPropose.addEventListener('click', () => {
        if (!currentId) return;
        const price = Math.max(1, parseInt(elPrice.value, 10) || 0);
        setLocked(true);
        setFeedback('Il réfléchit...', '');
        post('propose', { id: currentId, unitPrice: price });
    });

    btnRefuse.addEventListener('click', () => {
        if (!currentId) return;
        post('refuse', { id: currentId });
        hide();
    });

    elPrice.addEventListener('input', updateTotal);

    document.addEventListener('keyup', (e) => {
        if (!currentId) return;
        if (e.key === 'Escape') {
            post('refuse', { id: currentId });
            hide();
        }
    });

    window.addEventListener('message', (ev) => {
        const d = ev.data;
        if (!d || !d.action) return;
        if (d.action === 'show') show(d.offer || {});
        if (d.action === 'hide') hide();
        if (d.action === 'result') {
            if (d.status === 'accept') {
                setFeedback('Marché conclu.', 'accept');
                setTimeout(hide, 600);
            } else if (d.status === 'refuse') {
                card.classList.remove('shake');
                void card.offsetWidth;
                card.classList.add('shake');
                setFeedback('Trop cher pour lui.', 'refuse');
                elAttempts.textContent = d.attemptsLeft;
                setLocked(false);
            } else if (d.status === 'walkaway') {
                setFeedback('Il s\'est barré.', 'refuse');
                setTimeout(hide, 900);
            } else if (d.status === 'cancel') {
                hide();
            }
        }
    });
})();
