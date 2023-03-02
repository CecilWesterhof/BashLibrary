# This file needs to be include from BASHInitialisation.sh
# It uses functionality from this file
# Functions
# - getSeconds
# - waitMinutes
# - waitSeconds

################################################################################
# Functions                                                                    #
################################################################################

# Usage: getDuration <SECONDS>
# Converts SECONDS into a TIME_STRING
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
# Converts a TIME_STRING in number of seconds
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

# Usage: waitMinutes <INTERVAL>
# Needed
# Waits until minutes is a multiply of INTERVAL
# 60 % INTERVAL should be 0
# - BASH functions
#   - fatal
#   - waitSeconds
function waitMinutes {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <INTERVAL>"
        return
    fi

    declare -r INTERVAL=${1}; shift

    if [[ $((60 % ${INTERVAL})) -ne 0 ]] ; then
        fatal "${FUNCNAME}: 60 is not a multiply of ${INTERVAL}"
        return
    fi

    waitSeconds $((${INTERVAL} * 60))
}


# Usage: waitSeconds <INTERVAL>
# Waits until seconds is a multiply of INTERVAL
# 3600 % INTERVAL should be 0
# Needed
# - BASH functions
#   - fatal
#   - getSeconds
function waitSeconds {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <INTERVAL>"
        return
    fi

    declare -r INTERVAL=${1}; shift

    if [[ $((3600 % ${INTERVAL})) -ne 0 ]] ; then
        fatal "${FUNCNAME}: 3600 is not a multiply of ${INTERVAL}"
        return
    fi

    sleep $(( ${INTERVAL} - ($(getSeconds $(date +%T)) % ${INTERVAL})))
}
