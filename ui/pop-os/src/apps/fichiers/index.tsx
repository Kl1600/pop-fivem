import { useCallback, useEffect, useState } from 'react';
import { Button, Field, Glass, NearbySheet, Sheet, palette, useSettingsApi, type AppProps, type NuiResult } from '../../kit';
import { KIND_COLOR, KIND_EXT, TAGS, childCount, favFolders, fmtDate, kb, moveTargets, pathTo, tagColor, viewOf, type FileEntry, type FilesSel, type SortKey } from './model';

const BLUE = '#0088ff';
const D = {
  recents: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 7v5l3 2', shared: 'M9 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM3 19c0-3 3-5 6-5s6 2 6 5M17 8a3 3 0 0 1 0 6M20 19c0-2-1-3.500-3-4.300',
  tablet: 'M5 3h14v18H5zM11 18h2', folder: 'M4 6a2 2 0 0 1 2-2h4l2 3h6a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z', search: 'M20 20l-4-4',
  icons: 'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z', list: 'M4 6h16M4 12h16M4 18h16', share: 'M12 3v12M8 7l4-4 4 4M5 12v8h14v-8', dots: 'M5 12h.1M12 12h.1M19 12h.1',
};
type Res = Promise<NuiResult>;
type Kind = FileEntry['kind'];
interface ListRes extends NuiResult { items?: FileEntry[]; limit?: number }
interface Pv { id: number | null; name: string; kind: Kind; body: string; photo: string | null; readonly: boolean }
interface Pick { id: number; label: string; thumb?: string | null }

function Ico({ d, color = 'currentColor', size = 22 }: { d: string; color?: string; size?: number }) {
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
}

function Glyph({ e, big, nui, fill }: { e: FileEntry; big: boolean; nui: AppProps['nui']; fill: string }) {
  const [img, setImg] = useState<string | null>(null);
  useEffect(() => {
    if (e.kind !== 'photo' || e.ref === null) return;
    let live = true;
    void nui.call<NuiResult & { photo?: { data: string } }>('photos:get', e.ref).then((r) => { if (live && r.ok && r.photo) setImg(r.photo.data); });
    return () => { live = false; };
  }, [e.kind, e.ref, nui]);
  const w = big ? 120 : 34, h = big ? 96 : 28;
  if (e.kind === 'folder') return <svg aria-hidden="true" width={w} height={h} viewBox="0 0 120 96"><path d="M6 20a8 8 0 0 1 8-8h28l10 11h54a8 8 0 0 1 8 8v47a8 8 0 0 1-8 8H14a8 8 0 0 1-8-8z" fill="#1a8cff" /><rect x="6" y="30" width="108" height="56" rx="8" fill="#52aaff" /></svg>;
  if (e.kind === 'photo') return <span style={{ width: w, height: h, borderRadius: big ? 8 : 4, background: fill, overflow: 'hidden', display: 'block' }}>{img && <img alt="" src={img} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}</span>;
  const dw = big ? 76 : 24, dh = big ? 96 : 32;
  return (
    <span style={{ width: dw, height: dh, borderRadius: big ? 6 : 3, background: '#fff', boxShadow: big ? '0 2px 8px rgba(0,0,0,.25)' : 'none', border: big ? 'none' : `1px solid ${fill}`, borderTop: big ? undefined : `8px solid ${KIND_COLOR[e.kind]}`, position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', boxSizing: 'border-box' }}>
      {big && <span style={{ position: 'absolute', left: 8, right: 8, top: 12, height: 38, background: 'repeating-linear-gradient(#d1d1d6 0 3px, transparent 3px 9px)' }} />}
      {big && <span style={{ background: KIND_COLOR[e.kind], color: '#fff', fontSize: 12, fontWeight: 800, textAlign: 'center', padding: '4px 0' }}>{KIND_EXT[e.kind]}</span>}
    </span>
  );
}

export default function App(p: AppProps) {
  const { t, nui, dark } = p;
  const lang = useSettingsApi().lang;
  const c = palette(dark);
  const hi = dark ? '#2c2c2e' : '#e3e3e8';
  const [all, setAll] = useState<FileEntry[]>([]);
  const [sel, setSel] = useState<FilesSel>('tablet');
  const [path, setPath] = useState<number[]>([]);
  const [mode, setMode] = useState<'icons' | 'list'>('icons');
  const [sort, setSort] = useState<SortKey>('name');
  const [query, setQuery] = useState('');
  const [pv, setPv] = useState<Pv | null>(null);
  const [toast, setToast] = useState('');
  const [near, setNear] = useState<{ kind: 'file' | 'photo' | 'board'; id: number } | null>(null);
  const [sheet, setSheet] = useState<'none' | 'new' | 'name' | 'pick' | 'link' | 'item' | 'move'>('none');
  const [newKind, setNewKind] = useState<Kind>('folder');
  const [name, setName] = useState('');
  const [token, setToken] = useState('');
  const [picks, setPicks] = useState<Pick[]>([]);
  const [item, setItem] = useState<FileEntry | null>(null);

  const fail = useCallback((r: NuiResult) => setToast(r.err ? t(r.err) : t('fil.err')), [t]);
  const reload = useCallback(async () => {
    const r = await nui.call<ListRes>('files:list');
    // Le serveur Lua n'envoie pas les champs nil (parent, ref, tag, token) : on rétablit `null`.
    if (r.ok) setAll((Array.isArray(r.items) ? r.items : []).map((e) => ({ ...e, parent: e.parent ?? null, ref: e.ref ?? null, tag: e.tag ?? null, token: e.token ?? null }))); else fail(r);
  }, [nui, fail]);
  useEffect(() => { void reload(); }, [reload]);

  const parent = path.length ? (path[path.length - 1] as number) : null;
  const list = viewOf(all, sel, path, query, sort);
  const crumbs = [{ id: null as number | null, name: t('fil.tablet') }, ...path.map((id) => ({ id: id as number | null, name: all.find((e) => e.id === id)?.name ?? '' }))];
  const title = sel === 'tablet' ? (crumbs[crumbs.length - 1] as { name: string }).name : sel === 'recents' ? t('fil.recents') : sel === 'shared' ? t('fil.shared') : t(`fil.tag_${sel.slice(4)}`);

  const open = async (e: FileEntry) => {
    if (e.kind === 'folder') { setSel('tablet'); setPath(pathTo(all, e.id)); setQuery(''); return; }
    if (e.kind === 'doc') {
      const r = await nui.call<NuiResult & { file?: { body: string } }>('files:get', e.id);
      if (!r.ok) return fail(r);
      setPv({ id: e.id, name: e.name, kind: e.kind, body: r.file?.body ?? '', photo: null, readonly: false });
    } else if (e.kind === 'photo' && e.ref !== null) {
      const r = await nui.call<NuiResult & { photo?: { data: string } }>('photos:get', e.ref);
      setPv({ id: e.id, name: e.name, kind: e.kind, body: '', photo: r.ok ? r.photo?.data ?? null : null, readonly: false });
    } else setPv({ id: e.id, name: e.name, kind: e.kind, body: '', photo: null, readonly: false });
  };

  const create = async (kind: Kind, nm: string, refId?: number) => {
    const r = await nui.call('files:save', { kind, name: nm, ...(parent !== null ? { parentId: parent } : {}), ...(refId !== undefined ? { refId } : {}) });
    if (!r.ok) return fail(r);
    setSheet('none'); setName('');
    await reload();
  };

  const startNew = async (kind: Kind) => {
    setNewKind(kind);
    if (kind === 'folder' || kind === 'doc') { setName(''); setSheet('name'); return; }
    const src = kind === 'photo' ? 'photos:list' : kind === 'board' ? 'board:list' : 'rec:list';
    const r = await nui.call<NuiResult & { items?: Array<{ id: number; title?: string; thumb?: string | null }> }>(src, kind === 'photo' ? { scope: 'all' } : undefined);
    setPicks(r.ok ? (r.items ?? []).map((x) => ({ id: x.id, label: x.title ?? t('pho.photo', x.id), thumb: x.thumb })) : []);
    setSheet('pick');
  };

  const savePv = async () => {
    if (!pv || pv.id === null) return;
    const cur = all.find((e) => e.id === pv.id);
    const r = await nui.call('files:save', { id: pv.id, name: pv.name || t('fil.untitled'), body: pv.body, ...(cur?.tag ? { tag: cur.tag } : {}), fav: cur?.fav ?? false });
    if (!r.ok) return fail(r);
    setPv(null);
    await reload();
  };

  const share = async (id: number) => {
    const r = await nui.call<NuiResult & { token?: string }>('files:share', id);
    if (!r.ok) return fail(r);
    setToast(t('fil.share_done', r.token ?? ''));
    await reload();
  };

  const act = async (fn: () => Res) => { const r = await fn(); if (!r.ok) fail(r); else { setSheet('none'); setItem(null); await reload(); } };
  const patchItem = (e: FileEntry, ch: { tag?: string | null; fav?: boolean; name?: string }) => act(async () => {
    const r = await nui.call('files:save', { id: e.id, name: ch.name ?? e.name, fav: ch.fav ?? e.fav, ...((ch.tag !== undefined ? ch.tag : e.tag) ? { tag: ch.tag !== undefined ? ch.tag : e.tag } : {}), ...(e.kind === 'doc' ? {} : {}) });
    return r;
  });

  const openLink = async () => {
    const r = await nui.call<NuiResult & { file?: { kind: Kind; name: string; body?: string; photo?: string } }>('files:open', token.trim().toUpperCase());
    if (!r.ok || !r.file) return fail(r);
    setSheet('none'); setToken('');
    setPv({ id: null, name: r.file.name, kind: r.file.kind, body: r.file.body ?? '', photo: r.file.photo ?? null, readonly: true });
  };

  const side: Array<{ head: string; items: Array<{ key: string; name: string; d?: string; color: string; on: boolean; go: () => void; tag?: boolean }> }> = [
    { head: '', items: [
      { key: 'recents', name: t('fil.recents'), d: D.recents, color: BLUE, on: sel === 'recents', go: () => { setSel('recents'); setPath([]); setQuery(''); } },
      { key: 'shared', name: t('fil.shared'), d: D.shared, color: BLUE, on: sel === 'shared', go: () => { setSel('shared'); setPath([]); setQuery(''); } },
    ] },
    { head: t('fil.places'), items: [{ key: 'tablet', name: t('fil.tablet'), d: D.tablet, color: BLUE, on: sel === 'tablet' && path.length === 0, go: () => { setSel('tablet'); setPath([]); setQuery(''); } }] },
    { head: t('fil.favs'), items: favFolders(all).map((f) => ({ key: `f${f.id}`, name: f.name, d: D.folder, color: BLUE, on: sel === 'tablet' && path[path.length - 1] === f.id, go: () => { setSel('tablet'); setPath(pathTo(all, f.id)); setQuery(''); } })) },
    { head: t('fil.tags'), items: TAGS.map((x) => ({ key: x.id, name: t(`fil.tag_${x.id}`), color: x.color, tag: true, on: sel === `tag:${x.id}`, go: () => { setSel(`tag:${x.id}` as FilesSel); setQuery(''); } })) },
  ];

  const info = (e: FileEntry) => (e.kind === 'folder' ? t('fil.count', childCount(all, e.id)) : t('fil.kb', kb(e.size)));
  const used = all.reduce((s, e) => s + e.size, 0);

  return (
    <div data-app="fichiers" style={{ width: '100%', height: '100%', display: 'flex', background: c.cell, color: c.fg, overflow: 'hidden', position: 'relative' }}>
      <nav aria-label={t('fil.title')} className="scroll" style={{ width: 300, flexShrink: 0, height: '100%', boxSizing: 'border-box', background: c.side, borderInlineEnd: `1px solid ${c.sep}`, padding: '46px 14px 20px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontSize: 34, fontWeight: 700, padding: '0 10px 10px' }}>{t('fil.title')}</span>
        {side.map((g) => (
          <div key={g.head || 'top'} style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            {g.head && g.items.length > 0 && <span style={{ fontSize: 13, fontWeight: 600, color: c.sub, padding: '14px 10px 4px', textTransform: 'uppercase' }}>{g.head}</span>}
            {g.items.map((it) => (
              <button key={it.key} onClick={it.go} style={{ display: 'flex', alignItems: 'center', gap: 12, height: 42, padding: '0 10px', borderRadius: 10, background: it.on ? hi : 'transparent', color: c.fg }}>
                {it.tag ? <span style={{ width: 14, height: 14, borderRadius: '50%', background: it.color, margin: '0 4px' }} /> : <Ico d={it.d as string} color={it.color} />}
                <span style={{ fontSize: 17 }}>{it.name}</span>
              </button>
            ))}
          </div>
        ))}
        <button onClick={() => setSheet('link')} style={{ marginTop: 14, height: 42, padding: '0 10px', textAlign: 'start', color: BLUE, fontSize: 17 }}>{t('fil.open_link')}</button>
      </nav>

      <main style={{ flexGrow: 1, minWidth: 0, height: '100%', display: 'flex', flexDirection: 'column' }}>
        <div style={{ flexShrink: 0, padding: '40px 24px 10px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 34, fontWeight: 700, flexGrow: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{title}</span>
            <Glass as="label" style={{ height: 40, width: 230, borderRadius: 20, display: 'flex', alignItems: 'center', gap: 8, padding: '0 14px', boxSizing: 'border-box', color: c.sub }}>
              <svg aria-hidden="true" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"><circle cx="11" cy="11" r="7" /><path d={D.search} /></svg>
              <input aria-label={t('fil.search')} placeholder={t('fil.search')} value={query} onChange={(e) => setQuery(e.target.value)} style={{ flexGrow: 1, minWidth: 0, fontSize: 16, color: c.fg, background: 'transparent' }} />
            </Glass>
            <Glass style={{ display: 'flex', padding: 3, borderRadius: 20 }}>
              {(['icons', 'list'] as const).map((m) => (
                <button key={m} aria-label={t(`fil.${m}`)} aria-pressed={mode === m} onClick={() => setMode(m)} style={{ width: 42, height: 34, borderRadius: 17, display: 'flex', alignItems: 'center', justifyContent: 'center', background: mode === m ? BLUE : 'transparent', color: mode === m ? '#fff' : c.fg }}><Ico d={D[m]} size={20} /></button>
              ))}
            </Glass>
            {sel === 'tablet' && <Button onClick={() => setSheet('new')} aria-label={t('fil.new')}>{t('fil.new')}</Button>}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', minHeight: 36 }}>
            <Glass style={{ display: 'flex', alignItems: 'center', height: 34, borderRadius: 17, padding: '0 6px', fontSize: 15 }}>
              {sel === 'tablet' && !query ? crumbs.map((b, i) => (
                <button key={i} onClick={() => setPath(path.slice(0, i))} style={{ padding: '0 8px', fontWeight: i === crumbs.length - 1 ? 700 : 500, color: i === crumbs.length - 1 ? c.fg : BLUE }}>{b.name}<span style={{ color: c.sub, paddingInlineStart: 8 }}>{i < crumbs.length - 1 ? '›' : ''}</span></button>
              )) : <span style={{ padding: '0 8px' }}>{title}</span>}
            </Glass>
            <span style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 15, color: c.sub }}>{t('fil.sort')}
              {(['name', 'date', 'size', 'type'] as SortKey[]).map((k) => (
                <button key={k} onClick={() => setSort(k)} style={{ padding: '5px 12px', borderRadius: 15, fontWeight: 600, background: sort === k ? hi : 'transparent', color: sort === k ? c.fg : c.sub }}>{t(`fil.${k}`)}</button>
              ))}
            </span>
          </div>
          {toast && <span role="status" onClick={() => setToast('')} style={{ fontSize: 14, color: BLUE }}>{toast}</span>}
        </div>

        <div className="scroll" style={{ flexGrow: 1, overflowY: 'auto', padding: '8px 24px 30px' }}>
          {mode === 'icons' ? (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, minmax(0, 1fr))', gap: '22px 12px' }}>
              {list.map((e) => (
                <div key={e.id} style={{ position: 'relative' }}>
                  <button aria-label={e.name} onClick={() => void open(e)} style={{ width: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, padding: '10px 4px', borderRadius: 14, background: pv?.id === e.id ? hi : 'transparent' }}>
                    <Glyph e={e} big nui={nui} fill={c.fill} />
                    <span style={{ fontSize: 15, fontWeight: 500, textAlign: 'center', maxWidth: 140, lineHeight: 1.2, display: 'flex', alignItems: 'center', gap: 4 }}><span style={{ width: 9, height: 9, borderRadius: '50%', background: tagColor(e.tag), flexShrink: 0 }} />{e.name}</span>
                    <span style={{ fontSize: 13, color: c.sub }}>{info(e)}</span>
                  </button>
                  <button aria-label={`${t('fil.edit')} ${e.name}`} onClick={() => { setItem(e); setName(e.name); setSheet('item'); }} style={{ position: 'absolute', top: 4, insetInlineEnd: 4, color: c.sub }}><Ico d={D.dots} /></button>
                </div>
              ))}
            </div>
          ) : (
            <div>
              <div style={{ display: 'flex', padding: '6px 12px', fontSize: 13, color: c.sub, borderBottom: `1px solid ${c.sep}` }}><span style={{ flexGrow: 1 }}>{t('fil.name')}</span><span style={{ width: 160 }}>{t('fil.date')}</span><span style={{ width: 100 }}>{t('fil.size')}</span><span style={{ width: 100 }}>{t('fil.type')}</span><span style={{ width: 32 }} /></div>
              {list.map((e) => (
                <div key={e.id} style={{ display: 'flex', alignItems: 'center', borderBottom: `1px solid ${c.sep}`, height: 52 }}>
                  <button aria-label={e.name} onClick={() => void open(e)} style={{ flexGrow: 1, display: 'flex', alignItems: 'center', gap: 12, minWidth: 0, padding: '6px 12px', height: '100%', textAlign: 'start' }}>
                    <Glyph e={e} big={false} nui={nui} fill={c.sep} />
                    <span style={{ fontSize: 17, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{e.name}</span><span style={{ width: 10, height: 10, borderRadius: '50%', background: tagColor(e.tag), flexShrink: 0 }} />
                  </button>
                  <span style={{ width: 160, fontSize: 15, color: c.sub }}>{fmtDate(e.updated, lang)}</span>
                  <span style={{ width: 100, fontSize: 15, color: c.sub }}>{e.kind === 'folder' ? '--' : t('fil.kb', kb(e.size))}</span>
                  <span style={{ width: 100, fontSize: 15, color: c.sub }}>{t(`fil.k_${e.kind}`)}</span>
                  <button aria-label={`${t('fil.edit')} ${e.name}`} onClick={() => { setItem(e); setName(e.name); setSheet('item'); }} style={{ width: 32, color: c.sub }}><Ico d={D.dots} /></button>
                </div>
              ))}
            </div>
          )}
          {list.length === 0 && <span style={{ display: 'block', textAlign: 'center', padding: '120px 0', fontSize: 18, color: c.sub }}>{t('fil.empty')}</span>}
        </div>
        <div style={{ flexShrink: 0, textAlign: 'center', fontSize: 13, color: c.sub, padding: 8, borderTop: `1px solid ${c.sep}` }}>{t('fil.footer', list.length, kb(used))}</div>
      </main>

      {pv && (
        <div role="dialog" aria-label={pv.name} style={{ position: 'absolute', inset: 0, background: dark ? '#0a0a0c' : '#e9e9ee', display: 'flex', flexDirection: 'column', alignItems: 'center', zIndex: 5 }}>
          <Glass style={{ marginTop: 30, width: 1180, maxWidth: '92%', height: 56, borderRadius: 28, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 22px', boxSizing: 'border-box' }}>
            <button onClick={() => setPv(null)} style={{ fontSize: 17, fontWeight: 600, color: BLUE }}>{t('fil.ok')}</button>
            <input aria-label={t('fil.name')} value={pv.name} readOnly={pv.readonly || pv.kind !== 'doc'} maxLength={80} onChange={(e) => setPv({ ...pv, name: e.target.value })} style={{ fontSize: 16, fontWeight: 600, textAlign: 'center', color: c.fg, background: 'transparent', minWidth: 0, flexGrow: 1 }} />
            {pv.id !== null ? <button aria-label={t('fil.share')} onClick={() => void share(pv.id as number)} style={{ color: BLUE }}><Ico d={D.share} size={24} /></button> : <span style={{ width: 24 }} />}
          </Glass>
          <div style={{ flexGrow: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20, minHeight: 0 }}>
            {pv.kind === 'photo' && (pv.photo ? <img alt={pv.name} src={pv.photo} style={{ maxWidth: 820, maxHeight: 620, borderRadius: 10 }} /> : <span style={{ color: c.sub }}>{t('pho.loading')}</span>)}
            {pv.kind === 'doc' && (
              <textarea aria-label={t('fil.body')} readOnly={pv.readonly} value={pv.body} onChange={(e) => setPv({ ...pv, body: e.target.value })} style={{ width: 640, height: 720, background: '#fff', color: '#1c1c1e', borderRadius: 6, boxShadow: '0 12px 40px rgba(0,0,0,.35)', padding: 40, boxSizing: 'border-box', fontSize: 15, lineHeight: 1.5, resize: 'none' }} />
            )}
            {(pv.kind === 'audio' || pv.kind === 'board') && <span style={{ fontSize: 20 }}>{t(`fil.k_${pv.kind}`)} · {pv.name}</span>}
          </div>
          {pv.kind === 'doc' && !pv.readonly && <div style={{ paddingBottom: 24 }}><Button onClick={() => void savePv()}>{t('fil.save')}</Button></div>}
        </div>
      )}

      <Sheet open={sheet === 'new'} onClose={() => setSheet('none')} title={t('fil.new')}>
        {(['folder', 'doc', 'photo', 'board', 'audio'] as Kind[]).map((k) => (
          <button key={k} onClick={() => void startNew(k)} style={{ display: 'block', width: '100%', textAlign: 'start', height: 46, fontSize: 17, borderBottom: `1px solid ${c.sep}` }}>{k === 'folder' ? t('fil.new_folder') : k === 'doc' ? t('fil.new_doc') : k === 'photo' ? t('fil.add_photo') : k === 'board' ? t('fil.add_board') : t('fil.add_audio')}</button>
        ))}
      </Sheet>
      <Sheet open={sheet === 'name'} onClose={() => setSheet('none')} title={newKind === 'folder' ? t('fil.new_folder') : t('fil.new_doc')}>
        <Field value={name} onChange={setName} label={t('fil.name')} placeholder={t('fil.name')} maxLength={80} onEnter={() => void create(newKind, name.trim())} />
        <div style={{ marginTop: 14, display: 'flex', justifyContent: 'flex-end' }}><Button disabled={!name.trim()} onClick={() => void create(newKind, name.trim())}>{t('pho.create')}</Button></div>
      </Sheet>
      <Sheet open={sheet === 'pick'} onClose={() => setSheet('none')} title={t('fil.pick')}>
        {picks.length === 0 && <span style={{ color: c.sub }}>{t('fil.none_pick')}</span>}
        <div style={{ maxHeight: 340, overflowY: 'auto' }}>
          {picks.map((x) => (
            <button key={x.id} aria-label={x.label} onClick={() => void create(newKind, x.label.slice(0, 80), x.id)} style={{ display: 'flex', alignItems: 'center', gap: 12, width: '100%', height: 56, borderBottom: `1px solid ${c.sep}`, fontSize: 17, textAlign: 'start' }}>
              {x.thumb && <img alt="" src={x.thumb} style={{ width: 44, height: 44, objectFit: 'cover', borderRadius: 8 }} />}<span>{x.label}</span>
            </button>
          ))}
        </div>
      </Sheet>
      <Sheet open={sheet === 'link'} onClose={() => setSheet('none')} title={t('fil.open_link')}>
        <Field value={token} onChange={setToken} label={t('fil.token')} placeholder={t('fil.token')} maxLength={12} onEnter={() => void openLink()} />
        <div style={{ marginTop: 14, display: 'flex', justifyContent: 'flex-end' }}><Button disabled={token.trim().length !== 12} onClick={() => void openLink()}>{t('fil.open')}</Button></div>
      </Sheet>
      <Sheet open={sheet === 'item' && item !== null} onClose={() => setSheet('none')} title={item?.name ?? ''}>
        {item && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <Field value={name} onChange={setName} label={t('fil.rename')} maxLength={80} />
            <Button kind="plain" onClick={() => void patchItem(item, { name: name.trim() || item.name })}>{t('fil.save')}</Button>
            <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              <span style={{ color: c.sub }}>{t('fil.tag')}</span>
              {[{ id: '', color: c.sep }, ...TAGS].map((x) => (
                <button key={x.id || 'none'} aria-label={x.id ? t(`fil.tag_${x.id}`) : t('fil.no_tag')} aria-pressed={(item.tag ?? '') === x.id} onClick={() => void patchItem(item, { tag: x.id || null })} style={{ width: 28, height: 28, borderRadius: '50%', background: x.color, outline: (item.tag ?? '') === x.id ? `3px solid ${BLUE}` : 'none', outlineOffset: 2 }} />
              ))}
            </div>
            {item.kind === 'folder' && <Button kind="plain" onClick={() => void patchItem(item, { fav: !item.fav })}>{item.fav ? t('fil.fav_off') : t('fil.fav_on')}</Button>}
            <Button kind="plain" onClick={() => setSheet('move')}>{t('fil.move_title')}</Button>
            {item.kind !== 'folder' && (item.shared
              ? <Button kind="plain" onClick={() => void act(() => nui.call('files:unshare', item.id))}>{t('fil.unshare')}</Button>
              : <Button kind="plain" onClick={() => { void share(item.id); setSheet('none'); }}>{t('fil.share')}</Button>)}
            {(item.kind === 'doc' || item.kind === 'photo' || item.kind === 'board') && (item.kind === 'doc' || item.ref !== null) && (
              <Button kind="plain" onClick={() => { setNear({ kind: item.kind === 'doc' ? 'file' : (item.kind as 'photo' | 'board'), id: item.kind === 'doc' ? item.id : (item.ref as number) }); setSheet('none'); }}>{t('share.nearby')}</Button>
            )}
            <Button kind="plain" onClick={() => void act(() => nui.call('files:delete', item.id))} style={{ color: '#ff383c' }}>{t('fil.delete')}</Button>
          </div>
        )}
      </Sheet>
      <NearbySheet open={near !== null} onClose={() => setNear(null)} kind={near?.kind ?? 'file'} rid={near?.id ?? null} />
      <Sheet open={sheet === 'move' && item !== null} onClose={() => setSheet('none')} title={t('fil.move_title')}>
        {item && (
          <div style={{ maxHeight: 340, overflowY: 'auto' }}>
            <button onClick={() => void act(() => nui.call('files:move', { id: item.id }))} style={{ display: 'block', width: '100%', textAlign: 'start', height: 46, fontSize: 17, borderBottom: `1px solid ${c.sep}` }}>{t('fil.tablet')}</button>
            {moveTargets(all, item.id).map((f) => (
              <button key={f.id} onClick={() => void act(() => nui.call('files:move', { id: item.id, parentId: f.id }))} style={{ display: 'block', width: '100%', textAlign: 'start', height: 46, fontSize: 17, borderBottom: `1px solid ${c.sep}` }}>{f.name}</button>
            ))}
          </div>
        )}
      </Sheet>
    </div>
  );
}
