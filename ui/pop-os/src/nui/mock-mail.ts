// Simulation du Mail pour le navigateur de développement et les tests (même forme de réponses que server/apps/mail.lua).
interface Mail { id: number; folder: string; from: string; to: string; subject: string; body: string; at: number; read: boolean; flag: boolean }

export const MOCK_MAIL_ADDRESS = 'moi.test@pop.ls';
export const MAIL_CALLS = new Set(['mail:folders', 'mail:list', 'mail:get', 'mail:send', 'mail:move', 'mail:flag', 'mail:delete']);

let mails: Mail[] = [];
let seq = 0;

export function seedMail(): void {
  const t = Math.floor(Date.now() / 1000);
  seq = 0;
  const add = (folder: string, from: string, to: string, subject: string, body: string, ago: number, read = false): void => {
    mails.push({ id: ++seq, folder, from, to, subject, body, at: t - ago, read, flag: false });
  };
  mails = [];
  add('inbox', 'garage@pop.ls', MOCK_MAIL_ADDRESS, 'Votre véhicule est prêt', 'Bonjour,\nvotre véhicule est prêt à être récupéré.', 3600);
  add('inbox', 'lina.costa@pop.ls', MOCK_MAIL_ADDRESS, 'Samedi soir', 'On se retrouve à 20 h ?', 86400 * 2, true);
  add('sent', MOCK_MAIL_ADDRESS, 'lina.costa@pop.ls', 'Re: Dîner', 'Avec plaisir.', 86400 * 3, true);
}
seedMail();

const view = (m: Mail, full: boolean) => ({ id: m.id, from: m.from, to: m.to, subject: m.subject, preview: m.body.slice(0, 80), ...(full ? { body: m.body } : {}), at: m.at, read: m.read, flag: m.flag, folder: m.folder });

export function mailCall(name: string, raw: unknown): unknown {
  const a = (typeof raw === 'object' && raw ? raw : {}) as Record<string, unknown>;
  const id = Number(typeof raw === 'number' ? raw : a.id);
  const find = (): Mail | undefined => mails.find((m) => m.id === id);
  switch (name) {
    case 'mail:folders': {
      const folders: Record<string, { n: number; unread: number }> = {};
      for (const m of mails) { const f = (folders[m.folder] ??= { n: 0, unread: 0 }); f.n++; if (!m.read) f.unread++; }
      folders.flagged = { n: mails.filter((m) => m.flag && m.folder !== 'trash').length, unread: 0 };
      return { ok: true, address: MOCK_MAIL_ADDRESS, folders, max: 300 };
    }
    case 'mail:list': {
      const f = String(a.folder);
      const list = mails.filter((m) => (f === 'flagged' ? m.flag && m.folder !== 'trash' : m.folder === f)).sort((x, y) => y.id - x.id);
      return { ok: true, items: list.slice(0, 30).map((m) => view(m, false)), more: list.length > 30 };
    }
    case 'mail:get': {
      const m = find();
      if (!m) return { ok: false, err: 'err_not_found' };
      m.read = true;
      return { ok: true, mail: view(m, true) };
    }
    case 'mail:send': {
      const to = String(a.to ?? '').toLowerCase();
      const draft = a.draft === true;
      if (!draft && (!/^[\w.-]+@[\w.-]+$/.test(to) || String(a.subject ?? '') === '')) return { ok: false, err: 'err_payload' };
      if (String(a.body ?? '').length > 5000) return { ok: false, err: 'err_too_large' };
      if (a.id !== undefined) mails = mails.filter((m) => !(m.id === Number(a.id) && m.folder === 'draft'));
      const now = Math.floor(Date.now() / 1000);
      const base = { from: MOCK_MAIL_ADDRESS, to, subject: String(a.subject ?? ''), body: String(a.body ?? ''), at: now, flag: false };
      mails.push({ ...base, id: ++seq, folder: draft ? 'draft' : 'sent', read: true });
      return { ok: true, id: seq };
    }
    case 'mail:move': {
      const m = find();
      if (!m) return { ok: false, err: 'err_not_found' };
      m.folder = String(a.folder);
      return { ok: true };
    }
    case 'mail:flag': {
      const m = find();
      if (!m) return { ok: false, err: 'err_not_found' };
      m.flag = a.on === true;
      return { ok: true };
    }
    case 'mail:delete': {
      const m = find();
      if (!m) return { ok: false, err: 'err_not_found' };
      if (m.folder === 'trash' || m.folder === 'draft') mails = mails.filter((x) => x !== m); else m.folder = 'trash';
      return { ok: true };
    }
    default:
      return { ok: false, err: 'err_not_found' };
  }
}
