-- Container configurations for plate carriers
return {
    ['heavypc'] = {
        label = 'Heavy Plate Carrier',
        plateSlots = 4, -- For compatibility with existing code
        baseWeight = 2000, -- 2kg base weight
        stashPrefix = 'heavypc_',
        -- Drawable index for the Kevlar component (componentId 9)
        -- Optional: if provided, will be used to apply the vest on equip
        vestDrawable = 15,
        vestTexture = 2,
        whitelist = {
            'steel_plate',
            'uhmwpe_plate', 
            'ceramic_plate',
            'kevlar_plate'
        }
    },
    ['lightpc'] = {
        label = 'Light Plate Carrier',
        plateSlots = 2, -- For compatibility with existing code
        baseWeight = 1000, -- 1kg base weight
        stashPrefix = 'lightpc_',
        -- Drawable index for the Kevlar component (componentId 9)
        -- Optional: if provided, will be used to apply the vest on equip
        vestDrawable = 182,
        whitelist = {
            'steel_plate',
            'uhmwpe_plate',
            'ceramic_plate', 
            'kevlar_plate'
        }
    },
    -- Example of how to add a new plate carrier:
    -- ['mediumpc'] = {
    --     label = 'Medium Plate Carrier',
    --     plateSlots = 3,
    --     baseWeight = 1500,
    --     stashPrefix = 'mediumpc_',
    --     whitelist = {
    --         'steel_plate',
    --         'uhmwpe_plate',
    --         'ceramic_plate',
    --         'kevlar_plate'
    --     }
    -- }
} 