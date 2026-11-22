import { act, cleanup, render } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mockOpen, resetMock } from '../nui/mock';
import { nuiApi } from '../nui/bridge';
import { closeTablet, handleMessage, openApp, showCode, submitCode } from './actions';
import { os } from './store';
import { Host } from './Tablet';

// Reproduit les défauts vus en jeu : écran déverrouillé sans réponse du serveur, serveur reverrouillé sous un accueil affiché,
// accueil visible derrière l'Appareil photo.

const w = window as unknown as { GetParentResourceName?: () => string };
type Reply = { ok: boolean; err?: string; boot?: unknown };

function inGame(reply: (name: string) => Reply) {
  w.GetParentResourceName = () => 'pop_tablet';
  vi.stubGlobal('fetch', vi.fn(async (_url: string, init?: { body?: string }) => {
    const body = JSON.parse(init?.body ?? '{}') as { name?: string };
    return { json: async () => reply(body.name ?? '') };
  }));
}

beforeEach(() => { resetMock(); closeTablet(); });
afterEach(() => { cleanup(); closeTablet(); vi.unstubAllGlobals(); vi.restoreAllMocks(); delete w.GetParentResourceName; });

describe('verrouillage : l’interface suit le serveur', () => {
  it('un mauvais code reste sur l’écran de code et affiche l’erreur du serveur', async () => {
    inGame(() => ({ ok: false, err: 'err_code_wrong' }));
    render(<Host />);
    act(() => handleMessage('open', mockOpen({ needSetup: false })));
    act(() => showCode());
    const res = await submitCode('0000');
    expect(res.ok).toBe(false);
    expect(os.get().screen).toBe('code');
    expect(os.get().codeError).toBe('err_code_wrong');
  });

  it('le bon code (réponse ok + boot) ouvre l’accueil', async () => {
    inGame((n) => (n === 'device:unlock' ? { ok: true, boot: mockOpen().boot } : { ok: false }));
    render(<Host />);
    act(() => handleMessage('open', mockOpen({ needSetup: false })));
    act(() => showCode());
    expect((await submitCode('1234')).ok).toBe(true);
    expect(os.get().screen).toBe('home');
  });

  it('ouverture : session encore déverrouillée côté serveur (locked:false + boot) = accueil, sinon écran verrouillé', () => {
    render(<Host />);
    act(() => handleMessage('open', { ...mockOpen({ needSetup: false }), locked: false }));
    expect(os.get().screen).toBe('home');
    act(() => closeTablet());
    act(() => handleMessage('open', { ...mockOpen({ needSetup: false }), locked: true }));
    expect(os.get().screen).toBe('lock');
  });

  it('err_locked renvoyé par le serveur à un appel d’appli : retour à l’écran du code', async () => {
    inGame(() => ({ ok: false, err: 'err_locked' }));
    render(<Host />);
    act(() => handleMessage('open', { ...mockOpen({ needSetup: false }), locked: false }));
    act(() => openApp('horloge'));
    expect(os.get().screen).toBe('home');
    const r = await nuiApi.call('clock:list');
    expect(r.err).toBe('err_locked');
    expect(os.get().screen).toBe('code');
    expect(os.get().app).toBeNull();
  });
});

describe('Appareil photo : l’accueil ne reste pas derrière l’image du jeu', () => {
  it('appli caméra ouverte : accueil et écrans de verrouillage cachés, coque transparente', () => {
    render(<Host />);
    act(() => handleMessage('open', { ...mockOpen({ needSetup: false, shell: true }), locked: false }));
    const home = () => document.querySelector('[data-layer="home"]') as HTMLElement;
    expect(home().style.visibility).toBe('visible');
    act(() => openApp('camera'));
    expect(home().style.visibility).toBe('hidden');
    expect(document.querySelector('[data-camera-hide]')?.getAttribute('style')).toContain('visibility: hidden');
    expect(document.querySelector('[data-shell]')?.getAttribute('data-clear')).toBe('1');
    act(() => os.set({ app: null }));
    expect(home().style.visibility).toBe('visible');
    expect(document.querySelector('[data-shell]')?.getAttribute('data-clear')).toBeNull();
  });
});
