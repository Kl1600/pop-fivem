import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { describe, expect, it } from 'vitest';
import { LANGUAGES, RTL_LANGS, TABLES, makeT, missingKeys, type Lang } from './index';

const en = TABLES.en;
const KEYS = Object.keys(en);
const ph = (s: string) => (s.match(/%[sd]/g) ?? []).join('');
const pipes = (s: string) => (s.match(/\|/g) ?? []).length;

describe('i18n : les 10 langues ont toutes les clés', () => {
  it('10 langues déclarées, une table chacune', () => {
    expect(LANGUAGES.length).toBe(10);
    for (const l of LANGUAGES) expect(Object.keys(TABLES[l]).length).toBeGreaterThan(0);
  });

  for (const lang of LANGUAGES as readonly Lang[]) {
    it(`${lang} : aucune clé manquante ni en trop`, () => {
      expect(missingKeys(lang)).toEqual([]);
      const extra = Object.keys(TABLES[lang]).filter((k) => en[k] === undefined);
      expect(extra).toEqual([]);
    });

    it(`${lang} : textes non vides, mêmes %s/%d et mêmes séparateurs que l'anglais`, () => {
      const bad: string[] = [];
      for (const k of KEYS) {
        const v = TABLES[lang][k];
        if (typeof v !== 'string' || v.trim() === '') bad.push(`${k}: vide`);
        else if (ph(v) !== ph(en[k]!)) bad.push(`${k}: paramètres`);
        else if (pipes(v) !== pipes(en[k]!)) bad.push(`${k}: séparateurs`);
      }
      expect(bad).toEqual([]);
    });
  }

  for (const lang of LANGUAGES.filter((l) => l !== 'en' && l !== 'fr') as readonly Lang[]) {
    it(`${lang} : vraie traduction (moins de 25 % de textes identiques à l'anglais)`, () => {
      const same = KEYS.filter((k) => TABLES[lang][k] === en[k]).length;
      expect(same / KEYS.length).toBeLessThan(0.25);
    });
  }

  it('makeT utilise la langue demandée puis retombe sur l\'anglais', () => {
    expect(makeT('de')('app.mail')).toBe(TABLES.de['app.mail']);
    expect(makeT('de')('cle.inconnue')).toBe('cle.inconnue');
    expect(makeT('ar')('sto.count', 3)).toContain('3');
  });
});

describe('i18n : arabe (RTL)', () => {
  it('seul l\'arabe est de droite à gauche', () => {
    expect([...RTL_LANGS]).toEqual(['ar']);
  });

  it('le texte arabe contient bien de l\'arabe', () => {
    const arabic = KEYS.filter((k) => /[؀-ۿ]/.test(TABLES.ar[k]!)).length;
    expect(arabic / KEYS.length).toBeGreaterThan(0.9);
  });

  it('aucune bordure, marge ou alignement physique gauche/droite dans les composants (sauf calculette)', () => {
    const src = join(__dirname, '..');
    const hits: string[] = [];
    const walk = (dir: string) => {
      for (const name of readdirSync(dir)) {
        const p = join(dir, name);
        if (statSync(p).isDirectory()) walk(p);
        else if (/\.tsx$/.test(name) && !/\.test\.tsx$/.test(name)) {
          readFileSync(p, 'utf8').split('\n').forEach((line, i) => {
            if (/\b(borderLeft|borderRight|paddingRight)\b|textAlign: '(left|right)'/.test(line)) hits.push(`${relative(src, p)}:${i + 1}`);
            // paddingLeft : seule la touche 0 de la calculette (clavier toujours de gauche à droite)
            if (/\bpaddingLeft\b/.test(line) && !p.includes('calculette')) hits.push(`${relative(src, p)}:${i + 1}`);
          });
        }
      }
    };
    for (const d of ['apps', 'system', 'device', 'kit']) walk(join(src, d));
    expect(hits).toEqual([]);
  });
});
