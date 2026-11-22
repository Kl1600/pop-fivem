import { useCallback, useEffect, useRef, useState } from 'react';
import { Button, Field, Glass, NearbySheet, Sheet, palette, useSettingsApi, type AppProps, type NuiResult } from '../../kit';
import { FX, aspectOf, dateLabel, fxCss, groupPhotos, makeThumb, monthLabel, neighbour, type PhotoItem } from './model';

const BLUE = '#0088ff';
const D = {
  lib: 'M3 5h18v14H3zM3 16l6-6 5 5 3-3 4 4', albums: 'M5 4h14v16H5zM9 4v16', fav: 'M12 20s-7-4.500-7-10a4 4 0 0 1 7-2.500A4 4 0 0 1 19 10c0 5.500-7 10-7 10z',
  trash: 'M5 7h14M9 7V4h6v3M7 7l1 13h8l1-13', info: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 11v6M12 7.500v.1', edit: 'M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M20 18h0M14 4v4M8 10v4M16 16v4',
  wall: 'M3 5h18v14H3zM3 16l6-6 5 5 3-3 4 4', album: 'M12 5v14M5 12h14', star: 'M12 3l2.700 5.800 6.300.7-4.700 4.300 1.300 6.200L12 17l-5.600 3 1.300-6.200L3 9.500l6.300-.7z',
};
const FX_KEYS: Record<string, string> = { none: 'pho.fx_none', vivid: 'pho.fx_vivid', mono: 'pho.fx_mono', drama: 'pho.fx_drama', sepia: 'pho.fx_sepia' };

type Sel = 'lib' | 'fav' | 'trash' | 'albums' | number;
type Seg = 'years' | 'months' | 'all';
interface Album { id: number; name: string; n: number }
interface Counts { total: number; fav: number; trash: number }
interface ListRes extends NuiResult { items?: PhotoItem[]; more?: boolean; counts?: Counts; albums?: Album[] }
interface Full extends PhotoItem { data: string; albums: number[]; deleted: boolean }
interface GetRes extends NuiResult { photo?: Full }

function Ico({ d, color = 'currentColor', size = 22, fill = 'none' }: { d: string; color?: string; size?: number; fill?: string }) {
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
}

const thumbCache = new Map<number, string>();

/** Vignette : celle du serveur, sinon la photo entière réduite par l'interface puis enregistrée. */
function Thumb({ p, nui, fill }: { p: PhotoItem; nui: AppProps['nui']; fill: string }) {
  const [src, setSrc] = useState<string | null>(p.thumb ?? thumbCache.get(p.id) ?? null);
  useEffect(() => {
    if (src) return;
    let live = true;
    void (async () => {
      const r = await nui.call<GetRes>('photos:get', p.id);
      if (!live || !r.ok || !r.photo) return;
      const th = await makeThumb(r.photo.data);
      if (th) {
        thumbCache.set(p.id, th);
        void nui.call('photos:thumb', { id: p.id, data: th });
      }
      if (live) setSrc(th ?? r.photo.data);
    })();
    return () => { live = false; };
  }, [src, p.id, nui]);
  return (
    <span style={{ display: 'block', width: '100%', height: '100%', background: fill }}>
      {src && <img alt="" src={src} style={{ width: '100%', height: '100%', objectFit: 'cover', filter: fxCss(p.fx), display: 'block' }} />}
    </span>
  );
}

export default function App(p: AppProps) {
  const { t, nui, dark } = p;
  const settings = useSettingsApi();
  const lang = settings.lang;
  const c = palette(dark);
  const [sel, setSel] = useState<Sel>('lib');
  const [seg, setSeg] = useState<Seg>('all');
  const [items, setItems] = useState<PhotoItem[]>([]);
  const [counts, setCounts] = useState<Counts>({ total: 0, fav: 0, trash: 0 });
  const [albums, setAlbums] = useState<Album[]>([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState<number | null>(null);
  const [full, setFull] = useState<Full | null>(null);
  const [near, setNear] = useState(false);
  const [panel, setPanel] = useState<'none' | 'info' | 'edit'>('none');
  const [toast, setToast] = useState('');
  const [albumSheet, setAlbumSheet] = useState<'none' | 'new' | 'pick'>('none');
  const [albumName, setAlbumName] = useState('');
  const toastTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const note = useCallback((m: string) => {
    setToast(m);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(''), 1600);
  }, []);
  useEffect(() => () => { if (toastTimer.current) clearTimeout(toastTimer.current); }, []);

  const fail = useCallback((r: NuiResult) => note(r.err ? t(r.err) : t('cam.err')), [note, t]);

  /** Charge toutes les pages de la portée (30 vignettes par page, 200 photos au plus). */
  const load = useCallback(async (scope: Sel) => {
    if (scope === 'albums') {
      const r = await nui.call<ListRes>('photos:albums');
      if (r.ok) setAlbums((r as unknown as { albums: Album[] }).albums ?? []);
      setItems([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    const base = typeof scope === 'number' ? { scope: 'album', albumId: scope } : { scope: scope === 'lib' ? 'all' : scope };
    const all: PhotoItem[] = [];
    for (let offset = 0; offset <= 180; offset += 30) {
      const r = await nui.call<ListRes>('photos:list', { ...base, offset });
      if (!r.ok) { fail(r); break; }
      all.push(...(r.items ?? []));
      if (r.counts) setCounts(r.counts);
      if (r.albums) setAlbums(r.albums);
      if (!r.more) break;
    }
    setItems(all);
    setLoading(false);
  }, [nui, fail]);

  useEffect(() => {
    let live = true;
    void Promise.resolve().then(() => { if (live) void load(sel); });
    return () => { live = false; };
  }, [sel, load]);

  // Photo ouverte : lecture complète au serveur.
  useEffect(() => {
    if (open === null) { setFull(null); return; }
    let live = true;
    void nui.call<GetRes>('photos:get', open).then((r) => { if (live) { if (r.ok && r.photo) setFull(r.photo); else fail(r); } });
    return () => { live = false; };
  }, [open, nui, fail]);

  const patch = (id: number, ch: Partial<PhotoItem>) => {
    setItems((l) => l.map((x) => (x.id === id ? { ...x, ...ch } : x)));
    setFull((f) => (f && f.id === id ? { ...f, ...ch } : f));
  };

  const favorite = async () => {
    if (!full) return;
    const r = await nui.call<NuiResult & { fav?: boolean }>('photos:favorite', full.id);
    if (!r.ok) return fail(r);
    patch(full.id, { fav: r.fav === true });
    setCounts((k) => ({ ...k, fav: k.fav + (r.fav ? 1 : -1) }));
  };
  const rate = async (n: number) => {
    if (!full) return;
    const next = full.rating === n ? 0 : n;
    const r = await nui.call('photos:rate', { id: full.id, rating: next });
    if (r.ok) patch(full.id, { rating: next }); else fail(r);
  };
  const filter = async (fx: string) => {
    if (!full) return;
    const r = await nui.call('photos:filter', { id: full.id, fx });
    if (r.ok) patch(full.id, { fx }); else fail(r);
  };
  const remove = async () => {
    if (!full) return;
    const r = await nui.call<NuiResult & { permanent?: boolean }>('photos:delete', full.id);
    if (!r.ok) return fail(r);
    setItems((l) => l.filter((x) => x.id !== full.id));
    setCounts((k) => (r.permanent ? { ...k, trash: k.trash - 1 } : { ...k, total: k.total - 1, trash: k.trash + 1 }));
    setOpen(null);
    note(t('pho.deleted'));
  };
  const restore = async () => {
    if (!full) return;
    const r = await nui.call('photos:restore', full.id);
    if (!r.ok) return fail(r);
    setItems((l) => l.filter((x) => x.id !== full.id));
    setCounts((k) => ({ ...k, total: k.total + 1, trash: k.trash - 1 }));
    setOpen(null);
  };
  const wallpaper = () => {
    if (!full) return;
    settings.set({ wall: `photo:${full.id}` });
    note(t('pho.wall_done'));
  };
  const createAlbum = async () => {
    const r = await nui.call<NuiResult & { id?: number; name?: string }>('photos:albumSave', { name: albumName });
    if (!r.ok || r.id === undefined) return fail(r);
    setAlbums((l) => [...l, { id: r.id as number, name: r.name ?? albumName, n: 0 }]);
    setAlbumName('');
    setAlbumSheet('none');
  };
  const link = async (albumId: number, on: boolean) => {
    if (!full) return;
    const r = await nui.call('photos:albumLink', { albumId, photoId: full.id, on });
    if (!r.ok) return fail(r);
    setFull({ ...full, albums: on ? [...full.albums, albumId] : full.albums.filter((x) => x !== albumId) });
    setAlbums((l) => l.map((a) => (a.id === albumId ? { ...a, n: a.n + (on ? 1 : -1) } : a)));
  };
  const deleteAlbum = async () => {
    if (typeof sel !== 'number') return;
    const r = await nui.call('photos:albumDelete', sel);
    if (!r.ok) return fail(r);
    setAlbums((l) => l.filter((a) => a.id !== sel));
    setSel('albums');
  };

  const isPhotoScope = sel !== 'albums';
  const titleOf = sel === 'lib' ? t('pho.lib') : sel === 'fav' ? t('pho.fav') : sel === 'trash' ? t('pho.trash') : sel === 'albums' ? t('pho.albums') : albums.find((a) => a.id === sel)?.name ?? '';
  const sideGroups: Array<{ head: string; items: Array<{ key: string; sel: Sel; name: string; d: string; color: string; n: number | string }> }> = [
    { head: '', items: [{ key: 'lib', sel: 'lib', name: t('pho.lib'), d: D.lib, color: BLUE, n: counts.total }] },
    { head: t('pho.albums'), items: [
      { key: 'albums', sel: 'albums', name: t('pho.albums'), d: D.albums, color: BLUE, n: albums.length },
      ...albums.map((a) => ({ key: `a${a.id}`, sel: a.id as Sel, name: a.name, d: D.albums, color: '#ff8d28', n: a.n })),
      { key: 'fav', sel: 'fav', name: t('pho.fav'), d: D.fav, color: '#ff2d55', n: counts.fav },
    ] },
    { head: t('pho.utils'), items: [{ key: 'trash', sel: 'trash', name: t('pho.trash'), d: D.trash, color: '#ff383c', n: counts.trash }] },
  ];

  const cell = (ph: PhotoItem, ratio: string) => (
    <button key={ph.id} aria-label={t('pho.photo', ph.id)} onClick={() => { setOpen(ph.id); setPanel('none'); }} style={{ aspectRatio: ratio, position: 'relative', overflow: 'hidden', borderRadius: ratio === '1 / 1' ? 0 : 12 }}>
      <Thumb p={ph} nui={nui} fill={c.fill} />
      {ph.fav && <span aria-hidden="true" style={{ position: 'absolute', insetInlineStart: 8, bottom: 6, color: '#fff', fontSize: 14 }}>♥</span>}
    </button>
  );

  const ids = items.map((x) => x.id);
  const move = (step: 1 | -1) => { const n = full ? neighbour(ids, full.id, step) : null; if (n !== null) setOpen(n); };
  const years = groupPhotos(items, 'year');
  const months = groupPhotos(items, 'month');
  const tool = (key: string, label: string, d: string, color: string, go: () => void, active = false, fill = 'none') => (
    <button key={key} aria-label={label} onClick={go} style={{ width: 48, height: 48, borderRadius: 24, display: 'flex', alignItems: 'center', justifyContent: 'center', background: active ? 'rgba(255,255,255,.18)' : 'transparent' }}><Ico d={d} size={24} color={color} fill={fill} /></button>
  );

  return (
    <div data-app="photos" style={{ width: '100%', height: '100%', display: 'flex', background: c.cell, color: c.fg, overflow: 'hidden', position: 'relative' }}>
      <nav aria-label={t('pho.title')} className="scroll" style={{ width: 300, flexShrink: 0, height: '100%', boxSizing: 'border-box', background: c.side, borderInlineEnd: `1px solid ${c.sep}`, padding: '46px 14px 20px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontSize: 34, fontWeight: 700, padding: '0 10px 14px' }}>{t('pho.title')}</span>
        {sideGroups.map((g) => (
          <div key={g.head || 'top'} style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            {g.head && <span style={{ fontSize: 13, fontWeight: 600, color: c.sub, padding: '14px 10px 4px', textTransform: 'uppercase' }}>{g.head}</span>}
            {g.items.map((it) => {
              const on = sel === it.sel;
              return (
                <button key={it.key} onClick={() => { setSel(it.sel); setOpen(null); }} style={{ display: 'flex', alignItems: 'center', gap: 12, height: 42, padding: '0 10px', borderRadius: 10, background: on ? BLUE : 'transparent', color: on ? '#fff' : c.fg }}>
                  <Ico d={it.d} color={on ? '#fff' : it.color} />
                  <span style={{ flexGrow: 1, fontSize: 17, textAlign: 'start', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{it.name}</span>
                  <span style={{ fontSize: 15, color: on ? 'rgba(255,255,255,.8)' : c.sub }}>{it.n}</span>
                </button>
              );
            })}
          </div>
        ))}
      </nav>

      <main className="scroll" style={{ flexGrow: 1, minWidth: 0, height: '100%', overflowY: 'auto', position: 'relative' }}>
        <div style={{ position: 'sticky', top: 0, zIndex: 2, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '40px 28px 14px', background: `linear-gradient(180deg,${c.cell} 70%, transparent)` }}>
          <span style={{ fontSize: 34, fontWeight: 700 }}>{titleOf}</span>
          {isPhotoScope && (
            <Glass style={{ display: 'flex', padding: 3, borderRadius: 20, gap: 2 }}>
              {([['years', t('pho.years')], ['months', t('pho.months')], ['all', t('pho.all')]] as Array<[Seg, string]>).map(([id, name]) => (
                <button key={id} onClick={() => setSeg(id)} style={{ height: 34, padding: '0 20px', borderRadius: 17, fontSize: 15, fontWeight: 600, background: seg === id ? BLUE : 'transparent', color: seg === id ? '#fff' : c.fg }}>{name}</button>
              ))}
            </Glass>
          )}
          {typeof sel === 'number' && <Button kind="plain" onClick={() => void deleteAlbum()}>{t('pho.album_del')}</Button>}
        </div>
        {sel === 'trash' && <span style={{ display: 'block', padding: '0 28px 8px', fontSize: 14, color: c.sub }}>{t('pho.trash_hint')}</span>}

        {isPhotoScope && seg === 'years' && (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: 16, padding: '4px 28px 40px' }}>
            {years.map((g) => (
              <button key={g.key} onClick={() => setSeg('months')} style={{ height: 250, borderRadius: 22, overflow: 'hidden', position: 'relative', background: c.fill }}>
                {g.items[0] && <span style={{ position: 'absolute', inset: 0 }}><Thumb p={g.items[0]} nui={nui} fill={c.fill} /></span>}
                <span style={{ position: 'absolute', insetInlineStart: 22, bottom: 20, color: '#fff', display: 'flex', flexDirection: 'column', alignItems: 'flex-start', textShadow: '0 1px 8px rgba(0,0,0,.5)' }}><span style={{ fontSize: 40, fontWeight: 800 }}>{g.key}</span><span style={{ fontSize: 16 }}>{t('pho.items', g.items.length)}</span></span>
              </button>
            ))}
          </div>
        )}
        {isPhotoScope && seg === 'months' && (
          <div style={{ padding: '4px 28px 40px' }}>
            {months.map((g) => (
              <div key={g.key}>
                <span style={{ display: 'block', fontSize: 22, fontWeight: 700, padding: '14px 0 10px', textTransform: 'capitalize' }}>{monthLabel(g.label, lang)}</span>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 8 }}>{g.items.map((ph) => cell(ph, '4 / 3'))}</div>
              </div>
            ))}
          </div>
        )}
        {isPhotoScope && seg === 'all' && <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, minmax(0, 1fr))', gap: 2, padding: '4px 0 40px' }}>{items.map((ph) => cell(ph, '1 / 1'))}</div>}
        {isPhotoScope && !loading && items.length === 0 && <span style={{ display: 'block', textAlign: 'center', padding: '120px 0', fontSize: 20, color: c.sub }}>{t('pho.empty')}</span>}
        {loading && <span style={{ display: 'block', textAlign: 'center', padding: '40px 0', color: c.sub }}>{t('pho.loading')}</span>}

        {sel === 'albums' && (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: 18, padding: '4px 28px 40px' }}>
            {albums.map((a) => (
              <button key={a.id} onClick={() => setSel(a.id)} style={{ display: 'flex', flexDirection: 'column', gap: 8, alignItems: 'stretch', textAlign: 'start' }}>
                <span style={{ height: 190, borderRadius: 18, background: c.fill, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={D.albums} size={48} color={c.sub} /></span>
                <span style={{ fontSize: 17, fontWeight: 600 }}>{a.name}</span><span style={{ fontSize: 14, color: c.sub, marginTop: -6 }}>{t('pho.items', a.n)}</span>
              </button>
            ))}
            <button onClick={() => setAlbumSheet('new')} aria-label={t('pho.album_new')} style={{ height: 190, borderRadius: 18, border: `2px dashed ${c.sep}`, color: BLUE, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, fontSize: 17 }}><Ico d={D.album} color={BLUE} />{t('pho.album_new')}</button>
          </div>
        )}
      </main>

      {open !== null && (
        <div role="dialog" aria-label={t('pho.photo', open)} style={{ position: 'absolute', inset: 0, background: '#000', display: 'flex', color: '#fff', zIndex: 5 }}>
          <div style={{ flexGrow: 1, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', minWidth: 0 }}>
            {full ? <img alt={t('pho.photo', full.id)} src={full.data} style={{ maxWidth: 900, maxHeight: 700, aspectRatio: aspectOf(full.kind), objectFit: 'cover', borderRadius: 14, filter: fxCss(full.fx), transition: 'filter .3s' }} /> : <span>{t('pho.loading')}</span>}
            <Glass className="dk" style={{ position: 'absolute', top: 28, insetInline: 28, height: 56, borderRadius: 28, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 20px', boxSizing: 'border-box' }}>
              <button onClick={() => setOpen(null)} style={{ fontSize: 17, fontWeight: 600, color: '#4aa8ff' }}>{t('pho.back')}</button>
              <span style={{ fontSize: 16, fontWeight: 600 }}>{full ? dateLabel(full.taken, lang) : ''}</span>
              <span style={{ display: 'flex', gap: 6 }}>
                <button aria-label={t('pho.prev')} onClick={() => move(-1)} style={{ width: 36, fontSize: 24 }}>‹</button>
                <button aria-label={t('pho.next')} onClick={() => move(1)} style={{ width: 36, fontSize: 24 }}>›</button>
              </span>
            </Glass>
            {full && !full.deleted && (
              <div style={{ position: 'absolute', bottom: 120, display: 'flex', gap: 6 }}>
                {[1, 2, 3, 4, 5].map((n) => (
                  <button key={n} aria-label={t('pho.stars', n)} aria-pressed={n <= full.rating} onClick={() => void rate(n)}><Ico d={D.star} size={30} color={n <= full.rating ? '#ffcc00' : 'rgba(255,255,255,.7)'} fill={n <= full.rating ? '#ffcc00' : 'none'} /></button>
                ))}
              </div>
            )}
            <NearbySheet open={near} onClose={() => setNear(false)} kind="photo" rid={full?.id ?? null} />
            {full && (
              <Glass className="dk" style={{ position: 'absolute', bottom: 28, height: 60, borderRadius: 30, display: 'flex', alignItems: 'center', gap: 10, padding: '0 22px' }}>
                {full.deleted ? (
                  <>{tool('restore', t('pho.restore'), D.album, '#fff', () => void restore())}{tool('del', t('pho.del_forever'), D.trash, '#ff6b6b', () => void remove())}</>
                ) : (
                  <>
                    {tool('fav', t('pho.t_fav'), D.fav, full.fav ? '#ff2d55' : '#fff', () => void favorite(), false, full.fav ? '#ff2d55' : 'none')}
                    {tool('info', t('pho.t_info'), D.info, '#fff', () => setPanel(panel === 'info' ? 'none' : 'info'), panel === 'info')}
                    {tool('album', t('pho.t_album'), D.albums, '#fff', () => setAlbumSheet('pick'))}
                    {tool('wall', t('pho.t_wall'), D.wall, '#fff', wallpaper)}
                    {tool('share', t('share.nearby'), 'M12 15V4M8 8l4-4 4 4M6 12H5v8h14v-8h-1', '#fff', () => setNear(true))}
                    {tool('del', t('pho.t_del'), D.trash, '#ff6b6b', () => void remove())}
                    {tool('edit', t('pho.t_edit'), D.edit, '#fff', () => setPanel(panel === 'edit' ? 'none' : 'edit'), panel === 'edit')}
                  </>
                )}
              </Glass>
            )}
            {toast && <Glass className="dk" style={{ position: 'absolute', top: 100, padding: '8px 18px', borderRadius: 18, fontSize: 15 }}>{toast}</Glass>}
          </div>
          {full && panel === 'info' && (
            <div style={{ width: 320, flexShrink: 0, background: '#1c1c1e', padding: '40px 24px', boxSizing: 'border-box', display: 'flex', flexDirection: 'column', gap: 14 }}>
              <span style={{ fontSize: 22, fontWeight: 700 }}>{t('pho.t_info')}</span>
              {([[t('pho.k_date'), dateLabel(full.taken, lang)], [t('pho.k_place'), t('pho.place_value')], [t('pho.k_device'), t('pho.device_value')], [t('pho.k_format'), t(`cam.${full.kind}`)], [t('pho.k_rating'), full.rating ? `${full.rating} / 5` : t('pho.none')]] as Array<[string, string]>).map(([k, v]) => (
                <div key={k} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 16, borderBottom: '1px solid rgba(84,84,88,.6)', paddingBottom: 10 }}><span style={{ color: 'rgba(235,235,245,.6)' }}>{k}</span><span>{v}</span></div>
              ))}
            </div>
          )}
          {full && panel === 'edit' && (
            <div style={{ width: 320, flexShrink: 0, background: '#1c1c1e', padding: '40px 24px', boxSizing: 'border-box', display: 'flex', flexDirection: 'column', gap: 12 }}>
              <span style={{ fontSize: 22, fontWeight: 700 }}>{t('pho.t_edit')}</span>
              {FX.map((f) => (
                <button key={f.id} onClick={() => void filter(f.id)} style={{ height: 44, borderRadius: 12, padding: '0 16px', display: 'flex', alignItems: 'center', fontSize: 17, background: full.fx === f.id ? BLUE : '#2c2c2e' }}>{t(FX_KEYS[f.id] as string)}</button>
              ))}
            </div>
          )}
        </div>
      )}

      <Sheet open={albumSheet === 'new'} onClose={() => setAlbumSheet('none')} title={t('pho.album_new')}>
        <Field value={albumName} onChange={setAlbumName} label={t('pho.album_name')} placeholder={t('pho.album_name')} maxLength={40} onEnter={() => void createAlbum()} />
        <div style={{ marginTop: 14, display: 'flex', justifyContent: 'flex-end' }}><Button disabled={!albumName.trim()} onClick={() => void createAlbum()}>{t('pho.create')}</Button></div>
      </Sheet>
      <Sheet open={albumSheet === 'pick'} onClose={() => setAlbumSheet('none')} title={t('pho.t_album')}>
        {albums.length === 0 && <span style={{ color: c.sub }}>{t('pho.albums_none')}</span>}
        {albums.map((a) => {
          const inAlbum = full?.albums.includes(a.id) ?? false;
          return (
            <button key={a.id} role="checkbox" aria-checked={inAlbum} onClick={() => void link(a.id, !inAlbum)} style={{ display: 'flex', width: '100%', justifyContent: 'space-between', alignItems: 'center', height: 46, borderBottom: `1px solid ${c.sep}`, fontSize: 17 }}>
              <span>{a.name}</span><span aria-hidden="true" style={{ color: BLUE }}>{inAlbum ? '✓' : ''}</span>
            </button>
          );
        })}
        <div style={{ marginTop: 14 }}><Button kind="plain" onClick={() => setAlbumSheet('new')}>{t('pho.album_new')}</Button></div>
      </Sheet>
    </div>
  );
}
