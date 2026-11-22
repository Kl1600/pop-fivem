// Simulation du Navigateur et de Musique pour le navigateur de développement et les tests (formes de server/apps/browser.lua et music.lua).
interface Entry { url: string; title: string }
interface Playlist { name: string; ids: string[] }

export const MOCK_STATIONS = [
  { id: 's1', name: 'Groove Salad', tag: 'CHILL', url: '/flux/groove.mp3' },
  { id: 's2', name: 'Secret Agent', tag: 'LOUNGE', url: '/flux/agent.mp3' },
  { id: 's3', name: 'Space Station', tag: 'ELECTRO', url: '/flux/space.mp3' },
];

let bookmarks: Entry[] = [];
let history: Entry[] = [];
let favs: string[] = [];
let playlists: Playlist[] = [];
let state: unknown = null;

export function seedNav(): void { bookmarks = []; history = []; favs = []; playlists = []; state = null; }
export const navState = (): { bookmarks: Entry[]; history: Entry[]; favs: string[]; playlists: Playlist[]; state: unknown } => ({ bookmarks, history, favs, playlists, state });

const ids = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string' && MOCK_STATIONS.some((s) => s.id === x)) : []);
const entries = (v: unknown): Entry[] => (Array.isArray(v) ? v.filter((e): e is Entry => !!e && typeof (e as Entry).url === 'string' && !/[<>"\\]/.test((e as Entry).url)).slice(0, 50) : []);

export function navCall(name: string, raw: unknown): unknown {
  const a = (typeof raw === 'object' && raw ? raw : {}) as Record<string, unknown>;
  switch (name) {
    case 'browser:sites':
      return { ok: true, sites: [{ domain: 'annuaire.pop', title: 'Annuaire', page: 'nui://pop_annuaire/web/index.html' }], hosts: ['exemple.fr'], bookmarks, history };
    case 'browser:save':
      if (a.bookmarks !== undefined) bookmarks = entries(a.bookmarks);
      if (a.history !== undefined) history = entries(a.history);
      return { ok: true };
    case 'music:stations':
      return { ok: true, stations: MOCK_STATIONS, favs, playlists };
    case 'music:save':
      if (a.favs !== undefined) favs = ids(a.favs);
      if (a.playlists !== undefined) {
        if (!Array.isArray(a.playlists)) return { ok: false, err: 'err_payload' };
        playlists = (a.playlists as Array<{ name?: unknown; ids?: unknown }>).map((p) => ({ name: String(p.name ?? ''), ids: ids(p.ids) }));
        if (playlists.some((p) => !p.name)) return { ok: false, err: 'err_payload' };
      }
      return { ok: true };
    case 'music:state':
      state = raw;
      return { ok: true };
    default:
      return { ok: false, err: 'err_not_found' };
  }
}
