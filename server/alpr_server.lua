-- ALPR System Server Script
local ALPR_DATABASE = {
    -- Mock vehicle database
    ['ABC123'] = {
        plate = 'ABC123',
        model = 'Adder',
        owner = 'John Doe',
        status = 'REGISTERED',
        registration = 'Valid',
        insurance = 'Valid',
        isStolen = false,
        searchedBy = 'ALPR System',
        timestamp = os.time()
    },
    ['XYZ789'] = {
        plate = 'XYZ789',
        model = 'Zentorno',
        owner = 'Jane Smith',
        status = 'REGISTERED',
        registration = 'Valid',
        insurance = 'Valid',
        isStolen = false,
        searchedBy = 'ALPR System',
        timestamp = os.time()
    },
    ['STL001'] = {
        plate = 'STL001',
        model = 'Banshee',
        owner = 'Unknown',
        status = 'STOLEN/UNREGISTERED',
        registration = 'Invalid',
        insurance = 'Invalid',
        isStolen = true,
        searchedBy = 'ALPR System',
        timestamp = os.time()
    }
}

-- BOLO plates list
local BOLO_PLATES = {
    'STL001',
    'WANTED1',
    'FUGITIVE'
}

-- Get vehicle information
function getVehicleInfo(plate)
    local vehicleInfo = ALPR_DATABASE[plate]
    
    if not vehicleInfo then
        -- Return default info for unknown plates
        vehicleInfo = {
            plate = plate,
            model = 'Unknown Model',
            owner = 'Unknown',
            status = 'UNREGISTERED',
            registration = 'Unknown',
            insurance = 'Unknown',
            isStolen = true,
            searchedBy = 'ALPR System',
            timestamp = os.time()
        }
    end
    
    -- Check if plate is on BOLO list
    for _, boloPlate in ipairs(BOLO_PLATES) do
        if plate == boloPlate then
            vehicleInfo.isStolen = true
            vehicleInfo.status = 'STOLEN/UNREGISTERED'
            vehicleInfo.registration = 'Invalid'
            vehicleInfo.insurance = 'Invalid'
            break
        end
    end
    
    return vehicleInfo
end

-- Check if plate is on BOLO list
function isBOLOPlate(plate)
    for _, boloPlate in ipairs(BOLO_PLATES) do
        if plate == boloPlate then
            return true
        end
    end
    return false
end

-- Add plate to BOLO list
function addBOLOPlate(plate)
    table.insert(BOLO_PLATES, plate)
    print('[ALPR Server] Added plate to BOLO list:', plate)
end

-- Remove plate from BOLO list
function removeBOLOPlate(plate)
    for i, boloPlate in ipairs(BOLO_PLATES) do
        if plate == boloPlate then
            table.remove(BOLO_PLATES, i)
            print('[ALPR Server] Removed plate from BOLO list:', plate)
            break
        end
    end
end

-- Events
RegisterNetEvent('alpr:getVehicleInfo')
AddEventHandler('alpr:getVehicleInfo', function(plate)
    local src = source
    local vehicleInfo = getVehicleInfo(plate)
    
    TriggerClientEvent('alpr:receiveVehicleInfo', src, vehicleInfo)
end)

RegisterNetEvent('alpr:addBOLOPlate')
AddEventHandler('alpr:addBOLOPlate', function(plate)
    local src = source
    -- Add permission check here if needed
    addBOLOPlate(plate)
    
    TriggerClientEvent('alpr:notify', src, 'Plate added to BOLO list: ' .. plate)
end)

RegisterNetEvent('alpr:removeBOLOPlate')
AddEventHandler('alpr:removeBOLOPlate', function(plate)
    local src = source
    -- Add permission check here if needed
    removeBOLOPlate(plate)
    
    TriggerClientEvent('alpr:notify', src, 'Plate removed from BOLO list: ' .. plate)
end)

-- Commands
RegisterCommand('addbolo', function(source, args, rawCommand)
    if #args < 1 then
        TriggerClientEvent('alpr:notify', source, 'Usage: /addbolo <plate>')
        return
    end
    
    local plate = args[1]:upper()
    addBOLOPlate(plate)
    TriggerClientEvent('alpr:notify', source, 'Added ' .. plate .. ' to BOLO list')
end, false)

RegisterCommand('removebolo', function(source, args, rawCommand)
    if #args < 1 then
        TriggerClientEvent('alpr:notify', source, 'Usage: /removebolo <plate>')
        return
    end
    
    local plate = args[1]:upper()
    removeBOLOPlate(plate)
    TriggerClientEvent('alpr:notify', source, 'Removed ' .. plate .. ' from BOLO list')
end, false)

RegisterCommand('listbolo', function(source, args, rawCommand)
    local boloList = table.concat(BOLO_PLATES, ', ')
    TriggerClientEvent('alpr:notify', source, 'BOLO Plates: ' .. boloList)
end, false)

-- Export functions
exports('getVehicleInfo', getVehicleInfo)
exports('isBOLOPlate', isBOLOPlate)
exports('addBOLOPlate', addBOLOPlate)
exports('removeBOLOPlate', removeBOLOPlate)
