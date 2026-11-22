// Modèle de Tableau : éléments (post-it, formes, textes, images, flèches) et traits sur un plan de 1348 × 1019.
// Fonctions pures (testées). Le serveur reçoit un texte JSON `{ items, strokes }` ; il le revalide (limites, types).

export const W = 1348;
export const H = 1019;
export const MAX_BYTES = 131072;
export const MAX_POINTS = 10000;
export const MAX_BOARDS = 30;

export const COLS = [
  { key: 'tab.col_0', main: '#FFCC00', soft: '#FFE680' },
  { key: 'tab.col_1', main: '#FF2D55', soft: '#FFB3C1' },
  { key: 'tab.col_2', main: '#0088FF', soft: '#B3DAFF' },
  { key: 'tab.col_3', main: '#34C759', soft: '#B8EBC5' },
  { key: 'tab.col_4', main: '#FF8D28', soft: '#FFD3A8' },
  { key: 'tab.col_5', main: '#CB30E0', soft: '#EDB5F5' },
] as const;

export type ItemType = 'note' | 'shape' | 'text' | 'image' | 'arrow';
export type Tool = 'select' | 'pen' | 'shape' | 'text' | 'note' | 'image';
export type ShapeKind = 'rect' | 'circle' | 'arrow';

export interface Item {
  id: number;
  type: ItemType;
  col: number;
  text?: string;
  shape?: 'rect' | 'circle';
  fs?: number;
  x?: number; y?: number; w?: number; h?: number;
  x1?: number; y1?: number; x2?: number; y2?: number;
}
export interface Stroke { id: number; col: number; pts: Array<[number, number]> }
export interface Board { items: Item[]; strokes: Stroke[] }
export interface BoardRow { id: number; title: string; updated: number }

export const emptyBoard = (): Board => ({ items: [], strokes: [] });

const clamp = (v: number, lo: number, hi: number): number => Math.max(lo, Math.min(hi, v));

/** Point quantifié : entiers dans le plan. */
export const quant = (x: number, y: number): [number, number] => [clamp(Math.round(x), 0, W), clamp(Math.round(y), 0, H)];

/** Retire les points trop proches du précédent (moins de 3 px) pour garder les traits légers ; garde toujours le dernier. */
export function thin(pts: Array<[number, number]>): Array<[number, number]> {
  if (pts.length <= 2) return pts;
  const out: Array<[number, number]> = [pts[0] as [number, number]];
  for (let i = 1; i < pts.length - 1; i++) {
    const p = pts[i] as [number, number];
    const q = out[out.length - 1] as [number, number];
    if (Math.abs(p[0] - q[0]) + Math.abs(p[1] - q[1]) >= 3) out.push(p);
  }
  out.push(pts[pts.length - 1] as [number, number]);
  return out;
}

export const pointCount = (b: Board): number => b.strokes.reduce((n, s) => n + s.pts.length, 0);

export function serialize(b: Board): string {
  return JSON.stringify({ items: b.items, strokes: b.strokes });
}

/** Relit un tableau enregistré ; un texte vide ou invalide donne un tableau vide. */
export function parse(text: string | undefined | null): Board {
  if (!text) return emptyBoard();
  try {
    const d = JSON.parse(text) as Partial<Board>;
    return { items: Array.isArray(d.items) ? d.items : [], strokes: Array.isArray(d.strokes) ? d.strokes : [] };
  } catch {
    return emptyBoard();
  }
}

/** Le tableau tient dans les limites du serveur (128 Ko, 10 000 points). */
export function fits(b: Board): { ok: boolean; why?: 'bytes' | 'points' } {
  if (pointCount(b) > MAX_POINTS) return { ok: false, why: 'points' };
  if (serialize(b).length > MAX_BYTES) return { ok: false, why: 'bytes' };
  return { ok: true };
}

export const nextId = (b: Board): number => 1 + Math.max(0, ...b.items.map((i) => i.id), ...b.strokes.map((s) => s.id));

/** Ajoute un élément posé au point (x, y), centré. */
export function placeItem(b: Board, tool: Exclude<Tool, 'select' | 'pen'>, shape: ShapeKind, col: number, x: number, y: number, labels: { text: string; image: string }): Board {
  const id = nextId(b);
  let it: Item;
  if (tool === 'note') it = { id, type: 'note', col, x: x - 95, y: y - 95, w: 190, h: 190, text: '' };
  else if (tool === 'text') it = { id, type: 'text', col, x: x - 100, y: y - 20, w: 280, h: 40, fs: 28, text: labels.text };
  else if (tool === 'image') it = { id, type: 'image', col, x: x - 130, y: y - 95, w: 260, h: 190, text: labels.image };
  else if (shape === 'arrow') it = { id, type: 'arrow', col, x1: x - 90, y1: y + 35, x2: x + 90, y2: y - 35 };
  else it = { id, type: 'shape', shape, col, x: x - 90, y: y - 60, w: 180, h: 120, text: '' };
  return { ...b, items: [...b.items, it] };
}

export function patchItem(b: Board, id: number, patch: Partial<Item>): Board {
  return { ...b, items: b.items.map((i) => (i.id === id ? { ...i, ...patch } : i)) };
}

export const removeItem = (b: Board, id: number): Board => ({ ...b, items: b.items.filter((i) => i.id !== id) });

export function addStroke(b: Board, col: number, pts: Array<[number, number]>): Board {
  if (pts.length < 2) return b;
  return { ...b, strokes: [...b.strokes, { id: nextId(b), col, pts: thin(pts) }] };
}

/** Annule le dernier ajout (élément ou trait, le plus récent d'après l'identifiant). */
export function undo(b: Board): Board {
  const li = b.items.length ? (b.items[b.items.length - 1] as Item).id : -1;
  const ls = b.strokes.length ? (b.strokes[b.strokes.length - 1] as Stroke).id : -1;
  if (li < 0 && ls < 0) return b;
  return ls > li ? { ...b, strokes: b.strokes.slice(0, -1) } : { ...b, items: b.items.slice(0, -1) };
}

/** Déplacement d'un élément (ou d'une flèche entière) de (dx, dy) depuis sa position d'origine `o`. */
export function moved(o: Item, dx: number, dy: number): Partial<Item> {
  if (o.type === 'arrow') return { x1: (o.x1 ?? 0) + dx, y1: (o.y1 ?? 0) + dy, x2: (o.x2 ?? 0) + dx, y2: (o.y2 ?? 0) + dy };
  return { x: (o.x ?? 0) + dx, y: (o.y ?? 0) + dy };
}

/** Pointe d'une flèche : points du triangle. */
export function arrowHead(i: Item): string {
  const x1 = i.x1 ?? 0, y1 = i.y1 ?? 0, x2 = i.x2 ?? 0, y2 = i.y2 ?? 0;
  const a = Math.atan2(y2 - y1, x2 - x1);
  const p = (k: number): string => `${(x2 - 18 * Math.cos(a + k)).toFixed(0)},${(y2 - 18 * Math.sin(a + k)).toFixed(0)}`;
  return `${x2.toFixed(0)},${y2.toFixed(0)} ${p(-0.4)} ${p(0.4)}`;
}

export const polyline = (pts: Array<[number, number]>): string => pts.map((p) => p.join(',')).join(' ');

export const colorOf = (i: number): { main: string; soft: string } => COLS[i] ?? COLS[0];
