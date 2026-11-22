import { useEffect, useState } from 'react';
import { Button, Field, palette, useDark, useT } from '../../kit';
import { finishSetup, previewSetup, setLanguage, submitSetup } from '../actions';
import { useOS } from '../store';
import { Keypad } from '../Lock';
import { isValidMailLocal, mailLocalPart } from '../mailLocal';
import { MailField } from './MailField';
import { Aurora, HelloStep, LanguageStep, LookStep, StepFrame, WallStep, WelcomeStep } from './steps';
import './setup.css';

// Premier allumage, une étape par écran : Bonjour, langue, apparence, code (saisie puis confirmation), nom, adresse mail,
// fond d'écran, bienvenue. Tout est envoyé en une fois à `device:setup` à la fin du fond d'écran ; le serveur valide tout.

type Step = 'hello' | 'lang' | 'look' | 'code' | 'confirm' | 'name' | 'mail' | 'wall' | 'welcome';

/** Étape précédente (le retour depuis le nom repasse par la saisie du code, la confirmation étant déjà faite). */
const BACK: Partial<Record<Step, Step>> = { lang: 'hello', look: 'lang', code: 'look', confirm: 'code', name: 'code', mail: 'name', wall: 'mail' };
/** Pastille de progression : une marque par écran de choix (le code et sa confirmation comptent pour une). */
const DOTS: Step[] = ['lang', 'look', 'code', 'name', 'mail', 'wall'];

function Progress({ step }: { step: Step }) {
  const t = useT();
  const c = palette(useDark());
  const at = DOTS.indexOf(step === 'confirm' ? 'code' : step);
  if (at < 0) return null;
  return (
    <div role="img" aria-label={t('setup.step', at + 1, DOTS.length)} style={{ position: 'absolute', insetInline: 0, top: 34, display: 'flex', justifyContent: 'center', pointerEvents: 'none' }}>
      <span style={{ display: 'flex', gap: 8, padding: '8px 12px', borderRadius: 12, background: c.fill }}>
        {DOTS.map((d, i) => <span key={d} style={{ width: i === at ? 18 : 7, height: 7, borderRadius: 4, background: i === at ? 'var(--accent)' : c.sub, opacity: i <= at ? 1 : 0.45, transition: 'width .25s ease' }} />)}
      </span>
    </div>
  );
}

export function SetupLayer({ active }: { active: boolean }) {
  const t = useT();
  const c = palette(useDark());
  const lang = useOS((s) => s.lang);
  const domain = useOS((s) => s.mailDomain);
  const dark = useOS((s) => s.settings.dark === true);
  const [step, setStep] = useState<Step>('hello');
  const [code, setCode] = useState('');
  const [first, setFirst] = useState('');
  const [name, setName] = useState('POP Tab');
  const [mail, setMail] = useState('');
  const [wall, setWall] = useState('auto');
  const [error, setError] = useState<string | null>(null);
  const [shake, setShake] = useState(false);
  const [busy, setBusy] = useState(false);
  const [boot, setBoot] = useState<Parameters<typeof finishSetup>[0]>(undefined);

  useEffect(() => { if (!active) { setStep('hello'); setCode(''); setFirst(''); setError(null); setBoot(undefined); } }, [active]);

  const go = (to: Step) => { setError(null); setCode(''); setStep(to); };
  const back = () => { const to = BACK[step]; if (to) { if (to === 'code') setFirst(''); go(to); } };

  const onDigit = (d: string) => {
    if (shake || (step !== 'code' && step !== 'confirm')) return;
    const next = (code + d).slice(0, 4);
    setCode(next);
    if (next.length < 4) return;
    if (step === 'code') {
      setFirst(next);
      setTimeout(() => go('confirm'), 180);
    } else if (next === first) {
      setError(null);
      setTimeout(() => go('name'), 180);
    } else {
      setError('setup.mismatch');
      setShake(true);
      setTimeout(() => { setShake(false); setCode(''); setFirst(''); setStep('code'); }, 600);
    }
  };

  const toWall = () => {
    // Même règle que le serveur : l'erreur s'affiche avant de quitter l'écran.
    if (!isValidMailLocal(mail)) { setError('setup.mail_rules'); return; }
    go('wall');
  };
  const finish = async () => {
    setBusy(true);
    const res = await submitSetup({ code: first, name: name.trim(), lang, mail: mail.trim(), dark, wall });
    setBusy(false);
    if (res.ok) { setBoot(res.boot); go('welcome'); return; }
    const err = res.err ?? 'err_unavailable';
    // L'erreur s'affiche sur l'écran qui contient le champ fautif.
    if (err === 'err_mail_invalid' || err === 'err_mail_taken') { go('mail'); setError(err === 'err_mail_invalid' ? 'setup.mail_rules' : err); }
    else if (err === 'err_name_invalid') { go('name'); setError(err); }
    else if (err === 'err_code_format') { setFirst(''); go('code'); setError(err); }
    else setError(err);
  };

  const errorText = error ? (error === 'setup.mail_rules' ? t(error, domain) : t(error)) : null;
  const hello = step === 'hello';
  const welcome = step === 'welcome';
  const pad = step === 'code' || step === 'confirm';
  return (
    <div className="tr" data-layer="setup" data-step={step} aria-hidden={!active} inert={!active} style={{ position: 'absolute', inset: 0, zIndex: 7, background: hello ? '#050509' : c.bg, color: hello ? '#fff' : c.fg, opacity: active ? 1 : 0, pointerEvents: active ? 'auto' : 'none' }}>
      {(hello || welcome) && <Aurora />}
      {hello && <HelloStep lang={lang} active={active} onNext={() => setStep((s) => (s === 'hello' ? 'lang' : s))} />}
      {step === 'lang' && <LanguageStep lang={lang} onPick={(l) => void setLanguage(l)} />}
      {step === 'look' && <LookStep dark={dark} onPick={(d) => previewSetup({ dark: d })} />}
      {pad && (
        <StepFrame title={t(step === 'code' ? 'setup.code' : 'setup.confirm')}>
          <Keypad code={code} onDigit={onDigit} onDelete={() => setCode((v) => v.slice(0, -1))} shake={shake} disabled={!active || shake} tone={dark ? 'dark' : 'light'} />
        </StepFrame>
      )}
      {step === 'name' && (
        <StepFrame title={t('setup.name')} hint={t('setup.name_hint')}>
          <Field value={name} onChange={setName} label={t('setup.name')} maxLength={32} onEnter={() => name.trim() && go('mail')} />
        </StepFrame>
      )}
      {step === 'mail' && (
        <StepFrame title={t('setup.mail')}>
          <div style={{ width: '100%' }}><MailField value={mail} onChange={(v) => { setMail(mailLocalPart(v)); setError(null); }} label={t('setup.mail')} placeholder={t('setup.mail_ph')} domain={domain} onEnter={toWall} /></div>
        </StepFrame>
      )}
      {step === 'wall' && <WallStep wall={wall} dark={dark} onPick={setWall} />}
      {welcome && <WelcomeStep onStart={() => finishSetup(boot, name.trim())} />}

      {errorText && !welcome && <span role="alert" style={{ position: 'absolute', insetInline: 0, bottom: 150, textAlign: 'center', fontSize: 17, fontWeight: 600, color: '#ff453a', padding: '0 120px' }}>{errorText}</span>}
      {!hello && !welcome && <Progress step={step} />}
      {!hello && !welcome && (
        <Button kind="plain" aria-label={t('setup.back')} onClick={back} style={{ position: 'absolute', insetInlineStart: 26, top: 24, padding: '8px 10px', fontSize: 19 }}>
          <svg className="ps-chev" aria-hidden="true" width="12" height="20" viewBox="0 0 12 20" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round"><path d="M10 2L2 10l8 8" /></svg>
          <span style={{ marginInlineStart: 6 }}>{t('setup.back')}</span>
        </Button>
      )}
      {!hello && !welcome && !pad && (
        <div style={{ position: 'absolute', insetInline: 0, bottom: 64, display: 'flex', justifyContent: 'center' }}>
          {step === 'name' && <Button disabled={!name.trim()} onClick={() => go('mail')} style={{ width: 420, height: 56, borderRadius: 28, fontSize: 19 }}>{t('setup.next')}</Button>}
          {step === 'mail' && <Button disabled={!mail.trim()} onClick={toWall} style={{ width: 420, height: 56, borderRadius: 28, fontSize: 19 }}>{t('setup.next')}</Button>}
          {step === 'wall' && <Button disabled={busy} onClick={() => void finish()} style={{ width: 420, height: 56, borderRadius: 28, fontSize: 19 }}>{t('setup.next')}</Button>}
          {(step === 'lang' || step === 'look') && <Button onClick={() => go(step === 'lang' ? 'look' : 'code')} style={{ width: 420, height: 56, borderRadius: 28, fontSize: 19 }}>{t('setup.next')}</Button>}
        </div>
      )}
    </div>
  );
}
