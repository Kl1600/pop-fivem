import { afterEach, describe, expect, it } from 'vitest';
import { currentToken, onNuiMessage, withToken } from './bridge';

const post = (data: unknown) => window.dispatchEvent(new MessageEvent('message', { data }));

describe('jeton de session NUI', () => {
  afterEach(() => post({ action: 'tablet:close', data: {} }));

  it('joint le jeton aux appels, sauf ready et locale', () => {
    expect(withToken('tablet:call', { name: 'notes:list' }, 'abc')).toEqual({ name: 'notes:list', token: 'abc' });
    expect(withToken('tablet:close', undefined, 'abc')).toEqual({ token: 'abc' });
    expect(withToken('tablet:ready', {}, 'abc')).toEqual({});
    expect(withToken('tablet:locale', { lang: 'fr' }, 'abc')).toEqual({ lang: 'fr' });
  });
  it('sans jeton (fermée), la charge reste intacte', () => {
    expect(withToken('tablet:call', { a: 1 }, null)).toEqual({ a: 1 });
  });
  it('lit le jeton dans tablet:open et ne le transmet à personne', () => {
    let seen: unknown;
    const off = onNuiMessage((_a, d) => { seen = d; });
    post({ action: 'tablet:open', data: { serial: 'PT-X', token: 'secret123' } });
    off();
    expect(currentToken()).toBe('secret123');
    expect(seen).toEqual({ serial: 'PT-X' });
  });
  it('oublie le jeton à la fermeture', () => {
    const off = onNuiMessage(() => undefined);
    post({ action: 'tablet:open', data: { token: 't1' } });
    post({ action: 'tablet:close', data: {} });
    off();
    expect(currentToken()).toBeNull();
  });
});
