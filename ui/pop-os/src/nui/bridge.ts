import type { NuiApi, NuiResult } from '../kit';
import type { NuiEnvelope } from './types';

declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

/** Vrai dans le client FiveM (CEF) ; faux dans un navigateur de développement. */
export const inGame = (): boolean => typeof window !== 'undefined' && typeof window.GetParentResourceName === 'function';

// Jeton de session NUI : remis par Lua dans `tablet:open` à cette page seulement, jamais transmis aux cadres des applis
// (API, Navigateur). Chaque appel `tablet:*` le joint ; sans lui, le client Lua refuse.
let sessionToken: string | null = null;

/** Joint le jeton à la charge d'un appel (hors `tablet:ready` et `tablet:locale`, publics). */
export function withToken(name: string, data: unknown, token: string | null = sessionToken): unknown {
  if (token === null || name === 'tablet:ready' || name === 'tablet:locale') return data;
  const base = data !== null && typeof data === 'object' && !Array.isArray(data) ? (data as Record<string, unknown>) : {};
  return { ...base, token };
}

/** Jeton courant (tests). */
export function currentToken(): string | null {
  return sessionToken;
}

let lockedHandler: (() => void) | null = null;

/** Le système s'abonne : un appel d'appli dit `err_locked` quand le serveur a reverrouillé la session (inactivité). */
export function onServerLocked(fn: (() => void) | null): void {
  lockedHandler = fn;
}

/** Journal des appels NUI (développement seulement) : `window.__popCalls`, un `tablet:call` est déplié en `{ name, data }` de l'appel interne. */
function recordCall(name: string, data: unknown): void {
  const w = window as unknown as { __popCalls?: Array<{ name: string; data: unknown }> };
  const inner = name === 'tablet:call' && data !== null && typeof data === 'object' ? (data as { name?: unknown; data?: unknown }) : null;
  (w.__popCalls ??= []).push(inner && typeof inner.name === 'string' ? { name: inner.name, data: inner.data } : { name, data });
}

/** Appel d'un RegisterNUICallback côté Lua. Hors jeu : réponse simulée (aucun réseau). */
export async function fetchNui<T = unknown>(name: string, data?: unknown): Promise<T | null> {
  if (!inGame()) {
    // Crochet de test (robot Playwright) : `import.meta.env.DEV` est remplacé par `false` dans le build, ce bloc n'y existe donc pas.
    if (import.meta.env.DEV) recordCall(name, data);
    // Simulation chargée à la demande : hors de l'entrée du bundle, jamais téléchargée en jeu.
    const { simulate } = await import('./mock');
    return (await simulate(name, data)) as T | null;
  }
  try {
    const res = await fetch(`https://${window.GetParentResourceName!()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(withToken(name, data === undefined ? {} : data)),
    });
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

/** Écoute `SendNUIMessage`. Les messages du kit HUD (`pop:*`) sont ignorés : la page n'en a pas l'usage. */
export function onNuiMessage(handler: (action: string, data: unknown) => void): () => void {
  const listener = (e: MessageEvent) => {
    const msg = e.data as NuiEnvelope | null;
    if (!msg || typeof msg.action !== 'string' || !msg.action.startsWith('tablet:')) return;
    let data = msg.data;
    if (msg.action === 'tablet:open' && data !== null && typeof data === 'object' && 'token' in data) {
      const { token, ...rest } = data as Record<string, unknown>;
      sessionToken = typeof token === 'string' ? token : null;
      data = rest; // le jeton ne sort pas de ce module : ni store, ni applis
    } else if (msg.action === 'tablet:close') {
      sessionToken = null;
    }
    handler(msg.action.slice('tablet:'.length), data);
  };
  window.addEventListener('message', listener);
  return () => window.removeEventListener('message', listener);
}

/** API remise aux applis : `call` passe par le relais générique `tablet:call` (liste blanche côté client). */
export const nuiApi: NuiApi = {
  call: async <T extends NuiResult = NuiResult>(name: string, data?: unknown) => {
    const res = await fetchNui<T>('tablet:call', { name, data });
    if (res && (res as NuiResult).err === 'err_locked' && lockedHandler) lockedHandler();
    return (res ?? { ok: false, err: 'err_timeout' }) as T;
  },
  post: (action, data) => fetchNui(action.startsWith('tablet:') ? action : `tablet:${action}`, data) as Promise<never>,
};
