import { MEDIA_CALLS, mediaCall, seedMedia } from './mock-media';
import { BOARD_CALLS, boardCall, seedBoard } from './mock-board';
import { TOOLS_CALLS, mapCall, seedTools, toolsCall } from './mock-tools';
import { PROD_CALLS, prodCall, seedProd } from './mock-prod';
import type { Boot, OpenData } from './types';

// Mode simulé (navigateur de développement) : données fictives, aucune requête réseau.
// Code de la tablette fictive : 1234. Cinq erreurs de suite bloquent 60 s, comme le serveur.

export const MOCK_CODE = '1234';

const MOCK_BOOT: Boot = {
  serial: 'PT-DEV0000001',
  name: 'POP Tab',
  phone: '555-0142',
  battery: 87,
  settings: { lang: 'fr', dark: false, glass: 50, bright: 100, wall: 'auto', blur: true, wifi: true, bt: true },
  apps: ['calendrier', 'photos', 'camera', 'horloge', 'meteo', 'plans', 'rappels', 'notes', 'fichiers', 'tableau', 'calculette', 'dictaphone', 'traduire', 'bourse', 'contacts', 'boutique', 'messages', 'telephone', 'mail', 'navigateur', 'musique', 'reglages'],
  badges: { messages: 2, telephone: 1 },
  widgets: {
    events: [
      { title: 'Patrouille centre', time: '15:00 – 17:00', color: '#0088ff' },
      { title: 'Réunion au poste', time: '18:30', color: '#ff8d28' },
    ],
    reminders: [
      { id: 1, text: 'Récupérer le dossier Leroy', done: false },
      { id: 2, text: 'Faire le plein de la voiture', done: true },
      { id: 3, text: 'Appeler le central', done: false },
      { id: 4, text: 'Rapport de patrouille', done: false },
    ],
  },
  music: null,
};

/** Message `tablet:open` simulé. */
export function mockOpen(over: Partial<OpenData> = {}): OpenData {
  return {
    serial: MOCK_BOOT.serial,
    needSetup: false,
    locked: true,
    boot: MOCK_BOOT,
    lang: 'fr',
    locale: {},
    rtl: false,
    shell: true,
    clock: { h: 14, m: 32, d: 22, mo: 11, y: 2026, msPerMin: 2000 },
    weather: { temp: 24, kind: 'clear', hi: 27, lo: 18, city: 'Los Santos' },
    ...over,
  };
}

let fails = 0;
let blockedUntil = 0;
let code = MOCK_CODE;
// Messages, Téléphone et Contacts simulés : module chargé à la demande (hors du point d'entrée du bundle).
let commFresh = true;
let mailFresh = true;
let navFresh = true;
const NAV_NAMES = new Set(['browser:sites', 'browser:save', 'music:stations', 'music:save', 'music:state']);
const MAIL_NAMES = new Set(['mail:folders', 'mail:list', 'mail:get', 'mail:send', 'mail:move', 'mail:flag', 'mail:delete']);
const COMM_NAMES = new Set(['messages:threads', 'messages:thread', 'messages:send', 'messages:read', 'messages:pin', 'messages:group', 'messages:media',
  'phone:call', 'phone:answer', 'phone:decline', 'phone:hangup', 'phone:history', 'phone:voicemail', 'phone:voicemails', 'contacts:list', 'contacts:save', 'contacts:delete']);
let installed: string[] = [...MOCK_BOOT.apps];

export function resetMock(): void {
  seedMedia();
  seedProd();
  seedBoard();
  seedTools();
  commFresh = true;
  mailFresh = true;
  navFresh = true;
  installed = [...MOCK_BOOT.apps];
  fails = 0;
  blockedUntil = 0;
  code = MOCK_CODE;
}

type Json = Record<string, unknown>;

/** Réponses simulées des callbacks NUI. */
export async function simulate(name: string, data?: unknown): Promise<unknown> {
  const d = (data ?? {}) as Json;
  if (name === 'pop:ready') return { accent: undefined, locale: {} };
  if (name === 'tablet:ready' || name === 'tablet:close' || name === 'close' || name === 'tablet:schedule' || name === 'tablet:micro') return { ok: true };
  if (name === 'tablet:locale') return { ok: true, locale: {}, rtl: d.lang === 'ar' };
  if (name === 'tablet:resync') return { ok: true };
  if (name === 'tablet:map') return mapCall(data);
  if (name !== 'tablet:call') return { ok: false, err: 'err_unavailable' };
  const inner = (d.data ?? {}) as Json;
  switch (d.name) {
    case 'device:unlock': {
      const now = Date.now();
      if (now < blockedUntil) return { ok: false, err: 'err_code_blocked', wait: Math.ceil((blockedUntil - now) / 1000) };
      if (d.data === code) {
        fails = 0;
        return { ok: true, boot: MOCK_BOOT };
      }
      fails += 1;
      if (fails >= 5) {
        fails = 0;
        blockedUntil = now + 60_000;
        return { ok: false, err: 'err_code_blocked', wait: 60 };
      }
      return { ok: false, err: 'err_code_wrong' };
    }
    case 'device:setup':
      code = String(inner.code ?? code);
      return { ok: true, boot: { ...MOCK_BOOT, name: String(inner.name ?? MOCK_BOOT.name), settings: { ...MOCK_BOOT.settings, lang: String(inner.lang ?? 'fr'), mail: String(inner.mail ?? '') } } };
    case 'device:changeCode':
      if (inner.old !== code) return { ok: false, err: 'err_code_wrong' };
      code = String(inner.new);
      return { ok: true };
    case 'device:lock':
    case 'settings:save':
    case 'app:focus':
      return { ok: true };
    case 'settings:rename':
      return { ok: true, name: String(d.data ?? '') };
    case 'store:list':
      return { ok: true, items: installed.map((id) => ({ id, cat: 'tools', system: id === 'reglages' || id === 'boutique', installed: true })).concat(
        [{ id: 'police_mdt', cat: 'work', system: false, installed: false, api: true, name: 'Police MDT', page: 'nui://pop_police/web/mdt.html' } as never]) };
    case 'store:install':
      if (!installed.includes(String(d.data))) installed = [...installed, String(d.data)];
      return { ok: true, apps: installed };
    case 'store:remove':
      if (d.data === 'reglages' || d.data === 'boutique') return { ok: false, err: 'err_app_system' };
      installed = installed.filter((x) => x !== d.data);
      return { ok: true, apps: installed };
    default:
      if (NAV_NAMES.has(String(d.name))) {
        const m = await import('./mock-nav');
        if (navFresh) { m.seedNav(); navFresh = false; }
        return m.navCall(String(d.name), d.data);
      }
      if (MAIL_NAMES.has(String(d.name))) {
        const m = await import('./mock-mail');
        if (mailFresh) { m.seedMail(); mailFresh = false; }
        return m.mailCall(String(d.name), d.data);
      }
      if (COMM_NAMES.has(String(d.name))) {
        const m = await import('./mock-comm');
        if (commFresh) { m.seedComm(); commFresh = false; }
        return m.commCall(String(d.name), d.data);
      }
      return MEDIA_CALLS.has(String(d.name)) ? mediaCall(String(d.name), d.data) : PROD_CALLS.has(String(d.name)) ? prodCall(String(d.name), d.data) : BOARD_CALLS.has(String(d.name)) ? boardCall(String(d.name), d.data) : TOOLS_CALLS.has(String(d.name)) ? toolsCall(String(d.name), d.data) : { ok: false, err: 'err_unavailable' };
  }
}
