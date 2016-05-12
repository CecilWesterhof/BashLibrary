#!/usr/bin/env bash

# An error should terminate the script
set -o errexit
set -o nounset


# Always define all used variables
declare    command
declare    directory
declare    empty
declare -i expectedErrorcode
declare -i gotErrorcode
declare    inputfile
declare    testconfig
declare    testError
declare -i wrongErrorCodes=0
declare -i wrongStderrs=0
declare -i wrongStdouts=0
declare -i wrongTests=0

if [[ ${#} -ne 1 ]] ; then
    printf "%s <TEST_CONFIG_FILE>\n" "$(basename ${0})"
    exit 1
fi

directory="$(dirname ${1})"
testconfig="$(basename ${1})"
shift

cd "${directory}"
{
    read command
    printf "%s: Start testing '%s'\n" $(date +%T) "${command}"
    while read inputfile expectedErrorcode empty ; do
        if [[ ${inputfile} == '' || ${empty} != '' ]] ; then
            printf "There was a malformed line in %s\n" "${testconfig}"
            exit 1
        fi
        if [[ ${expectedErrorcode} -lt 0 || ${expectedErrorcode} -gt 255 ]] ; then
            printf "An expected error code of %d is not allowed\n" ${expectedErrorcode}
            exit 1
        fi
        printf "%s: Going to test with %s\n" $(date +%T) "${inputfile}"
        testError=n
        set +o errexit
        ${command} <"${inputfile}"_in.txt \
            >"${inputfile}"_out.log 2>"${inputfile}"_err.log
        gotErrorcode="${?}"
        set -o errexit
        if [[ ${gotErrorcode} -ne ${expectedErrorcode} ]] ; then
            printf "%s: ERROR: Got errorcode %d instead of %d\n" \
                $(date +%T) ${gotErrorcode} ${expectedErrorcode}
            testError=y
            wrongErrorCodes+=1
        fi
        if ! diff "${inputfile}"_out.txt "${inputfile}"_out.log >/dev/null ; then
            printf "%s: ERROR: stdout is not as expected\n" $(date +%T)
            testError=y
            wrongStdouts+=1
        fi
        if ! diff "${inputfile}"_err.txt "${inputfile}"_err.log >/dev/null ; then
            printf "%s: ERROR: stderr is not as expected\n" $(date +%T)
            testError=y
            wrongStderrs+=1
        fi
        if [[ ${testError} == y ]] ; then
            wrongTests+=1
        fi
    done
} <"${testconfig}"
if [[ ${wrongTests} -eq 0 ]] ; then
    printf "%s: Tests succesfull\n" $(date +%T)
else
    printf "%s: Not all tests were succesfull\n" $(date +%T)
    printf "%10sWrong tests:     %d\n" "" ${wrongTests}
    printf "%10sWrong errorcode: %d\n" "" ${wrongErrorCodes}
    printf "%10sWrong stdout:    %d\n" "" ${wrongStdouts}
    printf "%10sWrong stderr:    %d\n" "" ${wrongStderrs}
fi
