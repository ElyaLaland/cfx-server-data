fx_version 'cerulean'
game 'gta5'

author 'Elya'
description 'Création automatique d\'un seul personnage par compte (pas de multi-personnages)'
version '0.1.0'

client_script 'client.lua'

server_script '@oxmysql/lib/MySQL.lua'
server_script 'server.lua'

dependencies {
    'qb-core',
    'oxmysql'
}