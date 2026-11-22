// Contrôle du build (ui-01) : taille JS totale <= 450 Ko, `node --check` sur chaque fichier JS, aucune URL externe.
import { execFileSync } from 'node:child_process';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const dist = resolve(dirname(fileURLToPath(import.meta.url)), '../../../resources/[pop]/pop_tablet/web/dist');
const MAX = 450 * 1024;
const walk = (d) => readdirSync(d).flatMap((n) => (statSync(join(d, n)).isDirectory() ? walk(join(d, n)) : [join(d, n)]));
const files = walk(dist);
const js = files.filter((f) => f.endsWith('.js'));
let total = 0;
for (const f of js) {
  total += statSync(f).size;
  execFileSync(process.execPath, ['--check', f], { stdio: 'pipe' });
}
const html = readFileSync(join(dist, 'index.html'), 'utf8');
const external = html.match(/(?:src|href)="https?:\/\/[^"]+"/g) ?? [];
console.log(`dist : ${files.length} fichiers, ${js.length} JS, ${(total / 1024).toFixed(1)} Ko de JS, node --check OK, URL externes dans index.html : ${external.length}`);
if (total > MAX || external.length) { console.error('Taille ou URL externe hors limite'); process.exit(1); }
