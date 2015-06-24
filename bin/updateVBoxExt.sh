#!/usr/bin/env bash

set -o errexit
set -o nounset


function getExtensionPacks {
    /usr/bin/env ls -1 -rt ${DOWNLOAD_DIR}/*.vbox-extpack
}


declare -r DOWNLOAD_DIR="FILL WITH RIGHT VALUE"
declare    TO_INSTALL="$(getExtensionPacks | tail -n1)"


printf "Going to install %s\n" "${TO_INSTALL}"
VBoxManage extpack uninstall   'Oracle VM VirtualBox Extension Pack'
VBoxManage extpack install     "${TO_INSTALL}"
