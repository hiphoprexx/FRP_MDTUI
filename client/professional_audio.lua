-- FRP_MDTUI Professional Audio System
-- Simple, working audio playback using HTML5 audio via NUI

local QBCore = exports['qb-core']:GetCoreObject()
local audioQueue = {}
local isPlayingAudio = false
local lastVehicleInfoDispatch = nil
local isBuildingVehicleInfoSequence = false

-- Forward declaration to fix scoping issue
local ProcessAudioQueue

-- Initialize the professional audio system
local function InitializeProfessionalAudio()
    if Config.Audio and Config.Audio.EnableProfessionalAudio then
        print("^3[FRP_MDTUI]^7 Professional audio system loaded successfully!")
        print("^3[FRP_MDTUI]^7 Audio path: web/sounds/")
        print("^2[FRP_MDTUI]^7 Professional audio system ready!")
        print("^3[FRP_MDTUI]^7 Use /testaudio, /testdispatch, or /testareas to test")
    else
        print("^1[FRP_MDTUI]^7 Professional audio system disabled in config!")
    end
end

-- Simple audio playback using HTML5 audio via NUI
local function PlayAudioFile(audioFile, volume, delay)
    if not Config.Audio or not Config.Audio.EnableProfessionalAudio then
        return false
    end
    
    volume = volume or 1.0
    delay = delay or 0
    
    -- Check for duplicate audio files in the queue
    for _, item in ipairs(audioQueue) do
        if item.file == audioFile and item.volume == volume and item.delay == delay then
            print("^3[FRP_MDTUI]^7 Duplicate audio file ignored: " .. audioFile)
            return true
        end
    end
    
    -- Add to queue
    table.insert(audioQueue, {
        file = audioFile,
        volume = volume,
        delay = delay
    })
    
    -- Process queue if not currently playing
    if not isPlayingAudio then
        ProcessAudioQueue()
    end
    
    return true
end

-- Process the audio queue
ProcessAudioQueue = function()
    print("^3[FRP_MDTUI]^7 ProcessAudioQueue called - Queue length: " .. #audioQueue .. ", isPlaying: " .. tostring(isPlayingAudio))
    
    if #audioQueue == 0 or isPlayingAudio then
        print("^3[FRP_MDTUI]^7 ProcessAudioQueue exiting - Queue empty or already playing")
        return
    end
    
    isPlayingAudio = true
    local audioItem = table.remove(audioQueue, 1)
    
    print("^3[FRP_MDTUI]^7 Playing audio: " .. audioItem.file .. " (volume: " .. audioItem.volume .. ", delay: " .. audioItem.delay .. ")")
    print("^3[FRP_MDTUI]^7 Remaining queue items: " .. #audioQueue)
    
    -- Send to NUI for HTML5 audio playback
    SendNUIMessage({
        action = "playAudio",
        file = audioItem.file,
        volume = audioItem.volume,
        delay = audioItem.delay
    })
    
    -- Audio will be processed when audioFinished callback is received
    -- No timeout needed - let the audio finish naturally
end

-- Test command for basic audio functionality
RegisterCommand('testaudio', function()
    print("^2[FRP_MDTUI]^7 TEST AUDIO COMMAND WORKING!")
    print("^3[FRP_MDTUI]^7 If you see this, the script is loaded and commands are working!")
    
    -- Test basic GTA5 sound
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    print("^2[FRP_MDTUI]^7 Played test sound!")
    
    -- Test NUI audio
    SendNUIMessage({
        action = "playAudio",
        file = "test.mp3",
        volume = 0.8,
        delay = 0
    })
    print("^2[FRP_MDTUI]^7 Sent NUI audio command!")
end, false)

-- Test command for priority dispatch sounds
RegisterCommand('testpriority', function()
    print("^3[FRP_MDTUI]^7 Testing Priority Dispatch Sounds...")
    
    -- Test priority sounds from web/sounds
    PlayAudioFile("priority/OFFICER.wav", 0.8, 0)
    Wait(2000)
    PlayAudioFile("priority/PANIC_BUTTON.wav", 0.8, 0)
    Wait(2000)
    PlayAudioFile("priority/ASSIST_REQUIRED.wav", 0.9, 0)
    
    print("^2[FRP_MDTUI]^7 Priority dispatch test complete!")
end, false)

-- Test command for full dispatch sequence
RegisterCommand('testdispatch', function()
    print("^3[FRP_MDTUI]^7 Testing Full Dispatch Sequence...")
    
    -- Full dispatch sequence using web/sounds files
    PlayAudioFile("attention/ATTENTION_ALL_UNITS_01.wav", 0.85, 0)
    Wait(3000)
    PlayAudioFile("incidents/WE_HAVE_01.wav", 0.8, 0)
    Wait(2000)
    PlayAudioFile("areas/AREA_DOWNTOWN_01.wav", 0.7, 0)
    Wait(2000)
    PlayAudioFile("crimes/CRIME_SHOTS_FIRED_01.wav", 0.75, 0)
    Wait(2000)
    PlayAudioFile("units/UNITS_RESPOND_CODE_03_01.wav", 0.8, 0)
    
    print("^2[FRP_MDTUI]^7 Full dispatch test complete!")
end, false)

-- Test command for area sounds
RegisterCommand('testareas', function()
    print("^3[FRP_MDTUI]^7 Testing Area Announcement Sounds...")
    
    PlayAudioFile("areas/AREA_DOWNTOWN_01.wav", 0.7, 0)
    Wait(2000)
    PlayAudioFile("areas/AREA_ROCKFORD_HILLS_01.wav", 0.7, 0)
    Wait(2000)
    PlayAudioFile("areas/AREA_SANDY_SHORES_01.wav", 0.7, 0)
    
    print("^2[FRP_MDTUI]^7 Area sounds test complete!")
end, false)

-- Test command for crime sounds
RegisterCommand('testcrimes', function()
    print("^3[FRP_MDTUI]^7 Testing Crime Description Sounds...")
    
    PlayAudioFile("crimes/CRIME_SHOTS_FIRED_01.wav", 0.75, 0)
    Wait(2000)
    PlayAudioFile("crimes/CRIME_GRAND_THEFT_AUTO_01.wav", 0.75, 0)
    Wait(2000)
    PlayAudioFile("crimes/CRIME_OFFICER_IN_NEED_OF_ASSISTANCE_01.wav", 0.8, 0)
    
    print("^2[FRP_MDTUI]^7 Crime sounds test complete!")
end, false)

-- Test command for NUI audio system
RegisterCommand('testnuiaudio', function()
    print("^3[FRP_MDTUI]^7 Testing NUI Audio System...")
    
    SendNUIMessage({
        action = "testAudio",
        message = "Testing NUI audio system"
    })
    
    print("^2[FRP_MDTUI]^7 NUI audio test sent!")
end, false)

-- NUI callback for when audio finishes playing
RegisterNUICallback('audioFinished', function(data, cb)
    print("^3[FRP_MDTUI]^7 Audio finished callback received")
    isPlayingAudio = false
    ProcessAudioQueue()
    if cb then cb('ok') end
end)

-- Initialize when resource starts
CreateThread(function()
    Wait(1000) -- Wait for everything to load
    InitializeProfessionalAudio()
end)

-- Dispatch Sequence Builder
local function PlayDispatchSequence(sequence)
    if not Config.Audio or not Config.Audio.EnableProfessionalAudio then
        print("^1[FRP_MDTUI]^7 Professional audio disabled, cannot play dispatch sequence")
        return false
    end
    
    if not sequence or not sequence.audioFiles then
        print("^1[FRP_MDTUI]^7 Invalid dispatch sequence provided")
        return false
    end
    
    print("^3[FRP_MDTUI]^7 Starting dispatch sequence: " .. (sequence.name or "Unnamed"))
    
    -- Add all audio files to the queue with their delays (no extra gaps)
    for i, audioItem in ipairs(sequence.audioFiles) do
        local file = audioItem.file
        local volume = audioItem.volume or 0.8
        local delay = audioItem.delay or 0
        
        -- Add delay between files (except for the first one)
        -- Optional global gap between clips (set to 0 for seamless)
        if i > 1 then
            delay = delay + (sequence.delayBetween or 0)
        end
        
        PlayAudioFile(file, volume, delay)
    end
    
    return true
end

-- Realistic Dispatch Sequence Builder
local function BuildRealisticDispatch(crimeType, area, priority)
    local sequence = {
        name = "Realistic Dispatch - " .. (crimeType or "Unknown"),
        audioFiles = {},
        delayBetween = 600
    }
    
    -- 1. Start with dispatch intro
    table.insert(sequence.audioFiles, { file = "INTROOUTRO/DISPATCH_INTRO_01.wav", volume = 0.9, delay = 0 })
    
    -- 2. "We have"
    table.insert(sequence.audioFiles, { file = "WE_HAVE/WE_HAVE_01.wav", volume = 0.8, delay = 0 })
    
    -- 3. Crime type
    local crimeFile = "CRIMES/CRIME_" .. string.upper(crimeType or "UNKNOWN") .. "_01.wav"
    table.insert(sequence.audioFiles, { file = crimeFile, volume = 0.8, delay = 0 })
    
    -- 4. "On"
    table.insert(sequence.audioFiles, { file = "CONJUNCTIVES/ON_01.wav", volume = 0.7, delay = 0 })
    
    -- 5. Area/Location
    local areaFile = "AREAS/AREA_" .. string.upper(area or "UNKNOWN") .. "_01.wav"
    table.insert(sequence.audioFiles, { file = areaFile, volume = 0.7, delay = 0 })
    
    -- 6. Finish with outro
    table.insert(sequence.audioFiles, { file = "INTROOUTRO/OUTRO_01.wav", volume = 0.9, delay = 0 })
    
    return sequence
end

-- Predefined Dispatch Sequences (Legacy - keeping for compatibility)
local DispatchSequences = {
    -- Code 3 - Shots Fired
    shots_fired = {
        name = "Code 3 - Shots Fired",
        audioFiles = {
            { file = "INTROOUTRO/DISPATCH_INTRO_01.wav", volume = 0.9, delay = 0 },
            { file = "WE_HAVE/WE_HAVE_01.wav", volume = 0.8, delay = 0 },
            { file = "CRIMES/CRIME_SHOTS_FIRED_01.wav", volume = 0.8, delay = 0 },
            { file = "CONJUNCTIVES/ON_01.wav", volume = 0.7, delay = 0 },
            { file = "AREAS/AREA_DOWNTOWN_01.wav", volume = 0.7, delay = 0 },
            { file = "INTROOUTRO/OUTRO_01.wav", volume = 0.9, delay = 0 }
        },
        delayBetween = 600
    },
    
    -- Code 2 - Grand Theft Auto
    grand_theft_auto = {
        name = "Code 2 - Grand Theft Auto",
        audioFiles = {
            { file = "INTROOUTRO/DISPATCH_INTRO_01.wav", volume = 0.9, delay = 0 },
            { file = "WE_HAVE/WE_HAVE_01.wav", volume = 0.8, delay = 0 },
            { file = "CRIMES/CRIME_GRAND_THEFT_AUTO_01.wav", volume = 0.8, delay = 0 },
            { file = "CONJUNCTIVES/ON_01.wav", volume = 0.7, delay = 0 },
            { file = "AREAS/AREA_VINEWOOD_01.wav", volume = 0.7, delay = 0 },
            { file = "INTROOUTRO/OUTRO_01.wav", volume = 0.9, delay = 0 }
        },
        delayBetween = 600
    },
    
    -- Code 1 - Officer Assistance
    officer_assistance = {
        name = "Code 1 - Officer Assistance",
        audioFiles = {
            { file = "INTROOUTRO/DISPATCH_INTRO_01.wav", volume = 0.9, delay = 0 },
            { file = "WE_HAVE/WE_HAVE_01.wav", volume = 0.8, delay = 0 },
            { file = "CRIMES/CRIME_OFFICER_IN_NEED_OF_ASSISTANCE_01.wav", volume = 0.8, delay = 0 },
            { file = "CONJUNCTIVES/ON_01.wav", volume = 0.7, delay = 0 },
            { file = "AREAS/AREA_SANDY_SHORES_01.wav", volume = 0.7, delay = 0 },
            { file = "INTROOUTRO/OUTRO_01.wav", volume = 0.9, delay = 0 }
        },
        delayBetween = 500
    },
    
    -- Panic Button
    panic_button = {
        name = "Panic Button - Officer Down",
        audioFiles = {
            { file = "INTROOUTRO/ATTENTION_ALL_UNITS_01.wav", volume = 1.0, delay = 0 },
            { file = "OFFICERDOWN/OFFICER_DOWN_01.wav", volume = 1.0, delay = 0 },
            { file = "AREAS/AREA_DOWNTOWN_02.wav", volume = 0.8, delay = 0 },
            { file = "UNIT_TYPE/ALL_UNITS_RESPOND_01.wav", volume = 1.0, delay = 0 }
        },
        delayBetween = 300
    },
    
    -- Traffic Stop
    traffic_stop = {
        name = "Code 1 - Traffic Stop",
        audioFiles = {
            { file = "INTROOUTRO/ATTENTION_ALL_UNITS_04.wav", volume = 0.7, delay = 0 },
            { file = "WE_HAVE/WE_HAVE_04.wav", volume = 0.6, delay = 0 },
            { file = "AREAS/AREA_ROCKFORD_HILLS_01.wav", volume = 0.6, delay = 0 },
            { file = "CRIMES/CRIME_TRAFFIC_VIOLATION_01.wav", volume = 0.7, delay = 0 }
        },
        delayBetween = 400
    }
}

-- Function to play a specific dispatch sequence
local function PlayDispatchSequenceByName(sequenceName, customData)
    local sequence = DispatchSequences[sequenceName]
    if not sequence then
        print("^1[FRP_MDTUI]^7 Unknown dispatch sequence: " .. tostring(sequenceName))
        return false
    end
    
    -- Create a copy of the sequence to modify if needed
    local sequenceCopy = {
        name = sequence.name,
        audioFiles = {},
        delayBetween = sequence.delayBetween
    }
    
    -- Copy audio files and apply custom data if provided
    for i, audioItem in ipairs(sequence.audioFiles) do
        local newItem = {
            file = audioItem.file,
            volume = audioItem.volume,
            delay = audioItem.delay
        }
        
        -- Apply custom area if provided
        if customData and customData.area and string.find(newItem.file, "AREAS/") then
            newItem.file = "AREAS/AREA_" .. string.upper(customData.area) .. "_01.wav"
        end
        
        -- Apply custom priority if provided
        if customData and customData.priority and string.find(newItem.file, "UNITS_RESPOND_CODE_") then
            local priorityCode = "01"
            if customData.priority == "Code 3" then
                priorityCode = "03"
            elseif customData.priority == "Code 2" then
                priorityCode = "02"
            end
            newItem.file = string.gsub(newItem.file, "CODE_%d+", "CODE_" .. priorityCode)
        end
        
        table.insert(sequenceCopy.audioFiles, newItem)
    end
    
    return PlayDispatchSequence(sequenceCopy)
end

-- Test commands for dispatch sequences
RegisterCommand('testshots', function()
    print("^3[FRP_MDTUI]^7 Testing Shots Fired Dispatch...")
    PlayDispatchSequenceByName('shots_fired')
end, false)

RegisterCommand('testgta', function()
    print("^3[FRP_MDTUI]^7 Testing Grand Theft Auto Dispatch...")
    PlayDispatchSequenceByName('grand_theft_auto')
end, false)

RegisterCommand('testassist', function()
    print("^3[FRP_MDTUI]^7 Testing Officer Assistance Dispatch...")
    PlayDispatchSequenceByName('officer_assistance')
end, false)

RegisterCommand('testpanic', function()
    print("^3[FRP_MDTUI]^7 Testing Panic Button Dispatch...")
    PlayDispatchSequenceByName('panic_button')
end, false)

RegisterCommand('testtraffic', function()
    print("^3[FRP_MDTUI]^7 Testing Traffic Stop Dispatch...")
    PlayDispatchSequenceByName('traffic_stop')
end, false)

-- Test all dispatch sequences
RegisterCommand('testallsequences', function()
    print("^3[FRP_MDTUI]^7 Testing All Dispatch Sequences...")
    
    local sequences = {'shots_fired', 'grand_theft_auto', 'officer_assistance', 'panic_button', 'traffic_stop'}
    
    for i, seqName in ipairs(sequences) do
        CreateThread(function()
            Wait(i * 15000) -- 15 seconds between each sequence
            print("^3[FRP_MDTUI]^7 Playing sequence " .. i .. "/" .. #sequences .. ": " .. seqName)
            PlayDispatchSequenceByName(seqName)
        end)
    end
    
    print("^2[FRP_MDTUI]^7 All dispatch sequences queued! Check console for progress.")
end, false)

-- Custom dispatch command with parameters
RegisterCommand('customdispatch', function(source, args)
    if #args < 2 then
        print("^1[FRP_MDTUI]^7 Usage: /customdispatch <sequence> <area> [priority]")
        print("^3[FRP_MDTUI]^7 Available sequences: shots_fired, grand_theft_auto, officer_assistance, panic_button, traffic_stop")
        print("^3[FRP_MDTUI]^7 Available areas: downtown, vinewood, sandy_shores, rockford_hills, etc.")
        print("^3[FRP_MDTUI]^7 Available priorities: Code 1, Code 2, Code 3")
        return
    end
    
    local sequenceName = args[1]
    local area = args[2]
    local priority = args[3] or "Code 2"
    
    local customData = {
        area = area,
        priority = priority
    }
    
    print("^3[FRP_MDTUI]^7 Playing custom dispatch: " .. sequenceName .. " in " .. area .. " (" .. priority .. ")")
    PlayDispatchSequenceByName(sequenceName, customData)
end, false)

-- Function to play a realistic dispatch with custom parameters
local function PlayRealisticDispatch(crimeType, area, priority)
    if not Config.Audio or not Config.Audio.EnableProfessionalAudio then
        print("^1[FRP_MDTUI]^7 Professional audio disabled, cannot play realistic dispatch")
        return false
    end
    
    local sequence = BuildRealisticDispatch(crimeType, area, priority)
    print("^3[FRP_MDTUI]^7 Playing realistic dispatch: " .. sequence.name)
    return PlayDispatchSequence(sequence)
end

-- Test commands for realistic dispatch
RegisterCommand('testrealistic', function(source, args)
    if #args < 2 then
        print("^1[FRP_MDTUI]^7 Usage: /testrealistic <crime> <area>")
        print("^3[FRP_MDTUI]^7 Example: /testrealistic GRAND_THEFT_AUTO DOWNTOWN")
        print("^3[FRP_MDTUI]^7 Available crimes: SHOTS_FIRED, GRAND_THEFT_AUTO, OFFICER_IN_NEED_OF_ASSISTANCE, etc.")
        print("^3[FRP_MDTUI]^7 Available areas: DOWNTOWN, VINEWOOD, SANDY_SHORES, ROCKFORD_HILLS, etc.")
        return
    end
    
    local crimeType = args[1]
    local area = args[2]
    
    print("^3[FRP_MDTUI]^7 Testing realistic dispatch: " .. crimeType .. " in " .. area)
    PlayRealisticDispatch(crimeType, area, "Code 2")
end, false)

-- Test specific realistic dispatches
RegisterCommand('testtheft', function()
    print("^3[FRP_MDTUI]^7 Testing realistic vehicle theft dispatch...")
    PlayRealisticDispatch("GRAND_THEFT_AUTO", "DOWNTOWN", "Code 2")
end, false)

RegisterCommand('testshots', function()
    print("^3[FRP_MDTUI]^7 Testing realistic shots fired dispatch...")
    PlayRealisticDispatch("SHOTS_FIRED", "VINEWOOD", "Code 3")
end, false)

RegisterCommand('testassist', function()
    print("^3[FRP_MDTUI]^7 Testing realistic officer assistance dispatch...")
    PlayRealisticDispatch("OFFICER_IN_NEED_OF_ASSISTANCE", "SANDY_SHORES", "Code 1")
end, false)

-- Vehicle Info Dispatch Audio Sequence
local function PlayVehicleInfoDispatch(officerCallsign, plateNumber, isStolen)
    if not Config.Audio or not Config.Audio.EnableProfessionalAudio then
        print("^1[FRP_MDTUI]^7 Professional audio disabled, cannot play vehicle info dispatch")
        return false
    end
    
    -- Debounce duplicate requests within 10 seconds
    local currentTime = GetGameTimer()
    local dispatchKey = tostring(plateNumber) .. "_" .. tostring(isStolen)
    
    if lastVehicleInfoDispatch and 
       lastVehicleInfoDispatch.key == dispatchKey and 
       (currentTime - lastVehicleInfoDispatch.time) < 10000 then
        print("^3[FRP_MDTUI]^7 Duplicate vehicle info dispatch request ignored (within 10 seconds)")
        return false
    end
    
    -- Also check if we're currently playing any audio to prevent overlap
    if isPlayingAudio then
        print("^3[FRP_MDTUI]^7 Audio already playing, ignoring new vehicle info dispatch request")
        return false
    end
    
    -- Check if we're already building a vehicle info sequence
    if isBuildingVehicleInfoSequence then
        print("^3[FRP_MDTUI]^7 Already building vehicle info sequence, ignoring duplicate request")
        return false
    end
    
    isBuildingVehicleInfoSequence = true
    
    lastVehicleInfoDispatch = {
        key = dispatchKey,
        time = currentTime
    }
    
    -- Clear any existing audio queue to prevent overlapping sequences
    if #audioQueue > 0 then
        print("^3[FRP_MDTUI]^7 Clearing existing audio queue (" .. #audioQueue .. " items) to prevent overlap")
        audioQueue = {}
        isPlayingAudio = false
    end
    
    -- Reset the audio queue processing state
    isPlayingAudio = false
    
    print("^3[FRP_MDTUI]^7 Playing vehicle info dispatch for plate: " .. plateNumber .. " (Stolen: " .. tostring(isStolen) .. ")")
    print("^3[FRP_MDTUI]^7 Officer callsign: " .. tostring(officerCallsign) .. " (type: " .. type(officerCallsign) .. ")")
    
    -- Build the audio sequence
    local sequence = {
        name = "Vehicle Info Dispatch - " .. plateNumber,
        audioFiles = {},
        delayBetween = 0
    }
    
    -- 1. Intro
    table.insert(sequence.audioFiles, { file = "INTROOUTRO/DISPATCH_INTRO_01.ogg", volume = 0.9, delay = 0 })
    
    -- 2. "Officer"
    table.insert(sequence.audioFiles, { file = "OFFICER.ogg", volume = 0.8, delay = 0 })
    
    -- 3. Officer callsign (read each digit individually)
    local callsignStr = tostring(officerCallsign) or "167"
    print("^3[FRP_MDTUI]^7 Processing callsign string: '" .. callsignStr .. "' (length: " .. #callsignStr .. ")")
    
    for i = 1, #callsignStr do
        local char = callsignStr:sub(i, i)
        local digit = tonumber(char)
        print("^3[FRP_MDTUI]^7 Character " .. i .. ": '" .. char .. "' -> digit: " .. tostring(digit))
        
        if digit and digit >= 0 and digit <= 9 then
            -- Use BEAT files for individual digits (1-24)
            -- Map digits to BEAT files: 0->24, 1->1, 2->2, etc.
            local beatNumber = digit == 0 and 24 or digit
            local beatFile = string.format("BEAT/BEAT_%02d.ogg", beatNumber)
            print("^3[FRP_MDTUI]^7 Adding audio file: " .. beatFile)
            
            -- Add small delay between each digit (200ms) for more natural speech
            local digitDelay = i > 1 and 200 or 0
            table.insert(sequence.audioFiles, { file = beatFile, volume = 0.8, delay = digitDelay })
        else
            print("^1[FRP_MDTUI]^7 Skipping non-digit character: '" .. char .. "'")
        end
    end
    
    -- 4. "Target vehicle license plate" (with pause after callsign)
    table.insert(sequence.audioFiles, { file = "TARGET_VEHICLE_LICENCE_PLATE.ogg", volume = 0.8, delay = 300 })
    
    -- 5. Crime type (stolen vehicle or regular) - with small delay
    if isStolen then
        table.insert(sequence.audioFiles, { file = "CRIMES/CRIME_STOLEN_VEH_01.ogg", volume = 0.8, delay = 200 })
    else
        -- For registered vehicles, we could use a different crime type or skip this
        -- For now, let's use a generic vehicle-related audio
        table.insert(sequence.audioFiles, { file = "CRIMES/CRIME_TRAFFIC_ALERT.ogg", volume = 0.7, delay = 200 })
    end
    
    -- 6. Outro
    table.insert(sequence.audioFiles, { file = "INTROOUTRO/OUTRO_01.ogg", volume = 0.9, delay = 0 })
    
    local result = PlayDispatchSequence(sequence)
    
    -- Reset the building flag after a short delay
    SetTimeout(1000, function()
        isBuildingVehicleInfoSequence = false
    end)
    
    return result
end

-- Test command for vehicle info dispatch
RegisterCommand('testvehicleinfo', function(source, args)
    local callsign = args[1] or "167"
    local plate = args[2] or "ABC123"
    local stolen = args[3] == "true" or args[3] == "stolen"
    
    print("^3[FRP_MDTUI]^7 Testing vehicle info dispatch...")
    print("^3[FRP_MDTUI]^7 Callsign: " .. callsign .. " (will read each digit: " .. callsign:gsub(".", "%1 ") .. ")")
    print("^3[FRP_MDTUI]^7 Plate: " .. plate .. ", Stolen: " .. tostring(stolen))
    
    PlayVehicleInfoDispatch(callsign, plate, stolen)
end, false)

-- Export functions for other resources
exports('PlayAudioFile', PlayAudioFile)
exports('PlayDispatchSequence', PlayDispatchSequence)
exports('PlayDispatchSequenceByName', PlayDispatchSequenceByName)
exports('PlayRealisticDispatch', PlayRealisticDispatch)
exports('PlayVehicleInfoDispatch', PlayVehicleInfoDispatch)
