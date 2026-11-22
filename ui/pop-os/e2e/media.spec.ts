import { expect, test } from './fixtures';

test.describe('Appareil photo', () => {
  test('s\'ouvre sans revenir à l\'accueil, coque et barre d\'état visibles, viseur transparent', async ({ tab }) => {
    const { page } = tab;
    await tab.open();
    const app = await tab.openApp('Appareil photo');
    const start = await tab.waitCall('tablet:camera', (d) => (d as { action?: string }).action === 'start');
    expect(start.data).toEqual({ action: 'start' });
    await expect(tab.screen).toHaveAttribute('data-camera', '1');
    await page.waitForTimeout(1500); // pas de retour à l'accueil
    await expect(app).toBeVisible();
    await expect(app.locator('[data-app="camera"]')).toBeVisible();
    // Coque visible (cadre « clair ») et barre d'état (heure) affichée.
    await expect(page.locator('[data-shell="1"]')).toBeVisible();
    await expect(page.locator('[data-shell="1"]')).toHaveAttribute('data-clear', '1');
    await expect(tab.screen).toContainText('14:32');
    await expect(tab.screen).toContainText('87 %');
    // Viseur transparent : rien d'opaque entre l'image du jeu et le viseur.
    await expect(page.locator('html')).toHaveAttribute('data-cam', 'live');
    const bg = await page.evaluate(() => {
      const c = (el: Element | null) => (el ? getComputedStyle(el).backgroundColor : 'absent');
      return {
        body: c(document.body),
        screen: c(document.querySelector('[data-screen="1"]')),
        layer: c(document.querySelector('[data-layer="app"]')),
        viewfinder: c(document.querySelector('[data-viewfinder="1"]')),
      };
    });
    for (const [k, v] of Object.entries(bg)) expect(v, `fond de ${k}`).toBe('rgba(0, 0, 0, 0)');
    // Ni l'écran verrouillé ni l'accueil ne sont affichés dessous.
    await expect(page.locator('[data-camera-hide="1"]')).toHaveCSS('visibility', 'hidden');
  });

  test('Alt envoie look_mode, la fin de l\'orientation libre revient de la page', async ({ tab }) => {
    const { page } = tab;
    await tab.open();
    await tab.openApp('Appareil photo');
    await expect(page.locator('[data-look-hint="1"]')).toBeVisible();
    await page.keyboard.press('Alt');
    const call = await tab.waitCall('tablet:camera', (d) => (d as { action?: string }).action === 'look_mode');
    expect(call.data).toEqual({ action: 'look_mode', on: true });
    await expect(page.locator('[data-look-hint="1"]')).toContainText(/terminer|fin|Alt/i);
    await tab.send('cameraLook', { on: false });
    await expect(page.locator('[data-look-hint="1"]')).toBeVisible();
  });

  test('prise de vue : capture envoyée, miniature, formats, minuteur, zoom, retournement', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Appareil photo');
    await tab.waitCall('tablet:camera');
    await app.getByRole('option', { name: 'Carré' }).click();
    await expect(app.getByRole('option', { name: 'Carré' })).toHaveAttribute('aria-selected', 'true');
    await app.getByRole('button', { name: 'Minuteur' }).click();
    await app.getByRole('button', { name: 'Flash' }).click();
    await app.getByRole('button', { name: /Zoom.*2/ }).click();
    expect((await tab.waitCall('tablet:camera', (d) => (d as { action?: string }).action === 'zoom')).data).toMatchObject({ level: 3 });
    await app.getByRole('button', { name: 'Changer de caméra' }).click();
    expect((await tab.waitCall('tablet:camera', (d) => (d as { action?: string }).action === 'selfie')).data).toMatchObject({ on: true });
    await app.getByRole('button', { name: 'Prendre une photo' }).click();
    await expect(app.getByRole('status')).toHaveText('Photo enregistrée', { timeout: 15_000 }); // minuteur de 3 s avant la prise
    expect((await tab.waitCall('photos:capture')).data).toMatchObject({ kind: 'square' });
    await app.getByRole('button', { name: 'Dernière photo' }).click();
    await expect(app.getByRole('img', { name: 'Dernière photo' })).toBeVisible();
  });

  test('quitter l\'appli arrête la caméra', async ({ tab }) => {
    await tab.open();
    await tab.openApp('Appareil photo');
    await tab.waitCall('tablet:camera');
    await tab.home();
    expect((await tab.waitCall('tablet:camera', (d) => (d as { action?: string }).action === 'stop')).data).toEqual({ action: 'stop' });
    await expect(tab.screen).not.toHaveAttribute('data-camera', '1');
  });
});

test.describe('Photos', () => {
  test('photothèque, favori, étoiles, retouche, fond d\'écran, album, corbeille', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Photos');
    await app.getByRole('button', { name: 'Photo 1', exact: true }).click();
    const dlg = app.getByRole('dialog');
    await dlg.getByRole('button', { name: 'Favori' }).click();
    await tab.waitCall('photos:favorite');
    await dlg.getByRole('button', { name: '4 étoiles' }).click();
    await expect(dlg.getByRole('button', { name: '4 étoiles' })).toHaveAttribute('aria-pressed', 'true');
    await tab.waitCall('photos:rate');
    await dlg.getByRole('button', { name: 'Modifier' }).click();
    await dlg.getByText('Noir et blanc').click();
    await tab.waitCall('photos:filter');
    await dlg.getByRole('button', { name: "Fond d'écran" }).click();
    await tab.waitCall('settings:save', (d) => (d as { wall?: string }).wall === 'photo:1');
    await dlg.getByRole('button', { name: 'Ajouter à un album' }).click();
    await app.getByRole('button', { name: 'Nouvel album' }).click();
    await app.getByLabel("Nom de l'album").fill('Garage');
    await app.getByRole('button', { name: 'Créer' }).click();
    await tab.waitCall('photos:albumSave');
    await expect(app.getByText('Garage').first()).toBeVisible();
    await dlg.getByRole('button', { name: 'Supprimer' }).click();
    await tab.waitCall('photos:delete');
    await app.getByRole('button', { name: /Récemment supprimés/ }).click();
    await expect(app.getByRole('button', { name: 'Photo 1', exact: true })).toBeVisible();
  });
  test('vues Années, Mois, Tout, Albums, Favoris', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Photos');
    for (const v of ['Années', 'Mois', 'Tout']) await app.getByRole('button', { name: v, exact: true }).click();
    await app.getByRole('button', { name: /^Albums/ }).click();
    await app.getByRole('button', { name: /^Favoris/ }).click();
    await app.getByRole('button', { name: /^Photothèque/ }).click();
    await expect(app.getByRole('button', { name: 'Photo 2', exact: true })).toBeVisible();
  });
});

test.describe('Notes', () => {
  test('créer, liste à cocher, tableau, épingler, rechercher, supprimer, corbeille', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Notes');
    await expect(app.getByText('Courses').first()).toBeVisible();
    await app.getByRole('button', { name: 'Nouvelle note' }).click();
    await app.getByLabel('Titre').fill('Réunion');
    await app.getByLabel('Texte', { exact: true }).fill('Café');
    await app.getByRole('button', { name: 'Liste à cocher' }).click();
    const box = app.getByRole('checkbox', { name: 'Cocher' });
    await box.click();
    await expect(box).toHaveAttribute('aria-checked', 'true');
    await app.getByRole('button', { name: 'Tableau', exact: true }).click();
    await expect(app.getByLabel('Cellule')).toHaveCount(9);
    await app.getByRole('button', { name: 'Épingler' }).click();
    await expect(app.getByText('Épinglées')).toBeVisible();
    expect((await tab.waitCall('notes:save', (d) => (d as { title?: string }).title === 'Réunion')).data).toBeTruthy();
    await app.getByLabel('Rechercher dans les notes').fill('pain');
    await expect(app.getByText('Réunion')).toHaveCount(0);
    await app.getByLabel('Rechercher dans les notes').fill('');
    await app.getByRole('button', { name: 'Supprimer la note' }).click();
    await tab.waitCall('notes:delete');
    await expect(app.getByText('Aucune note sélectionnée')).toBeVisible();
    await app.getByRole('button', { name: /Supprimées/ }).click();
    await expect(app.getByText('Réunion').first()).toBeVisible();
  });
  test('nouveau dossier créé et sélectionné', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Notes');
    await app.getByRole('button', { name: 'Nouveau dossier' }).click();
    await app.getByLabel('Nom du dossier').fill('Travail');
    await app.getByRole('button', { name: 'Créer' }).click();
    await tab.waitCall('notes:folderSave');
    await expect(app.getByText('Travail').first()).toBeVisible();
  });
});

test.describe('Tableau', () => {
  test('post-it ajouté, enregistré, rechargé après changement de tableau', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Tableau');
    await expect(app.getByLabel('Texte libre')).toHaveCount(1);
    await app.getByRole('button', { name: 'Post-it' }).click();
    await app.getByRole('img', { name: 'Dessin' }).click({ position: { x: 300, y: 300 } });
    const notes = app.getByLabel('Texte du post-it');
    await notes.last().fill('Indice 1');
    await tab.waitCall('board:save', (d) => JSON.stringify(d).includes('Indice 1'));
    await app.getByRole('button', { name: 'Liste des tableaux' }).click();
    await app.getByRole('button', { name: '+ Nouveau' }).click();
    await expect(app.getByLabel('Texte du post-it')).toHaveCount(0);
    await app.getByRole('button', { name: 'Liste des tableaux' }).click();
    await app.getByRole('button', { name: 'Enquête Vinewood' }).click();
    await expect(app.getByLabel('Texte du post-it')).toHaveCount(2);
    await expect(app.getByLabel('Texte du post-it').last()).toHaveValue('Indice 1');
  });
  test('outils : crayon, formes, texte, couleur, annuler, partage à proximité', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Tableau');
    for (const o of ['Crayon', 'Formes', 'Texte', 'Sélection']) {
      await app.getByRole('button', { name: o, exact: true }).click();
      await expect(app.getByRole('button', { name: o, exact: true })).toHaveAttribute('aria-pressed', 'true');
    }
    await app.getByRole('button', { name: 'Crayon', exact: true }).click();
    const d = app.getByRole('img', { name: 'Dessin' });
    const box = (await d.boundingBox())!;
    await tab.page.mouse.move(box.x + 200, box.y + 400);
    await tab.page.mouse.down();
    await tab.page.mouse.move(box.x + 320, box.y + 460, { steps: 6 });
    await tab.page.mouse.up();
    await app.getByRole('button', { name: 'Annuler', exact: true }).click();
    await app.getByRole('button', { name: 'Couleur' }).click();
    await app.getByRole('button', { name: 'Partager à proximité' }).click();
    await tab.waitCall('share:nearby');
  });
});

test.describe('Dictaphone', () => {
  test('micro refusé : mémo dicté enregistré puis affiché, renommer, supprimer', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Dictaphone');
    await expect(app.getByText('Mémo de patrouille').first()).toBeVisible();
    await app.getByRole('button', { name: 'Mémo dicté' }).click();
    await app.getByLabel('Écrivez ou dictez votre mémo').fill('Rendez-vous au garage');
    await app.getByRole('button', { name: 'Enregistrer le mémo' }).click();
    await tab.waitCall('rec:save');
    await expect(app.getByTestId('memo-text')).toHaveText('Rendez-vous au garage');
    await app.getByRole('button', { name: 'Renommer' }).click();
    await app.getByRole('textbox').last().fill('Garage');
    await app.getByRole('button', { name: 'OK', exact: true }).click();
    await tab.waitCall('rec:rename', (d) => (d as { title?: string }).title === 'Garage');
    await app.getByRole('button', { name: 'Supprimer' }).click();
    await tab.waitCall('rec:delete');
  });
});
