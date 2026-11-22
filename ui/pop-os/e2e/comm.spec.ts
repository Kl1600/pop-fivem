import { expect, test } from './fixtures';

test.describe('Messages', () => {
  test('conversation : lecture, envoi, distribué puis lu, position partagée', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Messages');
    await app.getByRole('button', { name: /Sam Leroy/ }).click();
    await expect(app.getByText('Briefing à Mission Row à 18h.')).toBeVisible();
    await app.getByLabel('Message', { exact: true }).fill('Bien reçu');
    await app.getByRole('button', { name: 'Envoyer' }).click();
    expect((await tab.waitCall('messages:send')).data).toMatchObject({ body: 'Bien reçu' });
    await expect(app.getByText('Bien reçu').first()).toBeVisible();
    await expect(app.getByText('Distribué')).toBeVisible();
    await tab.send('message', { read: '555-0123' });
    await expect(app.getByText('Lu', { exact: true })).toBeVisible();
    await app.getByRole('button', { name: 'Ajouter' }).click();
    await app.getByRole('button', { name: 'Position', exact: true }).click();
    await expect(app.getByLabel('Position partagée').first()).toBeVisible();
  });
  test('recherche, épingler, nouveau message par numéro, groupe', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Messages');
    await app.getByLabel('Rechercher').fill('zzzz');
    await expect(app.getByText('Aucun résultat.')).toBeVisible();
    await app.getByLabel('Rechercher').fill('Noah');
    await app.getByText('Noah Petit').first().click();
    await app.getByRole('button', { name: 'Épingler' }).click();
    await tab.waitCall('messages:pin');
    await expect(app.getByRole('button', { name: 'Désépingler' })).toBeVisible();
    await app.getByLabel('Rechercher').fill('');
    await app.getByRole('button', { name: 'Nouveau message' }).click();
    await app.getByLabel('Nom ou numéro').fill('555-0999');
    await app.getByRole('button', { name: 'Créer' }).click();
    await expect(app.getByLabel('Message', { exact: true })).toBeVisible();
    await app.getByRole('button', { name: 'Nouveau message' }).click();
    const sheet = app.getByRole('dialog', { name: 'Nouveau message' });
    await sheet.getByRole('button', { name: 'Lina Costa' }).click();
    await sheet.getByRole('button', { name: 'Sam Leroy' }).click();
    await app.getByLabel('Nom du groupe').fill('Brigade');
    await app.getByRole('button', { name: 'Créer' }).click();
    await tab.waitCall('messages:group');
    await expect(app.getByText('Brigade').first()).toBeVisible();
  });
  test('message reçu appli fermée : bannière et pastille', async ({ tab }) => {
    await tab.open();
    await tab.send('message', { from: '555-0123', to: '555-0142', body: 'yo', kind: 'text', id: 99, at: 1 });
    await expect(tab.page.getByRole('button').filter({ hasText: 'yo' })).toBeVisible();
    await expect(tab.screen.getByRole('button', { name: 'Messages', exact: true }).first()).toContainText('3');
  });
});

test.describe('Téléphone', () => {
  test('clavier : composer, sonner, décrocher à distance, raccrocher', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Téléphone');
    await app.getByRole('button', { name: 'Clavier' }).click();
    for (const d of '5550123') await app.getByRole('button', { name: d, exact: true }).click();
    await expect(app.getByText('555-0123')).toBeVisible();
    await app.getByRole('button', { name: 'Appeler', exact: true }).click();
    const dlg = app.getByRole('dialog');
    await expect(dlg.getByText('Sam Leroy')).toBeVisible();
    await expect(dlg.getByText('Ça sonne…')).toBeVisible();
    expect((await tab.waitCall('phone:call')).data).toMatchObject({ to: '555-0123' });
    await tab.send('call', { id: 101, state: 'active', from: '555-0123' });
    await expect(dlg.getByText(/^\d+:\d\d$/)).toBeVisible();
    await tab.page.getByRole('button', { name: 'Raccrocher' }).click();
    await tab.waitCall('phone:hangup');
    await expect(app.getByRole('dialog')).toHaveCount(0);
  });
  test('numéro injoignable : message vocal laissé', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Téléphone');
    await app.getByRole('button', { name: 'Clavier' }).click();
    for (const d of '5550000') await app.getByRole('button', { name: d, exact: true }).click();
    await app.getByRole('button', { name: 'Appeler', exact: true }).click();
    await app.getByLabel('Votre message').fill('Rappelle-moi');
    await app.getByRole('button', { name: 'Envoyer' }).click();
    await tab.waitCall('phone:voicemail');
    await expect(app.getByLabel('Votre message')).toHaveCount(0);
  });
  test('appel entrant : refuser, puis accepter et raccrocher', async ({ tab }) => {
    await tab.open();
    await tab.send('call', { id: 7, state: 'ring', from: '555-0123' });
    const dlg = tab.page.getByRole('dialog', { name: 'Appel entrant' });
    await expect(dlg.getByText('Sam Leroy')).toBeVisible();
    await tab.page.getByRole('button', { name: 'Refuser' }).click();
    await tab.waitCall('phone:decline');
    await expect(tab.page.getByRole('dialog')).toHaveCount(0);
    await tab.send('call', { id: 8, state: 'ring', from: '555-0166' });
    await tab.page.getByRole('button', { name: 'Accepter' }).click();
    await tab.waitCall('phone:answer');
    await expect(tab.page.getByRole('button', { name: 'Raccrocher' })).toBeVisible();
    await tab.send('call', { id: 8, state: 'end', why: 'hangup' });
    await expect(tab.page.getByRole('dialog')).toHaveCount(0);
  });
  test('récents, manqués, messagerie vocale', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Téléphone');
    await expect(app.getByText('Appel manqué')).toHaveCount(2);
    await app.getByRole('button', { name: 'Manqués' }).click();
    await expect(app.getByText('Appel sortant')).toHaveCount(0);
    await app.getByRole('button', { name: 'Messagerie' }).click();
    await expect(app.getByText('Rappelle-moi quand tu peux.')).toBeVisible();
    for (const n of ['Favoris', 'Contacts']) await app.getByRole('button', { name: n, exact: true }).click();
  });
});

test.describe('Contacts', () => {
  test('ajout, modification, suppression', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Contacts');
    await expect(app.getByRole('button', { name: /Lina Costa/ })).toBeVisible();
    await app.getByRole('button', { name: 'Nouveau contact' }).click();
    await app.getByLabel('Prénom').fill('Eli');
    await app.getByLabel('Nom', { exact: true }).fill('Garcia');
    await app.locator('input[aria-label="Téléphone"]').fill('555-0150');
    await app.getByRole('button', { name: 'OK', exact: true }).click();
    expect((await tab.waitCall('contacts:save')).data).toMatchObject({ phone: '555-0150' });
    await expect(app.getByRole('button', { name: /Eli Garcia/ })).toBeVisible();
    await app.getByRole('button', { name: 'Modifier' }).click();
    await app.getByRole('button', { name: 'Supprimer le contact' }).click();
    await tab.waitCall('contacts:delete');
    await expect(app.getByRole('button', { name: /Eli Garcia/ })).toHaveCount(0);
  });
  test('groupes, recherche, favori, message, partage', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Contacts');
    await app.getByRole('button', { name: 'LSPD' }).click();
    await expect(app.getByRole('button', { name: /Lina Costa/ })).toHaveCount(0);
    await expect(app.getByRole('button', { name: /Sam Leroy/ })).toBeVisible();
    await app.getByRole('button', { name: 'Tous', exact: true }).click();
    await app.getByLabel('Rechercher').fill('0199');
    await expect(app.getByRole('button', { name: /Del Perro/ })).toBeVisible();
    await app.getByLabel('Rechercher').fill('');
    await app.getByRole('button', { name: /Jade Moreau/ }).click();
    await app.getByRole('button', { name: 'favori' }).click();
    await expect(app.getByRole('button', { name: 'favori' })).toHaveAttribute('aria-pressed', 'true');
    await app.getByRole('button', { name: 'partager' }).click();
    await expect(app.getByText('Partager à proximité')).toBeVisible();
  });
  test('message depuis un contact ouvre Messages', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Contacts');
    await app.getByRole('button', { name: /Jade Moreau/ }).click();
    await app.getByRole('button', { name: 'message' }).click();
    await expect(tab.app.getByLabel('Message', { exact: true })).toBeVisible();
  });
});

test.describe('Mail', () => {
  test('lecture, drapeau, archive, rédaction, envoi', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Mail');
    await app.getByRole('button', { name: 'Votre véhicule est prêt' }).click();
    await expect(app.getByText(/prêt à être récupéré/).last()).toBeVisible();
    await tab.waitCall('mail:get');
    await app.getByText("Marquer d'un drapeau").click();
    await tab.waitCall('mail:flag');
    await expect(app.getByText('Retirer le drapeau')).toBeVisible();
    await app.getByRole('article').getByText('Archive').click();
    await tab.waitCall('mail:move');
    await app.getByRole('button', { name: 'Nouveau mail' }).click();
    await app.getByLabel('À').fill('lina.costa@pop.ls');
    await app.getByLabel('Objet').fill('Test');
    await app.getByLabel('Message').fill('Corps');
    await app.getByText('Envoyer').click();
    expect((await tab.waitCall('mail:send')).data).toMatchObject({ subject: 'Test' });
    await expect(app.getByText('Mail envoyé')).toBeVisible();
    for (const f of ['Envoyés', 'Corbeille', 'Brouillons']) await app.getByRole('button', { name: f }).click();
  });
});

test.describe('Navigateur', () => {
  test('site en jeu, signet, onglets, site refusé', async ({ tab }) => {
    // Le cadre d'un site du jeu pointe vers nui:// : un navigateur ordinaire ne connaît pas ce protocole (aucun souci en jeu).
    tab.ignoreErrors(/external protocol blocked by sandbox/);
    await tab.open();
    const app = await tab.openApp('Navigateur');
    await app.getByRole('button', { name: 'Weazel News' }).click();
    await expect(app.getByRole('article', { name: 'Weazel News' })).toBeVisible();
    await app.getByRole('button', { name: 'Ajouter un signet' }).click();
    await app.getByRole('button', { name: 'Nouvel onglet' }).click();
    await app.getByRole('button', { name: 'Annuaire' }).click();
    await expect(app.locator('iframe')).toHaveAttribute('sandbox', 'allow-scripts');
    await expect(app.locator('iframe')).toHaveAttribute('src', 'nui://pop_annuaire/web/index.html');
    const bar = app.getByRole('textbox', { name: 'Adresse' });
    await bar.fill('https://pirate.example/x');
    await bar.press('Enter');
    await expect(app.getByText('Site non autorisé')).toBeVisible();
    await app.getByRole('button', { name: 'Onglets' }).click();
    await expect(app.getByRole('dialog').getByRole('button', { name: "Fermer l'onglet" })).toHaveCount(2);
    await tab.waitCall('browser:save');
  });
});

test.describe('Musique', () => {
  test('station, favori, suivant, liste, lecteur', async ({ tab }) => {
    await tab.open();
    const app = await tab.openApp('Musique');
    await app.getByRole('button', { name: 'Groove Salad' }).click();
    await app.getByRole('button', { name: 'Ajouter aux favoris' }).first().click();
    await tab.waitCall('music:save');
    await app.getByRole('button', { name: 'Suivant' }).click();
    await tab.waitCall('music:state', (d) => JSON.stringify(d).includes('Secret Agent'));
    await app.getByRole('tab', { name: 'Listes' }).click();
    await app.getByText('Nouvelle liste').click();
    await app.getByLabel('Nom de la liste').fill('Route');
    await app.getByText('Créer').click();
    await tab.waitCall('music:save', (d) => JSON.stringify(d).includes('Route'));
    await app.getByRole('button', { name: 'Ouvrir le lecteur' }).click();
    await expect(tab.page.getByRole('dialog', { name: 'Lecteur' })).toBeVisible();
  });
});
