import { useEffect } from 'react';
import { useOS } from '../system/store';
import { inGame } from './bridge';
import { mockOpen } from './mock';

// Outil de développement (navigateur seulement, jamais monté en jeu) : ouvre la tablette simulée et permet de la rouvrir.
function openMock(): void {
  const q = new URLSearchParams(location.search);
  const dark = q.get('dark') === '1';
  const data = mockOpen({ lang: q.get('lang') ?? 'fr', rtl: q.get('lang') === 'ar', needSetup: q.get('setup') === '1' });
  if (data.boot) data.boot = { ...data.boot, settings: { ...data.boot.settings, dark } };
  window.postMessage({ action: 'tablet:open', data }, '*');
}

export function DevHost() {
  const open = useOS((s) => s.open);
  useEffect(() => { if (!inGame()) openMock(); }, []);
  if (inGame() || open) return null;
  return <button onClick={openMock} style={{ position: 'fixed', top: 12, left: 12, padding: '8px 14px', borderRadius: 8, background: '#222', color: '#fff', font: '14px system-ui' }}>POP Tab</button>;
}
