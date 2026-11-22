import { useCallback, useEffect, useRef, useState } from 'react';
import { Button, Field, Glass, Sheet, duration, gradOf, initials, nameFor, useSettingsApi, whenOf, type AppProps, type ContactRow, type NuiResult } from '../../kit';

const BLUE = '#0088ff';
const RED = '#ff383c';
const GREEN = '#34c759';
const BTN = { all: 'unset', cursor: 'pointer' } as const;

type Tab = 'favs' | 'recents' | 'contacts' | 'pad' | 'voice';
interface Recent { id: number; peer: string; dir: 'in' | 'out' | 'missed'; at: number; secs: number }
interface Voice { id: number; from: string; text: string; at: number }
interface Call { id: number | null; num: string; phase: 'ring' | 'active' | 'incoming'; secs: number; mute: boolean; spk: boolean; keypad: boolean; typed: string }
interface ContactsRes extends NuiResult { items?: ContactRow[] }
interface VoiceRes extends NuiResult { items?: Voice[] }
interface CallPush { id?: number; state?: string; why?: string; from?: string }

const ICON = {
  favs: 'M12 3l2.700 5.600 6.100.9-4.400 4.300 1 6.100L12 17l-5.400 2.900 1-6.100L3.200 9.500l6.100-.9z', recents: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 7v5l3 2',
  contacts: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0', pad: 'M6 5h.01M12 5h.01M18 5h.01M6 10h.01M12 10h.01M18 10h.01M6 15h.01M12 15h.01M18 15h.01M12 20h.01',
  voice: 'M7 16a4 4 0 1 1 0-8 4 4 0 0 1 0 8zM17 16a4 4 0 1 1 0-8 4 4 0 0 1 0 8zM7 16h10',
  phone: 'M5 4h4l2 5-2.500 1.500a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2', back: 'M20 12H8M13 6l-6 6 6 6',
  mute: 'M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3zM5 11a7 7 0 0 0 14 0M12 18v3M4 4l16 16', speaker: 'M4 9v6h4l5 4V5L8 9zM16 9a4 4 0 0 1 0 6M18.500 6a8 8 0 0 1 0 12',
  plus: 'M12 5v14M5 12h14', play: 'M7 4l13 8-13 8z',
};
function Ico({ d, size = 24, color = 'currentColor' }: { d: string; size?: number; color?: string }) {
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
}

const KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
const LETTERS: Record<string, string> = { '2': 'ABC', '3': 'DEF', '4': 'GHI', '5': 'JKL', '6': 'MNO', '7': 'PQRS', '8': 'TUV', '9': 'WXYZ', '0': '+' };

function appendDigit(s: string, d: string): string {
  return s.length < 12 ? s + d : s;
}

/** Numéro tapé au clavier : 3 chiffres, un tiret, 4 chiffres (format du serveur). */
export const shownNumber = (digits: string): string => (digits.length > 3 && /^\d+$/.test(digits) ? `${digits.slice(0, 3)}-${digits.slice(3)}` : digits);

export default function App({ t, dark, nui, data }: AppProps) {
  const c = dark
    ? { bg: '#000000', cell: '#1c1c1e', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', fill: '#2c2c2e' }
    : { bg: '#f2f2f7', cell: '#ffffff', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', fill: '#e3e3e8' };
  const lang = useSettingsApi().lang;
  const [tab, setTab] = useState<Tab>('recents');
  const [seg, setSeg] = useState<'all' | 'missed'>('all');
  const [digits, setDigits] = useState('');
  const [contacts, setContacts] = useState<ContactRow[]>([]);
  const [recents, setRecents] = useState<Recent[]>([]);
  const [voice, setVoice] = useState<Voice[]>([]);
  const [call, setCall] = useState<Call | null>(null);
  const [vmFor, setVmFor] = useState<string | null>(null);
  const [vmText, setVmText] = useState('');
  const [toast, setToast] = useState('');
  const callRef = useRef<Call | null>(null);
  callRef.current = call;
  const flash = useCallback((text: string) => { setToast(text); setTimeout(() => setToast(''), 2400); }, []);

  const loadHistory = useCallback(async () => {
    const r = await nui.call<NuiResult & { items?: Recent[] }>('phone:history');
    if (r.ok) setRecents(r.items ?? []);
  }, [nui]);

  const start = useCallback(async (num: string) => {
    if (!num || callRef.current) return;
    const r = await nui.call<NuiResult & { callId?: number }>('phone:call', { to: num });
    if (r.ok && typeof r.callId === 'number') setCall({ id: r.callId, num, phase: 'ring', secs: 0, mute: false, spk: false, keypad: false, typed: '' });
    else { flash(r.err ? t(r.err) : t('tel.err')); if (r.err === 'err_unreachable') setVmFor(num); void loadHistory(); }
  }, [nui, t, flash, loadHistory]);

  useEffect(() => {
    let live = true;
    void (async () => {
      const pc = nui.call<ContactsRes>('contacts:list');
      const pv = nui.call<VoiceRes>('phone:voicemails');
      const [cl, vm] = await Promise.all([pc, pv, loadHistory()]);
      if (!live) return;
      if (cl.ok) setContacts(cl.items ?? []);
      if (vm.ok) setVoice(vm.items ?? []);
      const d = (data ?? {}) as { dial?: string; ring?: CallPush };
      if (d.ring && typeof d.ring.id === 'number') setCall({ id: d.ring.id, num: d.ring.from ?? '', phase: 'incoming', secs: 0, mute: false, spk: false, keypad: false, typed: '' });
      else if (d.dial) void start(d.dial);
    })();
    // Poussées du serveur : sonnerie, décroché de l'autre côté, fin d'appel.
    const on = (e: Event) => {
      const d = (e as CustomEvent).detail as CallPush | null;
      if (!d) return;
      const cur = callRef.current;
      if (d.state === 'ring' && !cur) setCall({ id: d.id ?? null, num: d.from ?? '', phase: 'incoming', secs: 0, mute: false, spk: false, keypad: false, typed: '' });
      else if (d.state === 'active' && cur) setCall({ ...cur, phase: 'active', secs: 0 });
      else if (d.state === 'end' && cur) {
        setCall(null);
        flash(t('tel.ended'));
        if (cur.phase === 'ring' && (d.why === 'missed' || d.why === 'declined')) setVmFor(cur.num);
        void loadHistory();
      }
    };
    window.addEventListener('pop-call', on);
    return () => { live = false; window.removeEventListener('pop-call', on); };
  }, [nui, data, start, loadHistory, flash, t]);

  // Durée de la communication : une seconde par seconde, seulement pendant l'appel.
  const active = call?.phase === 'active';
  useEffect(() => {
    if (!active) return;
    const id = setInterval(() => setCall((cur) => (cur ? { ...cur, secs: cur.secs + 1 } : cur)), 1000);
    return () => clearInterval(id);
  }, [active]);

  const hangUp = async () => { const cur = call; setCall(null); if (cur?.id != null) await nui.call('phone:hangup', cur.id); void loadHistory(); };
  const accept = async () => {
    if (!call || call.id == null) return;
    const r = await nui.call('phone:answer', call.id);
    if (r.ok) setCall({ ...call, phase: 'active', secs: 0 }); else { setCall(null); flash(r.err ? t(r.err) : t('tel.err')); }
  };
  const refuse = async () => { const cur = call; setCall(null); if (cur?.id != null) await nui.call('phone:decline', cur.id); void loadHistory(); };
  const sendVm = async () => {
    if (!vmFor || !vmText.trim()) return;
    const r = await nui.call('phone:voicemail', { to: vmFor, text: vmText.trim() });
    if (r.ok) { setVmFor(null); setVmText(''); } else flash(r.err ? t(r.err) : t('tel.err'));
  };

  const nm = (num: string) => nameFor(contacts, num);
  const label = (num: string) => (nm(num) === num ? num || t('tel.unknown') : nm(num));
  const missed = recents.filter((r) => r.dir === 'missed').length;
  const tabs: Array<[Tab, string]> = [['favs', 'tel.favs'], ['recents', 'tel.recents'], ['contacts', 'tel.contacts'], ['pad', 'tel.pad'], ['voice', 'tel.voice']];
  const favs = contacts.filter((x) => x.fav && x.phone);
  const list = tab === 'recents'
    ? recents.filter((r) => seg === 'all' || r.dir === 'missed').map((r) => ({ key: `r${r.id}`, num: r.peer, name: label(r.peer), sub: r.dir === 'missed' ? t('tel.missed_call') : r.dir === 'in' ? t('tel.in_call') : t('tel.out_call'), red: r.dir === 'missed', time: whenOf(r.at, t, lang) }))
    : contacts.filter((x) => x.phone).sort((a, b) => a.name.localeCompare(b.name)).map((x) => ({ key: `c${x.id}`, num: x.phone, name: x.name, sub: x.phone, red: false, time: '' }));
  const dialed = shownNumber(digits);

  return (
    <div style={{ width: '100%', height: '100%', display: 'flex', background: c.bg, color: c.fg, letterSpacing: '-0.01em', overflow: 'hidden', position: 'relative' }}>
      <nav aria-label={t('app.telephone')} style={{ width: 300, flexShrink: 0, height: '100%', boxSizing: 'border-box', borderInlineEnd: `1px solid ${c.sep}`, padding: '46px 14px 20px', display: 'flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontSize: 34, fontWeight: 700, padding: '0 10px 12px' }}>{t('app.telephone')}</span>
        {tabs.map(([id, key]) => {
          const on = tab === id;
          return (
            <button key={id} type="button" aria-pressed={on} onClick={() => setTab(id)} style={{ ...BTN, display: 'flex', alignItems: 'center', gap: 12, height: 46, padding: '0 10px', borderRadius: 10, background: on ? BLUE : 'transparent', color: on ? '#fff' : c.fg }}>
              <Ico d={ICON[id]} color={on ? '#fff' : id === 'favs' ? '#ff9f0a' : id === 'recents' ? BLUE : id === 'pad' ? GREEN : id === 'voice' ? '#cb30e0' : '#8e8e93'} />
              <span style={{ flexGrow: 1, fontSize: 17 }}>{t(key)}</span>
              {id === 'recents' && missed > 0 && <span style={{ minWidth: 22, height: 22, borderRadius: 11, background: RED, color: '#fff', fontSize: 13, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{missed}</span>}
            </button>
          );
        })}
      </nav>

      <main style={{ flexGrow: 1, minWidth: 0, height: '100%', display: 'flex', flexDirection: 'column', position: 'relative' }}>
        <div style={{ padding: '46px 40px 10px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontSize: 34, fontWeight: 700 }}>{t(tabs.find((x) => x[0] === tab)![1])}</span>
          {tab === 'recents' && (
            <Glass style={{ display: 'flex', padding: 3, borderRadius: 20, gap: 2 }}>
              {(['all', 'missed'] as const).map((g) => (
                <button key={g} type="button" aria-pressed={seg === g} onClick={() => setSeg(g)} style={{ ...BTN, height: 34, padding: '0 18px', borderRadius: 17, fontSize: 15, fontWeight: 600, background: seg === g ? BLUE : 'transparent', color: seg === g ? '#fff' : c.fg, display: 'flex', alignItems: 'center' }}>{t(g === 'all' ? 'tel.all' : 'tel.missed')}</button>
              ))}
            </Glass>
          )}
        </div>

        {tab === 'favs' && (
          <div style={{ padding: '10px 40px', display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, overflowY: 'auto' }}>
            {favs.length === 0 && <span style={{ color: c.sub }}>{t('tel.no_rows')}</span>}
            {favs.map((f) => (
              <button key={f.id} type="button" onClick={() => void start(f.phone)} style={{ ...BTN, background: c.cell, borderRadius: 20, padding: 18, display: 'flex', alignItems: 'center', gap: 14 }}>
                <span style={{ width: 56, height: 56, borderRadius: 28, background: gradOf(f.phone), color: '#fff', fontSize: 21, fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{initials(f.name)}</span>
                <span style={{ display: 'flex', flexDirection: 'column' }}><span style={{ fontSize: 17, fontWeight: 600 }}>{f.name}</span><span style={{ fontSize: 14, color: c.sub }}>{f.phone}</span></span>
              </button>
            ))}
          </div>
        )}

        {(tab === 'recents' || tab === 'contacts') && (
          <div style={{ flexGrow: 1, overflowY: 'auto', padding: '10px 40px 30px' }}>
            <div style={{ background: c.cell, borderRadius: 16, overflow: 'hidden' }}>
              {list.map((r, i) => (
                <div key={r.key} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '0 18px', height: 64, borderBottom: i < list.length - 1 ? `1px solid ${c.sep}` : 'none' }}>
                  <button type="button" onClick={() => void start(r.num)} style={{ ...BTN, flexGrow: 1, display: 'flex', flexDirection: 'column', gap: 2, minWidth: 0 }}>
                    <span style={{ fontSize: 18, fontWeight: 600, color: r.red ? RED : c.fg }}>{r.name}</span>
                    <span style={{ fontSize: 14, color: c.sub }}>{r.sub}</span>
                  </button>
                  <span style={{ fontSize: 15, color: c.sub }}>{r.time}</span>
                  <button type="button" aria-label={t('tel.call')} onClick={() => void start(r.num)} style={{ ...BTN, width: 38, height: 38, borderRadius: 19, background: c.fill, color: BLUE, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={ICON.phone} size={18} /></button>
                </div>
              ))}
              {list.length === 0 && <span style={{ display: 'block', textAlign: 'center', padding: 50, color: c.sub }}>{t('tel.no_rows')}</span>}
            </div>
          </div>
        )}

        {tab === 'voice' && (
          <div style={{ flexGrow: 1, overflowY: 'auto', padding: '10px 40px 30px' }}>
            <div style={{ background: c.cell, borderRadius: 16, overflow: 'hidden' }}>
              {voice.map((v, i) => (
                <div key={v.id} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '12px 18px', borderBottom: i < voice.length - 1 ? `1px solid ${c.sep}` : 'none' }}>
                  <span style={{ flexGrow: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
                    <span style={{ fontSize: 18, fontWeight: 600 }}>{label(v.from)}</span>
                    <span style={{ fontSize: 15, color: c.sub }}>{v.text}</span>
                  </span>
                  <span style={{ fontSize: 15, color: c.sub }}>{whenOf(v.at, t, lang)}</span>
                </div>
              ))}
              {voice.length === 0 && <span style={{ display: 'block', textAlign: 'center', padding: 50, color: c.sub }}>{t('tel.no_vm')}</span>}
            </div>
          </div>
        )}

        {tab === 'pad' && (
          <div style={{ flexGrow: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18, paddingTop: 20 }}>
            <span aria-live="polite" style={{ fontSize: 44, fontWeight: 300, height: 56, letterSpacing: 2 }}>{dialed}</span>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 92px)', gap: 16 }}>
              {KEYS.map((d) => (
                <button key={d} type="button" aria-label={d} onClick={() => setDigits((s) => appendDigit(s, d))} style={{ ...BTN, width: 92, height: 92, borderRadius: 46, background: c.cell, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
                  <span style={{ fontSize: 34, fontWeight: 400 }}>{d}</span>
                  <span style={{ fontSize: 11, letterSpacing: 2, color: c.sub, height: 12 }}>{LETTERS[d] ?? ''}</span>
                </button>
              ))}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 30 }}>
              <span style={{ width: 60 }} />
              <button type="button" aria-label={t('tel.call')} onClick={() => { void start(dialed); setDigits(''); }} style={{ ...BTN, width: 92, height: 92, borderRadius: 46, background: GREEN, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={ICON.phone} size={34} /></button>
              <button type="button" aria-label={t('tel.delete')} onClick={() => setDigits((s) => s.slice(0, -1))} style={{ ...BTN, width: 60, height: 60, display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: digits ? 1 : 0.3 }}><Ico d={ICON.back} size={30} /></button>
            </div>
          </div>
        )}
        {toast && <Glass style={{ position: 'absolute', bottom: 40, left: '50%', transform: 'translateX(-50%)', minWidth: 260, height: 44, borderRadius: 22, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, fontWeight: 600, padding: '0 16px', zIndex: 8 }}><span role="status">{toast}</span></Glass>}
      </main>

      {call && (
        <div role="dialog" aria-label={call.phase === 'incoming' ? t('tel.incoming') : label(call.num)} style={{ position: 'absolute', inset: 0, zIndex: 30, background: 'linear-gradient(170deg,#1d2a52,#0b1020)', color: '#fff', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '120px 40px 90px', boxSizing: 'border-box' }}>
          <span style={{ width: 120, height: 120, borderRadius: 60, background: gradOf(call.num), fontSize: 44, fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{initials(nm(call.num))}</span>
          <span style={{ fontSize: 38, fontWeight: 600, marginTop: 20 }}>{label(call.num)}</span>
          <span aria-live="polite" style={{ fontSize: 19, opacity: 0.75, marginTop: 6 }}>
            {call.phase === 'incoming' ? t('tel.incoming') : call.phase === 'ring' ? t('tel.ringing') : duration(call.secs)}{call.keypad && call.typed ? `  ·  ${call.typed}` : ''}
          </span>
          <span style={{ flexGrow: 1 }} />
          {call.phase === 'active' && !call.keypad && (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 88px)', gap: 22, marginBottom: 50 }}>
              {([['mute', 'tel.mute', ICON.mute, call.mute], ['keypad', 'tel.keypad', ICON.pad, false], ['spk', 'tel.speaker', ICON.speaker, call.spk], ['add', 'tel.add', ICON.plus, false]] as const).map(([k, key, d, on]) => (
                <button key={k} type="button" aria-label={t(key)} aria-pressed={on} onClick={() => { if (k === 'mute') setCall({ ...call, mute: !call.mute }); else if (k === 'spk') setCall({ ...call, spk: !call.spk }); else if (k === 'keypad') setCall({ ...call, keypad: true }); }} style={{ ...BTN, width: 88, height: 88, borderRadius: 44, background: on ? '#fff' : 'rgba(255,255,255,.18)', color: on ? '#1d2a52' : '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={d} size={30} /></button>
              ))}
            </div>
          )}
          {call.phase === 'active' && call.keypad && (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 80px)', gap: 14, marginBottom: 20 }}>
              {KEYS.map((d) => <button key={d} type="button" aria-label={d} onClick={() => setCall({ ...call, typed: call.typed + d })} style={{ ...BTN, width: 80, height: 80, borderRadius: 40, background: 'rgba(255,255,255,.18)', fontSize: 30, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{d}</button>)}
              <span /><span />
              <button type="button" onClick={() => setCall({ ...call, keypad: false })} style={{ ...BTN, fontSize: 16, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{t('tel.back')}</button>
            </div>
          )}
          {call.phase === 'incoming' ? (
            <div style={{ display: 'flex', gap: 120 }}>
              <button type="button" aria-label={t('tel.refuse')} onClick={() => void refuse()} style={{ ...BTN, width: 84, height: 84, borderRadius: 42, background: RED, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={ICON.phone} size={32} color="#fff" /></button>
              <button type="button" aria-label={t('tel.accept')} onClick={() => void accept()} style={{ ...BTN, width: 84, height: 84, borderRadius: 42, background: GREEN, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={ICON.phone} size={32} color="#fff" /></button>
            </div>
          ) : (
            <button type="button" aria-label={t('tel.hangup')} onClick={() => void hangUp()} style={{ ...BTN, width: 84, height: 84, borderRadius: 42, background: RED, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d={ICON.phone} size={32} color="#fff" /></button>
          )}
        </div>
      )}

      <Sheet open={vmFor !== null} onClose={() => setVmFor(null)} title={t('tel.vm_leave')}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <Field value={vmText} onChange={setVmText} label={t('tel.vm_text')} placeholder={t('tel.vm_text')} maxLength={200} onEnter={() => void sendVm()} />
          <Button onClick={() => void sendVm()} disabled={!vmText.trim()}>{t('tel.vm_send')}</Button>
        </div>
      </Sheet>
    </div>
  );
}
