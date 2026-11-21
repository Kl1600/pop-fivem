const MAX_HEALTH_WIDTH = 272;
const MAX_VBAR_HEIGHT  = 82;

let bigmapHidden = false;

const healthBar  = document.getElementById('healthBar');
const foodFill   = document.getElementById('foodFill');
const waterFill  = document.getElementById('waterFill');
const clockEl    = document.getElementById('clock');
const hudEl      = document.getElementById('statusHud');
const v1         = document.getElementById('voice1');
const v2         = document.getElementById('voice2');
const v3         = document.getElementById('voice3');
const signalEl   = document.getElementById('signal');

window.addEventListener('message', function(event) {
	const data = event.data;

	switch (data.action) {
		case 'updateStatusHud':
			hudEl.style.display = (data.show && !bigmapHidden) ? 'block' : 'none';

			// Health bar width + color
			const hp = Math.max(0, Math.min(100, data.health));
			healthBar.style.width = (hp / 100 * MAX_HEALTH_WIDTH) + 'px';
			healthBar.style.borderBottomRightRadius = (hp >= 99) ? '3px' : '0px';

			if (hp <= 33) {
				healthBar.style.background = 'linear-gradient(90deg, rgba(224,31,31,0.9), rgba(194,26,32,0.9))';
			} else if (hp <= 66) {
				healthBar.style.background = 'linear-gradient(90deg, rgba(251,188,4,0.9), rgba(248,148,39,0.9))';
			} else {
				healthBar.style.background = '#64d442ff';
			}

			// Water (soif, blue left bar)
			if (data.water !== undefined) {
				const waterPercent = Math.max(0, Math.min(100, data.water));
				waterFill.style.width = (waterPercent / 100 * MAX_VBAR_HEIGHT) + 'px';
				waterFill.style.borderTopRightRadius = (waterPercent >= 99) ? '3px' : '0px';
			}

			// Food (faim, orange right bar)
			if (data.food !== undefined) {
				const foodPercent = Math.max(0, Math.min(100, data.food));
				foodFill.style.width = (foodPercent / 100 * MAX_VBAR_HEIGHT) + 'px';
				foodFill.style.borderBottomRightRadius = (foodPercent >= 99) ? '3px' : '0px';
			}

			// Clock
			if (data.hours !== undefined) {
				const h = String(data.hours).padStart(2, '0');
				const m = String(data.minutes).padStart(2, '0');
				clockEl.textContent = h + 'h' + m;
			}

			// Voice Mode (Signal)
			if (data.voiceMode !== undefined) {
				v1.style.opacity = (data.voiceMode >= 1) ? '0.8' : '0.2';
				v2.style.opacity = (data.voiceMode >= 2) ? '0.8' : '0.2';
				v3.style.opacity = (data.voiceMode >= 3) ? '0.8' : '0.2';

				signalEl.style.fill = data.isTalking ? '#2aad0a' : 'white';
			}
			break;

		case 'hideUI':
			bigmapHidden = true;
			hudEl.style.display = 'none';
			break;

		case 'displayUI':
			bigmapHidden = false;
			hudEl.style.display = 'block';
			break;

		case 'updateAdminOverlay':
			updateAdminOverlay(data);
			break;

		case 'showChecklist':
			const checklist = document.getElementById('mechanicChecklist');
			if (checklist) {
				checklist.style.display = data.show ? 'block' : 'none';
			}
			break;
	}
});

// ── Mechanic Checklist ────────────────────────────────────────────────────────
window.closeChecklist = () => {
	const checklist = document.getElementById('mechanicChecklist');
	if (checklist) {
		checklist.style.display = 'none';
	}
	$.post('https://pop_hud/closeChecklist', JSON.stringify({}));
};

// ── Admin Overlay ─────────────────────────────────────────────────────────────

const grades = {
	1: { name: "Game Master",   color: "#15803d" },
	2: { name: "Modérateur",    color: "#C40155" },
	3: { name: "Support",       color: "#d97706" },
	4: { name: "Développeur",   color: "#3b82f6" },
	5: { name: "Staff",         color: "#fb7185" },
};

const reportColors = ["#10b981", "#ca8a04", "#f97316", "#dc2626"];

const getReportColor = (n) => {
	if (n >= 20) return reportColors[3];
	if (n >= 10) return reportColors[2];
	if (n >= 5)  return reportColors[1];
	return reportColors[0];
};

const updateAdminOverlay = (data) => {
	const overlay = document.querySelector('.AdminOverlay');
	const countEl = document.querySelector('.AdminOverlay #activeReports span');
	overlay.style.display = data.show ? 'flex' : 'none';
	countEl.textContent   = data.activeReports || 0;
	countEl.style.color   = getReportColor(data.activeReports);
};
