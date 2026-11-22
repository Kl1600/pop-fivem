import type { NuiApi, NuiResult } from '../kit';
import type { NuiEnvelope } from './types';

declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

/** Vrai dans le client FiveM (CEF) ; faux dans un navigateur de développement. */
export const inGame = (): boolean => typeof window !== 'undefined' && typeof window.GetParentResourceName === 'function';

/** Appel d'un RegisterNUICallback côté Lua. Hors jeu : réponse simulée (aucun réseau). */
export async function fetchNui<T = unknown>(name: string, data?: unknown): Promise<T | null> {
  if (!inGame()) {
    // Simulation chargée à la demande : hors de l'entrée du bundle, jamais téléchargée en jeu.
    const { simulate } = await import('./mock');
    return (await simulate(name, data)) as T | null;
  }
  try {
    const res = await fetch(`https://${window.GetParentResourceName!()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data === undefined ? {} : data),
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
    handler(msg.action.slice('tablet:'.length), msg.data);
  };
  window.addEventListener('message', listener);
  return () => window.removeEventListener('message', listener);
}

/** API remise aux applis : `call` passe par le relais générique `tablet:call` (liste blanche côté client). */
export const nuiApi: NuiApi = {
  call: async <T extends NuiResult = NuiResult>(name: string, data?: unknown) => {
    const res = await fetchNui<T>('tablet:call', { name, data });
    return (res ?? { ok: false, err: 'err_timeout' }) as T;
  },
  post: (action, data) => fetchNui(action.startsWith('tablet:') ? action : `tablet:${action}`, data) as Promise<never>,
};
