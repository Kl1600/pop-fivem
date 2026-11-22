import { ORDER, PHRASES, WORDS, norm, type DictLang, type Row } from './dict';

export { ORDER };
export type { DictLang };
export type Mode = 'text' | 'conv' | 'fav';

export type Kind = 'empty' | 'same' | 'phrase' | 'words' | 'none';
export interface Result {
  kind: Kind;
  text: string;
  /** Mots du texte absents du dictionnaire (conservés tels quels dans la traduction mot à mot). */
  unknown: number;
}

const isLang = (l: string): l is DictLang => (ORDER as readonly string[]).includes(l);

const phraseIndex = new Map<DictLang, Map<string, Row>>();
const wordIndex = new Map<DictLang, Map<string, Row>>();

function index(rows: Row[], lang: DictLang, store: Map<DictLang, Map<string, Row>>): Map<string, Row> {
  let m = store.get(lang);
  if (!m) {
    m = new Map();
    for (const r of rows) { const k = norm(r[lang]); if (k && !m.has(k)) m.set(k, r); }
    store.set(lang, m);
  }
  return m;
}

/**
 * Traduction hors ligne : phrase connue d'abord (comparaison sans accents ni ponctuation), sinon mot à mot.
 * `none` : aucun mot connu (l'interface propose alors le service, s'il y en a un, ou des suggestions).
 */
export function translate(text: string, src: string, dst: string): Result {
  if (!text.trim()) return { kind: 'empty', text: '', unknown: 0 };
  if (src === dst) return { kind: 'same', text, unknown: 0 };
  if (!isLang(src) || !isLang(dst)) return { kind: 'none', text: '', unknown: 0 };
  const n = norm(text);
  const phrase = index(PHRASES, src, phraseIndex).get(n);
  if (phrase) return { kind: 'phrase', text: phrase[dst], unknown: 0 };
  const words = index(WORDS, src, wordIndex);
  const tokens = n.split(' ').filter(Boolean);
  let known = 0;
  // Les mots composés (« tout droit », « au revoir ») passent avant les mots simples : on essaie 3, 2 puis 1 mot.
  const out: string[] = [];
  for (let i = 0; i < tokens.length;) {
    let hit: Row | undefined;
    let len = 0;
    for (const take of [3, 2, 1]) {
      if (i + take > tokens.length) continue;
      hit = words.get(tokens.slice(i, i + take).join(' '));
      if (hit) { len = take; break; }
    }
    if (hit) { out.push(hit[dst]); known += len; i += len; } else { out.push(tokens[i]!); i += 1; }
  }
  if (known === 0) return { kind: 'none', text: '', unknown: tokens.length };
  return { kind: 'words', text: out.join(' '), unknown: tokens.length - known };
}

/** Phrases de la langue source qui contiennent le texte tapé (2 caractères au moins), sans l'égaler. */
export function suggest(text: string, src: string, max = 3): string[] {
  const n = norm(text);
  if (n.length < 2 || !isLang(src)) return [];
  return PHRASES.filter((p) => { const k = norm(p[src]); return k.includes(n) && k !== n; }).slice(0, max).map((p) => p[src]);
}

export interface Fav { src: string; dst: string; s: string; t: string }
export const sameFav = (a: Fav, b: Fav): boolean => a.src === b.src && a.dst === b.dst && a.s === b.s;

export interface Bubble { side: 'a' | 'b'; src: string; dst: string; text: string; out: string; ok: boolean }

export function bubble(side: 'a' | 'b', src: string, dst: string, text: string): Bubble {
  const r = translate(text, src, dst);
  return { side, src, dst, text, out: r.text, ok: r.kind === 'phrase' || r.kind === 'words' || r.kind === 'same' };
}

export const dirOf = (lang: string): 'rtl' | 'ltr' => (lang === 'ar' ? 'rtl' : 'ltr');
