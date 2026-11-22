import { useState } from 'react';
import { Glass, type AppProps } from '../../kit';
import { ERR, clearHist, fmt, fontSize, initial, pickHist, press, type Calc } from './model';

const BTN = { all: 'unset', cursor: 'pointer' } as const;

function colors(dark: boolean) {
  return dark
    ? { bg: '#000000', fg: '#ffffff', sub: 'rgba(235,235,245,.6)', sep: 'rgba(84,84,88,.6)', num: '#333333', numFg: '#ffffff', fn: '#a5a5a5', fnFg: '#000000', op: '#ff9f0a', opOn: '#ffffff', sci: '#1f1f21' }
    : { bg: '#f2f2f7', fg: '#000000', sub: 'rgba(60,60,67,.6)', sep: 'rgba(60,60,67,.18)', num: '#ffffff', numFg: '#000000', fn: '#d4d4d9', fnFg: '#000000', op: '#ff9500', opOn: '#ffffff', sci: '#e3e3e8' };
}

type Kind = 'fn' | 'op' | 'num';
const STD: Array<[string, string, Kind]> = [
  ['AC', 'C', 'fn'], ['neg', '±', 'fn'], ['%', '%', 'fn'], ['÷', '÷', 'op'], ['7', '7', 'num'], ['8', '8', 'num'], ['9', '9', 'num'], ['×', '×', 'op'],
  ['4', '4', 'num'], ['5', '5', 'num'], ['6', '6', 'num'], ['−', '−', 'op'], ['1', '1', 'num'], ['2', '2', 'num'], ['3', '3', 'num'], ['+', '+', 'op'],
  ['0', '0', 'num'], ['.', ',', 'num'], ['=', '=', 'op'],
];
const SCI: Array<[string, string]> = [
  ['(', '('], [')', ')'], ['inv', '1/x'], ['sin', 'sin'], ['cos', 'cos'], ['tan', 'tan'], ['sq', 'x²'], ['sqrt', '√'], ['^', 'xʸ'], ['ln', 'ln'], ['log', 'log'], ['e', 'e'], ['pi', 'π'], ['deg', ''], ['fact', 'x!'],
];

export default function App({ t, dark, layout }: AppProps) {
  const c = colors(dark);
  const [s, setS] = useState<Calc>(initial);
  const [sci, setSci] = useState(layout === 'regular');
  const [showHist, setShowHist] = useState(layout === 'regular');
  const display = fmt(s.cur);
  const clr = s.cur !== '0' && !s.fresh ? 'C' : 'AC';
  const pend = (k: string) => s.op === k && s.lastOp;
  const key = (k: string) => () => setS((x) => press(x, k));
  return (
    <div style={{ width: '100%', height: '100%', display: 'flex', background: c.bg, color: c.fg, overflow: 'hidden', position: 'relative', letterSpacing: '-0.01em' }}>
      {showHist && layout === 'regular' ? (
        <nav aria-label={t('calc.history')} style={{ width: 320, flexShrink: 0, height: '100%', boxSizing: 'border-box', background: c.bg, borderRight: `1px solid ${c.sep}`, padding: '46px 18px 20px', display: 'flex', flexDirection: 'column' }}>
          <span style={{ fontSize: 34, fontWeight: 700, padding: '0 6px 14px' }}>{t('calc.history')}</span>
          <div style={{ flexGrow: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column' }}>
            {s.hist.map((h, i) => (
              <button type="button" key={i} onClick={() => setS((x) => pickHist(x, h))} style={{ ...BTN, display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 2, padding: '12px 8px', borderBottom: `1px solid ${c.sep}` }}>
                <span style={{ fontSize: 15, color: c.sub }}>{h.e}</span>
                <span style={{ fontSize: 30, fontWeight: 300, fontVariantNumeric: 'tabular-nums' }}>{h.r}</span>
              </button>
            ))}
            {s.hist.length === 0 ? <span style={{ display: 'block', textAlign: 'center', padding: '60px 10px', color: c.sub, fontSize: 16 }}>{t('calc.none')}</span> : null}
          </div>
          <button type="button" onClick={() => setS(clearHist)} style={{ ...BTN, textAlign: 'center', padding: 12, fontSize: 17, color: '#ff383c' }}>{t('calc.clear_history')}</button>
        </nav>
      ) : null}
      <main style={{ flexGrow: 1, minWidth: 0, height: '100%', position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div style={{ position: 'absolute', left: 22, right: 22, top: 26, display: 'flex', justifyContent: 'space-between' }}>
          <Glass as="button" aria-label={t('calc.show_history')} onClick={() => setShowHist((v) => !v)} style={{ ...BTN, width: 46, height: 46, borderRadius: 23, display: 'flex', alignItems: 'center', justifyContent: 'center', color: c.fg }}>
            <svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 5h16v14H4zM9 5v14" /></svg>
          </Glass>
          <Glass as="button" onClick={() => setSci((v) => !v)} style={{ ...BTN, height: 46, padding: '0 20px', borderRadius: 23, display: 'flex', alignItems: 'center', fontSize: 16, fontWeight: 600, color: sci ? '#ff9500' : c.fg }}>{t('calc.scientific')}</Glass>
        </div>
        <div style={{ width: sci ? 814 : 442, maxWidth: '100%', marginTop: 108, display: 'flex', flexDirection: 'column', alignItems: 'flex-end', justifyContent: 'flex-end', height: 200 }}>
          <span style={{ fontSize: 24, color: c.sub, height: 34, whiteSpace: 'nowrap', overflow: 'hidden', maxWidth: '100%' }}>{s.expr}</span>
          <span data-testid="calc-display" style={{ fontSize: fontSize(display), fontWeight: 300, lineHeight: 1.1, fontVariantNumeric: 'tabular-nums', whiteSpace: 'nowrap' }}>{display === ERR ? t('calc.error') : display}</span>
        </div>
        <div style={{ display: 'flex', gap: 44, marginTop: 26 }}>
          {sci ? (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 100px)', gridAutoRows: '100px', gap: 14 }}>
              {SCI.map(([k, label]) => {
                const text = k === 'deg' ? (s.deg ? t('calc.deg') : t('calc.rad')) : label;
                return (
                  <button type="button" key={k} aria-label={text} onClick={key(k)} style={{ ...BTN, width: 100, height: 100, borderRadius: 50, background: pend(k) ? c.opOn : c.sci, color: pend(k) ? c.op : c.fg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 26, fontWeight: 500 }}>{text}</button>
                );
              })}
            </div>
          ) : null}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 100px)', gridAutoRows: '100px', gap: 14 }}>
            {STD.map(([k, label, kind]) => {
              const on = kind === 'op' && pend(k);
              const zero = k === '0';
              return (
                <button type="button" key={k} aria-label={k === 'AC' ? clr : label} onClick={key(k)} style={{ ...BTN, gridColumn: zero ? 'span 2' : 'auto', height: 100, borderRadius: 50, boxSizing: 'border-box', background: kind === 'op' ? (on ? c.opOn : c.op) : kind === 'fn' ? c.fn : c.num, color: kind === 'op' ? (on ? c.op : '#ffffff') : kind === 'fn' ? c.fnFg : c.numFg, display: 'flex', alignItems: 'center', justifyContent: zero ? 'flex-start' : 'center', paddingLeft: zero ? 38 : 0, fontSize: 40, fontWeight: 400 }}>{k === 'AC' ? clr : label}</button>
              );
            })}
          </div>
        </div>
      </main>
    </div>
  );
}
