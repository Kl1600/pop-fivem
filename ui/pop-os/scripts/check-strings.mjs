// Contrôle i18n (ui-04) : aucune chaîne visible en dur dans les composants (system/, device/, kit/, apps/).
// Cherche du texte JSX contenant des lettres, et les attributs aria-label / placeholder / title / alt en littéral.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
export const SRC = resolve(here, '../src');
const ZONES = ['system', 'device', 'kit', 'apps'];

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.tsx$/.test(name) && !/\.test\.tsx$/.test(name)) out.push(p);
  }
  return out;
}

export function findLiterals(text) {
  const hits = [];
  const code = text.replace(/\{\/\*[\s\S]*?\*\/\}/g, '');
  for (const m of code.matchAll(/>([^<>{}=;]*[\p{L}]{2,}[^<>{}]*)</gu)) {
    const s = m[1].trim();
    if (s && !/^&#?\w+;$/.test(s) && !/^(=>|&&|\|\|)/.test(s) && !/ \? |\?\s*\(| : |&&|[()]\s*=>|\bconst\b|\breturn\b|<\w/.test(s)) hits.push(s);
  }
  for (const m of code.matchAll(/\b(?:aria-label|placeholder|title|alt)="([^"{}]*[\p{L}]{2,}[^"{}]*)"/gu)) hits.push(m[1]);
  return hits;
}

export function checkStrings(src = SRC) {
  const bad = [];
  for (const zone of ZONES) {
    let files = [];
    try { files = walk(join(src, zone)); } catch { continue; }
    for (const f of files) for (const h of findLiterals(readFileSync(f, 'utf8'))) bad.push(`${relative(src, f)} : « ${h} »`);
  }
  return bad;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const bad = checkStrings();
  if (bad.length) { console.error('Chaînes visibles en dur :\n' + bad.join('\n')); process.exit(1); }
  console.log('check-strings : OK');
}
