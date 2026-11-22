import { useCallback, useEffect, useRef, useState } from 'react';
import { Glass, Sheet, clock, gradOf, initials, nameFor, openOtherApp, useSettingsApi, whenOf, type AppProps, type ContactRow, type NuiResult } from '../../kit';

const BLUE = '#0088ff';
const BTN = { all: 'unset', cursor: 'pointer' } as const;

interface Thread { id: string; group: boolean; name?: string; unread: number; last?: { kind: string; body: string; me: boolean; at: number; read: boolean; from?: string } }
interface Msg { id: number; me: boolean; from: string; kind: string; body: string; ref: string | null; at: number; read: boolean }
interface ThreadsRes extends NuiResult { items?: Thread[]; pins?: string[]; blocked?: string[]; me?: string }
interface ThreadRes extends NuiResult { items?: Msg[] }
interface SendRes extends NuiResult { msg?: Msg }
interface ListRes extends NuiResult { items?: ContactRow[] }
interface PhotosRes extends NuiResult { items?: Array<{ id: number; thumb?: string | null }> }
interface PushMsg { id?: number; from?: string; to?: string; read?: string }

const D = {
  plus: 'M12 5v14M5 12h14', search: 'M20 20l-4-4', call: 'M5 4h4l2 5-2.500 1.500a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2',
  send: 'M12 19V5M5 12l7-7 7 7', photo: 'M4 7h4l2-3h4l2 3h4v13H4zM12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8z', loc: 'M12 21s-7-6-7-11a7 7 0 0 1 14 0c0 5-7 11-7 11zM12 12a2.500 2.500 0 1 0 0-5 2.500 2.500 0 0 0 0 5z',
  pin: 'M9 3h6l-1 6 3 3v2H7v-2l3-3zM12 14v7',
};
function Ico({ d, size = 22, color = 'currentColor' }: { d: string; size?: number; color?: string }) {
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
}

/** Photo reçue ou envoyée : lue au serveur à l'affichage (jamais copiée dans le message). */
function MediaPhoto({ id, nui, label }: { id: number; nui: AppProps['nui']; label: string }) {
  const [src, setSrc] = useState('');
  useEffect(() => {
    let live = true;
    void nui.call<NuiResult & { data?: string }>('messages:media', id).then((r) => { if (live && r.ok && r.data) setSrc(r.data); });
    return () => { live = false; };
  }, [id, nui]);
  return src ? <img alt={label} src={src} style={{ display: 'block', width: 300, maxHeight: 220, objectFit: 'cover', borderRadius: 20 }} />
    : <span role="img" aria-label={label} style={{ display: 'block', width: 300, height: 200, borderRadius: 20, background: 'linear-gradient(160deg,#ffae3d,#b8326f 60%,#2b1a5e)' }} />;
}

export default function App({ t, dark, nui, data }: AppProps) {
  const c = dark
    ? { cell: '#1c1c1e', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', fill: '#3a3a3c', bubble: '#3a3a3c', map: '#2c3a2c', road: '#48484a' }
    : { cell: '#ffffff', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', fill: '#e3e3e8', bubble: '#e9e9eb', map: '#dcebd2', road: '#ffffff' };
  const lang = useSettingsApi().lang;
  const [threads, setThreads] = useState<Thread[]>([]);
  const [pins, setPins] = useState<string[]>([]);
  const [blocked, setBlocked] = useState<string[]>([]);
  const [contacts, setContacts] = useState<ContactRow[]>([]);
  const [me, setMe] = useState('');
  const [sel, setSel] = useState<string | null>(null);
  const [msgs, setMsgs] = useState<Msg[]>([]);
  const [draft, setDraft] = useState('');
  const [query, setQuery] = useState('');
  const [plus, setPlus] = useState(false);
  const [pickContact, setPickContact] = useState(false);
  const [newOpen, setNewOpen] = useState(false);
  const [newTo, setNewTo] = useState('');
  const [picked, setPicked] = useState<string[]>([]);
  const [gname, setGname] = useState('');
  const [photos, setPhotos] = useState<Array<{ id: number; thumb?: string | null }> | null>(null);
  const [toast, setToast] = useState('');
  const selRef = useRef<string | null>(null);
  selRef.current = sel;
  const flash = useCallback((text: string) => { setToast(text); setTimeout(() => setToast(''), 2200); }, []);

  const refresh = useCallback(async () => {
    const r = await nui.call<ThreadsRes>('messages:threads');
    if (r.ok) { setThreads(r.items ?? []); setPins(r.pins ?? []); setBlocked(r.blocked ?? []); setMe(r.me ?? ''); }
  }, [nui]);

  const open = useCallback(async (id: string) => {
    setSel(id); setPlus(false); setMsgs([]);
    const r = await nui.call<ThreadRes>('messages:thread', { phone: id });
    if (r.ok && selRef.current === id) setMsgs(r.items ?? []);
    setThreads((cur) => (cur.some((x) => x.id === id) ? cur.map((x) => (x.id === id ? { ...x, unread: 0 } : x)) : [{ id, group: id.startsWith('g'), unread: 0 }, ...cur]));
    void nui.call('messages:read', { phone: id });
  }, [nui]);

  useEffect(() => {
    let live = true;
    void (async () => {
      const [, cl] = await Promise.all([refresh(), nui.call<ListRes>('contacts:list')]);
      if (live && cl.ok) setContacts(cl.items ?? []);
      const to = (data as { to?: string } | undefined)?.to;
      if (live && to) void open(to);
    })();
    // Réception en direct : accusé « Lu » ou nouveau message (le fil ouvert est relu, la liste aussi).
    const on = (e: Event) => {
      const d = (e as CustomEvent).detail as PushMsg | null;
      if (!d) return;
      if (d.read) { if (selRef.current === d.read) setMsgs((cur) => cur.map((x) => (x.me ? { ...x, read: true } : x))); return; }
      const peer = d.to?.startsWith('g') ? d.to : d.from;
      void refresh();
      if (peer && selRef.current === peer) void open(peer);
    };
    window.addEventListener('pop-message', on);
    return () => { live = false; window.removeEventListener('pop-message', on); };
  }, [nui, refresh, open, data]);

  const titleOf = (th: Thread) => (th.group ? th.name || t('msg.group') : nameFor(contacts, th.id));
  const previewOf = (th: Thread) => (!th.last ? t('msg.new_conv') : th.last.kind === 'photo' ? t('msg.photo_shared') : th.last.kind === 'location' ? t('msg.loc_shared') : th.last.kind === 'contact' ? t('msg.contact_shared') : th.last.body);
  const q = query.trim().toLowerCase();
  const match = (th: Thread) => !q || `${titleOf(th)} ${previewOf(th)}`.toLowerCase().includes(q);
  const pinned = threads.filter((x) => pins.includes(x.id) && match(x));
  const rows = threads.filter((x) => !pins.includes(x.id) && match(x));
  const cur = threads.find((x) => x.id === sel);

  const send = async (extra?: { kind: string; ref?: number }) => {
    const body = draft.trim();
    if (!sel || (!extra && !body)) return;
    const r = await nui.call<SendRes>('messages:send', extra ? { to: sel, ...extra } : { to: sel, body });
    if (r.ok && r.msg) { setMsgs((m) => [...m, r.msg!]); setDraft(''); setPlus(false); setPickContact(false); setPhotos(null); void refresh(); } else flash(r.err ? t(r.err) : t('msg.err'));
  };
  const togglePin = async () => {
    if (!sel) return;
    const r = await nui.call<NuiResult & { pins?: string[] }>('messages:pin', { phone: sel, on: !pins.includes(sel) });
    if (r.ok) setPins(r.pins ?? []);
  };
  // Groupe : quitter. Conversation à deux : bloquer ou débloquer le numéro.
  const leaveOrBlock = async () => {
    if (!sel) return;
    if (sel.startsWith('g')) {
      const r = await nui.call('messages:leave', { to: sel });
      if (r.ok) { setSel(null); setMsgs([]); void refresh(); } else flash(r.err ? t(r.err) : t('msg.err'));
      return;
    }
    const r = await nui.call<NuiResult & { blocked?: string[] }>('messages:block', { phone: sel, on: !blocked.includes(sel) });
    if (r.ok) setBlocked(r.blocked ?? []); else flash(r.err ? t(r.err) : t('msg.err'));
  };
  const askPhotos = async () => {
    setPlus(false);
    const r = await nui.call<PhotosRes>('photos:list', { offset: 0 });
    setPhotos(r.ok ? r.items ?? [] : []);
  };
  const call = async () => { if (sel && !sel.startsWith('g')) { flash(t('msg.calling', titleOf(cur ?? { id: sel, group: false, unread: 0 }))); openOtherApp('telephone', { dial: sel }); } };

  const typedPhone = (): string | null => {
    const v = newTo.trim();
    if (!v) return null;
    const byName = contacts.find((x) => x.name.toLowerCase() === v.toLowerCase());
    if (byName?.phone) return byName.phone;
    return /^\d{3}-\d{4}$/.test(v) ? v : null;
  };
  const targets = [...new Set([...picked, ...(typedPhone() ? [typedPhone()!] : [])])];
  const create = async () => {
    if (targets.length === 1) { setNewOpen(false); void open(targets[0]!); return; }
    if (targets.length >= 2 && gname.trim()) {
      const r = await nui.call<NuiResult & { id?: string }>('messages:group', { name: gname.trim(), members: targets });
      if (r.ok && r.id) { setNewOpen(false); await refresh(); void open(r.id); } else flash(r.err ? t(r.err) : t('msg.err'));
    }
  };

  const avatar = (id: string, name: string, size: number, fs: number) => (
    <span style={{ width: size, height: size, flexShrink: 0, borderRadius: size / 2, background: gradOf(id), color: '#fff', fontSize: fs, fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{initials(name)}</span>
  );
  const dayKey = (at: number) => new Date(at * 1000).toDateString();

  return (
    <div style={{ width: '100%', height: '100%', display: 'flex', background: c.cell, color: c.fg, fontFamily: 'inherit', letterSpacing: '-0.01em', overflow: 'hidden', position: 'relative' }}>
      <nav aria-label={t('app.messages')} style={{ width: 390, flexShrink: 0, height: '100%', boxSizing: 'border-box', borderInlineEnd: `1px solid ${c.sep}`, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '46px 18px 8px', display: 'flex', flexDirection: 'column', gap: 10 }}>
          <span style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: 34, fontWeight: 700 }}>{t('app.messages')}</span>
            <Glass as="button" aria-label={t('msg.new')} onClick={() => { setNewOpen(true); setNewTo(''); setPicked([]); setGname(''); }} style={{ width: 44, height: 44, borderRadius: 22, border: 0, padding: 0, cursor: 'pointer', color: BLUE, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={D.plus} /></Glass>
          </span>
          <span style={{ fontSize: 13, color: c.sub }}>{t('msg.me', me)}</span>
          <label style={{ height: 40, borderRadius: 20, background: c.fill, display: 'flex', alignItems: 'center', gap: 8, padding: '0 12px', color: c.sub }}>
            <Ico d={D.search} size={17} />
            <input aria-label={t('msg.search')} placeholder={t('msg.search')} value={query} onChange={(e) => setQuery(e.target.value)} style={{ all: 'unset', flexGrow: 1, fontSize: 17, color: c.fg }} />
          </label>
        </div>
        <div style={{ flexGrow: 1, overflowY: 'auto', paddingBottom: 20 }}>
          {pinned.length > 0 && (
            <div style={{ display: 'flex', justifyContent: 'space-around', padding: '10px 10px 14px', flexWrap: 'wrap' }}>
              {pinned.map((th) => (
                <button key={th.id} type="button" onClick={() => void open(th.id)} aria-label={titleOf(th)} style={{ ...BTN, width: 104, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, position: 'relative' }}>
                  <span style={{ borderRadius: 40, boxShadow: `0 0 0 3px ${sel === th.id ? BLUE : 'transparent'}`, display: 'flex' }}>{avatar(th.id, titleOf(th), 76, 28)}</span>
                  <span style={{ fontSize: 14, fontWeight: 500 }}>{titleOf(th).split(' ')[0]}</span>
                  {th.unread > 0 && <span style={{ position: 'absolute', top: 0, left: 6, minWidth: 20, height: 20, borderRadius: 10, background: BLUE, color: '#fff', fontSize: 12, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{th.unread}</span>}
                </button>
              ))}
            </div>
          )}
          {rows.map((th) => {
            const on = sel === th.id;
            return (
              <button key={th.id} type="button" onClick={() => void open(th.id)} style={{ ...BTN, display: 'flex', alignItems: 'center', gap: 12, margin: '0 8px', padding: 10, borderRadius: 14, boxSizing: 'border-box', width: 'calc(100% - 16px)', background: on ? BLUE : 'transparent' }}>
                {avatar(th.id, titleOf(th), 52, 19)}
                <span style={{ flexGrow: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 2 }}>
                  <span style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                    <span style={{ fontSize: 17, fontWeight: 600, color: on ? '#fff' : c.fg, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{titleOf(th)}</span>
                    <span style={{ fontSize: 14, color: on ? 'rgba(255,255,255,.8)' : c.sub, flexShrink: 0 }}>{th.last ? whenOf(th.last.at, t, lang) : ''}</span>
                  </span>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ flexGrow: 1, fontSize: 15, lineHeight: 1.3, color: on ? 'rgba(255,255,255,.8)' : c.sub, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{previewOf(th)}</span>
                    <span style={{ width: 12, height: 12, borderRadius: 6, background: BLUE, flexShrink: 0, opacity: th.unread > 0 ? 1 : 0 }} />
                  </span>
                </span>
              </button>
            );
          })}
          {!rows.length && !pinned.length && <span style={{ display: 'block', textAlign: 'center', padding: '50px 10px', color: c.sub, fontSize: 16 }}>{t('msg.empty')}</span>}
        </div>
      </nav>

      <main style={{ flexGrow: 1, minWidth: 0, height: '100%', position: 'relative', display: 'flex', flexDirection: 'column' }}>
        {sel && cur ? (
          <>
            <div style={{ position: 'absolute', top: 20, left: 24, right: 24, zIndex: 5, display: 'flex', justifyContent: 'space-between', alignItems: 'center', pointerEvents: 'none' }}>
              <Glass as="button" aria-label={pins.includes(sel) ? t('msg.unpin') : t('msg.pin')} onClick={() => void togglePin()} style={{ width: 48, height: 48, borderRadius: 24, border: 0, padding: 0, cursor: 'pointer', pointerEvents: 'auto', color: pins.includes(sel) ? '#ff9f0a' : c.sub, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={D.pin} size={20} /></Glass>
              <Glass as="button" aria-label={cur.group ? t('msg.leave') : blocked.includes(sel) ? t('msg.unblock') : t('msg.block')} onClick={() => void leaveOrBlock()} style={{ height: 48, borderRadius: 24, border: 0, padding: '0 16px', cursor: 'pointer', pointerEvents: 'auto', color: cur.group || !blocked.includes(sel) ? '#ff383c' : c.sub, fontSize: 15, fontWeight: 600 }}>{cur.group ? t('msg.leave') : blocked.includes(sel) ? t('msg.unblock') : t('msg.block')}</Glass>
              <Glass style={{ height: 52, borderRadius: 26, display: 'flex', alignItems: 'center', gap: 10, padding: '0 20px 0 6px', pointerEvents: 'auto' }}>
                {avatar(sel, titleOf(cur), 40, 15)}
                <span style={{ fontSize: 17, fontWeight: 600 }}>{titleOf(cur)}</span>
              </Glass>
              <Glass as="button" aria-label={t('msg.call')} onClick={() => void call()} style={{ width: 52, height: 52, borderRadius: 26, border: 0, padding: 0, cursor: 'pointer', pointerEvents: 'auto', color: BLUE, display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: cur.group ? 0.35 : 1 }}><Ico d={D.call} /></Glass>
            </div>
            <div style={{ flexGrow: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column-reverse' }}>
              <div style={{ padding: '96px 28px 100px', display: 'flex', flexDirection: 'column', gap: 3 }}>
                {msgs.map((m, i) => {
                  const media = m.kind !== 'text';
                  const newGroup = i === 0 || msgs[i - 1]!.me !== m.me;
                  const newDay = i === 0 || dayKey(msgs[i - 1]!.at) !== dayKey(m.at);
                  const last = i === msgs.length - 1;
                  return (
                    <div key={m.id}>
                      {newDay && <span style={{ display: 'block', textAlign: 'center', fontSize: 12, color: c.sub, padding: '14px 0 6px' }}><b>{whenOf(m.at, t, lang)}</b> {clock(m.at)}</span>}
                      <div style={{ display: 'flex', justifyContent: m.me ? 'flex-end' : 'flex-start', marginTop: newGroup ? 8 : 0 }}>
                        <div style={{ maxWidth: 460, boxSizing: 'border-box', borderRadius: 20, background: media ? 'transparent' : m.me ? BLUE : c.bubble, color: m.me ? '#fff' : c.fg, padding: media ? 0 : '8px 14px', fontSize: 17, lineHeight: 1.35 }}>
                          {m.kind === 'text' && <span>{m.body}</span>}
                          {m.kind === 'photo' && <MediaPhoto id={m.id} nui={nui} label={t('msg.photo_shared')} />}
                          {m.kind === 'contact' && (
                            <span style={{ display: 'block', minWidth: 220 }}>
                              <b style={{ display: 'block' }}>{m.body}</b>
                              <span style={{ fontSize: 15, opacity: 0.85 }}>{(m.ref ?? '').split('|')[0]}</span>
                            </span>
                          )}
                          {m.kind === 'location' && (
                            <span style={{ display: 'block', width: 300, borderRadius: 20, overflow: 'hidden', background: c.cell, color: c.fg }}>
                              <svg role="img" aria-label={t('msg.loc_shared')} width="300" height="150" viewBox="0 0 300 150"><rect width="300" height="150" fill={c.map} /><path d="M0 100h300M90 0v150M200 0l-60 150" stroke={c.road} strokeWidth="10" fill="none" /><path d="M150 112s-14-12-14-22a14 14 0 0 1 28 0c0 10-14 22-14 22z" fill="#ff3b30" /><circle cx="150" cy="90" r="5" fill="#fff" /></svg>
                              <span style={{ display: 'block', padding: '8px 14px', fontSize: 15 }}>{t('msg.loc_shared')}</span>
                            </span>
                          )}
                        </div>
                      </div>
                      {m.me && last && <span style={{ display: 'block', textAlign: 'end', fontSize: 12, fontWeight: 500, color: c.sub, padding: '2px 4px' }}>{m.read ? t('msg.read') : t('msg.delivered')}</span>}
                    </div>
                  );
                })}
              </div>
            </div>
            {plus && (
              <Glass style={{ position: 'absolute', left: 24, bottom: 84, width: 210, borderRadius: 18, padding: 6, zIndex: 6, display: 'flex', flexDirection: 'column' }}>
                <button type="button" onClick={() => void askPhotos()} style={{ ...BTN, height: 44, padding: '0 12px', borderRadius: 12, fontSize: 17, display: 'flex', alignItems: 'center', gap: 10 }}><Ico d={D.photo} size={20} color={BLUE} />{t('msg.photo')}</button>
                <button type="button" onClick={() => { setPlus(false); setPickContact(true); }} style={{ ...BTN, height: 44, padding: '0 12px', borderRadius: 12, fontSize: 17, display: 'flex', alignItems: 'center', gap: 10 }}><Ico d={D.call} size={20} color="#ff9f0a" />{t('msg.contact')}</button>
                <button type="button" onClick={() => void send({ kind: 'location' })} style={{ ...BTN, height: 44, padding: '0 12px', borderRadius: 12, fontSize: 17, display: 'flex', alignItems: 'center', gap: 10 }}><Ico d={D.loc} size={20} color="#34c759" />{t('msg.loc')}</button>
              </Glass>
            )}
            <div style={{ position: 'absolute', left: 24, right: 24, bottom: 20, display: 'flex', gap: 10, alignItems: 'center' }}>
              <Glass as="button" aria-label={t('msg.add')} onClick={() => setPlus(!plus)} style={{ width: 48, height: 48, borderRadius: 24, border: 0, padding: 0, cursor: 'pointer', color: c.fg, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', transition: 'transform .2s', transform: `rotate(${plus ? 45 : 0}deg)` }}><Ico d={D.plus} /></Glass>
              <Glass as="label" style={{ flexGrow: 1, height: 48, borderRadius: 24, display: 'flex', alignItems: 'center', padding: '0 8px 0 18px', gap: 8, boxSizing: 'border-box' }}>
                <input aria-label={t('msg.ph')} placeholder={t('msg.ph')} value={draft} onChange={(e) => setDraft(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') void send(); }} maxLength={1000} style={{ all: 'unset', flexGrow: 1, fontSize: 17, color: c.fg }} />
                <button type="button" aria-label={t('msg.send')} onClick={() => void send()} style={{ ...BTN, width: 34, height: 34, borderRadius: 17, background: BLUE, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: draft.trim() ? 1 : 0.35 }}><Ico d={D.send} size={18} /></button>
              </Glass>
            </div>
          </>
        ) : (
          <div style={{ flexGrow: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', color: c.sub, fontSize: 20 }}>{t('msg.none_sel')}</div>
        )}
        {toast && <Glass style={{ position: 'absolute', top: 88, left: '50%', transform: 'translateX(-50%)', minWidth: 260, height: 44, borderRadius: 22, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, fontWeight: 600, zIndex: 8, padding: '0 16px' }}><span role="status">{toast}</span></Glass>}
      </main>

      {newOpen && (
        <div role="dialog" aria-label={t('msg.new')} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,.35)', zIndex: 20, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ width: 520, borderRadius: 26, background: c.cell, padding: 22, boxSizing: 'border-box', display: 'flex', flexDirection: 'column', gap: 16, boxShadow: '0 20px 60px rgba(0,0,0,.4)' }}>
            <span style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <button type="button" onClick={() => setNewOpen(false)} style={{ ...BTN, fontSize: 17, color: BLUE }}>{t('msg.cancel')}</button>
              <span style={{ fontSize: 17, fontWeight: 700 }}>{t('msg.new')}</span>
              <button type="button" onClick={() => void create()} style={{ ...BTN, fontSize: 17, fontWeight: 600, color: BLUE }}>{t('msg.create')}</button>
            </span>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, height: 46, borderRadius: 12, background: c.fill, padding: '0 14px' }}>
              <span style={{ color: c.sub, fontSize: 17 }}>{t('msg.to')}</span>
              <input aria-label={t('msg.to_ph')} placeholder={t('msg.to_ph')} value={newTo} onChange={(e) => setNewTo(e.target.value)} style={{ all: 'unset', flexGrow: 1, fontSize: 17, color: c.fg }} />
            </label>
            {targets.length >= 2 && (
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, height: 46, borderRadius: 12, background: c.fill, padding: '0 14px' }}>
                <input aria-label={t('msg.group_name')} placeholder={t('msg.group_name')} value={gname} onChange={(e) => setGname(e.target.value)} maxLength={40} style={{ all: 'unset', flexGrow: 1, fontSize: 17, color: c.fg }} />
              </label>
            )}
            <span style={{ fontSize: 13, color: c.sub }}>{t('msg.suggest')}</span>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              {contacts.filter((x) => x.phone).map((u) => {
                const on = picked.includes(u.phone);
                return <button key={u.id} type="button" aria-pressed={on} onClick={() => setPicked(on ? picked.filter((p) => p !== u.phone) : [...picked, u.phone])} style={{ ...BTN, height: 34, padding: '0 14px', borderRadius: 17, background: on ? BLUE : c.fill, color: on ? '#fff' : c.fg, fontSize: 15, display: 'flex', alignItems: 'center' }}>{u.name}</button>;
              })}
            </div>
          </div>
        </div>
      )}

      <Sheet open={photos !== null} onClose={() => setPhotos(null)} title={t('msg.pick_photo')}>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {(photos ?? []).length === 0 && <span style={{ color: c.sub }}>{t('msg.no_photos')}</span>}
          {(photos ?? []).map((p) => (
            <button key={p.id} type="button" aria-label={t('msg.photo')} onClick={() => void send({ kind: 'photo', ref: p.id })} style={{ ...BTN, width: 96, height: 96, borderRadius: 12, overflow: 'hidden', background: c.fill }}>
              {p.thumb ? <img alt="" src={p.thumb} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : null}
            </button>
          ))}
        </div>
      </Sheet>
      <Sheet open={pickContact} onClose={() => setPickContact(false)} title={t('msg.contact')}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, maxHeight: 420, overflowY: 'auto' }}>
          {contacts.length === 0 && <span style={{ color: c.sub }}>{t('msg.no_contacts')}</span>}
          {contacts.map((u) => (
            <button key={u.id} type="button" aria-label={u.name} onClick={() => void send({ kind: 'contact', ref: u.id })} style={{ ...BTN, padding: '10px 12px', borderRadius: 12, fontSize: 17, display: 'flex', justifyContent: 'space-between' }}>
              <span>{u.name}</span><span style={{ color: c.sub }}>{u.phone}</span>
            </button>
          ))}
        </div>
      </Sheet>
    </div>
  );
}
