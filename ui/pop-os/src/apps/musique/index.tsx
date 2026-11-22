import { useCallback, useEffect, useState } from 'react';
import { Button, Field, Sheet, player, usePlayer, type AppProps, type NuiResult, type Track } from '../../kit';

interface Station { id: string; name: string; url: string; tag?: string }
interface Playlist { name: string; ids: string[] }
interface ListRes extends NuiResult { stations?: Station[]; favs?: string[]; playlists?: Playlist[] }
type Tab = 'radios' | 'favs' | 'lists';

const BTN = { all: 'unset', cursor: 'pointer' } as const;
const PINK = '#ff2d55';

/** Piste jouable d'une station (le « artiste » est le genre affiché). */
export const trackOf = (s: Station): Track => ({ id: s.id, title: s.name, artist: s.tag ?? '', url: s.url });

export default function App({ t, dark, nui }: AppProps) {
  const c = dark
    ? { bg: '#000000', cell: '#1c1c1e', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', sel: '#3a1020' }
    : { bg: '#f2f2f7', cell: '#ffffff', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', sel: '#ffe3ea' };
  const pl = usePlayer();
  const [tab, setTab] = useState<Tab>('radios');
  const [stations, setStations] = useState<Station[]>([]);
  const [favs, setFavs] = useState<string[]>([]);
  const [lists, setLists] = useState<Playlist[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [full, setFull] = useState(false);
  const [newList, setNewList] = useState<string | null>(null);
  const [toast, setToast] = useState('');
  const flash = useCallback((text: string) => { setToast(text); setTimeout(() => setToast(''), 2200); }, []);

  useEffect(() => {
    let live = true;
    void nui.call<ListRes>('music:stations').then((r) => {
      if (!live) return;
      if (r.ok) { setStations(r.stations ?? []); setFavs(r.favs ?? []); setLists(r.playlists ?? []); } else flash(t(r.err ?? 'mus.err'));
      setLoaded(true);
    });
    return () => { live = false; };
  }, [nui, t, flash]);

  // Le serveur retient ce qui joue (centre de contrôle à la réouverture) : un message par changement, jamais en boucle.
  const title = pl.track?.title;
  const artist = pl.track?.artist ?? '';
  useEffect(() => {
    if (title === undefined) return;
    void nui.call('music:state', { title, artist, playing: pl.playing });
  }, [title, artist, pl.playing, nui]);

  const byId = (id: string) => stations.find((s) => s.id === id);
  const save = async (patch: { favs?: string[]; playlists?: Playlist[] }) => {
    const r = await nui.call('music:save', patch);
    if (!r.ok) { flash(t(r.err ?? 'mus.err')); return false; }
    return true;
  };
  const toggleFav = async (id: string) => {
    const next = favs.includes(id) ? favs.filter((x) => x !== id) : [...favs, id];
    if (await save({ favs: next })) setFavs(next);
  };
  const addList = async () => {
    const name = (newList ?? '').trim();
    if (!name) return;
    const next = [...lists, { name, ids: [] }];
    if (await save({ playlists: next })) { setLists(next); setNewList(null); }
  };
  const editList = async (i: number, fn: (p: Playlist) => Playlist | null) => {
    const next: Playlist[] = [];
    lists.forEach((p, j) => {
      if (j !== i) { next.push(p); return; }
      const q = fn(p);
      if (q) next.push(q);
    });
    if (await save({ playlists: next })) setLists(next);
  };
  const playFrom = (s: Station, pool: Station[]) => player.play(trackOf(s), pool.map(trackOf));

  const row = (s: Station, pool: Station[]) => (
    <div key={s.id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 18px', borderTop: `1px solid ${c.sep}`, background: pl.track?.id === s.id ? c.sel : 'transparent' }}>
      <button style={{ ...BTN, flexGrow: 1, minWidth: 0, textAlign: 'start' }} aria-label={s.name} onClick={() => playFrom(s, pool)}>
        <span style={{ display: 'block', fontSize: 17, fontWeight: 600 }}>{s.name}</span>
        <span style={{ display: 'block', fontSize: 13, color: c.sub }}>{s.tag ?? t('mus.radio')}</span>
      </button>
      {lists.length > 0 && (
        <select
          aria-label={t('mus.add_to')}
          value=""
          onChange={(e) => {
            if (e.target.value === '') return;
            const i = Number(e.target.value);
            void editList(i, (p) => (p.ids.includes(s.id) ? p : { ...p, ids: [...p.ids, s.id] }));
          }}
          style={{ fontSize: 14, background: c.cell, color: c.fg, border: `1px solid ${c.sep}`, borderRadius: 8, padding: 4 }}
        >
          <option value="">{t('mus.add_to')}</option>
          {lists.map((p, i) => <option key={p.name} value={i}>{p.name}</option>)}
        </select>
      )}
      <button style={{ ...BTN, fontSize: 24, color: favs.includes(s.id) ? PINK : c.sub }} aria-pressed={favs.includes(s.id)} aria-label={t(favs.includes(s.id) ? 'mus.unfav' : 'mus.fav')} onClick={() => void toggleFav(s.id)}>{favs.includes(s.id) ? '♥' : '♡'}</button>
    </div>
  );

  const favStations = favs.map(byId).filter((x): x is Station => !!x);
  const ctl = (size: number) => (
    <span style={{ display: 'flex', gap: size, alignItems: 'center', fontSize: size }}>
      <button style={BTN} aria-label={t('mus.prev')} onClick={() => player.skip(-1)}>⏮</button>
      <button style={BTN} aria-label={t(pl.playing ? 'mus.pause' : 'mus.play')} onClick={() => player.toggle()}>{pl.playing ? '⏸' : '▶'}</button>
      <button style={BTN} aria-label={t('mus.next')} onClick={() => player.skip(1)}>⏭</button>
    </span>
  );

  return (
    <div style={{ position: 'absolute', inset: 0, background: c.bg, color: c.fg, paddingTop: 54, boxSizing: 'border-box', display: 'flex', flexDirection: 'column' }}>
      <div role="tablist" style={{ display: 'flex', gap: 8, padding: '8px 18px' }}>
        {(['radios', 'favs', 'lists'] as Tab[]).map((k) => (
          <button key={k} role="tab" aria-selected={tab === k} onClick={() => setTab(k)} style={{ ...BTN, padding: '8px 18px', borderRadius: 18, fontSize: 17, fontWeight: 600, background: tab === k ? PINK : c.cell, color: tab === k ? '#fff' : c.fg }}>{t(`mus.tab_${k}`)}</button>
        ))}
      </div>
      <div style={{ flexGrow: 1, overflowY: 'auto', paddingBottom: pl.track ? 96 : 0 }}>
        {tab === 'radios' && (
          <>
            {loaded && stations.length === 0 && <p style={{ padding: 24, color: c.sub }}>{t('mus.none')}</p>}
            {stations.map((s) => row(s, stations))}
          </>
        )}
        {tab === 'favs' && (
          <>
            {favStations.length === 0 && <p style={{ padding: 24, color: c.sub }}>{t('mus.no_favs')}</p>}
            {favStations.map((s) => row(s, favStations))}
          </>
        )}
        {tab === 'lists' && (
          <>
            <div style={{ padding: '4px 18px' }}><Button kind="plain" onClick={() => setNewList('')}>{t('mus.new_list')}</Button></div>
            {lists.length === 0 && <p style={{ padding: 24, color: c.sub }}>{t('mus.no_lists')}</p>}
            {lists.map((p, i) => {
              const pool = p.ids.map(byId).filter((x): x is Station => !!x);
              const first = pool[0];
              return (
                <section key={p.name} aria-label={p.name} style={{ marginBottom: 12 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 18px' }}>
                    <h2 style={{ margin: 0, fontSize: 21, flexGrow: 1 }}>{p.name}</h2>
                    {first && <Button kind="plain" onClick={() => playFrom(first, pool)}>{t('mus.play_list')}</Button>}
                    <Button kind="plain" onClick={() => void editList(i, () => null)}>{t('mus.del_list')}</Button>
                  </div>
                  {pool.length === 0 && <p style={{ padding: '0 18px', color: c.sub }}>{t('mus.list_empty')}</p>}
                  {pool.map((s) => row(s, pool))}
                </section>
              );
            })}
          </>
        )}
      </div>

      {pl.track && !full && (
        <div style={{ position: 'absolute', left: 18, right: 18, bottom: 18, borderRadius: 22, background: c.cell, border: `1px solid ${c.sep}`, display: 'flex', alignItems: 'center', gap: 14, padding: '10px 18px' }}>
          <button style={{ ...BTN, flexGrow: 1, minWidth: 0, textAlign: 'start' }} aria-label={t('mus.open_player')} onClick={() => setFull(true)}>
            <span style={{ display: 'block', fontSize: 17, fontWeight: 600 }}>{pl.track.title}</span>
            <span style={{ display: 'block', fontSize: 13, color: pl.error ? PINK : c.sub }}>{pl.error ? t('mus.err_stream') : pl.track.artist}</span>
          </button>
          {ctl(26)}
        </div>
      )}
      {pl.track && full && (
        <div role="dialog" aria-label={t('mus.player')} style={{ position: 'absolute', inset: 0, background: c.bg, paddingTop: 54, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 22, zIndex: 5 }}>
          <button style={{ ...BTN, position: 'absolute', top: 64, insetInlineStart: 24, fontSize: 17, color: PINK }} onClick={() => setFull(false)}>{t('mus.close_player')}</button>
          <span aria-hidden="true" style={{ width: 280, height: 280, borderRadius: 28, background: 'linear-gradient(150deg,#ff2d55,#5e5ce6)' }} />
          <h1 style={{ margin: 0, fontSize: 30 }}>{pl.track.title}</h1>
          <span style={{ fontSize: 17, color: pl.error ? PINK : c.sub }}>{pl.error ? t('mus.err_stream') : pl.track.artist}</span>
          {ctl(40)}
          <span style={{ fontSize: 14, color: c.sub }}>{t('mus.volume_hint')} · {player.volume()} %</span>
          <Button kind="plain" onClick={() => { player.stop(); setFull(false); }}>{t('mus.stop')}</Button>
        </div>
      )}

      <Sheet open={newList !== null} onClose={() => setNewList(null)} title={t('mus.new_list')}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <Field value={newList ?? ''} onChange={setNewList} label={t('mus.list_name')} maxLength={40} onEnter={() => void addList()} />
          <Button onClick={() => void addList()}>{t('mus.create')}</Button>
        </div>
      </Sheet>
      {toast && <div role="status" style={{ position: 'absolute', bottom: 120, left: '50%', transform: 'translateX(-50%)', padding: '10px 18px', borderRadius: 16, background: '#000c', color: '#fff', fontSize: 16 }}>{toast}</div>}
    </div>
  );
}
