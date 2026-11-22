import { createOptions, beginMenu, endMenu } from "./createOptions.js";

const optionsWrapper = document.getElementById("options-wrapper");
const body = document.body;
const eye = document.getElementById("eye");

let isTargetActive = false;
let isChecklistActive = false;

function updateBodyVisibility() {
  body.style.visibility = (isTargetActive || isChecklistActive) ? "visible" : "hidden";
}

window.closeChecklist = () => {
  // On NE masque PAS localement : le serveur décide (fermeture seulement si toutes
  // les tâches sont faites, sinon il renvoie showChecklist:true pour garder le menu).
  fetch(`https://${GetParentResourceName()}/closeChecklist`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json; charset=UTF-8",
    },
    body: JSON.stringify({}),
  });
};

document.addEventListener("DOMContentLoaded", () => {
  const closeBtn = document.querySelector(".checklist-close");
  if (closeBtn) {
    closeBtn.addEventListener("click", window.closeChecklist);
  }
});

window.addEventListener("message", (event) => {
  if (event.data.event !== "showChecklist") {
    optionsWrapper.innerHTML = "";
  }

  switch (event.data.event) {
    case "visible": {
      isTargetActive = event.data.state;
      updateBodyVisibility();
      const eyeEl = document.getElementById("eye");
      if (eyeEl) eyeEl.style.visibility = isTargetActive ? "visible" : "hidden";
      optionsWrapper.style.visibility = isTargetActive ? "visible" : "hidden";
      return eye.classList.remove("eye-hover");
    }

    case "leftTarget": {
      return eye.classList.remove("eye-hover");
    }

    case "setTarget": {
      eye.classList.add("eye-hover");
      beginMenu(event.data.identity);

      if (event.data.options) {
        for (const type in event.data.options) {
          event.data.options[type].forEach((data, id) => {
            createOptions(type, data, id + 1);
          });
        }
      }

      if (event.data.zones) {
        for (let i = 0; i < event.data.zones.length; i++) {
          event.data.zones[i].forEach((data, id) => {
            createOptions("zones", data, id + 1, i + 1);
          });
        }
      }
      endMenu();
      break;
    }

    case "showChecklist": {
      const checklist = document.getElementById("mechanicChecklist");
      isChecklistActive = event.data.show;
      if (checklist) {
        checklist.style.display = isChecklistActive ? "block" : "none";
        if (isChecklistActive && event.data.items) {
          const listContainer = checklist.querySelector(".checklist-items");
          if (listContainer) {
            listContainer.innerHTML = "";
            event.data.items.forEach(item => {
              const li = document.createElement("li");
              li.className = "checklist-item" + (item.done ? " done" : "");

              const checkbox = document.createElement("span");
              checkbox.className = "checkbox";
              checkbox.textContent = item.done ? "✓" : "☐";

              li.appendChild(checkbox);
              li.appendChild(document.createTextNode(" " + item.label));
              listContainer.appendChild(li);
            });
          }
        }
      }

      const eyeEl = document.getElementById("eye");
      updateBodyVisibility();
      if (isChecklistActive) {
        if (eyeEl) eyeEl.style.visibility = "hidden";
        optionsWrapper.style.visibility = "hidden";
        // Mesure la hauteur réelle de la liste et place les notifications juste
        // au-dessus (s'adapte à n'importe quel nombre de tâches).
        if (checklist) {
          requestAnimationFrame(() => {
            const rect = checklist.getBoundingClientRect();
            const bottom = Math.round(window.innerHeight - rect.top + 12);
            fetch(`https://${GetParentResourceName()}/checklistLayout`, {
              method: "POST",
              headers: { "Content-Type": "application/json; charset=UTF-8" },
              body: JSON.stringify({ bottom: bottom }),
            }).catch(() => {});
          });
        }
      } else {
        if (eyeEl) eyeEl.style.visibility = isTargetActive ? "visible" : "hidden";
        optionsWrapper.style.visibility = isTargetActive ? "visible" : "hidden";
      }
      break;
    }
  }
});
