import { fetchNui } from "./fetchNui.js";

const optionsWrapper = document.getElementById("options-wrapper");
let card = null;
let list = null;
let count = 0;

function onClick() {
  // when nuifocus is disabled after a click, the hover event is never released
  this.style.pointerEvents = "none";

  fetchNui("select", [this.targetType, this.targetId, this.zoneId]);
  setTimeout(() => (this.style.pointerEvents = "auto"), 100);
}

function escapeHtml(text) {
  return String(text ?? "").replace(/[&<>"']/g, (c) => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]
  ));
}

// Carte POP : en-tête « Interactions » + liste des options.
export function beginMenu(identity) {
  card = document.createElement("div");
  card.className = "pop-target";
  card.innerHTML = `
    <div class="pop-target-head">
      <span class="title">Interactions</span>
      <span class="count"></span>
    </div>`;
  card.querySelector(".title").textContent = (identity && identity.name) || "Interactions";
  card.querySelector(".count").textContent = identity && identity.id != null ? `ID ${identity.id}` : "";
  list = document.createElement("div");
  card.appendChild(list);
  count = 0;
}

export function endMenu() {
  if (!card) return;
  if (count > 0) {
    optionsWrapper.appendChild(card);
  }
  card = null;
  list = null;
}

export function createOptions(type, data, id, zoneId) {
  if (data.hide) return;
  if (!card) beginMenu();

  const isBack = data.openMenu === "home";
  const option = document.createElement("div");
  const icon = document.createElement("i");
  icon.className = `fa-fw ${data.icon || "fa-solid fa-circle"} option-icon`;
  if (data.iconColor) icon.style.color = data.iconColor;

  option.className = "option-container" + (isBack ? " back" : "");
  option.appendChild(icon);
  option.insertAdjacentHTML("beforeend", `<p class="option-label">${escapeHtml(data.label)}</p>`);
  if (data.openMenu && !isBack) {
    option.insertAdjacentHTML("beforeend", '<i class="fa-solid fa-chevron-right option-arrow"></i>');
  }

  option.targetType = type;
  option.targetId = id;
  option.zoneId = zoneId;
  option.addEventListener("click", onClick);
  list.appendChild(option);
  if (!isBack) count++;
}
