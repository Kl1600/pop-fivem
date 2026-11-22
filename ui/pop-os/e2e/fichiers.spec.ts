import { expect, test } from './fixtures';

// Fichiers : chaque action de l'appli est exercée et son appel NUI vérifié.
test.describe('Fichiers', () => {
  test('dossier, document : création, ouverture, modification enregistrée', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Fichiers');
    await app.getByRole('button', { name: 'Rapports', exact: true }).click(); // entre dans le dossier
    await expect(app.getByRole('button', { name: 'Rapport.txt', exact: true })).toBeVisible();
    await app.getByRole('button', { name: 'Nouveau', exact: true }).click();
    await app.getByRole('button', { name: 'Nouveau document' }).click();
    await app.getByLabel('Nom', { exact: true }).fill('Notes.txt');
    await app.getByRole('button', { name: 'Créer' }).click();
    await expect(app.getByRole('button', { name: 'Notes.txt', exact: true })).toBeVisible();
    expect((await tab.waitCall('files:save', (d) => (d as { name?: string }).name === 'Notes.txt')).data).toMatchObject({ kind: 'doc' });
    await app.getByRole('button', { name: 'Rapport.txt', exact: true }).click();
    const dlg = app.getByRole('dialog', { name: 'Rapport.txt' });
    await expect(dlg.getByLabel('Contenu')).toHaveValue('Bonjour');
    await dlg.getByLabel('Contenu').fill('Bonjour tout le monde');
    await dlg.getByRole('button', { name: 'Enregistrer' }).click();
    expect((await tab.waitCall('files:save', (d) => (d as { body?: string }).body === 'Bonjour tout le monde')).data).toMatchObject({ name: 'Rapport.txt' });
    await expect(dlg).toHaveCount(0);
  });

  test('nouveau dossier, renommer, étiquette, favori, déplacer, supprimer', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Fichiers');
    await app.getByRole('button', { name: 'Nouveau', exact: true }).click();
    await app.getByRole('button', { name: 'Nouveau dossier' }).click();
    await app.getByLabel('Nom', { exact: true }).fill('Archives');
    await app.getByRole('button', { name: 'Créer' }).click();
    await expect(app.getByRole('button', { name: 'Archives', exact: true })).toBeVisible();
    await tab.waitCall('files:save', (d) => (d as { name?: string; kind?: string }).name === 'Archives');
    // Renommer
    await app.getByRole('button', { name: 'Modifier Archives' }).click();
    await app.getByLabel('Renommer').fill('Archives 2026');
    await app.getByRole('button', { name: 'Enregistrer', exact: true }).click();
    await expect(app.getByRole('button', { name: 'Archives 2026', exact: true })).toBeVisible();
    await tab.waitCall('files:save', (d) => (d as { name?: string }).name === 'Archives 2026');
    // Étiquette
    await app.getByRole('button', { name: 'Modifier Archives 2026' }).click();
    await app.getByRole('button', { name: 'Urgent', exact: true }).last().click(); // la pastille de la feuille, pas la barre latérale
    await tab.waitCall('files:save', (d) => (d as { tag?: string }).tag === 'red');
    // Favori (dossier)
    await app.getByRole('button', { name: 'Modifier Archives 2026' }).click();
    await app.getByRole('button', { name: 'Ajouter aux favoris' }).first().click();
    await tab.waitCall('files:save', (d) => (d as { fav?: boolean }).fav === true);
    // Déplacer dans Rapports
    await app.getByRole('button', { name: 'Modifier Archives 2026' }).click();
    await app.getByRole('button', { name: 'Déplacer vers', exact: true }).click();
    await app.getByRole('button', { name: 'Rapports', exact: true }).last().click();
    await tab.waitCall('files:move', (d) => (d as { parentId?: number }).parentId !== undefined);
    await expect(app.locator('main').getByRole('button', { name: 'Archives 2026', exact: true })).toHaveCount(0);
    // Supprimer (depuis Rapports)
    await app.getByRole('button', { name: 'Rapports', exact: true }).first().click();
    await app.getByRole('button', { name: 'Modifier Archives 2026' }).click();
    await app.getByRole('button', { name: 'Supprimer', exact: true }).click();
    await tab.waitCall('files:delete');
    await expect(app.locator('main').getByRole('button', { name: 'Archives 2026', exact: true })).toHaveCount(0);
  });

  test('partage par code, retrait du partage, ouverture d\'un code en lecture seule', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Fichiers');
    await app.getByRole('button', { name: 'Rapports', exact: true }).click();
    await app.getByRole('button', { name: 'Rapport.txt', exact: true }).click();
    const dlg = app.getByRole('dialog', { name: 'Rapport.txt' });
    await dlg.getByRole('button', { name: 'Partager' }).click();
    await expect(app.getByText('Code de partage : ABCDEFGHJKLM')).toBeVisible();
    await tab.waitCall('files:share');
    await dlg.getByRole('button', { name: /OK/ }).click();
    await app.getByRole('button', { name: 'Ouvrir un lien' }).click();
    await app.getByLabel('Code de partage').fill('abcdefghjklm');
    await app.getByRole('button', { name: 'Ouvrir', exact: true }).click();
    const shared = app.getByRole('dialog', { name: 'Rapport.txt' });
    await expect(shared.getByLabel('Contenu')).toHaveAttribute('readonly', '');
    expect((await tab.waitCall('files:open')).data).toBe('ABCDEFGHJKLM');
    await shared.getByRole('button', { name: /OK/ }).click();
    await app.getByRole('button', { name: 'Partagés' }).click();
    await expect(app.getByRole('button', { name: 'Rapport.txt', exact: true })).toBeVisible();
    await app.getByRole('button', { name: 'Modifier Rapport.txt' }).click();
    await app.getByRole('button', { name: 'Arrêter le partage' }).click();
    await tab.waitCall('files:unshare');
  });

  test('vue liste, tri, recherche, récents, étiquettes de la barre latérale', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Fichiers');
    await app.getByRole('button', { name: 'Liste', exact: true }).click();
    await expect(app.getByRole('button', { name: 'Liste', exact: true })).toHaveAttribute('aria-pressed', 'true');
    for (const k of ['Date', 'Taille', 'Type', 'Nom']) await app.getByRole('button', { name: k, exact: true }).click();
    await app.getByRole('button', { name: 'Icônes', exact: true }).click();
    await app.getByRole('textbox', { name: 'Rechercher' }).fill('zzzzz');
    await expect(app.getByText('Rapports', { exact: true })).toHaveCount(0);
    await app.getByRole('textbox', { name: 'Rechercher' }).fill('');
    await app.getByRole('button', { name: 'Récents', exact: true }).click();
    await app.getByRole('button', { name: 'Urgent', exact: true }).last().click(); // la pastille de la feuille, pas la barre latérale
    await app.getByRole('button', { name: 'Sur la tablette', exact: true }).first().click();
    await expect(app.getByRole('button', { name: 'Rapports', exact: true })).toBeVisible();
  });

  test('ajouter une photo, un tableau, un enregistrement', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Fichiers');
    const cas = [['Ajouter une photo', 'photos:list', 'Photo 1', 'photo'], ['Ajouter un tableau', 'board:list', 'Enquête Vinewood', 'board'], ['Ajouter un enregistrement', 'rec:list', 'Mémo de patrouille', 'audio']] as const;
    for (const [label, listCall, pick, kind] of cas) {
      await app.getByRole('button', { name: 'Nouveau', exact: true }).click();
      await app.getByRole('button', { name: label, exact: true }).click();
      await tab.waitCall(listCall);
      await app.getByRole('button', { name: pick, exact: true }).last().click();
      const saved = await tab.waitCall('files:save', (d) => (d as { kind?: string }).kind === kind);
      expect(saved.data).toMatchObject({ kind, name: pick });
      expect((saved.data as { refId?: number }).refId).toBeGreaterThan(0);
    }
  });
});
