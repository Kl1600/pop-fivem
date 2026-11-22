// Calculette : logique pure (maquette Calculette.dc.html). Aucune donnée, aucun appel serveur.
export interface Hist { e: string; r: string }
interface Frame { acc: number | null; op: string | null }
export interface Calc {
  cur: string;
  acc: number | null;
  op: string | null;
  fresh: boolean;
  lastOp: boolean;
  closed: boolean;
  stack: Frame[];
  expr: string;
  deg: boolean;
  hist: Hist[];
}

export const ERR = 'Erreur';
const OPS = ['+', '−', '×', '÷', '^'];

export function initial(): Calc {
  return { cur: '0', acc: null, op: null, fresh: true, lastOp: false, closed: false, stack: [], expr: '', deg: true, hist: [] };
}

/** Affichage : espaces entre milliers, virgule décimale. */
export function fmt(v: string): string {
  if (v === ERR) return v;
  if (v.includes('e')) return v.replace('.', ',');
  const neg = v.startsWith('-');
  const parts = (neg ? v.slice(1) : v).split('.');
  const ip = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  return (neg ? '-' : '') + ip + (parts.length > 1 ? ',' + parts[1] : '');
}

const str = (v: number): string => (Number.isFinite(v) ? String(parseFloat(v.toPrecision(12))) : ERR);
const apply = (a: number, o: string | null, b: number): number =>
  o === '+' ? a + b : o === '−' ? a - b : o === '×' ? a * b : o === '÷' ? (b === 0 ? NaN : a / b) : o === '^' ? Math.pow(a, b) : b;

/** Taille de police de l'affichage selon sa longueur. */
export function fontSize(display: string): number {
  const n = display.length;
  return n <= 7 ? 112 : n <= 10 ? 90 : n <= 13 ? 70 : 54;
}

const pushHist = (h: Hist[], e: string, r: string): Hist[] => [{ e, r }, ...h].slice(0, 30);

/** Reprend un résultat de l'historique comme valeur courante. */
export function pickHist(s: Calc, h: Hist): Calc {
  return { ...s, cur: h.r.replace(/ /g, '').replace(',', '.'), fresh: true, lastOp: false, closed: false };
}

export function clearHist(s: Calc): Calc {
  return { ...s, hist: [] };
}

/** 1/x : erreur si la valeur est nulle. */
function inverse(s: Calc): Calc {
  const v = parseFloat(s.cur);
  const r = v === 0 || Number.isNaN(v) ? ERR : String(parseFloat((1 / v).toPrecision(12)));
  return { ...s, cur: r, fresh: true, lastOp: false, hist: pushHist(s.hist, `1/(${fmt(String(v))})`, fmt(r)) };
}

/** Applique une touche. Touches : chiffres, '.', 'AC', 'neg', '%', opérateurs, '(', ')', '=', 'deg', 'pi', 'e', 'inv' et fonctions. */
export function press(s: Calc, k: string): Calc {
  if (s.cur === ERR && k !== 'AC') return s;
  if (k === 'inv') return inverse(s);
  let { cur, acc, op, fresh, lastOp, closed, deg } = s;
  const stack = s.stack.slice();
  let { expr, hist } = s;
  const num = (v: string) => parseFloat(v);
  if (/^\d$/.test(k)) {
    if (fresh) { cur = k; fresh = false; lastOp = false; closed = false; }
    else if (cur === '0') cur = k;
    else if (cur.replace(/[-.]/g, '').length < 12) cur += k;
  } else if (k === '.') {
    if (fresh) { cur = '0.'; fresh = false; lastOp = false; closed = false; }
    else if (!cur.includes('.')) cur += '.';
  } else if (k === 'AC') {
    if (cur !== '0' && !fresh) { cur = '0'; fresh = false; }
    else { cur = '0'; acc = null; op = null; fresh = true; lastOp = false; closed = false; stack.length = 0; expr = ''; }
  } else if (k === 'neg') {
    cur = cur.startsWith('-') ? cur.slice(1) : cur === '0' ? '0' : '-' + cur;
  } else if (k === '%') {
    cur = str(num(cur) / 100); fresh = true;
  } else if (OPS.includes(k)) {
    if (lastOp) { expr = expr.slice(0, -3) + ' ' + k + ' '; op = k; }
    else {
      const v = num(cur);
      acc = op && acc !== null ? apply(acc, op, v) : v;
      expr += (closed ? '' : fmt(cur)) + ' ' + k + ' ';
      lastOp = true; closed = false; op = k; cur = str(acc); fresh = true;
    }
  } else if (k === '(') {
    stack.push({ acc, op }); acc = null; op = null; expr += '('; cur = '0'; fresh = true; lastOp = false; closed = false;
  } else if (k === ')') {
    if (!stack.length) return s;
    const v = op && acc !== null ? apply(acc, op, num(cur)) : num(cur);
    expr += (closed || lastOp ? '' : fmt(cur)) + ')';
    const fr = stack.pop() as Frame;
    acc = fr.acc; op = fr.op; cur = str(v); fresh = true; closed = true; lastOp = false;
  } else if (k === '=') {
    let v = num(cur);
    let e = expr + (closed ? '' : fmt(cur));
    while (stack.length) { v = op && acc !== null ? apply(acc, op, v) : v; const fr = stack.pop() as Frame; acc = fr.acc; op = fr.op; e += ')'; }
    if (op && acc !== null) {
      const res = str(apply(acc, op, v));
      if (res !== ERR) hist = pushHist(hist, e, fmt(res));
      cur = res; acc = null; op = null; expr = ''; fresh = true; lastOp = false; closed = false;
    }
  } else if (k === 'deg') {
    deg = !deg;
  } else if (k === 'pi') {
    cur = str(Math.PI); fresh = true; lastOp = false;
  } else if (k === 'e') {
    cur = str(Math.E); fresh = true; lastOp = false;
  } else {
    const v = num(cur);
    const r = deg ? Math.PI / 180 : 1;
    let res = NaN;
    let label = '';
    if (k === 'sin') { res = Math.sin(v * r); label = 'sin'; }
    else if (k === 'cos') { res = Math.cos(v * r); label = 'cos'; }
    else if (k === 'tan') { res = Math.tan(v * r); label = 'tan'; }
    else if (k === 'sq') { res = v * v; label = 'sqr'; }
    else if (k === 'sqrt') { res = v < 0 ? NaN : Math.sqrt(v); label = '√'; }
    else if (k === 'ln') { res = v <= 0 ? NaN : Math.log(v); label = 'ln'; }
    else if (k === 'log') { res = v <= 0 ? NaN : Math.log10(v); label = 'log'; }
    else if (k === 'fact') { res = v >= 0 && v <= 20 && Math.floor(v) === v ? 1 : NaN; for (let i = 2; i <= v && !Number.isNaN(res); i++) res *= i; label = 'fact'; }
    else return s;
    const out = Math.abs(res) < 1e-12 ? 0 : res;
    cur = str(out); fresh = true; lastOp = false;
    if (cur !== ERR) hist = pushHist(hist, `${label}(${fmt(String(v))})`, fmt(cur));
  }
  return { cur, acc, op, fresh, lastOp, closed, stack, expr, deg, hist };
}
