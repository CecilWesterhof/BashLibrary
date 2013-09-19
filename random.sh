# This file needs to be include from BASHInitialisation.sh
# It uses functionality from this file
# Functions
# - getRandom
# - getRandomInRange
# - getUUID

################################################################################
# Functions                                                                    #
################################################################################

# Usage: getRandom [--secure]
# Needed : Nothing
function getRandom {
    declare inputFile=/dev/urandom

    if [[ ${#} -ge 1 ]] && [[ ${1} == "--secure" ]] ; then
        inputFile=/dev/random; shift
    fi
    if [[ ${#} -ne 0 ]] ; then
        fatal "${FUNCNAME} [--secure]"
        return 1
    fi

    od --read-bytes=4 -t u4 ${inputFile} | awk '/^0000000 / { print $2 }'
}

# Usage: getRandomInRange [--secure] <MIN_VALUE> <MAX_VALUE>
# Needed
# - BASH functions:
#   - getRandom
function getRandomInRange {
    declare -i maxValue
    declare -i minValue
    declare -i modulo
    declare    params=""

    if [[ ${#} -ge 1 ]] && [[ ${1} == "--secure" ]] ; then
        params="--secure"; shift
    fi
    if [[ ${#} -ne 2 ]] ; then
        fatal "${FUNCNAME} [--secure] <MIN_VALUE> <MAX_VALUE>"
        return 1
    fi
    minValue=${1}; shift
    maxValue=${1}; shift
    if [[ ${maxValue} -le ${minValue} ]] ; then
        fatal "${FUNCNAME}: ${maxValue} is not greater as ${minValue}"
        return 1
    fi

    modulo=${maxValue}-${minValue}+1
    printf "%d\n" $(($(getRandom ${params}) % ${modulo} + ${minValue}))
}

# Usage: getUUID [--secure]
# Needed
# - BASH functions
#   getUUID
function getUUID {
    declare -r SIXTEEN_BITS=65535
    declare -r TWELF_BITS=4095

    declare    params=""

    if [[ ${#} -ge 1 ]] && [[ ${1} == "--secure" ]] ; then
        params="--secure"; shift
    fi
    if [[ ${#} -ne 0 ]] ; then
        fatal "${FUNCNAME} [--secure]"
        return
    fi

    printf "%.4x%.4x-%.4x-4%.3x-%x%.3x-%.4x%.4x%.4x\n" \
           $(getRandomInRange 0 ${SIXTEEN_BITS}) \
           $(getRandomInRange 0 ${SIXTEEN_BITS}) \
           $(getRandomInRange 0 ${SIXTEEN_BITS}) \
           $(getRandomInRange 0 ${TWELF_BITS})   \
           $(getRandomInRange 8 11)              \
           $(getRandomInRange 0 ${TWELF_BITS})   \
           $(getRandomInRange 0 ${SIXTEEN_BITS}) \
           $(getRandomInRange 0 ${SIXTEEN_BITS}) \
           $(getRandomInRange 0 ${SIXTEEN_BITS})
}
