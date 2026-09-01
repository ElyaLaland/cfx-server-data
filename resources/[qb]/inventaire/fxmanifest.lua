fx_version 'cerulean'
game 'gta5'

author 'Elya'
description 'Inventaire maison - V2'
version '0.1.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png'
}

shared_script 'config/items.lua'

client_script 'client.lua'
server_script 'server.lua'

dependency 'qb-core'
dependency 'notifications'