local currentArmorData = {}
local isArmorMonitoringActive = false
local isUnequipping = false
local isServerUpdatingArmor = false

-- Export function to open plate carrier stash
function openPlateCarrier(slot, carrierType)
    lib.notify({
        type = 'inform',
        description = 'Opening plate carrier...'
    })
    
    exports.ox_inventory:closeInventory()
    
    SetTimeout(100, function()
        TriggerServerEvent('sjarmor:openPlateCarrier', slot, carrierType)
    end)
end

-- Export function to equip plate carrier (for button use)
function equipPlateCarrier(slot, carrierType)
    local success = lib.progressCircle({
        label = Config.EquipSettings.progressText,
        duration = Config.EquipSettings.useTime,
        canCancel = true,
        disable = {
            move = true,
            combat = true,
            mouse = false,
        },
        anim = {
            dict = Config.EquipSettings.animation.dict,
            clip = Config.EquipSettings.animation.clip,
        },
    })
    
    if success then
        TriggerServerEvent('sjarmor:equipPlateCarrier', slot, carrierType)
    end
end

-- Export function to unequip plate carrier (for button use)
function unequipPlateCarrier()
    local success = lib.progressCircle({
        label = Config.UnequipSettings.progressText,
        duration = Config.UnequipSettings.useTime,
        canCancel = true,
        disable = {
            move = true,
            combat = true,
            mouse = false,
        },
        anim = {
            dict = Config.UnequipSettings.animation.dict,
            clip = Config.UnequipSettings.animation.clip,
        },
    })
    
    if success then
        TriggerServerEvent('sjarmor:unequipPlateCarrier')
    end
end

-- Register exports
exports('openPlateCarrier', openPlateCarrier)
exports('equipPlateCarrier', equipPlateCarrier)
exports('unequipPlateCarrier', unequipPlateCarrier)

-- Handle equipping plate carrier from server
RegisterNetEvent('sjarmor:equipArmorResponse', function(success, armorData, message, targetArmor)
    if success then
        isUnequipping = false
        
        local newVirtualArmor = armorData.virtualArmor
        
        currentArmorData = armorData
        
        isServerUpdatingArmor = true
        
        SetPlayerMaxArmour(cache.serverId, 100)
        SetPedArmour(cache.ped, targetArmor or 0)
        
        SetTimeout(1000, function()
            isServerUpdatingArmor = false
        end)
        
        if newVirtualArmor > 0 then
            startArmorMonitoring()
        else
            stopArmorMonitoring()
        end
        
        lib.notify({
            type = 'success',
            description = message or ('Plate carrier equipped! Virtual armor: %d'):format(newVirtualArmor)
        })
    else
        lib.notify({
            type = 'error',
            description = message or 'Failed to equip plate carrier'
        })
    end
end)

-- Handle unequipping plate carrier from server
RegisterNetEvent('sjarmor:unequipArmorResponse', function(success, message, targetArmor)
    if success then
        isUnequipping = true
        
        isServerUpdatingArmor = true
        
        currentArmorData = {}
        stopArmorMonitoring()
        
        SetPlayerMaxArmour(cache.serverId, 100)
        SetPedArmour(cache.ped, targetArmor or 0)
        
        SetTimeout(100, function()
            isUnequipping = false
        end)
        SetTimeout(1000, function()
            isServerUpdatingArmor = false
        end)
        
        lib.notify({
            type = 'success',
            description = message or 'Plate carrier removed'
        })
    else
        lib.notify({
            type = 'error',
            description = message or 'Failed to remove plate carrier'
        })
    end
end)

-- Handle armor updates from server
RegisterNetEvent('sjarmor:updateArmor', function(armorData, targetArmor)
    if armorData.virtualArmor > 0 then
        isUnequipping = false
    end

    isServerUpdatingArmor = true
    
    currentArmorData = armorData
    
    SetPlayerMaxArmour(cache.serverId, 100)
    SetPedArmour(cache.ped, targetArmor or 0)
    
    SetTimeout(1000, function()
        isServerUpdatingArmor = false
    end)
    
    if armorData.virtualArmor > 0 then
        if not isArmorMonitoringActive then
            startArmorMonitoring()
        end
    else
        stopArmorMonitoring()
    end
end)

-- Handle plate breaking notification
RegisterNetEvent('sjarmor:plateBroken', function(plateName)
    lib.notify({
        type = 'inform',
        icon = 'shield-crack',
        iconColor = 'orange',
        description = ('A %s has shattered'):format(plateName)
    })
end)

-- Handle all plates broken notification
RegisterNetEvent('sjarmor:allPlatesBroken', function()
    lib.notify({
        type = 'inform',
        icon = 'shield-halved',
        iconColor = 'red',
        description = 'All armor plates have shattered.'
    })
end)

-- Handle forced unequip
RegisterNetEvent('sjarmor:forceUnequip', function()
    
    isUnequipping = true
    
    currentArmorData = {}
    stopArmorMonitoring()
    
    SetPlayerMaxArmour(cache.serverId, 100)
    SetPedArmour(cache.ped, 0)
    
    SetTimeout(100, function()
        isUnequipping = false
    end)
    
    lib.notify({
        type = 'inform',
        icon = 'shield-halved',
        iconColor = 'orange',
        description = 'Plate carrier was removed improperly - armor disabled.'
    })
end)

function startArmorMonitoring()
    if isArmorMonitoringActive then 
        return 
    end
    
    isArmorMonitoringActive = true
    
    CreateThread(function()
        local lastCheckedArmor = GetPedArmour(cache.ped)
        local lastDamageTime = 0
        
        while isArmorMonitoringActive do
            Wait(300)
            
            local currentGtaArmor = GetPedArmour(cache.ped)
            local currentTime = GetGameTimer()
            
            if currentGtaArmor < lastCheckedArmor and (currentTime - lastDamageTime) > 500 and not isServerUpdatingArmor then
                local damageAmount = lastCheckedArmor - currentGtaArmor
                

                if damageAmount >= math.max(Config.DamageSettings.minimumDamageThreshold, 5) then
                    TriggerServerEvent('sjarmor:armorDamaged', damageAmount)
                    lastDamageTime = currentTime
                else
                end
            elseif isServerUpdatingArmor then
                if currentGtaArmor ~= lastCheckedArmor then
                end
                lastCheckedArmor = currentGtaArmor
            elseif currentGtaArmor < lastCheckedArmor and (currentTime - lastDamageTime) <= 500 then   
            end
            
            lastCheckedArmor = currentGtaArmor
            
            if not currentArmorData.virtualArmor or currentArmorData.virtualArmor <= 0 then
                isArmorMonitoringActive = false
                break
            end
        end
        
    end)
end

function stopArmorMonitoring()
    isArmorMonitoringActive = false
    if isUnequipping then
        currentArmorData = {}
    end
end

-- Stop monitoring when resource stops
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        stopArmorMonitoring()
    end
end)

-- Listen for armor slot changes
RegisterNetEvent('ox_inventory:armorSlotChanged', function(item, action)
    if action == 'equipped' and item then
        local carrierType = nil
        if item.name then
            carrierType = item.name
        end
        
        if carrierType then
            local success = lib.progressCircle({
                label = Config.EquipSettings.progressText,
                duration = Config.EquipSettings.useTime,
                canCancel = true,
                disable = {
                    move = true,
                    combat = true,
                    mouse = false,
                },
                anim = {
                    dict = Config.EquipSettings.animation.dict,
                    clip = Config.EquipSettings.animation.clip,
                },
            })
            
            if success then
                TriggerServerEvent('sjarmor:equipPlateCarrierFromSlot', item.slot, item.metadata, carrierType)
            else
                TriggerServerEvent('sjarmor:cancelEquip', item.slot)
            end
        end
    elseif action == 'unequipped' then
        local success = lib.progressCircle({
            label = Config.UnequipSettings.progressText,
            duration = Config.UnequipSettings.useTime,
            canCancel = true,
            disable = {
                move = true,
                combat = true,
                mouse = false,
            },
            anim = {
                dict = Config.UnequipSettings.animation.dict,
                clip = Config.UnequipSettings.animation.clip,
            },
        })
        
        if success then
            TriggerServerEvent('sjarmor:unequipPlateCarrier')
        end
    end
end)

-- Handle starting equip progress for drag-to-slot
RegisterNetEvent('sjarmor:startEquipProgress', function(targetSlot, metadata, carrierType)
    
    exports.ox_inventory:closeInventory()
    
    local success = lib.progressCircle({
        label = Config.EquipSettings.progressText,
        duration = Config.EquipSettings.useTime,
        canCancel = true,
        disable = {
            move = true,
            combat = true,
            mouse = false,
        },
        anim = {
            dict = Config.EquipSettings.animation.dict,
            clip = Config.EquipSettings.animation.clip,
        },
    })
    
    if success then
        TriggerServerEvent('sjarmor:equipPlateCarrierFromSlot', targetSlot, metadata, carrierType)
    else
        TriggerServerEvent('sjarmor:cancelEquipAndMoveBack', targetSlot, metadata, carrierType)
    end
end)

-- Handle starting unequip progress for drag-away-from-slot
RegisterNetEvent('sjarmor:startUnequipProgress', function(fromSlot, metadata, carrierType)
    
    exports.ox_inventory:closeInventory()
    
    local success = lib.progressCircle({
        label = Config.UnequipSettings.progressText,
        duration = Config.UnequipSettings.useTime,
        canCancel = true,
        disable = {
            move = true,
            combat = true,
            mouse = false,
        },
        anim = {
            dict = Config.UnequipSettings.animation.dict,
            clip = Config.UnequipSettings.animation.clip,
        },
    })
    
    if success then
        TriggerServerEvent('sjarmor:unequipPlateCarrier')
    else
        
        TriggerServerEvent('sjarmor:cancelUnequipAndMoveBack', fromSlot, metadata, carrierType)
    end
end) 