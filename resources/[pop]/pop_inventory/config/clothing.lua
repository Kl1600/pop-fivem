-- Animations de port, restrictions de conteneurs, tenue « nue » et vêtements.

Config.Animations = {
  cardboard_box = { anim = 'carry_box', dict = 'anim@heists@box_carry@' },
  safe = { anim = 'carry_box', dict = 'anim@heists@box_carry@' },
}

Config.ContainerRestrictions = {
  backpack = {
    denyItems = {
      'policevest',
      'kevlar',
    }
  }
}

Config.Nude = {
  male = {
    components = {
      [1] = { drawable = 0, texture = 0, palette = 0 }, -- mask
      [3] = { drawable = 15, texture = 0, palette = 0 }, -- arms
      [4] = { drawable = 61, texture = 0, palette = 0 }, -- pants
      [5] = { drawable = 0, texture = 0, palette = 0 }, -- bags
      [6] = { drawable = 34, texture = 0, palette = 0 }, -- shoes
      [7] = { drawable = 0, texture = 0, palette = 0 }, -- chain/tie
      [8] = { drawable = 15, texture = 0, palette = 0 }, -- undershirt
      [9] = { drawable = 0, texture = 0, palette = 0 }, -- bproof
      [10] = { drawable = 0, texture = 0, palette = 0 }, -- decals
      [11] = { drawable = 15, texture = 0, palette = 0 }, -- torso
    },
    props = {
      [0] = { drawable = -1, texture = 0 },
      [1] = { drawable = -1, texture = 0 },
      [2] = { drawable = -1, texture = 0 },
    },
  },
  female = {
    components = {
      [1] = { drawable = 0, texture = 0, palette = 0 }, -- mask
      [3] = { drawable = 15, texture = 0, palette = 0 },
      [4] = { drawable = 17, texture = 0, palette = 0 },
      [5] = { drawable = 0, texture = 0, palette = 0 }, -- bags
      [6] = { drawable = 35, texture = 0, palette = 0 },
      [7] = { drawable = 0, texture = 0, palette = 0 }, -- chain/tie
      [8] = { drawable = 2, texture = 0, palette = 0 },
      [9] = { drawable = 0, texture = 0, palette = 0 }, -- bproof
      [10] = { drawable = 0, texture = 0, palette = 0 }, -- decals
      [11] = { drawable = 15, texture = 0, palette = 0 },
    },
    props = {
      [0] = { drawable = -1, texture = 0 },
      [1] = { drawable = -1, texture = 0 },
      [2] = { drawable = -1, texture = 0 },
    },
  },
}

Config.Clothing = {
  panta = {
    male = { components = { [4] = { drawable = 173, texture = 0, palette = 0 } } },
    female = { components = { [4] = { drawable = 0, texture = 0, palette = 0 } } },
  },
  hoddie = {
    male = { components = { [11] = { drawable = 524, texture = 6, palette = 0 } } },
    female = { components = { [11] = { drawable = 0, texture = 0, palette = 0 } } },
  },
  -- T-shirt simple : haut (11) + sous-haut vide (8) + bras assortis (3).
  -- Avant : composant 38 inexistant (homme) et haut 15 = torse nu (femme).
  tshirt = {
    male = { components = { [11] = { drawable = 0, texture = 0, palette = 0 }, [8] = { drawable = 15, texture = 0, palette = 0 }, [3] = { drawable = 0, texture = 0, palette = 0 } } },
    female = { components = { [11] = { drawable = 0, texture = 0, palette = 0 }, [8] = { drawable = 14, texture = 0, palette = 0 }, [3] = { drawable = 0, texture = 0, palette = 0 } } },
  },
  shoes = {
    male = { components = { [6] = { drawable = 1, texture = 0, palette = 0 } } },
    female = { components = { [6] = { drawable = 1, texture = 0, palette = 0 } } },
  },
  hat = {
    male = { props = { [0] = { drawable = 0, texture = 0 } } },
    female = { props = { [0] = { drawable = 0, texture = 0 } } },
  },
  glasses = {
    male = { props = { [1] = { drawable = 0, texture = 0 } } },
    female = { props = { [1] = { drawable = 0, texture = 0 } } },
  },
  mask = {
    male = { components = { [1] = { drawable = 0, texture = 0, palette = 0 } } },
    female = { components = { [1] = { drawable = 0, texture = 0, palette = 0 } } },
  },
  tie = {
    male = { components = { [7] = { drawable = 0, texture = 0, palette = 0 } } },
    female = { components = { [7] = { drawable = 0, texture = 0, palette = 0 } } },
  },
  cardboard_box = {
    male = { props = { [5] = { drawable = 0, texture = 0 } } },
    female = { props = { [5] = { drawable = 0, texture = 0 } } },
  },
  safe = {
    male = { props = { [5] = { drawable = 0, texture = 0 } } },
    female = { props = { [5] = { drawable = 0, texture = 0 } } },
  },
}
