Config = {}

-- Equipping system configuration
Config.UseDragAndDrop = true -- Set to false if using button-based equipping
Config.ArmorSlot = 32 -- Armor slot number (Only used if UseDragAndDrop = true)

-- Plate data configuration
-- NOTE: All plates start at 100% durability and degrade based on their durability rating
-- Higher durability rating = less damage taken per hit
-- Protection values determine virtual armor amount each plate provides
Config.Plates = {
    ['steel_plate'] = {
        label = 'Steel Plate',
        weight = 4536, -- Match to items.lua
        durability = 150, -- Durability rating (higher = takes less damage)
        protection = 150, -- Virtual protection value (most protective)
        brokenItem = 'brokenplate',
        tier = 1 -- Highest tier = most durable
    },
    ['uhmwpe_plate'] = {
        label = 'UHMWPE Plate',
        weight = 1814, -- Match to items.lua
        durability = 125, -- Durability rating (takes less damage than steel)
        protection = 125, -- Virtual protection value (3rd most protective)
        brokenItem = 'brokenplate',
        tier = 2
    },
    ['ceramic_plate'] = {
        label = 'Ceramic Plate',
        weight = 3175, -- Match to items.lua
        durability = 100, -- Durability rating (takes more damage than steel)
        protection = 100, -- Virtual protection value (2nd least protective)
        brokenItem = 'brokenplate',
        tier = 3
    },
    ['kevlar_plate'] = {
        label = 'Kevlar Plate',
        weight = 1361, -- Match to items.lua
        durability = 75, -- Durability rating (takes most damage)
        protection = 75, -- Virtual protection value (least protective)
        brokenItem = 'brokenplate',
        tier = 4 -- Lowest tier = least durable
    }
}

-- Animation and progress bar settings
Config.EquipSettings = {
    useTime = 3000, -- 3 seconds
    animation = {
        dict = 'clothingshirt',
        clip = 'try_shirt_positive_d'
    },
    progressText = 'Equipping plate carrier...'
}

Config.UnequipSettings = {
    useTime = 2000, 
    animation = {
        dict = 'clothingshirt',
        clip = 'try_shirt_negative_a'
    },
    progressText = 'Removing plate carrier...'
}

-- Damage calculation settings
Config.DamageSettings = {
    -- How much durability loss per point of damage taken
    durabilityLossPerDamage = 1,
    -- Minimum damage threshold to trigger plate damage
    minimumDamageThreshold = 5
} 