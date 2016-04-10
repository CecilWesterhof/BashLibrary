#!/usr/bin/env bash

set -o errexit
set -o nounset


function getExtensionPacks {
    /usr/bin/env ls -1 -rt "${DOWNLOAD_DIR}/"*"${EXTENSION}"
}


# Make sure that VIRTUALBOX_DOWNLOAD_DIR contains correct directory
declare -r DOWNLOAD_DIR="${VIRTUALBOX_DOWNLOAD_DIR}"
declare -r EXTENSION=.vbox-extpack
declare -r INSTALLED=$(VBoxManage list extpacks | awk '/^Version:      / { print $2 }')
declare -r INSTALLING="Going to install version %s\n"
declare -r NO_UPDATE_NEEDED="Installed version is already %s\n"
declare -r SCRIPTNAME="${0##*/}"
declare -r TO_INSTALL="$(getExtensionPacks | tail -n1)"

declare temp
declare toInstallClean


temp="${TO_INSTALL%${EXTENSION}}"
toInstallClean=${temp##*-}


# Only run as root
if [ $(id -u) -ne 0 ]; then
    printf "${SCRIPTNAME} must be run as root\n" 1>&2
    exit 1
fi
# When last version alreay installed there is nothing to do
if [[ ${INSTALLED} == ${toInstallClean} ]] ; then
    printf "${NO_UPDATE_NEEDED}" "${INSTALLED}"
    exit
fi


printf "${INSTALLING}" "${toInstallClean}"
VBoxManage extpack uninstall 'Oracle VM VirtualBox Extension Pack'
VBoxManage extpack install   "${TO_INSTALL}"
