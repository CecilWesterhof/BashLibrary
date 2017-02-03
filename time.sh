# This file needs to be include from BASHInitialisation.sh
# It uses functionality from this file
# Functions
# - getSeconds

################################################################################
# Functions                                                                    #
################################################################################

# Usage: getDuration <SECONDS>
# Needed
# - BASH functions
#   - fatal
function getDuration {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <SECONDS>"
        return
    fi

    local hours
    local minutes
    local seconds
    local tmp

    tmp=${1}; shift
    seconds=$((tmp % 60))
    tmp=$((tmp / 60))
    minutes=$((tmp % 60))
    hours=$((tmp / 60))
    printf "%d:%02d:%02d\n" ${hours} ${minutes} ${seconds}
}

# Usage: getSeconds <TIME_STRING>
# Needed
# - BASH functions
#   - fatal
function getSeconds {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <TIME_STRING>"
        return
    fi

    declare -r TIME_FORMAT='Time has to be in the format xx:xx or xx:xx:xx'

    declare -i seconds=0
    declare    timeString=${1}; shift

    if [[ ${#timeString} -ne 5 ]] && [[ ${#timeString} -ne 8 ]] ; then
        printf "${TIME_FORMAT}\n" >&2
        return 1
    fi
    while [[ ${#timeString} -gt 0 ]] ; do
        let seconds*=60
        seconds+=$((10#${timeString:0:2}))
        timeString=${timeString:3}
    done
    printf "${seconds}\n"
    return 0
}
