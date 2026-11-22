import { Component, useEffect, useMemo, type ErrorInfo, type ReactNode } from 'react';
import { makeT } from '../i18n';
import { useOS } from './store';

/** Écran de secours sobre : texte + bouton Fermer. Ne dépend d'aucun contexte (il doit marcher quand tout le reste a planté). */
function Fallback({ onClose, escape }: { onClose: () => void; escape?: boolean }) {
  const lang = useOS((s) => s.lang);
  const server = useOS((s) => s.server);
  const dark = useOS((s) => s.settings?.dark === true);
  const t = useMemo(() => makeT(lang, server), [lang, server]);
  // Racine : la touche Échap doit toujours fermer la tablette, même si la page principale a planté.
  useEffect(() => {
    if (!escape) return;
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, [escape, onClose]);
  return (
    <div role="alert" data-crashed="1" style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 20, background: dark ? '#000' : '#f2f2f7', color: dark ? '#fff' : '#000', zIndex: 30 }}>
      <span style={{ fontSize: 24, fontWeight: 700 }}>{t('app.crashed')}</span>
      <button onClick={onClose} style={{ fontSize: 18, fontWeight: 600, padding: '12px 36px', borderRadius: 14, background: '#0088ff', color: '#fff' }}>{t('app.crashed_close')}</button>
    </div>
  );
}

interface Props { children: ReactNode; onClose: () => void; label: string; escape?: boolean }

/** Attrape une erreur d'affichage : journal `console.error` (visible en F8), puis écran de secours. */
export class ErrorBoundary extends Component<Props, { failed: boolean }> {
  state = { failed: false };
  static getDerivedStateFromError(): { failed: boolean } { return { failed: true }; }
  componentDidCatch(error: unknown, info: ErrorInfo): void {
    console.error(`[pop_tablet] ${this.props.label} a planté :`, error, info.componentStack);
  }
  render(): ReactNode {
    return this.state.failed ? <Fallback onClose={this.props.onClose} escape={this.props.escape} /> : this.props.children;
  }
}
