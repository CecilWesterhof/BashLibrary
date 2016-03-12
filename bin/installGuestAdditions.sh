#!/usr/bin/env bash

# For this script to work you should have installed:
# - headers current running kernel
# - gcc


# An error should terminate the script
set -o errexit
set -o nounset


# Always define all used variables
# I use uppercase for readonly variables
declare -r COMMAND=VBoxLinuxAdditions.run
declare -r MEDIA=/media/cdrom
# This is set in the script itself. So no -r and a readonly in the script.
declare    IS_MOUNTED=no

# main code
if grep -q "${MEDIA}" /proc/mounts; then
    IS_MOUNTED=yes
fi
readonly IS_MOUNTED
if [[ "${IS_MOUNTED}" != yes ]] ; then
    mount "${MEDIA}"
fi
sudo sh "${MEDIA}/${COMMAND}" || printf "\n\n%s gave back %s\n" "${COMMAND}" "${?}"
# You need to reboot after this, but I find it still important to clean up
if [[ "${IS_MOUNTED}" != yes ]] ; then
    umount "${MEDIA}"
fi
