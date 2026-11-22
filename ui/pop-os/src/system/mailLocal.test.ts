import { describe, expect, it } from 'vitest';
import { isValidMailLocal, mailLocalPart } from './mailLocal';

describe('nom de l\'adresse mail', () => {
  it('garde la partie avant @', () => {
    expect(mailLocalPart('Silvun@silvun.com')).toBe('Silvun');
    expect(mailLocalPart('alex')).toBe('alex');
    expect(mailLocalPart('@pop.ls')).toBe('');
    expect(mailLocalPart('a@b@c')).toBe('a');
  });
  it('accepte les noms valides, casse ignorée', () => {
    for (const v of ['Silvun', 'alex.martin', 'a-b_c', 'abc', 'a1', 'x'.repeat(32)].filter((x) => x.length >= 3)) expect(isValidMailLocal(v)).toBe(true);
  });
  it('refuse les noms invalides comme le serveur', () => {
    for (const v of ['', 'ab', 'x'.repeat(33), '.abc', 'abc.', '-abc', 'a..b', 'a b c', 'é-tude', 'a@b']) expect(isValidMailLocal(v)).toBe(false);
  });
});
