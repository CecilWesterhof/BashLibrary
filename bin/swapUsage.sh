#!/usr/bin/env bash

# Several scripts in one file:
# - memUsage.sh
# - memUsageProgram.sh
# - programsUsingMem.sh
# - programsUsingSwap.sh
# - swapUsage.sh
# - swapUsageProgram.sh
# The functionality is defined by the name of the script.
#
# Written with the help of:
#     https://www.kernel.org/doc/Documentation/filesystems/proc.txt
# One of the things this describes is /proc/PID/status.
#
# The total swap space that is reported can be quite different fror what
# ‘free’ displays. This is because the kernel and tmpfs can also use
# swap space. If anyone knows how to get those values: (bash@decebal.nl)
#
# I want to expand this script to show other metrics also. Let me know
# if you want certain metrics. (bash@decebal.nl)
#
#
# The different scripts
#
# memUsage.sh:
# Script that for all processes shows much RSS Memory they use, sorted
# on usage.
# It shows the MB RSS Memory, PID and name of the command.
# Overall used RSS Memory and number of processes that use RSS Memory is
# also displayed.
#
# memUsageProgram.sh:
# Script that shows all processes using certain commands how much RSS
# memory they use, sorted on usage.
# It shows the MB RSS Memory and PID.
# Overall used RSS Memory and number of processes that use RSS Memory is
# also displayed. (Only for processes using the commands.)
#
# programsUsingMem:
# Scripts that shows all commands that are using RSS Memory, sorted on
# name.
# Overall used RSS Memory and number of processes that RSS Memory space
# is also displayed.
#
# programsUsingSwap:
# Scripts that shows all commands that are using swap, sorted on name.
# Overall used swap space and number of processes that use swap space
# is also displayed.
#
# swapUsage.sh:
# Script that shows all processes that use swap, sorted on usage.
# It shows the MB swap, PID and name of the command.
# Overall used swap space and number of processes that use swap space
# is also displayed.
#
# swapUsageProgram.sh:
# Script that shows all processes using certain commands that use swap,
# sorted on usage.
# It shows the MB swap and PID.
# Overall used swap space and number of processes that use swap space
# is also displayed. (Only for processes using the command.)
#


# An error should terminate the script
set -o errexit
set -o nounset


# Always define all used variables
# I use uppercase for readonly variables
declare -ir COMMAND_NAME_LEN=15
declare -r  DIVIDER="========================================"
declare -r  OLD_IFS="${IFS}"
declare -r  SCRIPTNAME="${0##*/}"

# These are set in the script itself. So no -r and a readonly in the script.
declare     GET_COMMAND
declare     NOTHING_FOUND
declare     PROGNAME
declare     REPORT_COMMAND
declare     REPORT_STRING
declare     TAIL_COUNT=+0               # Default we want all output

# Holds all processes that need to be reported
declare    allValues=()
declare -i pid
declare -i pidLen=1
declare    prognameArray=()
declare    statusFile
declare -i usageLen=3
declare -i totalUsage=0

# functions
function checkNoParameters {
    if [[ "${#params[@]}" -ne 0 ]] ; then
        errorNoParameters
    fi
}

function checkOnlyCount {
    getCount
    if [[ "${#params[@]}" -ne 0 ]] ; then
        errorOnlyCount
    fi
}

function doWork {
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
}

function errorNoParameters {
    printf "ERROR: ${SCRIPTNAME} does not take parameters\n"
    exit 1
}

function errorNoPrograms {
    printf "ERROR: ${SCRIPTNAME} [--count <NO OF PROCESSES TO DISPLAY>] <PROGRAMS>\n"
    exit 1
}

function errorOnlyCount {
    printf "ERROR: ${SCRIPTNAME} [--count <NO OF PROCESSES TO DISPLAY>]\n"
    exit 1
}

function getCount {
    if [[ "${#params[@]}" -ge 2 ]] && [[ "${params[0]}" == '--count' ]] ; then
        TAIL_COUNT="${params[1]}"
        params=("${params[@]:2}")
    fi
}

function getMem {
    getUsage "VmRSS"
}

function getPrognames {
    getCount
    if [[ "${#params[@]}" -ne 1 ]] ; then
        errorNoPrograms
    fi
    PROGNAME="${params[0]}"
    params=("${params[@]:1}")
    readonly PROGNAME
    IFS=:
    set -- ${PROGNAME}
    while [[ ${#} -ge 1 ]]; do
        prognameArray+=("${1:0:${COMMAND_NAME_LEN}}"); shift
    done
    IFS="${OLD_IFS}"
}

# For lines that display usage in KB
# Only the second field is required
function getStatusKBs () {
    awk '/'"${1}"'/ { print $2 }' "${statusFile}"
}

# First field is de name and need to be removed
function getStatusValue () {
    awk '/'"${1}"'/ { $1 = "" ; print substr($0, 2) }' "${statusFile}"
}

function getSwap {
    getUsage "VmSwap"
}

function getUsage {
    local    name
    local    progname
    local -i usage
    local    usageString
    local    useProcess=no

    # Works because empty string equals 0
    # So when the sought entry is not found usage becomes zero
    usage=$(getStatusKBs "^${1}:")
    # Adds process that uses what is sought
    if [[ "${usage}" -gt 0 ]] ; then
        progname=$(getStatusValue "^Name:")
        if [[ "${#prognameArray[@]}" -eq 0 ]] ; then
            useProcess=yes
        else
            for name in "${prognameArray[@]}" ; do
                if [[ "${progname}" == "${name}" ]] ; then
                    useProcess=yes
                    break
                fi
            done
        fi
        if [[ "${useProcess}" == "yes" ]] ; then
            allValues+=("${usage}:${pid}:${progname}")
            usageString="$(printUsage ${usage})"
            if [[ "${#usageString}" -gt "${usageLen}" ]] ; then
                usageLen=${#usageString}
            fi
            if [[ "${#pid}" -gt "${pidLen}" ]] ; then
                pidLen=${#pid}
            fi
            totalUsage+="${usage}"
        fi
    fi
}

function printUsage {
    printf "$(((${1} + 512) / 1024)) MB"
}

function reportFooter () {
    declare -r TOTAL_USAGE="$(printUsage ${totalUsage})"

    printf "${DIVIDER}\n"
    printf "Total used ${REPORT_STRING}: ${TOTAL_USAGE}\n"
    if [[ ${#allValues[@]} -eq 1 ]] ; then
        printf "There is 1 process"
    else
        printf "There are ${#allValues[@]} processes"
    fi
    printf " using ${REPORT_STRING}\n"
}

function reportProgramsUsing {
    declare    progname
    declare    usageRecord

    printf "Programs using ${REPORT_STRING}\n"
    printf "${DIVIDER}\n"
    for usageRecord in "${allValues[@]}" ; do
        IFS=:
        set -- ${usageRecord}
        progname="${3}"
        IFS="${OLD_IFS}"
        printf "${progname}\n"
    done | sort --ignore-case | uniq
    reportFooter
}

function reportUsage {
    declare -i pid
    declare    progname
    declare    usage
    declare    usageRecord

    printf "${REPORT_STRING} usage"
    if [[ ${#prognameArray[@]} -ne 0 ]] ; then
        printf " for ${PROGNAME}"
    fi
    printf "\n"
    printf "${DIVIDER}\n"
    for usageRecord in "${allValues[@]}" ; do
        IFS=:
        set -- ${usageRecord}
        usage="$(printUsage ${1})"
        pid="${2}"
        progname="${3}"
        IFS="${OLD_IFS}"
        printf "${REPORT_STRING} %${usageLen}s by PID=%-${pidLen}d" \
            "${usage}" "${pid}"
        if [[ ${#prognameArray[@]} -ne 1 ]] ; then
            printf " (%s)" "${progname}"
        fi
        printf "\n"
    done | sort --key=2 --numeric-sort | tail -n "${TAIL_COUNT}"
    reportFooter
}

function reportUsageCombined {
    declare -Ai combined
    declare     combinedRecord
    declare     combinedUsage
    declare -i  pid
    declare     progname
    declare -i  usage
    declare     usageRecord

    printf "${REPORT_STRING} usage combined"
    if [[ ${#prognameArray[@]} -ne 0 ]] ; then
        printf " for ${PROGNAME}"
    fi
    printf "\n"
    printf "${DIVIDER}\n"
    for usageRecord in "${allValues[@]}" ; do
        IFS=:
        set -- ${usageRecord}
        usage="${1}"
        progname="${3}"
        IFS="${OLD_IFS}"
        combined["${progname}"]+="${usage}"
        if [[ "${#combined[${progname}]}" -gt "${usageLen}" ]] ; then
            usageLen="${#combined[${progname}]}"
        fi
    done
    for combinedRecord in "${!combined[@]}" ; do
        combinedUsage="$(printUsage ${combined[${combinedRecord}]})"
        printf "${REPORT_STRING} %${usageLen}s" "${combinedUsage}"
        if [[ ${#prognameArray[@]} -ne 1 ]] ; then
            printf " by %s" "${combinedRecord}"
        fi
        printf "\n"
    done | sort --key=2 --numeric-sort | tail -n "${TAIL_COUNT}"
    reportFooter
}


# main code
params=("${@}")
cd /proc
case "${SCRIPTNAME}" in
    memUsage.sh)
        checkOnlyCount
        GET_COMMAND=getMem
        NOTHING_FOUND="No memory used"
        REPORT_COMMAND=reportUsage
        REPORT_STRING="RSSMemory"
        ;;
    memUsageCombined.sh)
        checkOnlyCount
        GET_COMMAND=getMem
        NOTHING_FOUND="No memory used"
        REPORT_COMMAND=reportUsageCombined
        REPORT_STRING="RSSMemory"
        ;;
    memUsageProgram.sh)
        getPrognames
        GET_COMMAND=getMem
        NOTHING_FOUND="No memory used with ${PROGNAME}"
        REPORT_COMMAND=reportUsage
        REPORT_STRING="RSSMemory"
        ;;
    memUsageProgramCombined.sh)
        getPrognames
        GET_COMMAND=getMem
        NOTHING_FOUND="No memory used with ${PROGNAME}"
        REPORT_COMMAND=reportUsageCombined
        REPORT_STRING="RSSMemory"
        ;;
    programsUsingMem.sh)
        checkNoParameters
        GET_COMMAND=getMem
        NOTHING_FOUND="No memory used"
        REPORT_COMMAND=reportProgramsUsing
        REPORT_STRING="RSS Memory"
        ;;
    programsUsingSwap.sh)
        checkNoParameters
        GET_COMMAND=getSwap
        NOTHING_FOUND="No swap used"
        REPORT_COMMAND=reportProgramsUsing
        REPORT_STRING="swap"
        ;;
    swapUsage.sh)
        checkOnlyCount
        GET_COMMAND=getSwap
        NOTHING_FOUND="No swap used"
        REPORT_COMMAND=reportUsage
        REPORT_STRING="swap"
        ;;
    swapUsageCombined.sh)
        checkOnlyCount
        GET_COMMAND=getSwap
        NOTHING_FOUND="No swap used"
        REPORT_COMMAND=reportUsageCombined
        REPORT_STRING="swap"
        ;;
    swapUsageProgram.sh)
        getPrognames
        GET_COMMAND=getSwap
        NOTHING_FOUND="No swap used with ${PROGNAME}"
        REPORT_COMMAND=reportUsage
        REPORT_STRING="swap"
        ;;
    swapUsageProgramCombined.sh)
        getPrognames
        GET_COMMAND=getSwap
        NOTHING_FOUND="No swap used with ${PROGNAME}"
        REPORT_COMMAND=reportUsageCombined
        REPORT_STRING="swap"
        ;;
    *)
        printf "${SCRIPTNAME} is an illegal name for this script\n"
        exit 1
        ;;
esac
readonly GET_COMMAND
readonly NOTHING_FOUND
readonly REPORT_COMMAND
readonly REPORT_STRING
readonly TAIL_COUNT
doWork
