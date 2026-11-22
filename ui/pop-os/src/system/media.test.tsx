import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { nextTimer } from '../apps/camera/model';
import { childCount, moveTargets, pathTo, viewOf, type FileEntry } from '../apps/fichiers/model';
import { groupNotes, previewOf, visibleNotes, type NoteRow } from '../apps/notes/model';
import { aspectOf, fxCss, groupPhotos, neighbour } from '../apps/photos/model';
import { makeT } from '../i18n';
import { mockOpen, resetMock } from '../nui/mock';
import { closeTablet, handleMessage, openApp, submitCode } from './actions';
import { os } from './store';
import { Host } from './Tablet';

async function unlock() {
  act(() => handleMessage('open', mockOpen()));
  await act(async () => { await submitCode('1234'); });
}

beforeEach(() => { resetMock(); closeTablet(); });
afterEach(() => { cleanup(); closeTablet(); vi.restoreAllMocks(); });

const row = (o: Partial<NoteRow>): NoteRow => ({ id: 1, folder: null, title: 't', excerpt: '', hint: '', pinned: false, deleted: false, updated: 0, ...o });
const file = (o: Partial<FileEntry>): FileEntry => ({ id: 1, parent: null, kind: 'doc', name: 'a', ref: null, size: 0, shared: false, token: null, tag: null, fav: false, updated: 0, ...o });

describe('modèles purs', () => {
  it('notes : dossiers, corbeille, recherche, épinglées, aperçu', () => {
    const t = makeT('fr');
    const l = [row({ id: 1, title: 'Plaque', excerpt: 'fourgon', pinned: true }), row({ id: 2, folder: 5, title: 'Courses' }), row({ id: 3, deleted: true, title: 'Vieille' })];
    expect(visibleNotes(l, 'all', '').map((n) => n.id)).toEqual([1, 2]);
    expect(visibleNotes(l, 'def', '').map((n) => n.id)).toEqual([1]);
    expect(visibleNotes(l, 5, '').map((n) => n.id)).toEqual([2]);
    expect(visibleNotes(l, 'trash', '').map((n) => n.id)).toEqual([3]);
    expect(visibleNotes(l, 'all', 'FOURGON').map((n) => n.id)).toEqual([1]);
    expect(groupNotes(visibleNotes(l, 'all', '')).pinned.length).toBe(1);
    expect(previewOf(row({ hint: 'todo' }), t)).toBe('Liste à cocher');
    expect(previewOf(row({}), t)).toBe('Pas de texte supplémentaire');
  });
  it('photos : filtres, formats, regroupement, navigation en boucle', () => {
    expect(fxCss('mono')).toBe('grayscale(1)');
    expect(fxCss('inconnu')).toBe('none');
    expect(aspectOf('square')).toBe('1 / 1');
    const day = 86400;
    const items = [1, 2, 3].map((i) => ({ id: i, kind: 'photo', rating: 0, fav: false, fx: 'none', taken: 1_800_000_000 - (i === 3 ? 400 * day : 0) }));
    expect(groupPhotos(items, 'year').map((g) => g.items.length)).toEqual([2, 1]);
    expect(neighbour([1, 2, 3], 3, 1)).toBe(1);
    expect(neighbour([1, 2, 3], 1, -1)).toBe(3);
  });
  it('fichiers : récents, partagés, tags, dossiers d\'abord, déplacement sans cycle', () => {
    const all = [file({ id: 1, kind: 'folder', name: 'Rapports' }), file({ id: 2, parent: 1, name: 'b.txt', shared: true, tag: 'red', updated: 5 }), file({ id: 3, parent: 1, kind: 'folder', name: 'Sous' }), file({ id: 4, name: 'a.txt', updated: 9 })];
    expect(viewOf(all, 'tablet', [], '', 'name').map((e) => e.id)).toEqual([1, 4]);
    expect(viewOf(all, 'tablet', [1], '', 'name').map((e) => e.id)).toEqual([3, 2]);
    expect(viewOf(all, 'recents', [], '', 'name').map((e) => e.id)).toEqual([4, 2]);
    expect(viewOf(all, 'shared', [], '', 'name').map((e) => e.id)).toEqual([2]);
    expect(viewOf(all, 'tag:red', [], '', 'name').map((e) => e.id)).toEqual([2]);
    expect(viewOf(all, 'tablet', [], 'B.TXT', 'name').map((e) => e.id)).toEqual([2]);
    expect(childCount(all, 1)).toBe(2);
    expect(pathTo(all, 3)).toEqual([1, 3]);
    expect(moveTargets(all, 1).map((e) => e.id)).toEqual([]);
    expect(moveTargets(all, 4).map((e) => e.id)).toEqual([1, 3]);
  });
  it('appareil photo : minuteur 0 -> 3 -> 10 -> 0', () => {
    expect([nextTimer(0), nextTimer(3), nextTimer(10)]).toEqual([3, 10, 0]);
  });
});

describe('app-not Notes', () => {
  it('créer, écrire, cocher, épingler, rechercher, supprimer (corbeille puis définitive)', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('notes'));
    expect(await screen.findByText('Courses')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Nouvelle note' }));
    const title = (await screen.findByLabelText('Titre')) as HTMLInputElement;
    fireEvent.change(title, { target: { value: 'Réunion' } });
    fireEvent.change(screen.getByLabelText('Texte'), { target: { value: 'Café' } });
    fireEvent.click(screen.getByRole('button', { name: 'Liste à cocher' }));
    const box = await screen.findByRole('checkbox', { name: 'Cocher' });
    fireEvent.click(box);
    expect(box.getAttribute('aria-checked')).toBe('true');
    fireEvent.click(screen.getByRole('button', { name: 'Tableau' }));
    expect((await screen.findAllByLabelText('Cellule')).length).toBe(9);
    fireEvent.click(screen.getByRole('button', { name: 'Épingler' }));
    expect(await screen.findByText('Épinglées')).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Rechercher dans les notes'), { target: { value: 'pain' } });
    expect(screen.queryByText('Réunion')).toBeNull();
    fireEvent.change(screen.getByLabelText('Rechercher dans les notes'), { target: { value: '' } });
    fireEvent.click(screen.getByRole('button', { name: 'Supprimer la note' }));
    await waitFor(() => expect(screen.getByText('Aucune note sélectionnée')).toBeTruthy());
    fireEvent.click(screen.getByRole('button', { name: /Supprimées/ }));
    expect(await screen.findAllByText('Réunion')).toBeTruthy();
  });
  it('dossier de notes : créé et sélectionné', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('notes'));
    fireEvent.click(await screen.findByRole('button', { name: 'Nouveau dossier' }));
    fireEvent.change(await screen.findByLabelText('Nom du dossier'), { target: { value: 'Travail' } });
    fireEvent.click(screen.getByRole('button', { name: 'Créer' }));
    expect((await screen.findAllByText('Travail')).length).toBeGreaterThan(0);
  });
});

describe('app-pho Photos', () => {
  it('photothèque, favori, étoiles, filtre, fond d\'écran, corbeille, album', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('photos'));
    fireEvent.click(await screen.findByRole('button', { name: 'Photo 1' }));
    const dialog = await screen.findByRole('dialog');
    fireEvent.click(within(dialog).getByRole('button', { name: 'Favori' }));
    await waitFor(() => expect(within(dialog).getByRole('button', { name: 'Favori' })).toBeTruthy());
    fireEvent.click(within(dialog).getByRole('button', { name: '4 étoiles' }));
    await waitFor(() => expect(within(dialog).getByRole('button', { name: '4 étoiles' }).getAttribute('aria-pressed')).toBe('true'));
    fireEvent.click(within(dialog).getByRole('button', { name: 'Modifier' }));
    fireEvent.click(await within(dialog).findByText('Noir et blanc'));
    fireEvent.click(within(dialog).getByRole('button', { name: "Fond d'écran" }));
    await waitFor(() => expect(os.get().settings.wall).toBe('photo:1'));
    fireEvent.click(within(dialog).getByRole('button', { name: 'Ajouter à un album' }));
    fireEvent.click(await screen.findByRole('button', { name: 'Nouvel album' }));
    fireEvent.change(await screen.findByLabelText("Nom de l'album"), { target: { value: 'Garage' } });
    fireEvent.click(screen.getByRole('button', { name: 'Créer' }));
    expect((await screen.findAllByText('Garage')).length).toBeGreaterThan(0);
    fireEvent.click(within(dialog).getByRole('button', { name: 'Supprimer' }));
    await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Photo 1' })).toBeNull());
    fireEvent.click(screen.getByRole('button', { name: /Récemment supprimés/ }));
    expect(await screen.findByRole('button', { name: 'Photo 1' })).toBeTruthy();
  });
});

describe('app-fil Fichiers', () => {
  it('arborescence, nouveau dossier, document, partage par code, ouverture d\'un code', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('fichiers'));
    fireEvent.click(await screen.findByRole('button', { name: 'Rapports' }));
    expect(await screen.findByRole('button', { name: 'Rapport.txt' })).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Nouveau' }));
    fireEvent.click(await screen.findByRole('button', { name: 'Nouveau document' }));
    fireEvent.change(await screen.findByLabelText('Nom'), { target: { value: 'Notes.txt' } });
    fireEvent.click(screen.getByRole('button', { name: 'Créer' }));
    expect(await screen.findByRole('button', { name: 'Notes.txt' })).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Rapport.txt' }));
    const dlg = await screen.findByRole('dialog');
    expect((within(dlg).getByLabelText('Contenu') as HTMLTextAreaElement).value).toBe('Bonjour');
    fireEvent.click(within(dlg).getByRole('button', { name: 'Partager' }));
    expect(await screen.findByText('Code de partage : ABCDEFGHJKLM')).toBeTruthy();
    fireEvent.click(within(dlg).getByRole('button', { name: '‹ OK' }));
    fireEvent.click(screen.getByRole('button', { name: 'Ouvrir un lien' }));
    fireEvent.change(await screen.findByLabelText('Code de partage'), { target: { value: 'abcdefghjklm' } });
    fireEvent.click(screen.getByRole('button', { name: 'Ouvrir' }));
    const shared = await screen.findByRole('dialog', { name: 'Rapport.txt' });
    expect((within(shared).getByLabelText('Contenu') as HTMLTextAreaElement).readOnly).toBe(true);
  });
});

describe('app-cam Appareil photo', () => {
  it('prise de vue : capture envoyée au serveur, miniature, formats, minuteur', async () => {
    render(<Host />);
    await unlock();
    act(() => openApp('camera'));
    fireEvent.click(await screen.findByRole('option', { name: 'Carré' }));
    fireEvent.click(screen.getByRole('button', { name: 'Minuteur' }));
    fireEvent.click(screen.getByRole('button', { name: 'Minuteur' }));
    fireEvent.click(screen.getByRole('button', { name: 'Minuteur' }));
    fireEvent.click(screen.getByRole('button', { name: 'Prendre une photo' }));
    expect(await screen.findByRole('status')).toBeTruthy();
    expect(screen.getByRole('status').textContent).toBe('Photo enregistrée');
    fireEvent.click(screen.getByRole('button', { name: 'Dernière photo' }));
    expect(await screen.findByRole('img', { name: 'Dernière photo' })).toBeTruthy();
  });
});
