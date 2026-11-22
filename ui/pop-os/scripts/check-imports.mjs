// Contrôle d'architecture (ui-02) : sens des importations entre device/, system/, kit/, apps/.
//  - apps/ n'importe que kit/ (et ses propres fichiers) : jamais device/, system/, nui/, i18n/.
//  - kit/ n'importe ni device/, ni system/, ni apps/, ni nui/.
//  - device/ n'importe ni apps/ ni system/.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
export const SRC = resolve(here, '../src');

const FORBIDDEN = {
  apps: ['device', 'system', 'nui', 'i18n'],
  kit: ['device', 'system', 'apps', 'nui'],
  device: ['apps', 'system'],
};

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else if (/\.(ts|tsx)$/.test(name)) out.push(p);
  }
  return out;
}

/** Renvoie la liste des violations « fichier -> importation ». */
export function checkImports(src = SRC) {
  const bad = [];
  for (const file of walk(src)) {
    const rel = relative(src, file).split(sep);
    const zone = rel[0];
    const banned = FORBIDDEN[zone];
    if (!banned) continue;
    const text = readFileSync(file, 'utf8');
    for (const m of text.matchAll(/(?:from|import)\s*\(?\s*['"](\.[^'"]*)['"]/g)) {
      const target = relative(src, resolve(dirname(file), m[1])).split(sep)[0];
      if (banned.includes(target)) bad.push(`${rel.join('/')} -> ${m[1]}`);
    }
  }
  return bad;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const bad = checkImports();
  if (bad.length) { console.error('Importations interdites :\n' + bad.join('\n')); process.exit(1); }
  console.log('check-imports : OK');
}
