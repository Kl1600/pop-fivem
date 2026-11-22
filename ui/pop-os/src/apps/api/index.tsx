import { useEffect, useRef } from 'react';
import { type AppProps } from '../../kit';
import { apiPage } from './pages';

// Cadre isolé d'une appli d'une autre ressource (docs/api-applis.md, sections 4 à 6).
// `sandbox="allow-scripts"` seul : la page n'a aucun accès au DOM de la tablette, aux cookies ni à l'origine.
// La page parle par postMessage : `pop-app:call` -> serveur (app:call), réponse `pop-app:result`.

const MAX_CALL = 4096;

export interface FrameMessage {
  type?: unknown;
  appId?: unknown;
  action?: unknown;
  data?: unknown;
  id?: unknown;
}

/** Message d'appel valide d'une page, ou null (type, appli, action et taille contrôlés ; l'appli d'une autre page est refusée). */
export function parseCall(msg: FrameMessage, appId: string): { action: string; data: unknown; id: number } | null {
  if (msg.type !== 'pop-app:call' || msg.appId !== appId) return null;
  if (typeof msg.action !== 'string' || !/^[\w.-]{1,32}$/.test(msg.action)) return null;
  if (typeof msg.id !== 'number' || !Number.isInteger(msg.id)) return null;
  if (JSON.stringify(msg.data ?? null).length > MAX_CALL) return null;
  return { action: msg.action, data: msg.data, id: msg.id };
}

/**
 * Origine cible des réponses vers le cadre. Le cadre est en `sandbox="allow-scripts"` sans `allow-same-origin` : son
 * origine est opaque (« null »), aucune origine exacte ne peut la désigner et un postMessage vers l'origine d'un hôte https serait
 * perdu. `'*'` est donc la seule cible possible ; la protection vient de `e.source`, de `e.origin === 'null'` et de
 * `frameTrusted` (jamais de relais vers une page autre que celle de l'appli).
 */
export const FRAME_TARGET = '*';

/** Le cadre est-il toujours celui de l'appli ? URL du cadre inchangée et une seule charge (une 2e charge = navigation du cadre). */
export function frameTrusted(frame: { getAttribute(name: string): string | null }, expected: string, loads: number): boolean {
  return loads === 1 && frame.getAttribute('src') === expected;
}

export default function ApiFrame(p: AppProps) {
  const ref = useRef<HTMLIFrameElement>(null);
  const loads = useRef(0);
  const info = apiPage(p.id);
  const lang = document.documentElement.lang || 'en';

  useEffect(() => {
    void p.nui.call('app:focus', p.id);
    const onMessage = (e: MessageEvent) => {
      const frame = ref.current;
      if (!frame || e.source !== frame.contentWindow || e.origin !== 'null') return;
      if (!info || !frameTrusted(frame, info.page, loads.current)) return; // URL du cadre changée : rien n'est relayé
      const call = parseCall((e.data ?? {}) as FrameMessage, p.id);
      if (!call) return;
      void p.nui.call('app:call', { appId: p.id, action: call.action, data: call.data }).then((r) => {
        if (!frameTrusted(frame, info.page, loads.current)) return;
        frame.contentWindow?.postMessage({ type: 'pop-app:result', id: call.id, ok: r.ok, data: r.data, err: r.err }, FRAME_TARGET);
      });
    };
    const onEvent = (e: Event) => {
      const d = (e as CustomEvent).detail as { appId?: string; name?: string; data?: unknown } | undefined;
      const frame = ref.current;
      if (d?.appId === p.id && frame && info && frameTrusted(frame, info.page, loads.current)) {
        frame.contentWindow?.postMessage({ type: 'pop-app:event', name: d.name, data: d.data }, FRAME_TARGET);
      }
    };
    window.addEventListener('message', onMessage);
    window.addEventListener('pop-app-event', onEvent);
    return () => {
      window.removeEventListener('message', onMessage);
      window.removeEventListener('pop-app-event', onEvent);
      void p.nui.call('app:focus', null);
    };
  }, [p.id, p.nui, info]);

  if (!info) return null;
  const init = () => {
    loads.current += 1;
    const frame = ref.current;
    if (!frame || !frameTrusted(frame, info.page, loads.current)) return; // cadre navigué ailleurs : plus d'init ni de relais
    frame.contentWindow?.postMessage({
    type: 'pop-app:init', layout: p.layout, dark: p.dark, accent: getComputedStyle(document.documentElement).getPropertyValue('--accent').trim() || undefined,
    locale: lang, rtl: document.documentElement.dir === 'rtl', data: p.data,
    }, FRAME_TARGET);
  };
  return (
    <div data-api-app={p.id} style={{ position: 'absolute', inset: 0, background: p.dark ? '#000' : '#fff' }}>
      <iframe ref={ref} title={info.name} src={info.page} sandbox="allow-scripts" onLoad={init} style={{ width: '100%', height: '100%', border: 0, display: 'block' }} />
    </div>
  );
}
