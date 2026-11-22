import { act, cleanup, render, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mockOpen, resetMock } from '../nui/mock';
import { nuiApi } from '../nui/bridge';
import { closeTablet, handleMessage, openApp, power, showCode, submitCode } from './actions';
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

describe("verrouillage : le serveur d'abord", () => {
  it("bouton d'allumage : device:lock appelé, écran verrouillé seulement après la réponse", async () => {
    let release: (v: Reply) => void = () => {};
    const seen: string[] = [];
    w.GetParentResourceName = () => 'pop_tablet';
    vi.stubGlobal('fetch', vi.fn(async (_u: string, init?: { body?: string }) => {
      const body = JSON.parse(init?.body ?? '{}') as { name?: string };
      seen.push(body.name ?? '');
      if (body.name !== 'device:lock') return { json: async () => ({ ok: true }) };
      return { json: () => new Promise<Reply>((r) => { release = r; }) };
    }));
    render(<Host />);
    act(() => handleMessage('open', { ...mockOpen({ needSetup: false }), locked: false }));
    expect(os.get().screen).toBe('home');
    act(() => power());
    expect(seen).toContain('device:lock');
    expect(os.get().screen).toBe('home');
    await act(async () => { await Promise.resolve(); });
    expect(os.get().screen).toBe('home');
    await act(async () => { release({ ok: true }); });
    await waitFor(() => expect(os.get().screen).toBe('lock'));
    expect(os.get().on).toBe(false);
  });
  it("si le serveur ne verrouille pas, l'écran de code n'est pas affiché", async () => {
    inGame(() => ({ ok: false, err: 'err_timeout' }));
    render(<Host />);
    act(() => handleMessage('open', { ...mockOpen({ needSetup: false }), locked: false }));
    await act(async () => { power(); });
    expect(os.get().screen).toBe('home');
  });
});

describe('Appareil photo : l’accueil ne reste pas derrière l’image du jeu', () => {
  it('appli caméra ouverte : accueil et verrouillage cachés, coque et barre d’état restées visibles, écran évidé', async () => {
    render(<Host />);
    act(() => handleMessage('open', { ...mockOpen({ needSetup: false, shell: true }), locked: false }));
    const home = () => document.querySelector('[data-layer="home"]') as HTMLElement;
    expect(home().style.visibility).toBe('visible');
    act(() => openApp('camera'));
    expect(home().style.visibility).toBe('hidden');
    expect(document.querySelector('[data-camera-hide]')?.getAttribute('style')).toContain('visibility: hidden');
    const shell = document.querySelector('[data-shell]') as HTMLElement;
    expect(shell.getAttribute('data-clear')).toBe('1');
    expect(shell.style.visibility).not.toBe('hidden');
    expect(Array.from(shell.querySelectorAll<HTMLElement>('div')).filter((d) => (d.getAttribute('style') ?? '').includes('transparent')).length).toBeGreaterThanOrEqual(2);
    await waitFor(() => expect(document.querySelector('[data-camera-controls]')).not.toBeNull());
    expect(document.querySelector('[data-viewfinder]')).not.toBeNull();
    expect(document.body.textContent).toMatch(/\d+\s?%/);
    act(() => os.set({ app: null }));
    expect(home().style.visibility).toBe('visible');
    expect(document.querySelector('[data-shell]')?.getAttribute('data-clear')).toBeNull();
  });
});

describe('Appareil photo : orientation libre (Alt)', () => {
  it('Alt envoie look_mode, le repère change, et le jeu peut y mettre fin', async () => {
    const posts: Array<{ name?: string; action?: string; on?: boolean }> = [];
    w.GetParentResourceName = () => 'pop_tablet';
    vi.stubGlobal('fetch', vi.fn(async (_u: string, init?: { body?: string }) => {
      const body = JSON.parse(init?.body ?? '{}') as { action?: string; on?: boolean };
      posts.push({ name: _u.split('/').pop(), action: body.action, on: body.on });
      return { json: async () => ({ ok: true }) };
    }));
    render(<Host />);
    act(() => handleMessage('open', { ...mockOpen({ needSetup: false }), locked: false }));
    act(() => openApp('camera'));
    await waitFor(() => expect(document.querySelector('[data-look-hint]')).not.toBeNull());
    expect(document.querySelector('[data-look-hint]')?.textContent).toBe('Alt : orienter');
    await act(async () => { window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Alt' })); });
    expect(posts.some((p) => p.action === 'look_mode' && p.on === true)).toBe(true);
    await waitFor(() => expect(document.querySelector('[data-look-hint]')?.textContent).toBe('Alt : terminer'));
    act(() => handleMessage('cameraLook', { on: false }));
    expect(document.querySelector('[data-look-hint]')?.textContent).toBe('Alt : orienter');
  });
});
