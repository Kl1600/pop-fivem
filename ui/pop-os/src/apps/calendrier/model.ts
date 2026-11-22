// Calendrier : calculs purs (maquette Calendrier.dc.html). Toutes les dates sont des clés 'AAAA-MM-JJ' du jeu, calculées en UTC.
export interface CalEvent { id: number; title: string; place: string; notes: string; start: string; stop: string; allDay: boolean; alert: number | null; color: string }
export type View = 'day' | 'week' | 'month' | 'year';

export const PX = 56; // pixels par heure de la grille jour/semaine
export const CALS: Array<{ id: string; color: string; key: string }> = [
  { id: 'pol', color: '#ff383c', key: 'cal.cal_pol' },
  { id: 'post', color: '#0088ff', key: 'cal.cal_post' },
  { id: 'gar', color: '#ff8d28', key: 'cal.cal_gar' },
  { id: 'perso', color: '#34c759', key: 'cal.cal_perso' },
];
export const DEFAULT_COLOR = '#34c759';
/** Avances d'alerte acceptées par le serveur (minutes avant le début) ; null = aucune. */
export const ALERTS: Array<number | null> = [null, 0, 5, 10, 15, 30, 60, 120, 1440, 2880];

const p2 = (n: number) => String(n).padStart(2, '0');
export const dateOf = (key: string): Date => { const [y, m, d] = key.split('-').map(Number); return new Date(Date.UTC(y, m - 1, d)); };
export const keyOf = (d: Date): string => `${d.getUTCFullYear()}-${p2(d.getUTCMonth() + 1)}-${p2(d.getUTCDate())}`;
export const addDays = (key: string, n: number): string => { const d = dateOf(key); d.setUTCDate(d.getUTCDate() + n); return keyOf(d); };
export const addMonths = (key: string, n: number): string => { const d = dateOf(key); return keyOf(new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + n, 1))); };
export const addYears = (key: string, n: number): string => { const d = dateOf(key); return keyOf(new Date(Date.UTC(d.getUTCFullYear() + n, d.getUTCMonth(), 1))); };
/** Jour de la semaine, lundi = 1 ... dimanche = 7. */
export const dow = (key: string): number => dateOf(key).getUTCDay() || 7;
export const mondayOf = (key: string): string => addDays(key, 1 - dow(key));
export const firstOfMonth = (key: string): string => `${key.slice(0, 7)}-01`;

/** Clé du jour du jeu à partir du temps du jeu continu. */
export const todayKey = (gameMs: number): string => keyOf(new Date(gameMs));
/** Minute de la journée du jeu (0..1439). */
export const nowMinute = (gameMs: number): number => { const d = new Date(gameMs); return d.getUTCHours() * 60 + d.getUTCMinutes(); };

export const stampOf = (key: string, time: string): string => `${key} ${time}`;
export const dayPart = (stamp: string): string => stamp.slice(0, 10);
export const timePart = (stamp: string): string => stamp.slice(11, 16);
const minutesOf = (stamp: string): number => Number(stamp.slice(11, 13)) * 60 + Number(stamp.slice(14, 16));

/** Semaines pleines (lundi d'abord) d'un mois : 35 cases, ou 42 si le mois déborde sur une sixième semaine. */
export function monthGrid(anchor: string): string[] {
  const first = firstOfMonth(anchor);
  const start = mondayOf(first);
  const n = addDays(start, 35).slice(0, 7) === first.slice(0, 7) ? 42 : 35;
  return Array.from({ length: n }, (_, i) => addDays(start, i));
}

export const weekDays = (anchor: string): string[] => Array.from({ length: 7 }, (_, i) => addDays(mondayOf(anchor), i));

/** Plage de dates à demander au serveur pour une vue (<= 90 jours). L'année n'affiche pas d'événements. */
export function rangeFor(view: View, anchor: string): { from: string; to: string } | null {
  if (view === 'day') return { from: anchor, to: anchor };
  if (view === 'week') { const w = weekDays(anchor); return { from: w[0], to: w[6] }; }
  if (view === 'month') { const g = monthGrid(anchor); return { from: g[0], to: g[g.length - 1] }; }
  return null;
}

/** Événements qui touchent un jour, triés par début, calendriers masqués exclus. */
export function eventsOn(events: CalEvent[], key: string, hidden: Record<string, boolean> = {}): CalEvent[] {
  const hiddenColors = new Set(CALS.filter((c) => hidden[c.id]).map((c) => c.color));
  return events
    .filter((e) => dayPart(e.start) <= key && dayPart(e.stop) >= key && !hiddenColors.has(e.color))
    .sort((a, b) => a.start.localeCompare(b.start) || a.id - b.id);
}

export interface Block { top: number; height: number }
/** Position verticale d'un événement dans la colonne d'un jour (une heure = PX pixels, grille de 0 h à 24 h). */
export function blockOf(e: CalEvent, key: string): Block {
  const s = dayPart(e.start) < key || e.allDay ? 0 : minutesOf(e.start);
  const f = dayPart(e.stop) > key ? 1440 : e.allDay ? 1440 : minutesOf(e.stop);
  return { top: (s / 60) * PX, height: Math.max(22, ((f - s) / 60) * PX - 2) };
}

/** Titre de l'en-tête : « 15 – 21 nov. 2026 », mois, année ou jour (noms de mois par Intl, dans la langue). */
export function titleOf(view: View, anchor: string, lang: string): string {
  const fmt = (o: Intl.DateTimeFormatOptions, d: Date) => { try { return new Intl.DateTimeFormat(lang, { ...o, timeZone: 'UTC' }).format(d); } catch { return new Intl.DateTimeFormat('en', { ...o, timeZone: 'UTC' }).format(d); } };
  const d = dateOf(anchor);
  if (view === 'day') return fmt({ weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }, d);
  if (view === 'month') return fmt({ month: 'long', year: 'numeric' }, d);
  if (view === 'year') return String(d.getUTCFullYear());
  const w = weekDays(anchor);
  const a = dateOf(w[0]);
  const b = dateOf(w[6]);
  const sameMonth = a.getUTCMonth() === b.getUTCMonth();
  return `${sameMonth ? a.getUTCDate() : fmt({ day: 'numeric', month: 'short' }, a)} – ${fmt({ day: 'numeric', month: 'short', year: 'numeric' }, b)}`;
}

/** Pas de navigation (précédent / suivant) selon la vue. */
export function step(view: View, anchor: string, n: number): string {
  return view === 'day' ? addDays(anchor, n) : view === 'week' ? addDays(anchor, 7 * n) : view === 'month' ? addMonths(anchor, n) : addYears(anchor, n);
}

export const calOf = (color: string) => CALS.find((c) => c.color === color) ?? CALS[3];

/** Valeurs de départ d'un nouvel événement le jour `key` à l'heure `minute`. */
export function draftFor(key: string, minute: number): { date: string; from: string; to: string } {
  const start = Math.min(minute, 23 * 60);
  const end = Math.min(start + 60, 23 * 60 + 59);
  const hm = (m: number) => `${p2(Math.floor(m / 60))}:${p2(m % 60)}`;
  return { date: key, from: hm(start), to: hm(end) };
}

/** Échéance client d'une alerte : minute de la journée où elle sonne (début moins l'avance), ou null. */
export function alertMinute(e: { start: string; allDay: boolean; alert: number | null }): number | null {
  if (e.alert === null) return null;
  const start = e.allDay ? 0 : minutesOf(e.start);
  return (((start - e.alert) % 1440) + 1440) % 1440;
}
