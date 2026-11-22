const GTA_HAIR_COLORS = [
    '#0a0a0a','#161005','#271408','#3d2010','#5c3318','#73411f','#8a5028','#9e6b35',
    '#b8893e','#cca855','#ddc477','#ede8a8','#f5f5e0','#c8a060','#a07040','#6b2a1a',
    '#8c3a20','#a04828','#b86030','#c87840','#7a1010','#a01818','#c02020','#e02028',
    '#c06000','#e08000','#c0a000','#2a2a2a','#505050','#808080','#a8a8a8','#e8e8e8',
    '#050518','#0a0a40','#1010a0','#2030e0','#4060ff','#00a0c0','#008080','#050a05',
    '#0a1e0a','#0a3c0a','#0a7a0a','#20a020','#80c030','#200030','#500080','#8020d0',
    '#b060f0','#d040a0','#ff2080','#c020a0','#900060','#600040','#380020','#480010',
    '#300010','#1a0805','#0a0805','#050508','#050510','#080508','#050808','#302818'
];

const Config = {
    categories: [
        { id: "gender", label: "GENRE", icon: "fa-solid fa-venus-mars", type: "form" },
        { id: "genetics", label: "GÉNÉTIQUE", icon: "fa-solid fa-dna", type: "sliders" },
        { id: "features", label: "VISAGE", icon: "fa-solid fa-face-smile", type: "faceFeatures" },
        { id: "hair", label: "COIFFURE", icon: "fa-solid fa-scissors", type: "sliders" },
        { id: "beard", label: "BARBE", icon: "fa-solid fa-user-ninja", type: "sliders" },
        { id: "clothes", label: "VÊTEMENTS", icon: "fa-solid fa-shirt", type: "action" },
        { id: "tattoos", label: "TATOUAGES", icon: "fa-solid fa-paintbrush", type: "action" },
        { id: "arms", label: "BRAS", icon: "fa-solid fa-hand", type: "sliders" },
        // Onglet PEDS retiré : seuls les modèles freemode sont acceptés par le serveur
        { id: "size", label: "TAILLE", icon: "fa-solid fa-ruler-vertical", type: "sliders" },
        { id: "region", label: "RÉGION", icon: "fa-solid fa-earth-americas", type: "region" },
        { id: "save", label: "SAUVEGARDER", icon: "fa-solid fa-check", type: "action" }
    ],
    peds: [
        // --- PROTAGONISTS & MAIN CHARACTERS ---
        { label: "Michael De Santa", model: "player_zero" },
        { label: "Franklin Clinton", model: "player_one" },
        { label: "Trevor Philips", model: "player_two" },
        { label: "Lamar Davis", model: "ig_lamardavis" },
        { label: "Lester Crest", model: "ig_lestercrest" },
        { label: "Simeon Yetarian", model: "ig_simeonyetarian" },
        { label: "Jimmy De Santa", model: "ig_jimmydisanto" },
        { label: "Amanda De Santa", model: "ig_amanda_townley" },
        { label: "Tracy De Santa", model: "ig_tracy_disanto" },
        { label: "Paige Harris", model: "ig_paige" },
        { label: "Tanisha Jackson", model: "ig_tanisha" },
        { label: "Marnie Allen", model: "ig_marnie" },
        { label: "Tonya Wiggins", model: "ig_tonya" },
        { label: "Karen Daniels", model: "ig_karen_daniels" },
        { label: "Ron Jakowski", model: "ig_ron" },
        { label: "Wade Hebert", model: "ig_wade" },
        { label: "Chef Cuisinier", model: "ig_chef" },
        { label: "Lazlow Jones", model: "ig_lazlow" },
        { label: "Patricia Madrazo", model: "ig_patricia" },
        { label: "English Dave", model: "ig_englishdave" },
        { label: "Tony Prince", model: "ig_tonyprince" },
        { label: "Lacey Jonas", model: "ig_lacey_jonas" },
        { label: "Ashley Butler", model: "ig_ashley" },

        // --- PUBLIC SERVICES & FORCE ---
        { label: "Flic LSPD", model: "s_m_y_cop_01" },
        { label: "SWAT Agent", model: "s_m_y_swat_01" },
        { label: "SWAT Lourd", model: "s_m_m_swat_01" },
        { label: "Black Ops (H)", model: "s_m_y_blackops_01" },
        { label: "Black Ops Lourd", model: "s_m_y_blackops_02" },
        { label: "Militaire Marine", model: "s_m_y_marine_01" },
        { label: "Officier Armée", model: "s_m_m_armoured_01" },
        { label: "FBI Agent", model: "s_m_m_fiboffice_01" },
        { label: "IAA / CIA Agent", model: "s_m_m_ciasec_01" },
        { label: "Pompier", model: "s_m_y_fireman_01" },
        { label: "Médecin (H)", model: "s_m_y_paramedic_01" },
        { label: "Médecin (F)", model: "s_f_y_scrubs_01" },
        { label: "Docteur LSPD", model: "s_m_m_doctor_01" },
        { label: "Sheriff (H)", model: "s_m_y_sheriff_01" },
        { label: "Sheriff (F)", model: "s_f_y_sheriff_01" },
        { label: "Ranger Forestier", model: "s_m_y_ranger_01" },
        { label: "Police Autoroute", model: "s_m_y_hwaycop_01" },
        { label: "Garde Prison", model: "s_m_m_prisguard_01" },

        // --- GANGS & UNDERGROUND ---
        { label: "Ballas OG", model: "csb_ballasog" },
        { label: "Ballas Gangster", model: "g_m_y_ballaeast_01" },
        { label: "Ballas Elite", model: "g_m_y_ballaorig_01" },
        { label: "Ballas (F)", model: "g_f_y_ballas_01" },
        { label: "Vagos Leader", model: "csb_vagos_leader" },
        { label: "Vagos Member", model: "g_m_y_vagos_01" },
        { label: "Vagos (F)", model: "g_f_y_vagos_01" },
        { label: "Families Member", model: "g_m_y_famdnf_01" },
        { label: "Families South", model: "g_m_y_famca_01" },
        { label: "Families (F)", model: "g_f_y_families_01" },
        { label: "Marabunta Gang", model: "g_m_y_salvagoon_01" },
        { label: "Lost MC Biker 1", model: "g_m_y_lost_01" },
        { label: "Lost MC Biker 2", model: "g_m_y_lost_02" },
        { label: "Dealer", model: "s_m_y_dealer_01" },

        // --- JOBS & SERVICES ---
        { label: "Garde Sécurité", model: "s_m_m_security_01" },
        { label: "Éboueur", model: "s_m_y_garbage" },
        { label: "Mécanicien", model: "s_m_y_mechanic_01" },
        { label: "Serveur", model: "s_m_y_valet_01" },
        { label: "Serveuse (F)", model: "s_f_y_waitress_01" },
        { label: "Barman (F)", model: "s_f_y_bartender_01" },
        { label: "Livreur Cluckin", model: "s_m_y_cluckco_01" },
        { label: "Ouvrier Chantier", model: "s_m_y_construct_01" },

        // --- CITIZENS & CIVILIAN LIFE ---
        { label: "Plage (H)", model: "a_m_y_beach_01" },
        { label: "Plage (F)", model: "a_f_y_beach_01" },
        { label: "Business (H)", model: "a_m_y_business_01" },
        { label: "Business (F)", model: "a_f_y_business_01" },
        { label: "Cycliste (H)", model: "a_m_y_cyclist_01" },
        { label: "Hipster (H)", model: "a_m_y_hipster_01" },
        { label: "Hipster (F)", model: "a_f_y_hipster_01" },
        { label: "Skater (H)", model: "a_m_y_skater_01" },
        { label: "Fitness (F)", model: "a_f_y_fitness_01" },
        { label: "Touriste (H)", model: "a_m_y_tourist_01" },
        { label: "Touriste (F)", model: "a_f_y_tourist_01" },
        { label: "Muscle Beach", model: "a_m_y_musclbeac_01" },
        { label: "Hillbilly", model: "a_m_m_hillbilly_01" },
        { label: "Fermier", model: "a_m_m_farmer_01" },
        { label: "Randonneuse (F)", model: "a_f_y_hiker_01" },
        { label: "Hippie (F)", model: "a_f_y_hippie_01" },
        { label: "Joueuse Tennis", model: "a_f_y_tennis_01" },
        { label: "Golfeur (H)", model: "a_m_m_golfer_01" },
        { label: "Golfeuse (F)", model: "a_f_m_golfer_01" },

        // --- SPECIALS & UNDERWORLD ---
        { label: "Epsilonist (H)", model: "a_m_y_epsilon_01" },
        { label: "Epsilonist (F)", model: "a_f_y_epsilon_01" },
        { label: "Prisonnier", model: "s_m_y_prisoner_01" },
        { label: "Stripper 1 (F)", model: "s_f_y_stripper_01" },
        { label: "Stripper 2 (F)", model: "s_f_y_stripper_02" },
        { label: "Hooker 1 (F)", model: "s_f_y_hooker_01" },
        { label: "Hooker 2 (F)", model: "s_f_y_hooker_02" },
        { label: "Mime", model: "u_m_y_mime" },
        { label: "Astronaute", model: "s_m_m_movspace_01" },
        { label: "Zombie", model: "u_m_y_zombie_01" },
        { label: "Alien", model: "u_m_y_alien_01" },
        { label: "Clown", model: "u_m_y_clown_01" },
        { label: "Jésus", model: "u_m_y_impartial" }
    ],
    genetics: [
        { label: "PÈRE", id: "mom", min: 0, max: 45 },
        { label: "MÈRE", id: "dad", min: 0, max: 45 },
        { label: "RESSEMBLANCE", id: "face_md_weight", min: 0, max: 100 },
        { label: "COULEUR DE PEAU", id: "skin_md_weight", min: 0, max: 100 }
    ],
    size: [
        { label: "TAILLE", id: "height", min: 1, max: 3 }
    ],
    features: [
        { label: "NEZ", x: { id: "nose_1", min: -10, max: 10, labelMin: "Étroit", labelMax: "Large" }, y: { id: "nose_2", min: -10, max: 10, labelMin: "Haut", labelMax: "Bas" } },
        { label: "PROFIL NEZ", x: { id: "nose_3", min: -10, max: 10, labelMin: "Court", labelMax: "Long" }, y: { id: "nose_4", min: -10, max: 10, labelMin: "Courbé", labelMax: "Droit" } },
        { label: "BOUT NEZ", x: { id: "nose_5", min: -10, max: 10, labelMin: "Haut", labelMax: "Bas" }, y: { id: "nose_6", min: -10, max: 10, labelMin: "Gauche", labelMax: "Droite" } },
        { label: "SOURCILS", x: { id: "eyebrows_5", min: -10, max: 10, labelMin: "Haut", labelMax: "Bas" }, y: { id: "eyebrows_6", min: -10, max: 10, labelMin: "Profond", labelMax: "Saillant" } },
        { label: "POMMETTES", x: { id: "cheeks_1", min: -10, max: 10, labelMin: "Haut", labelMax: "Bas" }, y: { id: "cheeks_2", min: -10, max: 10, labelMin: "Creuses", labelMax: "Bombées" } },
        { label: "JOUES", x: { id: "cheeks_3", min: -10, max: 10, labelMin: "Minces", labelMax: "Larges" }, y: null },
        { label: "YEUX & LÈVRES", x: { id: "eyes_1", min: -10, max: 10, labelMin: "Ouverts", labelMax: "Fermés" }, y: { id: "lips_1", min: -10, max: 10, labelMin: "Fines", labelMax: "Épaisses" } },
        { label: "MÂCHOIRE", x: { id: "jaw_1", min: -10, max: 10, labelMin: "Étroite", labelMax: "Large" }, y: { id: "jaw_2", min: -10, max: 10, labelMin: "Ronde", labelMax: "Carrée" } },
        { label: "MENTON", x: { id: "chin_1", min: -10, max: 10, labelMin: "Haut", labelMax: "Bas" }, y: { id: "chin_2", min: -10, max: 10, labelMin: "Court", labelMax: "Long" } },
        { label: "FORME MENTON", x: { id: "chin_3", min: -10, max: 10, labelMin: "Étroit", labelMax: "Large" }, y: { id: "chin_4", min: -10, max: 10, labelMin: "Rond", labelMax: "Creux" } }
    ],
    hair: [
        { label: "COUPES", id: "hair_1", min: 0, max: 150 },
        { label: "COULEUR (BASE)", id: "hair_color_1", min: 0, max: 63, colorPicker: true },
        { label: "COULEUR (MÈCHES)", id: "hair_color_2", min: 0, max: 63, colorPicker: true },
        { label: "STYLE SOURCILS", id: "eyebrows_1", min: 0, max: 33 },
        { label: "OPACITÉ SOURCILS", id: "eyebrows_2", min: 0, max: 10 }
    ],
    beard: [
        { label: "STYLE BARBE", id: "beard_1", min: -1, max: 28 },
        { label: "OPACITÉ BARBE", id: "beard_2", min: 0, max: 10 },
        { label: "COULEUR BARBE", id: "beard_3", min: 0, max: 63, colorPicker: true },
        { label: "COULEUR SOURCILS", id: "eyebrows_3", min: 0, max: 63, colorPicker: true }
    ],
    arms: [
        { label: "STYLE BRAS / GANTS", id: "arms", min: 0, max: 200 },
        { label: "COULEUR BRAS", id: "arms_2", min: 0, max: 20 }
    ],
    parentImages: {
        0: "https://static.wikia.nocookie.net/gtawiki/images/0/0b/CharacterCreator-GTAO-Parent-Male-Benjamin.png",
        1: "https://static.wikia.nocookie.net/gtawiki/images/2/21/CharacterCreator-GTAO-Parent-Male-Daniel.png",
        2: "https://static.wikia.nocookie.net/gtawiki/images/d/df/CharacterCreator-GTAO-Parent-Male-Joshua.png",
        3: "https://static.wikia.nocookie.net/gtawiki/images/4/4c/CharacterCreator-GTAO-Parent-Male-Noah.png",
        4: "https://static.wikia.nocookie.net/gtawiki/images/7/77/CharacterCreator-GTAO-Parent-Male-Andrew.png",
        5: "https://static.wikia.nocookie.net/gtawiki/images/f/f0/CharacterCreator-GTAO-Parent-Male-Joan.png",
        6: "https://static.wikia.nocookie.net/gtawiki/images/7/7d/CharacterCreator-GTAO-Parent-Male-Alex.png",
        7: "https://static.wikia.nocookie.net/gtawiki/images/9/95/CharacterCreator-GTAO-Parent-Male-Isaac.png",
        8: "https://static.wikia.nocookie.net/gtawiki/images/d/dd/CharacterCreator-GTAO-Parent-Male-Evan.png",
        9: "https://static.wikia.nocookie.net/gtawiki/images/7/70/CharacterCreator-GTAO-Parent-Male-Ethan.png",
        10: "https://static.wikia.nocookie.net/gtawiki/images/e/e3/CharacterCreator-GTAO-Parent-Male-Vincent.png",
        11: "https://static.wikia.nocookie.net/gtawiki/images/6/6c/CharacterCreator-GTAO-Parent-Male-Angel.png",
        12: "https://static.wikia.nocookie.net/gtawiki/images/8/80/CharacterCreator-GTAO-Parent-Male-Diego.png",
        13: "https://static.wikia.nocookie.net/gtawiki/images/7/74/CharacterCreator-GTAO-Parent-Male-Adrian.png",
        14: "https://static.wikia.nocookie.net/gtawiki/images/5/5f/CharacterCreator-GTAO-Parent-Male-Gabriel.png",
        15: "https://static.wikia.nocookie.net/gtawiki/images/4/44/CharacterCreator-GTAO-Parent-Male-Michael.png",
        16: "https://static.wikia.nocookie.net/gtawiki/images/b/b6/CharacterCreator-GTAO-Parent-Male-Santiago.png",
        17: "https://static.wikia.nocookie.net/gtawiki/images/3/33/CharacterCreator-GTAO-Parent-Male-Kevin.png",
        18: "https://static.wikia.nocookie.net/gtawiki/images/2/27/CharacterCreator-GTAO-Parent-Male-Louis.png",
        19: "https://static.wikia.nocookie.net/gtawiki/images/4/46/CharacterCreator-GTAO-Parent-Male-Samuel.png",
        20: "https://static.wikia.nocookie.net/gtawiki/images/3/31/CharacterCreator-GTAO-Parent-Male-Anthony.png",
        21: "https://static.wikia.nocookie.net/gtawiki/images/b/b9/CharacterCreator-GTAO-Parent-Female-Hannah.png",
        22: "https://static.wikia.nocookie.net/gtawiki/images/1/14/CharacterCreator-GTAO-Parent-Female-Audrey.png",
        23: "https://static.wikia.nocookie.net/gtawiki/images/0/07/CharacterCreator-GTAO-Parent-Female-Jasmine.png",
        24: "https://static.wikia.nocookie.net/gtawiki/images/d/d1/CharacterCreator-GTAO-Parent-Female-Giselle.png",
        25: "https://static.wikia.nocookie.net/gtawiki/images/b/b3/CharacterCreator-GTAO-Parent-Female-Amelia.png",
        26: "https://static.wikia.nocookie.net/gtawiki/images/5/5c/CharacterCreator-GTAO-Parent-Female-Isabella.png",
        27: "https://static.wikia.nocookie.net/gtawiki/images/3/34/CharacterCreator-GTAO-Parent-Female-Zoe.png",
        28: "https://static.wikia.nocookie.net/gtawiki/images/5/51/CharacterCreator-GTAO-Parent-Female-Ava.png",
        29: "https://static.wikia.nocookie.net/gtawiki/images/7/77/CharacterCreator-GTAO-Parent-Female-Camila.png",
        30: "https://static.wikia.nocookie.net/gtawiki/images/e/e1/CharacterCreator-GTAO-Parent-Female-Violet.png",
        31: "https://static.wikia.nocookie.net/gtawiki/images/5/5b/CharacterCreator-GTAO-Parent-Female-Sophia.png",
        32: "https://static.wikia.nocookie.net/gtawiki/images/9/9b/CharacterCreator-GTAO-Parent-Female-Evelyn.png",
        33: "https://static.wikia.nocookie.net/gtawiki/images/e/e3/CharacterCreator-GTAO-Parent-Female-Nicole.png",
        34: "https://static.wikia.nocookie.net/gtawiki/images/6/60/CharacterCreator-GTAO-Parent-Female-Ashley.png",
        35: "https://static.wikia.nocookie.net/gtawiki/images/b/b5/CharacterCreator-GTAO-Parent-Female-Grace.png",
        36: "https://static.wikia.nocookie.net/gtawiki/images/5/51/CharacterCreator-GTAO-Parent-Female-Brianna.png",
        37: "https://static.wikia.nocookie.net/gtawiki/images/2/25/CharacterCreator-GTAO-Parent-Female-Natalie.png",
        38: "https://static.wikia.nocookie.net/gtawiki/images/1/15/CharacterCreator-GTAO-Parent-Female-Olivia.png",
        39: "https://static.wikia.nocookie.net/gtawiki/images/e/e3/CharacterCreator-GTAO-Parent-Female-Elizabeth.png",
        40: "https://static.wikia.nocookie.net/gtawiki/images/2/20/CharacterCreator-GTAO-Parent-Female-Charlotte.png",
        41: "https://static.wikia.nocookie.net/gtawiki/images/9/97/CharacterCreator-GTAO-Parent-Female-Emma.png",
        42: "https://static.wikia.nocookie.net/gtawiki/images/2/2a/CharacterCreator-GTAO-Parent-Male-Claude.png",
        43: "https://static.wikia.nocookie.net/gtawiki/images/6/65/CharacterCreator-GTAO-Parent-Male-John.png",
        44: "https://static.wikia.nocookie.net/gtawiki/images/a/ae/CharacterCreator-GTAO-Parent-Male-Niko.png",
        45: "https://static.wikia.nocookie.net/gtawiki/images/a/a6/CharacterCreator-GTAO-Parent-Female-Misty.png"
    }
};

let currentCategory = 'gender';
let currentGender = 'male';
let currentSpawn = 'losantos'; // lieu d'apparition choisi (clé Config.SpawnPoints, voir config.lua)
const characterData = {
    height: 2
};
let maxCounts = {};
let isVIP = false;

let enableHeight = true;

function init() {
    const list = document.getElementById('category-list');
    list.innerHTML = '';

    Config.categories.forEach(cat => {
        if (cat.id === 'size' && !enableHeight) return;

        const div = document.createElement('div');
        div.className = `category-item ${cat.id === currentCategory ? 'active' : ''}`;
        div.innerHTML = `<div class="icon"><i class="${cat.icon}"></i></div>`;
        div.onclick = () => switchCategory(cat.id);
        list.appendChild(div);
    });

    document.querySelectorAll('.gender-btn').forEach(btn => {
        btn.onclick = function () {
            document.querySelectorAll('.gender-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            currentGender = this.getAttribute('data-gender');
            
            const infoMsg = document.getElementById('gender-info');
            if (currentGender === 'other') {
                infoMsg.style.display = 'flex';
                // Randomly choose male/female for the actual model switch
                const randomGender = Math.random() > 0.5 ? 'male' : 'female';
                fetch(`https://${GetParentResourceName()}/updateGender`, {
                    method: 'POST',
                    body: JSON.stringify({ gender: randomGender })
                });
            } else {
                infoMsg.style.display = 'none';
                fetch(`https://${GetParentResourceName()}/updateGender`, {
                    method: 'POST',
                    body: JSON.stringify({ gender: currentGender })
                });
            }
        };
    });

    // Cartes de région (Los Santos / Nuevo Paso). On mémorise la clé choisie
    // (data-spawn), transmise au client Lua au moment de finish().
    document.querySelectorAll('.region-card').forEach(card => {
        card.onclick = function () {
            document.querySelectorAll('.region-card').forEach(c => c.classList.remove('active'));
            this.classList.add('active');
            currentSpawn = this.getAttribute('data-spawn');
        };
    });

    switchCategory('gender');
}

function switchCategory(id) {
    if (id === 'save') {
        showConfirmModal();
        return;
    } else if (id === 'clothes') {
        fetch(`https://${GetParentResourceName()}/openClothes`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({})
        });
        return;
    } else if (id === 'tattoos') {
        fetch(`https://${GetParentResourceName()}/openTattoos`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({})
        });
        return;
    }

    currentCategory = id;
    const cat = Config.categories.find(c => c.id === id);

    document.querySelectorAll('.category-item').forEach((el, i) => {
        if (Config.categories[i].id === id) el.classList.add('active');
        else el.classList.remove('active');
    });

    document.getElementById('category-title').innerText = cat.label;

    const sectionGender = document.getElementById('section-gender');
    if (sectionGender) sectionGender.style.display = (cat.type === 'form' ? 'block' : 'none');
    
    document.getElementById('grid-container').style.display = (cat.type === 'grid' ? 'flex' : 'none');
    document.getElementById('slider-container').style.display = (cat.type === 'sliders' && id !== 'size' ? 'block' : 'none');
    document.getElementById('face-features-container').style.display = (cat.type === 'faceFeatures' ? 'flex' : 'none');
    document.getElementById('size-container').style.display = (id === 'size' ? 'flex' : 'none');
    document.getElementById('section-peds').style.display = (id === 'peds' ? 'block' : 'none');

    const sectionRegion = document.getElementById('section-region');
    if (sectionRegion) sectionRegion.style.display = (cat.type === 'region' ? 'block' : 'none');

    if (id === 'peds') {
        renderPeds();
    }

    fetch(`https://${GetParentResourceName()}/switchCategory`, {
        method: 'POST',
        body: JSON.stringify({ category: id })
    });

    if (id === 'size') {
        renderRuler();
    } else if (cat.type === 'sliders') {
        setTimeout(() => {
            renderSliders(Config[cat.id]);
        }, 100);
    } else if (cat.type === 'faceFeatures') {
        setTimeout(() => {
            renderFaceGrids(Config[cat.id]);
        }, 100);
    } else if (cat.type === 'grid') {
        setTimeout(() => {
            renderGrid(cat);
        }, 100);
    }
}

function renderRuler() {
    const container = document.getElementById('size-container');
    container.innerHTML = `
        <div class="ruler-container">
            <div class="ruler-track"></div>
            <div class="ruler-indicator" id="ruler-indicator"></div>
            <div class="ruler-mark" data-val="3" data-label="Grande"></div>
            <div class="ruler-mark" data-val="2" data-label="Moyenne"></div>
            <div class="ruler-mark" data-val="1" data-label="Petite"></div>
        </div>
    `;

    const indicator = document.getElementById('ruler-indicator');
    const marks = container.querySelectorAll('.ruler-mark');
    const currentSize = characterData['height'] || 2;

    const updateIndicator = (val, element) => {
        const rect = element.getBoundingClientRect();
        const containerRect = element.parentElement.getBoundingClientRect();
        const top = rect.top - containerRect.top + (rect.height / 2) - 6;
        indicator.style.top = `${top}px`;
        
        marks.forEach(m => m.classList.remove('active'));
        element.classList.add('active');
        
        characterData['height'] = parseInt(val);
        fetch(`https://${GetParentResourceName()}/updateAppearance`, {
            method: 'POST',
            body: JSON.stringify({ id: 'height', value: parseInt(val) })
        });
    };

    marks.forEach(mark => {
        const val = mark.getAttribute('data-val');
        if (parseInt(val) === currentSize) {
            setTimeout(() => updateIndicator(val, mark), 50);
        }
        mark.onclick = () => updateIndicator(val, mark);
    });
}

function renderPeds() {
    const container = document.getElementById('peds-list');
    container.innerHTML = '';

    const section = document.getElementById('section-peds');
    
    // Remove existing lock
    const existingLock = section.querySelector('.vip-lock-overlay');
    if (existingLock) existingLock.remove();

    Config.peds.forEach(ped => {
        const isLocked = !isVIP;
        const div = document.createElement('div');
        div.className = `ped-item ${characterData.model === ped.model ? 'active' : ''} ${isLocked ? 'locked' : ''}`;
        
        const imgHtml = `<img src="https://docs.fivem.net/peds/${ped.model}.webp" class="ped-img" onerror="this.src='https://ui-avatars.com/api/?name=${ped.label}&background=202020&color=fff'">`;

        if (isLocked) {
            div.innerHTML = `
                <div class="ped-img-wrap">${imgHtml}</div>
                <div class="ped-lock"><i class="fas fa-lock"></i></div>
                <span>${ped.label}</span>
            `;
            div.onclick = () => {
                // Do nothing or play error sound
            };
        } else {
            div.innerHTML = `
                <div class="ped-img-wrap">${imgHtml}</div>
                <span>${ped.label}</span>
            `;
            div.onclick = () => {
                document.querySelectorAll('.ped-item').forEach(el => el.classList.remove('active'));
                div.classList.add('active');
                characterData.model = ped.model;
                fetch(`https://${GetParentResourceName()}/updateModel`, {
                    method: 'POST',
                    body: JSON.stringify({ model: ped.model })
                });
            };
        }
        
        container.appendChild(div);
    });
}

function renderSliders(items) {
    const container = document.getElementById('slider-container');
    container.innerHTML = '';
    
    const isGenetics = (currentCategory === 'genetics');
    let slidersContainer = container;

    if (isGenetics) {
        const geneticsWrap = document.createElement('div');
        geneticsWrap.className = 'genetics-container';
        
        const previewWrap = document.createElement('div');
        previewWrap.className = 'parents-preview';
        
        const dadId = characterData['mom'] || 0;
        const momId = characterData['dad'] || 0;
        
        previewWrap.innerHTML = `
            <div class="parent-box">
                <div class="parent-img-wrap">
                    <img id="img-dad" src="${Config.parentImages[dadId] || ''}" class="parent-img" onerror="this.src='https://ui-avatars.com/api/?name=P&background=5695C8&color=fff'">
                </div>
                <span class="parent-label">PÈRE</span>
            </div>
            <div class="parent-box">
                <div class="parent-img-wrap">
                    <img id="img-mom" src="${Config.parentImages[momId] || ''}" class="parent-img" onerror="this.src='https://ui-avatars.com/api/?name=M&background=8e44ad&color=fff'">
                </div>
                <span class="parent-label">MÈRE</span>
            </div>
        `;
        
        geneticsWrap.appendChild(previewWrap);
        
        const slidersWrap = document.createElement('div');
        slidersWrap.className = 'genetics-sliders';
        geneticsWrap.appendChild(slidersWrap);
        
        container.appendChild(geneticsWrap);
        slidersContainer = slidersWrap;
    }

    items.forEach(item => {
        const maximum = maxCounts[item.id] || item.max;
        const val = characterData[item.id] || 0;
        const div = document.createElement('div');

        if (item.colorPicker) {
            div.className = 'range-group color-picker-wrap';
            div.innerHTML = `
                <div class="range-header">
                    <label>${item.label}</label>
                    <span class="color-swatch-preview" id="preview-${item.id}" style="background:${GTA_HAIR_COLORS[val] || '#000'}"></span>
                </div>
                <div class="color-swatch-grid" id="swatches-${item.id}"></div>
            `;
            slidersContainer.appendChild(div);

            const grid = div.querySelector('.color-swatch-grid');
            for (let i = 0; i <= maximum; i++) {
                const swatch = document.createElement('div');
                swatch.className = 'color-swatch' + (i === val ? ' selected' : '');
                swatch.style.background = GTA_HAIR_COLORS[i] || '#000';
                swatch.title = `#${i}`;
                swatch.onclick = () => {
                    grid.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('selected'));
                    swatch.classList.add('selected');
                    characterData[item.id] = i;
                    document.getElementById(`preview-${item.id}`).style.background = GTA_HAIR_COLORS[i] || '#000';
                    fetch(`https://${GetParentResourceName()}/updateAppearance`, {
                        method: 'POST',
                        body: JSON.stringify({ id: item.id, value: i })
                    });
                };
                grid.appendChild(swatch);
            }
            return;
        }

        let displayVal = val;
        if (item.id === 'height') {
            displayVal = val === 1 ? "Petite" : val === 2 ? "Moyenne" : "Grande";
        }

        div.className = 'range-group';
        div.innerHTML = `
            <div class="range-header">
                <label>${item.label}</label>
                <span class="val" id="val-${item.id}">${displayVal}</span>
            </div>
            <input type="range" id="${item.id}" min="${item.min}" max="${maximum}" value="${val}">
        `;
        const slider = div.querySelector('input');
        slider.oninput = function () {
            const v = parseInt(this.value);

            let dVal = v;
            if (item.id === 'height') {
                dVal = v === 1 ? "Petite" : v === 2 ? "Moyenne" : "Grande";
            }

            document.getElementById(`val-${item.id}`).innerText = dVal;
            characterData[item.id] = v;

            if (isGenetics) {
                if (item.id === 'mom') {
                    document.getElementById('img-dad').src = Config.parentImages[v] || '';
                } else if (item.id === 'dad') {
                    document.getElementById('img-mom').src = Config.parentImages[v] || '';
                }
            }

            fetch(`https://${GetParentResourceName()}/updateAppearance`, {
                method: 'POST',
                body: JSON.stringify({ id: item.id, value: v })
            });
        };
        slidersContainer.appendChild(div);
    });
}

function renderFaceGrids(items) {
    const container = document.getElementById('face-features-container');
    container.innerHTML = '';

    items.forEach(group => {
        const div = document.createElement('div');
        div.className = 'face-grid-item';
        div.innerHTML = `
            <div class="face-grid-label">${group.label}</div>
            <div class="face-grid" id="grid-${group.x.id}">
                ${group.x ? `<div class="face-grid-axis-label axis-left">${group.x.labelMin}</div><div class="face-grid-axis-label axis-right">${group.x.labelMax}</div>` : ''}
                ${group.y ? `<div class="face-grid-axis-label axis-top">${group.y.labelMin}</div><div class="face-grid-axis-label axis-bottom">${group.y.labelMax}</div>` : ''}
                <div class="face-grid-cursor" id="cursor-${group.x.id}"></div>
            </div>
        `;

        const grid = div.querySelector('.face-grid');
        const cursor = div.querySelector('.face-grid-cursor');

        const updatePosition = (e) => {
            const rect = grid.getBoundingClientRect();
            let x = (e.clientX - rect.left) / rect.width;
            let y = (e.clientY - rect.top) / rect.height;

            x = Math.max(0, Math.min(1, x));
            y = Math.max(0, Math.min(1, y));

            cursor.style.left = `${x * 100}%`;
            cursor.style.top = `${y * 100}%`;

            // Convert 0..1 to -10..10 (or whatever min/max is)
            if (group.x) {
                const valX = Math.round((x * (group.x.max - group.x.min)) + group.x.min);
                characterData[group.x.id] = valX;
                fetch(`https://${GetParentResourceName()}/updateAppearance`, {
                    method: 'POST',
                    body: JSON.stringify({ id: group.x.id, value: valX })
                });
            }

            if (group.y) {
                const valY = Math.round((y * (group.y.max - group.y.min)) + group.y.min);
                characterData[group.y.id] = valY;
                fetch(`https://${GetParentResourceName()}/updateAppearance`, {
                    method: 'POST',
                    body: JSON.stringify({ id: group.y.id, value: valY })
                });
            }
        };

        // Initial cursor position
        const initX = characterData[group.x.id] || 0;
        const initY = group.y ? (characterData[group.y.id] || 0) : 0;
        
        const percX = (initX - group.x.min) / (group.x.max - group.x.min);
        cursor.style.left = `${percX * 100}%`;
        
        if (group.y) {
            const percY = (initY - group.y.min) / (group.y.max - group.y.min);
            cursor.style.top = `${percY * 100}%`;
        } else {
            cursor.style.top = '50%';
        }

        let isDragging = false;
        grid.onmousedown = (e) => {
            isDragging = true;
            updatePosition(e);
        };

        window.addEventListener('mousemove', (e) => {
            if (isDragging) updatePosition(e);
        });

        window.addEventListener('mouseup', () => {
            isDragging = false;
        });

        container.appendChild(div);
    });
}

function showConfirmModal() {
    const input = document.getElementById('dateofbirth');
    const errEl = document.getElementById('dateofbirth-error');
    const dobError = validateBirthDate(input.value.trim());
    if (dobError) {
        input.classList.add('invalid');
        if (errEl) errEl.textContent = dobError;
        switchCategory('gender');
        input.focus();
        return;
    }
    input.classList.remove('invalid');
    if (errEl) errEl.textContent = '';

    const modal = document.getElementById('confirm-modal');
    modal.style.display = 'flex';

    document.getElementById('confirm-yes').onclick = () => {
        modal.style.display = 'none';
        finish();
    };

    document.getElementById('confirm-no').onclick = () => {
        modal.style.display = 'none';
    };
}

function finish() {
    const fn = document.getElementById('firstname').value.trim() || "John";
    const ln = document.getElementById('lastname').value.trim() || "Doe";
    const dob = document.getElementById('dateofbirth').value.trim() || "01/01/1990";

    fetch(`https://${GetParentResourceName()}/finish`, {
        method: 'POST',
        body: JSON.stringify({
            appearance: characterData,
            gender: currentGender,
            firstname: fn,
            lastname: ln,
            dateofbirth: dob,
            spawn: currentSpawn
        })
    });
}

// Date de naissance : format JJ/MM/AAAA, les « / » s'ajoutent tout seuls.
function applyBirthDateRule() {
    const input = document.getElementById('dateofbirth');
    if (!input) return;
    input.readOnly = false;
    input.classList.remove('locked');
    input.inputMode = 'numeric';
}

function formatBirthDate(raw) {
    const d = (raw || '').replace(/\D/g, '').slice(0, 8);
    if (d.length > 4) return `${d.slice(0, 2)}/${d.slice(2, 4)}/${d.slice(4)}`;
    if (d.length > 2) return `${d.slice(0, 2)}/${d.slice(2)}`;
    return d;
}

(function bindBirthDateInput() {
    const input = document.getElementById('dateofbirth');
    if (!input) return;
    input.addEventListener('input', (e) => {
        // Effacement : on laisse supprimer le « / » sans le remettre aussitôt.
        if (e.inputType && e.inputType.startsWith('delete')) {
            const v = input.value.replace(/[^\d/]/g, '');
            if (v !== input.value) input.value = v;
        } else {
            input.value = formatBirthDate(input.value);
        }
        input.classList.remove('invalid');
        const errEl = document.getElementById('dateofbirth-error');
        if (errEl) errEl.textContent = '';
    });
})();

// Renvoie null si la date est valide, sinon un message d'erreur.
function validateBirthDate(value) {
    const m = (value || '').match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
    if (!m) return "Date de naissance invalide (JJ/MM/AAAA).";
    const day = parseInt(m[1], 10), month = parseInt(m[2], 10), year = parseInt(m[3], 10);
    const date = new Date(year, month - 1, day);
    if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
        return "Cette date n'existe pas.";
    }
    return null;
}

window.addEventListener('message', (event) => {
    if (event.data.action === 'openCreator') {
        document.getElementById('app').style.display = 'block';
        document.body.classList.toggle('theme-80s', !!event.data.mode80s);
        applyBirthDateRule(event.data.birthDate);
        enableHeight = event.data.enableHeight !== false;
        init();
    } else if (event.data.action === 'closeCreator') {
        document.getElementById('app').style.display = 'none';
    } else if (event.data.action === 'updateMax') {
        maxCounts[event.data.id] = event.data.max;
        const currentCatObj = Config.categories.find(c => c.id === currentCategory);
        if (currentCatObj && currentCatObj.type === 'sliders' && Config[currentCategory]) {
            renderSliders(Config[currentCategory]);
        } else if (currentCatObj && currentCatObj.type === 'grid' && currentCatObj.comp === event.data.id) {
            renderGrid(currentCatObj);
        }
    } else if (event.data.action === 'setVIP') {
        isVIP = event.data.isVIP;
    }
});



let isDraggingRot = false;
let isDraggingHeight = false;
let lastX = 0;
let lastY = 0;

document.addEventListener('mousedown', (e) => {
    if (e.target.tagName === 'INPUT' || e.target.closest('#category-list') || e.target.closest('.main-content')) {
        return;
    }
    
    if (e.button === 0) { isDraggingRot = true; } // Click gauche
    if (e.button === 2) { isDraggingHeight = true; } // Click droit

    lastX = e.clientX;
    lastY = e.clientY;
});

document.addEventListener('contextmenu', event => event.preventDefault());

document.addEventListener('mouseup', () => {
    isDraggingRot = false;
    isDraggingHeight = false;
});

document.addEventListener('mousemove', (e) => {
    if (isDraggingRot || isDraggingHeight) {
        const deltaX = isDraggingRot ? (e.clientX - lastX) : 0;
        const deltaY = isDraggingHeight ? (e.clientY - lastY) : 0;
        lastX = e.clientX;
        lastY = e.clientY;
        fetch(`https://${GetParentResourceName()}/rotate`, {
            method: 'POST',
            body: JSON.stringify({ deltaX: deltaX, deltaY: deltaY })
        });
    }
});

window.addEventListener('wheel', (e) => {
    // Prevent zoom inside the actual menu panel
    if (e.target.closest('.main-content') || e.target.closest('#category-list')) return;

    fetch(`https://${GetParentResourceName()}/zoom`, {
        method: 'POST',
        body: JSON.stringify({ delta: Math.sign(e.deltaY) })
    });
}, { passive: true });

init();
