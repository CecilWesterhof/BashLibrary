#!/usr/bin/env bash

# Take care of the possibility that the Bash library is not installed
declare -r BASH_LIB=/usr/local/bash/BASHInitialisation.sh
if [ -f "${BASH_LIB}" -a -r "${BASH_LIB}" ] ; then
    source "${BASH_LIB}"
else
    printf "No Bash library\n"
    function fatal {
        echo ${1}
        exit 1
    }
fi

set -o errexit
set -o nounset

declare    ONLY_OUTPUT="N"
declare    OVERWRITE="N"
declare    RAW_OUTPUT="N"
declare    RUN_OFTEN="N"
declare -r SCRIPT_NAME="${0##*/}"
declare -r USAGE="${SCRIPT_NAME} [--only-output] [--overwrite] [--raw-output] [--run-often] <DATABASE>"

if [[ "${#}" -ge 1 ]] && [[ "${1}" == '--only-output' ]]; then
    ONLY_OUTPUT="T" ; shift
fi
readonly ONLY_OUTPUT
if [[ "${#}" -ge 1 ]] && [[ "${1}" == '--overwrite' ]]; then
    OVERWRITE="T" ; shift
fi
readonly OVERWRITE
if [[ "${#}" -ge 1 ]] && [[ "${1}" == '--raw-output' ]]; then
    RAW_OUTPUT="T" ; shift
fi
readonly RAW_OUTPUT
if [[ "${#}" -ge 1 ]] && [[ "${1}" == '--run-often' ]]; then
    RUN_OFTEN="T" ; shift
fi
readonly RUN_OFTEN
if [[ "${#}" -ne 1 ]] ; then
    fatal "${USAGE}"
    return
fi

declare -i length
declare    name
declare -i tmpLen

declare -r DATABASE="${1}" ; shift
if [[ "${RUN_OFTEN}" == "T" ]] ; then
    declare -r DATE=$(date +%F_%T)
else
    declare -r DATE=$(date +%F)
fi
declare -r DELETE_SAVED="
    DELETE FROM directoryUsage
    WHERE date = '${DATE}'
    ;
    DELETE FROM partitionUsage
    WHERE date = '${DATE}'
    ;
"
declare -r DIR_INSERT="
    INSERT INTO directoryUsage
    (date, directory, used)
    VALUES
    ('%s', '%s', '%s')
    ;
"
declare -r DIR_SELECT="SELECT value FROM variables WHERE name = 'directories';"
declare -r DIRS=$(sqlite3 ${DATABASE} <<<${DIR_SELECT})
length=4
for name in ${DIRS} ; do
    tempLen=${#name}
    if [[ ${tempLen} -gt ${length} ]] ; then
        length=tempLen
    fi
done
declare -r DIR_OUTPUT="%-${length}s %4s\n"
echo $DIR_OUTPUT
if [[ "${RAW_OUTPUT}" == "T" ]] ; then
    declare -r OUTPUT_TYPE="-k"
else
    declare -r OUTPUT_TYPE="-h"
fi
declare -r PART_INSERT="
    INSERT INTO partitionUsage
    (date, partition, size, used, available, percentUsed)
    VALUES
    ('%s', '%s', '%s', '%s', '%s', '%s')
    ;
"
declare -r PART_SELECT="SELECT value FROM variables where name = 'partitions';"
declare -r PARTITIONS="$(sqlite3 ${DATABASE} <<<${PART_SELECT})"
length=4
for name in ${PARTITIONS} ; do
    tempLen=${#name}
    if [[ ${tempLen} -gt ${length} ]] ; then
        length=tempLen
    fi
done
declare -r PART_OUTPUT="%-${length}s %4s %4s %4s %4s\n"
echo $PART_OUTPUT
# This looks eleborate, but maybe nothing is saved for one of the two
# so I need to check both
declare -r WAS_ALREADY_SAVED="
    SELECT date
    FROM   directoryUsage
    WHERE  date = '${DATE}'
    UNION
    SELECT date
    FROM   partitionUsage
    WHERE  date = '${DATE}'
    ;
"

declare available
declare directory
declare filesystem
declare isSaved
declare line
declare partition
declare percentUsed
declare size
declare used


# Check the database is not locked
# Temporaly disable exit on error
set +o errexit
sqlite3 "${DATABASE}" "begin immediate" 2>/dev/null
errorCode="${?}"
# Enable exit on error again
set -o errexit
# The value 5 signifies that the database is locked
if [[ "${errorCode}" -eq 5 ]] ; then
    fatal "${DATABASE} is locked"
# There is another problem
elif [[ "${errorCode}" -ne 0 ]] ; then
    fatal "Error ${errorCode} while accessing ${DATABASE}\n"
fi
if [[ "${ONLY_OUTPUT}" != "T" ]] ; then
    if [[ "${OVERWRITE}" == "T" ]] ; then
        sqlite3 "${DATABASE}" "${DELETE_SAVED}"
    else
        isSaved=$(sqlite3 "${DATABASE}" "${WAS_ALREADY_SAVED}")
        if [[ "${isSaved}" != "" ]] ; then
            printf "There is already data for %s.\nQuiting\n" "${DATE}"
            exit
        fi
    fi
fi


while read used directory ; do
    printf "${DIR_OUTPUT}"           "${directory}" "${used}"
    if [[ "${ONLY_OUTPUT}" != "T" ]] ; then
        printf "${DIR_INSERT}" "${DATE}" "${directory}" "${used}" | \
            sqlite3 "${DATABASE}"
    fi
done < <(du -hs ${DIRS})

echo

{
    read line
    while read filesystem size used available percentUsed partition ; do
        printf                                  \
            "${PART_OUTPUT}"                    \
            "${partition}"                      \
            "${size}" "${used}" "${available}"  \
            "${percentUsed}"
        if [[ "${ONLY_OUTPUT}" != "T" ]] ; then
            printf                                  \
                "${PART_INSERT}"                    \
                "${DATE}"                           \
                "${partition}"                      \
                "${size}" "${used}" "${available}"  \
                "${percentUsed}"                    | sqlite3 "${DATABASE}"
        fi
    done
} < <(df "${OUTPUT_TYPE}" ${PARTITIONS})
