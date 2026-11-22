// Contrôle du build (ui-01) : point d'entrée JS <= 380 Ko, total JS <= 2 Mo (applis chargées à la demande),
// `node --check` sur chaque fichier JS, aucune URL externe.
import { execFileSync } from 'node:child_process';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const dist = resolve(dirname(fileURLToPath(import.meta.url)), '../../../resources/[pop]/pop_tablet/web/dist');
const MAX_ENTRY = 380 * 1024;
const MAX_TOTAL = 2 * 1024 * 1024;
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
const entrySrc = html.match(/<script[^>]*\ssrc="([^"]+\.js)"/)?.[1];
if (!entrySrc) { console.error('Point d\'entrée JS introuvable dans index.html'); process.exit(1); }
const entry = statSync(join(dist, entrySrc.replace(/^\.?\//, ''))).size;
console.log(`dist : ${files.length} fichiers, ${js.length} JS, entrée ${(entry / 1024).toFixed(1)} Ko, total ${(total / 1024).toFixed(1)} Ko de JS, node --check OK, URL externes dans index.html : ${external.length}`);
if (entry > MAX_ENTRY || total > MAX_TOTAL || external.length) { console.error('Taille ou URL externe hors limite'); process.exit(1); }
