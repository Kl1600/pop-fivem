import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { player } from '../kit';
import { mockOpen, resetMock } from '../nui/mock';
import { navState } from '../nui/mock-nav';
import { addressOf, resolve } from '../apps/navigateur/sites';
import { closeTablet, handleMessage, openApp, submitCode } from './actions';
import { Host } from './Tablet';

const game = [{ domain: 'annuaire.pop', title: 'Annuaire', page: 'nui://pop_annuaire/web/index.html' }];
const hosts = ['exemple.fr'];

async function unlock() {
  render(<Host />);
  act(() => handleMessage('open', mockOpen()));
  await act(async () => { await submitCode('1234'); });
}

beforeEach(() => {
  resetMock(); closeTablet();
  vi.spyOn(window.HTMLMediaElement.prototype, 'play').mockImplementation(() => Promise.resolve());
  vi.spyOn(window.HTMLMediaElement.prototype, 'pause').mockImplementation(() => undefined);
});
afterEach(() => { cleanup(); player.stop(); closeTablet(); vi.restoreAllMocks(); });

describe('app-nav : résolution des adresses', () => {
  it('sites de la maquette, sites en jeu, hôtes autorisés, hôte refusé, introuvable', () => {
    expect(resolve('', game, hosts)).toEqual({ k: 'home' });
    expect(resolve('weazelnews.com', game, hosts)).toEqual({ k: 'site', key: 'weazel' });
    expect(resolve('https://www.weazelnews.com', game, hosts)).toEqual({ k: 'blocked', host: 'www.weazelnews.com' });
    expect(resolve('pop://annuaire.pop', game, hosts)).toEqual({ k: 'game', domain: 'annuaire.pop' });
    expect(resolve('https://exemple.fr/page', game, hosts)).toEqual({ k: 'ext', url: 'https://exemple.fr/page', host: 'exemple.fr' });
    expect(resolve('https://pirate.example/x', game, hosts)).toEqual({ k: 'blocked', host: 'pirate.example' });
    expect(resolve('javascript://x', game, hosts).k).toBe('blocked');
    expect(resolve('zzzzzz', game, hosts)).toEqual({ k: 'miss', text: 'zzzzzz' });
    expect(addressOf({ k: 'game', domain: 'annuaire.pop' }, game)).toBe('pop://annuaire.pop');
  });
});

describe('app-nav Navigateur', () => {
  it('onglets, site en jeu, signet et historique enregistrés', async () => {
    await unlock();
    act(() => openApp('navigateur'));
    await waitFor(() => expect(screen.getByLabelText('Weazel News')).toBeTruthy());
    fireEvent.click(screen.getByLabelText('Weazel News'));
    expect(screen.getByRole('article', { name: 'Weazel News' })).toBeTruthy();
    fireEvent.click(screen.getByLabelText('Ajouter un signet'));
    fireEvent.click(screen.getByLabelText('Nouvel onglet'));
    fireEvent.click(await screen.findByLabelText('Annuaire'));
    const frame = document.querySelector('iframe')!;
    expect(frame.getAttribute('sandbox')).toBe('allow-scripts');
    expect(frame.getAttribute('src')).toBe('nui://pop_annuaire/web/index.html');
    const bar = screen.getByLabelText('Adresse') as HTMLInputElement;
    fireEvent.change(bar, { target: { value: 'https://pirate.example/x' } });
    fireEvent.keyDown(bar, { key: 'Enter' });
    expect(screen.getByText('Site non autorisé')).toBeTruthy();
    fireEvent.click(screen.getByLabelText('Onglets'));
    const dlg = screen.getByRole('dialog');
    expect(within(dlg).getAllByLabelText('Fermer l\'onglet').length).toBe(2);
    await waitFor(() => expect(navState().bookmarks.map((m) => m.url)).toEqual(['weazelnews.com']), { timeout: 3000 });
    expect(navState().history.some((h) => h.url === 'pop://annuaire.pop')).toBe(true);
  });
});

describe('app-mus Musique', () => {
  it('stations, lecture, favori, liste, suivant, lecteur plein écran, volume', async () => {
    await unlock();
    act(() => openApp('musique'));
    await waitFor(() => expect(screen.getByLabelText('Groove Salad')).toBeTruthy());
    fireEvent.click(screen.getByLabelText('Groove Salad'));
    expect(player.get().track?.title).toBe('Groove Salad');
    expect(player.get().queue.length).toBe(3);
    fireEvent.click(screen.getAllByLabelText('Ajouter aux favoris')[0]!);
    await waitFor(() => expect(navState().favs).toEqual(['s1']));
    fireEvent.click(screen.getByLabelText('Suivant'));
    expect(player.get().track?.title).toBe('Secret Agent');
    await waitFor(() => expect((navState().state as { title: string }).title).toBe('Secret Agent'));
    fireEvent.click(screen.getByRole('tab', { name: 'Listes' }));
    fireEvent.click(screen.getByText('Nouvelle liste'));
    fireEvent.change(await screen.findByLabelText('Nom de la liste'), { target: { value: 'Route' } });
    fireEvent.click(screen.getByText('Créer'));
    await waitFor(() => expect(navState().playlists.map((p) => p.name)).toEqual(['Route']));
    fireEvent.click(screen.getByLabelText('Ouvrir le lecteur'));
    expect(screen.getByRole('dialog', { name: 'Lecteur' })).toBeTruthy();
    player.setVolume(30);
    expect(player.volume()).toBe(30);
    expect(document.querySelector('audio')).toBeNull(); // l'élément audio n'est pas dans le DOM : il vit dans le module
  });

  it('le lecteur continue quand l\'appli est fermée', async () => {
    await unlock();
    player.play({ id: 's1', title: 'Groove Salad', artist: 'CHILL', url: 'https://flux.exemple.fr/groove.mp3' });
    act(() => openApp('musique'));
    closeTablet();
    expect(player.get().track?.id).toBe('s1');
  });
});
