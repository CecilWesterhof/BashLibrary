#!/usr/bin/env bash

: <<'###BLOCK-COMMENT'
A simple program to thin out the logfiles (older as three months in this case).
Can be run from the commandline and could be hung in systemd timers.
If there are log files you want to keep, you can put them in a subdirectory
(-maxdept 0)

Improvements (but not very important):
- Put beforeMtime and dirs in a config file.
###BLOCK-COMMENT


# exit on error and a variable that is not set is an error
set -o errexit
set -o nounset


# Give an error on stderr
# And exit with the right error code
function giveError {
    echo "$1" >&2
    exit "$2"
}

function init {
    # Make sure the script is run by root
    if [[ $(id --user) -ne 0 ]] ; then
        giveError "${_scriptName} should be run as root" 1
    fi
: <<'###BLOCK-COMMENT'
I want to clean out older as three months, this is a fancy way to do it.
But three monts is between 89 and 92 days, so I choose 92.
At least it shows how you can do things with date.
beforeMtime=$(( ($(date '+%s') - $(date -d '3 months ago' '+%s')) / 86400 ))
###BLOCK-COMMENT
    beforeMtime=92
    dirs=(cecil imaps root)
}

# To show the used space before and after thinning the log files
function showDuDirToClean {
    du -h ${dirToClean}
}


init

for subDir in "${dirs[@]}" ; do
    dirToClean="/var/log/${subDir}"
    showDuDirToClean
    find                            \
        ${dirToClean}/*.log         \
        -maxdepth 0                 \
        -type f                     \
        -mtime "+${beforeMtime}"    \
        -delete
    showDuDirToClean
    echo ""
done
