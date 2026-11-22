// Nom de l'adresse mail (partie avant @), miroir de `mailAddress` dans server/device.lua :
// 3 à 32 caractères, a-z 0-9 . _ -, début et fin alphanumériques, pas de deux points de suite.
// Le serveur reste la source de vérité ; ce miroir sert à montrer l'erreur avant l'envoi.

export const MAIL_LOCAL_MIN = 3;
export const MAIL_LOCAL_MAX = 32; // Tablet.Max.mailLocal

/** Ne garde que la partie avant le premier « @ » (le domaine est affiché à côté, non éditable). */
export function mailLocalPart(input: string): string {
  const at = input.indexOf('@');
  return at < 0 ? input : input.slice(0, at);
}

/** Vrai si le nom est accepté par le serveur (casse ignorée, le serveur met en minuscules). */
export function isValidMailLocal(input: string): boolean {
  const v = input.trim().toLowerCase();
  if (v.length < MAIL_LOCAL_MIN || v.length > MAIL_LOCAL_MAX) return false;
  return /^[a-z0-9][a-z0-9._-]*[a-z0-9]$/.test(v) && !v.includes('..');
}
