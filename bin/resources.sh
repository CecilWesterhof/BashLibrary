#!/usr/bin/env bash

source /usr/local/bash/BASHInitialisation.sh

set -o errexit
set -o nounset

declare -r  SCRIPT_NAME="${0##*/}"

if [[ ${#} -ne 1 ]] ; then
    fatal "${SCRIPT_NAME} <DATABASE>"
    return
fi


declare -r DATABASE="${1}" ; shift
declare -r DATE=$(date +%F)
declare -r DIR_INSERT="
    INSERT INTO directoryUsage
    (date, directory, used)
    VALUES
    ('%s', '%s', '%s')
    ;
"
declare -r DIR_OUTPUT="%-12s %4s\n"
declare -r DIR_SELECT="SELECT value FROM variables WHERE name = 'directories';"
declare -r DIRS=$(sqlite3 ${DATABASE} <<<${DIR_SELECT})
declare -r PART_INSERT="
    INSERT INTO partitionUsage
    (date, partition, size, used, available, percentUsed)
    VALUES
    ('%s', '%s', '%s', '%s', '%s', '%s')
    ;
"
declare -r PART_OUTPUT="%-8s %4s %4s %4s %4s\n"
declare -r PART_SELECT="SELECT value FROM variables where name = 'partitions';"
declare -r PARTITIONS="$(sqlite3 ${DATABASE} <<<${PART_SELECT})"

declare available
declare directory
declare line
declare partition
declare percentUsed
declare size
declare used


while read used directory ; do
    printf "${DIR_OUTPUT}"           "${directory}" "${used}"
    printf "${DIR_INSERT}" "${DATE}" "${directory}" "${used}" | \
        sqlite3 "${DATABASE}"
done < <(du -hs ${DIRS})

echo

{
    read line
    while read partition size used available percentUsed ; do
        printf                                  \
            "${PART_OUTPUT}"                    \
            "${partition}"                      \
            "${size}" "${used}" "${available}"  \
            "${percentUsed}"
        printf                                  \
            "${PART_INSERT}"                    \
            "${DATE}"                           \
            "${partition}"                      \
            "${size}" "${used}" "${available}"  \
            "${percentUsed}"                    | sqlite3 "${DATABASE}"
    done
} < <(df -h --output=target,size,used,avail,pcent ${PARTITIONS})
