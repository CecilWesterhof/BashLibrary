#!/usr/bin/env bash

set -o errexit
set -o nounset


function getExtensionPacks {
    /usr/bin/env ls -1 -rt ${DOWNLOAD_DIR}/*.vbox-extpack
}


# Make sure that VIRTUALBOX_DOWNLOAD_DIR contains correct directory
declare -r DOWNLOAD_DIR="${VIRTUALBOX_DOWNLOAD_DIR}"
declare -r SCRIPTNAME="${0##*/}"
declare -r TO_INSTALL="$(getExtensionPacks | tail -n1)"


if [ $(id -u) -ne 0 ]; then
    printf "${SCRIPTNAME} must be run as root\n" 1>&2
    exit 1
fi


printf "Going to install %s\n" "${TO_INSTALL}"
VBoxManage extpack uninstall   'Oracle VM VirtualBox Extension Pack'
VBoxManage extpack install     "${TO_INSTALL}"
