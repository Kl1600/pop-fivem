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

export default function ApiFrame(p: AppProps) {
  const ref = useRef<HTMLIFrameElement>(null);
  const info = apiPage(p.id);
  const lang = document.documentElement.lang || 'en';

  useEffect(() => {
    void p.nui.call('app:focus', p.id);
    const onMessage = (e: MessageEvent) => {
      const frame = ref.current;
      if (!frame || e.source !== frame.contentWindow) return;
      const call = parseCall((e.data ?? {}) as FrameMessage, p.id);
      if (!call) return;
      void p.nui.call('app:call', { appId: p.id, action: call.action, data: call.data }).then((r) => {
        frame.contentWindow?.postMessage({ type: 'pop-app:result', id: call.id, ok: r.ok, data: r.data, err: r.err }, '*');
      });
    };
    const onEvent = (e: Event) => {
      const d = (e as CustomEvent).detail as { appId?: string; name?: string; data?: unknown } | undefined;
      if (d?.appId === p.id) ref.current?.contentWindow?.postMessage({ type: 'pop-app:event', name: d.name, data: d.data }, '*');
    };
    window.addEventListener('message', onMessage);
    window.addEventListener('pop-app-event', onEvent);
    return () => {
      window.removeEventListener('message', onMessage);
      window.removeEventListener('pop-app-event', onEvent);
      void p.nui.call('app:focus', null);
    };
  }, [p.id, p.nui]);

  if (!info) return null;
  const init = () => ref.current?.contentWindow?.postMessage({
    type: 'pop-app:init', layout: p.layout, dark: p.dark, accent: getComputedStyle(document.documentElement).getPropertyValue('--accent').trim() || undefined,
    locale: lang, rtl: document.documentElement.dir === 'rtl', data: p.data,
  }, '*');
  return (
    <div data-api-app={p.id} style={{ position: 'absolute', inset: 0, background: p.dark ? '#000' : '#fff' }}>
      <iframe ref={ref} title={info.name} src={info.page} sandbox="allow-scripts" onLoad={init} style={{ width: '100%', height: '100%', border: 0, display: 'block' }} />
    </div>
  );
}
