// Aide commune de Messages, Téléphone et Contacts : fiche de contact, initiales, dégradés, dates, ouverture d'une autre appli.
import type { TFn } from './types';

export interface ContactRow {
  id: number;
  name: string;
  phone: string;
  mail: string;
  addr: string;
  notes: string;
  grp: string;
  fav: boolean;
}

export const CONTACT_GROUPS = ['famille', 'travail', 'lspd', 'ami'] as const;

const GRADS: Array<[string, string]> = [
  ['#ff8d28', '#ff2d55'], ['#34c759', '#00c0e8'], ['#0088ff', '#cb30e0'], ['#cb30e0', '#ff2d55'], ['#ffcc00', '#ff8d28'],
  ['#8e8e93', '#48484a'], ['#0088ff', '#00c0e8'], ['#ff383c', '#ff8d28'],
];

/** Dégradé stable pour une clé (nom ou numéro). */
export function gradOf(key: string): string {
  let h = 0;
  for (let i = 0; i < key.length; i++) h = (h * 31 + key.charCodeAt(i)) >>> 0;
  const g = GRADS[h % GRADS.length]!;
  return `linear-gradient(160deg,${g[0]},${g[1]})`;
}

export function initials(name: string): string {
  const s = name.split(' ').filter(Boolean).map((w) => Array.from(w)[0] ?? '').slice(0, 2).join('').toUpperCase();
  return s || '?';
}

/** « Prénom » et « nom » : le premier mot et le reste (le serveur garde un seul champ). */
export function splitName(name: string): { first: string; last: string } {
  const i = name.indexOf(' ');
  return i < 0 ? { first: name, last: '' } : { first: name.slice(0, i), last: name.slice(i + 1) };
}

/** Nom du contact portant ce numéro, sinon le numéro lui-même. */
export function nameFor(contacts: ContactRow[], phone: string): string {
  return contacts.find((c) => c.phone === phone)?.name || phone;
}

const pad = (n: number) => String(n).padStart(2, '0');

/** Heure du jour (HH:MM), « hier » ou date courte, pour un instant en secondes. */
export function whenOf(at: number, t: TFn, lang: string, now: number = Date.now()): string {
  const d = new Date(at * 1000);
  const n = new Date(now);
  const day = (x: Date) => Math.floor(Date.UTC(x.getFullYear(), x.getMonth(), x.getDate()) / 86400000);
  const diff = day(n) - day(d);
  if (diff <= 0) return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  if (diff === 1) return t('com.yesterday');
  return d.toLocaleDateString(lang, { day: 'numeric', month: 'numeric' });
}

export const clock = (at: number): string => {
  const d = new Date(at * 1000);
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

export const duration = (secs: number): string => `${Math.floor(secs / 60)}:${pad(secs % 60)}`;

/** Demande à la tablette d'ouvrir une autre appli (écouté par system/actions.ts). */
export function openOtherApp(app: string, data?: unknown): void {
  window.dispatchEvent(new CustomEvent('pop-open-app', { detail: { app, data } }));
}
