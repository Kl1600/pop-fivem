// Messages, Téléphone et Contacts simulés (mémoire seulement) : mêmes réponses que les callbacks du serveur.
type Json = Record<string, unknown>;

interface Msg { id: number; me: boolean; from: string; kind: string; body: string; ref: string | null; at: number; read: boolean }
interface Contact { id: number; name: string; phone: string; mail: string; addr: string; notes: string; grp: string; fav: boolean }

export const ME = '555-0142';
const now = () => Math.floor(Date.now() / 1000);

let contacts: Contact[] = [];
let threads: Record<string, Msg[]> = {};
let pins: string[] = [];
let blocked: string[] = [];
let calls: Array<{ id: number; peer: string; dir: string; at: number; secs: number }> = [];
let voicemails: Array<{ id: number; from: string; text: string; at: number }> = [];
let names: Record<string, string> = {};
let seq = 100;
let lastCall: string | null = null;

const C = (id: number, name: string, phone: string, mail: string, addr: string, notes: string, grp: string, fav = false): Contact => ({ id, name, phone, mail, addr, notes, grp, fav });

export function seedComm(): void {
  contacts = [
    C(1, 'Lina Costa', '555-0187', 'lina.costa@pop.ls', '12 Vinewood Boulevard, Vinewood', 'Commerçante, témoin du fourgon blanc.', 'ami', true),
    C(2, 'Sam Leroy', '555-0123', 'sam.leroy@lspd.gov', 'Mission Row, Los Santos', 'Coéquipier.', 'lspd', true),
    C(3, 'Noah Petit', '555-0166', '', '48 Del Perro Pier', '', 'ami'),
    C(4, 'Jade Moreau', '555-0109', '', '3 Route 68, Sandy Shores', '', 'lspd'),
    C(5, 'Garage Del Perro', '555-0199', 'contact@pop.ls', '21 Del Perro Pier', 'Ouvert de 8h à 19h.', 'travail'),
  ];
  const t = now();
  const m = (id: number, me: boolean, from: string, body: string, at: number, kind = 'text', ref: string | null = null, read = true): Msg => ({ id, me, from, kind, body, ref, at, read });
  threads = {
    '555-0187': [m(1, false, '555-0187', 'Salut ! Tu as vu le fourgon blanc ce matin ?', t - 7200), m(2, true, ME, 'Oui, devant ta boutique.', t - 7000), m(3, false, '555-0187', '', t - 6900, 'photo', '7')],
    '555-0123': [m(4, false, '555-0123', 'Briefing à Mission Row à 18h.', t - 600, 'text', null, false), m(5, false, '555-0123', 'On prend ma voiture.', t - 500, 'text', null, false)],
    '555-0166': [m(6, true, ME, 'Tu es où ?', t - 90000), m(7, true, ME, '', t - 89990, 'location', '441.0,-982.0')],
    g1: [m(8, false, '555-0187', 'Qui est dispo samedi ?', t - 4000)],
  };
  names = { g1: 'Équipe Mission Row' };
  pins = ['555-0187'];
  calls = [
    { id: 1, peer: '555-0123', dir: 'missed', at: t - 3000, secs: 0 },
    { id: 2, peer: '555-0187', dir: 'out', at: t - 5000, secs: 42 },
    { id: 3, peer: '555-0777', dir: 'missed', at: t - 90000, secs: 0 },
  ];
  voicemails = [{ id: 1, from: '555-0187', text: 'Rappelle-moi quand tu peux.', at: t - 90000 }];
  seq = 100;
  lastCall = null;
}
seedComm();

export const lastDialed = (): string | null => lastCall;
export const commState = (): { contacts: Contact[]; threads: Record<string, Msg[]> } => ({ contacts, threads });

export const COMM_CALLS = new Set([
  'messages:threads', 'messages:thread', 'messages:send', 'messages:read', 'messages:pin', 'messages:group', 'messages:media', 'messages:block', 'messages:leave',
  'phone:call', 'phone:answer', 'phone:decline', 'phone:hangup', 'phone:history', 'phone:voicemail', 'phone:voicemails',
  'contacts:list', 'contacts:save', 'contacts:delete',
]);

const PHONE = /^\d{3}-\d{4}$/;
const photo = 'data:image/gif;base64,R0lGODlhAQABAAAAACw=';

export function commCall(name: string, raw: unknown): unknown {
  const a = (typeof raw === 'object' && raw ? raw : {}) as Json;
  switch (name) {
    case 'messages:threads': {
      const items = Object.entries(threads).map(([id, list]) => {
        const l = list[list.length - 1];
        return { id, group: id.startsWith('g'), name: names[id], unread: list.filter((x) => !x.me && !x.read).length,
          last: l ? { kind: l.kind, body: l.kind === 'text' ? l.body : '', me: l.me, at: l.at, read: l.read } : undefined };
      });
      return { ok: true, items, pins, blocked, me: ME };
    }
    case 'messages:thread': return { ok: true, items: threads[String(a.phone)] ?? [], more: false };
    case 'messages:send': {
      const to = String(a.to);
      if (to !== ME && !PHONE.test(to) && !to.startsWith('g')) return { ok: false, err: 'err_payload' };
      const kind = String(a.kind ?? 'text');
      if (kind === 'text' && (typeof a.body !== 'string' || !a.body)) return { ok: false, err: 'err_payload' };
      const ct = kind === 'contact' ? contacts.find((x) => x.id === Number(a.ref)) : undefined;
      if (kind === 'contact' && !ct) return { ok: false, err: 'err_not_found' };
      const msg: Msg = { id: ++seq, me: true, from: ME, kind, body: kind === 'text' ? String(a.body) : ct ? ct.name : '', ref: ct ? `${ct.phone}|${ct.mail}` : kind === 'location' ? '441.0,-982.0' : a.ref == null ? null : String(a.ref), at: now(), read: false };
      threads[to] = [...(threads[to] ?? []), msg];
      return { ok: true, msg };
    }
    case 'messages:read': {
      const k = String(a.phone);
      threads[k] = (threads[k] ?? []).map((x) => (x.me ? x : { ...x, read: true }));
      return { ok: true };
    }
    case 'messages:pin': {
      const k = String(a.phone);
      pins = pins.filter((x) => x !== k);
      if (a.on === true) pins = [...pins, k];
      return { ok: true, pins };
    }
    case 'messages:block': {
      const k = String(a.phone);
      blocked = blocked.filter((x) => x !== k);
      if (a.on === true) blocked = [...blocked, k];
      return { ok: true, blocked };
    }
    case 'messages:leave': {
      const id = String(a.to);
      delete threads[id];
      return { ok: true };
    }
    case 'messages:group': {
      const id = `g${++seq}`;
      names[id] = String(a.name ?? '');
      threads[id] = [];
      return { ok: true, id };
    }
    case 'messages:media': return { ok: true, data: photo, kind: 'photo' };
    case 'phone:call': {
      const to = String(a.to);
      if (!PHONE.test(to) || to === ME) return { ok: false, err: 'err_payload' };
      lastCall = to;
      if (to === '555-0000') return { ok: false, err: 'err_unreachable' };
      return { ok: true, callId: ++seq };
    }
    case 'phone:answer': case 'phone:decline': return { ok: true };
    case 'phone:hangup': return { ok: true };
    case 'phone:history': return { ok: true, items: calls };
    case 'phone:voicemail': {
      if (typeof a.text !== 'string' || !a.text) return { ok: false, err: 'err_payload' };
      return { ok: true, id: ++seq };
    }
    case 'phone:voicemails': return { ok: true, items: voicemails };
    case 'contacts:list': return { ok: true, items: contacts };
    case 'contacts:save': {
      if (typeof a.name !== 'string' || !a.name) return { ok: false, err: 'err_payload' };
      const row: Contact = { id: typeof a.id === 'number' ? a.id : ++seq, name: a.name, phone: String(a.phone ?? ''), mail: String(a.mail ?? ''), addr: String(a.addr ?? ''), notes: String(a.notes ?? ''), grp: String(a.grp ?? ''), fav: a.fav === true };
      contacts = typeof a.id === 'number' ? contacts.map((c) => (c.id === a.id ? row : c)) : [...contacts, row];
      return { ok: true, id: row.id };
    }
    case 'contacts:delete': {
      const n = contacts.length;
      contacts = contacts.filter((c) => c.id !== raw);
      return contacts.length === n ? { ok: false, err: 'err_not_found' } : { ok: true };
    }
    default: return { ok: false, err: 'err_unavailable' };
  }
}
