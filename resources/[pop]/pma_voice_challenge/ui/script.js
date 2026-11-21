const container = document.getElementById('container');
const voiceBar = document.getElementById('voice-bar');
const persuasionBar = document.getElementById('persuasion-bar');
const timerDigits = document.getElementById('timer-digits');

let isTalking = false;
let currentVolume = 0;
let targetVolume = 0;

let persuasion = 0;
let timeLeft = 10.0;
let isActive = false;
let lastTimestamp = 0;

window.addEventListener('message', function (event) {
    const data = event.data;

    if (data.action === 'show') {
        container.style.display = 'block';
        resetChallenge();
        isActive = true;
        lastTimestamp = performance.now();
    } else if (data.action === 'hide') {
        container.style.display = 'none';
        isActive = false;
        isTalking = false;
        voiceBar.style.width = '0%';
    } else if (data.action === 'voiceStatus') {
        isTalking = data.talking;
        targetVolume = isTalking ? (60 + Math.random() * 40) : 0;
    } else if (data.action === 'voiceVolume') {
        targetVolume = data.volume * 100;
        isTalking = targetVolume > 0;
    }
});

function resetChallenge() {
    persuasion = 0;
    timeLeft = 10.0;
    updatePersuasionUI();
    updateTimerUI();
}

function updatePersuasionUI() {
    persuasionBar.style.width = `${Math.min(100, persuasion)}%`;
}

function updateTimerUI() {
    timerDigits.innerText = timeLeft.toFixed(2);
}

function updateLoop(timestamp) {
    if (isActive) {
        const deltaTime = (timestamp - lastTimestamp) / 1000;
        lastTimestamp = timestamp;

        // Timer countdown
        if (timeLeft > 0) {
            timeLeft -= deltaTime;
            if (timeLeft < 0) {
                timeLeft = 0;
                isActive = false;
                onChallengeEnd(false);
            }
            updateTimerUI();
        }

        // Persuasion increase if talking
        if (isTalking && timeLeft > 0) {
            // Increase persuasion slowly. 
            // 100% in ~10-15 seconds of speaking?
            persuasion += deltaTime * 20; // 100% in 5 seconds of speaking

            if (persuasion >= 100) {
                persuasion = 100;
                isActive = false;
                onChallengeEnd(true);
            }
            updatePersuasionUI();
        }
    }

    // Smoothen the volume transition for the voice bar
    currentVolume += (targetVolume - currentVolume) * 0.15;
    let displayVolume = currentVolume;
    if (isTalking && currentVolume > 10) {
        displayVolume += (Math.random() - 0.5) * 10;
    }

    voiceBar.style.width = `${Math.max(0, Math.min(100, displayVolume))}%`;

    if (isTalking && displayVolume > 5) {
        voiceBar.classList.add('talking-animation');
    } else {
        voiceBar.classList.remove('talking-animation');
    }

    requestAnimationFrame(updateLoop);
}

function onChallengeEnd(success) {
    if (success) {
        persuasionBar.style.boxShadow = '0 0 30px #f44336';
        timerDigits.style.color = '#4caf50';
    } else {
        timerDigits.style.color = '#f44336';
    }

    // Auto hide after 2 seconds
    setTimeout(() => {
        fetch(`https://${GetParentResourceName()}/finish`, {
            method: 'POST',
            body: JSON.stringify({ success })
        });
        container.style.display = 'none';
        isActive = false;
    }, 2000);
}

requestAnimationFrame(updateLoop);

// Debug if needed
// window.postMessage({action: 'show'}, '*');
// window.postMessage({action: 'voiceStatus', talking: true}, '*');
