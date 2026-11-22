// Tableau, Dictaphone et partage simulés (mémoire seulement) : mêmes réponses que les callbacks du serveur.
type Json = Record<string, unknown>;

interface MBoard { id: number; title: string; strokes: string; updated: number }
interface MRec { id: number; title: string; seconds: number; created: number; data: string }

let boards: MBoard[] = [];
let recs: MRec[] = [];
let seq = 200;
const NOW = Math.floor(Date.UTC(2026, 10, 22, 14, 32) / 1000);

export function seedBoard(): void {
  boards = [{ id: 1, title: 'Enquête Vinewood', updated: NOW, strokes: JSON.stringify({
    items: [
      { id: 1, type: 'text', col: 0, x: 120, y: 120, w: 520, h: 50, fs: 38, text: 'Enquête Vinewood' },
      { id: 2, type: 'note', col: 0, x: 120, y: 220, w: 190, h: 190, text: 'Fourgon blanc, plaque 42 ABC 117' },
      { id: 3, type: 'shape', col: 3, shape: 'rect', x: 170, y: 560, w: 200, h: 110, text: 'Suspect A' },
      { id: 4, type: 'arrow', col: 5, x1: 260, y1: 420, x2: 270, y2: 550 },
    ],
    strokes: [{ id: 5, col: 1, pts: [[130, 700], [260, 715], [420, 705]] }],
  }) }];
  recs = [
    { id: 1, title: 'Mémo de patrouille', seconds: 0, created: NOW - 3600, data: 'memo:Contrôle du fourgon blanc à Vinewood, plaque 42 ABC 117.' },
  ];
}
seedBoard();

export const BOARD_CALLS = new Set([
  'board:list', 'board:get', 'board:save', 'board:delete',
  'rec:list', 'rec:get', 'rec:save', 'rec:rename', 'rec:delete',
  'share:nearby', 'share:send', 'share:accept', 'share:refuse',
]);

let pending = '';

export function boardCall(name: string, raw: unknown): unknown {
  const a = (typeof raw === 'object' && raw ? raw : {}) as Json;
  const id = Number(typeof raw === 'object' && raw ? a.id : raw);
  switch (name) {
    case 'board:list': return { ok: true, items: boards.map((b) => ({ id: b.id, title: b.title, updated: b.updated })), limit: 30 };
    case 'board:get': { const b = boards.find((x) => x.id === id); return b ? { ok: true, board: { ...b } } : { ok: false, err: 'err_not_found' }; }
    case 'board:save': {
      if (typeof a.strokes !== 'string' || a.strokes.length > 131072) return { ok: false, err: 'err_too_large' };
      if (typeof a.id === 'number') {
        const b = boards.find((x) => x.id === a.id);
        if (!b) return { ok: false, err: 'err_not_found' };
        b.title = String(a.title); b.strokes = a.strokes; b.updated = NOW;
        return { ok: true, id: b.id };
      }
      if (boards.length >= 30) return { ok: false, err: 'err_limit' };
      const b: MBoard = { id: ++seq, title: String(a.title), strokes: a.strokes, updated: NOW };
      boards = [b, ...boards];
      return { ok: true, id: b.id };
    }
    case 'board:delete':
      if (!boards.some((x) => x.id === id)) return { ok: false, err: 'err_not_found' };
      boards = boards.filter((x) => x.id !== id);
      return { ok: true };
    case 'rec:list': return { ok: true, items: recs.map((r) => ({ id: r.id, title: r.title, seconds: r.seconds, created: r.created, memo: r.data.startsWith('memo:') })), limit: 30 };
    case 'rec:get': {
      const r = recs.find((x) => x.id === id);
      if (!r) return { ok: false, err: 'err_not_found' };
      const memo = r.data.startsWith('memo:');
      return { ok: true, rec: { id: r.id, title: r.title, seconds: r.seconds, created: r.created, memo, text: memo ? r.data.slice(5) : undefined, audio: memo ? undefined : r.data } };
    }
    case 'rec:save': {
      if (typeof a.memo === 'string') { const r: MRec = { id: ++seq, title: String(a.title), seconds: Number(a.seconds) || 0, created: NOW, data: `memo:${a.memo}` }; recs = [r, ...recs]; return { ok: true, id: r.id }; }
      if (a.index === 1) pending = '';
      pending += String(a.chunk ?? '');
      if (a.index !== a.total) return { ok: true, partial: true };
      const r: MRec = { id: ++seq, title: String(a.title), seconds: Number(a.seconds) || 0, created: NOW, data: pending };
      pending = '';
      recs = [r, ...recs];
      return { ok: true, id: r.id };
    }
    case 'rec:rename': { const r = recs.find((x) => x.id === a.id); if (!r) return { ok: false, err: 'err_not_found' }; r.title = String(a.title); return { ok: true }; }
    case 'rec:delete':
      if (!recs.some((x) => x.id === id)) return { ok: false, err: 'err_not_found' };
      recs = recs.filter((x) => x.id !== id);
      return { ok: true };
    case 'share:nearby': return { ok: true, items: [{ id: 2, name: 'iPad de Lina' }] };
    case 'share:send': return typeof a.target === 'number' ? { ok: true, offerId: 1 } : { ok: false, err: 'err_payload' };
    case 'share:accept': return { ok: true, kind: 'note' };
    case 'share:refuse': return { ok: true };
    default: return { ok: false, err: 'err_unavailable' };
  }
}
