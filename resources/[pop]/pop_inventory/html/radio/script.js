// Radio importée dans pop_inventory : les fetch ciblent la resource parente.
let resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pop_inventory'

$(function(){
    let radioOpen = false
    window.addEventListener('message', (event) => {
        if (event.data.type == 'showradio'){
            radioOpen = !radioOpen
            if (event.data.toggle === true) {
                $('.radioUI').show()
            } else {
                $('.radioUI').hide()
            }
        } else if (event.data.type === 'setFrequence'){
            $('.radioState').html(event.data.data)
        } else if (event.data.type === 'showIconsRadioOn') {
            $('#radioHZ').show()
            $('#radioNetwork').show()
        } else if (event.data.type === 'showMuteIcon'){
            if (event.data.toggle) {
                $('#radioMute').show()
                $('#radioRec').hide()
            } else {
                $('#radioRec').show()
                $('#radioMute').hide()
            }
        } else if (event.data.type === 'radioSkin'){
            // Config.RadioSkin : '80s' (SECURECOM rétro) ou 'modern' (défaut)
            $('.radioUI').toggleClass('skin-80s', event.data.skin === '80s')
        }
    });

    window.addEventListener('keydown', (e) => {
        if (e.keyCode == 80 || e.keyCode == 27) {
            $.post(`https://${resourceName}/closeRadio`)
        }
    })

});

$('#radioManual').click(() => {
    if (typeof window.showInputModal === 'function') {
        let currentFreq = $('.radioState').text() || '';
        window.showInputModal('Fréquence Radio', currentFreq, (frequence) => {
            $.post(`https://${resourceName}/setRadioFreq`, JSON.stringify({ frequence: frequence }));
        }, 'number');
    } else {
        $.post(`https://${resourceName}/requestFreq`);
    }
})

$('#radioButtonMute').click(() => {
    $.post(`https://${resourceName}/muteRadio`)
})

$("#radioToggle").click(() => {
    $('.radioState').html('')
    $('#radioRec').hide()
    $('#radioMute').hide()
    $('#radioHZ').hide()
    $('#radioNetwork').hide()
    $.post(`https://${resourceName}/offRadio`)
})

$('#radioUP').click(() => {
    $.post(`https://${resourceName}/volumeUp`)
})

$('#radioDown').click(() => {
    $.post(`https://${resourceName}/volumeDown`)
})

// ===== Skin 80s (SECURECOM) : les boutons rejouent les mêmes actions =====
function radio80sManual() {
    if (typeof window.showInputModal === 'function') {
        let currentFreq = $('.radioState').text() || '';
        window.showInputModal('Fréquence Radio', currentFreq, (frequence) => {
            $.post(`https://${resourceName}/setRadioFreq`, JSON.stringify({ frequence: frequence }));
        }, 'number');
    } else {
        $.post(`https://${resourceName}/requestFreq`);
    }
}
$('#r80_man').click(radio80sManual)
$('#r80_ok').click(radio80sManual)
$('#r80_up').click(() => { $.post(`https://${resourceName}/volumeUp`) })
$('#r80_down').click(() => { $.post(`https://${resourceName}/volumeDown`) })
$('#r80_mute').click(() => { $.post(`https://${resourceName}/muteRadio`) })
$('#r80_power').click(() => {
    $('.radioState').html('')
    $('#radioRec').hide()
    $('#radioMute').hide()
    $('#radioHZ').hide()
    $('#radioNetwork').hide()
    $.post(`https://${resourceName}/offRadio`)
})

window.addEventListener('message', function(e) {
    $("#container").stop(false, true);
    if (e.data.type == 'IconRadio'){
        if (e.data.toggle === true) {
            $("#container").css('display', 'none');
        } else {
            $("#container").css('display', 'flex');
        }
    }
});