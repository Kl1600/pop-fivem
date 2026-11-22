// Sites en jeu fournis avec le Navigateur (ceux de la maquette). Contenu de démonstration : texte seul, jamais de HTML.
export interface Card { tag: string; title: string; sub: string; price: string; from: string; to: string }
export interface Site {
  key: string;
  name: string;
  host: string;
  ini: string;
  color: string;
  fg: string;
  hero: string;
  menu: string[];
  kicker: string;
  title: string;
  lead: string;
  cards: Card[];
}

const card = (tag: string, title: string, sub: string, price: string, from: string, to: string): Card => ({ tag, title, sub, price, from, to });

export const SITES: Site[] = [
  { key: 'lifeinvader', name: 'LifeInvader', host: 'lifeinvader.com', ini: 'LI', color: '#1d4ed8', fg: '#fff', hero: 'linear-gradient(120deg,#1e3a8a,#2563eb 60%,#60a5fa)', menu: ['Fil', 'Amis', 'Messages', 'Événements'], kicker: 'RÉSEAU SOCIAL', title: 'Retrouvez vos amis à Los Santos', lead: 'Partagez vos sorties, vos photos et vos bons plans.', cards: [card('JADE MOREAU', 'Concert à Vinewood Bowl samedi, qui vient ?', 'il y a 2 h · 14 j’aime', '', '#c026d3', '#6d28d9'), card('SAM LEROY', 'Belle soirée sur la jetée de Del Perro.', 'il y a 5 h · 32 j’aime', '', '#f59e0b', '#be123c'), card('LINA COSTA', 'Nouvelle collection en boutique dès demain !', 'hier · 21 j’aime', '', '#10b981', '#047857')] },
  { key: 'mazebank', name: 'Maze Bank', host: 'maze-bank.com', ini: 'MB', color: '#b91c1c', fg: '#fff', hero: 'linear-gradient(120deg,#7f1d1d,#b91c1c 60%,#f97316)', menu: ['Comptes', 'Cartes', 'Prêts', 'Investir'], kicker: 'BANQUE DE LOS SANTOS', title: 'Votre argent, en toute confiance', lead: 'Gérez vos comptes, vos virements et vos cartes en quelques gestes.', cards: [card('COMPTES', 'Compte courant', 'Sans frais de tenue de compte', '', '#ef4444', '#7f1d1d'), card('CARTES', 'Carte Platine', 'Retraits gratuits à Los Santos', '', '#475569', '#0f172a'), card('PRÊTS', 'Prêt immobilier', 'Taux dès 3,2 %', '', '#f59e0b', '#92400e')] },
  { key: 'weazel', name: 'Weazel News', host: 'weazelnews.com', ini: 'W', color: '#c8102e', fg: '#fff', hero: 'linear-gradient(120deg,#8a0b20,#c8102e 60%,#ff5a3c)', menu: ['À la une', 'Los Santos', 'Sport', 'Économie', 'Météo'], kicker: 'À LA UNE', title: 'Course-poursuite sur l’autoroute de Del Perro : trois interpellations', lead: 'Les forces de l’ordre ont interpellé trois suspects après une poursuite de vingt minutes entre Vinewood et le front de mer.', cards: [card('FAITS DIVERS', 'Un fourgon blanc recherché à Vinewood', 'Un témoin a relevé la plaque du véhicule suspect.', '', '#374151', '#9ca3af'), card('ÉCONOMIE', 'Le prix de l’essence en hausse à Sandy Shores', 'Les stations de la route 68 augmentent leurs tarifs.', '', '#f59e0b', '#b45309'), card('SPORT', 'Les Vinewood Stars s’imposent 3 à 1', 'Victoire à domicile devant 12 000 spectateurs.', '', '#10b981', '#065f46'), card('MÉTÉO', 'Grand soleil sur Los Santos ce week-end', '28 °C attendus sur la côte, vent faible.', '', '#38bdf8', '#0369a1'), card('CULTURE', 'Festival de musique à Vinewood Bowl', 'Trois soirées de concerts à partir de samedi.', '', '#a855f7', '#4c1d95'), card('SOCIÉTÉ', 'Paleto Bay : la pêche reprend en baie', 'Les pêcheurs retrouvent les bancs de thons.', '', '#0ea5e9', '#164e63')] },
  { key: 'legendary', name: 'Legendary Motorsport', host: 'legendarymotorsport.net', ini: 'LM', color: '#111111', fg: '#ffcc00', hero: 'linear-gradient(120deg,#000,#1f2937 60%,#b45309)', menu: ['Sportives', 'Coupés', 'SUV', 'Occasions'], kicker: 'CONCESSIONNAIRE · LOS SANTOS', title: 'Les plus belles voitures de la côte', lead: 'Neuves et d’occasion, essai gratuit sur rendez-vous.', cards: [card('SPORTIVE', 'Pfister Comet', '4,2 s de 0 à 100 km/h', '98 000 $', '#ef4444', '#111827'), card('COUPÉ', 'Ocelot Jackal', 'Boîte automatique, cuir', '42 000 $', '#3b82f6', '#111827'), card('SUV', 'Albany Cavalcade', '7 places, toit ouvrant', '56 000 $', '#6b7280', '#111827')] },
  { key: 'dynasty', name: 'Dynasty 8', host: 'dynasty8realestate.com', ini: 'D8', color: '#14532d', fg: '#fff', hero: 'linear-gradient(120deg,#052e16,#166534 60%,#65a30d)', menu: ['Acheter', 'Louer', 'Vendre', 'Nos agents'], kicker: 'ANNONCES DE LA SEMAINE', title: 'Trouvez votre bien à Los Santos', lead: 'Villas, appartements, garages et locaux commerciaux dans tout le comté de Blaine.', cards: [card('VENTE · VINEWOOD HILLS', 'Villa moderne avec piscine', '5 pièces · 320 m² · vue sur le panneau', '1 250 000 $', '#0ea5e9', '#1e3a8a'), card('LOCATION · DEL PERRO', 'Appartement face à la jetée', '2 pièces · 58 m²', '1 400 $ / mois', '#f97316', '#7c2d12'), card('LOCATION · DEL PERRO', 'Garage deux baies, pont élévateur', '140 m² · atelier équipé', '850 $ / mois', '#6b7280', '#111827'), card('VENTE · PALETO BAY', 'Maison de pêcheur rénovée', '3 pièces · 95 m² · terrasse', '285 000 $', '#14b8a6', '#134e4a')] },
];

export interface GameSite { domain: string; title: string; page: string }

/** Page demandée par le texte de la barre d'adresse. Pur : testé sans interface. */
export type Page =
  | { k: 'home' }
  | { k: 'site'; key: string }
  | { k: 'game'; domain: string }
  | { k: 'ext'; url: string; host: string }
  | { k: 'blocked'; host: string }
  | { k: 'miss'; text: string };

export function resolve(input: string, game: readonly GameSite[], hosts: readonly string[]): Page {
  const raw = input.trim();
  if (!raw) return { k: 'home' };
  const ext = /^https:\/\/([a-z0-9.-]+)(?:[/:?#].*)?$/i.exec(raw);
  if (ext) {
    const host = ext[1]!.toLowerCase();
    return hosts.includes(host) ? { k: 'ext', url: raw, host } : { k: 'blocked', host };
  }
  if (/^[a-z]+:\/\//i.test(raw) && !/^pop:\/\//i.test(raw)) return { k: 'blocked', host: raw.replace(/^([a-z]+:\/\/)?([^/]*).*$/i, '$2') };
  const q = raw.toLowerCase().replace(/^pop:\/\//, '').replace(/^https?:\/\//, '').replace(/^www\./, '').replace(/\/$/, '');
  const g = game.find((x) => x.domain === q) ?? game.find((x) => x.title.toLowerCase() === q);
  if (g) return { k: 'game', domain: g.domain };
  const s = SITES.find((x) => x.host === q || x.key === q) ?? SITES.find((x) => x.host.includes(q) || x.name.toLowerCase().includes(q));
  if (s) return { k: 'site', key: s.key };
  return { k: 'miss', text: raw };
}

/** Adresse affichée et enregistrée pour une page. */
export function addressOf(p: Page, game: readonly GameSite[]): string {
  switch (p.k) {
    case 'site': return SITES.find((x) => x.key === p.key)?.host ?? '';
    case 'game': return `pop://${game.find((x) => x.domain === p.domain)?.domain ?? p.domain}`;
    case 'ext': return p.url;
    default: return '';
  }
}
