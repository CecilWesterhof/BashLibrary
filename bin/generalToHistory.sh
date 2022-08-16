#!/usr/bin/env bash

<<'###BLOCK-COMMENT'
This program moves data that is 'to old' from the tables in _tables
from general.sqlite to generalHistory.sqlite.

After this data that is 'to old' in partitionUsage is thined out.
Having only the first day of the month is good enough.

Lastly the unused space in general.sqlite is reclaimed


Possible improvements:
- When the is no data for the first day of the month after the
  thin out there is no data for that month
###BLOCK-COMMENT


# I want to exit on an error and an unset variable is an error
set -o errexit
set -o nounset


function deinit {
    sqlite3 ${_current} VACUUM
}

function init {
    readonly _current=~/Databases/general.sqlite
    readonly _history=~/Databases/generalHistory.sqlite
    readonly _tables=(
        DirectoryUsage
        InternetConnections
        messages
        vmstat
    )
    readonly _tables
    readonly _where="WHERE date < '2022-'" # Change to the correct year
}

function tableToHistory {
    local _table=$1

    currentSchema=$(sqlite3 ${_current} ".schema ${_table}")
    historySchema=$(sqlite3 ${_history} ".schema ${_table}")
    if [[ ${currentSchema} != ${historySchema} ]] ; then
        echo "Schemas are different for table ${_table}"
        exit 1
    fi
    echo "Old data from ${_table} to history"
    sqlite3 ${_history}                     \
    "ATTACH '${_current}' AS cur"           \
    "BEGIN TRANSACTION"                     \
    "INSERT INTO main.${_table}
     SELECT * FROM cur.${_table} ${_where}" \
    "DELETE   FROM cur.${_table} ${_where}" \
    "COMMIT TRANSACTION"                    \
    "DETACH cur"
}

function thinOut {
    local _table=partitionUsage

    echo "Thining out ${_table}"
    sqlite3 ${_current} "
        DELETE
        FROM   ${_table}
        ${_where} AND Date NOT LIKE '%-01'
    "
}


init
for table in "${_tables[@]}"; do
    tableToHistory ${table}
done
thinOut
deinit
