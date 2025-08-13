local playerArmorData = {} 
local registeredStashes = {} 
local plateInstallBusy = {}

-- Load container configurations from data/containers.lua
local ContainerConfigs = require('data.containers')

local function clone(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local out = {}
    for k, v in pairs(tbl) do
        out[k] = (type(v) == 'table') and clone(v) or v
    end
    return out
end

local function deepMerge(base, override)
    if type(base) ~= 'table' then return clone(override) end
    local out = clone(base)
    if type(override) == 'table' then
        for k, v in pairs(override) do
            if type(v) == 'table' and type(out[k]) == 'table' then
                out[k] = deepMerge(out[k], v)
            else
                out[k] = clone(v)
            end
        end
    end
    return out
end

-- Helper to get durability, preferring metadata.durability then metadata.degrade, otherwise config/default 100
local function getDurabilityFromMetadata(metadata, plateName)
    local d = nil
    if type(metadata) == 'table' then
        if type(metadata.durability) == 'number' then d = metadata.durability end
        if d == nil and type(metadata.degrade) == 'number' then d = metadata.degrade end
    end
    if d == nil then
        local cfg = Config.Plates[plateName]
        d = (cfg and cfg.durability) or 100
    end
    return d
end

-- Calculate total virtual armor from plates in a stash
local function calculateVirtualArmor(stashInventory)
    local totalArmor = 0
    local plateCount = 0
    
    if not stashInventory or not stashInventory.items then
        return totalArmor, plateCount
    end
    
    for slot, item in pairs(stashInventory.items) do
        if item and Config.Plates[item.name] then
            local plateConfig = Config.Plates[item.name]
            local durability = getDurabilityFromMetadata(item.metadata, item.name)
            
            if durability > 0 then
                totalArmor = totalArmor + plateConfig.protection
                plateCount = plateCount + 1
            end
        end
    end
    
    return math.floor(totalArmor), plateCount
end

local function calculatePlateWeight(stashInventory, baseWeight)
    local totalWeight = baseWeight or 0
    
    if not stashInventory or not stashInventory.items then
        return totalWeight
    end
    
    for slot, item in pairs(stashInventory.items) do
        if item and Config.Plates[item.name] then
            local plateConfig = Config.Plates[item.name]
            totalWeight = totalWeight + (plateConfig.weight * item.count)
        end
    end
    
    return totalWeight
end

local function updatePlateCarrierWeight(playerId, carrierSlot, stashId)
    local carrierItem = exports.ox_inventory:GetSlot(playerId, carrierSlot)
    if not carrierItem then 
        return 
    end
    
    local carrierConfig = ContainerConfigs[carrierItem.name]
    if not carrierConfig then 
        return 
    end
    
    local stashInv = exports.ox_inventory:GetInventory(stashId, false)
    local newWeight = calculatePlateWeight(stashInv, carrierConfig.baseWeight)
    
    local updatedMetadata = {}
    
    if carrierItem.metadata then
        for key, value in pairs(carrierItem.metadata) do
            updatedMetadata[key] = value
        end
    end
    
    -- Update the weight
    updatedMetadata.weight = newWeight
    
    -- Use SetMetadata with the fresh metadata table
    exports.ox_inventory:SetMetadata(playerId, carrierSlot, updatedMetadata)
end

-- Get the plate with highest tier (most durable) that has durability > 0
local function getNextPlateToBreak(stashInventory)
    if not stashInventory or not stashInventory.items then return nil end
    
    local bestPlate = nil
    local bestTier = 999 -- Lower tier number = higher priority
    
    for slot, item in pairs(stashInventory.items) do
        if item and Config.Plates[item.name] then
            local plateConfig = Config.Plates[item.name]
            local durability = getDurabilityFromMetadata(item.metadata, item.name)
            
            if durability > 0 and plateConfig.tier < bestTier then
                bestTier = plateConfig.tier
                bestPlate = {
                    slot = slot,
                    item = item,
                    config = plateConfig
                }
            end
        end
    end
    
    return bestPlate
end

-- local function createPlateCarrierStash(playerId, carrierType, itemSlot)
--     local identifier = exports.ox_inventory:GetInventory(playerId).owner
--     local timestamp = os.time()
--     local stashId = ('%s_%s_%d_%d'):format(ContainerConfigs[carrierType].stashPrefix, identifier, itemSlot, timestamp)
    
--     -- Register the stash in ox_inventory
--     local carrierConfig = ContainerConfigs[carrierType]
--     exports.ox_inventory:RegisterStash(stashId, carrierConfig.label, carrierConfig.plateSlots, 50000, identifier, {})
    
--     registeredStashes[stashId] = {
--         owner = identifier,
--         type = carrierType,
--         created = timestamp
--     }
    
--     return stashId
-- end

-- Hook to initialize item metadata when created (plates + plate carriers)
exports.ox_inventory:registerHook('createItem', function(payload)
    local item = payload.item
    local metadata = payload.metadata or {}
    
    -- Handle plate durability initialization
    if Config.Plates[item.name] then
        local plateConfig = Config.Plates[item.name]
        
        if metadata.durability == nil and metadata.degrade ~= nil then
            metadata.durability = metadata.degrade
        elseif metadata.durability == nil then
            metadata.durability = (plateConfig and plateConfig.durability) or 100
        end
        
        if metadata.degrade == nil then
            metadata.degrade = metadata.durability
        end
    end
    
    if ContainerConfigs[item.name] then
        local carrierConfig = ContainerConfigs[item.name]
        
        if not metadata.stashId then
            -- Generate unique stash ID
            local timestamp = os.time()
            local stashId = ('%s%d_%d'):format(carrierConfig.stashPrefix, timestamp, math.random(100000, 999999))
            
            exports.ox_inventory:RegisterStash(stashId, carrierConfig.label, carrierConfig.plateSlots, 50000, false, false)
            
            metadata.stashId = stashId
            registeredStashes[stashId] = {
                owner = false,  
                type = item.name,
                created = timestamp
            }
        end
        
        -- Initialize armor metadata
        if not metadata.virtualArmor then metadata.virtualArmor = 0 end
        if not metadata.plateCount then metadata.plateCount = 0 end
        if not metadata.weight then metadata.weight = carrierConfig.baseWeight end
        if not metadata.vestDrawable and carrierConfig and carrierConfig.vestDrawable then
            metadata.vestDrawable = carrierConfig.vestDrawable
        end
        if metadata.vestDrawable and metadata.vestTexture == nil and carrierConfig and carrierConfig.vestTexture ~= nil then
            metadata.vestTexture = carrierConfig.vestTexture
        end
    end
    
    return metadata
end, {
    itemFilter = {
        steel_plate = true,
        uhmwpe_plate = true,
        ceramic_plate = true,
        kevlar_plate = true,
        heavypc = true,
        lightpc = true
    }
})

-- Hook for plate carrier equipping (drag to armor slot)
exports.ox_inventory:registerHook('swapItems', function(payload)
    local fromInv = payload.fromInventory
    local toInv = payload.toInventory
    local fromSlot = payload.fromSlot
    local toSlot = payload.toSlot
    local item = fromSlot
    local source = payload.source
    local action = payload.action
    
    if action ~= 'move' and action ~= 'swap' then return true end
    
    if type(toInv) == 'number' and toInv == source and toSlot == Config.ArmorSlot then
        if item and ContainerConfigs[item.name] then            
            -- Check if player already has a plate carrier equipped
            if playerArmorData[source] then
                TriggerClientEvent('ox_lib:notify', source, {
                    type = 'error',
                    description = 'You already have a plate carrier equipped'
                })
                return false
            end
            
            SetTimeout(100, function()
                TriggerClientEvent('SJArmor:startEquipProgress', source, toSlot, item.metadata, item.name)
            end)
            
            return true  
        end
    end
    
    local movingFromArmorSlot = false
    if type(fromInv) == 'number' and fromInv == source then
        if type(fromSlot) == 'table' and fromSlot.slot == Config.ArmorSlot then
            movingFromArmorSlot = true
        elseif type(fromSlot) == 'number' and fromSlot == Config.ArmorSlot then
            movingFromArmorSlot = true
        end
    end
    
    if movingFromArmorSlot and item and ContainerConfigs[item.name] then
        if playerArmorData[source] and playerArmorData[source].stashId == item.metadata.stashId then
            if not playerArmorData[source].unequipInProgress then
                playerArmorData[source].unequipInProgress = true
                
        SetTimeout(100, function()
                    TriggerClientEvent('SJArmor:startUnequipProgress', source, Config.ArmorSlot, item.metadata, item.name)
                end)
                
                SetTimeout(5000, function()
                    if playerArmorData[source] then
                        playerArmorData[source].unequipInProgress = nil
                    end
                end)
            end
            
            return true
        end
    end
    
    return true
end, {
    itemFilter = {
        heavypc = true,
        lightpc = true
    },
    typeFilter = {
        player = true,
        stash = true  
    }
})

-- Hook to restrict items that can be placed in plate carrier stashes
exports.ox_inventory:registerHook('swapItems', function(payload)
    local toInv = payload.toInventory
    local item = payload.fromSlot
    
    if type(toInv) == 'string' then
        local baseStashId = toInv:match('([^:]+)')
        if registeredStashes[baseStashId] then
            local allowedItems = {
                steel_plate = true,
                uhmwpe_plate = true,
                ceramic_plate = true,
                kevlar_plate = true
            }
            
            if item and not allowedItems[item.name] then
                return false 
            end
        end
    end
    
    return true 
end, {
    typeFilter = {
        player = true,
        stash = true
    }
})

-- Hook to detect when button-equipped plate carriers are moved out of player inventory
exports.ox_inventory:registerHook('swapItems', function(payload)
    local fromInv = payload.fromInventory
    local toInv = payload.toInventory  
    local source = payload.source
    local action = payload.action
    local item = payload.fromSlot
    
    if action ~= 'move' and action ~= 'swap' then return true end
    
    if type(fromInv) == 'number' and fromInv == source and type(toInv) ~= 'number' then
        if item and ContainerConfigs[item.name] then
            if playerArmorData[source] and playerArmorData[source].stashId == item.metadata.stashId then
                
                SetTimeout(100, function()
                    if playerArmorData[source] and playerArmorData[source].stashId == item.metadata.stashId then
                        local playerInv = exports.ox_inventory:GetInventory(source)
                        local stillInPlayerInv = false
                        
                        if playerInv and playerInv.items then
                            for slot, playerItem in pairs(playerInv.items) do
                                if playerItem and playerItem.metadata and playerItem.metadata.stashId == item.metadata.stashId then
                                    stillInPlayerInv = true
                                    break
                                end
                            end
                        end
                        
                        if not stillInPlayerInv then
                            local prevComponent = nil
                            if playerArmorData[source] and playerArmorData[source].prevVestDrawable ~= nil then
                                prevComponent = {
                                    drawable = playerArmorData[source].prevVestDrawable,
                                    texture = playerArmorData[source].prevVestTexture or 0,
                                    palette = playerArmorData[source].prevVestPalette or 0
                                }
                            end
                            playerArmorData[source] = nil
                            TriggerClientEvent('SJArmor:forceUnequip', source, prevComponent)
                            TriggerClientEvent('ox_lib:notify', source, {
                                type = 'inform',
                                icon = 'shield-halved',
                                iconColor = 'orange',
                                description = 'Plate carrier unequipped - item moved to different inventory'
                            })
                        end
                    end
                end)
            end
        end
    end
    
    if type(fromInv) == 'number' and fromInv == source and type(toInv) == 'number' and toInv ~= source then
        if item and ContainerConfigs[item.name] then
            if playerArmorData[source] and playerArmorData[source].stashId == item.metadata.stashId then
                
                SetTimeout(100, function()
                    if playerArmorData[source] and playerArmorData[source].stashId == item.metadata.stashId then
                        local prevComponent = nil
                        if playerArmorData[source] and playerArmorData[source].prevVestDrawable ~= nil then
                            prevComponent = {
                                drawable = playerArmorData[source].prevVestDrawable,
                                texture = playerArmorData[source].prevVestTexture or 0,
                                palette = playerArmorData[source].prevVestPalette or 0
                            }
                        end
                        playerArmorData[source] = nil
                        TriggerClientEvent('SJArmor:forceUnequip', source, prevComponent)
                        TriggerClientEvent('ox_lib:notify', source, {
                            type = 'inform',
                            icon = 'shield-halved',
                            iconColor = 'orange',
                            description = 'Plate carrier unequipped - item given to another player'
                        })
                    end
                end)
            end
        end
    end
    
    return true
end, {
    itemFilter = {
        heavypc = true,
        lightpc = true
    },
    typeFilter = {
        player = true,
        stash = true
    }
})

exports.ox_inventory:registerHook('swapItems', function(payload)
    local fromInv = payload.fromInventory
    local toInv = payload.toInventory  
    local source = payload.source
    local action = payload.action
    local item = payload.fromSlot
    
    if action ~= 'move' and action ~= 'swap' then return true end
    
    local stashId = nil
    
    if type(toInv) == 'string' then
        local baseStashId = toInv:match('([^:]+)')
        
        if registeredStashes[baseStashId] then
            stashId = baseStashId
        elseif baseStashId then
            local carrierType = nil
            for configName, config in pairs(ContainerConfigs) do
                if baseStashId:match('^' .. config.stashPrefix) then
                    carrierType = configName
                    break
                end
            end
            
            if carrierType then
                local playerInv = exports.ox_inventory:GetInventory(source)
                local owner = playerInv and playerInv.owner
                
                -- Register the stash
                registeredStashes[baseStashId] = {
                    owner = owner,
                    type = carrierType,
                    created = os.time()
                }
                
                stashId = baseStashId
            end
        end
    end
    
    if type(fromInv) == 'string' then
        local baseStashId = fromInv:match('([^:]+)')
        
        if registeredStashes[baseStashId] then
            stashId = baseStashId
        elseif baseStashId then
            local carrierType = nil
            for configName, config in pairs(ContainerConfigs) do
                if baseStashId:match('^' .. config.stashPrefix) then
                    carrierType = configName
                    break
                end
            end
            
            if carrierType then
                local playerInv = exports.ox_inventory:GetInventory(source)
                local owner = playerInv and playerInv.owner
                
                registeredStashes[baseStashId] = {
                    owner = owner,
                    type = carrierType,
                    created = os.time()
                }
                
                stashId = baseStashId
            end
        end
    end
    
    if stashId then
        SetTimeout(200, function()
            
            local function findPlateCarrierInInventory(invItems, invId, isPlayerInv)
                if not invItems then return nil end
                
                for slot, item in pairs(invItems) do
                    if item and item.metadata and item.metadata.stashId == stashId then
                        
                        if isPlayerInv then
                            updatePlateCarrierWeight(source, slot, stashId)
                            
                            if playerArmorData[source] and playerArmorData[source].stashId == stashId then
                                
                                local stashInv = exports.ox_inventory:GetInventory(stashId, false)
                                if stashInv then
                                    local newVirtualArmor, newPlateCount = calculateVirtualArmor(stashInv)
                                    local oldVirtualArmor = playerArmorData[source].virtualArmor
                                    
                                    local lastPlateDurability = 100
                                    if newPlateCount == 1 then
                                        for slot, item in pairs(stashInv.items) do
                                            if item and Config.Plates[item.name] and item.metadata.durability and item.metadata.durability > 0 then
                                                lastPlateDurability = item.metadata.durability
                                                break
                                            end
                                        end
                                    end
                                    
                                    playerArmorData[source].virtualArmor = newVirtualArmor
                                    playerArmorData[source].plateCount = newPlateCount
                                    playerArmorData[source].lastPlateDurability = lastPlateDurability
                                    
                                    local targetArmor = 0
                                    if newVirtualArmor > 0 then
                                        if newPlateCount > 1 then
                                            targetArmor = 100
                                        else
                                            targetArmor = math.floor(lastPlateDurability)
                                        end
                                    end
                                    
                                    if oldVirtualArmor <= 0 and newVirtualArmor > 0 then
                                        TriggerClientEvent('SJArmor:equipArmorResponse', source, true, playerArmorData[source], ('Armor restored! %d plates (%d virtual armor)'):format(newPlateCount, newVirtualArmor), targetArmor)
                                    else
                                        TriggerClientEvent('SJArmor:updateArmor', source, playerArmorData[source], targetArmor)
                                    end
                                end
                            end
                        else
                            local plateStashInv = exports.ox_inventory:GetInventory(stashId, false)
                            if plateStashInv then
                                                            local carrierConfig = ContainerConfigs[item.name]
                                if carrierConfig then
                                    local newWeight = calculatePlateWeight(plateStashInv, carrierConfig.baseWeight)
                                    
                                    local updatedMetadata = {}
                                    if item.metadata then
                                        for key, value in pairs(item.metadata) do
                                            updatedMetadata[key] = value
                                        end
                                    end
                                    updatedMetadata.weight = newWeight
                                    
                                    exports.ox_inventory:SetMetadata(invId, slot, updatedMetadata)
                                end
                            end
                        end
                        return true
                    end
                end
                return nil
            end
            
            local playerItems = exports.ox_inventory:GetInventoryItems(source)
            if findPlateCarrierInInventory(playerItems, source, true) then
                return 
            end
            
            local playerInv = exports.ox_inventory:GetInventory(source)
            if playerInv and playerInv.items and playerInv.items[31] then
                local backpackItem = playerInv.items[31]
                if backpackItem and backpackItem.metadata and backpackItem.metadata.stashId then
                    local backpackStashInv = exports.ox_inventory:GetInventory(backpackItem.metadata.stashId, false)
                    if backpackStashInv and backpackStashInv.items then
                        if findPlateCarrierInInventory(backpackStashInv.items, backpackItem.metadata.stashId, false) then
                            return 
                        end
                    end
                end
            end
            
        end)
    end
    
    return true
end, {
    itemFilter = {
        steel_plate = true,
        uhmwpe_plate = true,
        ceramic_plate = true,
        kevlar_plate = true
    },
    typeFilter = {
        player = true,
        stash = true
    }
})

-- Fix plate carrier stash for items missing stashId
function fixPlateCarrierStash(source, slot, carrierType)
    local playerInv = exports.ox_inventory:GetInventory(source)
    if not playerInv or not playerInv.items or not playerInv.items[slot] then
        return false, nil
    end
    
    local carrierItem = playerInv.items[slot]
    local carrierConfig = ContainerConfigs[carrierType]
    
    if not carrierConfig then
        return false, nil
    end
    
    local stashId = carrierConfig.stashPrefix .. '_' .. os.time() .. '_' .. math.random(10000, 99999)
    
    local success = pcall(function()
        exports.ox_inventory:RegisterStash(stashId, carrierConfig.label, carrierConfig.plateSlots, 50000, false, false)
    end)
    
    if not success then
        return false, nil
    end
    
    local newMetadata = {}
    if carrierItem.metadata then
        for k, v in pairs(carrierItem.metadata) do
            newMetadata[k] = v
        end
    end
    newMetadata.stashId = stashId
    newMetadata.weight = carrierConfig.baseWeight
    
    local setSuccess = exports.ox_inventory:SetMetadata(source, slot, newMetadata)
    
    if setSuccess then
        registeredStashes[stashId] = {
            owner = false,
            type = carrierType,
            created = os.time()
        }
        
        return true, stashId
    end
    
    return false, nil
end

RegisterNetEvent('SJArmor:equipPlateCarrier', function(slot, carrierType, prevDrawable, prevTexture, prevPalette)
    local source = source
    local playerInv = exports.ox_inventory:GetInventory(source)
    
    if not playerInv or not playerInv.items[slot] then
        TriggerClientEvent('SJArmor:equipArmorResponse', source, false, nil, 'Invalid plate carrier')
        return
    end
    
    local carrierItem = playerInv.items[slot]
    local metadata = carrierItem.metadata or {}
    
    if not metadata.stashId then
        local success, newStashId = fixPlateCarrierStash(source, slot, carrierType)
        if success then
            metadata.stashId = newStashId
            TriggerClientEvent('ox_lib:notify', source, {
                type = 'success',
                description = 'Plate carrier storage fixed! You can now equip it.'
            })
            local updatedItem = exports.ox_inventory:GetSlot(source, slot)
            if updatedItem and updatedItem.metadata then
                metadata = updatedItem.metadata
            end
        else
            TriggerClientEvent('SJArmor:equipArmorResponse', source, false, nil, 'Failed to fix plate carrier storage')
            return
        end
    end
    
    if playerArmorData[source] then
        TriggerClientEvent('SJArmor:equipArmorResponse', source, false, nil, 'You already have a plate carrier equipped')
        return
    end
    
    local stashInv = exports.ox_inventory:GetInventory(metadata.stashId, false)
    if not stashInv then
        local carrierConfig = ContainerConfigs[carrierType]
        if carrierConfig then
            local owner = playerInv.owner
            
            local success = pcall(function()
                exports.ox_inventory:RegisterStash(metadata.stashId, carrierConfig.label, carrierConfig.plateSlots, 50000, owner, false)
            end)
            
            if success then
                registeredStashes[metadata.stashId] = {
                    owner = owner,
                    type = carrierType,
                    created = os.time()
                }
                
                stashInv = exports.ox_inventory:GetInventory(metadata.stashId, false)
            end
        end
        
    if not stashInv then
        TriggerClientEvent('SJArmor:equipArmorResponse', source, false, nil, 'Unable to access plate carrier storage')
        return
        end
    end
    
    local virtualArmor, plateCount = calculateVirtualArmor(stashInv)
    
    local lastPlateDurability = 100
    if plateCount == 1 then
        for slotNum, item in pairs(stashInv.items) do
            if item and Config.Plates[item.name] then
                local d = getDurabilityFromMetadata(item.metadata, item.name)
                if d > 0 then
                    lastPlateDurability = d
                    break
                end
            end
        end
    end
    
    local updatedMetadata = {}
    if carrierItem.metadata then
        for key, value in pairs(carrierItem.metadata) do
            updatedMetadata[key] = value
        end
    end
    updatedMetadata.equipped = true 
    updatedMetadata.unequipped = nil 
    if prevDrawable ~= nil then
        updatedMetadata.prevVestDrawable = prevDrawable
        updatedMetadata.prevVestTexture = prevTexture or 0
        updatedMetadata.prevVestPalette = prevPalette or 0
    end
    exports.ox_inventory:SetMetadata(source, slot, updatedMetadata)
    
    local carrierConfig = ContainerConfigs[carrierType]
    playerArmorData[source] = {
        stashId = metadata.stashId,
        carrierType = carrierType,
        carrierSlot = slot,
        virtualArmor = virtualArmor,
        plateCount = plateCount,
        lastPlateDurability = lastPlateDurability,
        equippedAt = os.time(),
        vestDrawable = (carrierItem.metadata and carrierItem.metadata.vestDrawable)
            or (carrierConfig and carrierConfig.vestDrawable),
        vestTexture = (carrierItem.metadata and carrierItem.metadata.vestTexture)
            or (carrierConfig and carrierConfig.vestTexture),
        prevVestDrawable = prevDrawable,
        prevVestTexture = prevTexture,
        prevVestPalette = prevPalette
    }
    
    local targetArmor = 0
    if virtualArmor > 0 then
        if plateCount > 1 then
            targetArmor = 100
        else
            targetArmor = math.floor(lastPlateDurability)
        end
    end
    
    local message = ('Plate carrier equipped with %d plates (%d virtual armor)'):format(plateCount, virtualArmor)
    TriggerClientEvent('SJArmor:equipArmorResponse', source, true, playerArmorData[source], message, targetArmor)
end)

RegisterNetEvent('SJArmor:equipPlateCarrierFromSlot', function(targetSlot, metadata, carrierType)
    local source = source
    
    if playerArmorData[source] then
        TriggerClientEvent('SJArmor:equipArmorResponse', source, false, nil, 'You already have a plate carrier equipped')
        return
    end
    
    if targetSlot ~= Config.ArmorSlot then
        TriggerClientEvent('SJArmor:equipArmorResponse', source, false, nil, 'Invalid armor slot')
        return
    end
    
    if not metadata or not metadata.stashId then
        TriggerClientEvent('SJArmor:equipArmorResponse', source, false, nil, 'Plate carrier has no storage')
        return
    end
    
    local stashInv = exports.ox_inventory:GetInventory(metadata.stashId, false)
    if not stashInv then
        
        local carrierConfig = ContainerConfigs[carrierType]
        if carrierConfig then
            local playerInv = exports.ox_inventory:GetInventory(source)
            local owner = playerInv and playerInv.owner
            
            local success = pcall(function()
                exports.ox_inventory:RegisterStash(metadata.stashId, carrierConfig.label, carrierConfig.plateSlots, 50000, owner, false)
            end)
            
            if success then
                registeredStashes[metadata.stashId] = {
                    owner = owner,
                    type = carrierType,
                    created = os.time()
                }
                
                stashInv = exports.ox_inventory:GetInventory(metadata.stashId, false)
            end
        end
        
        if not stashInv then
            TriggerClientEvent('SJArmor:equipArmorResponse', source, false, nil, 'Unable to access plate carrier storage')
            return
        end
    end
    
    local virtualArmor, plateCount = calculateVirtualArmor(stashInv)
    
    local lastPlateDurability = 100
    if plateCount == 1 then
        for slotNum, item in pairs(stashInv.items) do
            if item and Config.Plates[item.name] then
                local d = getDurabilityFromMetadata(item.metadata, item.name)
                if d > 0 then
                    lastPlateDurability = d
                    break
                end
            end
        end
    end
    
    local playerInv = exports.ox_inventory:GetInventory(source)
    if playerInv and playerInv.items[targetSlot] then
        local item = playerInv.items[targetSlot]
        local updatedMetadata = {}
        if item.metadata then
            for key, value in pairs(item.metadata) do
                updatedMetadata[key] = value
            end
        end
        updatedMetadata.equipped = true 
        updatedMetadata.unequipped = nil 
        if metadata and metadata.prevVestDrawable ~= nil then
            updatedMetadata.prevVestDrawable = metadata.prevVestDrawable
            updatedMetadata.prevVestTexture = metadata.prevVestTexture or 0
            updatedMetadata.prevVestPalette = metadata.prevVestPalette or 0
        end
        exports.ox_inventory:SetMetadata(source, targetSlot, updatedMetadata)
    end
    
    local carrierConfig = ContainerConfigs[carrierType]
    playerArmorData[source] = {
        stashId = metadata.stashId,
        carrierType = carrierType,
        carrierSlot = targetSlot,
        virtualArmor = virtualArmor,
        plateCount = plateCount,
        lastPlateDurability = lastPlateDurability,
        equippedAt = os.time(),
        vestDrawable = (metadata and metadata.vestDrawable)
            or (carrierConfig and carrierConfig.vestDrawable),
        vestTexture = (metadata and metadata.vestTexture)
            or (carrierConfig and carrierConfig.vestTexture),
        prevVestDrawable = metadata and metadata.prevVestDrawable,
        prevVestTexture = metadata and metadata.prevVestTexture,
        prevVestPalette = metadata and metadata.prevVestPalette
    }
    
    local targetArmor = 0
    if virtualArmor > 0 then
        if plateCount > 1 then
            targetArmor = 100
        else
            targetArmor = math.floor(lastPlateDurability)
        end
    end
    
    local message = ('Plate carrier equipped with %d plates (%d virtual armor)'):format(plateCount, virtualArmor)
    TriggerClientEvent('SJArmor:equipArmorResponse', source, true, playerArmorData[source], message, targetArmor)
end)

RegisterNetEvent('SJArmor:unequipPlateCarrier', function()
    local source = source
    
    if not playerArmorData[source] then
        TriggerClientEvent('SJArmor:unequipArmorResponse', source, false, 'No plate carrier equipped')
        return
    end
    
    local armorData = playerArmorData[source]
    local stashInv = exports.ox_inventory:GetInventory(armorData.stashId, false)
    
    if stashInv then
        for slot, item in pairs(stashInv.items) do
            if item and Config.Plates[item.name] and item.metadata.durability then
                exports.ox_inventory:SetMetadata(armorData.stashId, slot, item.metadata)
            end
        end
    end
    
    local playerInv = exports.ox_inventory:GetInventory(source)
    if playerInv and playerInv.items[armorData.carrierSlot] then
        local item = playerInv.items[armorData.carrierSlot]
        local metadata = item.metadata or {}
        metadata.equipped = false 
        metadata.unequipped = true 
        exports.ox_inventory:SetMetadata(source, armorData.carrierSlot, metadata)
    end
    
    local prevComponent = nil
    if armorData.prevVestDrawable ~= nil then
        prevComponent = {
            drawable = armorData.prevVestDrawable,
            texture = armorData.prevVestTexture or 0,
            palette = armorData.prevVestPalette or 0
        }
    end
    playerArmorData[source] = nil
    
    TriggerClientEvent('SJArmor:unequipArmorResponse', source, true, 'Plate carrier removed', 0, prevComponent)
end)

RegisterNetEvent('SJArmor:cancelEquip', function(slot)
    local source = source
    playerArmorData[source] = nil
end)

RegisterNetEvent('SJArmor:cancelEquipAndMoveBack', function(targetSlot, metadata, carrierType)
    local source = source
    playerArmorData[source] = nil
    
    local playerInv = exports.ox_inventory:GetInventory(source)
    if playerInv and playerInv.items[targetSlot] then
        local item = playerInv.items[targetSlot]
        
        if item and item.metadata and item.metadata.stashId == metadata.stashId then
            for slot = 1, playerInv.slots do
                if slot ~= Config.ArmorSlot and not playerInv.items[slot] then
                    local success = exports.ox_inventory:SwapSlots(playerInv, playerInv, targetSlot, slot)
                    if success then
                    else
                    end
                    break
                end
            end
        end
    end
end)

RegisterNetEvent('SJArmor:cancelUnequipAndMoveBack', function(originalSlot, metadata, carrierType)
    local source = source
    
    local playerInv = exports.ox_inventory:GetInventory(source)
    if playerInv and playerInv.items then
        for slot, item in pairs(playerInv.items) do
            if item and item.metadata and item.metadata.stashId == metadata.stashId then
                if slot ~= originalSlot then
                    local success = exports.ox_inventory:SwapSlots(playerInv, playerInv, slot, originalSlot)
                    if success then
                    else
                    end
                end
                break
            end
        end
    end
end)

RegisterNetEvent('SJArmor:armorDamaged', function(damageAmount)
    local source = source
    local armorData = playerArmorData[source]
    
    if not armorData then return end
        
    local stashInv = exports.ox_inventory:GetInventory(armorData.stashId, false)
    if not stashInv then return end
    
    local plateToBreak = getNextPlateToBreak(stashInv)
    if not plateToBreak then 
        return 
    end
    
    local remainingDamage = damageAmount
    local brokenPlates = {}
    
    while remainingDamage > 0 do
        local currentPlate = getNextPlateToBreak(stashInv)
        if not currentPlate then 
            break 
        end
        
        local durabilityLoss = remainingDamage * Config.DamageSettings.durabilityLossPerDamage
        local currentDurability = (currentPlate.item.metadata and (currentPlate.item.metadata.durability or currentPlate.item.metadata.degrade)) or 100
        local newDurability = currentDurability - durabilityLoss
        
        if newDurability <= 0 then
            local damageAbsorbed = currentDurability / Config.DamageSettings.durabilityLossPerDamage
            remainingDamage = remainingDamage - damageAbsorbed
            
            local brokenItemName = currentPlate.config.brokenItem
            local brokenMetadata = {
                originalPlate = currentPlate.item.name,
                originalWeight = currentPlate.config.weight,
                weight = currentPlate.config.weight
            }
            
            local removeSuccess = exports.ox_inventory:RemoveItem(armorData.stashId, currentPlate.item.name, 1, nil, currentPlate.slot)
            if removeSuccess then
                exports.ox_inventory:AddItem(armorData.stashId, brokenItemName, 1, brokenMetadata, currentPlate.slot)
            end
            
            table.insert(brokenPlates, {
                label = Config.Plates[currentPlate.item.name].label,
                broken = true
            })
            
            stashInv = exports.ox_inventory:GetInventory(armorData.stashId, false)
        else
            currentPlate.item.metadata.durability = math.max(0, newDurability)
            currentPlate.item.metadata.degrade = currentPlate.item.metadata.durability
            
            exports.ox_inventory:SetMetadata(armorData.stashId, currentPlate.slot, currentPlate.item.metadata)
            
            remainingDamage = 0 
        end
    end
    

    
    local newVirtualArmor, newPlateCount = calculateVirtualArmor(stashInv)
    armorData.virtualArmor = newVirtualArmor
    armorData.plateCount = newPlateCount
    
    local lastPlateDurability = 100
    if newPlateCount == 1 then
        for slot, item in pairs(stashInv.items) do
            if item and Config.Plates[item.name] then
                local d = getDurabilityFromMetadata(item.metadata, item.name)
                if d > 0 then
                    lastPlateDurability = d
                    break
                end
            end
        end
    end
    armorData.lastPlateDurability = lastPlateDurability
    
    for _, plateBroken in ipairs(brokenPlates) do
        if newVirtualArmor <= 0 then
            TriggerClientEvent('SJArmor:allPlatesBroken', source)
            break 
        else
            TriggerClientEvent('SJArmor:plateBroken', source, plateBroken.label)
        end
    end
    
    local targetArmor = 0
    if newVirtualArmor > 0 then
        if newPlateCount > 1 then
            targetArmor = 100
        elseif newPlateCount == 1 then
            targetArmor = math.floor(lastPlateDurability)
        else
            targetArmor = 0
        end
    end
    
    
    TriggerClientEvent('SJArmor:updateArmor', source, armorData, targetArmor)
    
    updatePlateCarrierWeight(source, armorData.carrierSlot, armorData.stashId)
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    if playerArmorData[source] then
        playerArmorData[source] = nil
    end
end)

AddEventHandler('playerJoining', function()
    local source = source
    
    SetTimeout(3000, function()
        if not playerArmorData[source] then
            local playerInv = exports.ox_inventory:GetInventory(source)
            if playerInv and playerInv.items then
                for slot, item in pairs(playerInv.items) do
                    if item and ContainerConfigs[item.name] and item.metadata and item.metadata.stashId then
                        local isEquipped = false
                        
                        local stashInv = exports.ox_inventory:GetInventory(item.metadata.stashId, false)
                        if stashInv then
                            local virtualArmor, plateCount = calculateVirtualArmor(stashInv)
                            
                            local shouldRestore = item.metadata.equipped and (not Config.UseDragAndDrop or slot == Config.ArmorSlot)
                            
                            if shouldRestore then
                                local lastPlateDurability = 100
                                if plateCount == 1 then
                                    for slotNum, stashItem in pairs(stashInv.items) do
                                        if stashItem and Config.Plates[stashItem.name] then
                                            local d = getDurabilityFromMetadata(stashItem.metadata, stashItem.name)
                                            if d > 0 then
                                                lastPlateDurability = d
                                                break
                                            end
                                        end
                                    end
                                end
                                
                                local carrierConfig = ContainerConfigs[item.name]
                                playerArmorData[source] = {
                                    stashId = item.metadata.stashId,
                                    carrierType = item.name,
                                    carrierSlot = slot,
                                    virtualArmor = virtualArmor,
                                    plateCount = plateCount,
                                    lastPlateDurability = lastPlateDurability,
                                    equippedAt = os.time(),
                                    vestDrawable = (item.metadata and item.metadata.vestDrawable)
                                        or (carrierConfig and carrierConfig.vestDrawable),
                                    vestTexture = (item.metadata and item.metadata.vestTexture)
                                        or (carrierConfig and carrierConfig.vestTexture),
                                    prevVestDrawable = item.metadata and item.metadata.prevVestDrawable,
                                    prevVestTexture = item.metadata and item.metadata.prevVestTexture,
                                    prevVestPalette = item.metadata and item.metadata.prevVestPalette
                                }
                                
                                local targetArmor = 0
                                if virtualArmor > 0 then
                                    if plateCount > 1 then
                                        targetArmor = 100
                                    else
                                        targetArmor = math.floor(lastPlateDurability)
                                    end
                                end
                                
                                local message = virtualArmor > 0 
                                    and ('Welcome back! Plate carrier restored: %d plates (%d virtual armor)'):format(plateCount, virtualArmor)
                                    or 'Welcome back! Empty plate carrier restored - add plates to activate armor'
                                
                                TriggerClientEvent('SJArmor:equipArmorResponse', source, true, playerArmorData[source], message, targetArmor)
                                break
                            end
                        end
                    end
                end
            end
        end
    end)
end)

local function detectEquippedCarriers()
    local players = GetPlayers()    
    for _, playerId in ipairs(players) do
        local playerIdNum = tonumber(playerId)
        if not playerArmorData[playerIdNum] then
            local playerInv = exports.ox_inventory:GetInventory(playerIdNum)
            if playerInv and playerInv.items then
                for slot, item in pairs(playerInv.items) do
                    if item then
                        if ContainerConfigs[item.name] then
                            if item.metadata then
                                if item.metadata.stashId then
                                else
                                end
                            else
                            end
                        else
                        end
                    end
                    
                    if item and ContainerConfigs[item.name] and item.metadata and item.metadata.stashId then
                        local stashInv = exports.ox_inventory:GetInventory(item.metadata.stashId, false)
                        if stashInv then
                            local virtualArmor, plateCount = calculateVirtualArmor(stashInv)
                            
                            local shouldRestore = item.metadata.equipped and (not Config.UseDragAndDrop or slot == Config.ArmorSlot)
                            
                            if shouldRestore then
                                local lastPlateDurability = 100
                                if plateCount == 1 then
                                    for slotNum, stashItem in pairs(stashInv.items) do
                                        if stashItem and Config.Plates[stashItem.name] then
                                            local d = getDurabilityFromMetadata(stashItem.metadata, stashItem.name)
                                            if d > 0 then
                                                lastPlateDurability = d
                                                break
                                            end
                                        end
                                    end
                                end
                                
                                playerArmorData[playerIdNum] = {
                                    stashId = item.metadata.stashId,
                                    carrierType = item.name,
                                    carrierSlot = slot,
                                    virtualArmor = virtualArmor,
                                    plateCount = plateCount,
                                    lastPlateDurability = lastPlateDurability,
                                    equippedAt = os.time(),
                                    vestDrawable = (item.metadata and item.metadata.vestDrawable)
                                        or (ContainerConfigs[item.name] and ContainerConfigs[item.name].vestDrawable),
                                    vestTexture = (item.metadata and item.metadata.vestTexture)
                                        or (ContainerConfigs[item.name] and ContainerConfigs[item.name].vestTexture),
                                    prevVestDrawable = item.metadata and item.metadata.prevVestDrawable,
                                    prevVestTexture = item.metadata and item.metadata.prevVestTexture,
                                    prevVestPalette = item.metadata and item.metadata.prevVestPalette
                                }
                                
                                local targetArmor = 0
                                if virtualArmor > 0 then
                                    if plateCount > 1 then
                                        targetArmor = 100
                                    else
                                        targetArmor = math.floor(lastPlateDurability)
                                    end
                                end
                                
                                local message = virtualArmor > 0 
                                    and ('Plate carrier restored! %d plates (%d virtual armor)'):format(plateCount, virtualArmor)
                                    or 'Empty plate carrier restored - add plates to activate armor'
                                
                                TriggerClientEvent('SJArmor:equipArmorResponse', playerIdNum, true, playerArmorData[playerIdNum], message, targetArmor)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetTimeout(2000, function()
            detectEquippedCarriers()
        end)
        
        CreateThread(function()
            while true do
                Wait(5000) 
                
                for playerId, armorData in pairs(playerArmorData) do
                    local playerPed = GetPlayerPed(playerId)
                    if not DoesEntityExist(playerPed) then
                        playerArmorData[playerId] = nil
                        goto continue
                    end
                    
            local playerInv = exports.ox_inventory:GetInventory(playerId)
            if playerInv and playerInv.items then
                local expectedSlot = armorData.carrierSlot
                local slotItem = playerInv.items[expectedSlot]
                if not slotItem or not slotItem.metadata or slotItem.metadata.stashId ~= armorData.stashId then
                    if armorData.unequipInProgress then
                    else
                        playerArmorData[playerId] = nil
                        
                        TriggerClientEvent('SJArmor:forceUnequip', playerId)
                    end
                end
            end
                    
                    ::continue::
                end
            end
        end)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        playerArmorData = {}
    end
end)

RegisterNetEvent('SJArmor:openPlateCarrier', function(slot, carrierType)
    local source = source
    local playerInv = exports.ox_inventory:GetInventory(source)
    
    if not playerInv or not playerInv.items[slot] then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'No item found in slot'
        })
        return
    end
    
    local carrierItem = playerInv.items[slot]
    local metadata = carrierItem.metadata or {}
    local stashId = metadata.stashId
    
    if not stashId then
        local success, newStashId = fixPlateCarrierStash(source, slot, carrierType)
        if success then
            stashId = newStashId
            TriggerClientEvent('ox_lib:notify', source, {
                type = 'success',
                description = 'Plate carrier storage fixed! Opening...'
            })
        else
            TriggerClientEvent('ox_lib:notify', source, {
                type = 'error',
                description = 'Failed to fix plate carrier storage'
            })
            return
        end
    end
    
    local playerInv = exports.ox_inventory:GetInventory(source)
    local currentOwner = playerInv and playerInv.owner
    
    local function tryOpenStash()
        local existingStash = exports.ox_inventory:GetInventory(stashId, false)
        if existingStash then
            TriggerClientEvent('ox_inventory:openInventory', source, 'stash', stashId)
            return true
        end
        
        local stashData = registeredStashes[stashId]
        local carrierConfig = nil
        
        if stashData then
            carrierConfig = ContainerConfigs[stashData.type]
        else
            carrierConfig = ContainerConfigs[carrierType]
            if carrierConfig then
                registeredStashes[stashId] = {
                    owner = false,
                    type = carrierType,
                    created = os.time()
                }
            end
        end
        
        if not carrierConfig then
            TriggerClientEvent('ox_lib:notify', source, {
                type = 'error',
                description = 'Unable to open plate carrier storage'
            })
            return false
        end
        
        local registerSuccess = pcall(function()
            exports.ox_inventory:RegisterStash(stashId, carrierConfig.label, carrierConfig.plateSlots, 50000, false, false)
        end)
        
        if registerSuccess then
            if registeredStashes[stashId] then
                registeredStashes[stashId].owner = false
            end
            
            TriggerClientEvent('ox_inventory:openInventory', source, 'stash', stashId)
            return true
        else
            TriggerClientEvent('ox_lib:notify', source, {
                type = 'error',
                description = 'Failed to access plate carrier storage'
            })
            return false
        end
    end
    
    if not tryOpenStash() then
        SetTimeout(100, function()
            if not tryOpenStash() then
                TriggerClientEvent('ox_lib:notify', source, {
                    type = 'error',
                    description = 'Unable to access plate carrier storage. Try closing and reopening the inventory.'
                })
            end
        end)
    end
end)

exports('getPlayerArmorData', function(playerId)
    return playerArmorData[playerId]
end)

exports('setPlayerVirtualArmor', function(playerId, amount)
    if playerArmorData[playerId] then
        playerArmorData[playerId].virtualArmor = amount
        TriggerClientEvent('SJArmor:updateArmor', playerId, playerArmorData[playerId])
        return true
    end
    return false
end)

exports('getRegisteredStashes', function()
    return registeredStashes
end)

exports('GetContainerConfig', function(itemName)
    return ContainerConfigs[itemName]
end)

exports('RegisterPlateCarrierStash', function(stashId, carrierType, owner)
    
    if registeredStashes[stashId] then
        return true
    end
    
    registeredStashes[stashId] = {
        owner = owner,
        type = carrierType,
        created = os.time()
    }
    
    local count = 0
    for id, data in pairs(registeredStashes) do
        count = count + 1
    end
    
    return true
end)

lib.callback.register('SJArmor:checkStashExists', function(source, stashId)
    
    local isRegistered = registeredStashes[stashId] ~= nil
    
    local oxInventory = exports.ox_inventory:GetInventory(stashId, false)
    local existsInOx = oxInventory ~= nil

    return {
        registered = isRegistered,
        existsInOx = existsInOx,
        details = oxInventory and {
            type = oxInventory.type,
            slots = oxInventory.slots,
            maxWeight = oxInventory.maxWeight,
            itemCount = oxInventory.items and #oxInventory.items or 0
        } or nil
    }
end)

local function countActivePlates(stashInv)
    if not stashInv or not stashInv.items then return 0 end
    local count = 0
    for _, itm in pairs(stashInv.items) do
        if itm and Config.Plates[itm.name] then
            local d = (itm.metadata and itm.metadata.durability) or Config.Plates[itm.name].durability or 100
            if d > 0 then count = count + 1 end
        end
    end
    return count
end

local function getInstallParamsForPlate(plateName)
    local cfg = Config.PlateInstall or {}
    if cfg.enabled == false then return nil end

    local base = clone(cfg)
    base.perPlate = nil

    local per = (cfg.perPlate and cfg.perPlate[plateName]) or {}
    local params = deepMerge(base, per)

    -- Always set label to "Installing <Plate Label>"
    if Config.Plates[plateName] and Config.Plates[plateName].label then
        params.label = ("Installing %s"):format(Config.Plates[plateName].label)
    end

    return params
end

exports('useArmorPlate', function(event, item, inventory, slot, data)
    local src = inventory.id
    if plateInstallBusy[src] then
        return lib.notify(src, { type = 'inform', description = 'You are already installing a plate.' })
    end
    plateInstallBusy[src] = true

    local function finish()
        plateInstallBusy[src] = nil
    end

    -- If ox auto-consumed (misconfig), put the plate back on any early exit.
    local function fail(msg, ntype)
        ntype = ntype or 'error'
        -- only restore if the plate is actually gone from the slot
        local slotItem = exports.ox_inventory:GetSlot(src, slot)
        if not slotItem or slotItem.name ~= item.name then
            exports.ox_inventory:AddItem(src, item.name, 1, item.metadata)
        end
        finish()
        return lib.notify(src, { type = ntype, description = msg })
    end

    local armorData = playerArmorData[src]

    -- must be wearing a carrier
    if not armorData then
        return fail('You need to equip a plate carrier first.')
    end

    local carrierType = armorData.carrierType
    local carrierCfg = ContainerConfigs[carrierType]
    if not carrierCfg then
        return fail('Invalid plate carrier.')
    end

    -- plate must be valid
    if not Config.Plates[item.name] then
        return fail('That item is not a plate.')
    end

    -- whitelist check
    local allowed = false
    for _, v in ipairs(carrierCfg.whitelist or {}) do
        if v == item.name then allowed = true break end
    end
    if not allowed then
        return fail('This plate type doesn’t fit your carrier.')
    end

    -- stash must exist
    local stashId = armorData.stashId
    local stashInv = exports.ox_inventory:GetInventory(stashId, false)
    if not stashInv then
        return fail('Carrier storage not found.')
    end

    -- capacity check
    local used = countActivePlates(stashInv)
    if used >= (carrierCfg.plateSlots or 0) then
        return fail('Your carrier is full.')
    end

    -- durability check
    local durability = getDurabilityFromMetadata(item.metadata, item.name)
    if durability <= 0 then
        return fail('This plate is broken.')
    end

    -- ✅ All checks passed — show progress (config-driven)
    local params = getInstallParamsForPlate(item.name)
    if params then
        local ok = lib.callback.await('SJArmor:plateInstallProgress', src, params)
        if not ok then
            return fail('Plate install cancelled.', 'inform')
        end
    end

    -- clone metadata and normalize
    local newMeta = {}
    if item.metadata then
        for k, v in pairs(item.metadata) do newMeta[k] = v end
    end
    newMeta.durability = durability
    newMeta.degrade    = newMeta.durability
    newMeta.weight     = Config.Plates[item.name].weight

    -- add to carrier stash first
    local addOk = exports.ox_inventory:AddItem(stashId, item.name, 1, newMeta, nil)
    if not addOk then
        return fail('Could not install the plate.')
    end

    -- remove from player (only after successful add)
    local removed = exports.ox_inventory:RemoveItem(src, item.name, 1, item.metadata, slot)
    if not removed then
        -- rollback to avoid dupes
        exports.ox_inventory:RemoveItem(stashId, item.name, 1, newMeta)
        return fail('Could not remove the plate from your inventory. Try again.')
    end

    -- recalc armor + weight
    local invNow = exports.ox_inventory:GetInventory(stashId, false)
    local newVirtualArmor, newPlateCount = calculateVirtualArmor(invNow)
    armorData.virtualArmor = newVirtualArmor
    armorData.plateCount   = newPlateCount

    -- last plate durability if only one plate
    local lastPlateDurability = 100
    if newPlateCount == 1 and invNow and invNow.items then
        for _, it in pairs(invNow.items) do
            if it and Config.Plates[it.name] then
                local d = getDurabilityFromMetadata(it.metadata, it.name)
                if d > 0 then lastPlateDurability = d break end
            end
        end
    end
    armorData.lastPlateDurability = lastPlateDurability

    -- set GTA armor target
    local targetArmor = 0
    if newVirtualArmor > 0 then
        if newPlateCount > 1 then targetArmor = 100 else targetArmor = math.floor(lastPlateDurability) end
    end

    -- push to client
    TriggerClientEvent('SJArmor:updateArmor', src, armorData, targetArmor)

    -- update carrier weight metadata
    updatePlateCarrierWeight(src, armorData.carrierSlot, armorData.stashId)

    -- feedback
    TriggerClientEvent('ox_lib:notify', source, {
            type = 'success',
            description = ('Installed %s. Plates: %d/%d.'):format(item.label, newPlateCount, carrierCfg.plateSlots or 0)
        })
    finish()
end)

exports('usePlateCarrier', function(event, item, inventory, slot, data)
    local source = inventory.id
    local metadata = item.metadata
    
    if metadata.stashId then
        local stashInv = exports.ox_inventory:GetInventory(metadata.stashId, false)
        local virtualArmor, plateCount = calculateVirtualArmor(stashInv)
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'inform',
            description = ('Plate carrier: %d plates, %d virtual armor'):format(plateCount, virtualArmor)
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Plate carrier has no storage assigned'
        })
    end
end) 
