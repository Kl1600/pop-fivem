/**
 * Imite ce que le vrai serveur envoie : une réponse Lua passe par msgpack puis JSON.
 * - une clé à `nil` disparaît (la simulation écrit `null`, le serveur n'envoie rien : `undefined` côté UI) ;
 * - une table vide devient `[]`, y compris quand le code attendait un objet.
 * Un tableau garde ses éléments (un `null` y reste, comme un trou rempli par FiveM).
 */
export function luaJson<T>(value: T): T {
  return walk(value) as T;
}

function walk(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(walk);
  if (v !== null && typeof v === 'object') {
    const out: Record<string, unknown> = {};
    for (const [k, x] of Object.entries(v as Record<string, unknown>)) {
      if (x !== null && x !== undefined) out[k] = walk(x);
    }
    return Object.keys(out).length === 0 ? [] : out;
  }
  return v;
}
