# Functions:
# - checkInternetConnection
# - checkWiFi
# - connectedToNetwork
# - getIPs

################################################################################
# Functions                                                                    #
################################################################################

function checkInternetConnection {
    if [[ ${#} -ge 1 ]] && [[ "${1}" == '--once' ]] ; then
        declare -r _once=yes ; shift
    else
        declare -r _once=no
    fi
    if [[ ${#} -ne 0 ]] ; then
        fatal "${FUNCNAME} [--once]"
        return
    fi
    if ! isVarSet pingDomain ; then
        fatal "The variable 'pingDomain' has to be set."
        return
    fi

    while : ; do
        if ping -q -c 1 -W 1 ${pingDomain} &>/dev/null ; then
            showMessage y 'Connected'
        else
            showMessage y 'NOT Connected'
        fi
        if [[ ${_once} == 'yes' ]] ; then
            return
        fi
        waitMinutes 5
    done
}

function checkWiFi {
    if [[ ${#} -ge 1 ]] && [[ "${1}" == '--tee' ]] ; then
        declare -r TEE=yes ; shift
    else
        declare -r TEE=no
    fi
    if [[ ${#} -ge 1 ]] ; then
        declare    WIFI="${1}" ; shift
    else
        declare    WIFI="^wlp2s0:"
    fi
    if [[ ${#} -ne 0 ]] ; then
        fatal "${FUNCNAME} [--tee] [<WiFi Interface>]"
        return
    fi

    declare -i lines=0
    declare    output

    while : ; do
        output=''
        if [[ "${lines}" -eq 0 ]] ; then
            output+="\\n$(head -n 2 /proc/net/wireless)"
        fi
        output+="\\n$(grep ${WIFI} /proc/net/wireless)     ($(date +%T))"
        printf "${output}"
        if [[ "${TEE}" == 'yes' ]] ; then
            printf "${output}" >> "${HOME}/Logging/checkWiFi_$(date +%F).log"
        fi
        lines=$(( (lines + 1) % 60 ))
        sleep $(( 60 - $(date +%S) ))
        if [[ "$(date +%M)" == "00" ]] ; then
            lines=0
        fi
    done
}

# Usage: connectedToNetwork
# Check that the system is connected to the network
# Needed:
# - BASH functions
#   - fatal
function connectedToNetwork {
    if [[ ${#} -ne 0 ]] ; then
        fatal "${FUNCNAME} does not take arguments"
        return
    fi

    if [[ "$(/sbin/route -n | grep -c '^0\.0\.0\.0')" -gt 0 ]] ; then
        printf "yes\n"
    else
        printf "no\n"
    fi
}

# Usage: getIPs [--only-first]
# Get the ip-addresses of your system. With --only-first, only the first address.
# Needed
# - BASH function
#   - fatal
function getIPs {
    declare IDENTIFIER="inet "
    declare IP_REGEX='[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
    declare PARAMETERS='--only-matching -E'

    if [[ ${#} -ge 1 ]] && [[ ${1} == '--only-first' ]]; then
        PARAMETERS="--max-count=1 ${PARAMETERS}"; shift
    fi
    if [[ ${#} -ne 0 ]] ; then
        fatal "${FUNCNAME} [--only-first]"
        return
    fi

    /sbin/ifconfig | \
        grep ${PARAMETERS} "${IDENTIFIER}${IP_REGEX} " | \
        cut -c $((${#IDENTIFIER} + 1))-
}

function getExternalIP {
    curl http://myexternalip.com/raw
    printf "\n"
}
