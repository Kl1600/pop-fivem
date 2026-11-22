// Calendrier, Rappels et Horloge simulés (mémoire seulement) : mêmes réponses que les callbacks du serveur.
type Json = Record<string, unknown>;

interface MEvent { id: number; title: string; place: string; notes: string; start: string; stop: string; allDay: boolean; alert: number | null; color: string }
interface MList { id: number; name: string; color: string }
interface MRem { id: number; list: number; title: string; done: boolean; due: string | null; flag: boolean }
interface MAlarm { id: number; label: string; minute: number; mask: number; enabled: boolean; sound: string }
interface MTimer { id: number; label: string; endsAt: number }

let events: MEvent[] = [];
let lists: MList[] = [];
let rems: MRem[] = [];
let alarms: MAlarm[] = [];
let timers: MTimer[] = [];
let seq = 100;

export function seedProd(): void {
  events = [
    { id: 1, title: 'Patrouille', place: 'Vinewood Boulevard', notes: '', start: '2026-11-22 08:00', stop: '2026-11-22 12:00', allDay: false, alert: 15, color: '#ff383c' },
    { id: 2, title: 'Réunion au poste', place: 'Poste de Mission Row', notes: 'Point hebdomadaire', start: '2026-11-24 14:00', stop: '2026-11-24 15:30', allDay: false, alert: null, color: '#0088ff' },
  ];
  lists = [{ id: 1, name: 'Travail', color: '#0088ff' }, { id: 2, name: 'Personnel', color: '#ff2d55' }];
  rems = [
    { id: 1, list: 1, title: 'Rédiger le rapport', done: false, due: '2026-11-22 18:00', flag: true },
    { id: 2, list: 2, title: 'Appeler Lina', done: false, due: null, flag: false },
    { id: 3, list: 1, title: 'Envoyer le planning', done: true, due: '2026-11-20 09:00', flag: false },
  ];
  alarms = [{ id: 1, label: 'Réveil', minute: 420, mask: 31, enabled: true, sound: '' }];
  timers = [];
}
seedProd();

export const PROD_CALLS = new Set([
  'calendar:list', 'calendar:save', 'calendar:delete',
  'reminders:list', 'reminders:save', 'reminders:delete', 'reminders:toggle', 'reminders:listSave',
  'clock:list', 'clock:saveAlarm', 'clock:deleteAlarm', 'clock:startTimer', 'clock:cancelTimer',
]);

const NOW_MS = Date.UTC(2026, 10, 22, 14, 32);

/** Réponse simulée d'un callback de Calendrier, Rappels ou Horloge. `raw` = charge brute envoyée par l'appli. */
export function prodCall(name: string, raw: unknown): unknown {
  const a = (typeof raw === 'object' && raw ? raw : {}) as Json;
  const id = Number(typeof raw === 'object' && raw ? a.id : raw);
  switch (name) {
    case 'calendar:list':
      return { ok: true, events: events.filter((e) => e.start.slice(0, 10) <= String(a.to) && e.stop.slice(0, 10) >= String(a.from)),
        alerts: events.filter((e) => e.alert !== null).map((e) => ({ id: e.id, start: e.start, allDay: e.allDay, alert: e.alert })) };
    case 'calendar:save': {
      const ev: MEvent = { id: typeof a.id === 'number' ? a.id : ++seq, title: String(a.title ?? ''), place: String(a.place ?? ''), notes: String(a.notes ?? ''), start: String(a.start), stop: String(a.stop), allDay: a.allDay === true, alert: typeof a.alert === 'number' ? a.alert : null, color: String(a.color ?? '') };
      events = typeof a.id === 'number' ? events.map((e) => (e.id === ev.id ? ev : e)) : [...events, ev];
      return { ok: true, id: ev.id };
    }
    case 'calendar:delete':
      if (!events.some((e) => e.id === id)) return { ok: false, err: 'err_not_found' };
      events = events.filter((e) => e.id !== id);
      return { ok: true };
    case 'reminders:list':
      return { ok: true, lists: lists.map((l) => ({ ...l })), items: rems.map((r) => ({ ...r })) };
    case 'reminders:listSave': {
      if (a.delete === true) { lists = lists.filter((l) => l.id !== a.id); rems = rems.filter((r) => r.list !== a.id); return { ok: true, deleted: true }; }
      const l: MList = { id: typeof a.id === 'number' ? a.id : ++seq, name: String(a.name ?? ''), color: String(a.color ?? '') };
      lists = typeof a.id === 'number' ? lists.map((x) => (x.id === l.id ? l : x)) : [...lists, l];
      return { ok: true, id: l.id, name: l.name, color: l.color };
    }
    case 'reminders:save': {
      const r: MRem = { id: typeof a.id === 'number' ? a.id : ++seq, list: Number(a.list), title: String(a.title ?? ''), done: false, due: typeof a.due === 'string' && a.due ? a.due : null, flag: a.flag === true };
      const old = rems.find((x) => x.id === r.id);
      if (old) r.done = old.done;
      rems = old ? rems.map((x) => (x.id === r.id ? r : x)) : [...rems, r];
      return { ok: true, id: r.id };
    }
    case 'reminders:toggle':
      rems = rems.map((r) => (r.id === a.id ? { ...r, done: a.done === true } : r));
      return { ok: true };
    case 'reminders:delete':
      rems = rems.filter((r) => r.id !== id);
      return { ok: true };
    case 'clock:list':
      return { ok: true, alarms: alarms.map((x) => ({ ...x })), timers: timers.map((x) => ({ id: x.id, label: x.label, remaining: Math.max(0, Math.round((x.endsAt - Date.now()) / 1000)) })) };
    case 'clock:saveAlarm': {
      const al: MAlarm = { id: typeof a.id === 'number' ? a.id : ++seq, label: String(a.label ?? ''), minute: Number(a.minute), mask: Number(a.mask ?? 0), enabled: a.enabled !== false, sound: String(a.sound ?? '') };
      alarms = typeof a.id === 'number' ? alarms.map((x) => (x.id === al.id ? al : x)) : [...alarms, al];
      return { ok: true, id: al.id };
    }
    case 'clock:deleteAlarm':
      alarms = alarms.filter((x) => x.id !== id);
      return { ok: true };
    case 'clock:startTimer': {
      if (timers.length >= 5) return { ok: false, err: 'err_limit' };
      const t = { id: ++seq, label: String(a.label ?? ''), endsAt: Date.now() + Number(a.seconds) * 1000 };
      timers = [...timers, t];
      return { ok: true, id: t.id, remaining: Number(a.seconds) };
    }
    case 'clock:cancelTimer':
      timers = timers.filter((x) => x.id !== id);
      return { ok: true };
    default:
      return { ok: false, err: 'err_unavailable', at: NOW_MS };
  }
}
