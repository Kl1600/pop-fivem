import type { TFn } from '../kit';
import en from './en';
import fr from './fr';
import es from './es';
import de from './de';
import it from './it';
import pt from './pt';
import nl from './nl';
import pl from './pl';
import tr from './tr';
import ar from './ar';

export type Table = Record<string, string>;

/** Les 10 langues de la SPEC. fr et en sont complètes ; les 8 autres retombent sur l'anglais clé par clé. */
import { LANGUAGES, LANGUAGE_NAMES } from '../kit';
export { LANGUAGES, LANGUAGE_NAMES };
export type Lang = (typeof LANGUAGES)[number];

export const TABLES: Record<Lang, Table> = { en, fr, es, de, it, pt, nl, pl, tr, ar };


export const RTL_LANGS: ReadonlySet<string> = new Set(['ar']);

export function isLang(v: unknown): v is Lang {
  return typeof v === 'string' && (LANGUAGES as readonly string[]).includes(v);
}

/**
 * Fabrique `t(clé, ...args)`.
 * Ordre : table de l'interface dans la langue, textes envoyés par le client (client/locale.lua), anglais, clé brute.
 * `%s` et `%d` sont remplacés dans l'ordre.
 */
export function makeT(lang: string, server: Record<string, unknown> = {}): TFn {
  const own = isLang(lang) ? TABLES[lang] : en;
  return (key, ...args) => {
    let text: string | undefined = own[key];
    if (text === undefined) {
      const s = server[key];
      if (typeof s === 'string') text = s;
    }
    if (text === undefined) text = en[key];
    if (text === undefined) return key;
    let i = 0;
    return text.replace(/%[sd]/g, (m) => (i < args.length ? String(args[i++]) : m));
  };
}

/** Clés présentes en anglais mais absentes d'une langue (aide au suivi des traductions). */
export function missingKeys(lang: Lang): string[] {
  return Object.keys(en).filter((k) => TABLES[lang][k] === undefined);
}

export function localeTag(lang: string): string {
  return isLang(lang) ? lang : 'en';
}
