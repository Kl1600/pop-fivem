import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react';
import { Button, WALLPAPERS, palette, useDark, useT, wallpaper } from '../../kit';
import { LANGUAGES, LANGUAGE_NAMES, TABLES, RTL_LANGS } from '../../i18n';

// Écrans du premier allumage qui n'ont pas d'état propre : Bonjour, langue, apparence, fond, bienvenue.

const GREET_MS = 2600;

/** Les « Bonjour » de toutes les langues de la tablette, celui de la langue courante d'abord, sans doublon. */
export function greetings(lang: string): Array<{ lang: string; text: string }> {
  const seen = new Set<string>();
  const out: Array<{ lang: string; text: string }> = [];
  const order = [lang, ...LANGUAGES.filter((l) => l !== lang)];
  for (const l of order) {
    const table = (TABLES as Record<string, Record<string, string>>)[l];
    const text = table?.['setup.hello'];
    if (!text || seen.has(text)) continue;
    seen.add(text);
    out.push({ lang: l, text });
  }
  return out;
}

/** Halos aux couleurs de l'accent, animés en CSS (transform seulement). */
export function Aurora() {
  return (
    <div aria-hidden="true" style={{ position: 'absolute', inset: 0, overflow: 'hidden', pointerEvents: 'none' }}>
      <span className="ps-blob ps-a" />
      <span className="ps-blob ps-b" />
      <span className="ps-blob ps-c" />
    </div>
  );
}

/** Étape 1 : « Bonjour » qui défile ; glisser vers le haut ou cliquer pour commencer. */
export function HelloStep({ lang, active, onNext }: { lang: string; active: boolean; onNext: () => void }) {
  const t = useT();
  const list = useRef(greetings(lang)).current;
  const [i, setI] = useState(0);
  const startY = useRef<number | null>(null);
  // Un seul minuteur, seulement pendant cet écran.
  useEffect(() => {
    if (!active) { setI(0); return; }
    const id = setInterval(() => setI((n) => (n + 1) % list.length), GREET_MS);
    return () => clearInterval(id);
  }, [active, list.length]);
  const g = list[i] ?? list[0]!;
  return (
    <button
      type="button"
      aria-label={t('setup.slide')}
      onClick={onNext}
      onPointerDown={(e) => { startY.current = e.clientY; }}
      onPointerUp={(e) => { if (startY.current !== null && startY.current - e.clientY > 60) onNext(); startY.current = null; }}
      style={{ position: 'absolute', inset: 0, display: 'block', color: '#fff', cursor: 'pointer' }}
    >
      <span style={{ position: 'absolute', insetInline: 0, top: 380, display: 'flex', justifyContent: 'center' }}>
        <span key={`${i}-${g.lang}`} className="ps-greet" lang={g.lang} dir={RTL_LANGS.has(g.lang) ? 'rtl' : 'ltr'} style={{ fontSize: 112, fontWeight: 700, letterSpacing: -3 }}>{g.text}</span>
      </span>
      <span className="ps-bob" style={{ position: 'absolute', insetInline: 0, bottom: 70, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, fontSize: 19, fontWeight: 500, opacity: 0.9 }}>
        <svg aria-hidden="true" width="26" height="14" viewBox="0 0 26 14" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12l10-9 10 9" /></svg>
        <span>{t('setup.slide')}</span>
      </span>
    </button>
  );
}

/** Titre, texte d'aide et contenu d'une étape ; le titre porte le rôle `status` (lecteurs d'écran, tests). */
export function StepFrame({ title, hint, children, wide }: { title: string; hint?: string; children?: ReactNode; wide?: boolean }) {
  const c = palette(useDark());
  return (
    <div className="ps-step" style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 128 }}>
      <span role="status" style={{ fontSize: 42, fontWeight: 700, letterSpacing: -1, textAlign: 'center' }}>{title}</span>
      {hint && <span style={{ marginTop: 12, fontSize: 19, color: c.sub, textAlign: 'center', maxWidth: 640 }}>{hint}</span>}
      <div style={{ marginTop: 38, width: wide ? 900 : 520, display: 'flex', flexDirection: 'column', alignItems: 'center', minHeight: 0 }}>{children}</div>
    </div>
  );
}

/** Étape 2 : liste des langues de la tablette ; le choix traduit l'interface tout de suite. */
export function LanguageStep({ lang, onPick }: { lang: string; onPick: (l: string) => void }) {
  const t = useT();
  const c = palette(useDark());
  return (
    <StepFrame title={t('setup.lang')}>
      <div role="group" aria-label={t('setup.lang')} style={{ width: 520, borderRadius: 16, overflow: 'hidden', background: c.cell, maxHeight: 560, overflowY: 'auto' }}>
        {LANGUAGES.map((l, i) => (
          <button key={l} type="button" className="ps-row" aria-pressed={lang === l} onClick={() => onPick(l)} style={{ width: '100%', height: 54, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 20px', fontSize: 19, fontWeight: lang === l ? 600 : 400, color: c.fg, borderTop: i ? `1px solid ${c.sep}` : 'none' }}>
            <span lang={l}>{LANGUAGE_NAMES[l]}</span>
            {lang === l && <svg aria-hidden="true" width="22" height="18" viewBox="0 0 22 18" fill="none" stroke="var(--accent)" strokeWidth="2.8" strokeLinecap="round" strokeLinejoin="round"><path d="M2 9.5l6 6L20 3" /></svg>}
          </button>
        ))}
      </div>
    </StepFrame>
  );
}

/** Aperçu miniature de l'accueil dans le thème donné. */
function MiniHome({ dark }: { dark: boolean }) {
  const tile = dark ? 'rgba(255,255,255,.22)' : 'rgba(255,255,255,.72)';
  return (
    <div aria-hidden="true" style={{ position: 'relative', width: 300, height: 200, borderRadius: 18, overflow: 'hidden', background: wallpaper('auto', dark) }}>
      <div style={{ position: 'absolute', insetInline: 22, top: 20, display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 10 }}>
        {Array.from({ length: 12 }, (_, k) => <span key={k} style={{ aspectRatio: '1', borderRadius: 8, background: tile }} />)}
      </div>
      <span style={{ position: 'absolute', insetInline: 56, bottom: 14, height: 34, borderRadius: 14, background: tile }} />
    </div>
  );
}

/** Étape 3 : deux grandes vignettes Clair / Sombre ; le choix s'applique en direct (aperçu local, envoyé à la fin). */
export function LookStep({ dark, onPick }: { dark: boolean; onPick: (dark: boolean) => void }) {
  const t = useT();
  const c = palette(useDark());
  return (
    <StepFrame title={t('setup.look')} hint={t('setup.look_hint')} wide>
      <div style={{ display: 'flex', gap: 56, marginTop: 20 }}>
        {[false, true].map((d) => (
          <button key={String(d)} type="button" aria-pressed={dark === d} onClick={() => onPick(d)} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18, color: c.fg }}>
            <span style={{ padding: 8, borderRadius: 26, border: `3px solid ${dark === d ? 'var(--accent)' : 'transparent'}`, display: 'block' }}><MiniHome dark={d} /></span>
            <span style={{ fontSize: 22, fontWeight: dark === d ? 700 : 500 }}>{d ? t('setup.dark') : t('setup.light')}</span>
            <span aria-hidden="true" style={{ width: 26, height: 26, borderRadius: '50%', border: `2px solid ${dark === d ? 'var(--accent)' : c.sub}`, background: dark === d ? 'var(--accent)' : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {dark === d && <svg width="14" height="12" viewBox="0 0 22 18" fill="none" stroke="#fff" strokeWidth="3.4" strokeLinecap="round" strokeLinejoin="round"><path d="M2 9.5l6 6L20 3" /></svg>}
            </span>
          </button>
        ))}
      </div>
    </StepFrame>
  );
}

/** Étape 7 : fond d'écran, choix rapide parmi la collection (ou automatique). */
export function WallStep({ wall, dark, onPick }: { wall: string; dark: boolean; onPick: (w: string) => void }) {
  const t = useT();
  const items: Array<{ id: string; bg: string; label: string }> = [
    { id: 'auto', bg: wallpaper('auto', dark), label: t('set.wall_auto') },
    ...WALLPAPERS.map((bg, i) => ({ id: String(i), bg, label: t('setup.wall_n', i + 1) })),
  ];
  return (
    <StepFrame title={t('set.wall')} hint={t('setup.wall_hint')} wide>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 160px)', gap: 18, justifyContent: 'center' }}>
        {items.map((it) => {
          const on = wall === it.id;
          const ring: CSSProperties = { border: `3px solid ${on ? 'var(--accent)' : 'transparent'}`, padding: 4, borderRadius: 22, display: 'block' };
          return (
            <button key={it.id} type="button" aria-label={it.label} aria-pressed={on} onClick={() => onPick(it.id)} style={ring}>
              <span style={{ display: 'block', width: '100%', height: 104, borderRadius: 16, background: it.bg }} />
            </button>
          );
        })}
      </div>
    </StepFrame>
  );
}

/** Dernière étape : bienvenue, puis l'accueil. */
export function WelcomeStep({ onStart }: { onStart: () => void }) {
  const t = useT();
  return (
    <div className="ps-step" style={{ position: 'absolute', inset: 0 }}>
      <Aurora />
      <span role="status" style={{ position: 'absolute', insetInline: 0, top: 380, textAlign: 'center', fontSize: 72, fontWeight: 700, letterSpacing: -2 }}>{t('setup.welcome')}</span>
      <div style={{ position: 'absolute', insetInline: 0, bottom: 70, display: 'flex', justifyContent: 'center' }}>
        <Button onClick={onStart} style={{ width: 420, height: 56, borderRadius: 28, fontSize: 19 }}>{t('setup.start')}</Button>
      </div>
    </div>
  );
}
