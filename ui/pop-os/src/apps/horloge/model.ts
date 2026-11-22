// Horloge : calculs purs (maquette Horloge.dc.html). Heure du jeu, cadrans, chronomètre, minuteur, répétition des alarmes.

export const p2 = (n: number): string => String(n).padStart(2, '0');

export interface Zone { name: string; offset: number }
/** Horloges du monde fictives : décalage en heures sur l'heure locale du joueur. */
export const ZONES: Zone[] = [
  { name: 'Los Santos', offset: 0 },
  { name: 'Liberty City', offset: 3 },
  { name: 'Vice City', offset: 3 },
  { name: 'Paris', offset: 9 },
];

export function polar(deg: number, r: number): { x: number; y: number } {
  const rad = (deg * Math.PI) / 180;
  return { x: +(100 + r * Math.sin(rad)).toFixed(1), y: +(100 - r * Math.cos(rad)).toFixed(1) };
}

export interface Face {
  h: number; m: number; digital: string; night: boolean; dayDiff: number;
  hx: number; hy: number; mx: number; my: number; sx: number; sy: number; tx: number; ty: number;
}

/** Cadran d'une zone : aiguilles de l'heure, des minutes, de la trotteuse et sa queue. */
export function faceOf(gameMs: number, offsetHours: number): Face {
  const d = new Date(gameMs + offsetHours * 3_600_000);
  const h = d.getUTCHours();
  const m = d.getUTCMinutes();
  const sec = d.getUTCSeconds() + d.getUTCMilliseconds() / 1000;
  const hp = polar(((h % 12) + m / 60) * 30, 52);
  const mp = polar((m + sec / 60) * 6, 76);
  const sp = polar(sec * 6, 84);
  const tp = polar(sec * 6 + 180, 18);
  const dayDiff = Math.floor((gameMs + offsetHours * 3_600_000) / 86_400_000) - Math.floor(gameMs / 86_400_000);
  return { h, m, digital: `${p2(h)}:${p2(m)}`, night: h < 6 || h >= 18, dayDiff, hx: hp.x, hy: hp.y, mx: mp.x, my: mp.y, sx: sp.x, sy: sp.y, tx: tp.x, ty: tp.y };
}

/** Chronomètre : MM:SS,cc */
export function fmtSw(ms: number): string {
  const cs = Math.floor(ms / 10) % 100;
  const sec = Math.floor(ms / 1000) % 60;
  const mi = Math.floor(ms / 60_000);
  return `${p2(mi)}:${p2(sec)},${p2(cs)}`;
}

export interface Lap { n: number; d: number; kind: 'best' | 'worst' | 'normal' }

/** Durées de chaque tour (le plus récent en premier) ; meilleur et pire marqués à partir de trois tours. */
export function lapRows(totals: number[]): Lap[] {
  const laps: Lap[] = [];
  let prev = 0;
  totals.forEach((tot, i) => { laps.push({ n: i + 1, d: tot - prev, kind: 'normal' }); prev = tot; });
  if (laps.length > 2) {
    const best = Math.min(...laps.map((l) => l.d));
    const worst = Math.max(...laps.map((l) => l.d));
    for (const l of laps) l.kind = l.d === best ? 'best' : l.d === worst ? 'worst' : 'normal';
  }
  return laps.reverse();
}

/** Minuteur : H:MM:SS au-delà d'une heure, sinon MM:SS. */
export function timerText(totalSeconds: number): string {
  const s = Math.max(0, Math.ceil(totalSeconds));
  return s >= 3600 ? `${Math.floor(s / 3600)}:${p2(Math.floor(s / 60) % 60)}:${p2(s % 60)}` : `${p2(Math.floor(s / 60))}:${p2(s % 60)}`;
}

/** Durées proposées (secondes). */
export const PRESETS = [60, 300, 600, 900, 1800, 3600];
export const TIMER_MIN = 60;
export const TIMER_MAX = 5940;

export function clampTotal(sec: number): number {
  return Math.min(TIMER_MAX, Math.max(TIMER_MIN, sec));
}

/** Masque de répétition : bit 0 = lundi ... bit 6 = dimanche. */
export const WEEKDAYS = 0b0011111;
export const WEEKEND = 0b1100000;
export const EVERY = 0b1111111;

export type RepKind = 'never' | 'daily' | 'weekdays' | 'weekend' | 'custom';
export function repKind(mask: number): RepKind {
  return mask === 0 ? 'never' : mask === EVERY ? 'daily' : mask === WEEKDAYS ? 'weekdays' : mask === WEEKEND ? 'weekend' : 'custom';
}

export const hasDay = (mask: number, day: number): boolean => (mask & (1 << day)) !== 0;
export const toggleDay = (mask: number, day: number): number => mask ^ (1 << day);

/** Alarmes triées par heure. */
export interface Alarm { id: number; label: string; minute: number; mask: number; enabled: boolean }
export function sortAlarms(list: Alarm[]): Alarm[] {
  return [...list].sort((a, b) => a.minute - b.minute || a.id - b.id);
}
