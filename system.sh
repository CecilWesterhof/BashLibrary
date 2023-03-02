# This file needs to be include from BASHInitialisation.sh
# It uses functionality from this file

# Functions
# - getMemInfoFromPID
# - getMemInfoFromString
# - getVMPeak

################################################################################
# Functions                                                                    #
################################################################################

# Usage: getMemInfoFromPID <PID>
# Displays complete commandline and memory info for <PID>
# Needed:
# - BASH functions
#  - fatal
function getMemInfoFromPID {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} needs a PID" ; return
    fi
    declare -r PID=${1} ; shift

    # We only want the command with arguments, -ww to get everything
    ps --no-header --format %a -ww --pid ${PID}
    # We want VmHWM, VmPeak, VmRSS and VmSwap, displayed in Mb instead of kB
    awk '/^Vm[a-zA-z]*:/ {
        if ($2 < 1024) {
            size = $2
            type = "kB"
        } else {
            size = $2 / 1024
            type = "mB"
        }
        printf("%-8s %6d %s\n", $1, size, type)
    }' "/proc/${PID}/status"
}

# Usage: getMemInfoFromString <STRING>
# Calls getMemInfoFromPID for all processes where the commandline contains <STRING>
# Bug: the PID is also used in the match
# Needed:
# - BASH functions
#  - fatal
#  - getMemInfoFromPID
function getMemInfoFromString {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} needs a string" ; return
    fi
    declare -r STRING=${1} ; shift
    declare i

    for i in $(ps ax --no-header --format "%p %a" | \
      awk -v string="${STRING}" '{
        if (index($0, string)) {
          print $1
        }
      }') ; do
        # Check that PID still exists: skips the awk process that  gets the PID's
        if ps --pid ${i} >/dev/null ; then
            printf "Info from PID %s:\n" ${i}
            getMemInfoFromPID ${i}
            printf "\n"
        fi
    done
}

# Usage: getVMPeak <STRING>
# Display VmPeak if there is exactly one 'ps aux' line that contains <STRING>
# Needed:
# - BASH functions
#  - fatal
function getVMPeak {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} needs a string" ; return
    fi
    declare id
    declare searchString

    searchString="[${1:0:1}]${1:1}"; shift

    id=$(ps aux | awk "/${searchString}/ {print \$2}")
    if [[ $id == '' ]] ; then
        fatal 'No process found' ; return
    fi
    if [[ $id =~ [[:space:]] ]] ; then
        fatal 'More as one process found' ; return
    fi
    awk '/^VmPeak:/ { print $2 }' /proc/$id/status
}
