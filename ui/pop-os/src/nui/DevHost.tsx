import { useEffect } from 'react';
import { useOS } from '../system/store';
import { inGame } from './bridge';

// Outil de développement (navigateur seulement, jamais monté en jeu) : ouvre la tablette simulée et permet de la rouvrir.
async function openMock(): Promise<void> {
  const { mockOpen, mockSetupDone, mockBoot } = await import('./mock');
  const q = new URLSearchParams(location.search);
  const dark = q.get('dark') === '1';
  // Réouverture après le premier allumage : réglages enregistrés (langue, clair/sombre, fond) et plus de configuration.
  if (mockSetupDone()) {
    const boot = mockBoot();
    const lang = boot.settings.lang ?? 'fr';
    window.postMessage({ action: 'tablet:open', data: mockOpen({ lang, rtl: lang === 'ar', needSetup: false, boot }) }, '*');
    return;
  }
  const data = mockOpen({ lang: q.get('lang') ?? 'fr', rtl: q.get('lang') === 'ar', needSetup: q.get('setup') === '1' });
  if (data.boot) data.boot = { ...data.boot, settings: { ...data.boot.settings, dark } };
  window.postMessage({ action: 'tablet:open', data }, '*');
}

export function DevHost() {
  const open = useOS((s) => s.open);
  useEffect(() => { if (!inGame()) void openMock(); }, []);
  if (inGame() || open) return null;
  return <button onClick={() => void openMock()} style={{ position: 'fixed', top: 12, left: 12, padding: '8px 14px', borderRadius: 8, background: '#222', color: '#fff', font: '14px system-ui' }}>POP Tab</button>;
}
