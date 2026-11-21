fx_version 'cerulean'
games { 'gta5' }
lua54 'yes'

description "Vision v1 Map"
author 'KL'
version "1.0"

client_script {
	'client.lua'
 }

ui_page('html/index.html')

files({
	"html/script.js",
	"html/styles.css",
	"html/index.html",
})
