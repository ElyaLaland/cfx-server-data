fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Elya'
description 'Menu administration'
version '0.2.0'

dependency 'notifications'
dependency 'oxmysql'

shared_script 'config.lua'
server_script '@oxmysql/lib/MySQL.lua'
server_script 'server.lua'
client_script 'client.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}