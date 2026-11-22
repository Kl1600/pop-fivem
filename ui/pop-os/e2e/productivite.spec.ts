import { expect, test } from './fixtures';

test.describe('Calculette', () => {
  test('7 × 6 = 42, historique, scientifique, effacement', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Calculette');
    for (const k of ['7', '×', '6', '=']) await app.getByRole('button', { name: k, exact: true }).click();
    await expect(app.getByTestId('calc-display')).toHaveText('42');
    await expect(app.getByRole('navigation', { name: 'Historique' }).getByText('7 × 6')).toBeVisible();
    for (const k of ['9', '√']) await app.getByRole('button', { name: k, exact: true }).click();
    await expect(app.getByTestId('calc-display')).toHaveText('3');
    await app.getByRole('button', { name: "Effacer l'historique" }).click();
    await expect(app.getByText('Aucun calcul.')).toBeVisible();
    await app.getByRole('button', { name: 'Scientifique' }).click();
    await expect(app.getByRole('button', { name: 'sin' })).toHaveCount(0);
  });
  test('division par zéro : erreur affichée', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Calculette');
    for (const k of ['1', '÷', '0', '=']) await app.getByRole('button', { name: k, exact: true }).click();
    await expect(app.getByTestId('calc-display')).toHaveText('Erreur');
  });
});

test.describe('Horloge', () => {
  test('horloges du monde', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Horloge');
    await expect(app.getByRole('img', { name: 'Los Santos' })).toBeVisible();
    await expect(app.getByRole('img', { name: 'Paris' })).toBeVisible();
  });
  test('alarme : Enregistrer crée l\'alarme, l\'interrupteur la coupe, Supprimer la retire', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Horloge');
    await app.getByRole('button', { name: 'Alarmes' }).click();
    await expect(app.getByText('Réveil, En semaine')).toBeVisible();
    await expect(app.getByRole('switch')).toHaveCount(1);
    await app.getByRole('button', { name: 'Ajouter une alarme' }).click();
    await app.getByRole('button', { name: 'Enregistrer' }).click();
    await expect(app.getByText('Alarme, Jamais')).toBeVisible();
    await expect(app.getByRole('switch')).toHaveCount(2);
    const saved = await tab.waitCall('clock:saveAlarm');
    expect(saved.data).toMatchObject({ enabled: true });
    await app.getByRole('switch').last().click();
    await expect.poll(async () => (await tab.calls('clock:saveAlarm')).length).toBeGreaterThanOrEqual(2);
    await app.getByRole('button', { name: 'Modifier' }).click();
    await app.getByRole('button', { name: "Supprimer l'alarme" }).first().click();
    await tab.waitCall('clock:deleteAlarm');
    await expect(app.getByRole('switch')).toHaveCount(1);
  });
  test('chronomètre : démarre, tour, réinitialisation', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Horloge');
    await app.getByRole('button', { name: 'Chronomètre' }).click();
    await expect(app.getByTestId('sw-text')).toHaveText('00:00,00');
    await app.getByRole('button', { name: 'Démarrer ou arrêter' }).click();
    await expect(app.getByTestId('sw-text')).not.toHaveText('00:00,00');
    await app.getByRole('button', { name: 'Tour ou réinitialiser' }).click();
    await expect(app.getByText('Tour 1')).toBeVisible();
    await app.getByRole('button', { name: 'Démarrer ou arrêter' }).click();
    await app.getByRole('button', { name: 'Tour ou réinitialiser' }).click();
    await expect(app.getByText('Tour 1')).toHaveCount(0);
  });
  test('minuteur : démarre et décompte, pause, annulation', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Horloge');
    await app.getByRole('button', { name: 'Minuteurs' }).click();
    await expect(app.getByTestId('timer-text')).toHaveText('05:00');
    await app.getByRole('button', { name: '10 min' }).click();
    await expect(app.getByTestId('timer-text')).toHaveText('10:00');
    await app.getByRole('button', { name: 'Démarrer ou mettre en pause' }).click();
    await tab.waitCall('clock:startTimer');
    // Il décompte réellement : le texte descend sous 10:00 sans autre action.
    await expect(app.getByTestId('timer-text')).not.toHaveText('10:00', { timeout: 6000 });
    await expect(app.getByTestId('timer-text')).toHaveText(/^09:5\d$/);
    await expect(app.getByText('Pause')).toBeVisible();
    await app.getByRole('button', { name: 'Annuler le minuteur' }).click();
    await tab.waitCall('clock:cancelTimer');
    await expect(app.getByText('Pause')).toHaveCount(0);
  });
});

test.describe('Rappels', () => {
  test('cocher, ajouter, signaler, rechercher, liste', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Rappels');
    await expect(app.getByText('Rédiger le rapport')).toBeVisible();
    await app.getByRole('checkbox', { name: 'Terminer' }).first().click();
    await tab.waitCall('reminders:toggle');
    await expect(app.getByText('Rédiger le rapport')).toHaveCount(0);
    await app.getByRole('button', { name: /Tous/ }).click();
    await app.getByRole('button', { name: 'Ajouter un rappel' }).click();
    await app.getByLabel('Nouveau rappel').fill('Faire le plein');
    await app.getByLabel('Nouveau rappel').press('Enter');
    await expect(app.getByText('Faire le plein')).toBeVisible();
    expect((await tab.waitCall('reminders:save')).data).toMatchObject({ title: 'Faire le plein' });
    await app.getByRole('button', { name: 'Signaler' }).first().click();
    await expect(app.getByRole('button', { name: 'Signaler' }).first()).toHaveAttribute('aria-pressed', 'true');
    await app.getByLabel('Rechercher').fill('plein');
    await expect(app.getByText('Appeler Lina')).toHaveCount(0);
    await app.getByLabel('Rechercher').fill('');
    await app.getByRole('button', { name: 'Ajouter une liste' }).click();
    await app.getByLabel('Nom de la liste').fill('Garage');
    await app.getByRole('button', { name: 'Enregistrer' }).click();
    await tab.waitCall('reminders:listSave');
    await expect(app.getByText('Garage').first()).toBeVisible();
    await app.getByRole('button', { name: 'Supprimer la liste' }).click();
    await expect(app.getByText('Garage')).toHaveCount(0);
  });
});

test.describe('Calendrier', () => {
  test('vues, détail, calendrier masqué, création et suppression', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Calendrier');
    await expect(app.getByText('Patrouille', { exact: true })).toBeVisible();
    await app.getByRole('button', { name: 'Mois', exact: true }).click();
    await expect(app.getByText('Patrouille', { exact: true })).toBeVisible();
    await app.getByRole('button', { name: 'Année', exact: true }).click();
    await expect(app.getByText(/janvier/i).first()).toBeVisible();
    await app.getByRole('button', { name: 'Semaine', exact: true }).click();
    await app.getByText('Patrouille', { exact: true }).click();
    await expect(app.getByText('Vinewood Boulevard')).toBeVisible();
    await app.getByRole('button', { name: 'Fermer' }).click();
    await app.getByRole('button', { name: 'Patrouilles' }).click();
    await expect(app.getByText('Patrouille', { exact: true })).toHaveCount(0);
    await app.getByRole('button', { name: 'Patrouilles' }).click();
    await app.getByRole('button', { name: 'Ajouter un événement' }).click();
    await app.getByLabel('Titre').fill('Brunch');
    await app.getByRole('button', { name: 'Enregistrer' }).click();
    expect((await tab.waitCall('calendar:save')).data).toMatchObject({ title: 'Brunch' });
    await expect(app.getByText('Brunch')).toBeVisible();
    await app.getByText('Brunch').click();
    await app.getByRole('button', { name: 'Supprimer' }).click();
    await tab.waitCall('calendar:delete');
    await expect(app.getByText('Brunch')).toHaveCount(0);
  });
  test('titre vide ou fin avant le début : refusé', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Calendrier');
    await app.getByRole('button', { name: 'Ajouter un événement' }).click();
    await app.getByRole('button', { name: 'Enregistrer' }).click();
    await expect(app.getByText('Donnez un titre')).toBeVisible();
    await app.getByLabel('Titre').fill('X');
    await app.getByLabel('Début').fill('18:00');
    await app.getByLabel('Fin').fill('17:00');
    await app.getByRole('button', { name: 'Enregistrer' }).click();
    await expect(app.getByText('La fin doit suivre le début')).toBeVisible();
    expect(await tab.calls('calendar:save')).toHaveLength(0);
  });
});

test.describe('Météo, Plans, Bourse, Traduire', () => {
  test('météo : lieu, unité, recherche vide', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Météo');
    await expect(app.getByTestId('met-temp')).toHaveText('24°');
    await app.locator('[data-place="ss"]').click();
    await expect(app.getByTestId('met-temp')).toHaveText('33°');
    await app.getByRole('button', { name: 'Changer d’unité' }).click();
    await expect(app.getByTestId('met-temp')).toHaveText('91°');
    await app.getByLabel('Rechercher un lieu').fill('zzz');
    await expect(app.getByText('Aucun lieu.')).toBeVisible();
  });
  test('météo : la météo du jeu poussée met l\'écran à jour', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Météo');
    await tab.send('weather', { temp: 15, kind: 'rain', hi: 18, lo: 11, wind: 30, deg: 90, city: 'Los Santos' });
    await expect(app.getByTestId('met-temp')).toHaveText('15°');
    await expect(app.getByText('Pluvieux').first()).toBeVisible();
  });
  test('plans : favoris, recherche, lieu en favori, itinéraire puis arrêt', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Plans');
    await expect(app.locator('[data-fav]')).toHaveCount(3);
    await app.getByLabel('Rechercher un lieu').fill('banque');
    await app.getByText('Fleeca Bank, Legion Square').click();
    await expect(app.getByText(/Banque ·/)).toBeVisible();
    await app.getByRole('button', { name: 'Favori' }).click();
    await expect(app.getByRole('button', { name: 'Favori' })).toHaveAttribute('aria-pressed', 'true');
    await tab.waitCall('plans:fav');
    await app.getByRole('button', { name: /^Itinéraire/ }).click();
    await app.getByRole('button', { name: 'Démarrer' }).click();
    await expect(app.getByRole('button', { name: 'Terminer' })).toBeVisible();
    await app.getByRole('button', { name: 'Terminer' }).click();
    await expect(app.getByText('Récents')).toBeVisible();
    await tab.waitCall('plans:recent');
  });
  test('bourse : cours, période, liste de suivi', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Bourse');
    await expect(app.getByTestId('price-MAZE')).toHaveText('412,60');
    await tab.page.evaluate(() => window.dispatchEvent(new CustomEvent('pop-market', { detail: { p: [1184230, 42000, 8735, 15620, 6480, 20345, 9810] } })));
    await expect(app.getByTestId('price-MAZE')).toHaveText('420,00');
    await app.locator('[data-sym="FLCA"]').click();
    const before = await app.getByTestId('chart-line').getAttribute('d');
    await app.getByRole('button', { name: '1A' }).click();
    await expect.poll(() => app.getByTestId('chart-line').getAttribute('d')).not.toBe(before);
    await expect(app.getByText('Chiffres clés')).toBeVisible();
    await app.getByRole('button', { name: 'Modifier la liste' }).click();
    await app.getByRole('button', { name: 'Ne plus suivre PISS' }).click();
    await expect(app.getByRole('button', { name: 'Suivre PISS' })).toBeVisible();
    await app.getByRole('button', { name: 'Terminé' }).click();
    await expect(app.locator('[data-sym="PISS"]')).toHaveCount(0);
    await tab.waitCall('stocks:watch');
  });
  test('traduire : phrase, favori, favoris, retrait', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Traduire');
    await app.getByLabel('Texte à traduire').fill('Combien ça coûte ?');
    await expect(app.getByTestId('tra-out')).toHaveText('How much is it?');
    await app.getByRole('button', { name: 'Ajouter aux favoris' }).click();
    await expect(app.getByRole('button', { name: 'Ajouter aux favoris' })).toHaveAttribute('aria-pressed', 'true');
    await tab.waitCall('translate:fav');
    await app.getByRole('button', { name: /Favoris/ }).click();
    await expect(app.getByText('Combien ça coûte ?')).toBeVisible();
    await app.getByRole('button', { name: 'Retirer des favoris' }).click();
    await expect(app.getByText('Combien ça coûte ?')).toHaveCount(0);
  });
});
