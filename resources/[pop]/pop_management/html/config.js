const carConfig = {
    categories: [
        { id: 'sports', label: 'Sportives' },
        { id: 'supers', label: 'Supercars' },
        { id: 'suvs', label: 'SUV' },
        { id: 'sedans', label: 'Berlines' },
        { id: 'coupes', label: 'Coupés' },
        { id: 'offroad', label: 'Tout-terrain' },
        { id: 'motorcycles', label: 'Motos' },
        { id: 'muscle', label: 'Muscle Cars' },
        { id: 'compacts', label: 'Compactes' },
        { id: 'vans', label: 'Vans' },
        { id: 'utility', label: 'Utilitaires' },
        { id: 'industrial', label: 'Industriels' },
        { id: 'service', label: 'Service' },
        { id: 'commercial', label: 'Commerciaux' },
        { id: 'boats', label: 'Bateaux' },
        { id: 'cycles', label: 'Vélos' },
        { id: 'jobs', label: 'Services Publics' }
    ],
    cars: [
        {
            model: 't20',
            label: 'Progen T20',
            price: 550000,
            category: 'supers',
            image: 't20.jpg'
        },
        {
            model: 'zentorno',
            label: 'Pegassi Zentorno',
            price: 450000,
            category: 'supers',
            image: 'zentorno.jpg'
        },
        {
            model: 'adder',
            label: 'Truffade Adder',
            price: 850000,
            category: 'supers',
            image: 'adder.jpg'
        },
        {
            model: 'elegy',
            label: 'Annis Elegy RH8',
            price: 95000,
            category: 'sports',
            image: 'elegy.jpg'
        },
        {
            model: 'comet2',
            label: 'Pfister Comet SR',
            price: 145000,
            category: 'sports',
            image: 'comet2.jpg'
        },
        {
            model: 'baller',
            label: 'Gallivanter Baller',
            price: 65000,
            category: 'suvs',
            image: 'baller.jpg'
        },
        {
            model: 'sentinel5',
            label: 'Übermacht Sentinel GTS',
            price: 82000,
            category: 'sedans',
            image: 'sentinel_gts.jpg'
        },
        {
            model: 'cogcabrio',
            label: 'Enus Cognoscenti Cabrio',
            price: 185000,
            category: 'coupes',
            image: 'cogcabrio.jpg'
        },
        {
            model: 'exemplar',
            label: 'Dewbauchee Exemplar',
            price: 205000,
            category: 'coupes',
            image: 'exemplar.jpg'
        },
        {
            model: 'bifta',
            label: 'BF Bifta',
            price: 25000,
            category: 'offroad',
            image: 'bifta.jpg'
        },
        {
            model: 'sanchez',
            label: 'Maibatsu Sanchez',
            price: 15000,
            category: 'motorcycles',
            image: 'sanchez.jpg'
        },
        {
            model: 'carbonrs',
            label: 'Nagasaki Carbon RS',
            price: 45000,
            category: 'motorcycles',
            image: 'carbonrs.jpg'
        },
        // --- VÉHICULES SERVICES PUBLICS (JOBS) ---
        {
            model: 'poldorado',
            label: 'Bravado Dorado',
            price: 50000,
            category: 'jobs',
            image: 'poldorado.jpg',
            job: 'police'
        },
        {
            model: 'ambulance',
            label: 'Ambulance',
            price: 0,
            category: 'jobs',
            image: 'bulance1.png',
            job: 'ambulance'
        },
        {
            model: 'polgauntlet',
            label: 'Gauntlet Interceptor',
            price: 120000,
            category: 'jobs',
            image: 'polgauntlet.jpg',
            job: 'police'
        },
        {
            model: 'polbuffalostx',
            label: 'Bravado Buffalo STX',
            price: 75000,
            category: 'jobs',
            image: 'polbuffalostx.jpg',
            job: 'police'
        }
    ]
};
