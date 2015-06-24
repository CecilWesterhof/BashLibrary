# Functions:
# - connectedToNetwork

################################################################################
# Functions                                                                    #
################################################################################

# Usage: connectedToNetwork?
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
