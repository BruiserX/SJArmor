local currentArmorData = {}
local isArmorMonitoringActive = false
local isUnequipping = false
local isServerUpdatingArmor = false
local savedKevlarComponent = nil
local isVestApplied = false

function openPlateCarrier(slot, carrierType)
    lib.notify({
        type = 'inform',
        description = 'Opening plate carrier...'
    })
    
    exports.ox_inventory:closeInventory()
    
    SetTimeout(100, function()
        TriggerServerEvent('SJArmor:openPlateCarrier', slot, carrierType)
    end)
end

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
        local ped = cache.ped or PlayerPedId()
        local kevlarComponentId = 9
        local prevDrawable = GetPedDrawableVariation(ped, kevlarComponentId)
        local prevTexture  = GetPedTextureVariation(ped, kevlarComponentId)
        local prevPalette  = GetPedPaletteVariation(ped, kevlarComponentId)
        TriggerServerEvent('SJArmor:equipPlateCarrier', slot, carrierType, prevDrawable, prevTexture, prevPalette)
    end
end

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
        TriggerServerEvent('SJArmor:unequipPlateCarrier')
    end
end

exports('openPlateCarrier', openPlateCarrier)
exports('equipPlateCarrier', equipPlateCarrier)
exports('unequipPlateCarrier', unequipPlateCarrier)

RegisterNetEvent('SJArmor:equipArmorResponse', function(success, armorData, message, targetArmor)
    if success then
        isUnequipping = false
        
        local newVirtualArmor = armorData.virtualArmor
        
        currentArmorData = armorData
        
        isServerUpdatingArmor = true
        
        SetPlayerMaxArmour(cache.serverId, 100)
        SetPedArmour(cache.ped, targetArmor or 0)

        local ped = cache.ped or PlayerPedId()
        if DoesEntityExist(ped) then
            local kevlarComponentId = 9
            local desiredDrawable = armorData and armorData.vestDrawable
            local desiredTexture  = (armorData and armorData.vestTexture) or 0
            if desiredDrawable then
                if not isVestApplied then
                    local currentDrawable = GetPedDrawableVariation(ped, kevlarComponentId)
                    local currentTexture = GetPedTextureVariation(ped, kevlarComponentId)
                    local currentPalette = GetPedPaletteVariation(ped, kevlarComponentId)
                    savedKevlarComponent = {
                        drawable = currentDrawable,
                        texture = currentTexture,
                        palette = currentPalette
                    }
                end
                SetPedComponentVariation(ped, kevlarComponentId, desiredDrawable, desiredTexture, 0)
                isVestApplied = true
            end
        end
        
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

RegisterNetEvent('SJArmor:unequipArmorResponse', function(success, message, targetArmor, prevComponent)
    if success then
        isUnequipping = true
        
        isServerUpdatingArmor = true
        
        currentArmorData = {}
        stopArmorMonitoring()
        
        SetPlayerMaxArmour(cache.serverId, 100)
        SetPedArmour(cache.ped, targetArmor or 0)

        local ped = cache.ped or PlayerPedId()
        if DoesEntityExist(ped) then
            if prevComponent then
                SetPedComponentVariation(ped, 9, prevComponent.drawable or 0, prevComponent.texture or 0, prevComponent.palette or 0)
            elseif isVestApplied and savedKevlarComponent then
                SetPedComponentVariation(ped, 9, savedKevlarComponent.drawable or 0, savedKevlarComponent.texture or 0, savedKevlarComponent.palette or 0)
            end
        end
        savedKevlarComponent = nil
        isVestApplied = false
        
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

RegisterNetEvent('SJArmor:updateArmor', function(armorData, targetArmor)
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

RegisterNetEvent('SJArmor:plateBroken', function(plateName)
    lib.notify({
        type = 'inform',
        icon = 'shield-crack',
        iconColor = 'orange',
        description = ('A %s has shattered'):format(plateName)
    })
end)

RegisterNetEvent('SJArmor:allPlatesBroken', function()
    lib.notify({
        type = 'inform',
        icon = 'shield-halved',
        iconColor = 'red',
        description = 'All armor plates have shattered.'
    })
end)

RegisterNetEvent('SJArmor:forceUnequip', function(prevComponent)
    
    isUnequipping = true
    
    currentArmorData = {}
    stopArmorMonitoring()
    
    SetPlayerMaxArmour(cache.serverId, 100)
    SetPedArmour(cache.ped, 0)

    local ped = cache.ped or PlayerPedId()
    if DoesEntityExist(ped) then
        if isVestApplied and savedKevlarComponent then
            SetPedComponentVariation(ped, 9, savedKevlarComponent.drawable or 0, savedKevlarComponent.texture or 0, savedKevlarComponent.palette or 0)
        elseif prevComponent then
            SetPedComponentVariation(ped, 9, prevComponent.drawable or 0, prevComponent.texture or 0, prevComponent.palette or 0)
        end
    end
    savedKevlarComponent = nil
    isVestApplied = false
    
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
                    TriggerServerEvent('SJArmor:armorDamaged', damageAmount)
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

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        stopArmorMonitoring()
    end
end)


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
                TriggerServerEvent('SJArmor:equipPlateCarrierFromSlot', item.slot, item.metadata, carrierType)
            else
                TriggerServerEvent('SJArmor:cancelEquip', item.slot)
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
            TriggerServerEvent('SJArmor:unequipPlateCarrier')
        end
    end
end)

RegisterNetEvent('SJArmor:startEquipProgress', function(targetSlot, metadata, carrierType)
    
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
        local ped = cache.ped or PlayerPedId()
        if DoesEntityExist(ped) then
            local kevlarComponentId = 9
            metadata = metadata or {}
            metadata.prevVestDrawable = GetPedDrawableVariation(ped, kevlarComponentId)
            metadata.prevVestTexture  = GetPedTextureVariation(ped, kevlarComponentId)
            metadata.prevVestPalette  = GetPedPaletteVariation(ped, kevlarComponentId)
        end
        TriggerServerEvent('SJArmor:equipPlateCarrierFromSlot', targetSlot, metadata, carrierType)
    else
        TriggerServerEvent('SJArmor:cancelEquipAndMoveBack', targetSlot, metadata, carrierType)
    end
end)

RegisterNetEvent('SJArmor:startUnequipProgress', function(fromSlot, metadata, carrierType)
    
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
        TriggerServerEvent('SJArmor:unequipPlateCarrier')
    else
        
        TriggerServerEvent('SJArmor:cancelUnequipAndMoveBack', fromSlot, metadata, carrierType)
    end
end) 