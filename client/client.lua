local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local isUIOpen = false
local isComputerOpen = false
local isNUIFocused = false
local lastPayload = nil
local currentRect = Config.DefaultRect
local resourceStarted = false

-- ALPR System
local alprActive = false
local alprThread = nil
local lastScannedVehicles = {}
local isALPROpen = false
local alprScanCount = 0

-- Resource restart handling
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print('^2[FRP_MDTUI]^7 Resource started - Initializing...')
        resourceStarted = true
        
        -- Reset all states
        isUIOpen = false
        isComputerOpen = false
        isNUIFocused = false
        lastPayload = nil
        currentRect = Config.DefaultRect
        
        -- Close any open UI
        SendNUIMessage({ action = 'close' })
        SetNuiFocus(false, false)
        
        -- Reinitialize after a short delay
        Wait(1000)
        InitializeResource()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print('^1[FRP_MDTUI]^7 Resource stopped - Cleaning up...')
        resourceStarted = false
        
        -- Close UI and reset states
        if isUIOpen then
            CloseMDT()
        end
        
        isUIOpen = false
        isComputerOpen = false
        isNUIFocused = false
        lastPayload = nil
    end
end)

-- Initialize resource function
function InitializeResource()
    if not resourceStarted then return end
    
    print('^2[FRP_MDTUI]^7 Initializing resource...')
    
    -- Get fresh QBCore reference
    QBCore = exports['qb-core']:GetCoreObject()
    
    -- Get initial player data
    PlayerData = QBCore.Functions.GetPlayerData()
    
    -- Wait for player data to be available
    local attempts = 0
    while (not PlayerData or not PlayerData.job) and attempts < 50 do
        Wait(100)
        PlayerData = QBCore.Functions.GetPlayerData()
        attempts = attempts + 1
    end
    
    if PlayerData and PlayerData.job then
        print('^2[FRP_MDTUI]^7 Player data loaded successfully!')
        print('^2[FRP_MDTUI]^7 Job: ' .. tostring(PlayerData.job.name))
        print('^2[FRP_MDTUI]^7 Grade: ' .. tostring(PlayerData.job.grade.name))
        
        -- Load saved position after data is ready
        LoadSavedPosition()
    else
        print('^3[FRP_MDTUI]^7 Warning: Could not load player data after restart')
    end
end

-- Wait for QBCore to be fully loaded (initial load)
CreateThread(function()
    while not QBCore do
        Wait(100)
    end
    
    print('^2[FRP_MDTUI]^7 QBCore loaded successfully')
    InitializeResource()
end)

-- Initialize player data
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    LoadSavedPosition()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
    print('^2[FRP_MDTUI]^7 Job updated - New job: ' .. tostring(JobInfo.name))
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    print('^1[FRP_MDTUI]^7 Player unloaded')
end)

-- Load saved position from KVP
function LoadSavedPosition()
    local saved = GetResourceKvpString(Config.Kvp)
    if saved then
        local success, data = pcall(json.decode, saved)
        if success and data then
            currentRect = data
        end
    end
end

-- Save position to KVP
function SavePosition()
    SetResourceKvp(Config.Kvp, json.encode(currentRect))
end

-- Check if player has access to MDT
function HasAccess()
    if not PlayerData or not PlayerData.job then 
        print('^1[FRP_MDTUI]^7 HasAccess: PlayerData.job is nil - waiting for data...')
        return false
    end
    
    local jobName = PlayerData.job.name
    local hasAccess = Config.WhitelistJobs[jobName] == true
    
    print('^2[FRP_MDTUI]^7 HasAccess check:')
    print('  Job name: ' .. tostring(jobName))
    print('  In whitelist: ' .. tostring(hasAccess))
    
    return hasAccess
end

-- Check if player is police
function IsPolice()
    if not PlayerData.job then return false end
    return Config.PoliceJobs[PlayerData.job.name] == true
end

-- Check if player is EMS
function IsEMS()
    if not PlayerData.job then return false end
    return Config.EMSJobs[PlayerData.job.name] == true
end

-- Get player callsign (fallback method for client-side)
function GetPlayerCallsign()
    if not PlayerData or not PlayerData.job then return '000' end
    
    -- Fallback to generating a callsign based on job grade and name
    local gradeLevel = PlayerData.job.grade.level or 0
    local firstName = PlayerData.charinfo and PlayerData.charinfo.firstname or 'UNIT'
    
    -- Generate a 3-digit callsign based on grade level and name hash
    local nameHash = 0
    for i = 1, #firstName do
        nameHash = nameHash + string.byte(firstName, i)
    end
    
    local callsignNumber = (gradeLevel * 100 + (nameHash % 100)) % 1000
    local generatedCallsign = string.format('%03d', callsignNumber)
    
    print('^3[FRP_MDTUI]^7 Generated callsign: ' .. generatedCallsign .. ' (fallback)')
    return generatedCallsign
end

-- Open MDT UI
function OpenMDT(payload)
    print('^3[FRP_MDTUI]^7 OpenMDT called with payload:', payload and 'yes' or 'no')
    
    -- Check if resource is properly initialized
    if not resourceStarted then
        print('^1[FRP_MDTUI]^7 Resource not properly initialized, please wait...')
        QBCore.Functions.Notify('MDT is initializing, please wait...', 'error')
        return
    end
    
    -- Wait for player data if not loaded yet
    if not PlayerData or not PlayerData.job then
        print('^1[FRP_MDTUI]^7 Cannot open MDT - Player data not loaded yet')
        QBCore.Functions.Notify('Please wait for your data to load...', 'error')

        -- Try to get fresh data
        PlayerData = QBCore.Functions.GetPlayerData()
        if not PlayerData or not PlayerData.job then
            return
        end
    end

    if not HasAccess() then
        print('^1[FRP_MDTUI]^7 Access denied - not in whitelist')
        QBCore.Functions.Notify('You do not have access to the MDT', 'error')
        return
    end
    
    print('^2[FRP_MDTUI]^7 Access granted, opening MDT...')

    -- Request callsign from server
    TriggerServerEvent('FRP_MDTUI:getPlayerCallsign')

    -- Update payload if provided, otherwise use last known or create default
    if payload then
        lastPayload = payload
        -- Play dispatch sound for new alerts
        if payload.address and payload.address ~= 'No Active Callout' then
            CreateDispatchNotification(payload)
        end
    elseif not lastPayload then
        -- Create a default "empty" payload for when MDT is opened without 911 call
        lastPayload = {
            address = 'No Active 911 Call',
            area = 'N/A',
            county = 'N/A',
            agency = Config.DefaultAgency,
            priority = 'None',
            unit = PlayerData.job.grade.name .. '-' .. (PlayerData.charinfo and PlayerData.charinfo.firstname or 'UNIT') .. '-' .. PlayerData.job.grade.level,
            status = 'Available',
            details = {
                '------ DISPATCH INTERFACE OPENED ------',
                'No active 911 call at this time.',
                'Use this interface to monitor for new dispatch alerts.',
                'Hold Left-ALT to move and resize the interface.'
            },
            timestamp = GetGameTimer()
        }
    end

    isUIOpen = true
    print('^2[FRP_MDTUI]^7 Setting isUIOpen to true')
    
    -- Do not capture keyboard or mouse by default; UI is passive overlay
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    -- Hide mouse cursor by default (will show when ALT is held)
    print('^2[FRP_MDTUI]^7 Sending NUI message to open UI')
    SendNUIMessage({
        action = 'open',
        payload = lastPayload,
        rect = currentRect,
        hideCursor = true
    })

    -- Inform listeners UI is open
    TriggerServerEvent('FRP_MDTUI:UIOpenState', true)
    print('^2[FRP_MDTUI]^7 MDT should now be open!')
end

-- Close MDT UI
function CloseMDT()
    -- Prevent multiple close calls
    if not isUIOpen then
        print('^3[FRP_MDTUI]^7 Close called but UI is already closed, ignoring')
        return
    end
    
    print('^2[FRP_MDTUI]^7 Closing MDT...')
    
    isUIOpen = false
    isComputerOpen = false
    isNUIFocused = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
    
    -- Clear any stored data
    lastPayload = nil
    
    -- Inform listeners UI is closed
    TriggerEvent('FRP_MDTUI:UIOpenState', false)
    
    print('^2[FRP_MDTUI]^7 MDT closed successfully')
end

-- Close only the main computer UI but keep dispatch info screen open
function CloseMainComputerUI()
    if not isComputerOpen then
        print('^3[FRP_MDTUI]^7 Computer not open, ignoring close request')
        return
    end
    
    print('^2[FRP_MDTUI]^7 Closing main computer UI but keeping dispatch info...')
    
    -- Send message to close only the main computer UI first
    SendNUIMessage({
        action = 'closeMainUI'
    })
    
    -- Wait a frame then remove NUI focus completely
    CreateThread(function()
        Wait(0) -- Wait one frame
        isNUIFocused = false
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        print('^2[FRP_MDTUI]^7 NUI focus completely removed - cursor should disappear')
    end)
    
    print('^2[FRP_MDTUI]^7 Main computer UI closed, dispatch info remains visible but non-interactive')
end

-- Update MDT with new payload
function UpdateMDT(payload)
    if not isUIOpen then return end
    
    lastPayload = payload
    
    -- Play dispatch sound for updates (but not for the same 911 call)
    if payload.address and payload.address ~= 'No Active 911 Call' then
        -- Check if this is a new 911 call or update to existing
        if not lastPayload or lastPayload.address ~= payload.address then
            CreateDispatchNotification(payload)
        else
            -- Same 911 call, just play a subtle update sound
            PlayDispatchSound('unit_response')
        end
    end
    
    SendNUIMessage({
        action = 'update',
        payload = payload
    })
end

-- Function to open computer with cursor visible
function OpenComputerWithCursor()
    if not HasAccess() then
        QBCore.Functions.Notify('You do not have access to the computer', 'error')
        return
    end
    
    if isUIOpen then
        print('^3[FRP_MDTUI]^7 Computer is already open')
        return
    end
    
    isUIOpen = true
    isComputerOpen = true
    isNUIFocused = true
    
    -- Set NUI focus to show cursor
    SetNuiFocus(true, true)
    
    -- Send NUI message to open with cursor
    SendNUIMessage({
        action = 'open',
        payload = lastPayload or {
            callout = {
                id = 'COMPUTER_SYSTEM',
                title = 'Police Computer System',
                description = 'Computer system active - Cursor enabled',
                priority = 'Code 3',
                location = 'Vehicle Computer',
                time = GetClockHours() .. ':' .. string.format('%02d', GetClockMinutes()) .. ':' .. string.format('%02d', GetClockSeconds()),
                status = 'Active'
            }
        }
    })
    
    print('^2[FRP_MDTUI]^7 Computer opened with cursor enabled')
end

-- Commands
RegisterCommand(Config.OpenCommand, function()
    -- Check if main UI is open and has NUI focus (not just dispatch popup)
    if isComputerOpen and isNUIFocused then
        -- Close everything
        print('^2[FRP_MDTUI]^7 Closing computer system...')
        CloseMDT()
        isComputerOpen = false
        isNUIFocused = false
        return
    end
    
    -- If computer is open but no NUI focus (dispatch popup only), reopen main UI
    if isComputerOpen and not isNUIFocused then
        print('^2[FRP_MDTUI]^7 Reopening main computer UI...')
        -- Just reopen the main UI without changing the computer state
        SendNUIMessage({
            action = 'reopenMainUI'
        })
        isNUIFocused = true
        SetNuiFocus(true, true)
        return
    end
    
    -- Require being in driver/passenger seat of allowed police vehicle
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        QBCore.Functions.Notify('You must be in a patrol vehicle to use the computer', 'error')
        return
    end
    -- Only allow for whitelisted models (hash compare)
    local allowed = false
    for _, v in ipairs(Config.AllowedVehicles or {}) do
        if IsVehicleModel(veh, GetHashKey(v)) then
            allowed = true
            break
        end
    end
    if not allowed then
        QBCore.Functions.Notify('This vehicle has no computer', 'error')
        return
    end
    
    -- Open computer with cursor visible
    print('^2[FRP_MDTUI]^7 Opening computer system with cursor...')
    OpenComputerWithCursor()
end, false)

-- Player-configurable keybind (FiveM input mapper)
-- Players can change this in GTA settings: Settings → Key Bindings → FiveM
RegisterKeyMapping('frp_mdtui_toggle', 'Open Police Computer', 'keyboard', Config.ToggleKey)
RegisterCommand('frp_mdtui_toggle', function()
    -- Same restriction as command
    ExecuteCommand(Config.OpenCommand)
end, false)

-- ESC key handler for closing main computer UI
RegisterKeyMapping('frp_mdtui_escape', 'Close Computer UI', 'keyboard', 'ESCAPE')
RegisterCommand('frp_mdtui_escape', function()
    -- Only close if computer is open and we have NUI focus
    if isComputerOpen and isNUIFocused then
        print('^2[FRP_MDTUI]^7 ESC key pressed - closing main computer UI...')
        CloseMainComputerUI()
    end
end, false)

-- Test command to verify resource is working
RegisterCommand('testcomputer', function()
    print('^3[FRP_MDTUI]^7 Test command executed!')
    print('^3[FRP_MDTUI]^7 Config exists: ' .. tostring(Config ~= nil))
    if Config then
        print('^3[FRP_MDTUI]^7 Config.ToggleKey: ' .. tostring(Config.ToggleKey))
        print('^3[FRP_MDTUI]^7 Config.OpenCommand: ' .. tostring(Config.OpenCommand))
        print('^3[FRP_MDTUI]^7 currentRect: ' .. tostring(currentRect ~= nil))
        if currentRect then
            print('^3[FRP_MDTUI]^7 currentRect: ' .. json.encode(currentRect))
        end
    end
    print('^3[FRP_MDTUI]^7 PlayerData.job: ' .. tostring(PlayerData.job ~= nil))
    if PlayerData.job then
        print('^3[FRP_MDTUI]^7 Job: ' .. tostring(PlayerData.job.name))
    end
    print('^3[FRP_MDTUI]^7 isUIOpen: ' .. tostring(isUIOpen))
    print('^3[FRP_MDTUI]^7 lastPayload exists: ' .. tostring(lastPayload ~= nil))
end, false)

-- Command to manually open computer with last callout data
RegisterCommand('opencomputer', function()
    if not HasAccess() then
        QBCore.Functions.Notify('You do not have access to the computer', 'error')
        return
    end
    
    if isUIOpen then
        QBCore.Functions.Notify('Computer is already open', 'info')
        return
    end
    
    -- Open with last payload if available, otherwise create default
    if lastPayload then
        print('^3[FRP_MDTUI]^7 Opening computer with last callout data')
        OpenMDT(lastPayload)
    else
        print('^3[FRP_MDTUI]^7 Opening computer with default data')
        OpenMDT()
    end
end, false)

-- Test command
RegisterCommand('mdtuitest', function()
    TriggerServerEvent('FRP_MDTUI:test')
end, false)

-- Debug command to check current job
RegisterCommand('checkjob', function()
    if PlayerData and PlayerData.job then
        print('^2[FRP_MDTUI]^7 Current job: ' .. tostring(PlayerData.job.name))
        print('^2[FRP_MDTUI]^7 Job grade: ' .. tostring(PlayerData.job.grade.name))
        print('^2[FRP_MDTUI]^7 Has access: ' .. tostring(HasAccess()))
    else
        print('^1[FRP_MDTUI]^7 PlayerData.job is nil!')
    end
end, false)

-- Test dispatch sounds command
RegisterCommand('testsounds', function()
    print('^3[FRP_MDTUI]^7 Testing dispatch sounds...')
    print('^3[FRP_MDTUI]^7 Config.EnableDispatchSounds: ' .. tostring(Config.EnableDispatchSounds))
    
    if not Config.EnableDispatchSounds then
        print('^3[FRP_MDTUI]^7 Dispatch sounds are disabled in config')
        return
    end
    
    -- Test Code 3 sound
    print('^3[FRP_MDTUI]^7 Playing Code 3 sound...')
    PlayDispatchSound('priority_3')
    Wait(2000)
    
    -- Test Code 2 sound
    print('^3[FRP_MDTUI]^7 Playing Code 2 sound...')
    PlayDispatchSound('priority_2')
    Wait(2000)
    
    -- Test Code 1 sound
    print('^3[FRP_MDTUI]^7 Playing Code 1 sound...')
    PlayDispatchSound('priority_1')
    Wait(2000)
    
    -- Test radio chatter
    print('^3[FRP_MDTUI]^7 Playing radio chatter...')
    PlayDispatchSound('radio_chatter')
    
    print('^2[FRP_MDTUI]^7 Sound test complete!')
end, false)

-- Simple sound test command (no config dependency)
RegisterCommand('testsimple', function()
    print('^3[FRP_MDTUI]^7 Testing simple sounds...')
    
    -- Test basic sound
    print('^3[FRP_MDTUI]^7 Testing basic sound...')
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    
    -- Test different sound sets
    Wait(1000)
    print('^3[FRP_MDTUI]^7 Testing police radio sound...')
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    
    Wait(1000)
    print('^3[FRP_MDTUI]^7 Testing double sound (Code 3 style)...')
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    Wait(100)
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    
    print('^2[FRP_MDTUI]^7 Simple sound test complete!')
end, false)

-- Test dispatch notification command
RegisterCommand('testdispatch', function()
    print('^3[FRP_MDTUI]^7 Testing dispatch notification...')
    
    -- Test Code 3 dispatch
    local testData = {
        priority = 'Code 3',
        address = '123 Test Street',
        area = 'Downtown'
    }
    
    CreateDispatchNotification(testData)
    
    print('^2[FRP_MDTUI]^7 Dispatch notification test complete!')
end, false)

-- Test all sound types command
RegisterCommand('testall', function()
    print('^3[FRP_MDTUI]^7 Testing all dispatch sound types...')
    
    print('^3[FRP_MDTUI]^7 1. Testing Code 3 (urgent)...')
    PlayDispatchSound('priority_3')
    Wait(3000)
    
    print('^3[FRP_MDTUI]^7 2. Testing Code 2 (medium)...')
    PlayDispatchSound('priority_2')
    Wait(3000)
    
    print('^3[FRP_MDTUI]^7 3. Testing Code 1 (routine)...')
    PlayDispatchSound('priority_1')
    Wait(3000)
    
    print('^3[FRP_MDTUI]^7 4. Testing radio chatter...')
    PlayDispatchSound('radio_chatter')
    Wait(2000)
    
    print('^3[FRP_MDTUI]^7 5. Testing unit response...')
    PlayDispatchSound('unit_response')
    
    print('^2[FRP_MDTUI]^7 All sound types test complete!')
end, false)

-- Test callsign command
RegisterCommand('testcallsign', function()
    local callsign = GetPlayerCallsign()
    print('^2[FRP_MDTUI]^7 Current callsign: ' .. callsign)
    QBCore.Functions.Notify('Your callsign is: ' .. callsign, 'success')
end, false)

-- Test professional audio system
RegisterCommand('testpro', function()
    print('^3[FRP_MDTUI]^7 Testing professional audio system...')
    
    if Config.EnableProfessionalAudio then
        print('^2[FRP_MDTUI]^7 Professional audio is enabled - testing...')
        
        -- Test different dispatch scenarios
        local testScenarios = {
            {
                name = 'Code 3 - Shots Fired Downtown',
                data = { priority = 'Code 3', area = 'downtown', crimeType = 'shots_fired' }
            },
            {
                name = 'Code 2 - GTA in Vinewood',
                data = { priority = 'Code 2', area = 'vinewood', crimeType = 'grand_theft_auto' }
            },
            {
                name = 'Code 1 - Officer Assistance in Sandy Shores',
                data = { priority = 'Code 1', area = 'sandy_shores', crimeType = 'officer_assistance' }
            }
        }
        
        for i, scenario in ipairs(testScenarios) do
            CreateThread(function()
                Wait(i * 8000) -- 8 seconds between scenarios
                print('^3[FRP_MDTUI]^7 Testing scenario: ' .. scenario.name)
                exports['FRP_MDTUI']:PlayFullDispatch(scenario.data)
            end)
        end
        
        print('^2[FRP_MDTUI]^7 Professional audio test started! Check console for progress.')
    else
        print('^1[FRP_MDTUI]^7 Professional audio is disabled. Enable it in config first.')
    end
end, false)

-- ASE Speed Enforcement Command
RegisterCommand('ase', function()
    if not IsPolice() then
        QBCore.Functions.Notify('You are not authorized to use this system', 'error')
        return
    end
    
    if isASEOpen then
        CloseASEInterface()
    else
        OpenASEInterface()
    end
end, false)

-- Events
RegisterNetEvent('FRP_MDTUI:show', function(payload)
    OpenMDT(payload)
end)

RegisterNetEvent('FRP_MDTUI:update', function(payload)
    UpdateMDT(payload)
end)

RegisterNetEvent('FRP_MDTUI:clear', function()
    CloseMDT()
end)

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    print('^3[FRP_MDTUI]^7 Close callback triggered from NUI')
    
    -- Check if UI is already closed to prevent multiple close calls
    if not isUIOpen then
        print('^3[FRP_MDTUI]^7 UI is already closed, ignoring close callback')
        cb('ok')
        return
    end
    
    CloseMDT()
    cb('ok')
end)

RegisterNUICallback('statusUpdate', function(data, cb)
    -- Handle status updates from toolbar
    if data.status then
        print('^3[FRP_MDTUI]^7 Status updated to: ' .. data.status)
        
        -- Request callsign from server for status update
        TriggerServerEvent('FRP_MDTUI:getPlayerCallsignForStatus', data.status, lastPayload and lastPayload.id)
        
        -- Handle Code 4 (resolved) status
        if data.status == 'Code 4' then
            print('^2[FRP_MDTUI]^7 Incident resolved (Code 4)')
            -- The server will handle closing the dispatch
        end
    end
    cb('ok')
end)

RegisterNUICallback('panic', function(data, cb)
    -- Handle panic button activation
    if data.active then
        print('^1[FRP_MDTUI]^7 PANIC BUTTON ACTIVATED!')
        -- You can add panic logic here (e.g., notify other officers)
    end
    cb('ok')
end)

RegisterNUICallback('alpr', function(data, cb)
    -- Handle ALPR toggle - open ALPR interface
    if data.active then
        print('^3[FRP_MDTUI]^7 Opening ALPR interface')
        OpenALPRInterface()
    else
        print('^3[FRP_MDTUI]^7 ALPR deactivated')
    end
    cb('ok')
end)

RegisterNUICallback('settings', function(data, cb)
    -- Handle settings
    print('^3[FRP_MDTUI]^7 Settings requested')
    cb('ok')
end)

RegisterNUICallback('saveRect', function(data, cb)
    if data.rect then
        currentRect = data.rect
        SavePosition()
    end
    cb('ok')
end)

RegisterNUICallback('getActiveIncidents', function(data, cb)
    -- Request active incidents from server
    TriggerServerEvent('FRP_MDTUI:getActiveDispatches')
    cb('ok')
end)

RegisterNUICallback('attachToIncident', function(data, cb)
    if IsPolice() and data.incidentId then
        print('^3[FRP_MDTUI]^7 Attaching to incident:', data.incidentId)
        TriggerServerEvent('FRP_MDTUI:getPlayerCallsignForStatus', 'En Route', data.incidentId)
    end
    cb('ok')
end)

RegisterNUICallback('closeIncident', function(data, cb)
    if IsPolice() and data.incidentId then
        print('^3[FRP_MDTUI]^7 Closing incident:', data.incidentId)
        TriggerServerEvent('FRP_MDTUI:getPlayerCallsignForStatus', 'Code 4', data.incidentId)
    end
    cb('ok')
end)

RegisterNUICallback('removeFocus', function(data, cb)
    print('^2[FRP_MDTUI]^7 Removing NUI focus while keeping dispatch popup visible...')
    isNUIFocused = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    cb('ok')
end)

-- ALPR System Callbacks
RegisterNUICallback('startALPR', function(data, cb)
    if IsPolice() then
        print('^2[FRP_MDTUI]^7 Starting ALPR system')
        StartALPRSystem()
    end
    cb('ok')
end)

RegisterNUICallback('stopALPR', function(data, cb)
    if IsPolice() then
        print('^1[FRP_MDTUI]^7 Stopping ALPR system')
        StopALPRSystem()
    end
    cb('ok')
end)

RegisterNUICallback('getVehicleInfo', function(data, cb)
    print('^3[FRP_MDTUI]^7 getVehicleInfo NUI callback received with data:', json.encode(data))
    if IsPolice() and data.plate then
        print('^3[FRP_MDTUI]^7 Requesting vehicle info for plate:', data.plate)
        TriggerServerEvent('FRP_MDTUI:getVehicleInfo', data.plate)
        print('^3[FRP_MDTUI]^7 Triggered server event for vehicle info')
    else
        print('^1[FRP_MDTUI]^7 Cannot request vehicle info - not police or no plate data')
    end
    cb('ok')
end)

-- Handle new dispatch from lb-tablet integration
RegisterNetEvent('FRP_MDTUI:newDispatch', function(dispatchData)
    if IsPolice() then
        print('^3[FRP_MDTUI]^7 Received new dispatch:', dispatchData.id)
        
        -- Store the dispatch data
        lastPayload = dispatchData
        
        -- Flash the appropriate priority button
        FlashPriorityButton(dispatchData.priority)
        
        -- Only update if MDT is already open
        if isUIOpen then
            UpdateMDT(dispatchData)
        end
        
        -- Play dispatch notification sound
        CreateDispatchNotification(dispatchData)
    end
end)

-- Handle dispatch status updates
RegisterNetEvent('FRP_MDTUI:dispatchStatusUpdate', function(dispatchId, status, callsign)
    if IsPolice() then
        print('^3[FRP_MDTUI]^7 Dispatch status update:', dispatchId, status, callsign)
        
        -- Update the current payload if it matches
        if lastPayload and lastPayload.id == dispatchId then
            lastPayload.status = status
            lastPayload.respondingUnit = callsign
            
            -- Add status update to details
            table.insert(lastPayload.details, callsign .. ' - ' .. status .. ' at ' .. GetFormattedTime())
            
            -- Update UI if open
            if isUIOpen then
                UpdateMDT(lastPayload)
            end
        end
    end
end)

-- Handle receiving active dispatches
RegisterNetEvent('FRP_MDTUI:receiveActiveDispatches', function(incidents)
    if IsPolice() then
        print('^2[FRP_MDTUI]^7 Received active incidents:', #incidents)
        SendNUIMessage({
            action = 'updateIncidents',
            incidents = incidents
        })
    end
end)

-- Handle receiving callsign from server
RegisterNetEvent('FRP_MDTUI:receiveCallsign', function(callsign, rank)
    if IsPolice() then
        print('^2[FRP_MDTUI]^7 Received callsign from server:', callsign, 'Rank:', rank)
        
        -- Update the UI with the callsign and rank
        SendNUIMessage({
            action = 'updateOfficerInfo',
            callsign = callsign,
            rank = rank
        })
    end
end)

-- Handle vehicle info response
RegisterNetEvent('FRP_MDTUI:receiveVehicleInfo', function(vehicleData)
    print('^3[FRP_MDTUI]^7 receiveVehicleInfo event received with data:', json.encode(vehicleData))
    if IsPolice() then
        print('^2[FRP_MDTUI]^7 Received vehicle info:', json.encode(vehicleData))
        
        -- Send to ALPR system (existing functionality)
        SendNUIMessage({
            action = 'vehicleInfo',
            vehicleData = vehicleData
        })
        
        -- Also display in dispatch info screen
        SendNUIMessage({
            action = 'displayVehicleInfoInDispatch',
            vehicleData = vehicleData
        })
        
        print('^2[FRP_MDTUI]^7 Sent vehicle info to NUI and dispatch screen')
    else
        print('^1[FRP_MDTUI]^7 Player is not police, ignoring vehicle info')
    end
end)

-- Handle vehicle info audio dispatch
local lastAudioDispatch = nil
RegisterNetEvent('FRP_MDTUI:playVehicleInfoAudio', function(callsign, plateNumber, isStolen)
    print('^3[FRP_MDTUI]^7 playVehicleInfoAudio event received - Callsign:', callsign, 'Plate:', plateNumber, 'Stolen:', isStolen)
    
    if not IsPolice() then
        print('^1[FRP_MDTUI]^7 Player is not police, ignoring vehicle info audio')
        return
    end
    
    -- Debounce duplicate audio dispatch requests within 5 seconds
    local currentTime = GetGameTimer()
    local dispatchKey = tostring(plateNumber) .. "_" .. tostring(isStolen)
    
    if lastAudioDispatch and 
       lastAudioDispatch.key == dispatchKey and 
       (currentTime - lastAudioDispatch.time) < 5000 then
        print('^3[FRP_MDTUI]^7 Duplicate audio dispatch request ignored (within 5 seconds)')
        return
    end
    
    lastAudioDispatch = {
        key = dispatchKey,
        time = currentTime
    }
    
    -- Use the professional audio system to play the dispatch
    exports['FRP_MDTUI']:PlayVehicleInfoDispatch(callsign, plateNumber, isStolen)
    print('^2[FRP_MDTUI]^7 Vehicle info audio dispatch triggered')
end)

-- Handle plate detection
RegisterNetEvent('FRP_MDTUI:plateDetected', function(plateData)
    if IsPolice() then
        print('^2[FRP_MDTUI]^7 Plate detected:', plateData.plate)
        SendNUIMessage({
            action = 'plateDetected',
            plateData = plateData
        })
    end
end)

-- Handle BOLO alerts
RegisterNetEvent('FRP_MDTUI:boloAlert', function(plateData)
    if IsPolice() then
        print('^1[FRP_MDTUI]^7 BOLO ALERT for plate:', plateData.plate)
        SendNUIMessage({
            action = 'boloAlert',
            plateData = plateData
        })
        
        -- Play BOLO alert sound (you can add your sound file here)
        -- PlaySoundFrontend(-1, "BOLO_ALERT", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 1)
    end
end)

-- ALPR System Functions
function StartALPRSystem()
    if alprActive then return end
    
    alprActive = true
    lastScannedVehicles = {}
    
    -- Start ALPR scanning thread
    alprThread = CreateThread(function()
        while alprActive do
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            
            if vehicle ~= 0 then
                -- Player is in a vehicle, scan nearby vehicles
                ScanNearbyVehicles(vehicle)
            end
            
            -- Update GPS coordinates
            local coords = GetEntityCoords(PlayerPedId())
            SendNUIMessage({
                action = 'updateGPS',
                coords = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z
                }
            })
            
            Wait(1000) -- Scan every second
        end
    end)
    
    print('^2[FRP_MDTUI]^7 ALPR system started')
end

function StopALPRSystem()
    if not alprActive then return end
    
    alprActive = false
    lastScannedVehicles = {}
    
    if alprThread then
        alprThread = nil
    end
    
    print('^1[FRP_MDTUI]^7 ALPR system stopped')
end

function ScanNearbyVehicles(policeVehicle)
    local policeCoords = GetEntityCoords(policeVehicle)
    local policeHeading = GetEntityHeading(policeVehicle)
    
    -- Get all vehicles in a 50 meter radius
    local vehicles = GetGamePool('CVehicle')
    local nearbyCount = 0
    local scannedCount = 0
    
    for _, vehicle in pairs(vehicles) do
        if vehicle ~= policeVehicle and DoesEntityExist(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            local distance = #(policeCoords - vehicleCoords)
            
            -- Only scan vehicles within 30 meters
            if distance <= 30.0 then
                nearbyCount = nearbyCount + 1
                local plate = GetVehicleNumberPlateText(vehicle)
                local vehicleHash = GetEntityModel(vehicle)
                local vehicleModel = GetDisplayNameFromVehicleModel(vehicleHash)
                
                -- Check if we've already scanned this vehicle recently
                local scanKey = plate .. '_' .. tostring(vehicle)
                if not lastScannedVehicles[scanKey] or (GetGameTimer() - lastScannedVehicles[scanKey]) > 30000 then -- 30 second cooldown
                    
                    -- Determine if vehicle is in front or behind
                    local relativeHeading = GetRelativeHeadingBetweenEntities(policeVehicle, vehicle)
                    local source = 'Front'
                    if relativeHeading > 90 and relativeHeading < 270 then
                        source = 'Rear'
                    end
                    
                    print('^3[FRP_MDTUI]^7 Scanning vehicle:', plate, 'Model:', vehicleModel, 'Distance:', math.floor(distance), 'Source:', source)
                    
                    -- Create plate data for ALPR interface
                    local plateData = {
                        plate = plate,
                        model = vehicleModel,
                        source = source,
                        timestamp = GetGameTimer(),
                        distance = math.floor(distance),
                        coords = vehicleCoords,
                        flags = {}
                    }
                    
                    -- Send to ALPR interface
                    SendNUIMessage({
                        action = 'plateDetected',
                        plateData = plateData
                    })
                    
                    -- Increment scan count
                    alprScanCount = alprScanCount + 1
                    SendNUIMessage({
                        action = 'updateScanCount',
                        count = alprScanCount
                    })
                    
                    -- Send plate data to server for processing
                    TriggerServerEvent('FRP_MDTUI:processPlate', {
                        plate = plate,
                        vehicle = vehicle,
                        model = vehicleModel,
                        source = source,
                        coords = vehicleCoords,
                        timestamp = GetGameTimer()
                    })
                    
                    -- Mark as scanned
                    lastScannedVehicles[scanKey] = GetGameTimer()
                    scannedCount = scannedCount + 1
                end
            end
        end
    end
    
    if nearbyCount > 0 then
        print('^3[FRP_MDTUI]^7 ALPR Scan: Found', nearbyCount, 'nearby vehicles, scanned', scannedCount, 'new plates')
    end
end

function GetRelativeHeadingBetweenEntities(entity1, entity2)
    local coords1 = GetEntityCoords(entity1)
    local coords2 = GetEntityCoords(entity2)
    local heading1 = GetEntityHeading(entity1)
    
    local dx = coords2.x - coords1.x
    local dy = coords2.y - coords1.y
    
    local targetHeading = math.deg(math.atan2(dy, dx))
    local relativeHeading = (targetHeading - heading1) % 360
    
    return relativeHeading
end

-- Toggle MDT event handler
RegisterNetEvent('FRP_MDTUI:toggle', function()
    ToggleMDT()
end)

-- Bridge events for wasabi_police
RegisterNetEvent('wasabi_police:dispatch', function(data)
    if IsPolice() then
        local payload = {
            address = data.location or 'Unknown Location',
            area = data.area or 'Unknown Area',
            county = data.county or 'Los Santos',
            agency = Config.DefaultAgency,
            priority = data.priority or 'Code 2',
            unit = PlayerData.job.grade.name .. '-' .. (PlayerData.charinfo and PlayerData.charinfo.firstname or 'UNIT') .. '-' .. PlayerData.job.grade.level,
            status = 'Available',
            details = {
                '------ INCIDENT OPENED at ' .. GetFormattedTime() .. ' ------',
                data.description or 'No description provided',
                data.advisory or 'No advisory provided'
            },
            timestamp = GetGameTimer()
        }
        -- Store the payload but don't auto-open the MDT
        lastPayload = payload
        -- Only open if MDT is already open, otherwise just store the data
        if isUIOpen then
            UpdateMDT(payload)
        end
    end
end)

-- Bridge events for EMS
RegisterNetEvent('fusion-ems:dispatch', function(data)
    if IsEMS() then
        local payload = {
            address = data.location or 'Unknown Location',
            area = data.area or 'Unknown Area',
            county = data.county or 'Los Santos',
            agency = 'LSFD',
            priority = data.priority or 'Code 2',
            unit = PlayerData.job.grade.name .. '-' .. (PlayerData.charinfo and PlayerData.charinfo.firstname or 'UNIT') .. '-' .. PlayerData.job.grade.level,
            status = 'Available',
            details = {
                '------ INCIDENT OPENED at ' .. GetFormattedTime() .. ' ------',
                data.description or 'No description provided',
                data.advisory or 'No advisory provided'
            },
            timestamp = GetGameTimer()
        }
        -- Store the payload but don't auto-open the MDT
        lastPayload = payload
        -- Only open if MDT is already open, otherwise just store the data
        if isUIOpen then
            UpdateMDT(payload)
        end
    end
end)

RegisterNetEvent('wasabi_ambulance:dispatch', function(data)
    if IsEMS() then
        local payload = {
            address = data.location or 'Unknown Location',
            area = data.area or 'Unknown Area',
            county = data.county or 'Los Santos',
            agency = 'LSFD',
            priority = 'Code 2',
            unit = PlayerData.job.grade.name .. '-' .. (PlayerData.charinfo and PlayerData.charinfo.firstname or 'UNIT') .. '-' .. PlayerData.job.grade.level,
            status = 'Available',
            details = {
                '------ INCIDENT OPENED at ' .. GetFormattedTime() .. ' ------',
                data.description or 'No description provided',
                data.advisory or 'No advisory provided'
            },
            timestamp = GetGameTimer()
        }
        -- Store the payload but don't auto-open the MDT
        lastPayload = payload
        -- Only open if MDT is already open, otherwise just store the data
        if isUIOpen then
            UpdateMDT(payload)
        end
    end
end)

-- Helper function for timestamps
function GetFormattedTime()
    local gameTimer = GetGameTimer()
    local minutes = math.floor(gameTimer / 60000)
    local seconds = math.floor((gameTimer % 60000) / 1000)
    return string.format('%02d:%02d', minutes, seconds)
end

-- Dispatch Audio Functions
function PlayDispatchSound(soundType)
    print('^3[FRP_MDTUI]^7 PlayDispatchSound called with: ' .. tostring(soundType))
    
    if soundType == 'priority_3' then
        -- High priority - urgent double sound
        print('^3[FRP_MDTUI]^7 Playing Code 3 (urgent) sound...')
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        Wait(150)
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        Wait(150)
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    elseif soundType == 'priority_2' then
        -- Medium priority - double sound
        print('^3[FRP_MDTUI]^7 Playing Code 2 (medium) sound...')
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        Wait(200)
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    elseif soundType == 'priority_1' then
        -- Low priority - single sound
        print('^3[FRP_MDTUI]^7 Playing Code 1 (routine) sound...')
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    elseif soundType == 'radio_chatter' then
        -- Radio chatter - different sound
        print('^3[FRP_MDTUI]^7 Playing radio chatter sound...')
        PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    elseif soundType == 'unit_response' then
        -- Unit response - acknowledgment sound
        print('^3[FRP_MDTUI]^7 Playing unit response sound...')
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    elseif soundType == 'dispatch_start' then
        -- Dispatch start
        print('^3[FRP_MDTUI]^7 Playing dispatch start sound...')
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    elseif soundType == 'dispatch_end' then
        -- Dispatch end
        print('^3[FRP_MDTUI]^7 Playing dispatch end sound...')
        PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    else
        print('^1[FRP_MDTUI]^7 Unknown sound type: ' .. tostring(soundType))
    end
end

function CreateDispatchNotification(data)
    print('^3[FRP_MDTUI]^7 CreateDispatchNotification called with data')
    if data then
        print('^3[FRP_MDTUI]^7 Priority: ' .. tostring(data.priority))
        print('^3[FRP_MDTUI]^7 Address: ' .. tostring(data.address))
        print('^3[FRP_MDTUI]^7 Area: ' .. tostring(data.area))
    end
    
    -- Check if dispatch sounds are enabled
    if not Config.EnableDispatchSounds then
        print('^3[FRP_MDTUI]^7 Dispatch sounds are disabled, skipping audio')
        return
    end
    
    -- Create a realistic dispatch notification
    local priority = data.priority or 'Code 1'
    local address = data.address or 'Unknown Location'
    local area = data.area or 'Unknown Area'
    
    print('^3[FRP_MDTUI]^7 Creating notification for: ' .. priority .. ' - ' .. address .. ' in ' .. area)
    
    -- Try to use professional audio system first
    if Config.EnableProfessionalAudio then
        print('^3[FRP_MDTUI]^7 Using professional audio system')
        
        -- Determine crime type from details if available
        local crimeType = nil
        if data.details then
            for _, detail in ipairs(data.details) do
                local detailLower = string.lower(detail)
                if string.find(detailLower, 'shots') or string.find(detailLower, 'gunfire') then
                    crimeType = 'shots_fired'
                    break
                elseif string.find(detailLower, 'theft') or string.find(detailLower, 'stolen') then
                    crimeType = 'grand_theft_auto'
                    break
                elseif string.find(detailLower, 'assistance') or string.find(detailLower, 'help') then
                    crimeType = 'officer_assistance'
                    break
                elseif string.find(detailLower, 'resist') or string.find(detailLower, 'arrest') then
                    crimeType = 'resist_arrest'
                    break
                end
            end
        end
        
        -- Play full professional dispatch
        local dispatchData = {
            priority = priority,
            area = area,
            crimeType = crimeType
        }
        
        -- Use exports to call the professional audio system
        -- Avoid double playback: do not also play GTA sounds here
        exports['FRP_MDTUI']:PlayFullDispatch(dispatchData)
        return
    else
        -- Fallback to basic GTA5 sounds
        print('^3[FRP_MDTUI]^7 Using basic GTA5 sounds')
        
        -- Play appropriate sound based on priority
        if priority == 'Code 3' then
            PlayDispatchSound('priority_3')
        else
            PlayDispatchSound('priority_2')
        end
        
        -- Play radio chatter sound
        Wait(1000)
        PlayDispatchSound('radio_chatter')
    end
    
    -- Show dispatch notification
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(string.format('~b~DISPATCH:~w~ %s - %s in %s', priority, address, area))
    EndTextCommandThefeedPostTicker(false, true)
end

-- Toggle MDT function
function ToggleMDT()
    print('^3[FRP_MDTUI]^7 ToggleMDT called, current state: ' .. tostring(isUIOpen))
    
    if isUIOpen then
        print('^3[FRP_MDTUI]^7 Closing MDT...')
        CloseMDT()
    else
        print('^3[FRP_MDTUI]^7 Opening MDT...')
        -- Check if player is in a police vehicle
        if not IsInPoliceVehicle() then
            QBCore.Functions.Notify('You must be in a police vehicle to use the MDT', 'error')
            return
        end
        
        -- Open with last payload or default
        if lastPayload then
            OpenMDT(lastPayload)
        else
            -- Generate default payload
            local defaultPayload = {
                address = 'No Active 911 Call',
                area = 'N/A',
                county = 'Los Santos',
                agency = Config.DefaultAgency,
                priority = 'Code 1',
                unit = PlayerData.job.grade.name .. '-' .. (PlayerData.charinfo and PlayerData.charinfo.firstname or 'UNIT') .. '-' .. PlayerData.job.grade.level,
                status = 'Available',
                details = {
                    '------ NO ACTIVE 911 CALL ------',
                    'No active 911 call at this time.',
                    'Use the toolbar to update your status.',
                    'Monitor for incoming dispatch alerts.'
                },
                timestamp = GetGameTimer()
            }
            OpenMDT(defaultPayload)
        end
    end
end

-- Check if player is in a police vehicle
function IsInPoliceVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        return false
    end
    
    local vehicle = GetVehiclePedIsIn(ped, false)
    local model = GetEntityModel(vehicle)
    local modelName = GetDisplayNameFromVehicleModel(model):lower()
    
    -- Check against allowed vehicle models
    for _, allowedModel in ipairs(Config.AllowedVehicles) do
        if modelName == allowedModel:lower() then
            return true
        end
    end
    
    return false
end



-- Vehicle exit detection
CreateThread(function()
    local wasInVehicle = false
    
    while true do
        Wait(500) -- Check every 500ms
        
        local ped = PlayerPedId()
        local isInVehicle = IsPedInAnyVehicle(ped, false)
        
        -- If player was in vehicle but now isn't, close MDT
        if wasInVehicle and not isInVehicle and isUIOpen then
            print('^3[FRP_MDTUI]^7 Player exited vehicle, closing MDT')
            CloseMDT()
        end
        
        wasInVehicle = isInVehicle
    end
end)

-- Main thread
CreateThread(function()
    while not QBCore do
        Wait(100)
    end
    
    print('^2[FRP_MDTUI]^7 QBCore loaded, waiting for player data...')
    
    -- Wait for player data to be loaded
    while not PlayerData or not PlayerData.job do
        Wait(100)
    end
    
    print('^2[FRP_MDTUI]^7 Player data loaded successfully!')
    print('^2[FRP_MDTUI]^7 Job: ' .. tostring(PlayerData.job.name))
    print('^2[FRP_MDTUI]^7 Grade: ' .. tostring(PlayerData.job.grade.name))
end)

-- Flash priority button based on incident type
function FlashPriorityButton(priority)
    if not priority then return end
    
    print('^3[FRP_MDTUI]^7 Flashing priority button for:', priority)
    
    -- Send flash command to NUI
    SendNUIMessage({
        action = 'flashPriority',
        priority = priority
    })
end

-- ALPR Interface Functions
function OpenALPRInterface()
    if isALPROpen then return end
    
    isALPROpen = true
    alprScanCount = 0
    
    -- Get unit information
    local unitName = "Unit 1-LINCOLN-18" -- This should be dynamic based on player data
    local coords = GetEntityCoords(PlayerPedId())
    
    -- Send open command to ALPR NUI
    SendNUIMessage({
        action = 'openALPR',
        unitName = unitName,
        gpsCoords = {
            x = coords.x,
            y = coords.y,
            z = coords.z
        }
    })
    
    print('^2[FRP_MDTUI]^7 ALPR interface opened')
end

function CloseALPRInterface()
    if not isALPROpen then return end
    
    isALPROpen = false
    alprActive = false
    
    -- Stop scanning thread
    if alprThread then
        alprThread = nil
    end
    
    -- Send close command to ALPR NUI
    SendNUIMessage({
        action = 'closeALPR'
    })
    
    print('^2[FRP_MDTUI]^7 ALPR interface closed')
end

-- ALPR NUI Callbacks
RegisterNUICallback('alprClosed', function(data, cb)
    CloseALPRInterface()
    cb('ok')
end)

RegisterNUICallback('startALPRScanning', function(data, cb)
    if not alprActive then
        alprActive = true
        StartALPRSystem()
    end
    cb('ok')
end)

RegisterNUICallback('stopALPRScanning', function(data, cb)
    if alprActive then
        alprActive = false
        StopALPRSystem()
    end
    cb('ok')
end)

RegisterNUICallback('getVehicleInfo', function(data, cb)
    if IsPolice() and data.plate then
        print('^3[FRP_MDTUI]^7 Requesting vehicle info for plate:', data.plate)
        TriggerServerEvent('FRP_MDTUI:getVehicleInfo', data.plate)
    end
    cb('ok')
end)

-- ASE (Speed Enforcement) System
local isASEOpen = false
local aseActive = false
local aseLaserMode = false
local patrolSpeed = 0

-- ASE Interface Functions
function OpenASEInterface()
    if isASEOpen then return end
    
    isASEOpen = true
    
    -- Send open command to ASE NUI
    SendNUIMessage({
        action = 'ASE_OPEN'
    })
    
    print('^2[FRP_MDTUI]^7 ASE interface opened')
end

function CloseASEInterface()
    if not isASEOpen then return end
    
    isASEOpen = false
    aseActive = false
    aseLaserMode = false
    
    -- Send close command to ASE NUI
    SendNUIMessage({
        action = 'ASE_CLOSE'
    })
    
    print('^2[FRP_MDTUI]^7 ASE interface closed')
end

-- ASE NUI Callbacks
RegisterNUICallback('aseOpened', function(data, cb)
    -- ASE window opened from MDT interface
    isASEOpen = true
    cb('ok')
end)

RegisterNUICallback('aseClosed', function(data, cb)
    -- ASE window closed from MDT interface
    isASEOpen = false
    aseActive = false
    aseLaserMode = false
    cb('ok')
end)

RegisterNUICallback('asePowerToggle', function(data, cb)
    aseActive = data.active
    if not aseActive then
        aseLaserMode = false
    end
    cb('ok')
end)

RegisterNUICallback('aseLaserToggle', function(data, cb)
    aseLaserMode = data.laserMode
    cb('ok')
end)

RegisterNUICallback('aseSpeedDetected', function(data, cb)
    -- Handle speed detection logic here
    cb('ok')
end)

RegisterNUICallback('aseLaserTarget', function(data, cb)
    -- Handle laser targeting logic here
    cb('ok')
end)

RegisterNUICallback('asePlateDetected', function(data, cb)
    -- Handle plate detection logic here
    cb('ok')
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isUIOpen then
            CloseMDT()
        end
        if isALPROpen then
            CloseALPRInterface()
        end
        if isASEOpen then
            CloseASEInterface()
        end
    end
end)
