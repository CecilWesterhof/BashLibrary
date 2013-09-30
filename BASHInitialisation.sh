# Functions:
# - calc
# - canRun
# - chall
# - cdll
# - checkReadOnlyVariables
# - commandExists
# - convertInput
# - default_PS_OPTIONS
# - elementInList
# - fatal
# - filterCommand
# - getIPs
# - getOptionValue
# - isInteractive
# - isVarSet
# - psCommand
# - psGrep
# - psStatus
# - psUser
# - screent
# - stackTrace
# - stripLeadingZeros
# - taggedMsg
# - valueInArray
# - variableExist

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
# Includes                                                                     #
################################################################################
pushd  /usr/local/bash 1>/dev/null
source disk.sh
source random.sh
source systemd.sh
source time.sh
popd   1>/dev/null

################################################################################
# Functions                                                                    #
################################################################################

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

    cd ${1}
    ls -l
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

  PS_OPTIONS='ax --columns 132 -o user,pid,ppid,start_time,tty,time,stat,args'
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
    taggedMsg "FATAL" "$@"
    stackTrace 1
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

# Usage: getIPs [--only-first]
# Get the ip-addresses of your system. With --only-first, only the first address.
# Needed
# - BASH function
#   - fatal
function getIPs {
    declare IDENTIFIER="inet addr:"
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

    filterCommand --field 8 "ps ${PS_OPTIONS}" "${COMMAND}"
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

    filterCommand --field 7 "ps ${PS_OPTIONS}" "${statusCode}"
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

# Usage: screent <USER>
# Starts a screen session as <USER>. Also sets the title.
# Needed
# - BASH variables
#   - STACK_TRACE_DEPTH
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

# Usage: stackTrace [<DEPTH>]
# Generates a stacktrace. Strart at <DEPTH> if given, otherwise at the top.
# Needed
# - BASH variables
#   - STACK_TRACE_DEPTH
function stackTrace {
    declare    callAr
    declare -i depth
    declare    fileName
    declare    fnName="()"
    declare    lineNo

    case ${-} in
        *i*) # interactive shell: no stackTrace
            return
            ;;
        *) # non-interactive shell
            ;;
    esac
    if [[ ${#} -ne 0 ]]; then
        depth=${1}; shift
    else
        depth=0
    fi
    while [[ ${fnName} != "main" && ${depth} -le ${STACK_TRACE_DEPTH} ]]; do
        callAr=($(caller ${depth}))
        lineNo=${callAr[0]}
        fnName=${callAr[1]}
        fileName=${callAr[2]}
        if [[ ${fnName} == "" ]]; then
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
# It shows the filename with linenummer and function name from which it is called.
# Not very useful interactive.
# Needed: nothing
function taggedMsg {
    declare -r OLD_IFS=${IFS}

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
    callAr=($(caller 1))
    lineNo=${callAr[0]}
    fnName=${callAr[1]}
    fileName=${callAr[2]}
    printf "${TAG}: ${fileName}:${lineNo} in ${fnName}\n" >&2
    IFS=$'\n'
    set -- ${message}
    while [[ ${#} -ge 1 ]]; do
        printf "\t${1}\n"; shift
    done
    IFS=${OLD_IFS}
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
  if [[ ${IS_FATAL} -ne "false" ]]; then
    callAr=($(caller 0))
    function=${callAr[1]}
    fatal "${function} needs ${VAR_NAME} to be defined"
    return
  fi
  return 1
}

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

case ${-} in
    *i*) # do things for interactive shell
         # define +=, -= and ==

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
                pushd ${1}
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
        ;;
esac

includeFile --notNeeded BASHExtra.sh
