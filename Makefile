ifeq (Cygwin,$(shell uname -o))
		addonpath := /c/Users/chris/AppData/Roaming/NCSOFT/WildStar
else
		addonpath := ${HOME}/wineprefixes/wildstar/drive_c/users/chris/Application\ Data/NCSOFT/WildStar
endif

install:
		find ${addonpath}/Addons/ -type l -name 'Viking*' -delete
		ln -s -t ${addonpath}/Addons ${PWD}/Viking*

wipe:
		rm -rf ${addonpath}/AddonSaveDataForDevelopment/*

play:
		rm -f ${addonpath}/Addons
		rm -f ${addonpath}/AddonSaveData
		ln -s ${addonpath}/AddonsForPlaying ${addonpath}/Addons
		ln -s ${addonpath}/AddonSaveDataForPlaying ${addonpath}/AddonSaveData

dev:
		rm -f ${addonpath}/Addons
		rm -f ${addonpath}/AddonSaveData
		ln -s ${addonpath}/AddonsForDevelopment ${addonpath}/Addons
		ln -s ${addonpath}/AddonSaveDataForDevelopment ${addonpath}/AddonSaveData

towindows:
		ifeq (Cygwin,$(shell uname -o))
				$(error Task only works from Linux.)
		endif
		rsync --exclude ".*/" -avP ${PWD}/ /media/windows/cygwin64/home/chris/vikingui/

fromwindows:
		ifeq (Cygwin,$(shell uname -o))
				$(error Task only works from Linux.)
		endif
		rsync --exclude ".*/" -avP /media/windows/cygwin64/home/chris/vikingui/ ${PWD}/
