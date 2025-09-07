fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'FRP_MDTUI'
author 'FRP Development'
description 'ryan stuff'
version '1.0.0'

ui_page 'web/index.html'

files {
  'web/index.html',
  'web/styles.css',
  'web/app.js',
  'web/audio-player.js',
  'web/alpr.html',
  'web/alpr-styles.css',
  'web/alpr-app.js',
  'web/sounds/**/*.*',
  'web/plates/**/*.png',
  'web/INTERFACE/**/*.png'
}

shared_scripts { 
    'shared/config.lua',
    'shared/audio_config.lua'
}
client_scripts { 
    'client/client.lua',
    'client/professional_audio.lua',
    'client/test_simple.lua'
}
server_scripts { 
    '@oxmysql/lib/MySQL.lua', 
    'server/*.lua',
    'server/alpr_server.lua'
}

dependencies { 'qb-core', 'oxmysql', 'lb-tablet' }
