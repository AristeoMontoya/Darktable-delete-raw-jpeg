install:
	cp './deleteRawJpeg.lua' ~/.config/darktable/lua/tools

flatpak-install:
	cp './deleteRawJpeg.lua' ~/.var/app/org.darktable.Darktable/config/darktable/lua/tools/

remove-all:
	rm '~/.config/darktable/lua/examples/deleteRawJpeg.lua'
	rm '~/.var/app/org.darktable.Darktable/config/darktable/lua/tools/deleteRawJpeg.lua'

remove:
	rm '~/.config/darktable/lua/examples/deleteRawJpeg.lua'

flatpak-remove:
	rm ~/.var/app/org.darktable.Darktable/config/darktable/lua/tools/deleteRawJpeg.lua
