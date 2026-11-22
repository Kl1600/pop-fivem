// Photos, Notes et Fichiers simulés (mémoire seulement) : mêmes réponses que les callbacks du serveur.
type Json = Record<string, unknown>;

const PX = 'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==';
interface MPhoto { id: number; kind: string; rating: number; fav: boolean; fx: string; taken: number; deleted: boolean; albums: number[] }
interface MNote { id: number; folder: number | null; title: string; blocks: unknown[]; pinned: boolean; deleted: boolean; updated: number }
interface MFile { id: number; parent: number | null; kind: string; name: string; body: string; ref: number | null; size: number; shared: boolean; token: string | null; tag: string | null; fav: boolean; updated: number }

let mPhotos: MPhoto[] = [];
let mAlbums: Array<{ id: number; name: string }> = [];
let mNotes: MNote[] = [];
let mFolders: Array<{ id: number; name: string }> = [];
let mFiles: MFile[] = [];
let mSeq = 100;
const NOW = 1_800_000_000;

export function seedMedia(): void {
  mPhotos = [1, 2, 3].map((i) => ({ id: i, kind: 'photo', rating: 0, fav: false, fx: 'none', taken: NOW - i * 86_400 * 20, deleted: false, albums: [] }));
  mAlbums = [];
  mNotes = [{ id: 1, folder: null, title: 'Courses', blocks: [{ type: 'text', value: 'Pain, café' }, { type: 'todo', items: [{ t: 'Huile moteur', done: false }] }], pinned: false, deleted: false, updated: NOW }];
  mFolders = [];
  mFiles = [
    { id: 1, parent: null, kind: 'folder', name: 'Rapports', body: '', ref: null, size: 0, shared: false, token: null, tag: null, fav: false, updated: NOW },
    { id: 2, parent: 1, kind: 'doc', name: 'Rapport.txt', body: 'Bonjour', ref: null, size: 7, shared: false, token: null, tag: 'red', fav: false, updated: NOW },
  ];
}
seedMedia();

const excerptOf = (blocks: Array<{ type?: string; value?: string }>): string => (blocks.find((b) => b.type === 'text')?.value ?? '').replace(/\s+/g, ' ').trim().slice(0, 120);
const hintOf = (blocks: Array<{ type?: string }>): string => blocks[0]?.type ?? '';
const fileRow = (f: MFile): Json => ({ id: f.id, parent: f.parent, kind: f.kind, name: f.name, ref: f.ref, size: f.size, shared: f.shared, token: f.token, tag: f.tag, fav: f.fav, updated: f.updated });
const albumsOut = () => mAlbums.map((al) => ({ ...al, n: mPhotos.filter((p) => p.albums.includes(al.id)).length }));

export const MEDIA_CALLS = new Set([
  'photos:capture', 'photos:list', 'photos:get', 'photos:favorite', 'photos:rate', 'photos:filter', 'photos:delete', 'photos:restore', 'photos:thumb',
  'photos:albums', 'photos:albumSave', 'photos:albumDelete', 'photos:albumLink',
  'notes:list', 'notes:get', 'notes:save', 'notes:delete', 'notes:restore', 'notes:folderSave', 'notes:folderDelete',
  'files:list', 'files:get', 'files:save', 'files:delete', 'files:move', 'files:share', 'files:unshare', 'files:open',
]);

/** Réponse simulée d'un callback de Photos, Notes ou Fichiers. `raw` = charge brute envoyée par l'appli. */
export function mediaCall(name: string, raw: unknown): unknown {
  const a = (typeof raw === 'object' && raw ? raw : {}) as Json;
  const id = Number(typeof raw === 'object' && raw ? a.id : raw);
  switch (name) {
    case 'photos:capture': {
      const n = ++mSeq;
      mPhotos.unshift({ id: n, kind: String(a.kind ?? 'photo'), rating: 0, fav: false, fx: 'none', taken: NOW, deleted: false, albums: [] });
      return { ok: true, id: n };
    }
    case 'photos:list': {
      const scope = String(a.scope ?? 'all');
      const live = mPhotos.filter((p) => (scope === 'trash' ? p.deleted : !p.deleted && (scope !== 'fav' || p.fav) && (scope !== 'album' || p.albums.includes(Number(a.albumId)))));
      return { ok: true, items: live.map((p) => ({ id: p.id, kind: p.kind, rating: p.rating, fav: p.fav, fx: p.fx, taken: p.taken, thumb: PX })), more: false,
        counts: { total: mPhotos.filter((p) => !p.deleted).length, fav: mPhotos.filter((p) => !p.deleted && p.fav).length, trash: mPhotos.filter((p) => p.deleted).length }, albums: albumsOut() };
    }
    case 'photos:get': { const p = mPhotos.find((x) => x.id === id); return p ? { ok: true, photo: { ...p, data: PX } } : { ok: false, err: 'err_not_found' }; }
    case 'photos:favorite': { const p = mPhotos.find((x) => x.id === id); if (!p) return { ok: false, err: 'err_not_found' }; p.fav = !p.fav; return { ok: true, fav: p.fav }; }
    case 'photos:rate': { const p = mPhotos.find((x) => x.id === id); if (!p) return { ok: false, err: 'err_not_found' }; p.rating = Number(a.rating); return { ok: true, rating: p.rating }; }
    case 'photos:filter': { const p = mPhotos.find((x) => x.id === id); if (!p) return { ok: false, err: 'err_not_found' }; p.fx = String(a.fx); return { ok: true }; }
    case 'photos:delete': {
      const p = mPhotos.find((x) => x.id === id);
      if (!p) return { ok: false, err: 'err_not_found' };
      if (p.deleted) { mPhotos = mPhotos.filter((x) => x !== p); return { ok: true, permanent: true }; }
      p.deleted = true;
      return { ok: true, permanent: false };
    }
    case 'photos:restore': { const p = mPhotos.find((x) => x.id === id); if (p) p.deleted = false; return { ok: !!p }; }
    case 'photos:thumb': return { ok: true };
    case 'photos:albums': return { ok: true, albums: albumsOut() };
    case 'photos:albumSave': { const n = ++mSeq; mAlbums.push({ id: n, name: String(a.name) }); return { ok: true, id: n, name: String(a.name) }; }
    case 'photos:albumDelete': mAlbums = mAlbums.filter((al) => al.id !== id); return { ok: true };
    case 'photos:albumLink': {
      const p = mPhotos.find((x) => x.id === Number(a.photoId));
      if (!p) return { ok: false, err: 'err_not_found' };
      p.albums = a.on ? [...p.albums, Number(a.albumId)] : p.albums.filter((x) => x !== Number(a.albumId));
      return { ok: true };
    }
    case 'notes:list': return { ok: true, folders: mFolders, notes: mNotes.map((n) => ({ id: n.id, folder: n.folder, title: n.title, excerpt: excerptOf(n.blocks as never), hint: hintOf(n.blocks as never), pinned: n.pinned, deleted: n.deleted, updated: n.updated })) };
    case 'notes:get': { const n = mNotes.find((x) => x.id === id); return n ? { ok: true, note: n } : { ok: false, err: 'err_not_found' }; }
    case 'notes:save': {
      const blocks = (a.blocks ?? []) as never[];
      const common = { title: String(a.title ?? ''), blocks, pinned: a.pinned === true, folder: typeof a.folder === 'number' ? a.folder : null, updated: NOW + 1 };
      if (a.id !== undefined) {
        const n = mNotes.find((x) => x.id === Number(a.id));
        if (!n) return { ok: false, err: 'err_not_found' };
        Object.assign(n, common);
        return { ok: true, id: n.id, updated: n.updated, excerpt: excerptOf(blocks), hint: hintOf(blocks) };
      }
      if (mNotes.length >= 200) return { ok: false, err: 'err_limit' };
      const n = { id: ++mSeq, deleted: false, ...common };
      mNotes.unshift(n);
      return { ok: true, id: n.id, updated: n.updated, excerpt: excerptOf(blocks), hint: hintOf(blocks) };
    }
    case 'notes:delete': {
      const n = mNotes.find((x) => x.id === id);
      if (!n) return { ok: false, err: 'err_not_found' };
      if (n.deleted) { mNotes = mNotes.filter((x) => x !== n); return { ok: true, permanent: true }; }
      n.deleted = true;
      n.pinned = false;
      return { ok: true, permanent: false };
    }
    case 'notes:restore': { const n = mNotes.find((x) => x.id === id); if (n) n.deleted = false; return { ok: !!n }; }
    case 'notes:folderSave': { const n = ++mSeq; mFolders.push({ id: n, name: String(a.name) }); return { ok: true, id: n, name: String(a.name) }; }
    case 'notes:folderDelete': mFolders = mFolders.filter((f) => f.id !== id); mNotes.forEach((n) => { if (n.folder === id) n.folder = null; }); return { ok: true };
    case 'files:list': return { ok: true, items: mFiles.map(fileRow), limit: 500 };
    case 'files:get': { const f = mFiles.find((x) => x.id === id); return f ? { ok: true, file: { ...fileRow(f), body: f.body } } : { ok: false, err: 'err_not_found' }; }
    case 'files:save': {
      if (a.id !== undefined) {
        const f = mFiles.find((x) => x.id === Number(a.id));
        if (!f) return { ok: false, err: 'err_not_found' };
        f.name = String(a.name);
        f.fav = a.fav === true;
        f.tag = typeof a.tag === 'string' ? a.tag : null;
        if (typeof a.body === 'string') { f.body = a.body; f.size = a.body.length; }
        return { ok: true, id: f.id };
      }
      const f: MFile = { id: ++mSeq, parent: typeof a.parentId === 'number' ? a.parentId : null, kind: String(a.kind), name: String(a.name), body: String(a.body ?? ''), ref: typeof a.refId === 'number' ? a.refId : null, size: 0, shared: false, token: null, tag: null, fav: false, updated: NOW };
      mFiles.push(f);
      return { ok: true, id: f.id };
    }
    case 'files:delete': mFiles = mFiles.filter((f) => f.id !== id && f.parent !== id); return { ok: true };
    case 'files:move': { const f = mFiles.find((x) => x.id === id); if (!f) return { ok: false, err: 'err_not_found' }; f.parent = typeof a.parentId === 'number' ? a.parentId : null; return { ok: true }; }
    case 'files:share': { const f = mFiles.find((x) => x.id === id); if (!f) return { ok: false, err: 'err_not_found' }; f.shared = true; f.token = 'ABCDEFGHJKLM'; return { ok: true, token: f.token }; }
    case 'files:unshare': { const f = mFiles.find((x) => x.id === id); if (f) { f.shared = false; f.token = null; } return { ok: true }; }
    case 'files:open': { const f = mFiles.find((x) => x.token === raw); return f ? { ok: true, file: { kind: f.kind, name: f.name, body: f.body } } : { ok: false, err: 'err_token' }; }
    default: return { ok: false, err: 'err_unavailable' };
  }
}
