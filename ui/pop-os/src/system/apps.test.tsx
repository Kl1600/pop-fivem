import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { getApp } from '../apps/registry';
import { parseCall } from '../apps/api';
import { groupByCategory } from '../apps/boutique';
import { maskSerial } from '../apps/reglages';
import { makeT } from '../i18n';
import { mockOpen, resetMock } from '../nui/mock';
import { closeTablet, handleMessage, networkOff, openApp, pushNotify, refreshApps, submitCode } from './actions';
import { bootPatch, os } from './store';
import { Host } from './Tablet';

async function unlock(settings: Record<string, unknown> = {}) {
  const data = mockOpen();
  if (data.boot) data.boot = { ...data.boot, settings: { ...data.boot.settings, ...settings } };
  act(() => handleMessage('open', data));
  await act(async () => { await submitCode('1234'); });
  // submitCode applique le démarrage simulé : les réglages demandés sont posés après.
  if (Object.keys(settings).length) act(() => os.set({ settings: { ...os.get().settings, ...settings } }));
}

beforeEach(() => { resetMock(); closeTablet(); });
afterEach(() => { cleanup(); closeTablet(); vi.restoreAllMocks(); });

describe('app-set Réglages', () => {
  it('toutes les rubriques ont une fonction : navigation, recherche, nom masqué du numéro de série', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('reglages'));
    expect(await screen.findByRole('button', { name: /Notifications/ })).toBeTruthy();
    for (const name of ['Mode avion', 'Wi-Fi', 'Bluetooth', 'Batterie', 'Sons', 'Concentration', 'Général', 'Centre de contrôle', 'Luminosité et affichage', 'Accessibilité', "Fond d'écran", 'Confidentialité et sécurité', 'Code', 'Boutique']) {
      expect(screen.getAllByText(name).length, name).toBeGreaterThan(0);
    }
    fireEvent.change(screen.getByLabelText('Rechercher'), { target: { value: 'wi-fi' } });
    expect(screen.queryByText('Sons')).toBeNull();
    expect(maskSerial('PT-ABCDEFGH23')).toBe('PT-••••••GH23');
  });

  it('notifications par appli : le réglage `notif` complet est envoyé et appliqué', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('reglages'));
    fireEvent.click(await screen.findByRole('button', { name: /Notifications/ }));
    fireEvent.click(await screen.findByRole('switch', { name: 'Notifications Messages' }));
    expect(os.get().settings.notif).toEqual({ messages: false });
    pushNotify({ app: 'messages', title: 'x', text: 'y' });
    expect(os.get().notifs.length).toBe(0);
    pushNotify({ app: 'mail', title: 'x', text: 'y' });
    expect(os.get().notifs.length).toBe(1);
  });

  it('langue, transparence du verre, luminosité, nom, informations', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('reglages'));
    fireEvent.click(await screen.findByRole('button', { name: /Général/ }));
    expect(await screen.findByText('POP OS', { exact: false })).toBeTruthy();
    const field = screen.getByLabelText('Nom') as HTMLInputElement;
    fireEvent.change(field, { target: { value: 'Tablette de Bob' } });
    fireEvent.click(screen.getByRole('button', { name: 'Renommer' }));
    await waitFor(() => expect(os.get().name).toBe('Tablette de Bob'));
    act(() => os.set({ settings: { ...os.get().settings, glass: 10 } }));
    expect(os.get().settings.glass).toBe(10);
  });

  it('sons : volume et sonnerie sont enregistrés comme réglages', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('reglages'));
    fireEvent.click(await screen.findByRole('button', { name: /Sons/ }));
    fireEvent.click(await screen.findByText('Radar'));
    expect(os.get().settings.ring).toBe(5);
  });

  it('accessibilité : texte en gras appliqué à la tablette', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('reglages'));
    fireEvent.click(await screen.findByRole('button', { name: /Accessibilité/ }));
    fireEvent.click(await screen.findByRole('switch', { name: 'Texte en gras' }));
    expect(document.querySelector('.pop')?.getAttribute('data-bold')).toBe('on');
  });
});

describe('app-sto Boutique', () => {
  it('catalogue, installation d’une appli de métier, retrait, appli système non retirable', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('boutique'));
    fireEvent.click(await screen.findByRole('button', { name: 'Obtenir Police MDT' }));
    await waitFor(() => expect(os.get().apps).toContain('police_mdt'));
    expect(getApp('police_mdt')?.domain).toBe('api');
    expect(makeT('fr')('api.police_mdt')).toBe('Police MDT');
    fireEvent.click(screen.getByRole('button', { name: 'Retirer Police MDT' }));
    await waitFor(() => expect(os.get().apps).not.toContain('police_mdt'));
    const sys = screen.getByRole('button', { name: 'Installée Réglages' }) as HTMLButtonElement;
    expect(sys.disabled).toBe(true);
  });

  it('groupement par catégorie', () => {
    const g = groupByCategory([{ id: 'a', cat: 'tools', installed: true }, { id: 'b', cat: 'media', installed: false }, { id: 'c', cat: 'tools', installed: true }]);
    expect(g.map((x) => [x.cat, x.items.length])).toEqual([['tools', 2], ['media', 1]]);
  });

  it('arb-01 : Mode Avion et Wi-Fi coupé remplacent Boutique, Messages, Téléphone, Mail, Navigateur', async () => {
    render(<Host />);
    await unlock({ air: true });
    expect(networkOff()).toBe(true);
    act(() => openApp('boutique'));
    expect(await screen.findByText('Pas de connexion')).toBeTruthy();
    act(() => { os.set({ settings: { ...os.get().settings, air: false, wifi: false } }); });
    expect(networkOff()).toBe(true);
    for (const id of ['messages', 'telephone', 'mail', 'navigateur']) {
      act(() => openApp(id));
      expect(document.querySelector(`[data-offline="${id}"]`), id).not.toBeNull();
    }
    act(() => { os.set({ settings: { ...os.get().settings, wifi: true } }); });
    expect(networkOff()).toBe(false);
  });
});

describe('api : applis d’autres ressources', () => {
  it('boot.apiApps enregistre l’appli, son nom et son cadre isolé (sandbox allow-scripts seul)', async () => {
    render(<Host />);
    await unlock();
    const boot = { ...os.get().boot!, apps: [...os.get().boot!.apps, 'police_mdt'], apiApps: [{ id: 'police_mdt', api: true as const, name: 'MDT Police', page: 'nui://pop_police/web/mdt.html', installed: true }] };
    act(() => os.set(bootPatch(boot)));
    act(() => openApp('police_mdt'));
    const frame = await waitFor(() => {
      const f = document.querySelector('[data-api-app="police_mdt"] iframe');
      if (!f) throw new Error('cadre absent');
      return f as HTMLIFrameElement;
    });
    expect(frame.getAttribute('sandbox')).toBe('allow-scripts');
    expect(frame.getAttribute('src')).toBe('nui://pop_police/web/mdt.html');
    expect(makeT('fr')('api.police_mdt')).toBe('MDT Police');
  });

  it('pop-app:call : seuls les appels bien formés de la bonne appli sont relayés', () => {
    expect(parseCall({ type: 'pop-app:call', appId: 'a_b', action: 'search', data: { q: 'x' }, id: 1 }, 'a_b')).toEqual({ action: 'search', data: { q: 'x' }, id: 1 });
    expect(parseCall({ type: 'pop-app:call', appId: 'autre', action: 'x', id: 1 }, 'a_b')).toBeNull();
    expect(parseCall({ type: 'autre', appId: 'a_b', action: 'x', id: 1 }, 'a_b')).toBeNull();
    expect(parseCall({ type: 'pop-app:call', appId: 'a_b', action: 'a b', id: 1 }, 'a_b')).toBeNull();
    expect(parseCall({ type: 'pop-app:call', appId: 'a_b', action: 'x', id: 'z' }, 'a_b')).toBeNull();
    expect(parseCall({ type: 'pop-app:call', appId: 'a_b', action: 'x', id: 1, data: 'y'.repeat(5000) }, 'a_b')).toBeNull();
  });

  it('tablet:apps : le catalogue est relu quand une ressource démarre ou s’arrête', async () => {
    render(<Host />);
    await unlock();
    await act(async () => { await refreshApps(); });
    expect(os.get().apps).not.toContain('police_mdt');
    expect(os.get().apps).toContain('reglages');
  });

  it('notification d’une appli API : titre fourni par le serveur', async () => {
    render(<Host />);
    await unlock();
    pushNotify({ app: 'police_mdt', title: 'Alerte', text: 'Vol' });
    expect(os.get().notifs[0]).toMatchObject({ title: 'Alerte', body: 'Vol' });
  });
});
