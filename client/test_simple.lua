-- ALPR Test Client - Integrated with MDT
local QBCore = exports['qb-core']:GetCoreObject()
local isALPROpen = false
local isScanning = false
local scanInterval = nil

-- Register commands (keeping for testing purposes)
RegisterCommand('alpr', function()
    if isALPROpen then
        closeALPR()
    else
        openALPR()
    end
end, false)

RegisterCommand('alprscan', function(source, args)
    if not isALPROpen then
        QBCore.Functions.Notify('ALPR system is not open', 'error')
        return
    end
    
    local enabled = args[1]
    if enabled == 'on' or enabled == 'true' then
        startScanning()
    elseif enabled == 'off' or enabled == 'false' then
        stopScanning()
    else
        toggleScanning()
    end
end, false)

-- ALPR Functions
function openALPR()
    if isALPROpen then return end
    
    isALPROpen = true
    
    -- Get player data
    local PlayerData = QBCore.Functions.GetPlayerData()
    local unitName = '1-LINCOLN-18' -- Default unit
    
    if PlayerData and PlayerData.job and PlayerData.job.name == 'police' then
        -- Generate unit name based on player data
        local callsign = PlayerData.metadata.callsign or '18'
        local division = 'LINCOLN' -- Could be dynamic based on player location
        unitName = string.format('%s-%s-%s', '1', division, callsign)
    end
    
    -- Get GPS coordinates
    local coords = GetEntityCoords(PlayerPedId())
    local gpsCoords = {
        x = coords.x,
        y = coords.y,
        z = coords.z
    }
    
    -- Send NUI message to open ALPR
    SendNUIMessage({
        action = 'ALPR_OPEN',
        unit = unitName,
        gpsCoords = gpsCoords
    })
    
    -- Set NUI focus
    SetNuiFocus(true, true)
    
    QBCore.Functions.Notify('ALPR system opened', 'success')
    print('[ALPR] ALPR system opened for unit: ' .. unitName)
end

function closeALPR()
    if not isALPROpen then return end
    
    isALPROpen = false
    stopScanning()
    
    -- Send NUI message to close ALPR
    SendNUIMessage({
        action = 'ALPR_CLOSE'
    })
    
    -- Remove NUI focus
    SetNuiFocus(false, false)
    
    QBCore.Functions.Notify('ALPR system closed', 'info')
    print('[ALPR] ALPR system closed')
end

function toggleScanning()
    if isScanning then
        stopScanning()
    else
        startScanning()
    end
end

function startScanning()
    if isScanning or not isALPROpen then return end
    
    isScanning = true
    
    -- Send NUI message to start scanning
    SendNUIMessage({
        action = 'ALPR_TOGGLE',
        enabled = true
    })
    
    -- Start fake scan interval
    startFakeScanning()
    
    QBCore.Functions.Notify('ALPR scanning started', 'success')
    print('[ALPR] ALPR scanning started')
end

function stopScanning()
    if not isScanning then return end
    
    isScanning = false
    
    -- Send NUI message to stop scanning
    SendNUIMessage({
        action = 'ALPR_TOGGLE',
        enabled = false
    })
    
    -- Stop fake scan interval
    stopFakeScanning()
    
    QBCore.Functions.Notify('ALPR scanning stopped', 'info')
    print('[ALPR] ALPR scanning stopped')
end

function startFakeScanning()
    if scanInterval then return end
    
    local frontRear = true -- Alternate between front and rear
    
    scanInterval = SetInterval(function()
        if not isScanning or not isALPROpen then
            stopFakeScanning()
            return
        end
        
        -- Generate fake plate data
        local plateData = generateFakePlateData(frontRear)
        frontRear = not frontRear -- Toggle for next scan
        
        -- Send scan data to NUI
        SendNUIMessage({
            action = 'ALPR_SCAN',
            payload = plateData
        })
        
        print('[ALPR] Fake scan: ' .. plateData.plate .. ' (' .. plateData.source .. ')')
        
    end, 2000) -- Scan every 2 seconds
end

function stopFakeScanning()
    if scanInterval then
        ClearInterval(scanInterval)
        scanInterval = nil
    end
end

function generateFakePlateData(source)
    -- Generate random plate number
    local plateNumber = generateRandomPlate()
    
    -- Random vehicle data
    local vehicles = {
        { make = 'Vapid', model = 'Scout', color = 'Black' },
        { make = 'Declasse', model = 'Granger', color = 'White' },
        { make = 'Bravado', model = 'Buffalo', color = 'Blue' },
        { make = 'Karin', model = 'Kuruma', color = 'Red' },
        { make = 'Benefactor', model = 'Schafter', color = 'Silver' },
        { make = 'Grotti', model = 'Carbonizzare', color = 'Yellow' },
        { make = 'Pegassi', model = 'Zentorno', color = 'Green' },
        { make = 'Truffade', model = 'Adder', color = 'Orange' }
    }
    
    local vehicle = vehicles[math.random(#vehicles)]
    
    -- Random flags (low probability)
    local flags = {}
    if math.random(100) <= 5 then flags.stolen = true end
    if math.random(100) <= 10 then flags.expired = true end
    if math.random(100) <= 3 then flags.wanted = true end
    if math.random(100) <= 8 then flags.uninsured = true end
    
    -- Random owner
    local owners = {
        'John Doe', 'Jane Smith', 'Mike Johnson', 'Sarah Wilson',
        'David Brown', 'Lisa Davis', 'Chris Miller', 'Amy Taylor'
    }
    
    local owner = owners[math.random(#owners)]
    
    -- Random insurance status
    local insuranceStatus = math.random(100) <= 85 and 'Valid' or 'Expired'
    
    return {
        plate = plateNumber,
        source = source and 'Front' or 'Rear',
        flags = flags,
        vehicle = vehicle,
        owner = owner,
        insurance = insuranceStatus,
        expiry = os.date('%Y-%m-%d', os.time() + math.random(-365, 365) * 24 * 60 * 60)
    }
end

function generateRandomPlate()
    local letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local numbers = '0123456789'
    
    local plate = ''
    
    -- Generate 3 letters
    for i = 1, 3 do
        plate = plate .. string.sub(letters, math.random(1, #letters), math.random(1, #letters))
    end
    
    -- Generate 3 numbers
    for i = 1, 3 do
        plate = plate .. string.sub(numbers, math.random(1, #numbers), math.random(1, #numbers))
    end
    
    return plate
end

-- NUI Callbacks
RegisterNUICallback('alpr_vehicle_info', function(data, cb)
    print('[ALPR] NUI Callback received:', json.encode(data))
    
    if data.action == 'close' then
        closeALPR()
    elseif data.action == 'start_scanning' then
        startScanning()
    elseif data.action == 'stop_scanning' then
        stopScanning()
    elseif data.action == 'vehicle_info' then
        -- Handle vehicle info request
        local plate = data.plate
        print('[ALPR] Vehicle info requested for plate: ' .. plate)
        
        -- In a real implementation, this would query a database
        -- For now, just show a notification
        QBCore.Functions.Notify('Vehicle info requested for plate: ' .. plate, 'info')
        
        -- Simulate opening lb-tablet search
        -- This would trigger the actual tablet search in a real implementation
        print('[ALPR] Would open lb-tablet search for plate: ' .. plate)
    end
    
    cb('ok')
end)

-- Handle ALPR opening from MDT interface
RegisterNUICallback('openALPR', function(data, cb)
    print('[ALPR] ALPR opened from MDT interface')
    openALPR()
    cb('ok')
end)

-- Key mapping for hotkeys
RegisterKeyMapping('alpr', 'Toggle ALPR System', 'keyboard', 'F9')
RegisterKeyMapping('alprscan', 'Toggle ALPR Scanning', 'keyboard', 'F10')

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isALPROpen then
            closeALPR()
        end
    end
end)

-- Player loaded event
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    print('[ALPR] Player loaded, ALPR system ready')
end)

-- Player unloaded event
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if isALPROpen then
        closeALPR()
    end
end)

print('[ALPR] Test client loaded - Use /alpr to open, /alprscan on|off to control scanning')