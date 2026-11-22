import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { chooseMode, chunks, clampSeconds, mmss, nextSpeed, recClock, wave } from '../apps/dictaphone/model';
import { MAX_POINTS, addStroke, emptyBoard, fits, moved, parse, patchItem, placeItem, quant, serialize, thin, undo, type Board } from '../apps/tableau/model';
import { resetMock, mockOpen } from '../nui/mock';
import { closeTablet, handleMessage, openApp, submitCode } from './actions';
import { Host } from './Tablet';

async function unlock() {
  act(() => handleMessage('open', mockOpen()));
  await act(async () => { await submitCode('1234'); });
}

beforeEach(() => { resetMock(); closeTablet(); });
afterEach(() => { cleanup(); closeTablet(); vi.restoreAllMocks(); });

const labels = { text: 'Texte', image: 'Photo' };

describe('modèle Tableau', () => {
  it('éléments, déplacement, annulation, aller-retour JSON identique', () => {
    let b: Board = emptyBoard();
    b = placeItem(b, 'note', 'rect', 2, 300, 300, labels);
    b = placeItem(b, 'shape', 'arrow', 1, 600, 400, labels);
    b = placeItem(b, 'shape', 'circle', 3, 700, 500, labels);
    expect(b.items.map((i) => i.type)).toEqual(['note', 'arrow', 'shape']);
    b = patchItem(b, 1, moved(b.items[0] as never, 10, -5));
    expect(b.items[0]).toMatchObject({ x: 215, y: 200 });
    b = addStroke(b, 1, [[1, 2], [50, 60], [90, 99]]);
    expect(parse(serialize(b))).toEqual(b);
    expect(undo(b).strokes.length).toBe(0);
    expect(undo(undo(b)).items.length).toBe(2);
    expect(parse('{nope')).toEqual(emptyBoard());
  });
  it('points quantifiés, traits allégés, limites 10 000 points et 128 Ko', () => {
    expect(quant(1500.4, -3)).toEqual([1348, 0]);
    const dense: Array<[number, number]> = Array.from({ length: 200 }, (_, i) => [100 + (i % 2), 100]);
    expect(thin(dense).length).toBeLessThan(5);
    const big: Board = { items: [], strokes: [{ id: 1, col: 0, pts: Array.from({ length: MAX_POINTS + 1 }, () => [1, 1] as [number, number]) }] };
    expect(fits(big)).toEqual({ ok: false, why: 'points' });
    const heavy: Board = { items: [{ id: 1, type: 'text', col: 0, x: 0, y: 0, w: 10, h: 10, text: 'a'.repeat(140000) }], strokes: [] };
    expect(fits(heavy)).toEqual({ ok: false, why: 'bytes' });
    expect(fits(emptyBoard()).ok).toBe(true);
  });
});

describe('modèle Dictaphone', () => {
  it('choix du mode : test, enregistrement, mémo dicté', () => {
    expect(chooseMode('unknown', true)).toBe('testing');
    expect(chooseMode('granted', true)).toBe('record');
    expect(chooseMode('granted', false)).toBe('memo');
    expect(chooseMode('denied', true)).toBe('memo');
  });
  it('durées, découpage, onde', () => {
    expect(mmss(204)).toBe('3:24');
    expect(recClock(65_300)).toBe('01:05,3');
    expect(clampSeconds(500_000)).toBe(120);
    expect(clampSeconds(10)).toBe(1);
    expect(chunks('abcdefg', 3)).toEqual(['abc', 'def', 'g']);
    expect(wave(3, 96)).toEqual(wave(3, 96));
    expect(wave(3, 8).every((a) => a >= 0.08 && a <= 1.1)).toBe(true);
    expect(nextSpeed(2)).toBe(0.5);
  });
});

describe('app-tab Tableau', () => {
  it('ouvre le dernier tableau, ajoute un post-it, l\'enregistre et le recharge', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    render(<Host />);
    await unlock();
    act(() => openApp('tableau'));
    expect(await screen.findByRole('button', { name: 'Liste des tableaux' })).toBeTruthy();
    expect((await screen.findAllByLabelText('Texte libre')).length).toBe(1);
    fireEvent.click(screen.getByRole('button', { name: 'Post-it' }));
    const overlay = screen.getByRole('img', { name: 'Dessin' });
    fireEvent.pointerDown(overlay, { clientX: 300, clientY: 300 });
    const notes = await screen.findAllByLabelText('Texte du post-it');
    const note = notes[notes.length - 1] as HTMLElement;
    fireEvent.change(note, { target: { value: 'Indice 1' } });
    await act(async () => { await vi.advanceTimersByTimeAsync(1000); });
    fireEvent.click(screen.getByRole('button', { name: 'Liste des tableaux' }));
    fireEvent.click(await screen.findByRole('button', { name: '+ Nouveau' }));
    await waitFor(() => expect(screen.queryAllByLabelText('Texte du post-it').length).toBe(0));
    fireEvent.click(screen.getByRole('button', { name: 'Liste des tableaux' }));
    fireEvent.click(await screen.findByRole('button', { name: 'Enquête Vinewood' }));
    const back = (await screen.findAllByLabelText('Texte du post-it')) as HTMLTextAreaElement[];
    expect(back.map((x) => x.value)).toEqual(['Fourgon blanc, plaque 42 ABC 117', 'Indice 1']);
    vi.useRealTimers();
  });
});

describe('app-dic Dictaphone (micro refusé : mémo dicté)', () => {
  it('écran dégradé, mémo enregistré puis relu', async () => {
    vi.stubGlobal('speechSynthesis', undefined);
    render(<Host />);
    await unlock();
    act(() => openApp('dictaphone'));
    expect(await screen.findByRole('status')).toBeTruthy();
    fireEvent.click(await screen.findByRole('button', { name: 'Mémo dicté' }));
    fireEvent.change(await screen.findByLabelText('Écrivez ou dictez votre mémo'), { target: { value: 'Rendez-vous au garage' } });
    fireEvent.click(screen.getByRole('button', { name: 'Enregistrer le mémo' }));
    await waitFor(() => expect(screen.getByTestId('memo-text').textContent).toBe('Rendez-vous au garage'));
    expect(screen.getByText('Lecture vocale indisponible')).toBeTruthy();
  });
});

describe('share Partage de proximité', () => {
  it('une offre reçue se propose, et accepter appelle le serveur', async () => {
    render(<Host />);
    await unlock();
    act(() => handleMessage('share', { offerId: 7, kind: 'note', name: 'Idée' }));
    expect(await screen.findByText('Quelqu\'un près de vous propose : note, Idée')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Accepter' }));
    await waitFor(() => expect(screen.queryByText('Partage reçu')).toBeNull());
  });
});
