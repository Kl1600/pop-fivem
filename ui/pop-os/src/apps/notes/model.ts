import type { TFn } from '../../kit';

// Modèle de Notes : blocs, liste et regroupement. Fonctions pures, testées.

export interface TodoItem { t: string; done: boolean }
export type Block =
  | { type: 'text'; value: string }
  | { type: 'todo'; items: TodoItem[] }
  | { type: 'table'; rows: string[][] }
  | { type: 'photo'; id: number };

export interface NoteRow {
  id: number;
  folder: number | null;
  title: string;
  excerpt: string;
  hint: string;
  pinned: boolean;
  deleted: boolean;
  updated: number;
}

export interface Folder { id: number; name: string }

/** Sélection de la colonne de gauche : tout, dossier par défaut, corbeille, ou un dossier créé. */
export type FolderSel = 'all' | 'def' | 'trash' | number;

export const MAX_NOTES = 200;

/** Notes d'un dossier, filtrées par la recherche (titre + extrait). */
export function visibleNotes(notes: NoteRow[], sel: FolderSel, query: string): NoteRow[] {
  const q = query.trim().toLowerCase();
  return notes.filter((n) => {
    if (sel === 'trash' ? !n.deleted : n.deleted) return false;
    if (sel === 'def' && n.folder !== null) return false;
    if (typeof sel === 'number' && n.folder !== sel) return false;
    return !q || `${n.title} ${n.excerpt}`.toLowerCase().includes(q);
  });
}

/** Épinglées d'abord ; la corbeille n'a pas de groupe d'épinglées. */
export function groupNotes(list: NoteRow[]): { pinned: NoteRow[]; rest: NoteRow[] } {
  return { pinned: list.filter((n) => n.pinned), rest: list.filter((n) => !n.pinned) };
}

export function countIn(notes: NoteRow[], sel: FolderSel): number {
  return visibleNotes(notes, sel, '').length;
}

/** Aperçu d'une ligne de la liste : extrait, sinon libellé selon le contenu. */
export function previewOf(n: NoteRow, t: TFn): string {
  if (n.excerpt) return n.excerpt;
  if (n.hint === 'todo') return t('not.todo');
  if (n.hint === 'table') return t('not.table');
  if (n.hint === 'photo') return t('not.photo_l');
  return t('not.no_text');
}

export function emptyTable(): string[][] {
  return [['', '', ''], ['', '', ''], ['', '', '']];
}

export const emptyBlocks = (): Block[] => [{ type: 'text', value: '' }];

/** Date courte d'une ligne : l'heure aujourd'hui, sinon la date. `seconds` : époque en secondes. */
export function stamp(seconds: number, lang: string, now = Date.now()): string {
  const d = new Date(seconds * 1000);
  const same = new Date(now).toDateString() === d.toDateString();
  try {
    return same ? d.toLocaleTimeString(lang, { hour: '2-digit', minute: '2-digit' }) : d.toLocaleDateString(lang, { day: '2-digit', month: '2-digit', year: 'numeric' });
  } catch {
    return d.toISOString().slice(0, 10);
  }
}

export function longStamp(seconds: number, lang: string): string {
  try {
    return new Date(seconds * 1000).toLocaleString(lang, { dateStyle: 'long', timeStyle: 'short' });
  } catch {
    return new Date(seconds * 1000).toISOString();
  }
}
