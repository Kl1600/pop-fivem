import { useCallback, useEffect, useRef, useState } from 'react';
import { Button, Field, Glass, Sheet, useSettingsApi, type AppProps, type NuiResult } from '../../kit';
import { CHUNK, MAX_RECS, MAX_SECONDS, audioFits, chooseMode, chunks, clampSeconds, mmss, nextSpeed, recClock, speechAvailable, wave, type MicState, type RecRow } from './model';

const BTN = { all: 'unset', cursor: 'pointer' } as const;
const RED = '#ff383c';
const BLUE = '#0088ff';
const N = 96;

interface ListRes extends NuiResult { items?: RecRow[] }
interface GetRes extends NuiResult { rec?: { id: number; memo: boolean; text?: string; audio?: string } }

function Ico({ d, size = 20 }: { d: string; size?: number }) {
  return <svg aria-hidden="true" width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={d} /></svg>;
}

/** Test du micro de la NUI : getUserMedia, puis arrêt immédiat des pistes. */
async function testMic(): Promise<MicState> {
  try {
    if (!navigator.mediaDevices?.getUserMedia) return 'denied';
    const s = await navigator.mediaDevices.getUserMedia({ audio: true });
    s.getTracks().forEach((x) => x.stop());
    return 'granted';
  } catch {
    return 'denied';
  }
}

export default function App({ t, dark, nui }: AppProps) {
  const lang = useSettingsApi().lang ?? 'en';
  const c = dark
    ? { bg: '#000000', side: '#000000', cell: '#1c1c1e', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', fill: '#3a3a3c', bar: 'rgba(235,235,245,.3)' }
    : { bg: '#f2f2f7', side: '#f2f2f7', cell: '#ffffff', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', fill: '#e3e3e8', bar: 'rgba(60,60,67,.3)' };
  const hasRecorder = typeof MediaRecorder !== 'undefined';
  const [mic, setMic] = useState<MicState>('unknown');
  const mode = chooseMode(mic, hasRecorder);
  const [rows, setRows] = useState<RecRow[]>([]);
  const [sel, setSel] = useState<number | null>(null);
  const [content, setContent] = useState<{ memo: boolean; text?: string; audio?: string } | null>(null);
  const [error, setError] = useState('');
  const [renaming, setRenaming] = useState(false);
  const [rate, setRate] = useState(1);
  const [pos, setPos] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [rec, setRec] = useState<{ start: number; live: number[]; now: number } | null>(null);
  const [memoOpen, setMemoOpen] = useState(false);
  const [memoText, setMemoText] = useState('');
  const [speaking, setSpeaking] = useState(false);
  const audio = useRef<HTMLAudioElement | null>(null);
  const media = useRef<{ rec: MediaRecorder; stream: MediaStream; ctx: AudioContext | null; iv: ReturnType<typeof setInterval>; stop: ReturnType<typeof setTimeout> } | null>(null);

  const fail = useCallback((r: NuiResult) => setError(r.err ? t(r.err) : t('dic.err')), [t]);
  const reload = useCallback(async (): Promise<RecRow[]> => {
    const r = await nui.call<ListRes>('rec:list');
    if (!r.ok) { fail(r); return []; }
    setRows(r.items ?? []);
    return r.items ?? [];
  }, [nui, fail]);

  useEffect(() => {
    let live = true;
    void (async () => {
      const state = await testMic();
      if (!live) return;
      setMic(state);
      void nui.post('micro', { state });
      const list = await reload();
      if (live && list[0]) setSel(list[0].id);
    })();
    return () => { live = false; };
  }, [nui, reload]);

  // Contenu de l'enregistrement choisi.
  useEffect(() => {
    setContent(null); setPos(0); setPlaying(false); setRenaming(false);
    if (sel === null) return;
    let live = true;
    void nui.call<GetRes>('rec:get', sel).then((r) => { if (live && r.ok && r.rec) setContent({ memo: r.rec.memo, text: r.rec.text, audio: r.rec.audio }); });
    return () => { live = false; };
  }, [sel, nui]);

  // Nettoyage : lecture, synthèse et micro coupés à la fermeture.
  useEffect(() => () => {
    audio.current?.pause();
    if (speechAvailable()) window.speechSynthesis.cancel();
    const m = media.current;
    if (m) { clearInterval(m.iv); clearTimeout(m.stop); m.stream.getTracks().forEach((x) => x.stop()); void m.ctx?.close(); }
  }, []);

  const cur = rows.find((r) => r.id === sel) ?? null;
  const dateOf = (ms: number): string => new Date(ms * 1000).toLocaleString(lang, { dateStyle: 'short', timeStyle: 'short' });

  const upload = async (title: string, seconds: number, dataUri: string): Promise<boolean> => {
    if (!audioFits(dataUri)) { setError(t('dic.too_big')); return false; }
    const parts = chunks(dataUri, CHUNK);
    let last: NuiResult = { ok: false };
    for (let i = 0; i < parts.length; i++) {
      last = await nui.call('rec:save', { title, seconds, index: i + 1, total: parts.length, chunk: parts[i] });
      if (!last.ok) { fail(last); return false; }
    }
    const list = await reload();
    if (typeof last.id === 'number') setSel(last.id); else if (list[0]) setSel(list[0].id);
    return true;
  };

  const startRec = async () => {
    if (rows.length >= MAX_RECS) return setError(t('err_limit'));
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const r = new MediaRecorder(stream);
      const parts: Blob[] = [];
      const start = Date.now();
      let ctx: AudioContext | null = null;
      let analyser: AnalyserNode | null = null;
      try {
        ctx = new AudioContext();
        analyser = ctx.createAnalyser();
        ctx.createMediaStreamSource(stream).connect(analyser);
      } catch { ctx = null; analyser = null; }
      const buf = new Uint8Array(analyser?.fftSize ?? 0);
      const iv = setInterval(() => {
        let a = 0.2;
        if (analyser) { analyser.getByteTimeDomainData(buf); let m = 0; for (const v of buf) m = Math.max(m, Math.abs(v - 128)); a = Math.max(0.06, Math.min(1, m / 90)); }
        setRec((s) => (s ? { ...s, live: [...s.live, a].slice(-48), now: Date.now() } : s));
      }, 100);
      const stop = setTimeout(() => { if (r.state === 'recording') r.stop(); }, MAX_SECONDS * 1000);
      r.ondataavailable = (e) => { if (e.data.size > 0) parts.push(e.data); };
      r.onstop = () => {
        clearInterval(iv); clearTimeout(stop);
        stream.getTracks().forEach((x) => x.stop());
        void ctx?.close();
        media.current = null;
        setRec(null);
        const seconds = clampSeconds(Date.now() - start);
        const fr = new FileReader();
        fr.onload = () => { void upload(t('dic.default_name', rows.length + 1), seconds, String(fr.result)); };
        fr.readAsDataURL(new Blob(parts, { type: r.mimeType || 'audio/webm' }));
      };
      media.current = { rec: r, stream, ctx, iv, stop };
      r.start();
      setRec({ start, live: [], now: start });
      setPlaying(false);
    } catch {
      setMic('denied');
    }
  };
  const stopRec = () => { if (media.current?.rec.state === 'recording') media.current.rec.stop(); };

  const saveMemo = async () => {
    const body = memoText.trim();
    if (!body) return;
    const r = await nui.call<NuiResult & { id?: number }>('rec:save', { title: t('dic.memo_default', rows.length + 1), seconds: 0, memo: body });
    if (!r.ok) return fail(r);
    setMemoOpen(false); setMemoText('');
    await reload();
    if (typeof r.id === 'number') setSel(r.id);
  };

  const speak = () => {
    if (!content?.text || !speechAvailable()) return;
    if (speaking) { window.speechSynthesis.cancel(); setSpeaking(false); return; }
    const u = new SpeechSynthesisUtterance(content.text);
    u.lang = lang;
    u.onend = () => setSpeaking(false);
    u.onerror = () => setSpeaking(false);
    setSpeaking(true);
    window.speechSynthesis.speak(u);
  };

  const togglePlay = () => {
    const el = audio.current;
    if (!el || !content?.audio) return;
    if (playing) { el.pause(); setPlaying(false); return; }
    el.playbackRate = rate;
    void el.play().then(() => setPlaying(true)).catch(() => setError(t('dic.err')));
  };
  const seek = (s: number) => { const el = audio.current; const d = cur?.seconds ?? 0; const v = Math.max(0, Math.min(Math.max(0, d - 0.1), s)); if (el) el.currentTime = v; setPos(v); };

  const rename = (name: string) => {
    if (sel === null) return;
    setRows((l) => l.map((r) => (r.id === sel ? { ...r, title: name } : r)));
  };
  const commitRename = async () => {
    setRenaming(false);
    if (cur && cur.title.trim()) { const r = await nui.call('rec:rename', { id: cur.id, title: cur.title.trim() }); if (!r.ok) fail(r); }
  };
  const remove = async () => {
    if (sel === null) return;
    const r = await nui.call('rec:delete', sel);
    if (!r.ok) return fail(r);
    const list = await reload();
    setSel(list[0]?.id ?? null);
  };

  const bars = cur && content && !content.memo ? wave(cur.id, N) : [];
  const frac = cur && cur.seconds > 0 ? pos / cur.seconds : 0;
  const recMs = rec ? rec.now - rec.start : 0;
  const liveBars = Array.from({ length: 48 }, (_, i) => { const idx = i - (48 - (rec?.live.length ?? 0)); const a = idx >= 0 ? (rec?.live[idx] as number) : 0.04; return { h: Math.round(a * 190) + 4, op: idx >= 0 ? 1 : 0.3 }; });
  const isMemo = content?.memo === true;

  return (
    <div style={{ width: '100%', height: '100%', display: 'flex', background: c.bg, color: c.fg, overflow: 'hidden', position: 'relative' }}>
      <nav aria-label={t('dic.title')} style={{ width: 360, flexShrink: 0, height: '100%', boxSizing: 'border-box', background: c.side, borderInlineEnd: `1px solid ${c.sep}`, padding: '46px 14px 20px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <span style={{ fontSize: 34, fontWeight: 700, padding: '0 10px' }}>{t('dic.title')}</span>
        <span style={{ fontSize: 14, color: c.sub, padding: '0 10px 8px' }}>{t('dic.count', rows.length)}</span>
        <div style={{ flexGrow: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 2 }}>
          {rows.map((r) => (
            <button key={r.id} type="button" aria-pressed={sel === r.id} onClick={() => { if (!rec) setSel(r.id); }} style={{ ...BTN, display: 'flex', flexDirection: 'column', gap: 3, padding: '11px 12px', borderRadius: 12, background: sel === r.id ? RED : 'transparent', color: sel === r.id ? '#fff' : c.fg }}>
              <span style={{ fontSize: 17, fontWeight: 700, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.title}</span>
              <span style={{ display: 'flex', justifyContent: 'space-between', fontSize: 14, color: sel === r.id ? 'rgba(255,255,255,.85)' : c.sub }}><span>{dateOf(r.created)}</span><span>{r.memo ? t('dic.memo_badge') : mmss(r.seconds)}</span></span>
            </button>
          ))}
          {rows.length === 0 && <span style={{ display: 'block', textAlign: 'center', padding: '60px 10px', color: c.sub, fontSize: 16 }}>{t('dic.none')}</span>}
        </div>
      </nav>

      <main style={{ flexGrow: 1, minWidth: 0, height: '100%', position: 'relative', background: c.cell, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        {mode === 'testing' && <span role="status" style={{ marginTop: 160, color: c.sub, fontSize: 18 }}>{t('dic.mic_test')}</span>}
        {mode === 'memo' && !cur && <span role="status" style={{ marginTop: 160, maxWidth: 560, textAlign: 'center', color: c.sub, fontSize: 18, lineHeight: 1.4 }}>{t('dic.mic_denied')}</span>}

        {rec && (
          <>
            <div style={{ marginTop: 160, display: 'flex', alignItems: 'center', gap: 10, color: RED, fontSize: 18, fontWeight: 700 }}><span style={{ width: 12, height: 12, borderRadius: 6, background: RED }} />{t('dic.recording')}</div>
            <span style={{ fontSize: 96, fontWeight: 200, fontVariantNumeric: 'tabular-nums', paddingTop: 18 }}>{recClock(recMs)}</span>
            <div aria-label={t('dic.live')} role="img" style={{ width: 864, maxWidth: '90%', height: 200, marginTop: 40, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4 }}>
              {liveBars.map((b, i) => <span key={i} style={{ width: 5, height: b.h, borderRadius: 3, background: RED, opacity: b.op }} />)}
            </div>
          </>
        )}

        {cur && !rec && (
          <div style={{ width: 864, maxWidth: '90%', marginTop: 70, display: 'flex', flexDirection: 'column', gap: 4 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 56 }}>
              {renaming
                ? <input aria-label={t('dic.name')} value={cur.title} maxLength={80} onChange={(e) => rename(e.target.value)} style={{ all: 'unset', flexGrow: 1, height: 48, padding: '0 14px', borderRadius: 12, background: c.fill, fontSize: 28, fontWeight: 800, color: c.fg, marginInlineEnd: 12 }} />
                : <span style={{ fontSize: 34, fontWeight: 800, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{cur.title}</span>}
              <span style={{ display: 'flex', gap: 10, flexShrink: 0 }}>
                <Glass as="button" onClick={() => (renaming ? void commitRename() : setRenaming(true))} style={{ ...BTN, height: 42, padding: '0 18px', borderRadius: 21, display: 'flex', alignItems: 'center', fontSize: 16, fontWeight: 600, color: BLUE }}>{renaming ? t('dic.ok') : t('dic.rename')}</Glass>
                <Glass as="button" aria-label={t('dic.delete')} onClick={() => void remove()} style={{ ...BTN, width: 42, height: 42, borderRadius: 21, display: 'flex', alignItems: 'center', justifyContent: 'center', color: RED }}><Ico d="M5 7h14M9 7V4h6v3M7 7l1 13h8l1-13" /></Glass>
              </span>
            </div>
            <span style={{ fontSize: 16, color: c.sub }}>{dateOf(cur.created)} · {isMemo ? t('dic.memo_badge') : mmss(cur.seconds)}</span>
          </div>
        )}

        {cur && !rec && isMemo && (
          <div style={{ width: 864, maxWidth: '90%', marginTop: 30, display: 'flex', flexDirection: 'column', gap: 18 }}>
            <p data-testid="memo-text" style={{ margin: 0, fontSize: 22, lineHeight: 1.45, whiteSpace: 'pre-wrap', maxHeight: 420, overflowY: 'auto' }}>{content?.text}</p>
            {speechAvailable()
              ? <Button kind="plain" onClick={speak}>{speaking ? t('dic.memo_stop') : t('dic.memo_read')}</Button>
              : <span style={{ color: c.sub, fontSize: 15 }}>{t('dic.no_voice')}</span>}
          </div>
        )}

        {cur && !rec && content && !isMemo && (
          <>
            {content.audio && <audio ref={audio} src={content.audio} onTimeUpdate={(e) => setPos(e.currentTarget.currentTime)} onEnded={() => { setPlaying(false); setPos(0); }} />}
            <div style={{ position: 'relative', width: 864, maxWidth: '90%', height: 200, marginTop: 40, display: 'flex', alignItems: 'center', gap: 4, flexShrink: 0 }}>
              {bars.map((a, i) => <button key={i} type="button" aria-label={t('dic.seek')} onClick={() => seek((i / N) * cur.seconds)} style={{ ...BTN, width: 5, height: Math.round(a * 190), borderRadius: 3, background: i / N < frac ? RED : c.bar }} />)}
              <span style={{ position: 'absolute', top: -8, bottom: -8, insetInlineStart: `${frac * 100}%`, width: 2, background: RED, borderRadius: 1, pointerEvents: 'none' }} />
            </div>
            <div style={{ width: 864, maxWidth: '90%', display: 'flex', justifyContent: 'space-between', fontSize: 15, color: c.sub, paddingTop: 12, fontVariantNumeric: 'tabular-nums' }}><span>{mmss(pos)}</span><span>-{mmss(Math.max(0, cur.seconds - pos))}</span></div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 36, marginTop: 34 }}>
              <Glass as="button" aria-label={t('dic.speed')} onClick={() => { const r = nextSpeed(rate); setRate(r); if (audio.current) audio.current.playbackRate = r; }} style={{ ...BTN, width: 64, height: 44, borderRadius: 22, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 700, color: BLUE }}>{rate}×</Glass>
              <button type="button" aria-label={t('dic.back15')} onClick={() => seek(pos - 15)} style={{ ...BTN, width: 56, height: 56, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d="M4 4v5h5M4.5 9A8 8 0 1 1 4 13" size={40} /></button>
              <button type="button" aria-label={t('dic.play')} onClick={togglePlay} style={{ ...BTN, width: 76, height: 76, borderRadius: 38, background: c.fg, color: c.cell, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><svg aria-hidden="true" width="34" height="34" viewBox="0 0 24 24" fill="currentColor"><path d={playing ? 'M7 5h4v14H7zM13 5h4v14h-4z' : 'M7 4l13 8-13 8z'} /></svg></button>
              <button type="button" aria-label={t('dic.fwd15')} onClick={() => seek(pos + 15)} style={{ ...BTN, width: 56, height: 56, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Ico d="M20 4v5h-5M19.5 9A8 8 0 1 0 20 13" size={40} /></button>
              <span style={{ width: 64 }} />
            </div>
          </>
        )}

        {mode !== 'testing' && (
          <Glass style={{ position: 'absolute', insetInlineStart: '50%', bottom: 34, transform: 'translateX(-50%)', height: 92, padding: '0 36px', borderRadius: 46, display: 'flex', alignItems: 'center', gap: 18 }}>
            {mode === 'memo' && <span style={{ fontSize: 14, color: c.sub, maxWidth: 220 }}>{t('dic.mic_denied_short')}</span>}
            <span style={{ fontSize: 16, fontWeight: 600, color: c.sub, minWidth: 90, textAlign: 'end' }}>{mode === 'memo' ? t('dic.memo_title') : rec ? t('dic.stop') : t('dic.rec')}</span>
            <button type="button" aria-label={mode === 'memo' ? t('dic.memo_title') : t('dic.rec')} onClick={() => (mode === 'memo' ? setMemoOpen(true) : rec ? stopRec() : void startRec())} style={{ ...BTN, width: 68, height: 68, borderRadius: 34, boxSizing: 'border-box', border: `4px solid ${c.fg}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <span style={{ width: rec ? 26 : 52, height: rec ? 26 : 52, borderRadius: rec ? 7 : 26, background: RED, transition: 'width .2s, height .2s, border-radius .2s' }} />
            </button>
            <span style={{ minWidth: 90 }} />
          </Glass>
        )}
      </main>

      <Sheet open={memoOpen} onClose={() => setMemoOpen(false)} title={t('dic.memo_title')}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <Field value={memoText} onChange={setMemoText} label={t('dic.memo_ph')} placeholder={t('dic.memo_ph')} maxLength={2000} />
          <Button onClick={() => void saveMemo()} disabled={memoText.trim() === ''}>{t('dic.memo_save')}</Button>
        </div>
      </Sheet>
      {error && <button type="button" role="alert" onClick={() => setError('')} style={{ ...BTN, position: 'absolute', left: '50%', bottom: 140, transform: 'translateX(-50%)', padding: '10px 18px', borderRadius: 18, background: RED, color: '#fff', fontSize: 15, fontWeight: 600 }}>{error}</button>}
    </div>
  );
}
