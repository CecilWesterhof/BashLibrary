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
# It shows the KB RSS Memory, PID and name of the command.
# Overall used RSS Memory and number of processes that use RSS Memory is
# also displayed.
#
# memUsageProgram.sh:
# Script that shows all processes using certain commands how much RSS
# memory they use, sorted on usage.
# It shows the KB RSS Memory and PID.
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
# It shows the KB swap, PID and name of the command.
# Overall used swap space and number of processes that use swap space
# is also displayed.
#
# swapUsageProgram.sh:
# Script that shows all processes using certain commands that use swap,
# sorted on usage.
# It shows the KB swap and PID.
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

# Holds all processes that need to be reported
declare    allValues=()
declare -i pid
declare -i pidLen=1
declare    prognameArray=()
declare    statusFile
declare -i usageLen=1
declare -i totalUsage=0

# functions
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

function getMem {
    getUsage "VmRSS"
}

function getPrognames {
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
            if [[ "${#usage}" -gt "${usageLen}" ]] ; then
                usageLen=${#usage}
            fi
            if [[ "${#pid}" -gt "${pidLen}" ]] ; then
                pidLen=${#pid}
            fi
            totalUsage+="${usage}"
        fi
    fi
}

function reportFooter () {
    printf "${DIVIDER}\n"
    printf "Total used ${REPORT_STRING}: ${totalUsage} KB\n"
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
    declare -i usage
    declare    usageRecord

    if [[ ${#prognameArray[@]} -ne 0 ]] ; then
        printf "${REPORT_STRING} usage for ${PROGNAME}\n"
        printf "${DIVIDER}\n"
    fi
    for usageRecord in "${allValues[@]}" ; do
        IFS=:
        set -- ${usageRecord}
        usage="${1}"
        pid="${2}"
        progname="${3}"
        IFS="${OLD_IFS}"
        printf "${REPORT_STRING} %${usageLen}d KB by PID=%-${pidLen}d" \
            "${usage}" "${pid}"
        if [[ ${#prognameArray[@]} -ne 1 ]] ; then
            printf " (%s)" "${progname}"
        fi
        printf "\n"
    done | sort --key=2 --numeric-sort
    reportFooter
}


# main code
cd /proc
case "${SCRIPTNAME}" in
    memUsage.sh)
        if [[ "${#}" -ne 0 ]] ; then
            printf "ERROR: ${SCRIPTNAME} does not take parameters\n"
            exit 1
        fi
        GET_COMMAND=getMem
        NOTHING_FOUND="No memory used"
        REPORT_COMMAND=reportUsage
        REPORT_STRING="RSSMemory"
        ;;
    memUsageProgram.sh)
        if [[ "${#}" -ne 1 ]] ; then
            printf "ERROR: ${SCRIPTNAME} <PROGRAM>\n"
            exit 1
        fi
        PROGNAME="${1}" ; shift
        readonly PROGNAME
        getPrognames
        GET_COMMAND=getMem
        NOTHING_FOUND="No memory used with ${PROGNAME}"
        REPORT_COMMAND=reportUsage
        REPORT_STRING="RSSMemory"
        ;;
    programsUsingMem.sh)
        if [[ "${#}" -ne 0 ]] ; then
            printf "ERROR: ${SCRIPTNAME} does not take parameters\n"
            exit 1
        fi
        GET_COMMAND=getMem
        NOTHING_FOUND="No memory used"
        REPORT_COMMAND=reportProgramsUsing
        REPORT_STRING="RSS Memory"
        ;;
    programsUsingSwap.sh)
        if [[ "${#}" -ne 0 ]] ; then
            printf "ERROR: ${SCRIPTNAME} does not take parameters\n"
            exit 1
        fi
        GET_COMMAND=getSwap
        NOTHING_FOUND="No swap used"
        REPORT_COMMAND=reportProgramsUsing
        REPORT_STRING="swap"
        ;;
    swapUsage.sh)
        if [[ "${#}" -ne 0 ]] ; then
            printf "ERROR: ${SCRIPTNAME} does not take parameters\n"
            exit 1
        fi
        GET_COMMAND=getSwap
        NOTHING_FOUND="No swap used"
        REPORT_COMMAND=reportUsage
        REPORT_STRING="swap"
        ;;
    swapUsageProgram.sh)
        if [[ "${#}" -ne 1 ]] ; then
            printf "ERROR: ${SCRIPTNAME} <PROGRAM>\n"
            exit 1
        fi
        PROGNAME="${1}" ; shift
        readonly PROGNAME
        getPrognames
        GET_COMMAND=getSwap
        NOTHING_FOUND="No swap used with ${PROGNAME}"
        REPORT_COMMAND=reportUsage
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
doWork
