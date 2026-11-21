fx_version "adamant"

game "gta5"

client_scripts {
	"client.lua",
}

files {
    "html/index.html",
    "html/img/*",
    "html/music.mp3"
}

loadscreen "html/index.html"
ui_page "html/index.html?nuipage=true"
loadscreen_cursor "yes"
loadscreen_manual_shutdown "yes"
