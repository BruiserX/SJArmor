# SJArmor - Advanced Armor Plate System

A realistic armor plate system for FiveM servers using ox_inventory. Players can equip plate carriers with different types of armor plates that degrade over time and provide varying levels of protection.

## Features

- **Modular Plate System**: 4 default plate types (Steel, UHMWPE, Ceramic, Kevlar) with fully configurable stats, plus ability to add custom plates
- **Dynamic Weight System**: Plate carrier weight automatically updates based on plates inside - heavier plates = heavier carrier
- **Tier-Based Damage Priority**: Lower tier plates (Kevlar) take damage first, protecting higher tier plates (Steel) until they break
- **Flexible Plate Carriers**: Heavy (4 slots) and Light (2 slots) carriers with customizable slot counts and base weights
- **Multiple Equipping Methods**: Drag & drop to armor slot or use inventory buttons
- **Individual Plate Storage**: Each plate carrier has its own stash system for storing and managing plates
- **Realistic Durability**: Plates degrade with damage and can break completely, turning into broken plate items
- **Virtual Armor System**: Multiple plates provide layered protection with intelligent damage distribution
- **Fully Configurable**: All plate stats, damage calculations, animations, and settings are easily customizable
- **Progress Bar Integration**: Smooth equip/unequip animations with ox_lib progress bars

## Requirements

- [ox_inventory](https://github.com/overextended/ox_inventory)
- [ox_lib](https://github.com/overextended/ox_lib)

## Installation

1. **Download and extract** to your resources folder
2. **Add items to ox_inventory** - Copy items from `install/ox_inv_items.md` to your `ox_inventory/data/items.lua`
3. **Add images** - Copy all images from `install/images/` to your `ox_inventory/web/images/` folder
4. **Configure** - Edit `shared/config.lua` to adjust plate stats, damage settings, etc.
5. **Start the resource** - Add `start SJArmor` to your server.cfg

## Usage

### For Players
- **Equip Plate Carrier**: Drag to armor slot or use the "Equip" button
- **Add Plates**: Open plate carrier and drag plates into the slots
- **Remove Plates**: Open plate carrier and remove plates from slots
- **Unequip**: Use the "Unequip" button or drag away from armor slot

### For Admins
- **Configure Plates**: Edit `shared/config.lua` to adjust durability, protection, and weight values
- **Damage Settings**: Modify `Config.DamageSettings` to change how plates degrade
- **Animation Settings**: Customize equip/unequip animations and timing

## Plate Types

| Plate Type | Durability | Protection | Weight | Tier |
|------------|------------|------------|--------|------|
| Steel Plate | 150 | 150 | 4536g | 1 (Best) |
| UHMWPE Plate | 125 | 125 | 1814g | 2 |
| Ceramic Plate | 100 | 100 | 3175g | 3 |
| Kevlar Plate | 75 | 75 | 1361g | 4 (Worst) |

**Tier System**: Lower tier numbers = higher priority. Kevlar (Tier 4) takes damage first, Steel (Tier 1) takes damage last.

## Configuration

Key settings in `shared/config.lua`:

## Adding New Vest Types

To add new plate carrier types (vests), you need to update multiple files:

### 1. Add Container Configuration (`data/containers.lua`)

```lua
['mediumpc'] = {
    label = 'Medium Plate Carrier',
    plateSlots = 3, -- Number of plate slots
    baseWeight = 1500, -- Base weight in grams
    stashPrefix = 'mediumpc_', -- Unique prefix for stash IDs
    whitelist = {
        'steel_plate',
        'uhmwpe_plate',
        'ceramic_plate',
        'kevlar_plate'
    }
}
```

### 2. Add Item Definition (`ox_inventory/data/items.lua`)

```lua
['mediumpc'] = {
    label = 'Medium Plate Carrier',
    weight = 1500, -- Should match baseWeight from containers.lua
    stack = false,
    close = true,
    description = 'Medium plate carrier with 3 plate slots. Drag to armor slot to equip.',
    buttons = {
        {
            label = 'Open Plate Carrier',
            action = function(slot)
                exports.SJArmor:openPlateCarrier(slot, 'mediumpc')
            end
        },
        {
            label = 'Equip Plate Carrier',
            action = function(slot)
                exports.SJArmor:equipPlateCarrier(slot, 'mediumpc')
            end
        },
        {
            label = 'Unequip Plate Carrier',
            action = function(slot)
                exports.SJArmor:unequipPlateCarrier()
            end
        }
    }
}
```

### 3. Update Item Filters (Server-side)

Add your new vest type to the item filters in `server/main.lua`:

**In the `createItem` hook:**
```lua
itemFilter = {
    steel_plate = true,
    uhmwpe_plate = true,
    ceramic_plate = true,
    kevlar_plate = true,
    heavypc = true,
    lightpc = true,
    mediumpc = true  -- Add your new vest type here
}
```

**In the `swapItems` hook for equipping:**
```lua
itemFilter = {
    heavypc = true,
    lightpc = true,
    mediumpc = true  -- Add your new vest type here
}
```

If adding a new plate type:

**In the `swapItems` hook for plate restrictions:**
```lua
allowedItems = {
    steel_plate = true,
    uhmwpe_plate = true,
    ceramic_plate = true,
    kevlar_plate = true
}
```

## Support

For issues or questions, please check the [Issues](https://github.com/yourusername/SJArmor/issues) page or create a new issue.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 
