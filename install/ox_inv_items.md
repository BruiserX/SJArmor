# SJ Armor - Items Installation

Add the following items to your ox_inventory `data/items.lua` file:

```lua
----------------------------------------
-- ARMOR PLATES
----------------------------------------
['steel_plate'] = {
    label = 'Steel Plate',
    weight = 4536, -- Match to config.lua
    stack = false,
    close = true,
    description = 'Heavy steel armor plate. Provides maximum durability but significant weight.',
},

['uhmwpe_plate'] = {
    label = 'UHMWPE Plate',
    weight = 1814, -- Match to config.lua
    stack = false,
    close = true,
    description = 'Ultra-high molecular weight polyethylene plate. Lightweight with excellent protection.',
},

['ceramic_plate'] = {
    label = 'Ceramic Plate',
    weight = 3175, -- Match to config.lua
    stack = false,
    close = true,
    description = 'Ceramic composite armor plate. Good protection with moderate weight.',
},

['kevlar_plate'] = {
    label = 'Kevlar Plate',
    weight = 1361, -- Match to config.lua
    stack = false,
    close = true,
    description = 'Lightweight kevlar armor plate. Minimal weight but limited durability.',
},

----------------------------------------
-- BROKEN PLATES
----------------------------------------
['brokenplate'] = {
    label = 'Broken Armor Plate',
    weight = 2000, -- 2 kg average weight, will be set to actual plate weight when broken
    stack = true,
    close = true,
    description = 'A damaged armor plate. Can be sold for scrap or potentially repaired.',
},

----------------------------------------
-- PLATE CARRIERS
----------------------------------------
['heavypc'] = {
    label = 'Heavy Plate Carrier',
    weight = 2000, -- placeholder, set baseWeight in containers.lua
    stack = false,
    close = true,
    description = 'Heavy-duty plate carrier with 4 plate slots. Drag to armor slot to equip.',
    buttons = {
        {
            label = 'Open Plate Carrier',
            action = function(slot)
                exports.SJArmor:openPlateCarrier(slot, 'heavypc')
            end
        },
        {
            label = 'Equip Plate Carrier',
            action = function(slot)
                exports.SJArmor:equipPlateCarrier(slot, 'heavypc')
            end
        },
        {
            label = 'Unequip Plate Carrier',
            action = function(slot)
                exports.SJArmor:unequipPlateCarrier()
            end
        }
    }
},

['lightpc'] = {
    label = 'Light Plate Carrier',
    weight = 1000, -- placeholder, set baseWeight in containers.lua
    stack = false,
    close = true,
    description = 'Lightweight plate carrier with 2 plate slots. Drag to armor slot to equip.',
    buttons = {
        {
            label = 'Open Plate Carrier',
            action = function(slot)
                exports.SJArmor:openPlateCarrier(slot, 'lightpc')
            end
        },
        {
            label = 'Equip Plate Carrier',
            action = function(slot)
                exports.SJArmor:equipPlateCarrier(slot, 'lightpc')
            end
        },
        {
            label = 'Unequip Plate Carrier',
            action = function(slot)
                exports.SJArmor:unequipPlateCarrier()
            end
        }
    }
},
```

## Installation Instructions:

1. **Copy Items**: Copy the items above and paste them into your ox_inventory `data/items.lua` file

2. **Button Configuration**: 
   - **For drag & drop only**: Remove the "Equip Plate Carrier" and "Unequip Plate Carrier" buttons, keep only "Open Plate Carrier"
   - **For button-based equipping**: Use all buttons as shown above

3. **Add Images**: Add the appropriate item images to your ox_inventory `web/images/` folder:
   - steel_plate.png
   - uhmwpe_plate.png  
   - ceramic_plate.png
   - kevlar_plate.png
   - brokenplate.png
   - heavypc.png
   - lightpc.png

4. **Configure sjarmor**: 
   - Edit `shared/config.lua` in sjarmor

5. **Start Resource**:
   - Add `start SJArmor` to your server.cfg

## Button Configuration Guide:

**Option 1: Drag & Drop Only (Recommended for custom ox_inventory setups)**
```
-- Enable "Config.UseDragAndDrop = true"
-- Remove the "Equip Plate Carrier" and "Unequip Plate Carrier" buttons from items above
-- Keep only "Open Plate Carrier" button
-- Specify inventory slot in Config.ArmorSlot
```

**Option 2: Button-Based Equipping (Standard ox_inventory)**
```
-- Disable "Config.UseDragAndDrop = false"
-- Use all buttons as shown above (Open, Equip, Unequip)
```

**How the Buttons Work:**
- **Open Plate Carrier**: Opens the plate carrier storage (works from any location)
- **Equip Plate Carrier**: Adds armor protection without moving the item (plays animation)
- **Unequip Plate Carrier**: Removes armor protection (item stays in same location) 
