#!/usr/bin/env bash

# Script that shows all processes that use swap, sorted on usage.
# It shows the KB swap, PID and name of the command.
# Overall used swap space and number of processes that use swap space
# is also displayed.
#
# At the moment the total swap space is about 90 percent of what ‘free’
# displays. When someone knows the reason of this difference:
# enlighten me. (bash@decebal.nl)
#
# I want to expand this script to show other metrics also. Let me know
# if you want certain metrics. (bash@decebal.nl)
#
# Written with the help of:
#     https://www.kernel.org/doc/Documentation/filesystems/proc.txt.
# One of the things this describes is /proc/PID/status.
# I always wanted to know which processes used swap and with this info
# I could write this script.
#
# I work with GET_COMMAND, NOTHING_FOUND and REPORT_COMMAND because in
# the future I want to use this script for other information also.
# The functionality will then be defined by the name of the script.


# An error should terminate the script
set -o errexit
set -o nounset


# Always define all used variables
# I use uppercase for readonly variables
declare -r DIVIDER="========================================"
declare -r SCRIPTNAME="${0##*/}"
# These are set in the script itself. So no -r and a readonly in the script.
declare    GET_COMMAND
declare    NOTHING_FOUND
declare    PROGNAME=""
declare    REPORT_COMMAND

# Holds all processes that need to be reported
declare    allValues=()
declare -i pid
declare -i pidLen=1
declare    statusFile
declare -i swapLen=1
declare -i totalSwap=0


# functions
function getStatusKBs () {
    awk '/'"${1}"'/ { print $2 }' "${statusFile}"
}

function getStatusValue () {
    awk '/'"${1}"'/ { $1 = "" ; print substr($0, 2) }' "${statusFile}"
}

function getSwap {
    local    progname
    local -i swap

    # Works because empty string equals 0
    swap=$(getStatusKBs "^VmSwap:")
    # Adds process that uses swap
    if [[ ${swap} -gt 0 ]] ; then
        progname=$(getStatusValue "^Name:")
        if [[ "${PROGNAME}" == "" ]] || [[ "${PROGNAME}" == "${progname}" ]] ; then
            allValues+=("${swap}:${pid}:${progname}")
            if [[ ${#swap} -gt ${swapLen} ]] ; then
                swapLen=${#swap}
            fi
            if [[ ${#pid} -gt ${pidLen} ]] ; then
                pidLen=${#pid}
            fi
            totalSwap+=${swap}
        fi
    fi
}

function reportFooter () {
    printf "${DIVIDER}\n"
    printf "Total used swap: ${totalSwap} KB\n"
    printf "There are ${#allValues[@]} processes using swap\n"
}

function reportProgramsUsingSwap {
    declare -r OLD_IFS="${IFS}"

    declare    progname
    declare    swapRecord

    printf "Programs using swap\n"
    printf "${DIVIDER}\n"
    for swapRecord in "${allValues[@]}" ; do
        IFS=:
        set -- ${swapRecord}
        progname="${3}"
        IFS=${OLD_IFS}
        printf "${progname}\n"
    done | sort | uniq
    reportFooter
}
function reportSwap {
    declare -r OLD_IFS="${IFS}"

    declare -i pid
    declare    progname
    declare -i swap
    declare    swapRecord

    if [[ "${PROGNAME}" != "" ]] ; then
        printf "Swap usage for ${PROGNAME}\n"
        printf "${DIVIDER}\n"
    fi
    for swapRecord in "${allValues[@]}" ; do
        IFS=:
        set -- ${swapRecord}
        swap="${1}"
        pid="${2}"
        progname="${3}"
        IFS=${OLD_IFS}
        if [[ "${PROGNAME}" == "" ]] ; then
            printf "swapped %${swapLen}d KB by PID=%-${pidLen}d (%s)\n" \
                "${swap}" "${pid}" "${progname}"
        else
            printf "swapped %${swapLen}d KB by PID=%-${pidLen}d\n" \
                "${swap}" "${pid}"
        fi
    done | sort --key=2 --numeric-sort
    reportFooter
}

# main code
case "${SCRIPTNAME}" in
    programsUsingSwap.sh)
        if [[ "${#}" -ne 0 ]] ; then
            printf "ERROR: ${SCRIPTNAME} does not take parameters\n"
            exit 1
        fi
        GET_COMMAND=getSwap
        NOTHING_FOUND="No swap used"
        REPORT_COMMAND=reportProgramsUsingSwap
        ;;
    swapUsage.sh)
        if [[ "${#}" -ne 0 ]] ; then
            printf "ERROR: ${SCRIPTNAME} does not take parameters\n"
            exit 1
        fi
        GET_COMMAND=getSwap
        NOTHING_FOUND="No swap used"
        REPORT_COMMAND=reportSwap
        ;;
    swapUsageProgram.sh)
        if [[ "${#}" -ne 1 ]] ; then
            printf "ERROR: ${SCRIPTNAME} <PROGRAM>\n"
            exit 1
        fi
        PROGNAME="${1}" ; shift
        readonly PROGNAME
        GET_COMMAND=getSwap
        NOTHING_FOUND="No swap used with ${PROGNAME}"
        REPORT_COMMAND=reportSwap
        ;;
    *)
        printf "${SCRIPTNAME} is an illegal name for this script\n"
        exit 1
        ;;
esac
readonly GET_COMMAND
readonly NOTHING_FOUND
readonly REPORT_COMMAND
cd /proc
for pid in $(ls -1 --directory [0-9]*) ; do
    statusFile="/proc/${pid}/status"
    # Script takes time, so make sure process stil exist
    if [ -f "${statusFile}" ] ; then
        "${GET_COMMAND}"
    fi
done
if [[ "${#allValues[@]}" -eq 0 ]] ; then
    printf "${NOTHING_FOUND}\n"
else
    "${REPORT_COMMAND}"
fi
