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
export function beginMenu() {
  card = document.createElement("div");
  card.className = "pop-target";
  card.innerHTML = `
    <div class="pop-target-head">
      <span class="circle"><svg width="11" height="11" fill="currentColor" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512"><path fill="currentColor" d="M128 40c0-22.1 17.9-40 40-40s40 17.9 40 40l0 148.2c8.5-7.6 19.7-12.2 32-12.2 20.6 0 38.2 13 45 31.2 8.8-9.3 21.2-15.2 35-15.2 25.3 0 46 19.5 47.9 44.3 8.5-7.7 19.8-12.3 32.1-12.3 26.5 0 48 21.5 48 48l0 112c0 70.7-57.3 128-128 128l-85.3 0c-5 0-9.9-.3-14.7-1-55.3-5.6-106.2-34-140-79L8 336c-13.3-17.7-9.7-42.7 8-56s42.7-9.7 56 8l56 74.7 0-322.7zM240 304c0-8.8-7.2-16-16-16s-16 7.2-16 16l0 96c0 8.8 7.2 16 16 16s16-7.2 16-16l0-96zm48-16c-8.8 0-16 7.2-16 16l0 96c0 8.8 7.2 16 16 16s16-7.2 16-16l0-96c0-8.8-7.2-16-16-16zm80 16c0-8.8-7.2-16-16-16s-16 7.2-16 16l0 96c0 8.8 7.2 16 16 16s16-7.2 16-16l0-96z"/></svg></span>
      <span class="title">Interactions</span>
      <span class="count"></span>
    </div>`;
  list = document.createElement("div");
  card.appendChild(list);
  count = 0;
}

export function endMenu() {
  if (!card) return;
  if (count > 0) {
    card.querySelector(".count").textContent = String(count);
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
