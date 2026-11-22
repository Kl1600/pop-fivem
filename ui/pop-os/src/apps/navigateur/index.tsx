import { useCallback, useEffect, useRef, useState } from 'react';
import { Button, type AppProps, type NuiResult } from '../../kit';
import { SITES, addressOf, resolve, type GameSite, type Page } from './sites';

interface Entry { url: string; title: string }
interface SitesRes extends NuiResult { sites?: GameSite[]; hosts?: string[]; bookmarks?: Entry[]; history?: Entry[] }
interface Tab { id: number; hist: Page[]; pos: number }

const BTN = { all: 'unset', cursor: 'pointer' } as const;
const BLUE = '#0a84ff';
const HOME: Page = { k: 'home' };

export default function App({ t, dark, nui }: AppProps) {
  const c = dark
    ? { bg: '#000000', bar: '#1c1c1e', cell: '#1c1c1e', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)' }
    : { bg: '#f2f2f7', bar: '#e9e9ee', cell: '#ffffff', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)' };
  const [game, setGame] = useState<GameSite[]>([]);
  const [hosts, setHosts] = useState<string[]>([]);
  const [marks, setMarks] = useState<Entry[]>([]);
  const [hist, setHist] = useState<Entry[]>([]);
  const [tabs, setTabs] = useState<Tab[]>([{ id: 1, hist: [HOME], pos: 0 }]);
  const [active, setActive] = useState(1);
  const [nid, setNid] = useState(2);
  const [side, setSide] = useState(false);
  const [grid, setGrid] = useState(false);
  const [addr, setAddr] = useState<string | null>(null);
  const [toast, setToast] = useState('');
  const dirty = useRef<{ bookmarks?: Entry[]; history?: Entry[] }>({});
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const flash = useCallback((text: string) => { setToast(text); setTimeout(() => setToast(''), 2200); }, []);

  useEffect(() => {
    let live = true;
    void nui.call<SitesRes>('browser:sites').then((r) => {
      if (!live || !r.ok) return;
      setGame(r.sites ?? []); setHosts(r.hosts ?? []); setMarks(r.bookmarks ?? []); setHist(r.history ?? []);
    });
    return () => { live = false; if (timer.current) clearTimeout(timer.current); };
  }, [nui]);

  // Signets et historique : un seul envoi groupé après la dernière modification (jamais un message par clic).
  const later = useCallback((patch: { bookmarks?: Entry[]; history?: Entry[] }) => {
    dirty.current = { ...dirty.current, ...patch };
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      const body = dirty.current;
      dirty.current = {};
      void nui.call('browser:save', body).then((r) => { if (!r.ok) flash(t(r.err ?? 'nav.err')); });
    }, 800);
  }, [nui, flash, t]);
  // À la fermeture de l'appli, ce qui reste en attente part tout de suite.
  useEffect(() => () => { if (Object.keys(dirty.current).length) void nui.call('browser:save', dirty.current); }, [nui]);

  const cur = tabs.find((x) => x.id === active) ?? tabs[0]!;
  const page = cur.hist[cur.pos] ?? HOME;
  const patchTab = (fn: (x: Tab) => Tab) => { setTabs((l) => l.map((x) => (x.id === cur.id ? fn(x) : x))); setAddr(null); };
  const titleOf = (p: Page): string => {
    if (p.k === 'site') return SITES.find((s) => s.key === p.key)?.name ?? '';
    if (p.k === 'game') return game.find((s) => s.domain === p.domain)?.title ?? p.domain;
    if (p.k === 'ext') return p.host;
    if (p.k === 'blocked') return t('nav.blocked_title');
    if (p.k === 'miss') return t('nav.missing_title');
    return t('nav.home');
  };
  const go = (p: Page) => {
    patchTab((x) => ({ ...x, hist: [...x.hist.slice(0, x.pos + 1), p], pos: x.pos + 1 }));
    const url = addressOf(p, game);
    if (url) {
      const next = [{ url, title: titleOf(p) }, ...hist.filter((h) => h.url !== url)].slice(0, 50);
      setHist(next); later({ history: next });
    }
  };
  const open = (url: string) => go(resolve(url, game, hosts));
  const mark = () => {
    const url = addressOf(page, game);
    if (!url) return;
    const next = marks.some((m) => m.url === url) ? marks.filter((m) => m.url !== url) : [...marks, { url, title: titleOf(page) }];
    setMarks(next); later({ bookmarks: next });
  };
  const newTab = () => { setTabs((l) => [...l, { id: nid, hist: [HOME], pos: 0 }]); setActive(nid); setNid(nid + 1); setGrid(false); setAddr(null); };
  const closeTab = (id: number) => {
    if (tabs.length === 1) { setTabs([{ id: nid, hist: [HOME], pos: 0 }]); setActive(nid); setNid(nid + 1); setGrid(false); return; }
    const rest = tabs.filter((x) => x.id !== id);
    setTabs(rest);
    if (active === id) setActive(rest[rest.length - 1]!.id);
  };
  const url = addressOf(page, game);
  const marked = !!url && marks.some((m) => m.url === url);
  const icon = (d: string) => <svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
  const tool = (label: string, d: string, onClick: () => void, off = false) => (
    <button key={label} aria-label={label} disabled={off} onClick={onClick} style={{ ...BTN, width: 40, height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: off ? 0.35 : 1, color: c.fg }}>{icon(d)}</button>
  );
  const tiles = [...SITES.map((s) => ({ name: s.name, sub: s.host, ini: s.ini, color: s.color, go: () => go({ k: 'site', key: s.key }) })),
    ...game.map((s) => ({ name: s.title, sub: `pop://${s.domain}`, ini: s.title.slice(0, 2).toUpperCase(), color: '#8e8e93', go: () => go({ k: 'game', domain: s.domain }) }))];

  const body = (() => {
    if (page.k === 'home') {
      return (
        <div style={{ padding: '28px 40px' }}>
          <h2 style={{ margin: '0 0 16px', fontSize: 22 }}>{t('nav.favorites')}</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(130px,1fr))', gap: 18 }}>
            {tiles.map((x) => (
              <button key={x.sub} style={{ ...BTN, textAlign: 'center' }} aria-label={x.name} onClick={x.go}>
                <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', width: 76, height: 76, margin: '0 auto 8px', borderRadius: 18, background: x.color, color: '#fff', fontWeight: 700, fontSize: 24 }}>{x.ini}</span>
                <span style={{ fontSize: 15 }}>{x.name}</span>
              </button>
            ))}
          </div>
          {hist.length > 0 && (
            <>
              <h2 style={{ margin: '28px 0 10px', fontSize: 22 }}>{t('nav.history')}</h2>
              {hist.slice(0, 8).map((h) => <button key={h.url} style={{ ...BTN, display: 'block', padding: '8px 0', fontSize: 17 }} onClick={() => open(h.url)}>{h.title} <span style={{ color: c.sub, fontSize: 14 }}>{h.url}</span></button>)}
            </>
          )}
        </div>
      );
    }
    if (page.k === 'site') {
      const s = SITES.find((x) => x.key === page.key);
      if (!s) return null;
      return (
        <article aria-label={s.name}>
          <div style={{ display: 'flex', gap: 24, alignItems: 'center', padding: '14px 40px', background: s.color, color: s.fg }}>
            <b style={{ fontSize: 22 }}>{s.name}</b>
            {s.menu.map((m) => <span key={m} style={{ fontSize: 15, opacity: 0.9 }}>{m}</span>)}
          </div>
          <div style={{ background: s.hero, color: '#fff', padding: '48px 40px' }}>
            <span style={{ fontSize: 13, letterSpacing: 1.5, opacity: 0.85 }}>{s.kicker}</span>
            <h1 style={{ margin: '8px 0', fontSize: 34, maxWidth: 760 }}>{s.title}</h1>
            <p style={{ margin: 0, fontSize: 18, maxWidth: 680 }}>{s.lead}</p>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(280px,1fr))', gap: 16, padding: '24px 40px' }}>
            {s.cards.map((k) => (
              <div key={k.title} style={{ borderRadius: 16, overflow: 'hidden', background: c.cell }}>
                <div style={{ height: 120, background: `linear-gradient(150deg,${k.from},${k.to})` }} />
                <div style={{ padding: 14 }}>
                  <span style={{ fontSize: 12, color: c.sub, letterSpacing: 1 }}>{k.tag}</span>
                  <h3 style={{ margin: '4px 0', fontSize: 18 }}>{k.title}</h3>
                  <span style={{ fontSize: 15, color: c.sub }}>{k.sub}</span>
                  {k.price && <b style={{ display: 'block', marginTop: 6 }}>{k.price}</b>}
                </div>
              </div>
            ))}
          </div>
        </article>
      );
    }
    if (page.k === 'game' || page.k === 'ext') {
      const g = page.k === 'game' ? game.find((x) => x.domain === page.domain) : null;
      const src = page.k === 'game' ? g?.page : page.url;
      if (!src) return <p style={{ padding: 40, color: c.sub }}>{t('nav.missing')}</p>;
      // Cadre isolé : aucun accès au DOM, aux cookies ni à l'origine de la tablette.
      return (
        <div style={{ position: 'absolute', inset: '110px 0 0 0', display: 'flex', flexDirection: 'column' }}>
          <iframe title={titleOf(page)} src={src} sandbox="allow-scripts" style={{ flexGrow: 1, border: 0, background: '#fff' }} />
          {page.k === 'ext' && <p style={{ margin: 0, padding: '6px 16px', fontSize: 13, color: c.sub, background: c.bar }}>{t('nav.frame_note')}</p>}
        </div>
      );
    }
    if (page.k === 'blocked') {
      return <div style={{ padding: '80px 40px', textAlign: 'center' }}><h1 style={{ fontSize: 28 }}>{t('nav.blocked_title')}</h1><p style={{ color: c.sub, fontSize: 17 }}>{t('nav.blocked', page.host)}</p><Button kind="plain" onClick={() => go(HOME)}>{t('nav.home')}</Button></div>;
    }
    return <div style={{ padding: '80px 40px', textAlign: 'center' }}><h1 style={{ fontSize: 28 }}>{t('nav.missing_title')}</h1><p style={{ color: c.sub, fontSize: 17 }}>{t('nav.missing_text', page.k === 'miss' ? page.text : '')}</p><Button kind="plain" onClick={() => go(HOME)}>{t('nav.home')}</Button></div>;
  })();

  return (
    <div style={{ position: 'absolute', inset: 0, background: c.bg, color: c.fg, paddingTop: 54, boxSizing: 'border-box', display: 'flex', flexDirection: 'column' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '6px 14px', background: c.bar }}>
        {tool(t('nav.bookmarks'), 'M4 5h16v14H4zM9 5v14', () => setSide(!side))}
        {tool(t('nav.back'), 'M15 5l-7 7 7 7', () => patchTab((x) => ({ ...x, pos: x.pos - 1 })), cur.pos <= 0)}
        {tool(t('nav.forward'), 'M9 5l7 7-7 7', () => patchTab((x) => ({ ...x, pos: x.pos + 1 })), cur.pos >= cur.hist.length - 1)}
        <input aria-label={t('nav.address')} placeholder={t('nav.address_ph')} value={addr ?? url} onChange={(e) => setAddr(e.target.value)} onBlur={() => setAddr(null)}
          onKeyDown={(e) => { if (e.key === 'Enter') { const v = (e.target as HTMLInputElement).value; setAddr(null); open(v); } }}
          style={{ flexGrow: 1, margin: '0 8px', height: 38, borderRadius: 12, border: 0, padding: '0 14px', fontSize: 16, background: c.cell, color: c.fg, textAlign: 'center' }} />
        {tool(t(marked ? 'nav.unmark' : 'nav.mark'), marked ? 'M12 3l2.800 6 6.200.7-4.600 4.300 1.300 6.200L12 17l-5.700 3.200 1.300-6.200L3 9.700 9.200 9z' : 'M12 4l2.500 5.500 5.500.6-4.100 3.800 1.200 5.600L12 16.600 6.900 19.500l1.200-5.600L4 10.100l5.500-.6z', mark, !url)}
        {tool(t('nav.new_tab'), 'M12 5v14M5 12h14', newTab)}
        <button aria-label={t('nav.tabs')} onClick={() => setGrid(true)} style={{ ...BTN, minWidth: 40, height: 40, textAlign: 'center', lineHeight: '40px', fontWeight: 700 }}>{tabs.length}</button>
      </div>
      <div style={{ display: 'flex', flexGrow: 1, minHeight: 0, position: 'relative' }}>
        {side && (
          <nav aria-label={t('nav.bookmarks')} style={{ width: 290, flexShrink: 0, borderInlineEnd: `1px solid ${c.sep}`, overflowY: 'auto', padding: 14 }}>
            <h2 style={{ margin: '0 0 8px', fontSize: 20 }}>{t('nav.bookmarks')}</h2>
            {marks.length === 0 && <p style={{ color: c.sub }}>{t('nav.no_marks')}</p>}
            {marks.map((m) => <button key={m.url} style={{ ...BTN, display: 'block', padding: '8px 0', width: '100%' }} onClick={() => open(m.url)}><span style={{ display: 'block', fontSize: 16 }}>{m.title}</span><span style={{ fontSize: 13, color: c.sub }}>{m.url}</span></button>)}
          </nav>
        )}
        <div style={{ flexGrow: 1, minWidth: 0, overflowY: 'auto', position: 'relative' }}>{body}</div>
      </div>

      {grid && (
        <div role="dialog" aria-label={t('nav.tabs')} style={{ position: 'absolute', inset: 0, paddingTop: 54, background: c.bg, zIndex: 5, overflowY: 'auto' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 24px' }}>
            <Button kind="plain" onClick={newTab}>{t('nav.new_tab')}</Button>
            <Button kind="plain" onClick={() => setGrid(false)}>{t('nav.done')}</Button>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(260px,1fr))', gap: 16, padding: '0 24px 24px' }}>
            {tabs.map((x) => {
              const p = x.hist[x.pos] ?? HOME;
              return (
                <div key={x.id} style={{ borderRadius: 16, background: c.cell, border: `2px solid ${x.id === active ? BLUE : 'transparent'}`, padding: 14 }}>
                  <button style={{ ...BTN, display: 'block', width: '100%', textAlign: 'start' }} aria-label={titleOf(p)} onClick={() => { setActive(x.id); setGrid(false); setAddr(null); }}>
                    <b style={{ display: 'block', fontSize: 17 }}>{titleOf(p)}</b>
                    <span style={{ fontSize: 13, color: c.sub }}>{addressOf(p, game) || t('nav.favorites')}</span>
                  </button>
                  <button aria-label={t('nav.close_tab')} onClick={() => closeTab(x.id)} style={{ ...BTN, marginTop: 8, color: '#ff453a', fontSize: 15 }}>{t('nav.close_tab')}</button>
                </div>
              );
            })}
          </div>
        </div>
      )}
      {toast && <div role="status" style={{ position: 'absolute', bottom: 24, left: '50%', transform: 'translateX(-50%)', padding: '10px 18px', borderRadius: 16, background: '#000c', color: '#fff', fontSize: 16 }}>{toast}</div>}
    </div>
  );
}
