import { useCallback, useEffect, useRef, useState } from 'react';
import { Glass, LANGUAGE_NAMES, type AppProps, type NuiResult } from '../../kit';
import { ORDER, bubble, dirOf, sameFav, suggest, translate, type Bubble, type Fav, type Mode } from './model';

const BTN = { all: 'unset', cursor: 'pointer' } as const;
const BLUE = '#0088ff';
const STAR = 'M12 3l2.7 5.6 6.1.8-4.5 4.2 1.1 6.1L12 16.8 6.6 19.7l1.1-6.1L3.2 9.4l6.1-.8z';
const NAV: Array<[Mode, string, string, string]> = [
  ['text', 'tra.text', 'M4 7h9M8.5 7c0 5-2 8-5 10M5 11c1.5 2.5 4 4 7 5M13 19l4-10 4 10M14.5 16h5', BLUE],
  ['conv', 'tra.conv', 'M4 5h12v9H9l-4 3v-3H4zM14 14h6v6l-3-2h-3', '#34c759'],
  ['fav', 'tra.favs', STAR, '#ff8d28'],
];

function Ico({ d, size = 18, fill = 'none', sw = 2, color = 'currentColor' }: { d: string; size?: number; fill?: string; sw?: number; color?: string }) {
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
}

interface RunRes extends NuiResult { text?: string }
interface FavRes extends NuiResult { items?: Fav[] }

export default function App({ t, dark, nui }: AppProps) {
  const c = dark
    ? { bg: '#000000', cell: '#1c1c1e', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', fill: '#3a3a3c' }
    : { bg: '#f2f2f7', cell: '#ffffff', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', fill: '#e3e3e8' };
  const [mode, setMode] = useState<Mode>('text');
  const [src, setSrc] = useState('fr');
  const [dst, setDst] = useState('en');
  const [text, setText] = useState('');
  const [picker, setPicker] = useState<'src' | 'dst' | null>(null);
  const [favs, setFavs] = useState<Fav[]>([]);
  const [conv, setConv] = useState<Bubble[]>([]);
  const [draft, setDraft] = useState('');
  const [copied, setCopied] = useState(false);
  const [online, setOnline] = useState<{ key: string; text: string } | null>(null);
  const [error, setError] = useState('');
  const seq = useRef(0);

  const langName = (l: string) => LANGUAGE_NAMES[l as keyof typeof LANGUAGE_NAMES] ?? l;
  const local = translate(text, src, dst);
  const key = `${src}|${dst}|${text}`;
  const viaService = online && online.key === key ? online.text : null;
  const out = viaService ?? local.text;
  const noMatch = local.kind === 'none' && viaService === null;
  const partial = local.kind === 'words' && viaService === null;

  useEffect(() => {
    void (async () => {
      const r = await nui.call<FavRes>('translate:favs');
      if (r.ok) setFavs(r.items ?? []);
    })();
  }, [nui]);

  // Service HTTP optionnel du serveur : essayé seulement quand le dictionnaire ne donne pas une phrase entière ;
  // sans service ou hors connexion, la réponse est une erreur et le dictionnaire reste la réponse.
  useEffect(() => {
    if (mode !== 'text' || !text.trim() || src === dst || local.kind === 'phrase') return;
    const mine = ++seq.current;
    const id = setTimeout(() => {
      void (async () => {
        const r = await nui.call<RunRes>('translate:run', { text: text.trim(), src, dst });
        if (mine === seq.current && r.ok && typeof r.text === 'string') setOnline({ key, text: r.text });
      })();
    }, 700);
    return () => clearTimeout(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [text, src, dst, mode]);

  const isFav = out !== '' && favs.some((f) => sameFav(f, { src, dst, s: text, t: out }));
  const setFav = useCallback(async (f: Fav, on: boolean) => {
    const r = await nui.call<FavRes>('translate:fav', { ...f, on });
    if (r.ok) setFavs(r.items ?? []); else setError(r.err ? t(r.err) : t('tra.err'));
  }, [nui, t]);

  const pickLang = (l: string) => {
    const other = picker === 'src' ? dst : src;
    if (l === other) { setSrc(dst); setDst(src); } else if (picker === 'src') setSrc(l); else setDst(l);
    setPicker(null);
  };
  const swap = () => { const o = local.kind === 'phrase' || local.kind === 'words' ? out : text; setSrc(dst); setDst(src); setText(o); setPicker(null); };
  const copy = () => {
    void navigator.clipboard?.writeText(out).catch(() => undefined);
    setCopied(true);
  };
  const send = (side: 'a' | 'b') => {
    const d = draft.trim();
    if (!d) return;
    setConv((b) => [...b, side === 'a' ? bubble('a', src, dst, d) : bubble('b', dst, src, d)]);
    setDraft('');
  };

  const sugg = suggest(text, src);
  const lang = (id: string, label: string, onClick: () => void) => (
    <Glass as="button" aria-label={label} onClick={onClick} style={{ ...BTN, flex: 1, height: 56, borderRadius: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, fontSize: 19, fontWeight: 700, color: BLUE }}>
      {langName(id)}<Ico d="M6 9l6 6 6-6" size={16} sw={2.6} />
    </Glass>
  );

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', display: 'flex', overflow: 'hidden', background: c.bg, color: c.fg, letterSpacing: '-0.01em' }}>
      <nav aria-label={t('app.traduire')} style={{ width: 280, flexShrink: 0, height: '100%', boxSizing: 'border-box', background: c.bg, borderRight: `1px solid ${c.sep}`, padding: '46px 14px 20px', display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontSize: 34, fontWeight: 700, padding: '0 10px 14px' }}>{t('app.traduire')}</span>
        {NAV.map(([id, key, d, col]) => (
          <button key={id} onClick={() => { setMode(id); setPicker(null); }} aria-pressed={mode === id} style={{ ...BTN, display: 'flex', alignItems: 'center', gap: 12, height: 46, padding: '0 10px', borderRadius: 10, background: mode === id ? BLUE : 'transparent', color: mode === id ? '#fff' : c.fg }}>
            <span style={{ width: 30, height: 30, borderRadius: 8, background: col, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={d} color="#fff" /></span>
            <span style={{ flexGrow: 1, fontSize: 17, textAlign: 'start' }}>{t(key)}</span>
            <span style={{ fontSize: 16, color: mode === id ? 'rgba(255,255,255,.85)' : c.sub }}>{id === 'fav' ? favs.length : ''}</span>
          </button>
        ))}
        <span style={{ marginTop: 'auto', padding: '0 10px', fontSize: 13, color: c.sub }}>{t('tra.offline_note')}</span>
      </nav>

      <main style={{ flexGrow: 1, minWidth: 0, height: '100%', position: 'relative', display: 'flex', flexDirection: 'column', padding: '46px 36px 28px', boxSizing: 'border-box', gap: 18 }}>
        {mode !== 'fav' && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, position: 'relative', zIndex: 3 }}>
            {lang(src, t('tra.src_lang'), () => setPicker(picker === 'src' ? null : 'src'))}
            <Glass as="button" aria-label={t('tra.swap')} onClick={swap} style={{ ...BTN, width: 56, height: 56, borderRadius: 28, display: 'flex', alignItems: 'center', justifyContent: 'center', color: c.fg }}><Ico d="M4 8h15l-4-4M20 16H5l4 4" size={24} sw={2.2} /></Glass>
            {lang(dst, t('tra.dst_lang'), () => setPicker(picker === 'dst' ? null : 'dst'))}
            {picker && (
              <Glass style={{ position: 'absolute', top: 66, [picker === 'src' ? 'insetInlineStart' : 'insetInlineEnd']: 0, width: 360, borderRadius: 24, padding: 8, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 2 }}>
                {ORDER.map((l) => {
                  const on = (picker === 'src' ? src : dst) === l;
                  return <button key={l} onClick={() => pickLang(l)} style={{ ...BTN, height: 42, padding: '0 14px', borderRadius: 14, display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: 17, fontWeight: 600, background: on ? 'rgba(0,136,255,.16)' : 'transparent', color: on ? BLUE : c.fg }}>{langName(l)}<span style={{ opacity: on ? 1 : 0 }}>✓</span></button>;
                })}
              </Glass>
            )}
          </div>
        )}
        {error && <span role="alert" style={{ fontSize: 14, color: '#ff383c' }}>{error}</span>}

        {mode === 'text' && (
          <div style={{ flexGrow: 1, display: 'flex', gap: 18, minHeight: 0 }}>
            <section aria-label={t('tra.source')} style={{ flex: 1, borderRadius: 28, background: c.cell, padding: '22px 26px', display: 'flex', flexDirection: 'column', gap: 12, minWidth: 0 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: 14, fontWeight: 600, color: c.sub }}>{langName(src)}</span>
                <button onClick={() => { setText(''); setCopied(false); }} aria-label={t('tra.clear')} style={{ ...BTN, width: 30, height: 30, borderRadius: 15, background: c.fill, display: 'flex', alignItems: 'center', justifyContent: 'center', color: c.sub }}><Ico d="M6 6l12 12M18 6L6 18" size={14} sw={3} /></button>
              </div>
              <textarea aria-label={t('tra.input')} placeholder={t('tra.input_ph')} value={text} dir={dirOf(src)} maxLength={500} onChange={(e) => { setText(e.target.value); setCopied(false); }} style={{ all: 'unset', flexGrow: 1, fontSize: 32, lineHeight: 1.3, fontWeight: 500, color: c.fg, whiteSpace: 'pre-wrap' }} />
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, minHeight: 40 }}>
                {sugg.map((s) => <button key={s} onClick={() => { setText(s); setCopied(false); }} style={{ ...BTN, padding: '8px 14px', borderRadius: 18, background: c.fill, fontSize: 15, color: c.fg }}>{s}</button>)}
              </div>
            </section>
            <section aria-label={t('tra.result')} style={{ flex: 1, borderRadius: 28, background: c.cell, padding: '22px 26px', display: 'flex', flexDirection: 'column', gap: 12, minWidth: 0 }}>
              <span style={{ fontSize: 14, fontWeight: 600, color: c.sub }}>{langName(dst)}</span>
              <span data-testid="tra-out" dir={dirOf(dst)} style={{ flexGrow: 1, fontSize: 32, lineHeight: 1.3, fontWeight: 500, color: BLUE, whiteSpace: 'pre-wrap' }}>{out}</span>
              {noMatch && <span style={{ fontSize: 15, color: c.sub }}>{t('tra.no_match')}</span>}
              {partial && <span style={{ fontSize: 15, color: c.sub }}>{t('tra.word_by_word', local.unknown)}</span>}
              {viaService !== null && <span style={{ fontSize: 15, color: c.sub }}>{t('tra.via_service')}</span>}
              <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
                <button onClick={copy} aria-label={t('tra.copy_aria')} style={{ ...BTN, height: 40, padding: '0 16px', borderRadius: 20, background: c.fill, display: 'flex', alignItems: 'center', fontSize: 15, fontWeight: 600, color: c.fg }}>{copied ? t('tra.copied') : t('tra.copy')}</button>
                <button onClick={() => { if (out) void setFav({ src, dst, s: text, t: out }, !isFav); }} aria-label={t('tra.fav_add')} aria-pressed={isFav} style={{ ...BTN, width: 40, height: 40, borderRadius: 20, background: c.fill, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#ff8d28' }}><Ico d={STAR} size={20} fill={isFav ? 'currentColor' : 'none'} /></button>
              </div>
            </section>
          </div>
        )}

        {mode === 'conv' && <>
          <div style={{ flexGrow: 1, overflowY: 'auto', borderRadius: 28, background: c.cell, padding: 26, display: 'flex', flexDirection: 'column', gap: 14 }}>
            {conv.map((b, i) => (
              <div key={i} style={{ display: 'flex', justifyContent: b.side === 'a' ? 'flex-start' : 'flex-end' }}>
                <div style={{ maxWidth: 520, padding: '14px 20px', borderRadius: 24, background: b.side === 'a' ? c.fill : BLUE, color: b.side === 'a' ? c.fg : '#fff', display: 'flex', flexDirection: 'column', gap: 6 }}>
                  <span style={{ fontSize: 13, opacity: 0.75, fontWeight: 600 }}>{langName(b.src)}</span>
                  <span dir={dirOf(b.src)} style={{ fontSize: 22, fontWeight: 600 }}>{b.text}</span>
                  <span dir={dirOf(b.dst)} style={{ fontSize: 18, color: b.side === 'a' ? BLUE : 'rgba(255,255,255,.9)' }}>{b.out || t('tra.unavailable')}</span>
                </div>
              </div>
            ))}
            {!conv.length && <span style={{ textAlign: 'center', padding: '80px 10px', color: c.sub, fontSize: 17 }}>{t('tra.conv_empty')}</span>}
          </div>
          <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            <input aria-label={t('tra.message')} placeholder={t('tra.message_ph')} value={draft} maxLength={300} onChange={(e) => setDraft(e.target.value)} style={{ all: 'unset', flex: 1, height: 56, padding: '0 22px', borderRadius: 28, background: c.cell, fontSize: 18, color: c.fg }} />
            <button onClick={() => send('a')} style={{ ...BTN, height: 56, padding: '0 22px', borderRadius: 28, background: BLUE, color: '#fff', fontSize: 16, fontWeight: 700, display: 'flex', alignItems: 'center' }}>{langName(src)}</button>
            <button onClick={() => send('b')} style={{ ...BTN, height: 56, padding: '0 22px', borderRadius: 28, background: '#34c759', color: '#fff', fontSize: 16, fontWeight: 700, display: 'flex', alignItems: 'center' }}>{langName(dst)}</button>
          </div>
        </>}

        {mode === 'fav' && <>
          <span style={{ fontSize: 34, fontWeight: 700 }}>{t('tra.favs')}</span>
          <div style={{ flexGrow: 1, overflowY: 'auto', borderRadius: 22, background: c.cell, alignSelf: 'stretch' }}>
            {favs.map((f, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 16, padding: '16px 22px', borderBottom: `1px solid ${c.sep}` }}>
                <button onClick={() => { setMode('text'); setSrc(f.src); setDst(f.dst); setText(f.s); }} style={{ ...BTN, flexGrow: 1, display: 'flex', flexDirection: 'column', gap: 4, textAlign: 'start' }}>
                  <span style={{ fontSize: 13, color: c.sub }}>{langName(f.src)} → {langName(f.dst)}</span>
                  <span style={{ fontSize: 20, fontWeight: 600 }}>{f.s}</span>
                  <span style={{ fontSize: 19, color: BLUE }}>{f.t}</span>
                </button>
                <button onClick={() => void setFav(f, false)} aria-label={t('tra.fav_remove')} style={{ ...BTN, width: 40, height: 40, borderRadius: 20, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#ff8d28' }}><Ico d={STAR} size={22} fill="currentColor" /></button>
              </div>
            ))}
            {!favs.length && <span style={{ display: 'block', textAlign: 'center', padding: '80px 10px', color: c.sub, fontSize: 17 }}>{t('tra.favs_empty')}</span>}
          </div>
        </>}
      </main>
    </div>
  );
}
