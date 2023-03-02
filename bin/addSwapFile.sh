#!/usr/bin/env bash

: <<'###BLOCK-COMMENT'
Try to create and use new swapfile.
Parameters:
- swapfile to create
- number of GB (an integer)

Error codes:
 1 user is not root
 2 wrong parameters
 3 swapfile already exists
 4 not enough space on device
 5 filesystem is not on /dev
###BLOCK-COMMENT

# I want to exit on an error and an unset variable is an error
set -o errexit
set -o nounset


function getFreeGB {
    fields="$(df -BG -T "$(dirname "$1")" | awk '
        END { print dev, fs, gb }
        {
            dev = $1
            fs  = $2
            gb  = 0 + $5
        }
    ')"
    read -r dev fs gb <<< "${fields}"
    # Check $dev starts with /dev/
    if [[ ! $dev =~ ^/dev/.* ]]; then
        giveError "File system is not on /dev ($dev)" 5
    fi
    if [[ $fs == btrfs ]] ; then
        echo "This script is not guaranted to work with btrfs" >&2
    fi
    echo "$gb"
}

function giveError {
    echo "$1" >&2
    exit "$2"
}


# Get the parameters for the script
declare _scriptName
_scriptName=$(basename "$0")
readonly _scriptName
if [[ $(id --user) -ne 0 ]] ; then
    giveError "${_scriptName} should be run as root" 1
fi
if [[ $# -ne 2 ]] ; then
    giveError "ERROR: ${_scriptName} SWAPFILE GB" 2
fi
declare -r  _swapFile="$1"
declare -ir _gb="$2"

if [[ -e ${_swapFile} ]] ; then
    giveError "${_swapFile} already exists" 3
fi
declare -i  _gbFree
_gbFree=$(getFreeGB "${_swapFile}")
readonly _gbFree
# Make sure swapfile is less as a quarter of free space
if (( _gbFree <= _gb * 4 )) ; then
    giveError "Not enough space for swap file ($_gb, ${_gbFree})" 4
fi

echo Current Swap:
swapon
echo
date "+%T: Creating ${_swapFile}"
dd if=/dev/zero of="${_swapFile}" bs=1024 count=$((_gb * 1024 ** 2))
echo
# @@@@ check for right permission and ownership?
chown :disk "${_swapFile}"
chmod 600   "${_swapFile}"
mkswap      "${_swapFile}"
swapon      "${_swapFile}"
echo New Swap:
swapon
