// Modèle de Fichiers : arbre, vues (récents, partagés, tags, favoris), tri, recherche. Fonctions pures, testées.

export interface FileEntry {
  id: number;
  parent: number | null;
  kind: 'folder' | 'doc' | 'photo' | 'audio' | 'board';
  name: string;
  ref: number | null;
  size: number;
  shared: boolean;
  token: string | null;
  tag: string | null;
  fav: boolean;
  updated: number;
}

export type FilesSel = 'recents' | 'shared' | 'tablet' | `tag:${string}`;
export type SortKey = 'name' | 'date' | 'size' | 'type';

export const TAGS: Array<{ id: string; color: string }> = [
  { id: 'red', color: '#ff383c' }, { id: 'orange', color: '#ff8d28' }, { id: 'yellow', color: '#ffcc00' }, { id: 'green', color: '#34c759' }, { id: 'blue', color: '#0088ff' },
];
export const tagColor = (id: string | null): string => TAGS.find((x) => x.id === id)?.color ?? 'transparent';

export const KIND_COLOR: Record<FileEntry['kind'], string> = { folder: '#1a8cff', doc: '#0088ff', photo: '#8e8e93', audio: '#ff8d28', board: '#34c759' };
export const KIND_EXT: Record<FileEntry['kind'], string> = { folder: '', doc: 'TXT', photo: 'IMG', audio: 'AUD', board: 'TAB' };

/** Nombre d'éléments directement dans un dossier. */
export function childCount(all: FileEntry[], id: number): number {
  return all.filter((e) => e.parent === id).length;
}

/** Chaîne de dossiers de la racine à `id` (ids). */
export function pathTo(all: FileEntry[], id: number | null): number[] {
  const out: number[] = [];
  const byId = new Map(all.map((e) => [e.id, e]));
  let cur = id;
  for (let i = 0; cur !== null && i < 10; i++) {
    out.unshift(cur);
    cur = byId.get(cur)?.parent ?? null;
  }
  return out;
}

/** Taille d'affichage en Ko (une décimale), 0 pour un dossier. */
export function kb(bytes: number): number {
  return Math.round((bytes / 1024) * 10) / 10;
}

const cmp: Record<SortKey, (a: FileEntry, b: FileEntry) => number> = {
  name: (a, b) => a.name.localeCompare(b.name),
  date: (a, b) => b.updated - a.updated,
  size: (a, b) => b.size - a.size,
  type: (a, b) => a.kind.localeCompare(b.kind) || a.name.localeCompare(b.name),
};

/** Liste affichée : selon la sélection, le dossier courant (`path`), la recherche et le tri. Les dossiers passent d'abord dans « Sur la tablette ». */
export function viewOf(all: FileEntry[], sel: FilesSel, path: number[], query: string, sort: SortKey): FileEntry[] {
  const q = query.trim().toLowerCase();
  let list: FileEntry[];
  if (q) list = all.filter((e) => e.name.toLowerCase().includes(q));
  else if (sel === 'tablet') list = all.filter((e) => e.parent === (path.length ? (path[path.length - 1] as number) : null));
  else if (sel === 'recents') list = all.filter((e) => e.kind !== 'folder').sort(cmp.date).slice(0, 12);
  else if (sel === 'shared') list = all.filter((e) => e.shared);
  else list = all.filter((e) => e.tag === sel.slice(4));
  const foldersFirst = sel === 'tablet' && !q;
  return list.slice().sort((a, b) => (foldersFirst && (a.kind === 'folder') !== (b.kind === 'folder') ? (a.kind === 'folder' ? -1 : 1) : cmp[sort](a, b)));
}

/** Dossiers marqués favoris, pour la barre latérale. */
export function favFolders(all: FileEntry[]): FileEntry[] {
  return all.filter((e) => e.kind === 'folder' && e.fav);
}

export function fmtDate(seconds: number, lang: string): string {
  try {
    return new Date(seconds * 1000).toLocaleDateString(lang, { day: 'numeric', month: 'short', year: 'numeric' });
  } catch {
    return new Date(seconds * 1000).toISOString().slice(0, 10);
  }
}

/** Dossiers où `id` peut être déplacé : ni lui-même ni un de ses descendants. */
export function moveTargets(all: FileEntry[], id: number): FileEntry[] {
  const banned = new Set<number>([id]);
  let grew = true;
  while (grew) {
    grew = false;
    for (const e of all) if (e.parent !== null && banned.has(e.parent) && !banned.has(e.id)) { banned.add(e.id); grew = true; }
  }
  return all.filter((e) => e.kind === 'folder' && !banned.has(e.id));
}
