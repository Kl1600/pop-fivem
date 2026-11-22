import { useCallback, useEffect, useMemo, useState } from 'react';
import { AppIcon, Button, Field, palette, useSettingsApi, type AppProps, type StoreEntry } from '../../kit';

// Boutique : catalogue réel (applis natives + applis d'autres ressources visibles pour le métier), fiche, installation
// et retrait par le serveur. Hors ligne (Mode Avion, Wi-Fi coupé), l'appli entière est remplacée par l'écran « Pas de connexion ».

type Tab = 'discover' | 'installed' | 'search';
const TABS: Array<{ id: Tab; nameKey: string; color: string; d: string }> = [
  { id: 'discover', nameKey: 'sto.discover', color: '#0088ff', d: 'M12 3l2.5 6 6.5.5-5 4.2 1.6 6.3L12 16.8 6.4 20l1.6-6.3-5-4.2 6.5-.5z' },
  { id: 'installed', nameKey: 'sto.installed', color: '#34c759', d: 'M5 13l4 4L19 7' },
  { id: 'search', nameKey: 'sto.search', color: '#ff8d28', d: 'M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-4-4' },
];

/** Nom d'une fiche : natives dans l'interface, applis d'autres ressources par leur nom. */
export function entryName(t: AppProps['t'], e: StoreEntry): string {
  return e.api ? (e.name ?? e.id) : t(`app.${e.id}`);
}

/** Regroupe les fiches par catégorie, dans l'ordre de première apparition. */
export function groupByCategory(items: StoreEntry[]): Array<{ cat: string; items: StoreEntry[] }> {
  const out: Array<{ cat: string; items: StoreEntry[] }> = [];
  for (const it of items) {
    const cat = it.cat ?? 'work';
    let g = out.find((x) => x.cat === cat);
    if (!g) { g = { cat, items: [] }; out.push(g); }
    g.items.push(it);
  }
  return out;
}

export default function Store(p: AppProps) {
  const { t, dark } = p;
  const c = palette(dark);
  const api = useSettingsApi();
  const [items, setItems] = useState<StoreEntry[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [tab, setTab] = useState<Tab>('discover');
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const load = useCallback(async () => {
    const r = await p.nui.call<{ ok: boolean; err?: string; items?: StoreEntry[] }>('store:list');
    if (r.ok) { setItems(r.items ?? []); setErr(null); } else setErr(r.err ?? 'err_unavailable');
  }, [p.nui]);
  useEffect(() => { void load(); }, [load]);

  const act = async (e: StoreEntry) => {
    setBusy(e.id);
    const r = e.installed ? await api.uninstall(e.id) : await api.install(e);
    setBusy(null);
    if (r.ok) { setErr(null); setItems((cur) => (cur ?? []).map((x) => (x.id === e.id ? { ...x, installed: !e.installed } : x))); } else setErr(r.err ?? 'err_unavailable');
  };

  const q = query.trim().toLowerCase();
  const shown = useMemo(() => {
    const all = items ?? [];
    if (tab === 'installed') return all.filter((e) => e.installed);
    if (tab === 'search') return q === '' ? [] : all.filter((e) => entryName(t, e).toLowerCase().includes(q));
    return all;
  }, [items, tab, q, t]);
  const current = items?.find((e) => e.id === open) ?? null;
  const catName = (cat: string) => { const k = `sto.cat.${cat}`; const v = t(k); return v === k ? cat : v; };

  const button = (e: StoreEntry, big = false) => {
    const removable = e.installed && !e.system;
    const label = busy === e.id ? t('sto.wait') : e.installed ? (e.system ? t('sto.installed_label') : t('sto.remove')) : t('sto.get');
    return (
      <Button kind={e.installed ? 'plain' : 'primary'} disabled={busy === e.id || (e.installed && !removable)} onClick={() => void act(e)} aria-label={`${label} ${entryName(t, e)}`} style={big ? undefined : { minWidth: 76, padding: '6px 14px', fontSize: 15 }}>{label}</Button>
    );
  };

  const card = (e: StoreEntry) => (
    <div key={e.id} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: 14, borderRadius: 20, background: c.cell }}>
      <button onClick={() => setOpen(e.id)} aria-label={entryName(t, e)} style={{ display: 'flex', alignItems: 'center', gap: 14, flexGrow: 1, minWidth: 0, textAlign: 'start' }}>
        <AppIcon appId={e.id} size={64} dark={dark} />
        <span style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
          <span style={{ fontSize: 17, fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{entryName(t, e)}</span>
          <span style={{ fontSize: 14, color: c.sub }}>{catName(e.cat ?? 'work')}</span>
        </span>
      </button>
      {button(e)}
    </div>
  );

  const offline = err === 'err_offline';
  return (
    <div style={{ width: '100%', height: '100%', display: 'flex', background: c.bg, color: c.fg, position: 'relative' }}>
      <nav aria-label={t('app.boutique')} style={{ width: 290, flexShrink: 0, background: c.side, borderInlineEnd: `1px solid ${c.sep}`, padding: '46px 18px 20px', display: 'flex', flexDirection: 'column', gap: 6 }}>
        <span style={{ fontSize: 34, fontWeight: 700, padding: '0 8px 14px' }}>{t('app.boutique')}</span>
        {TABS.map((x) => (
          <button key={x.id} onClick={() => { setTab(x.id); setOpen(null); }} style={{ display: 'flex', alignItems: 'center', gap: 12, height: 46, padding: '0 12px', borderRadius: 12, background: tab === x.id ? 'var(--accent)' : 'transparent', color: tab === x.id ? '#fff' : c.fg, textAlign: 'start' }}>
            <span style={{ width: 30, height: 30, borderRadius: 8, background: x.color, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d={x.d} /></svg></span>
            <span style={{ fontSize: 17, fontWeight: 500 }}>{t(x.nameKey)}</span>
          </button>
        ))}
        <span style={{ flexGrow: 1 }} />
        <span style={{ fontSize: 13, color: c.sub, padding: '12px' }}>{t('sto.count', (items ?? []).filter((e) => e.installed).length)}</span>
      </nav>
      <main style={{ flexGrow: 1, minWidth: 0, height: '100%', overflowY: 'auto', padding: '46px 40px 40px', position: 'relative' }}>
        {!current && (
          <>
            <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', paddingBottom: 18 }}>
              <span style={{ fontSize: 34, fontWeight: 700 }}>{t(TABS.find((x) => x.id === tab)!.nameKey)}</span>
              {tab === 'search' && <div style={{ width: 380 }}><Field value={query} onChange={setQuery} label={t('sto.search_label')} placeholder={t('sto.search_label')} maxLength={60} /></div>}
            </div>
            {err && <span role="status" style={{ display: 'block', paddingBottom: 14, color: '#ff383c', fontSize: 16 }}>{offline ? t('net.offline') : t(err)}</span>}
            {items === null && !err && <span style={{ color: c.sub }}>{t('sto.loading')}</span>}
            {tab === 'search' && q === '' && <span style={{ color: c.sub, fontSize: 17 }}>{t('sto.search_hint')}</span>}
            {items !== null && shown.length === 0 && (tab !== 'search' || q !== '') && <span style={{ display: 'block', padding: 40, textAlign: 'center', color: c.sub, fontSize: 17 }}>{t('sto.none')}</span>}
            {groupByCategory(shown).map((g) => (
              <section key={g.cat} aria-label={catName(g.cat)} style={{ marginBottom: 18 }}>
                <span style={{ display: 'block', fontSize: 22, fontWeight: 700, padding: '8px 4px 12px', borderTop: `1px solid ${c.sep}` }}>{catName(g.cat)}</span>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(310px, 1fr))', gap: 14 }}>{g.items.map(card)}</div>
              </section>
            ))}
          </>
        )}
        {current && (
          <div data-store-detail={current.id}>
            <Button kind="plain" onClick={() => setOpen(null)} aria-label={t('kit.back')}>{`‹ ${t('kit.back')}`}</Button>
            <div style={{ display: 'flex', gap: 26, padding: '24px 0', alignItems: 'center' }}>
              <AppIcon appId={current.id} size={130} dark={dark} />
              <span style={{ display: 'flex', flexDirection: 'column', gap: 6, flexGrow: 1 }}>
                <span style={{ fontSize: 34, fontWeight: 800 }}>{entryName(t, current)}</span>
                <span style={{ fontSize: 17, color: c.sub }}>{catName(current.cat ?? 'work')}</span>
                <span style={{ marginTop: 10 }}>{button(current, true)}</span>
              </span>
            </div>
            <span style={{ display: 'block', fontSize: 22, fontWeight: 700, padding: '18px 0 8px' }}>{t('sto.description')}</span>
            <span style={{ display: 'block', fontSize: 16, lineHeight: 1.45, maxWidth: 820 }}>{current.api ? t('sto.desc_api') : t(`sto.desc.${current.id}`)}</span>
            {current.system && <span style={{ display: 'block', fontSize: 15, color: c.sub, paddingTop: 14 }}>{t('sto.system_hint')}</span>}
          </div>
        )}
      </main>
    </div>
  );
}
