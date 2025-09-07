Config = {
  OpenCommand = 'computer',
  WhitelistJobs = { 
    police=true, 
    sheriff=true, 
    state=true, 
    ambulance=true, 
    ems=true,
    -- Add variations your server might use
    ['[LSPD]']=true,
    ['LSPD']=true,
    ['[BCSO]']=true,
    ['BCSO']=true,
    ['[SASP]']=true,
    ['SASP']=true,
    ['[LSFD]']=true,
    ['LSFD']=true,
    ['firefighter']=true,
    ['corrections']=true
  },
  PoliceJobs = { 
    police=true, 
    sheriff=true, 
    state=true,
    ['[LSPD]']=true,
    ['LSPD']=true,
    ['[BCSO]']=true,
    ['BCSO']=true,
    ['[SASP]']=true,
    ['SASP']=true,
    ['corrections']=true
  },
  EMSJobs = { 
    ambulance=true, 
    ems=true,
    ['[LSFD]']=true,
    ['LSFD']=true,
    ['firefighter']=true
  },
  Kvp = 'frp_mdtui_rect',
  DefaultAgency = 'LSPD',
  DefaultUnit = '6-PAUL-11',
  DefaultStatus = 'Out Of Service',
  ToggleKey = 'F7', -- default key to toggle MDT (can be changed in GTA settings)
  Sources = {
    LBTablet = 'lb-tablet',
    WasabiPolice = 'wasabi_police',
    EMS = { 'fusion-ems', 'wasabi_ambulance' }
  },
  -- Allowed patrol vehicle models (lowercase model names)
  AllowedVehicles = {
    'onx_polalamo','onx_polaleu','onx_polbison','onx_polbison2','onx_polbison3','onx_polbison4',
    'onx_polbuff','onx_polbuffhf','onx_polcara','onx_polcava','onx_polcon','onx_poldom','onx_poldorado','onx_poldorado2',
    'onx_polgaunt','onx_polgrang','onx_polgrang2','onx_polinvict','onx_polinvict2','onx_polkandra','onx_polmerit','onx_polmerit3',
    'onx_polmonar','onx_polregent','onx_polregentxl','onx_polsand','onx_polsandh','onx_polsandsc','onx_polsandxl','onx_polscout',
    'onx_polscout2','onx_polsem','onx_polstalk','onx_poltavros','onx_polterm','onx_polterm2','onx_poltulip','onx_polverus',
    'onx_polvigero','onx_polvstr',
    'police'
  },
  
  -- Audio Settings
  EnableDispatchSounds = true, -- Enable/disable dispatch audio
  DispatchVolume = 0.8, -- Volume for dispatch sounds (0.0 to 1.0)

  -- Professional Audio System
  EnableProfessionalAudio = true, -- Enable/disable professional police scanner audio
  ProfessionalAudioVolume = 0.9 -- Volume for professional audio (0.0 to 1.0)
}

-- Priority colors
Config.PriorityColors = {
  ['Code 1'] = '#00ff00', -- Green
  ['Code 2'] = '#ffff00', -- Yellow
  ['Code 3'] = '#ff0000', -- Red
  ['Code 4'] = '#0000ff', -- Blue
  ['High'] = '#ff0000',
  ['Medium'] = '#ffff00',
  ['Low'] = '#00ff00'
}

-- Default position and size
Config.DefaultRect = { x = 100, y = 100, width = 800, height = 580 }
