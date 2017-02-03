#!/usr/bin/env bash

# An error should terminate the script
set -o errexit
set -o nounset


# Always define all used variables
# I use uppercase for readonly variables
declare -r COMMAND=VBoxLinuxAdditions.run
declare -r DISTRIBUTION=$(awk -F = '{
                              if ($1 == "ID") {
                                  print $2
                              }
                          }' /etc/os-release 2>/dev/null)
declare -r MEDIA=/media/cdrom

# This is set in the script itself. So no -r and a readonly in the script.
declare    IS_MOUNTED=no

if [[ $(id --user) != 0 ]] ; then
    printf "Need to be root to execute this!!!\n"
    exit 1
fi


# main code
# Make sure the necessary stuff is installed
case "${DISTRIBUTION}" in
    debian|ubuntu)
	apt-get update
	apt-get upgrade
	apt-get install build-essential module-assistant
	m-a prepare
        ;;
    *)
        printf "Unknown distibution (${DISTRIBUTION})\n"
        printf "You should have installed at least the headers for the current running kernel and gcc\n"
        printf "If not: terminate this script\n"
        sleep 30
        ;;
esac
if grep -q "${MEDIA}" /proc/mounts; then
    IS_MOUNTED=yes
fi
readonly IS_MOUNTED
if [[ "${IS_MOUNTED}" != yes ]] ; then
    mount "${MEDIA}"
fi
sh "${MEDIA}/${COMMAND}" || printf "\n\n%s gave back %s\n" "${COMMAND}" "${?}"
# You need to reboot after this, but I find it still important to clean up
if [[ "${IS_MOUNTED}" != yes ]] ; then
    umount "${MEDIA}"
fi
printf "Successful installed guest additions.\nYou should reboot your guest now.\n"
