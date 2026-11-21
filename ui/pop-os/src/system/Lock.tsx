import { useEffect, useState } from 'react';
import { AppIcon, Glass, useT } from '../kit';
import { LANGUAGES, LANGUAGE_NAMES } from '../i18n';
import { formatDate, formatTime, useGameDate } from './clock';
import { cancelCode, setLanguage, submitCode, submitSetup } from './actions';
import { os, useOS } from './store';
import { relTime } from './format';
import { Field, Button } from '../kit';

// Écran verrouillé, saisie du code et premier allumage. Positions de la maquette Main.dc.html (référence 1348 x 1019).

export function LockLayer({ active, toCode }: { active: boolean; toCode: boolean }) {
  const t = useT();
  const lang = useOS((s) => s.lang);
  const weather = useOS((s) => s.weather);
  const battery = useOS((s) => s.battery);
  const boot = useOS((s) => s.boot);
  const notifs = useOS((s) => s.notifs);
  const d = useGameDate();
  const events = boot?.widgets?.events ?? [];
  const next = events[0];
  return (
    <div className="tr" data-layer="lock" style={{ position: 'absolute', inset: 0, opacity: active ? 1 : 0, transform: active ? 'none' : toCode ? 'translateY(-40px)' : 'translateY(-100%)', pointerEvents: active ? 'auto' : 'none' }}>
      <div style={{ position: 'absolute', insetInlineStart: 70, top: 90, display: 'flex', flexDirection: 'column' }}>
        <span style={{ fontSize: 28, fontWeight: 600, opacity: 0.92 }}>{formatDate(d, lang, 'long')}</span>
        <span dir="ltr" style={{ fontSize: 172, fontWeight: 700, lineHeight: 0.95, letterSpacing: -6, color: 'rgba(255,255,255,.88)', textShadow: '0 2px 0 rgba(255,255,255,.25), 0 8px 40px rgba(0,0,0,.18)' }}>{formatTime(d)}</span>
        <div style={{ display: 'flex', gap: 14, marginTop: 26 }}>
          <Glass kind="gw" style={{ width: 168, height: 76, borderRadius: 22, padding: '12px 16px', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
            <span style={{ fontSize: 13, fontWeight: 600, opacity: 0.8 }}>{weather?.city ?? t('widget.city')}</span>
            <span style={{ fontSize: 24, fontWeight: 600 }}>{weather ? `${Math.round(weather.temp)}° · ${t(`weather.${weather.kind}`)}` : '–'}</span>
          </Glass>
          <Glass kind="gw" style={{ width: 168, height: 76, borderRadius: 22, padding: '12px 16px', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
            <span style={{ fontSize: 13, fontWeight: 600, opacity: 0.8 }}>{next ? next.time.split(' ')[0] : t('widget.calendar')}</span>
            <span style={{ fontSize: 18, fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{next ? next.title : t('widget.no_event')}</span>
          </Glass>
          <Glass kind="gw" style={{ width: 76, height: 76, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 15, fontWeight: 700 }}>
            <span dir="ltr">{Math.round(battery)} %</span>
          </Glass>
        </div>
      </div>
      <div style={{ position: 'absolute', insetInlineEnd: 70, top: 420, width: 460, display: 'flex', flexDirection: 'column', gap: 10 }}>
        {notifs.slice(0, 2).map((n) => (
          <Glass key={n.id} kind="gw" style={{ borderRadius: 26, padding: '14px 16px', display: 'flex', gap: 12, alignItems: 'center' }}>
            <AppIcon appId={n.app} size={38} />
            <span style={{ display: 'flex', flexDirection: 'column', flexGrow: 1, minWidth: 0 }}>
              <span style={{ display: 'flex', justifyContent: 'space-between', fontSize: 15, fontWeight: 600 }}><span>{n.title}</span><span style={{ fontWeight: 400, opacity: 0.7, fontSize: 13 }}>{relTime(n.at, Date.now(), t)}</span></span>
              <span style={{ fontSize: 15, opacity: 0.92 }}>{n.body}</span>
            </span>
          </Glass>
        ))}
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 40, textAlign: 'center', fontSize: 16, fontWeight: 500, opacity: 0.85 }}>{t('lock.swipe')}</div>
    </div>
  );
}

const KEYS: Array<[string, string]> = [['1', ''], ['2', 'ABC'], ['3', 'DEF'], ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'], ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'], ['', ''], ['0', ''], ['', '']];

/** Pavé numérique et points de saisie, partagés par le déverrouillage et le premier allumage. */
export function Keypad({ code, onDigit, onDelete, shake, disabled }: { code: string; onDigit: (d: string) => void; onDelete: () => void; shake: boolean; disabled: boolean }) {
  // Les chiffres du clavier physique fonctionnent aussi : l'écouteur n'existe que pendant la saisie.
  useEffect(() => {
    if (disabled) return;
    const h = (e: KeyboardEvent) => {
      if (/^[0-9]$/.test(e.key)) onDigit(e.key);
      else if (e.key === 'Backspace') onDelete();
    };
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, [disabled, onDigit, onDelete]);
  return (
    <>
      <div className={shake ? 'shake' : ''} data-testid="dots" style={{ display: 'flex', gap: 22, margin: '26px 0 50px' }}>
        {[0, 1, 2, 3].map((i) => (
          <span key={i} data-filled={i < code.length ? '1' : '0'} style={{ width: 15, height: 15, borderRadius: '50%', border: '1.5px solid #fff', background: i < code.length ? '#fff' : 'transparent' }} />
        ))}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 84px)', gap: '22px 30px' }}>
        {KEYS.map(([d, l], i) =>
          d ? (
            <button key={i} aria-label={d} className="gw key" onClick={() => !disabled && onDigit(d)} style={{ width: 84, height: 84, borderRadius: '50%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', background: 'rgba(255,255,255,.16)', border: '1px solid rgba(255,255,255,.22)' }}>
              <span style={{ fontSize: 36, fontWeight: 400, lineHeight: 1 }}>{d}</span>
              <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: 2, opacity: 0.9 }}>{l}</span>
            </button>
          ) : (
            <span key={i} />
          ),
        )}
      </div>
    </>
  );
}

export function CodeLayer({ active }: { active: boolean }) {
  const t = useT();
  const err = useOS((s) => s.codeError);
  const wait = useOS((s) => s.lockWait);
  const [code, setCode] = useState('');
  const [shake, setShake] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => { if (!active) { setCode(''); setShake(false); } }, [active]);
  // Compte à rebours du blocage : une seconde à la fois, seulement tant que le blocage dure.
  useEffect(() => {
    if (wait <= 0) return;
    const id = setTimeout(() => os.set({ lockWait: wait - 1 }), 1000);
    return () => clearTimeout(id);
  }, [wait]);

  const blocked = wait > 0;
  const onDigit = (d: string) => {
    if (shake || busy || blocked || !active) return;
    const next = (code + d).slice(0, 4);
    setCode(next);
    if (next.length === 4) {
      setBusy(true);
      void submitCode(next).then((res) => {
        setBusy(false);
        if (!res.ok) {
          setShake(true);
          setTimeout(() => { setShake(false); setCode(''); }, 600);
        }
      });
    }
  };
  const onDelete = () => { if (!busy) setCode((c) => c.slice(0, -1)); };
  const message = blocked ? t('code.wait', wait) : err ? (err === 'err_code_blocked' ? t('code.wait', wait) : t(err === 'err_code_wrong' ? 'code.wrong' : err)) : t('code.enter');
  return (
    <div className="tr" data-layer="code" style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 150, opacity: active ? 1 : 0, pointerEvents: active ? 'auto' : 'none' }}>
      <span role="status" style={{ fontSize: 22, fontWeight: 500 }}>{message}</span>
      <Keypad code={code} onDigit={onDigit} onDelete={onDelete} shake={shake} disabled={!active || blocked} />
      <div style={{ position: 'absolute', bottom: 44, insetInlineEnd: 60, display: 'flex', gap: 30, fontSize: 17 }}>
        <button onClick={onDelete}>{t('code.delete')}</button>
        <button onClick={cancelCode}>{t('code.cancel')}</button>
      </div>
    </div>
  );
}

type Step = 'lang' | 'code' | 'confirm' | 'name' | 'mail';
const STEPS: Step[] = ['lang', 'code', 'confirm', 'name', 'mail'];

/** Premier allumage : langue, code, nom de l'appareil, adresse mail. Le serveur valide tout. */
export function SetupLayer({ active }: { active: boolean }) {
  const t = useT();
  const lang = useOS((s) => s.lang);
  const [step, setStep] = useState<Step>('lang');
  const [code, setCode] = useState('');
  const [first, setFirst] = useState('');
  const [name, setName] = useState('POP Tab');
  const [mail, setMail] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [shake, setShake] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => { if (!active) { setStep('lang'); setCode(''); setFirst(''); setError(null); } }, [active]);

  const onDigit = (d: string) => {
    if (shake || (step !== 'code' && step !== 'confirm')) return;
    const next = (code + d).slice(0, 4);
    setCode(next);
    if (next.length < 4) return;
    if (step === 'code') {
      setFirst(next);
      setTimeout(() => { setCode(''); setStep('confirm'); }, 180);
    } else if (next === first) {
      setError(null);
      setTimeout(() => setStep('name'), 180);
    } else {
      setError('setup.mismatch');
      setShake(true);
      setTimeout(() => { setShake(false); setCode(''); setFirst(''); setStep('code'); }, 600);
    }
  };
  const finish = async () => {
    setBusy(true);
    const res = await submitSetup({ code: first, name: name.trim(), lang, mail: mail.trim() });
    setBusy(false);
    if (!res.ok) setError(res.err ?? 'err_unavailable');
  };
  const idx = STEPS.indexOf(step);
  const title = { lang: 'setup.lang', code: 'setup.code', confirm: 'setup.confirm', name: 'setup.name', mail: 'setup.mail' }[step];
  return (
    <div className="tr" data-layer="setup" style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 120, opacity: active ? 1 : 0, pointerEvents: active ? 'auto' : 'none' }}>
      <span style={{ fontSize: 40, fontWeight: 700 }}>{t('setup.hello')}</span>
      <span role="status" style={{ fontSize: 22, fontWeight: 500, marginTop: 10 }}>{t(title)}</span>
      {step === 'lang' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 220px)', gap: 12, marginTop: 30 }}>
          {LANGUAGES.map((l) => (
            <Glass key={l} kind="gw" as="button" onClick={() => void setLanguage(l)} style={{ height: 52, borderRadius: 18, fontSize: 18, fontWeight: lang === l ? 700 : 500, outline: lang === l ? '2px solid #fff' : 'none' }}>
              {LANGUAGE_NAMES[l]}
            </Glass>
          ))}
        </div>
      )}
      {(step === 'code' || step === 'confirm') && <Keypad code={code} onDigit={onDigit} onDelete={() => setCode((c) => c.slice(0, -1))} shake={shake} disabled={!active || shake} />}
      {step === 'name' && (
        <div style={{ width: 420, marginTop: 30, color: '#000' }}><Field value={name} onChange={setName} label={t('setup.name')} maxLength={32} onEnter={() => name.trim() && setStep('mail')} /></div>
      )}
      {step === 'mail' && (
        <div style={{ width: 420, marginTop: 30, color: '#000' }}><Field value={mail} onChange={setMail} label={t('setup.mail')} placeholder={t('setup.mail_hint')} type="email" inputMode="email" onEnter={() => void finish()} /></div>
      )}
      {error && <span role="alert" style={{ marginTop: 18, fontSize: 16, fontWeight: 600 }}>{error === 'setup.mismatch' ? t('setup.mismatch') : t(error)}</span>}
      <div style={{ display: 'flex', gap: 14, marginTop: 34 }}>
        {idx > 0 && step !== 'name' && step !== 'mail' ? <Button kind="plain" onClick={() => { setCode(''); setStep(STEPS[Math.max(0, idx - (step === 'confirm' ? 2 : 1))] as Step); }} style={{ color: '#fff' }}>{t('setup.back')}</Button> : null}
        {step === 'lang' && <Button onClick={() => setStep('code')}>{t('setup.next')}</Button>}
        {step === 'name' && <Button disabled={!name.trim()} onClick={() => setStep('mail')}>{t('setup.next')}</Button>}
        {step === 'mail' && <Button disabled={busy || !mail.trim()} onClick={() => void finish()}>{t('setup.finish')}</Button>}
      </div>
    </div>
  );
}
