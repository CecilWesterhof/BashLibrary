#!/usr/bin/env bash

set -o errexit
set -o nounset



function getFreeGB {
    df -BG $(dirname $1) |  \
        tail -n 1        |  \
        awk '{print substr($4, 1, length($4) - 1)}'
}

function giveError {
    echo $1
    exit 1
}


declare -r _scriptName=$(basename ${0})
if [[ $(id --user) -ne 0 ]] ; then
    giveError "${_scriptName} should be run as root"
fi
if [[ $# -ne 2 ]] ; then
    giveError "ERROR: ${_scriptName} SWAPFILE GB"
fi
declare -r  _swapFile=$1
declare -ir _gb=$2

if [[ -e ${_swapFile} ]] ; then
    giveError "${_swapFile} already exists"
fi
declare -ir _gbFree=$(getFreeGB ${_swapFile})
# Make sure swapfile is less as a quarter of free space
if [[ ${_gbFree} -le $(($_gb * 4)) ]] ; then
    giveError "Not enough space for swap file ($_gb, ${_gbFree})"
fi
echo Current Swap:
swapon
echo
date "+%T: Creating ${_swapFile}"
dd if=/dev/zero of=${_swapFile} bs=1024 count=$(($_gb * 1024 ** 2))
echo
chmod 600 ${_swapFile}
mkswap    ${_swapFile}
swapon    ${_swapFile}
echo New Swap:
swapon
