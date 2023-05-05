# Functions:
# - addToPath
# - calc
# - canRun
# - chall
# - cdll
# - checkInteger
# - checkNetworkInterface
# - checkReadableDirectory
# - checkReadOnlyVariables
# - cleanPath
# - commandExists
# - convertInput
# - defaultPS_OPTIONS
# - elementInList
# - fatal
# - filterCommand
# - getCPUTemperature
# - getOptionValue
# - getPathDirs
# - isInteger
# - isInteractive
# - isVarSet
# - loadXmodmapExtra
# - logDRY
# - logError
# - logMsg
# - nrOfDirs
# - nrOfFiles
# - nrOfFilesAndDirs
# - psCommand
# - psGrep
# - psPid
# - psPpid
# - psStatus
# - psUser
# - removeFromPath
# - screent
# - showMessage
# - stackTrace
# - stripLeadingZeros
# - taggedMsg
# - taggedMsgAndStackTrace
# - valueInArray
# - variableExist
# - warning

# Variables:
# - STACK_TRACE_DEPTH

# Comments:
# I prefer long parameters. If you can not use long parameters, you need to use
# the following substitutions:
#
# grep:
# - --extended-grep  -E
# - --max-count=1    -m 1
# - --only-matching  -o

################################################################################
# Functions                                                                    #
################################################################################

# Usage: AddToPath [--start|--end] [--no-reorder] <DIRECTORY_TO_ADD>
# Adds a directory to PATH
# Default to the front, but can also be on the end
# Default at the the old place the directory is deleted,
# but with --no-reorder PATH will not be changed if it already contains the directory.
# Needed:
# - BASH functions
#  - fatal
function addToPath {
    declare -r USAGE="USAGE: ${FUNCNAME} [--start|--end] [--no-reorder] <DIRECTORY_TO_ADD>"

    declare    ALWAYS_SET=y
    declare    START=y
    declare    ADD_DIR

    declare    dir
    declare    path=""

    if [[ ${#} -ge 1 ]] ; then
        if [[ ${1} == --start ]] ; then
            START=y ; shift
        elif [[ ${1} == --end ]] ; then
            START=n ; shift
        fi
    fi
    readonly START
    if [[ ${#} -ge 1 && ${1} == --no-reorder ]] ; then
        ALWAYS_SET=n ; shift
    fi
    readonly ALWAYS_SET
    if [[ ${#} -ne 1 ]] ; then
        fatal "${USAGE}"
        return
    fi
    ADD_DIR="${1}" ; shift

    while read dir ; do
        if [[ ${dir} == ${ADD_DIR} ]] ; then
            if [[ ${ALWAYS_SET} == y ]] ; then
                continue
            fi
            return
        fi
        path+="${dir}:"
    done < <(getPathDirs)
    if [[ ${START} == y ]] ; then
        path="${ADD_DIR}:${path}"
    else
        path="${path}${ADD_DIR}:"
    fi
    PATH="${path:0:-1}"
}

# Usage: calc <EXPRESSION>
# Gives an expression to be evaluated to bc
# Needed:
# - BASH functions
#  - fatal
function calc {
  if [[ ${#} -lt 1 ]] ; then
    fatal "${FUNCNAME} needs an expression"
    return
  fi

  printf "${@}\n" | bc
}

# Usage: canRun <LOCK-FILE>
# Often you want to be sure something is only run one time at the time
# This function tries to get a semaphore and report the status
# Needed:
# - BASH functions
#  - fatal
function canRun {
  declare LOCK_FILE

  if [[ ${#} -ne 1 ]] ; then
    fatal "${FUNCNAME} <LOCK-FILE>"
    return
  fi
  LOCK_FILE=${1}; shift

  (set -o noclobber; :>${LOCK_FILE}) &>/dev/null || return 1
  return 0
}

# Usage:   chall [-R] mode own:group <file/dir>
# Example: chall -R a=rx root:sys /usr/data"
# Based on a script of Everhard Faas
# Combined chown en chmod, an idea of Rolf Sonneveld
# Needed:
# - BASH functions
#  - fatal
function chall {
    declare mod
    declare opts=''
    declare own

    if [[ ${#} -ge 1 ]] && [[ ${1} = "-R" ]] ; then
        opts=${1}; shift
    fi

    if [ ${#} -lt 3 ] ; then
        fatal "${FUNCNAME}: Error, not enough arguments
Usage: ${FUNCNAME} [-R] mode own:group <file/dir>
Example: ${FUNCNAME} -R a=rx root:sys /usr/data"
        return
    fi

    mod=${1}; own=${2}; shift 2

    chmod ${opts} ${mod} ${*}
    chown ${opts} ${own} ${*}
}

# Usage: cdll <DIRECTORY>
# cd and ls -l combined
# Needed:
# - BASH functions
#  - fatal
function cdll {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <DIRECTORY>"
        return
    fi

    cd ${1} ; shift
    ls -l
}

# Usage: checkInteger  <VALUE_TO_CHECK>
# A fatal error when parameter is NOT an integer
# Needed:
# - BASH functions
#  - fatal
#  - isInteger
function checkInteger {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <VALUE_TO_CHECK>"
        return
    fi
    if ! isInteger ${1} ; then
        fatal "'${1}' is not an integer"
        return
    fi
}

# Usage: checkNetworkInterface [<INTERFACE>]
# Shows if errors, dropped or overruns of the specified interface
# are unequal zero
# When no interface is given, check all interfaces
# Needed:
# - BASH functions
#  - fatal
function checkNetworkInterface {
    if [[ "$#" -gt "1" ]] ; then
        fatal "${FUNCNAME} [<INTERFACE>]"
        return
    fi
    if [[ "$#" -eq "1" ]] ; then
        declare -r INTERFACE=${1}; shift
    else
        declare -r INTERFACE=""
    fi

    /sbin/ifconfig ${INTERFACE} | grep '\(errors\|dropped\|overruns\):[^0]'
}

# Usage: checkReadableDirectory <CALLING_FN> [<DIRECTORY>]
# Checks if DIRECTORY is readable
# First parameter is the calling function which is used in the error messages
# If no directory is given the current directory is used
# Needed:
# - BASH functions
#  - fatal
function checkReadableDirectory {
    if [[ $# -lt 1 ]] ; then
        fatal "${FUNCNAME} needs at least the name of the calling function"
        return
    fi
    declare -r CALLING_FN="${1}" ; shift
    declare -r USAGE="USAGE: ${CALLING_FN} [DIRECTORY]"

    declare    dir

    if   [[ ${#} -eq 0 ]] ; then
        dir=.
    elif [[ ${#} -eq 1 ]] ; then
        dir="${1}"
    else
        fatal "${USAGE}"
        return
    fi
    if [[ ! -d ${dir} ]] ; then
        # It is not a directory or not reachable (/root/bin)
        fatal "${CALLING_FN}: ${dir} is not a (reachable) directory"
        return
    fi
    if [[ ! -r ${dir} ]] ; then
        fatal "${CALLING_FN}: ${dir} is not readable"
        return
    fi
    echo ${dir}
}

# Usage: checkReadOnlyVariables <VARS_TO_CHECK>
# Checks if at least one of the given variables is read only
# Needed:
# - BASH functions
#  - fatal
function checkReadOnlyVariables {
    if [[ "$#" -ne "1" ]] ; then
        fatal "${FUNCNAME} <VARS_TO_CHECK>"
        return
    fi
    declare -r VARS_TO_CHECK=${1}; shift

    readonly | awk -v variableNames=${VARS_TO_CHECK} '
        BEGIN {
            returnCode = 0;
            split(variableNames, variableArray, "#");
        }

        END {
            exit returnCode
        }

        {
            for(i in variableArray) {
                variableName = variableArray[i];
                temp = "^" variableName "=";
                if( match($3, temp ) ) {
                    print "ERROR: " variableName " defined as read only"
                    returnCode = 1;
                }
            }
        }
  '
}

# Usage: cleanPath
# Makes sure that directories are not more as once in PATH
# Needed:
# - Bash 4 because it uses associative arrays
# - BASH functions
#  - fatal
function cleanPath {
    declare -r USAGE="USAGE: ${FUNCNAME}"

    declare    dir
    declare -A found
    declare    path

    if [[ ${#} -ne 0 ]] ; then
        fatal "${USAGE}"
        return
    fi

    while read dir ; do
        if [[ ${found[$dir]} ]] ; then
            continue
        fi
        path+="${dir}:"
        found["${dir}"]=1
    done < <(getPathDirs)
    PATH="${path:0:-1}"
}

# Usage: commandExists: commandExists <COMMAND_TO_CHECK>
# Checks if a command exist
# Needed:
# - BASH functions
#  - fatal
function commandExists {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <COMMAND_TO_CHECK>"
        return
    fi
    declare -r COMMAND_TO_CHECK=${1}; shift

    type "${COMMAND_TO_CHECK}" &> /dev/null
}

# Usage: convertInput <INPUT_TO_CONVER>
# Sometimes you have to compare an input to certain values.
# But for example you want YES, Yes and yes have the same meaning.
# This function removes leading and tailing whitespace
# and converts the rest to lowercase.
# Needed: nothing
function convertInput {
    local converted

    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <COMMAND_TO_CHECK>"
        return
    fi

    read converted <<EOT
${1,,}
EOT
    printf "${converted}\n"
}

# Usage: defaultPS_OPTIONS
# Sets PS_OPTIONS to its default value
# Needed:
# - BASH functions
#   - fatal
function defaultPS_OPTIONS {
    if [[ ${#} -ne 0 ]] ; then
        fatal "${FUNCNAME} has no parameters"
        return
    fi

    PS_OPTIONS='ax --columns 200 -o user,pid,ppid,tty,start_time,etime,time,stat,args'
}

# Usage: elementInList <ELEMENT> <LIST OF ELEMENTS>
# Checks if element is contained in the list
# Needed:
# - BASH functions
#  - fatal
function elementInList {
    if [[ ${#} -lt 2 ]] ; then
        fatal "${FUNCNAME} <ELEMENT> <LIST OF ELEMENTS>"
        return
    fi

    local -r ELEMENT=${1}; shift

    local thisElement

    while [[ ${#} -gt 0 ]] ; do
        thisElement=${1}; shift
        if [[ ${thisElement} == ${ELEMENT} ]] ; then
            return 0
        fi
    done
    return 1
}

# Usage: fatal [<tag> [<message]]
# Used when something has gone fatally wrong. Gives a tagged message and stacktrace.
# When in a script: exit the script. When interactive just return.
# Needed:
# - BASH functions:
#   - stackTrace
#   - taggedMsg
function fatal {
    taggedMsgAndStackTrace "FATAL" "$@"
    case ${-} in
        *i*) # interactive shell
            return 1
            ;;
        *) # non-interactive shell
            exit 1
            ;;
    esac
}

# Usage: filterCommand [--field FIELD_NO] <COMMAND> <FILTER>
# Filter the output from <COMMAND> on <Filter>. When given a field,
# only filter on that field.
# Needed:
# - BASH function
#   - fatal
function filterCommand {
  declare    command
  declare -i field
  declare    match

  if [[ ${#} -ge 2 ]] && [[ ${1} == '--field' ]]; then
    field=${2}; shift 2
    if [[ ${field} -lt 1 ]]; then
      fatal "${FUNCNAME} field has to be 1 or higher"
      return
    fi
  else
    field=0
  fi
  if [[ ${#} -ne 2 ]] ; then
    fatal "${FUNCNAME} [--field FIELD_NO] <COMMAND> <FILTER>"
    return
  fi
  command="${1}"; match="${2}"; shift 2

  eval ${command} | awk '{
    if( NR == 1 ) {
      print $0;
    } else if( match($'${field}', "'${match}'") ) {
      print $0;
    }
  }'
}

# Usage: getCPUTemperature
# Get the temperature of the processor
# Needed:
# - BASH function
#   - fatal
# - External function
#   - acpi
function getCPUTemperature {
    if [[ ${#} -ne 0 ]] ; then
        fatal "${FUNCNAME} does not take parameters"
        return
    fi

    acpi -t | awk '{ print $4 }'
}

# Usage: getOptionValue <OPTION>
# Get the value of option <OPTION>
# Needed
# - BASH function
#   - fatal
function getOptionValue {
    declare OPTION

    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <OPTION>"
        return
    fi
    OPTION=${1}; shift

    set -o | awk '/^'"${OPTION} "'/ {print $2; exit; }'
}

# Usage: getPathDirs
# Displays all directories that are searched for entered commands
# Needed:
# - BASH functions
#  - fatal
function getPathDirs {
    declare -r OLD_IFS="${IFS}"
    declare -r USAGE="USAGE: ${FUNCNAME}"

    if [[ ${#} -ne 0 ]] ; then
        fatal "${USAGE}"
        return
    fi

    IFS=':'
    set -- ${PATH}
    IFS="${OLD_IFS}"
    while [[ "${#}" -gt 0 ]] ; do
        printf "${1}\n" ; shift
    done
}

# Usage: getRSSAndSwap PID
# Displays VmRSS and VmSwap of the proces with process id PID
# Needed:
# - BASH functions
#  - fatal
function getRSSAndSwap {
    declare -r USAGE="USAGE: ${FUNCNAME} PID"

    if [[ ${#} -ne 1 ]] ; then
        fatal "${USAGE}"
        return
    fi
    grep --extended-regexp 'VmRSS|VmSwap' "/proc/${1}/status"
}


# Usage: isInteger  <VALUE_TO_CHECK>
# Returns if parameter is an integer
# Needed:
# - BASH functions
#  - fatal
function isInteger {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <VALUE_TO_CHECK>"
        return
    fi
    [[ "$1" =~ ^[[:digit:]]+$ ]]
}

# Usage: isInteractive
# Interactive shell or not?
# Needed:
# - BASH function
#   - fatal
function isInteractive {
    if [[ ${#} -ne 0 ]] ; then
        fatal "${FUNCNAME} does not take parameters"
        return
    fi

    if [ -t 0 ] ; then
        return 0
    else
        return 1
    fi
}

# Usage: isVarSet <VARIABLE-NAME>
# Check if a variable is set.
# Needed
# - BASH function
#   - fatal
function isVarSet {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <VARIABLE-NAME>"
        return
    fi

    declare -p ${1} &>/dev/null
    return
}

# Usage: loadXmodmapExtra
# Sets extra xmodmap values
# Needed:
# - BASH functions
#   - fatal
function loadXmodmapExtra {
    if [[ ${#} -ne 0 ]] ; then
        fatal "${FUNCNAME} has no parameters"
        return
    fi

    local -r XMODMAP_EXTRA=/usr/local/bash/XModmap.extra

    if isReadableFile ${XMODMAP_EXTRA} ; then
        xmodmap ${XMODMAP_EXTRA}
    else
        printf "The file ${XMODMAP_EXTRA} cannot be read\n"
    fi
}

# This function should never be called directly.
# It is an internal function which is called by logError and logMsg.
# logError logs to stderr and logMsg to stdout
# Prints a message prepended with the following information:
# - Date and time
# - Filename with line number
# - Function from which it is called
# When the first parameter is --simple only date and time are prepended
function logDRY {
    if [[ ${#} -ge 1 ]] && [[ ${1} == "--simple" ]] ; then
        declare -r SIMPLE="true"; shift
    else
        declare -r SIMPLE="false"
    fi
    declare message="${@}"

    if [[ ${SIMPLE} == "true" ]] ; then
        printf "$(date +%F_%T): ${message}\n"
    else
        callAr=($(caller 1))
        lineNo=${callAr[0]}
        fnName=${callAr[1]-noFunction}
        fileName=${callAr[2]-noFile}
        printf "$(date +%F_%T):${fileName}(${lineNo}):${fnName}: ${message}\n"
    fi
}

# Usage: logError [--simple]
# Log to stderr, see logDRY
# Needed:
# - BASH functions
#   - logDRY
function logError {
    if [[ ${#} -ge 1 ]] && [[ ${1} == "--simple" ]] ; then
        declare -r PARAMS="--simple"; shift
    else
        declare -r PARAMS=""
    fi

    logDRY ${PARAMS} "${@}" >&2
}

# Usage: logMsg [--simple]
# Log to stdout, see logDRY
# Needed:
# - BASH functions
#   - logDRY
function logMsg {
    if [[ ${#} -ge 1 ]] && [[ ${1} == "--simple" ]] ; then
        declare -r PARAMS="--simple"; shift
    else
        declare -r PARAMS=""
    fi

    logDRY ${PARAMS} "${@}"
}

# Usage: nrOfDirs [<DIRECTORY>]
# Gives nr of directories in DIRECTORY, default current directory
# If DIRECTORY is not a readable directory give an error
# Needed:
# - BASH functions
#   - checkReadableDirectory
function nrOfDirs {
    dir=$(checkReadableDirectory ${FUNCNAME} "$@") || return
    find "${dir}" -maxdepth 1 -type d | echo $(($(wc -l) - 1 ))
}

# Usage: nrOfFiles [<DIRECTORY>]
# Gives nr of files in DIRECTORY, default current directory
# If DIRECTORY is not a readable directory give an error
# Needed:
# - BASH functions
#   - checkReadableDirectory
function nrOfFiles {
    dir=$(checkReadableDirectory ${FUNCNAME} "$@") || return
    find "${dir}" -maxdepth 1 -type f | wc -l
}

# Usage: nrOfFilesAndDirs [<DIRECTORY>]
# Gives nr of files and directories in DIRECTORY, default current directory
# If DIRECTORY is not a readable directory give an error
# Needed:
# - BASH functions
#   - checkReadableDirectory
#   - nrOfDirs
#   - nrofFiles
function nrOfFilesAndDirs {
    dir=$(checkReadableDirectory ${FUNCNAME} "$@") || return
    echo $(($(nrOfFiles ${dir}) + $(nrOfDirs ${dir})))
}

# Usage: psCommand <COMMAND>
# Get information about running commands that contain <COMMAND>.
# Needed
# - BASH function
#   - fatal
#   - filterCommand
# - BASH variable
#   - PS_OPTIONS
function psCommand {
    declare COMMAND

    if [[ ${#} -ne 1 ]]; then
        fatal "${FUNCNAME} <COMMAND>"
        return
    fi
    COMMAND=${1}; shift

    filterCommand --field 9 "ps ${PS_OPTIONS}" "${COMMAND}"
}

# Usage: psGrep <SEARCH_STRING>
# Filter ps with <SEARCH_STRING>
# Needed
# - BASH function
#   - fatal
#   - filterCommand
# - BASH variable
#   - PS_OPTIONS
function psGrep {
    declare SEARCH_STRING

    if [[ ${#} -ne 1 ]]; then
        fatal "${FUNCNAME} <SEARCH_STRING>"
        return
    fi
    SEARCH_STRING=${1}; shift

    filterCommand "ps ${PS_OPTIONS}" "[${SEARCH_STRING:0:1}]${SEARCH_STRING:1}"
}

# Usage: psPid <PID>
# Filter ps with <PID>
# Needed
# - BASH function
#   - fatal
#   - filterCommand
# - BASH variable
#   - PS_OPTIONS
function psPid {
    declare PID

    if [[ ${#} -ne 1 ]]; then
        fatal "${FUNCNAME} <PID>"
        return
    fi
    PID=${1}; shift

    filterCommand --field 2 "ps ${PS_OPTIONS}" "^${PID}\$"
}

# Usage: psPpid <PPID>
# Filter ps with <PPID>
# Needed
# - BASH function
#   - fatal
#   - filterCommand
# - BASH variable
#   - PS_OPTIONS
function psPpid {
    declare -i ppid                                                            # to get rid of space

    if [[ ${#} -ne 1 ]]; then
        fatal "${FUNCNAME} <PPID>"
        return
    fi
    ppid=$(ps --no-headers -p "${1}" -o ppid); shift

    psPid "${ppid}"
}

# Usage statusCode [<STATUS_CODE>]
# Filter ps on a status code. Default ‘D’ (uninterruptible sleep).
# Needed
# - BASH function
#   - fatal
#   - filterCommand
# - BASH variable
#   - PS_OPTIONS
function psStatus {
    declare statusCode

    if [[ ${#} -gt 1 ]] ; then
        fatal "${FUNCNAME} [<STATUS_CODE>]"
        return
    fi
    if [[ ${#} -eq 1 ]]; then
        statusCode=${1}; shift
    else
        statusCode="D"
    fi

    filterCommand --field 8 "ps ${PS_OPTIONS}" "${statusCode}"
}

# Usage: psUser <USER>
# Filter ps on users containing <USER>.
# Needed
# - BASH function
#   - fatal
#   - filterCommand
# - BASH variable
#   - PS_OPTIONS
function psUser {
    declare USER

    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <USER>"
        return
    fi
    USER=${1}; shift

    filterCommand --field 1 "ps ${PS_OPTIONS}" "${USER}"
}

# Usage: removeFromPath <DIRECTORY_TO_REMOVE>
# Removes a directory from PATH
# Needed:
# - BASH functions
#  - fatal
function removeFromPath {
    declare -r USAGE="USAGE: ${FUNCNAME} <DIRECTORY_TO_REMOVE>"

    declare    REMOVE_DIR

    declare    dir
    declare    path=""

    if [[ ${#} -ne 1 ]] ; then
        fatal "${USAGE}"
        return
    fi
    REMOVE_DIR="${1}" ; shift
    readonly REMOVE_DIR

    while read dir ; do
        if [[ ${dir} == ${REMOVE_DIR} ]] ; then
            continue
        fi
        path+="${dir}:"
    done < <(getPathDirs)
    PATH="${path:0:-1}"
}

# Usage: screent <USER>
# Starts a screen session as <USER>. Also sets the title.
# Needed
# - External programs
#   screen
function screent {
    declare THIS_USER

    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <USER>"
        return
    fi
    THIS_USER=${1}; shift

    screen -t ${THIS_USER} su - ${THIS_USER}
}

# Usage: showMessage <SHOW_MESSAGE> <MESSAGE>
# If SHOW_MESSAGE = y print MESSAGE prepended with current time
# Needed
# - BASH functions
#  - fatal
function showMessage {
  if [[ ${#} -ne 2 ]] ; then
    fatal "${FUNCNAME} <SHOW_MESSAGE> <MESSAGE>"
    return
  fi

  local -r SHOW_MESSAGE="${1}"; shift
  local -r MESSAGE="${1}"; shift

  if [[ ${SHOW_MESSAGE} == y ]] ; then
    printf "%s: %s\n" "$(date +%F_%T)" "${MESSAGE}"
  fi
}

# Usage: stackTrace [<DEPTH>]
# Generates a stacktrace. Strart at <DEPTH> if given, otherwise at the top.
# Needed
# - BASH variables
#   - STACK_TRACE_DEPTH
function stackTrace {
    declare    callAr
    declare -i depth
    declare    fileName
    declare    fnName
    declare    lineNo

    case ${-} in
        *i*) # interactive shell: check for stackTrace
            if [[ ${INTERACTIVE_STACK_TRACE} != yes ]] ; then
                return
            fi
            ;;
        *) # non-interactive shell
            ;;
    esac
    if [[ ${#} -ne 0 ]]; then
        depth=${1}; shift
    else
        depth=0
    fi
    while [[ ${depth} -le ${STACK_TRACE_DEPTH} ]]; do
        callAr=($(caller ${depth}))
        lineNo=${callAr[0]}
        fnName=${callAr[1]-noFunction}
        fileName=${callAr[2]-noFile}
        if [[ ${fnName} == "noFunction" ]]; then
            break;
        fi
        printf "called from: ${fileName}:${lineNo} in ${fnName}\n" >&2
        depth+=1
    done
}

# Usage: stripLeadingZeros <STRING_TO_STRIP>
# Strip leading zeros of a string, but leave it otherwise intact.
# Needed
# - BASH function
#   - fatal
function stripLeadingZeros {
  if [[ ${#} != 1 ]] ; then
    fatal "${FUNCNAME} <STRING_TO_STRIP>"
    return
  fi
  toStrip=${1}; shift

  if [[ ${toStrip:0:1} != '0' ]]; then
    printf "${toStrip}\n"
    return
  fi
  printf "${toStrip}" | awk '
    {
      sub("^0*", "");
      if( $0 == "" || substr($0, 1, 1) < "0" || substr($0, 1, 1) > "9" ) {
        $0 = "0"$0
      }
      print $0;
    }
  '
}

# Usage: taggedMsg [<TAG> [<MESSAGE>]]
# Used to give a debug message.
# With no parameters it just shows an untagged message.
# You can give a tag to define the type of message and a message to show.
# It shows the filename with linenummer and function name from which its
# calling function is called.
# function with error → fatal/warning → taggedMsgAndStackTrace -> taggedMsg
# Not very useful interactive.
# Needed: nothing
function taggedMsg {
    declare -r DCBL_OLD_IFS=${IFS}

    declare callAr
    declare fileName
    declare lineNo
    declare message
    declare fnName
    declare TAG

    TAG="<untagged>"
    if [[ ${#} -ne 0 ]]; then
        TAG=${1}; shift
    fi
    message="${@}"
    callAr=($(caller 2))
    echo ${callAr[*]}
    lineNo=${callAr[0]-noLine}
    fnName=${callAr[1]-noFunction}
    fileName=${callAr[2]-noFile}
    printf "${TAG}: ${fileName}:${lineNo} in ${fnName}\n" >&2
    IFS=$'\n'
    set -- ${message}
    while [[ ${#} -ge 1 ]]; do
        printf "\t${1}\n" >&2 ; shift
    done
    IFS=${DCBL_OLD_IFS}
}

function taggedMsgAndStackTrace {
    local tag=''
    if [[ ${#} -ge 1 ]] ; then
        tag=${1} ; shift
    fi
    taggedMsg "${tag}" "$@"
    stackTrace 3
}

# Usage: valueInArray <value> <array-values>
# Example: valueInArray 12 ${thisArray[*]}
# Checks if <value> is contained in <array-values>
# Needed
# - BASH function
#   - fatal
function valueInArray {
  declare ARRAY
  declare thisValue
  declare VALUE

  if [[ ${#} -lt 1 ]] ; then
    fatal "${FUNCNAME} <value> <array-values>"
    return
  fi
  VALUE=${1}; shift
  ARRAY=( "$@" )

  for thisValue in ${ARRAY[@]}; do
    if [[ ${thisValue} == ${VALUE} ]] ; then
      printf "true\n"
      return
    fi
  done
  printf "false\n"
}

# Usage: variableExist [--non-fatal] <VARIABLE_NAME>
# Checks if a variable is defined
# If --non-fatal not defined of variable is not fatal
# Needed
# - BASH function
#   - fatal
function variableExist {
  declare callAr
  declare error
  declare function
  declare IS_FATAL
  declare VAR_NAME


  if [[ ${#} -ge 1 ]] && [[ ${1} == '--non-fatal' ]]; then
    IS_FATAL="false"; shift
  else
    IS_FATAL="true"
  fi
  if [[ ${#} -ne 1 ]] ; then
    fatal "${FUNCNAME} [--non-fatal] <VARIABLE_NAME>"
    return
  fi
  VAR_NAME=${1}; shift

  error=$((set -u; : $(eval echo '${'"${VAR_NAME}"'}')) 2>&1)
  if [[ ${error} == '' ]]; then
    return 0
  fi
  if [[ "${IS_FATAL}" != "false" ]]; then
    callAr=($(caller 0))
    function=${callAr[1]}
    fatal "${function} needs ${VAR_NAME} to be defined"
    return
  fi
  return 1
}

# Usage: warning [<tag> [<message]]
# Used to give a warning. Gives a tagged message and stacktrace.
# Needed:
# - BASH functions:
#   - stackTrace
#   - taggedMsg
function warning {
    taggedMsgAndStackTrace "WARNING" "$@"
}

################################################################################
# Includes                                                                     #
################################################################################
includeDir=/usr/local/bash
source ${includeDir}/disk.sh
source ${includeDir}/network.sh
source ${includeDir}/random.sh
source ${includeDir}/system.sh
source ${includeDir}/systemd.sh
source ${includeDir}/time.sh
includeFile --notNeeded ${includeDir}/BASHExtra.sh
# includes for interactive shell
if isInteractive ; then
    includeFile --notNeeded ${includeDir}/alias
fi
unset includeDir

################################################################################
# initialisation                                                               #
################################################################################

# Only set variables if they are not already set.
if ! isVarSet PS_OPTIONS ; then
    defaultPS_OPTIONS
    export PS_OPTIONS
fi
if  ! isVarSet STACK_TRACE_DEPTH  ; then
    declare -i STACK_TRACE_DEPTH

    STACK_TRACE_DEPTH=10
    export STACK_TRACE_DEPTH
fi
if  ! isVarSet INTERACTIVE_STACK_TRACE  ; then
    declare INTERACTIVE_STACK_TRACE

    INTERACTIVE_STACK_TRACE=no
    export INTERACTIVE_STACK_TRACE
fi

# do things for interactive shell
# define +=, -= and ==
if isInteractive ; then
    # Usage: += [<DIRECTORY>]
    # Does a pushd for the given directory. Default current.
    # Needed
    # - BASH function
    #   - fatal
    function += {
        if [[ ${#} -gt 1 ]] ; then
            fatal "${FUNCNAME} [<DIRECTORY>]"
            return
        fi

        if [[ ${#} -eq 1 ]] ; then
            pushd ${1} ; shift
        else
            pushd .
        fi
    }

    # Usage: -=
    # Does a popd if the directory stack is not empty.
    # Needed
    # - BASH function
    #   - fatal
    function -= {
        if [[ ${#} -ne 0 ]] ; then
            fatal "${FUNCNAME} does not take parameters"
            return
        fi
        if [[ ${#DIRSTACK[@]} -le 1 ]] ; then
            fatal "Directory stack is empty"
            return
        fi

        popd
    }

    # Usage: ==
    # Shows the directory stack.
    # Needed
    # - BASH function
    #   - fatal
    function == {
        if [[ ${#} -ne 0 ]] ; then
            fatal "${FUNCNAME} does not take parameters"
            return
        fi

        dirs
    }
fi
