// ============================================================
//  pop_passport — affichage NUI (page unique imprimée)
// ============================================================

function renderPassport(d, type) {
    var isMx = (type === 'mx');
    var p = isMx ? 'mx' : 'us';

    document.getElementById(p + '-lastname').textContent  = (d.lastname || '').toUpperCase();
    document.getElementById(p + '-firstname').textContent = (d.firstname || '').toUpperCase();
    document.getElementById(p + '-sex').textContent       = d.sex || '';
    document.getElementById(p + '-dob').textContent       = d.dob || '';
    document.getElementById(p + '-expiry').textContent    = d.expiry || '';
    document.getElementById(p + '-number').textContent    = d.number || '';

    // Signature : prénom + nom en écriture manuscrite
    var sign = ((d.firstname || '') + ' ' + (d.lastname || '')).trim();
    document.getElementById(p + '-sign').textContent = sign;

    // Pas de photo du titulaire : on masque l'image, le fond par défaut reste visible
    var photoSrc = d.headshot ? ('https://nui-img/' + d.headshot + '/' + d.headshot) : (d.photo || '');
    var photoEl = document.getElementById('player-photo-' + p);
    photoEl.setAttribute('src', photoSrc);
    photoEl.style.visibility = photoSrc ? 'visible' : 'hidden';

    if (isMx) {
        $('#passport-container').addClass('show-mx');
    } else {
        $('#passport-container').removeClass('show-mx');
    }
    $('#passport-container').fadeIn(280);
}

$(document).ready(function () {
    window.addEventListener('message', function (event) {
        var msg = event.data;
        if (msg.action === 'show') {
            renderPassport(msg.data, msg.type || msg.data.type || 'us');
        } else if (msg.action === 'hide') {
            $('#passport-container').fadeOut(150);
        }
    });

    $(document).on('keyup', function (e) {
        if (e.keyCode === 27 || e.keyCode === 13) {
            $('#passport-container').fadeOut(150);
            $.post('https://pop_passport/close', JSON.stringify({}));
        }
    });

    // ---- Aperçu navigateur (npx serve / python http) : données bidon ----
    if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
        var demoUs = {
            lastname: 'Mercer', firstname: 'Jonathan David', sex: 'M',
            dob: '14 MARS 1991', expiry: '01 FÉV 2034', number: 'A04827193',
            photo: 'https://i.pravatar.cc/300?img=12'
        };
        var demoMx = {
            lastname: 'Reyes Salazar', firstname: 'María Fernanda', sex: 'F',
            dob: '08 NOV 1995', expiry: '19 MAI 2035', number: 'G19483072',
            photo: 'https://i.pravatar.cc/300?img=45'
        };
        var showingMx = false;
        function preview() { renderPassport(showingMx ? demoMx : demoUs, showingMx ? 'mx' : 'us'); }
        preview();
        document.addEventListener('click', function () { showingMx = !showingMx; preview(); });
    }
});
