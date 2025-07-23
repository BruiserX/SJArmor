-- Container configurations for plate carriers
return {
    ['heavypc'] = {
        label = 'Heavy Plate Carrier',
        plateSlots = 4, -- For compatibility with existing code
        baseWeight = 2000, -- 2kg base weight
        stashPrefix = 'heavypc_',
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