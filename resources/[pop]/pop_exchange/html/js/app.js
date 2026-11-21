let currentMode = 'usd'; // 'usd' = usd -> pesos, 'pesos' = pesos -> usd
let rates = { UsdToPesos: 20.0, PesosToUsd: 0.045 };
let balances = { cash: 0, pesos: 0 };
let translations = {};

window.addEventListener('message', function (event) {
    const data = event.data;
    if (data.type === "toggle") {
        if (data.display) {
            document.getElementById('app').style.display = 'flex';
            if (data.rates) rates = data.rates;
            if (data.balances) balances = data.balances;
            if (data.translate) {
                translations = data.translate;
                applyTranslations();
            }
            updateBalances();
            updateMode();
            document.getElementById('exchange-amount').value = '';
            document.getElementById('payout-lbl').innerText = '0 ₱';
        } else {
            document.getElementById('app').style.display = 'none';
        }
    }
});

function applyTranslations() {
    if (translations.menu_title) {
        document.getElementById('menu-title').innerText = translations.menu_title;
    }
}

function updateBalances() {
    document.getElementById('val-cash').innerText = `${formatNumber(balances.cash)} $`;
    document.getElementById('val-pesos').innerText = `${formatNumber(balances.pesos)} ₱`;
}

function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ");
}

function updateMode() {
    const amountInput = document.getElementById('exchange-amount');
    const currencyLbl = document.getElementById('input-currency-lbl');
    const rateLbl = document.getElementById('rate-lbl');

    if (currentMode === 'usd') {
        currencyLbl.innerText = '$';
        rateLbl.innerText = `1 $ = ${rates.UsdToPesos} ₱`;
    } else {
        currencyLbl.innerText = '₱';
        rateLbl.innerText = `1 ₱ = ${rates.PesosToUsd} $`;
    }

    calculatePayout();
}

function calculatePayout() {
    const amount = parseFloat(document.getElementById('exchange-amount').value) || 0;
    const payoutLbl = document.getElementById('payout-lbl');

    if (amount <= 0) {
        payoutLbl.innerText = currentMode === 'usd' ? '0 ₱' : '0 $';
        return;
    }

    if (currentMode === 'usd') {
        const result = Math.floor(amount * rates.UsdToPesos);
        payoutLbl.innerText = `${formatNumber(result)} ₱`;
    } else {
        const result = Math.floor(amount * rates.PesosToUsd);
        payoutLbl.innerText = `${formatNumber(result)} $`;
    }
}

// Tab handlers
document.getElementById('tab-usd-to-pesos').addEventListener('click', function() {
    document.getElementById('tab-pesos-to-usd').classList.remove('active');
    this.classList.add('active');
    currentMode = 'usd';
    updateMode();
});

document.getElementById('tab-pesos-to-usd').addEventListener('click', function() {
    document.getElementById('tab-usd-to-pesos').classList.remove('active');
    this.classList.add('active');
    currentMode = 'pesos';
    updateMode();
});

// Real-time calculation
document.getElementById('exchange-amount').addEventListener('input', calculatePayout);

function closeMenu() {
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

function submitExchange() {
    const amountVal = document.getElementById('exchange-amount').value;
    const amount = parseFloat(amountVal);

    if (!amount || amount <= 0) {
        return;
    }

    fetch(`https://${GetParentResourceName()}/exchange`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            from: currentMode,
            amount: amount
        })
    })
    .then(resp => resp.json())
    .then(data => {
        if (data && data.status === 'success') {
            balances.cash = data.balances.cash;
            balances.pesos = data.balances.pesos;
            updateBalances();
            document.getElementById('exchange-amount').value = '';
            calculatePayout();
        }
    });
}

// Close on ESC key
window.addEventListener('keydown', function (event) {
    if (event.key === "Escape") {
        closeMenu();
    }
});
