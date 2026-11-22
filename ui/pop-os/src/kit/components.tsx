import { createElement, useContext, type CSSProperties, type KeyboardEvent, type PointerEvent, type ReactNode } from 'react';
import { DarkContext, FlatGlassContext, LayoutContext, useDark, useLayout } from './context';
import { palette } from './theme';
import { AppIcon } from './AppIcon';

// Composants communs : verre, bouton, ligne de liste, champ, interrupteur, curseur, feuille.
// Chaque composant lit `layout` (regular | compact) et `dark` dans les contextes, sans rien importer de l'appareil.

type GlassKind = 'g' | 'gw' | 'wg';

interface GlassProps {
  kind?: GlassKind;
  as?: 'div' | 'button' | 'span' | 'label';
  className?: string;
  style?: CSSProperties;
  children?: ReactNode;
  onClick?: (e: React.MouseEvent) => void;
  'aria-label'?: string;
  /** Force le verre à plat (sans backdrop-filter). */
  flat?: boolean;
}

/** Panneau de verre. À plat automatiquement dans une `BlurLayer` : un seul backdrop-filter par couche. */
export function Glass({ kind = 'g', as = 'div', className = '', style, children, flat, ...rest }: GlassProps) {
  const inLayer = useContext(FlatGlassContext);
  const cls = `${kind} ${flat || inLayer ? 'flat' : ''} ${className}`.trim();
  return createElement(as, { className: cls, style, ...rest }, children);
}

/** Couche qui porte le seul flou d'arrière-plan : le verre qu'elle contient est à plat. */
export function BlurLayer({ children, style, className = '', onClick }: { children?: ReactNode; style?: CSSProperties; className?: string; onClick?: () => void }) {
  return (
    <FlatGlassContext.Provider value={true}>
      <div className={`scrim ${className}`.trim()} data-blur-layer="1" onClick={onClick} style={style}>
        {children}
      </div>
    </FlatGlassContext.Provider>
  );
}

export function Button({ children, onClick, kind = 'primary', disabled, style, ...aria }: { children?: ReactNode; onClick?: () => void; kind?: 'primary' | 'plain'; disabled?: boolean; style?: CSSProperties; 'aria-label'?: string }) {
  const layout = useLayout();
  const compact = layout === 'compact';
  const base: CSSProperties = {
    display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: disabled ? 'default' : 'pointer', opacity: disabled ? 0.45 : 1,
    padding: compact ? '10px 18px' : '12px 26px', borderRadius: 22, fontSize: compact ? 15 : 17, fontWeight: 600,
    background: kind === 'primary' ? 'var(--accent)' : 'transparent', color: kind === 'primary' ? '#fff' : 'var(--accent)',
  };
  return (
    <button type="button" disabled={disabled} onClick={disabled ? undefined : onClick} style={{ ...base, ...style }} {...aria}>
      {children}
    </button>
  );
}

export function Switch({ on, onChange, label }: { on: boolean; onChange: (v: boolean) => void; label: string }) {
  const dark = useDark();
  const c = palette(dark);
  return (
    <button
      role="switch"
      aria-checked={on}
      aria-label={label}
      onClick={() => onChange(!on)}
      style={{ width: 51, height: 31, borderRadius: 16, background: on ? '#34c759' : c.fill, position: 'relative', transition: 'background .2s', flexShrink: 0 }}
    >
      <span style={{ position: 'absolute', top: 2, insetInlineStart: on ? 22 : 2, width: 27, height: 27, borderRadius: '50%', background: '#fff', boxShadow: '0 2px 4px rgba(0,0,0,.2)', transition: 'inset-inline-start .2s' }} />
    </button>
  );
}

/** Curseur horizontal (Réglages : verre, luminosité). `value` de 0 à 100. */
export function Slider({ value, onChange, label, min = 0 }: { value: number; onChange: (v: number) => void; label: string; min?: number }) {
  const dark = useDark();
  const c = palette(dark);
  const drag = (e: PointerEvent<HTMLDivElement>) => {
    if (e.type === 'pointermove' && !e.buttons) return;
    const r = e.currentTarget.getBoundingClientRect();
    if (!r.width) return;
    const rtl = getComputedStyle(e.currentTarget).direction === 'rtl';
    const x = rtl ? r.right - e.clientX : e.clientX - r.left;
    onChange(Math.max(min, Math.round(Math.max(0, Math.min(1, x / r.width)) * 100)));
  };
  const key = (e: KeyboardEvent) => {
    if (e.key === 'ArrowRight' || e.key === 'ArrowUp') onChange(Math.min(100, value + 5));
    if (e.key === 'ArrowLeft' || e.key === 'ArrowDown') onChange(Math.max(min, value - 5));
  };
  return (
    <div role="slider" tabIndex={0} aria-label={label} aria-valuemin={min} aria-valuemax={100} aria-valuenow={value} onKeyDown={key} onPointerDown={drag} onPointerMove={drag} style={{ position: 'relative', height: 30, cursor: 'pointer', touchAction: 'none', flexGrow: 1 }}>
      <span style={{ position: 'absolute', left: 0, right: 0, top: 13, height: 4, borderRadius: 2, background: c.fill }} />
      <span style={{ position: 'absolute', insetInlineStart: 0, top: 13, height: 4, borderRadius: 2, background: 'var(--accent)', width: `${value}%` }} />
      <span style={{ position: 'absolute', top: 1, insetInlineStart: `${value}%`, marginInlineStart: -14, width: 28, height: 28, borderRadius: '50%', background: '#fff', boxShadow: '0 2px 8px rgba(0,0,0,.25)' }} />
    </div>
  );
}

export function ListRow({ title, value, icon, onClick, selected, last }: { title: ReactNode; value?: ReactNode; icon?: ReactNode; onClick?: () => void; selected?: boolean; last?: boolean }) {
  const dark = useDark();
  const layout = useLayout();
  const c = palette(dark);
  return (
    <button
      type="button"
      onClick={onClick}
      style={{ display: 'flex', alignItems: 'center', gap: 12, width: '100%', padding: '0 12px', height: layout === 'compact' ? 52 : 46, background: selected ? 'var(--accent)' : 'transparent', color: selected ? '#fff' : c.fg, borderBottom: last ? 'none' : `1px solid ${c.sep}` }}
    >
      {icon}
      <span style={{ flexGrow: 1, fontSize: 17, textAlign: 'start' }}>{title}</span>
      {value !== undefined && <span style={{ fontSize: 16, color: selected ? 'rgba(255,255,255,.8)' : c.sub }}>{value}</span>}
    </button>
  );
}

export function Field({ value, onChange, label, placeholder, maxLength, type = 'text', inputMode, onEnter }: { value: string; onChange: (v: string) => void; label: string; placeholder?: string; maxLength?: number; type?: string; inputMode?: 'numeric' | 'email' | 'text'; onEnter?: () => void }) {
  const dark = useDark();
  const c = palette(dark);
  return (
    <input
      aria-label={label}
      placeholder={placeholder}
      value={value}
      maxLength={maxLength}
      type={type}
      inputMode={inputMode}
      onChange={(e) => onChange(e.target.value)}
      onKeyDown={(e) => { if (e.key === 'Enter') onEnter?.(); }}
      style={{ display: 'block', width: '100%', height: 44, borderRadius: 14, padding: '0 14px', background: c.fill, color: c.fg, fontSize: 17 }}
    />
  );
}

/** Feuille modale : centrée en `regular`, collée en bas en `compact`. */
export function Sheet({ open, onClose, title, children }: { open: boolean; onClose: () => void; title: ReactNode; children?: ReactNode }) {
  const dark = useDark();
  const layout = useLayout();
  const c = palette(dark);
  if (!open) return null;
  const compact = layout === 'compact';
  return (
    <div role="dialog" aria-modal="true" style={{ position: 'absolute', inset: 0, zIndex: 20, display: 'flex', alignItems: compact ? 'flex-end' : 'center', justifyContent: 'center', background: 'rgba(0,0,0,.35)' }} onClick={onClose}>
      <div onClick={(e) => e.stopPropagation()} style={{ width: compact ? '100%' : 520, maxWidth: '100%', borderRadius: compact ? '22px 22px 0 0' : 22, background: c.cell, color: c.fg, padding: 22, boxShadow: '0 20px 50px rgba(0,0,0,.4)' }}>
        <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 14 }}>{title}</div>
        {children}
      </div>
    </div>
  );
}

/** Fournit layout et thème à un sous-arbre (essais, futur téléphone). */
export function KitProvider({ layout, dark, children }: { layout: 'regular' | 'compact'; dark: boolean; children?: ReactNode }) {
  return (
    <LayoutContext.Provider value={layout}>
      <DarkContext.Provider value={dark}>{children}</DarkContext.Provider>
    </LayoutContext.Provider>
  );
}

/** Écran d'attente d'une appli pas encore construite : icône, nom et message, avec retour à l'accueil. */
export function AppWaiting({ id, dark, t, close }: { id: string; dark: boolean; t: (k: string, ...a: Array<string | number>) => string; close: () => void }) {
  const c = palette(dark);
  return (
    <div data-waiting={id} style={{ width: '100%', height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 14, background: c.bg, color: c.fg }}>
      <AppIcon appId={id} size={90} dark={dark} />
      <span style={{ fontSize: 26, fontWeight: 700 }}>{t(`app.${id}`)}</span>
      <span style={{ fontSize: 16, color: c.sub, textAlign: 'center', maxWidth: 420 }}>{t('app.waiting')}</span>
      <Button onClick={close}>{t('app.back_home')}</Button>
    </div>
  );
}
