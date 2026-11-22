import { useCallback, useEffect, useRef, useState } from 'react';
import { Button, Field, Glass, NearbySheet, Sheet, palette, useSettingsApi, type AppProps, type NuiResult } from '../../kit';
import { countIn, emptyBlocks, emptyTable, groupNotes, longStamp, previewOf, stamp, visibleNotes, type Block, type Folder, type FolderSel, type NoteRow } from './model';

const GOLD = '#ffa800';
const D = {
  all: 'M5 4h14v16H5zM9 9h6M9 13h6', folder: 'M4 6a2 2 0 0 1 2-2h4l2 3h6a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z', trash: 'M5 7h14M9 7V4h6v3M7 7l1 13h8l1-13',
  pen: 'M4 20h4L19 9l-4-4L4 16zM13 7l4 4', search: 'M20 20l-4-4', pin: 'M9 3h6l-1 6 3 3v2H7v-2l3-3zM12 14v7', style: 'M4 19L10 5l6 14M6.500 14h7M16 19l3-7 3 7',
  todo: 'M5 6l2 2 3-3M5 14l2 2 3-3M13 7h7M13 15h7', table: 'M4 5h16v14H4zM4 10h16M4 15h16M10 5v14', attach: 'M20 11l-8 8a5 5 0 0 1-7-7l8-8a3.500 3.500 0 0 1 5 5l-8 8a2 2 0 0 1-3-3l7-7',
  plus: 'M12 5v14M5 12h14',
};

function Ico({ d, color = 'currentColor', size = 22, fill = 'none' }: { d: string; color?: string; size?: number; fill?: string }) {
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
}

interface Cur { id: number; title: string; blocks: Block[]; pinned: boolean; folder: number | null; deleted: boolean; updated: number }
interface ListRes extends NuiResult { notes?: NoteRow[]; folders?: Folder[] }
interface GetRes extends NuiResult { note?: Cur }
interface SaveRes extends NuiResult { id?: number; updated?: number; excerpt?: string; hint?: string }
interface PhotoRes extends NuiResult { photo?: { data: string } }
interface PhotoList extends NuiResult { items?: Array<{ id: number; thumb?: string | null }> }

/** Photo jointe : la photo entière est lue au serveur à l'affichage. */
function PhotoBlock({ id, nui, c }: { id: number; nui: AppProps['nui']; c: ReturnType<typeof palette> }) {
  const [src, setSrc] = useState<string | null>(null);
  useEffect(() => {
    let live = true;
    void nui.call<PhotoRes>('photos:get', id).then((r) => { if (live && r.ok && r.photo) setSrc(r.photo.data); });
    return () => { live = false; };
  }, [id, nui]);
  return src ? <img alt="" src={src} style={{ maxWidth: 360, maxHeight: 260, borderRadius: 14, display: 'block' }} /> : <span style={{ display: 'block', width: 360, height: 220, borderRadius: 14, background: c.fill }} />;
}

export default function App(p: AppProps) {
  const { t, nui, dark } = p;
  const lang = useSettingsApi().lang;
  const c = palette(dark);
  const cellAlt = dark ? '#2c2c2e' : '#f2f2f7';
  const [notes, setNotes] = useState<NoteRow[]>([]);
  const [folders, setFolders] = useState<Folder[]>([]);
  const [sel, setSel] = useState<FolderSel>('all');
  const [cur, setCur] = useState<Cur | null>(null);
  const [near, setNear] = useState(false);
  const [query, setQuery] = useState('');
  const [big, setBig] = useState(false);
  const [error, setError] = useState('');
  const [folderSheet, setFolderSheet] = useState(false);
  const [folderName, setFolderName] = useState('');
  const [photoSheet, setPhotoSheet] = useState(false);
  const [photos, setPhotos] = useState<Array<{ id: number; thumb?: string | null }>>([]);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pending = useRef<Cur | null>(null);

  const fail = useCallback((r: NuiResult) => setError(r.err ? t(r.err) : t('not.err')), [t]);

  useEffect(() => {
    let live = true;
    void nui.call<ListRes>('notes:list').then((r) => {
      if (!live) return;
      // Le serveur Lua n'envoie pas `folder` quand il est nil : on rétablit `null`.
      if (r.ok) { setNotes((Array.isArray(r.notes) ? r.notes : []).map((n) => ({ ...n, folder: n.folder ?? null }))); setFolders(Array.isArray(r.folders) ? r.folders : []); } else fail(r);
    });
    return () => { live = false; };
  }, [nui, fail]);

  const patchRow = useCallback((id: number, patch: Partial<NoteRow>) => setNotes((l) => l.map((n) => (n.id === id ? { ...n, ...patch } : n))), []);

  const flush = useCallback(async () => {
    if (timer.current) { clearTimeout(timer.current); timer.current = null; }
    const n = pending.current;
    if (!n) return;
    pending.current = null;
    const r = await nui.call<SaveRes>('notes:save', { id: n.id, title: n.title, blocks: n.blocks, pinned: n.pinned, ...(n.folder !== null ? { folder: n.folder } : {}) });
    if (r.ok) patchRow(n.id, { title: n.title, excerpt: r.excerpt ?? '', hint: r.hint ?? '', pinned: n.pinned, updated: r.updated ?? n.updated });
    else fail(r);
  }, [nui, patchRow, fail]);

  // Enregistre ce qui reste à la fermeture de l'appli.
  useEffect(() => () => { void flush(); }, [flush]);

  const edit = (next: Cur, now = false) => {
    setCur(next);
    pending.current = next;
    if (timer.current) clearTimeout(timer.current);
    if (now) void flush(); else timer.current = setTimeout(() => void flush(), 500);
  };

  const pick = async (id: number) => {
    await flush();
    const r = await nui.call<GetRes>('notes:get', id);
    if (r.ok && r.note) setCur({ ...r.note, folder: r.note.folder ?? null }); else fail(r);
  };

  const create = async () => {
    await flush();
    const folder = typeof sel === 'number' ? sel : undefined;
    const r = await nui.call<SaveRes>('notes:save', { title: '', blocks: emptyBlocks(), ...(folder !== undefined ? { folder } : {}) });
    if (!r.ok || r.id === undefined) return fail(r);
    const row: NoteRow = { id: r.id, folder: folder ?? null, title: '', excerpt: '', hint: '', pinned: false, deleted: false, updated: r.updated ?? 0 };
    setNotes((l) => [row, ...l]);
    setCur({ id: r.id, title: '', blocks: emptyBlocks(), pinned: false, folder: folder ?? null, deleted: false, updated: r.updated ?? 0 });
    setQuery('');
  };

  const remove = async () => {
    if (!cur) return;
    pending.current = null;
    const r = await nui.call<NuiResult & { permanent?: boolean }>('notes:delete', cur.id);
    if (!r.ok) return fail(r);
    if (r.permanent) setNotes((l) => l.filter((n) => n.id !== cur.id)); else patchRow(cur.id, { deleted: true, pinned: false });
    setCur(null);
  };

  const restore = async () => {
    if (!cur) return;
    const r = await nui.call('notes:restore', cur.id);
    if (!r.ok) return fail(r);
    patchRow(cur.id, { deleted: false });
    setCur({ ...cur, deleted: false });
  };

  const addFolder = async () => {
    const r = await nui.call<NuiResult & { id?: number; name?: string }>('notes:folderSave', { name: folderName });
    if (!r.ok || r.id === undefined) return fail(r);
    setFolders((l) => [...l, { id: r.id as number, name: r.name ?? folderName }]);
    setFolderName('');
    setFolderSheet(false);
    setSel(r.id);
  };

  const removeFolder = async () => {
    if (typeof sel !== 'number') return;
    const r = await nui.call('notes:folderDelete', sel);
    if (!r.ok) return fail(r);
    setNotes((l) => l.map((n) => (n.folder === sel ? { ...n, folder: null } : n)));
    setFolders((l) => l.filter((f) => f.id !== sel));
    setSel('all');
  };

  const openPhotos = async () => {
    const r = await nui.call<PhotoList>('photos:list', { scope: 'all' });
    setPhotos(r.ok ? (r.items ?? []) : []);
    setPhotoSheet(true);
  };

  const setBlock = (i: number, b: Block) => cur && edit({ ...cur, blocks: cur.blocks.map((x, j) => (j === i ? b : x)) });
  const addBlock = (b: Block) => cur && edit({ ...cur, blocks: [...cur.blocks, b] }, true);

  const visible = visibleNotes(notes, sel, query);
  const { pinned, rest } = groupNotes(visible);
  const inTrash = sel === 'trash';
  const selName = sel === 'all' ? t('not.all') : sel === 'def' ? t('not.default') : sel === 'trash' ? t('not.trash') : folders.find((f) => f.id === sel)?.name ?? '';
  const side: Array<{ key: string; sel: FolderSel; name: string; d: string }> = [
    { key: 'all', sel: 'all', name: t('not.all'), d: D.all },
    { key: 'def', sel: 'def', name: t('not.default'), d: D.folder },
    ...folders.map((f) => ({ key: `f${f.id}`, sel: f.id as FolderSel, name: f.name, d: D.folder })),
    { key: 'trash', sel: 'trash', name: t('not.trash'), d: D.trash },
  ];

  const row = (n: NoteRow, i: number, arr: NoteRow[]) => {
    const on = cur?.id === n.id;
    return (
      <button key={n.id} onClick={() => void pick(n.id)} style={{ display: 'flex', flexDirection: 'column', gap: 2, width: '100%', boxSizing: 'border-box', padding: '11px 14px', textAlign: 'start', background: on ? GOLD : 'transparent', color: on ? '#fff' : c.fg, borderBottom: i < arr.length - 1 && !on ? `1px solid ${c.sep}` : '1px solid transparent' }}>
        <span style={{ fontSize: 17, fontWeight: 700, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{n.title || t('not.untitled')}</span>
        <span style={{ fontSize: 14, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', color: on ? 'rgba(255,255,255,.85)' : c.sub }}><span style={{ color: on ? '#fff' : c.fg }}>{stamp(n.updated, lang)}</span>{'  '}{previewOf(n, t)}</span>
      </button>
    );
  };
  const group = (head: string, list: NoteRow[]) => list.length > 0 && (
    <div key={head}>
      <span style={{ display: 'block', fontSize: 15, fontWeight: 700, padding: '12px 8px 6px' }}>{head}</span>
      <div style={{ borderRadius: 14, background: cellAlt, overflow: 'hidden' }}>{list.map(row)}</div>
    </div>
  );

  const tools = [
    { key: 'style', label: t('not.style'), d: D.style, on: big, go: () => setBig(!big) },
    { key: 'todo', label: t('not.todo'), d: D.todo, on: false, go: () => addBlock({ type: 'todo', items: [{ t: '', done: false }] }) },
    { key: 'table', label: t('not.table'), d: D.table, on: false, go: () => addBlock({ type: 'table', rows: emptyTable() }) },
    { key: 'attach', label: t('not.attach'), d: D.attach, on: false, go: () => void openPhotos() },
  ];

  const input = { color: c.fg, background: 'transparent', fontSize: 17 } as const;

  return (
    <div data-app="notes" style={{ width: '100%', height: '100%', display: 'flex', background: c.bg, color: c.fg, overflow: 'hidden', position: 'relative' }}>
      <nav aria-label={t('not.folders')} style={{ width: 280, flexShrink: 0, height: '100%', boxSizing: 'border-box', background: c.side, borderInlineEnd: `1px solid ${c.sep}`, padding: '46px 14px 20px', display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontSize: 34, fontWeight: 700, padding: '0 10px 12px' }}>{t('not.folders')}</span>
        <span style={{ fontSize: 13, fontWeight: 600, color: c.sub, padding: '6px 10px' }}>{t('not.on_tablet')}</span>
        {side.map((f) => {
          const on = sel === f.sel;
          return (
            <button key={f.key} onClick={() => { void flush(); setSel(f.sel); }} style={{ display: 'flex', alignItems: 'center', gap: 12, height: 44, padding: '0 10px', borderRadius: 10, background: on ? GOLD : 'transparent', color: on ? '#fff' : c.fg }}>
              <Ico d={f.d} color={on ? '#fff' : GOLD} />
              <span style={{ flexGrow: 1, fontSize: 17, textAlign: 'start' }}>{f.name}</span>
              <span style={{ fontSize: 16, color: on ? 'rgba(255,255,255,.85)' : c.sub }}>{countIn(notes, f.sel)}</span>
            </button>
          );
        })}
        <button onClick={() => setFolderSheet(true)} aria-label={t('not.folder_new')} style={{ display: 'flex', alignItems: 'center', gap: 12, height: 44, padding: '0 10px', color: GOLD }}>
          <Ico d={D.plus} color={GOLD} /><span style={{ fontSize: 17 }}>{t('not.folder_new')}</span>
        </button>
      </nav>

      <section aria-label={selName} style={{ width: 370, flexShrink: 0, height: '100%', boxSizing: 'border-box', background: c.cell, borderInlineEnd: `1px solid ${c.sep}`, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '46px 18px 10px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          <span style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 34, fontWeight: 700, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{selName}</span>
            <Glass as="button" aria-label={t('not.new')} onClick={() => void create()} style={{ width: 44, height: 44, borderRadius: 22, display: 'flex', alignItems: 'center', justifyContent: 'center', color: GOLD, flexShrink: 0 }}><Ico d={D.pen} /></Glass>
          </span>
          <label style={{ height: 40, borderRadius: 20, background: dark ? '#3a3a3c' : '#e3e3e8', display: 'flex', alignItems: 'center', gap: 8, padding: '0 12px', color: c.sub }}>
            <svg aria-hidden="true" width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"><circle cx="11" cy="11" r="7" /><path d={D.search} /></svg>
            <input aria-label={t('not.search')} placeholder={t('home.search')} value={query} onChange={(e) => setQuery(e.target.value)} style={{ ...input, flexGrow: 1, minWidth: 0 }} />
          </label>
          {error && <span role="alert" style={{ color: '#ff383c', fontSize: 14 }}>{error}</span>}
        </div>
        <div className="scroll" style={{ flexGrow: 1, overflowY: 'auto', padding: '0 12px 24px' }}>
          {inTrash ? group(t('not.trash'), rest) : (<>{group(t('not.pinned'), pinned)}{group(pinned.length ? t('not.notes') : t('not.recent'), rest)}</>)}
          {visible.length === 0 && <span style={{ display: 'block', textAlign: 'center', padding: '60px 10px', color: c.sub, fontSize: 16 }}>{t('not.none')}</span>}
          {typeof sel === 'number' && <button onClick={() => void removeFolder()} style={{ display: 'block', margin: '18px auto 0', color: '#ff383c', fontSize: 15 }}>{t('not.folder_del')}</button>}
        </div>
      </section>

      <main style={{ flexGrow: 1, minWidth: 0, height: '100%', position: 'relative', display: 'flex', flexDirection: 'column', background: c.cell }}>
        {cur ? (
          <>
            <div style={{ height: 76, flexShrink: 0, display: 'flex', alignItems: 'flex-end', justifyContent: 'flex-end', gap: 10, padding: '0 22px 8px' }}>
              {cur.deleted ? (
                <Button kind="plain" onClick={() => void restore()}>{t('not.restore')}</Button>
              ) : (
                <Glass as="button" aria-label={t('not.pin')} onClick={() => edit({ ...cur, pinned: !cur.pinned }, true)} style={{ height: 40, padding: '0 16px', borderRadius: 20, display: 'flex', alignItems: 'center', gap: 6, fontSize: 15, fontWeight: 600, color: cur.pinned ? GOLD : c.fg }}>
                  <Ico d={D.pin} size={18} fill={cur.pinned ? GOLD : 'none'} />{cur.pinned ? t('not.pinned_l') : t('not.pin')}
                </Glass>
              )}
              {!cur.deleted && <Glass as="button" aria-label={t('share.nearby')} onClick={() => setNear(true)} style={{ height: 40, padding: '0 16px', borderRadius: 20, display: 'flex', alignItems: 'center', fontSize: 15 }}>{t('share.nearby')}</Glass>}
              <Glass as="button" aria-label={cur.deleted ? t('not.delete_forever') : t('not.del')} onClick={() => void remove()} style={{ width: 40, height: 40, borderRadius: 20, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#ff383c' }}><Ico d={D.trash} size={18} /></Glass>
            </div>
            <div className="scroll" style={{ flexGrow: 1, overflowY: 'auto', padding: '0 60px 120px' }}>
              <span style={{ display: 'block', textAlign: 'center', fontSize: 13, color: c.sub, paddingBottom: 14 }}>{longStamp(cur.updated, lang)}</span>
              <input aria-label={t('not.title')} value={cur.title} maxLength={80} readOnly={cur.deleted} placeholder={t('not.title')} onChange={(e) => edit({ ...cur, title: e.target.value })} style={{ display: 'block', width: '100%', fontSize: big ? 40 : 30, fontWeight: 800, paddingBottom: 12, color: c.fg, background: 'transparent' }} />
              {cur.blocks.map((b, i) => (
                <div key={i} style={{ padding: '6px 0' }}>
                  {b.type === 'text' && <textarea aria-label={t('not.text')} readOnly={cur.deleted} rows={Math.max(2, b.value.split('\n').length + 1)} value={b.value} onChange={(e) => setBlock(i, { type: 'text', value: e.target.value })} style={{ ...input, display: 'block', width: '100%', lineHeight: 1.5, whiteSpace: 'pre-wrap', resize: 'none' }} />}
                  {b.type === 'todo' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                      {b.items.map((it, j) => (
                        <div key={j} style={{ display: 'flex', alignItems: 'center', gap: 12, height: 38 }}>
                          <button role="checkbox" aria-checked={it.done} aria-label={t('not.check')} onClick={() => setBlock(i, { ...b, items: b.items.map((y, k) => (k === j ? { ...y, done: !y.done } : y)) })} style={{ width: 24, height: 24, borderRadius: '50%', boxSizing: 'border-box', border: `2px solid ${it.done ? GOLD : c.sub}`, background: it.done ? GOLD : 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                            <svg aria-hidden="true" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round" style={{ opacity: it.done ? 1 : 0 }}><path d="M5 12l5 5 9-10" /></svg>
                          </button>
                          <input aria-label={t('not.item')} value={it.t} maxLength={120} onChange={(e) => setBlock(i, { ...b, items: b.items.map((y, k) => (k === j ? { ...y, t: e.target.value } : y)) })} style={{ ...input, flexGrow: 1, color: it.done ? c.sub : c.fg, textDecoration: it.done ? 'line-through' : 'none' }} />
                        </div>
                      ))}
                      {!cur.deleted && <button onClick={() => setBlock(i, { ...b, items: [...b.items, { t: '', done: false }] })} style={{ fontSize: 16, color: GOLD, padding: '6px 0 0 36px', textAlign: 'start' }}>{t('not.add_item')}</button>}
                    </div>
                  )}
                  {b.type === 'table' && (
                    <div style={{ border: `1px solid ${c.sep}`, borderRadius: 10, overflow: 'hidden' }}>
                      {b.rows.map((r, ri) => (
                        <div key={ri} style={{ display: 'flex', background: ri === 0 ? cellAlt : 'transparent' }}>
                          {r.map((v, ci) => (
                            <input key={ci} aria-label={t('not.cell')} value={v} maxLength={60} onChange={(e) => setBlock(i, { ...b, rows: b.rows.map((rr, k) => (k === ri ? rr.map((vv, m) => (m === ci ? e.target.value : vv)) : rr)) })} style={{ ...input, flex: 1, minWidth: 0, boxSizing: 'border-box', padding: '10px 14px', fontSize: 16, fontWeight: ri === 0 ? 700 : 400, borderInlineEnd: `1px solid ${c.sep}`, borderTop: `1px solid ${c.sep}` }} />
                          ))}
                        </div>
                      ))}
                    </div>
                  )}
                  {b.type === 'photo' && <PhotoBlock id={b.id} nui={nui} c={c} />}
                </div>
              ))}
            </div>
            {!cur.deleted && (
              <Glass style={{ position: 'absolute', insetInlineStart: '50%', bottom: 28, marginInlineStart: -180, width: 360, height: 60, borderRadius: 30, display: 'flex', alignItems: 'center', justifyContent: 'space-around', boxSizing: 'border-box', padding: '0 14px' }}>
                {tools.map((x) => (
                  <button key={x.key} aria-label={x.label} onClick={x.go} style={{ width: 48, height: 48, borderRadius: 24, display: 'flex', alignItems: 'center', justifyContent: 'center', background: x.on ? 'rgba(255,168,0,.2)' : 'transparent', color: GOLD }}><Ico d={x.d} size={24} /></button>
                ))}
              </Glass>
            )}
          </>
        ) : (
          <div style={{ flexGrow: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', color: c.sub, fontSize: 20 }}>{t('not.none_sel')}</div>
        )}
      </main>

      <NearbySheet open={near} onClose={() => setNear(false)} kind="note" rid={cur?.id ?? null} />
      <Sheet open={folderSheet} onClose={() => setFolderSheet(false)} title={t('not.folder_new')}>
        <Field value={folderName} onChange={setFolderName} label={t('not.folder_name')} placeholder={t('not.folder_name')} maxLength={40} onEnter={() => void addFolder()} />
        <div style={{ marginTop: 14, display: 'flex', justifyContent: 'flex-end' }}><Button disabled={!folderName.trim()} onClick={() => void addFolder()}>{t('not.create')}</Button></div>
      </Sheet>
      <Sheet open={photoSheet} onClose={() => setPhotoSheet(false)} title={t('not.pick_photo')}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 8, maxHeight: 360, overflowY: 'auto' }}>
          {photos.map((ph) => (
            <button key={ph.id} aria-label={t('pho.photo', ph.id)} onClick={() => { addBlock({ type: 'photo', id: ph.id }); setPhotoSheet(false); }} style={{ aspectRatio: '1 / 1', borderRadius: 10, background: c.fill, overflow: 'hidden' }}>
              {ph.thumb && <img alt="" src={ph.thumb} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
            </button>
          ))}
        </div>
      </Sheet>
    </div>
  );
}
