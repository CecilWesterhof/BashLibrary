#!/usr/bin/env bash

# Set computer in suspended mode when:
# - the screen is locked a certain time (5 minutes)
# - and is not connected to an AC adapter.
# to prevent the battery needless getting empty

# When your grep does not understand --quiet use -q

# An error should terminate the script
# An unset variable is also an error
set -o errexit
set -o nounset


# I always declare the variables I use
# I use all caps for read only variables
declare -r  DEBUG=T                    # T to get debug information
declare -ir MIN_LOCKED=5

declare -i minInDayLocked
declare -i minInDayNow
declare -i minLocked
declare    screenSaver


# When DEBUG is 'T' print message with a timestamp
function debug {
    if [[ "${DEBUG}" == T ]] ; then
        printf "%s: %s\n" "$(date +%T)" "${1}" >>~/Logging/suspend$(date +%F).log
    fi
}

# Get minutes belonging to a time string
# Can be in the format:
# - hh:mm
# - hh:mm:ss
# - …
# Only the hours and minutes are necesary.
# No check if the format is correct
# Hours or minutes can start with a zero, that is why I use 10#
function getMinutes {
    printf $((60 * 10#${1:0:2} + 10#${1:3:2}))
}

# Get minutes between two time strings with getMinutes
# Can be in the format:
# - hh:mm
# - hh:mm:ss
# - …
# Only the hours and minutes are necesary.
# No check if the format or number of parameters is correct
function getMinutesDifference {
    declare -i diff
    declare -i end
    declare -i start

    end=$(getMinutes "${1}")
    start=$(getMinutes "${2}")
    diff=$(( end - start ))
    # For when start was yesterday
    if [[ "${diff}" -lt 0 ]] ; then
        diff+=1440
    fi
    printf ${diff}
}

# When run from systemd DISPLAY is not set.
# Set it to the value that is going to be used to circumvent warnings
if [ ! -v DISPLAY ] ; then
    export DISPLAY=":0.0"
fi
debug "Before xscreensaver check"
while ! xscreensaver-command -time >/dev/null 2>&1 ; do
    sleep $(( MIN_LOCKED * 60 ))
done
debug "After xscreensaver check"
# Do it ‘forever’
while : ; do
    # Get screensaver status and since when
    screenSaver=$(xscreensaver-command -time)
    debug "${screenSaver}"
    # Only suspend when screen is locked and there is no AC adapter
    if grep --quiet locked <<<${screenSaver} && \
            grep --quiet "off-line" < <(acpi --ac-adapter) ; then
        debug "Locked and no AC adapter"
        minLocked=$(getMinutesDifference \
                       "$(date +%T)" \
                       "$(awk '{ print $9 }' <<<${screenSaver})")
        if [[ "${minLocked}" -ge "${MIN_LOCKED}" ]] ; then
            debug "Going to suspend (${minLocked})"
            # The command has an exit status of 1, so I need to mask it
            systemctl suspend || true
            # Suspend takes some time
            sleep 5
            debug "Computer woke up"
            # When waking up you have one minute to unlock the computer
        fi
    fi
    # Checking once a minute is enough
    sleep 60
done
