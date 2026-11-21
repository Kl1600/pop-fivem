import { AnimatePresence, motion } from 'motion/react';
import type { ReactNode } from 'react';
import { useDark, useLayout, useT } from './context';
import { palette } from './theme';

// Mises en page adaptatives : en `compact` (futur téléphone) les volets passent en pile et la barre d'onglets en pied de page.

/** Deux volets en `regular` (liste + détail). En `compact` : un seul volet à la fois (`showDetail`). */
export function SplitView({ sidebar, detail, showDetail = false, sidebarWidth = 400 }: { sidebar: ReactNode; detail: ReactNode; showDetail?: boolean; sidebarWidth?: number }) {
  const layout = useLayout();
  const dark = useDark();
  const c = palette(dark);
  if (layout === 'compact') {
    return <div data-split="compact" style={{ display: 'flex', width: '100%', height: '100%', background: c.bg, color: c.fg }}><div style={{ flexGrow: 1, minWidth: 0, height: '100%' }}>{showDetail ? detail : sidebar}</div></div>;
  }
  return (
    <div data-split="regular" style={{ display: 'flex', width: '100%', height: '100%', background: c.bg, color: c.fg, overflow: 'hidden' }}>
      <nav className="scroll" style={{ width: sidebarWidth, flexShrink: 0, height: '100%', background: c.side, borderInlineEnd: `1px solid ${c.sep}`, padding: '46px 18px 20px', display: 'flex', flexDirection: 'column', gap: 18 }}>{sidebar}</nav>
      <main className="scroll" style={{ flexGrow: 1, minWidth: 0, height: '100%', padding: '0 70px 40px' }}>{detail}</main>
    </div>
  );
}

export interface NavPage {
  key: string;
  title: ReactNode;
  content: ReactNode;
}

/** Pile de pages avec barre de titre et retour. Glissement transform/opacity seulement. */
export function NavStack({ pages, onBack }: { pages: NavPage[]; onBack: () => void }) {
  const dark = useDark();
  const layout = useLayout();
  const t = useT();
  const c = palette(dark);
  const top = pages[pages.length - 1];
  if (!top) return null;
  return (
    <div data-nav={layout} style={{ position: 'relative', width: '100%', height: '100%', overflow: 'hidden', background: c.bg, color: c.fg, display: 'flex', flexDirection: 'column' }}>
      <header style={{ height: layout === 'compact' ? 56 : 72, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', fontSize: 17, fontWeight: 600, flexShrink: 0 }}>
        {pages.length > 1 && (
          <button aria-label={t('kit.back')} onClick={onBack} style={{ position: 'absolute', insetInlineStart: 16, color: 'var(--accent)', fontSize: 17, display: 'flex', alignItems: 'center', gap: 4 }}>
            <span aria-hidden="true" style={{ display: 'inline-block', transform: 'scaleX(var(--dir,1))' }}>‹</span>{t('kit.back')}
          </button>
        )}
        {top.title}
      </header>
      <div style={{ position: 'relative', flexGrow: 1, minHeight: 0 }}>
        <AnimatePresence initial={false}>
          <motion.div key={top.key} initial={{ x: 40, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: 0.22 }} style={{ position: 'absolute', inset: 0, overflowY: 'auto' }}>
            {top.content}
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  );
}

export interface TabItem {
  id: string;
  label: string;
  icon?: ReactNode;
}

/** Barre d'onglets : pastille flottante en `regular`, pleine largeur en pied de page en `compact`. */
export function TabBar({ tabs, value, onChange }: { tabs: TabItem[]; value: string; onChange: (id: string) => void }) {
  const layout = useLayout();
  const dark = useDark();
  const c = palette(dark);
  const compact = layout === 'compact';
  return (
    <div
      role="tablist"
      data-tabbar={layout}
      style={compact
        ? { display: 'flex', width: '100%', height: 62, borderTop: `1px solid ${c.sep}`, background: c.cell }
        : { display: 'inline-flex', gap: 6, padding: 6, borderRadius: 24, background: c.cell, boxShadow: '0 6px 20px rgba(0,0,0,.12)' }}
    >
      {tabs.map((tab) => {
        const on = tab.id === value;
        return (
          <button key={tab.id} role="tab" aria-selected={on} onClick={() => onChange(tab.id)} style={{ flex: compact ? 1 : undefined, display: 'flex', flexDirection: compact ? 'column' : 'row', alignItems: 'center', justifyContent: 'center', gap: compact ? 2 : 8, padding: compact ? 0 : '8px 18px', borderRadius: 18, fontSize: compact ? 11 : 15, fontWeight: 600, color: on ? 'var(--accent)' : c.sub, background: on && !compact ? c.fill : 'transparent' }}>
            {tab.icon}{tab.label}
          </button>
        );
      })}
    </div>
  );
}
