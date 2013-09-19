# This file needs to be include from BASHInitialisation.sh
# It uses functionality from this file

# Functions
# - showJournalctl

################################################################################
# Functions                                                                    #
################################################################################

# Usage: showJournalctl [--pager] [--since <SINCE>] 1 to 10 search strings
# Needed
# - BASH functions:
#   - journalctl
function showJournalctl {
    local -r USAGE="${FUNCNAME} [--pager] [--since <SINCE>] 1 to 10 search strings"

    local pager="false"
    local since="-1week"

    if [[ ${#} -eq 0 ]] ; then
        fatal "${USAGE}"
        return
    fi
    if [[ ${1} == "--pager" ]] ; then
        if [[ ${#} -lt 2 ]] ; then
            fatal "${USAGE}"
            return
        fi
        pager="true"; shift
    fi
    if [[ ${1} == "--since" ]] ; then
        if [[ ${#} -lt 3 ]] ; then
            fatal "${USAGE}"
            return
        fi
        since="${2}"; shift 2
    fi
    if [[ ${#} -gt 10 ]] ; then
        fatal "${USAGE}"
        return
    fi

    local command
    local regexp="/${1}/"; shift

    while [[ ${#} -gt 0 ]] ; do
        regexp+=" && /${1}/"; shift
    done
    command="journalctl --since=${since} | "
    command+="gawk --assign IGNORECASE=1 '${regexp} { print; }'"
    if [[ ${pager} == "true" ]] ; then
        command+=" | less"
    fi
    eval "${command}"
}
