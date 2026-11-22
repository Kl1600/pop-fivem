// Rappels : filtres et calculs purs (maquette Rappels.dc.html). Échéances en dates du jeu 'AAAA-MM-JJ HH:MM'.
export interface Reminder { id: number; list: number; title: string; done: boolean; due: string | null; flag: boolean }
export interface RList { id: number; name: string; color: string }
/** Sélection : une tuile intelligente ou l'identifiant d'une liste. */
export type Sel = 'today' | 'sched' | 'all' | 'flag' | 'done' | number;

export const TILES: Array<{ id: Exclude<Sel, number>; key: string; color: string; d: string }> = [
  { id: 'today', key: 'rem.today', color: '#0088ff', d: 'M8 3v3M16 3v3M4 8h16M5 5h14v15H5z' },
  { id: 'sched', key: 'rem.scheduled', color: '#ff383c', d: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 7v5l3 2' },
  { id: 'all', key: 'rem.all', color: '#636366', d: 'M4 7h16M4 12h16M4 17h16' },
  { id: 'flag', key: 'rem.flagged', color: '#ff8d28', d: 'M5 21V4M5 4h12l-2 4 2 4H5' },
  { id: 'done', key: 'rem.done', color: '#8e8e93', d: 'M5 12l5 5 9-10' },
];
/** Couleurs proposées pour une liste (acceptées par le serveur : #rrggbb). */
export const LIST_COLORS = ['#0088ff', '#ff2d55', '#34c759', '#ff8d28', '#af52de', '#5ac8fa'];

const dayOf = (due: string): string => due.slice(0, 10);

/** Un rappel appartient à une sélection. `today` = échéance aujourd'hui ou en retard. */
export function inSel(r: Reminder, sel: Sel, today: string): boolean {
  if (typeof sel === 'number') return r.list === sel;
  if (sel === 'done') return r.done;
  if (r.done) return false;
  if (sel === 'all') return true;
  if (sel === 'flag') return r.flag;
  if (r.due === null) return false;
  return sel === 'sched' ? true : dayOf(r.due) <= today;
}

/** Nombre affiché sur une tuile ou une liste (une liste ne compte que les rappels à faire). */
export function countOf(items: Reminder[], sel: Sel, today: string): number {
  return items.filter((r) => inSel(r, sel, today) && (typeof sel !== 'number' || !r.done)).length;
}

/** Rappels affichés : recherche sur le titre, à faire d'abord puis par échéance. */
export function visible(items: Reminder[], sel: Sel, today: string, query: string): Reminder[] {
  const q = query.trim().toLowerCase();
  return items
    .filter((r) => inSel(r, sel, today) && (!q || r.title.toLowerCase().includes(q)))
    .sort((a, b) => Number(a.done) - Number(b.done) || (a.due ?? '9999').localeCompare(b.due ?? '9999') || a.id - b.id);
}

const ms = (key: string): number => { const [y, m, d] = key.split('-').map(Number); return Date.UTC(y, m - 1, d); };
/** Écart en jours entre l'échéance et aujourd'hui (négatif = en retard). */
export function dayDiff(due: string, today: string): number {
  return Math.round((ms(dayOf(due)) - ms(today)) / 86_400_000);
}

/** Échéance proposée pour un rappel créé aujourd'hui : l'heure pleine suivante (au plus 23 h). */
export function defaultDue(today: string, nowMinute: number): string {
  const h = Math.min(23, Math.ceil((nowMinute + 1) / 60));
  return `${today} ${String(h).padStart(2, '0')}:00`;
}
