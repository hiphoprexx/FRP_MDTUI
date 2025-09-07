-- Professional Police Scanner Audio Configuration
-- This file maps real police scanner audio files to dispatch scenarios

-- Wait for main config to be defined
if not Config then
    Config = {}
end

Config.Audio = {
    -- Enable/disable professional audio system
    EnableProfessionalAudio = true,
    
    -- Audio file paths (relative to the resource)
    AudioPath = 'Police Scanner/',
    
    -- Dispatch Priority Audio
    PriorityAudio = {
        -- Code 3 (Emergency) - Multiple urgent sounds
        ['priority_3'] = {
            'ATTENTION_ALL_UNITS/ATTENTION_ALL_UNITS_01.wav',
            'ATTENTION_ALL_UNITS/ATTENTION_ALL_UNITS_02.wav',
            'ATTENTION_ALL_UNITS/ATTENTION_ALL_UNITS_03.wav'
        },
        
        -- Code 2 (Medium Priority) - Standard dispatch
        ['priority_2'] = {
            'WE_HAVE/WE_HAVE_01.wav',
            'WE_HAVE/WE_HAVE_02.wav'
        },
        
        -- Code 1 (Routine) - Subtle notification
        ['priority_1'] = {
            'WE_HAVE/CITIZENS_REPORT_01.wav',
            'WE_HAVE/CITIZENS_REPORT_02.wav'
        }
    },
    
    -- Specific Crime Audio
    CrimeAudio = {
        ['shots_fired'] = {
            'CRIMES/CRIME_SHOTS_FIRED_01.wav',
            'CRIMES/CRIME_GUNFIRE_01.wav',
            'CRIMES/CRIME_GUNFIRE_02.wav'
        },
        
        ['officer_assistance'] = {
            'CRIMES/CRIME_OFFICER_IN_NEED_OF_ASSISTANCE_01.wav',
            'CRIMES/CRIME_OFFICER_IN_NEED_OF_ASSISTANCE_02.wav',
            'CRIMES/CRIME_OFFICER_IN_NEED_OF_ASSISTANCE_03.wav'
        },
        
        ['grand_theft_auto'] = {
            'CRIMES/CRIME_GRAND_THEFT_AUTO_01.wav',
            'CRIMES/CRIME_GRAND_THEFT_AUTO_02.wav',
            'CRIMES/CRIME_GRAND_THEFT_AUTO_03.wav'
        },
        
        ['resist_arrest'] = {
            'CRIMES/CRIME_RESIST_ARREST_01.wav',
            'CRIMES/CRIME_RESIST_ARREST_02.wav',
            'CRIMES/CRIME_RESIST_ARREST_03.wav'
        },
        
        ['air_support'] = {
            'CRIMES/CRIME_OFFICER_REQUESTS_AIR_SUPPORT_01.wav',
            'CRIMES/CRIME_OFFICER_REQUESTS_AIR_SUPPORT_02.wav'
        },
        
        ['code_99'] = {
            'CRIMES/CRIME_10_99_DAVID_01.wav'
        },
        
        ['ambulance_requested'] = {
            'CRIMES/CRIME_AMBULANCE_REQUESTED_01.wav',
            'CRIMES/CRIME_AMBULANCE_REQUESTED_02.wav',
            'CRIMES/CRIME_AMBULANCE_REQUESTED_03.wav'
        }
    },
    
    -- Unit Response Audio
    UnitResponseAudio = {
        ['code_3'] = {
            'UNITS_RESPOND/UNITS_RESPOND_CODE_03_01.wav',
            'UNITS_RESPOND/UNITS_RESPOND_CODE_03_02.wav'
        },
        
        ['code_2'] = {
            'UNITS_RESPOND/UNITS_RESPOND_CODE_02_01.wav',
            'UNITS_RESPOND/UNITS_RESPOND_CODE_02_02.wav'
        },
        
        ['code_99'] = {
            'UNITS_RESPOND/UNITS_RESPOND_CODE_99_01.wav',
            'UNITS_RESPOND/UNITS_RESPOND_CODE_99_02.wav',
            'UNITS_RESPOND/UNITS_RESPOND_CODE_99_03.wav'
        }
    },
    
    -- Area Audio (for location announcements)
    AreaAudio = {
        ['downtown'] = {
            'AREAS/AREA_DOWNTOWN_01.wav',
            'AREAS/AREA_DOWNTOWN_02.wav'
        },
        
        ['vinewood'] = {
            'AREAS/AREA_VINEWOOD_01.wav',
            'AREAS/AREA_EAST_VINEWOOD_01.wav'
        },
        
        ['sandy_shores'] = {
            'AREAS/AREA_SANDY_SHORES_01.wav',
            'AREAS/AREA_SANDY_SHORES_02.wav'
        },
        
        ['paleto_bay'] = {
            'AREAS/AREA_PALETO_BAY_01.wav',
            'AREAS/AREA_PALETO_COVE_01.wav'
        },
        
        ['grapeseed'] = {
            'AREAS/AREA_GRAPESEED_01.wav'
        },
        
        ['chiliad'] = {
            'AREAS/AREA_CHILLIAD_MOUNTAIN_STATE_WILDERNESS_01.wav',
            'AREAS/AREA_MOUNT_CHILLIAD_01.wav'
        }
    },
    
    -- SWAT and Special Units
    SpecialUnitsAudio = {
        ['swat'] = {
            'ATTENTION_ALL_UNITS/ATTENTION_ALL_SWAT_UNITS_01.wav',
            'ATTENTION_ALL_UNITS/ATTENTION_ALL_SWAT_UNITS_02.wav',
            'ATTENTION_ALL_UNITS/DISPATCH_SWAT_UNITS_FROM_01.wav'
        }
    },
    
    -- Vehicle Descriptions
    VehicleAudio = {
        ['police_car'] = {
            'PeterUCallouts Audio/VEHCAT_POLICECAR.wav',
            'PeterUCallouts Audio/VEHCAT_POLICESEDAN.wav'
        },
        
        ['police_motorcycle'] = {
            'PeterUCallouts Audio/VEHCAT_POLICEMOTORCYCLE.wav'
        },
        
        ['police_truck'] = {
            'PeterUCallouts Audio/MODEL_POLICET.wav'
        }
    },
    
    -- Suspect Descriptions
    SuspectAudio = {
        ['general'] = {
            'SUSPECT/SUSPECT_01.wav',
            'SUSPECT/SUSPECT_02.wav'
        }
    },
    
    -- Street Names
    StreetAudio = {
        ['general'] = {
            'STREETS/STREET_01.wav',
            'STREETS/STREET_02.wav'
        }
    },
    
    -- Direction Audio
    DirectionAudio = {
        ['north'] = {
            'DIRECTION/DIRECTION_NORTH_01.wav'
        },
        
        ['south'] = {
            'DIRECTION/DIRECTION_SOUTH_01.wav'
        },
        
        ['east'] = {
            'DIRECTION/DIRECTION_EAST_01.wav'
        },
        
        ['west'] = {
            'DIRECTION/DIRECTION_WEST_01.wav'
        }
    },
    
    -- Conjunctions and Connectors
    ConjunctionAudio = {
        ['and'] = {
            'CONJUNCTIVES/CONJUNCTIVE_AND_01.wav'
        },
        
        ['at'] = {
            'CONJUNCTIVES/CONJUNCTIVE_AT_01.wav'
        },
        
        ['in'] = {
            'CONJUNCTIVES/CONJUNCTIVE_IN_01.wav'
        }
    },
    
    -- Assistance Required
    AssistanceAudio = {
        ['general'] = {
            'ASSISTANCE_REQUIRED/ASSISTANCE_REQUIRED_01.wav',
            'ASSISTANCE_REQUIRED/ASSISTANCE_REQUIRED_02.wav'
        }
    },
    
    -- Report Response
    ReportResponseAudio = {
        ['citizens_report'] = {
            'REPORT_RESPONSE/CITIZENS_REPORT_01.wav',
            'REPORT_RESPONSE/CITIZENS_REPORT_02.wav'
        },
        
        ['officers_report'] = {
            'REPORT_RESPONSE/OFFICERS_REPORT_01.wav',
            'REPORT_RESPONSE/OFFICERS_REPORT_02.wav'
        }
    }
}

-- Audio Volume Settings
Config.AudioVolume = {
    ['priority_3'] = 1.0,    -- Full volume for emergencies
    ['priority_2'] = 0.8,    -- 80% volume for medium priority
    ['priority_1'] = 0.6,    -- 60% volume for routine calls
    ['background'] = 0.5,    -- 50% volume for background audio
    ['ambient'] = 0.4        -- 40% volume for ambient sounds
}

-- Audio Delay Settings (in milliseconds)
Config.AudioDelays = {
    ['priority_3'] = 200,    -- 200ms between urgent sounds
    ['priority_2'] = 300,    -- 300ms between medium sounds
    ['priority_1'] = 500,    -- 500ms between routine sounds
    ['area_announcement'] = 1000,  -- 1 second before area announcement
    ['crime_description'] = 800,   -- 800ms before crime description
    ['unit_response'] = 1200       -- 1.2 seconds before unit response
}
