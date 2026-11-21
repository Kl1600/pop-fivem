const container = document.getElementById('container');
const voiceBar = document.getElementById('voice-bar');

let currentVolume = 0;
let targetVolume = 0;
let isTalking = false;
let running = false;

window.addEventListener('message', function (event) {
    const data = event.data;

    if (data.action === 'show') {
        container.style.display = 'block';
        if (!running) { running = true; requestAnimationFrame(loop); }
    } else if (data.action === 'hide') {
        container.style.display = 'none';
        isTalking = false;
        targetVolume = 0;
        currentVolume = 0;
        voiceBar.style.width = '0%';
        running = false;
    } else if (data.action === 'voiceLevel') {
        targetVolume = data.volume * 100;
        isTalking = (targetVolume > 0);
    }
});

function loop() {
    if (!running) return; // pas d'animation quand l'UI est cachée
    // Smooth transition
    currentVolume += (targetVolume - currentVolume) * 0.15;

    // Add some noise if talking to make it look active
    let displayVolume = currentVolume;
    if (isTalking && currentVolume > 10) {
        displayVolume += (Math.random() - 0.5) * 15;
    }

    // Limits
    displayVolume = Math.max(0, Math.min(100, displayVolume));

    voiceBar.style.width = displayVolume + '%';

    if (isTalking && displayVolume > 5) {
        voiceBar.classList.add('talking');
    } else {
        voiceBar.classList.remove('talking');
    }

    requestAnimationFrame(loop);
}
