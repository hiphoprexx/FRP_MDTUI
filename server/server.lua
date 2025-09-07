local QBCore = exports['qb-core']:GetCoreObject()

-- Get online players with specific jobs
function GetOnlineCops()
    local cops = {}
    local players = QBCore.Functions.GetQBPlayers()
    
    for _, player in pairs(players) do
        if player.PlayerData.job and Config.PoliceJobs[player.PlayerData.job.name] then
            table.insert(cops, player.PlayerData.source)
        end
    end
    
    return cops
end

function GetOnlineEMS()
    local ems = {}
    local players = QBCore.Functions.GetQBPlayers()
    
    for _, player in pairs(players) do
        if player.PlayerData.job and Config.EMSJobs[player.PlayerData.job.name] then
            table.insert(ems, player.PlayerData.source)
        end
    end
    
    return ems
end

-- Auto-detect priority based on alert type and keywords
function DetectPriority(data)
    local text = string.lower((data.type or '') .. ' ' .. (data.description or '') .. ' ' .. (data.emergency or ''))
    
    -- High priority indicators
    if string.find(text, 'panic') or string.find(text, 'officer down') or string.find(text, 'shots fired') or 
       string.find(text, 'armed') or string.find(text, 'hostage') or string.find(text, 'bomb') or
       string.find(text, 'fire') or string.find(text, 'explosion') or string.find(text, 'emergency') then
        return 'Code 3'
    end
    
    -- Medium priority indicators
    if string.find(text, 'assault') or string.find(text, 'robbery') or string.find(text, 'theft') or
       string.find(text, 'traffic') or string.find(text, 'accident') or string.find(text, 'disturbance') then
        return 'Code 2'
    end
    
    -- Default to Code 1 for routine calls
    return 'Code 1'
end

-- Normalize external alert data to our schema
function Normalize(data)
    local normalized = {
        address = data.location or data.address or 'Unknown Location',
        area = data.area or 'Unknown Area',
        county = data.county or 'Los Santos',
        agency = data.agency or Config.DefaultAgency,
        priority = data.priority or DetectPriority(data),
        unit = data.unit or Config.DefaultUnit,
        status = data.status or Config.DefaultStatus,
        details = data.details or { 'No details provided' },
        timestamp = data.timestamp or os.time()
    }
    
    return normalized
end

-- Broadcast payload to specific targets
function Broadcast(payload, targetIds)
    if not payload then return end
    
    local normalized = Normalize(payload)
    
    if targetIds then
        -- Send to specific players
        for _, id in pairs(targetIds) do
            TriggerClientEvent('FRP_MDTUI:show', id, normalized)
        end
    else
        -- Auto-detect based on agency
        if Config.PoliceJobs[normalized.agency] or normalized.agency == Config.DefaultAgency then
            local cops = GetOnlineCops()
            for _, id in pairs(cops) do
                TriggerClientEvent('FRP_MDTUI:show', id, normalized)
            end
        elseif Config.EMSJobs[normalized.agency] or normalized.agency == 'LSFD' then
            local ems = GetOnlineEMS()
            for _, id in pairs(ems) do
                TriggerClientEvent('FRP_MDTUI:show', id, normalized)
            end
        end
    end
end

-- Test command
RegisterNetEvent('FRP_MDTUI:test', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local testPayload = {
        address = '123 Test Street',
        area = 'Test Area',
        county = 'Test County',
        agency = Player.PlayerData.job.name == 'police' and 'LSPD' or 'LSFD',
        priority = 'Code 2',
        unit = Player.PlayerData.job.grade.name .. '-' .. Player.PlayerData.charinfo.firstname .. '-' .. Player.PlayerData.job.grade.level,
        status = 'Available',
        details = {
            '------ TEST INCIDENT at ' .. os.date('%m/%d/%y %H:%M:%S') .. ' ------',
            'This is a test callout for the MDT UI.',
            'Please verify all functionality is working correctly.',
            'Location: Test coordinates',
            'Units responding: Test units'
        },
        timestamp = os.time()
    }
    
    TriggerClientEvent('FRP_MDTUI:show', src, testPayload)
end)

-- Handle client status updates
RegisterNetEvent('FRP_MDTUI:statusUpdate', function(status)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Update player status in database or broadcast to other clients
    print('^2[FRP_MDTUI]^7 Player ' .. Player.PlayerData.charinfo.firstname .. ' status: ' .. status)
end)

-- Handle UI state events
RegisterNetEvent('FRP_MDTUI:UIOpenState', function(state)
    local src = source
    -- Broadcast UI state to all clients
    TriggerClientEvent('FRP_MDTUI:UIOpenState', src, state)
end)



-- Get active dispatches for computer interface
RegisterNetEvent('FRP_MDTUI:getActiveDispatches', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.PoliceJobs[Player.PlayerData.job.name] then return end
    
    -- Convert activeDispatches to incidents format
    local incidents = {}
    for dispatchId, dispatch in pairs(activeDispatches) do
        table.insert(incidents, {
            id = dispatchId,
            description = dispatch.description or 'Unknown Incident',
            priority = dispatch.priority or 'Code 1',
            unit = dispatch.respondingUnit or 'N/A',
            lastUpdate = dispatch.lastUpdate or os.date('%m/%d/%y %H:%M:%S'),
            address = dispatch.address,
            details = dispatch.details
        })
    end
    
    -- Send incidents to client
    TriggerClientEvent('FRP_MDTUI:receiveActiveDispatches', src, incidents)
end)

-- Get player callsign from lb-tablet
RegisterNetEvent('FRP_MDTUI:getPlayerCallsign', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.PoliceJobs[Player.PlayerData.job.name] then return end
    
    local callsign = GetPlayerCallsignFromTablet(Player)
    
    -- Send callsign to client
    TriggerClientEvent('FRP_MDTUI:receiveCallsign', src, callsign, Player.PlayerData.job.grade.name)
end)

-- ALPR System Events
RegisterNetEvent('FRP_MDTUI:processPlate', function(plateData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.PoliceJobs[Player.PlayerData.job.name] then 
        print('^1[FRP_MDTUI]^7 Player not authorized for ALPR:', src, Player and Player.PlayerData.job.name or 'No Player')
        return 
    end
    
    print('^3[FRP_MDTUI]^7 Processing plate:', plateData.plate, 'from player:', src)
    
    -- Clean plate text (remove spaces and convert to uppercase)
    local cleanPlate = string.gsub(plateData.plate, "%s+", "")
    cleanPlate = string.upper(cleanPlate)
    
    -- Check for BOLO flags using lb-tablet
    local flags = {}
    local isBolo = false
    
    -- Check if plate is in BOLO database
    local success, boloResult = pcall(function()
        return exports['lb-tablet']:GetBolo(cleanPlate)
    end)
    
    if success and boloResult then
        table.insert(flags, 'bolo')
        isBolo = true
        print('^1[FRP_MDTUI]^7 BOLO ALERT: Plate ' .. cleanPlate .. ' is flagged!')
    end
    
    -- Check for expired registration (placeholder - you'd implement this based on your system)
    -- if IsExpiredRegistration(cleanPlate) then
    --     table.insert(flags, 'expired')
    -- end
    
    -- Check for stolen vehicle (placeholder - you'd implement this based on your system)
    -- if IsStolenVehicle(cleanPlate) then
    --     table.insert(flags, 'stolen')
    -- end
    
    -- Send plate data to client
    local plateInfo = {
        plate = cleanPlate,
        source = plateData.source,
        timestamp = plateData.timestamp,
        flags = flags,
        plateType = 'blue' -- Default plate type
    }
    
    print('^2[FRP_MDTUI]^7 Sending plate detection to client:', src, 'Plate:', cleanPlate)
    TriggerClientEvent('FRP_MDTUI:plateDetected', src, plateInfo)
    
    -- If BOLO, send alert to all police officers
    if isBolo then
        local cops = GetOnlineCops()
        for _, id in pairs(cops) do
            TriggerClientEvent('FRP_MDTUI:boloAlert', id, plateInfo)
        end
    end
end)

RegisterNetEvent('FRP_MDTUI:getVehicleInfo', function(plate)
    local src = source
    print('^3[FRP_MDTUI]^7 getVehicleInfo event received from player:', src, 'for plate:', plate)
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        print('^1[FRP_MDTUI]^7 Player not found for source:', src)
        return
    end
    
    if not Config.PoliceJobs[Player.PlayerData.job.name] then
        print('^1[FRP_MDTUI]^7 Player not authorized for vehicle lookup:', Player.PlayerData.job.name)
        return
    end
    
    print('^3[FRP_MDTUI]^7 Getting vehicle info for plate:', plate, 'from player:', Player.PlayerData.charinfo.firstname)
    
    -- Clean plate text
    local cleanPlate = string.gsub(plate, "%s+", "")
    cleanPlate = string.upper(cleanPlate)
    
    -- Try to get vehicle information from lb-tablet first
    local vehicleData = nil
    print('^3[FRP_MDTUI]^7 Attempting to get vehicle info from lb-tablet for plate:', cleanPlate)
    
    local success, result = pcall(function()
        return exports['lb-tablet']:GetVehicle(cleanPlate)
    end)
    
    if success then
        print('^3[FRP_MDTUI]^7 lb-tablet call successful, result:', json.encode(result))
        if result and result.model then
            print('^2[FRP_MDTUI]^7 Found vehicle info from lb-tablet for plate:', cleanPlate)
            -- Vehicle found in database - get additional info if available
            local ownerName = 'Unknown'
            local registration = 'Valid'
            local insurance = 'Valid'
            
            -- Try to get owner info from lb-tablet if available
            if result.owner then
                ownerName = result.owner
            elseif result.firstname and result.lastname then
                ownerName = result.firstname .. ' ' .. result.lastname
            end
            
            -- Check for registration and insurance status if available
            if result.registration == false or result.registration == 'false' then
                registration = 'Invalid'
            end
            if result.insurance == false or result.insurance == 'false' then
                insurance = 'Invalid'
            end
            
            vehicleData = {
                plate = cleanPlate,
                model = result.model or 'Unknown Model',
                owner = ownerName,
                registration = registration,
                insurance = insurance,
                status = 'Registered',
                isStolen = false
            }
        else
            print('^1[FRP_MDTUI]^7 lb-tablet returned no data for plate:', cleanPlate)
            -- Vehicle not found in database - likely stolen or unregistered
            vehicleData = {
                plate = cleanPlate,
                model = 'Unknown Model',
                owner = 'No Record Found',
                registration = 'Invalid/Stolen',
                insurance = 'Invalid/Stolen',
                status = 'STOLEN/UNREGISTERED',
                isStolen = true,
                flags = {'stolen', 'unregistered'}
            }
        end
    else
        print('^1[FRP_MDTUI]^7 lb-tablet call failed, error:', result)
        -- lb-tablet not available or error - mark as stolen/unregistered
        vehicleData = {
            plate = cleanPlate,
            model = 'Unknown Model',
            owner = 'No Record Found',
            registration = 'Invalid/Stolen',
            insurance = 'Invalid/Stolen',
            status = 'STOLEN/UNREGISTERED',
            isStolen = true,
            flags = {'stolen', 'unregistered'}
        }
    end
    
    -- Add additional vehicle information
    vehicleData.plate = cleanPlate
    vehicleData.timestamp = os.time()
    vehicleData.searchedBy = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    print('^2[FRP_MDTUI]^7 Sending vehicle info response to client:', src, 'Data:', json.encode(vehicleData))
    TriggerClientEvent('FRP_MDTUI:receiveVehicleInfo', src, vehicleData)
    
    -- Trigger vehicle info dispatch audio
    local callsign = GetPlayerCallsignFromTablet(Player)
    local isStolen = vehicleData.isStolen or false
    
    print('^3[FRP_MDTUI]^7 Server sending audio dispatch - Callsign:', callsign, 'Type:', type(callsign))
    
    TriggerClientEvent('FRP_MDTUI:playVehicleInfoAudio', src, callsign, cleanPlate, isStolen)
    
    print('^2[FRP_MDTUI]^7 Vehicle info response sent successfully')
end)

-- Get player callsign for status update
RegisterNetEvent('FRP_MDTUI:getPlayerCallsignForStatus', function(status, dispatchId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Config.PoliceJobs[Player.PlayerData.job.name] then return end
    
    local callsign = GetPlayerCallsignFromTablet(Player)
    
    -- Update dispatch status if dispatchId is provided
    if dispatchId and activeDispatches[dispatchId] then
        -- Update our local dispatch data
        activeDispatches[dispatchId].status = status
        activeDispatches[dispatchId].respondingUnit = callsign
        
        -- Update lb-tablet dispatch if it exists
        local lbDispatch = exports['lb-tablet']:GetDispatch(dispatchId)
        if lbDispatch then
            -- Update the dispatch in lb-tablet
            local updatedDispatch = {
                priority = lbDispatch.priority,
                code = lbDispatch.code,
                title = lbDispatch.title,
                description = lbDispatch.description,
                location = lbDispatch.location,
                time = lbDispatch.time,
                job = lbDispatch.job,
                sound = lbDispatch.sound,
                fields = lbDispatch.fields or {}
            }
            
            -- Add status update to fields
            table.insert(updatedDispatch.fields, {
                icon = 'person',
                label = 'Status Update',
                value = callsign .. ' - ' .. status
            })
            
            exports['lb-tablet']:UpdateDispatch(dispatchId, updatedDispatch)
        end
        
        -- If status is Code 4, close the dispatch
        if status == 'Code 4' then
            exports['lb-tablet']:RemoveDispatch(dispatchId)
            activeDispatches[dispatchId] = nil
            print('^2[FRP_MDTUI]^7 Dispatch ' .. dispatchId .. ' closed (Code 4)')
        end
        
        -- Notify all police about the status update
        local cops = GetOnlineCops()
        for _, id in pairs(cops) do
            TriggerClientEvent('FRP_MDTUI:dispatchStatusUpdate', id, dispatchId, status, callsign)
        end
    end
end)

-- Helper function to get callsign from lb-tablet
function GetPlayerCallsignFromTablet(Player)
    local identifier = Player.PlayerData.citizenid
    local callsign = nil
    
    -- Try to get callsign from lb-tablet using the server export
    local success, result = pcall(function()
        return exports['lb-tablet']:GetPoliceCallsign(identifier)
    end)
    
    if success and result and result ~= nil and result ~= '' then
        callsign = result
        print('^2[FRP_MDTUI]^7 Found callsign from lb-tablet: ' .. callsign)
    else
        -- Fallback to generating a callsign
        local gradeLevel = Player.PlayerData.job.grade.level or 0
        local firstName = Player.PlayerData.charinfo.firstname or 'UNIT'
        
        local nameHash = 0
        for i = 1, #firstName do
            nameHash = nameHash + string.byte(firstName, i)
        end
        
        local callsignNumber = (gradeLevel * 100 + (nameHash % 100)) % 1000
        callsign = string.format('%03d', callsignNumber)
        print('^3[FRP_MDTUI]^7 Generated callsign: ' .. callsign .. ' (fallback)')
    end
    
    return callsign
end

-- Exports
exports('Broadcast', Broadcast)
exports('Normalize', Normalize)
exports('GetOnlineCops', GetOnlineCops)
exports('GetOnlineEMS', GetOnlineEMS)
exports('GetActiveDispatches', function() return activeDispatches end)
exports('CreateDispatch', function(data)
    TriggerEvent('lb-tablet:dispatch', data)
end)

-- Bridge events for external resources
RegisterNetEvent('FRP_MDTUI:broadcast', function(payload, targetIds)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Validate payload
    if not payload or type(payload) ~= 'table' then
        print('[FRP_MDTUI] Invalid payload received from player ' .. src)
        return
    end
    
    Broadcast(payload, targetIds)
end)

-- ========================================
-- LB-TABLET INTEGRATION
-- ========================================

-- Store active dispatches for the computer interface
local activeDispatches = {}

-- Listen for lb-tablet dispatch events and create dispatch
RegisterNetEvent('lb-tablet:dispatch', function(data)
    print('^3[FRP_MDTUI]^7 Received lb-tablet dispatch:', json.encode(data))
    
    -- Create dispatch in lb-tablet system
    local dispatchData = {
        priority = data.priority or 'medium',
        code = data.code or '10-54',
        title = data.title or data.type or 'Incident',
        description = data.description or 'No description provided',
        location = {
            label = data.location or data.address or 'Unknown Location',
            coords = data.coords or vector2(0.0, 0.0)
        },
        time = data.time or 300, -- 5 minutes default
        job = 'police',
        sound = data.sound or 'notification.mp3',
        fields = data.fields or {}
    }
    
    -- Add dispatch to lb-tablet
    local dispatchId = exports['lb-tablet']:AddDispatch(dispatchData)
    
    if dispatchId then
        print('^2[FRP_MDTUI]^7 Created lb-tablet dispatch with ID:', dispatchId)
        
        -- Store dispatch data for computer interface
        activeDispatches[dispatchId] = {
            id = dispatchId,
            address = data.location or data.address or 'Unknown Location',
            area = data.area or data.zone or 'Unknown Area',
            county = data.county or 'Los Santos',
            agency = 'LSPD',
            priority = data.priority or 'Code 2',
            unit = data.unit or 'Dispatch',
            status = 'New',
            details = {
                '------ INCIDENT OPENED at ' .. os.date('%m/%d/%y %H:%M:%S') .. ' ------',
                'Type: ' .. (data.type or 'Unknown'),
                'Description: ' .. (data.description or 'No description'),
                'Caller: ' .. (data.caller or 'Anonymous'),
                'Phone: ' .. (data.phone or 'N/A'),
                'Priority: ' .. (data.priority or 'Code 2'),
                'Units: ' .. (data.units or 'Available units')
            },
            timestamp = os.time(),
            lbTabletId = dispatchId
        }
        
        -- Add additional details if available
        if data.weapons then
            table.insert(activeDispatches[dispatchId].details, 'Weapons: ' .. data.weapons)
        end
        
        if data.vehicles then
            table.insert(activeDispatches[dispatchId].details, 'Vehicles: ' .. data.vehicles)
        end
        
        if data.suspects then
            table.insert(activeDispatches[dispatchId].details, 'Suspects: ' .. data.suspects)
        end
        
        -- Notify all police officers about the new dispatch
        local cops = GetOnlineCops()
        for _, id in pairs(cops) do
            TriggerClientEvent('FRP_MDTUI:newDispatch', id, activeDispatches[dispatchId])
        end
    else
        print('^1[FRP_MDTUI]^7 Failed to create lb-tablet dispatch')
    end
end)

-- Listen for lb-tablet callout events
RegisterNetEvent('lb-tablet:callout', function(data)
    print('^3[FRP_MDTUI]^7 Received lb-tablet callout:', json.encode(data))
    
    local payload = {
        address = data.location or data.address or 'Unknown Location',
        area = data.area or data.zone or 'Unknown Area',
        county = data.county or 'Los Santos',
        agency = 'LSPD',
        priority = data.priority or 'Code 2',
        unit = data.unit or 'Callout',
        status = 'Active',
        details = {
            '------ LB-TABLET CALLOUT ------',
            'Callout: ' .. (data.name or 'Unknown Callout'),
            'Description: ' .. (data.description or 'No description'),
            'Type: ' .. (data.type or 'Unknown'),
            'Time: ' .. os.date('%m/%d/%y %H:%M:%S'),
            'Priority: ' .. (data.priority or 'Code 2'),
            'Status: Active Callout'
        },
        timestamp = os.time()
    }
    
    -- Add callout-specific details
    if data.objectives then
        for _, objective in ipairs(data.objectives or {}) do
            table.insert(payload.details, 'Objective: ' .. objective)
        end
    end
    
    if data.requirements then
        table.insert(payload.details, 'Requirements: ' .. data.requirements)
    end
    
    -- Broadcast(payload) -- Commented out to prevent auto-opening
end)

-- Listen for lb-tablet alert events
RegisterNetEvent('lb-tablet:alert', function(data)
    print('^3[FRP_MDTUI]^7 Received lb-tablet alert:', json.encode(data))
    
    local payload = {
        address = data.location or data.address or 'Unknown Location',
        area = data.area or data.zone or 'Unknown Area',
        county = data.county or 'Los Santos',
        agency = 'LSPD',
        priority = data.priority or 'Code 2',
        unit = data.unit or 'Alert',
        status = 'Alert',
        details = {
            '------ LB-TABLET ALERT ------',
            'Alert Type: ' .. (data.alertType or 'Unknown'),
            'Message: ' .. (data.message or 'No message'),
            'Time: ' .. os.date('%m/%d/%y %H:%M:%S'),
            'Priority: ' .. (data.priority or 'Code 2'),
            'Source: ' .. (data.source or 'lb-tablet')
        },
        timestamp = os.time()
    }
    
    -- Add alert-specific details
    if data.target then
        table.insert(payload.details, 'Target: ' .. data.target)
    end
    
    if data.reason then
        table.insert(payload.details, 'Reason: ' .. data.reason)
    end
    
    -- Broadcast(payload) -- Commented out to prevent auto-opening
end)

-- Listen for lb-tablet 911 calls
RegisterNetEvent('lb-tablet:911', function(data)
    print('^3[FRP_MDTUI]^7 Received lb-tablet 911 call:', json.encode(data))
    
    local payload = {
        address = data.location or data.address or 'Unknown Location',
        area = data.area or data.zone or 'Unknown Area',
        county = data.county or 'Los Santos',
        agency = 'LSPD',
        priority = data.priority or 'Code 2',
        unit = data.unit or '911',
        status = 'New 911 Call',
        details = {
            '------ 911 EMERGENCY CALL ------',
            'Caller: ' .. (data.caller or 'Anonymous'),
            'Phone: ' .. (data.phone or 'N/A'),
            'Emergency: ' .. (data.emergency or 'Unknown'),
            'Description: ' .. (data.description or 'No description'),
            'Time: ' .. os.date('%m/%d/%y %H:%M:%S'),
            'Priority: ' .. (data.priority or 'Code 2')
        },
        timestamp = os.time()
    }
    
    -- Add emergency-specific details
    if data.injuries then
        table.insert(payload.details, 'Injuries: ' .. data.injuries)
    end
    
    if data.weapons then
        table.insert(payload.details, 'Weapons: ' .. data.weapons)
    end
    
    if data.suspects then
        table.insert(payload.details, 'Suspects: ' .. data.suspects)
    end
    
    -- Broadcast(payload) -- Commented out to prevent auto-opening
end)

-- Listen for lb-tablet backup requests
RegisterNetEvent('lb-tablet:backup', function(data)
    print('^3[FRP_MDTUI]^7 Received lb-tablet backup request:', json.encode(data))
    
    local payload = {
        address = data.location or data.address or 'Unknown Location',
        area = data.area or data.zone or 'Unknown Area',
        county = data.county or 'Los Santos',
        agency = 'LSPD',
        priority = data.priority or 'Code 3',
        unit = data.unit or 'Backup',
        status = 'Backup Requested',
        details = {
            '------ BACKUP REQUEST ------',
            'Officer: ' .. (data.officer or 'Unknown'),
            'Reason: ' .. (data.reason or 'No reason given'),
            'Type: ' .. (data.backupType or 'Code 3'),
            'Time: ' .. os.date('%m/%d/%y %H:%M:%S'),
            'Priority: ' .. (data.priority or 'Code 3'),
            'Status: Backup Requested'
        },
        timestamp = os.time()
    }
    
    -- Add backup-specific details
    if data.backupType then
        table.insert(payload.details, 'Backup Type: ' .. data.backupType)
    end
    
    if data.additionalInfo then
        table.insert(payload.details, 'Additional Info: ' .. data.additionalInfo)
    end
    
    -- Broadcast(payload) -- Commented out to prevent auto-opening
end)

-- Listen for lb-tablet panic button
RegisterNetEvent('lb-tablet:panic', function(data)
    print('^1[FRP_MDTUI]^7 Received lb-tablet PANIC button:', json.encode(data))
    
    local payload = {
        address = data.location or data.address or 'Unknown Location',
        area = data.area or data.zone or 'Unknown Area',
        county = data.county or 'Los Santos',
        agency = 'LSPD',
        priority = 'Code 3',
        unit = data.unit or 'PANIC',
        status = 'PANIC BUTTON ACTIVATED',
        details = {
            '------ PANIC BUTTON ACTIVATED ------',
            'Officer: ' .. (data.officer or 'Unknown'),
            'Location: ' .. (data.location or 'Unknown'),
            'Time: ' .. os.date('%m/%d/%y %H:%M:%S'),
            'Priority: Code 3 - EMERGENCY',
            'Status: PANIC BUTTON - IMMEDIATE RESPONSE REQUIRED'
        },
        timestamp = os.time()
    }
    
    -- Add panic-specific details
    if data.reason then
        table.insert(payload.details, 'Reason: ' .. data.reason)
    end
    
    if data.additionalInfo then
        table.insert(payload.details, 'Additional Info: ' .. data.additionalInfo)
    end
    
    -- Broadcast(payload) -- Commented out to prevent auto-opening
end)

-- ========================================
-- WASABI_POLICE INTEGRATION (if available)
-- ========================================

-- Listen for wasabi_police events (if the resource exists)
RegisterNetEvent('wasabi_police:dispatch', function(data)
    print('^3[FRP_MDTUI]^7 Received wasabi_police dispatch:', json.encode(data))
    
    local payload = {
        address = data.location or data.address or 'Unknown Location',
        area = data.area or data.zone or 'Unknown Area',
        county = data.county or 'Los Santos',
        agency = 'LSPD',
        priority = data.priority or 'Code 2',
        unit = data.unit or 'Wasabi Dispatch',
        status = 'New',
        details = {
            '------ WASABI POLICE DISPATCH ------',
            'Type: ' .. (data.type or 'Unknown'),
            'Description: ' .. (data.description or 'No description'),
            'Time: ' .. os.date('%m/%d/%y %H:%M:%S'),
            'Priority: ' .. (data.priority or 'Code 2')
        },
        timestamp = os.time()
    }
    
    -- Broadcast(payload) -- Commented out to prevent auto-opening
end)

-- ========================================
-- ADDITIONAL LB-TABLET EVENT PATTERNS
-- ========================================

-- Listen for lb-tablet location-based events
RegisterNetEvent('lb-tablet:location', function(data)
    print('^3[FRP_MDTUI]^7 Received lb-tablet location event:', json.encode(data))
    
    local payload = {
        address = data.location or data.address or 'Unknown Location',
        area = data.area or data.zone or 'Unknown Area',
        county = data.county or 'Los Santos',
        agency = 'LSPD',
        priority = data.priority or DetectPriority(data),
        unit = data.unit or 'Location Alert',
        status = 'New',
        details = {
            '------ LOCATION ALERT ------',
            'Type: ' .. (data.type or 'Unknown'),
            'Description: ' .. (data.description or 'No description'),
            'Time: ' .. os.date('%m/%d/%y %H:%M:%S'),
            'Priority: ' .. (data.priority or DetectPriority(data))
        },
        timestamp = os.time()
    }
    
    -- Broadcast(payload) -- Commented out to prevent auto-opening
end)

-- Listen for lb-tablet general events (catch-all)
RegisterNetEvent('lb-tablet:event', function(data)
    print('^3[FRP_MDTUI]^7 Received lb-tablet general event:', json.encode(data))
    
    local payload = {
        address = data.location or data.address or data.coords or 'Unknown Location',
        area = data.area or data.zone or 'Unknown Area',
        county = data.county or 'Los Santos',
        agency = 'LSPD',
        priority = data.priority or DetectPriority(data),
        unit = data.unit or 'General Alert',
        status = 'New',
        details = {
            '------ GENERAL ALERT ------',
            'Event: ' .. (data.event or 'Unknown'),
            'Type: ' .. (data.type or 'Unknown'),
            'Description: ' .. (data.description or 'No description'),
            'Time: ' .. os.date('%m/%d/%y %H:%M:%S'),
            'Priority: ' .. (data.priority or DetectPriority(data))
        },
        timestamp = os.time()
    }
    
    -- Add any additional data fields
    for key, value in pairs(data) do
        if key ~= 'location' and key ~= 'address' and key ~= 'coords' and 
           key ~= 'area' and key ~= 'zone' and key ~= 'county' and 
           key ~= 'priority' and key ~= 'unit' and key ~= 'event' and 
           key ~= 'type' and key ~= 'description' and key ~= 'timestamp' then
            table.insert(payload.details, key .. ': ' .. tostring(value))
        end
    end
    
    -- Broadcast(payload) -- Commented out to prevent auto-opening
end)

-- ========================================
-- MANUAL TRIGGER COMMANDS FOR TESTING
-- ========================================

-- Command to manually trigger a test lb-tablet dispatch
RegisterCommand('test_lb_dispatch', function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not Config.PoliceJobs[Player.PlayerData.job.name] then
        TriggerClientEvent('QBCore:Notify', src, 'You must be police to use this command', 'error')
        return
    end
    
    -- Simulate a lb-tablet dispatch event
    local testData = {
        location = args[1] or '123 Test Street',
        area = args[2] or 'Test Area',
        type = args[3] or 'Test Call',
        description = args[4] or 'This is a test dispatch from lb-tablet',
        priority = args[5] or 'Code 2',
        caller = 'Test Caller',
        phone = '555-0123'
    }
    
    -- Trigger the event handler
    TriggerEvent('lb-tablet:dispatch', testData)
    
    TriggerClientEvent('QBCore:Notify', src, 'Test lb-tablet dispatch sent!', 'success')
end, false)

-- Command to manually trigger a test lb-tablet panic
RegisterCommand('test_lb_panic', function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not Config.PoliceJobs[Player.PlayerData.job.name] then
        TriggerClientEvent('QBCore:Notify', src, 'You must be police to use this command', 'error')
        return
    end
    
    -- Simulate a lb-tablet panic event
    local testData = {
        location = args[1] or '123 Test Street',
        area = args[2] or 'Test Area',
        officer = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        reason = args[3] or 'Test panic button',
        priority = 'Code 3'
    }
    
    -- Trigger the event handler
    TriggerEvent('lb-tablet:panic', testData)
    
    TriggerClientEvent('QBCore:Notify', src, 'Test lb-tablet panic sent!', 'success')
end, false)

-- Command to manually broadcast a dispatch (for testing)
RegisterCommand('broadcast_dispatch', function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not Config.PoliceJobs[Player.PlayerData.job.name] then
        TriggerClientEvent('QBCore:Notify', src, 'You must be police to use this command', 'error')
        return
    end
    
    local testPayload = {
        address = args[1] or '123 Test Street',
        area = args[2] or 'Test Area',
        county = 'Los Santos',
        agency = 'LSPD',
        priority = args[3] or 'Code 2',
        unit = Player.PlayerData.job.grade.name .. '-' .. Player.PlayerData.charinfo.firstname .. '-' .. Player.PlayerData.job.grade.level,
        status = 'Available',
        details = {
            '------ MANUAL TEST DISPATCH ------',
            'This is a manual test dispatch',
            'Time: ' .. os.date('%m/%d/%y %H:%M:%S'),
            'Priority: ' .. (args[3] or 'Code 2')
        },
        timestamp = os.time()
    }
    
    -- Manually broadcast to all police
    local cops = GetOnlineCops()
    for _, id in pairs(cops) do
        TriggerClientEvent('FRP_MDTUI:show', id, testPayload)
    end
    
    TriggerClientEvent('QBCore:Notify', src, 'Manual dispatch broadcast sent to all police!', 'success')
end, false)

-- Command to create a test dispatch using lb-tablet integration
RegisterCommand('test_dispatch', function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not Config.PoliceJobs[Player.PlayerData.job.name] then
        TriggerClientEvent('QBCore:Notify', src, 'You must be police to use this command', 'error')
        return
    end
    
    -- Create test dispatch data
    local testData = {
        location = args[1] or '123 Test Street',
        area = args[2] or 'Test Area',
        type = args[3] or 'Test Incident',
        description = args[4] or 'This is a test dispatch created via command',
        priority = args[5] or 'medium',
        caller = 'Test Caller',
        phone = '555-0123',
        code = '10-54',
        title = 'Test Incident'
    }
    
    -- Trigger the dispatch event
    TriggerEvent('lb-tablet:dispatch', testData)
    
    TriggerClientEvent('QBCore:Notify', src, 'Test dispatch created! Check your computer.', 'success')
end, false)

-- Test command for vehicle info
RegisterCommand('test_vehicle_info', function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not Config.PoliceJobs[Player.PlayerData.job.name] then
        TriggerClientEvent('QBCore:Notify', src, 'You must be police to use this command', 'error')
        return
    end
    
    local testPlate = args[1] or 'TEST123'
    print('^3[FRP_MDTUI]^7 Testing vehicle info for plate:', testPlate)
    
    -- Trigger the vehicle info event directly
    TriggerEvent('FRP_MDTUI:getVehicleInfo', testPlate)
    
    TriggerClientEvent('QBCore:Notify', src, 'Test vehicle info request sent for plate: ' .. testPlate, 'success')
end, false)

-- Test command for vehicle info audio
RegisterCommand('test_vehicle_audio', function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player or not Config.PoliceJobs[Player.PlayerData.job.name] then
        TriggerClientEvent('QBCore:Notify', src, 'You must be police to use this command', 'error')
        return
    end
    
    local callsign = args[1] or '167'
    local plate = args[2] or 'ABC123'
    local stolen = args[3] == 'true' or args[3] == 'stolen'
    
    print('^3[FRP_MDTUI]^7 Testing vehicle info audio - Callsign:', callsign, 'Plate:', plate, 'Stolen:', stolen)
    
    -- Trigger the vehicle info audio event directly
    TriggerClientEvent('FRP_MDTUI:playVehicleInfoAudio', src, callsign, plate, stolen)
    
    TriggerClientEvent('QBCore:Notify', src, 'Test vehicle info audio sent for plate: ' .. plate, 'success')
end, false)
