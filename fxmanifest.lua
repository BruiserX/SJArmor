fx_version 'cerulean'
game 'gta5'

name 'SJArmor'
author 'subj3ct'
version '1.0.0'
description 'Advanced armor plate system for ox_inventory'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'data/containers.lua'
}

dependencies {
    'ox_inventory',
    'ox_lib'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes' 