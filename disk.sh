# Functions:
# - changedToday
# - diskFree
# - diskUsage
# - doUnzip
# - getDirTree
# - getFunctionsFromFile
# - includeFile
# - isReadableFile
# - localFind
# - pushdCheck
# - removeSpacesFromFileNames
# - removeSpecialCharsFromFileName
# - sizeOfFolder

################################################################################
# Functions                                                                    #
################################################################################

# Usage: changedToday [--short] <FILE-EXPRESSION>
# I sometimes want to know which files has changed ‘today’.
# (With today I mean the last 24 hours.)
# This function show the files that match the given regex. (Think about shell expansion.)
# Default ls -l is used. If you want ls give the --short parameter.
# Needed:
# - BASH functions
#   - fatal
function changedToday {
    declare command=$(which ls)
    declare findExpr

    if [[ ${#} -ge 1 ]] && [[ ${1} == '--short' ]]; then
        shift
    else
        command+=" -l"
    fi
    if [[ ${#} -ge 1 ]] ; then
        findExpr=${1}; shift
    else
        findExpr='*'
    fi
    if [[ ${#} -ge 1 ]] ; then
        fatal "${FUNCNAME} [--short] <FILE-EXPRESSION>"
        return
    fi

    ${command} $(eval find . -maxdepth 1 -mindepth 1 -mtime -1 -type f -name \'${findExpr}\')
}

# Usage: diskFree [-G|-K|-M] <DIRECTORY>
# Shows the diskusage of partition containing <DIRECTORY>.
# Default in GB, but can also be done in KB and MB.
# If <DIRECTORY> not the root of the partition: show mountpoint
# Needed:
# - BASH functions
#   - fatal
function diskFree {
    declare DIRECTORY
    declare FORMAT=1G

    if [[ ${#} -ne 0 ]]; then
        case ${1} in
            '-G')
                FORMAT=1G; shift
                ;;
            '-K')
                FORMAT=1K; shift
                ;;
            '-M')
                FORMAT=1M; shift
                ;;
        esac
    fi
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} [-G|-K|-M] <DIRECTORY>"
        return
    fi
    DIRECTORY=$(readlink -f ${1}); shift

    df --block-size=${FORMAT} ${DIRECTORY} | tail -n 1 | awk \
        -v dir=${DIRECTORY} \
        -v format=${FORMAT:1} '
    {
      if ( dir != $6 ) {
        print dir " is mounted on " $6
      }
      print $4, format
    };'
}

# Usage: diskUsage [-G|-K|-M] <DIRECTORY>
# Shows the diskusage of <DIRECTORY>.
# Default in GB, but can also be done in KB and MB.
# Needed:
# - BASH functions
#   - fatal
function diskUsage {
    declare DIRECTORY
    declare FORMAT=1G

    if [[ ${#} -ne 0 ]]; then
        case ${1} in
            '-G')
                FORMAT=1G; shift
                ;;
            '-K')
                FORMAT=1K; shift
                ;;
            '-M')
                FORMAT=1M; shift
                ;;
        esac
    fi
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} [-G|-K|-M] <DIRECTORY>"
        return
    fi
    DIRECTORY=$(readlink -f ${1}); shift

    du --block-size=${FORMAT} -s ${DIRECTORY} | awk \
        -v dir=${DIRECTORY} \
        -v format=${FORMAT:1} \
        '{ print $1, format };'
}

# Usage: doUnzip
# Unzip all zip-archives in the current directory, that contain newer files.
# Needed:
# - BASH functions
#   - fatal
# - External programs
#   - unzip
function doUnzip {
    if [[ ${#} -ne 0 ]] ; then
        fatal "${FUNCNAME} does not take arguments"
    fi

    for file in *.zip ; do
        unzip -u ${file}
    done
}

# Usage: getDirTree [<START_DIR>]
# Get all the directories and subdirectories contained in <START_DIR>
# Default is current directory
# Needed:
# - BASH functions
#   - fatal
function getDirTree {
    declare START_DIR

    if [[ ${#} -gt 1 ]] ; then
        fatal "${FUNCNAME} [<START_DIR>]"
        return
    fi
    if [[ ${#} -eq 1 ]] ; then
        START_DIR=${1}; shift
    else
        START_DIR=.
    fi

    find ${START_DIR} -mindepth 1 -type d -printf %P\\n
}

# Usage: getFunctionsFromFile <INPUT_FILE>
# Get all the function names from a file.
# Supposes the functions are started like: ^function <NAME> {$
# Needed:
# - BASH functions
#   - fatal
function getFunctionsFromFile {
    declare INPUTFILE

    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <INPUT_FILE>"
        return
    fi
    INPUTFILE=${1}; shift

    awk '/^function / { print $2; }' ${INPUTFILE}
}

# Usage: includeFile [--notNeeded] <INPUT_FILE>
# To include a file into a script
# Because it is a function, you cannot use declare for global variables
# Needed:
# - BASH functions
#   - fatal
function includeFile() {
    local fileName
    local needsToExist=true

    if [[ ${1} == "--notNeeded" ]] ; then
        needsToExist=false; shift
    fi
    if [[ ${#} -ne 1 ]] ; then
        fatal "includeFile [--notNeeded] <INPUT_FILE>"
        return
    fi
    INPUTFILE=${1}; shift

    if isReadableFile ${INPUTFILE} ; then
        source ${INPUTFILE}
    else
        if [[ ${needsToExist} != false ]] ; then
            fatal "${INPUTFILE} could not be used"
        fi
    fi
}

# Usage: isReadableFile <FILENAME>
# Is <FILENAME> readable
# Needed:
# - BASH functions
#   - fatal
function isReadableFile {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <FILENAME>"
        return
    fi

    [ -s ${1} -a -f ${1} -a -r ${1} ]
}

# Usage: localFind [DIRECTORY [OTHER ARGS]]
# To do a find without descending into directories on other filesystems
# When there are parameters the first should be the directory to search
# At the moment the following options of find are not supported:
#     [-H] [-L] [-P] [-D debugopts] [-Olevel]
# Needed: nothing
function localFind {
    declare directory

    if [[ ${#} -eq 0 ]] ; then
        find -xdev
    else
        directory="${1}"; shift
        find "${directory}" -xdev "${@}"
    fi
}

# pushdCheck [<DIRECTORY>]
# Do a pushd and check success
# Needed:
# - BASH functions
#   - fatal
function pushdCheck {
    declare newDir

    if [[ ${#} -gt 1 ]] ; then
        fatal "${FUNCNAME} [<DIRECTORY>]"
        return
    fi
    if [[ ${#} -eq 1 ]] ; then
        newDir="${1}"
    else
        newDir=.
    fi
    if ! pushd "${newDir}" ; then
        fatal "${FUNCNAME}: could not pushd ${newDir}"
        return
    fi
}

# removeSpacesFromFileNames
# In the current directory change all spaces in filenames to underscores.
# Needed:
# - BASH functions
#   - fatal
function removeSpacesFromFileNames {
    if [[ "$#" -ne 0 ]] ; then
        fatal "${FUNCNAME} has no parameters"
        return
    fi

    declare fileName

    find . -maxdepth 1 -type f -name "* *" | while read fileName; do
        mv "${fileName}" $(printf ${fileName} | tr " " "_")
    done
}

# Usage: removeSpecialCharsFromFileName
# In the current directory remove ‘all’ special characters from filenames
# Needed:
# - BASH functions
#   - fatal
function removeSpecialCharsFromFileName {
    if [[ "$#" -ne 0 ]] ; then
        fatal "${FUNCNAME} has no parameters"
        return
    fi

    declare file
    declare fileClean

    find . -maxdepth 1 -mindepth 1 -type f | while IFS= read file ; do
        fileClean=${file//[ ()&\'\,]/_}
        if [[ ${file} != ${fileClean} ]] ; then
            mv "$file" "$fileClean"
        fi
    done
}

# Usage: sizeOfFolder [-G|-K|-M] [FOLDER]
# Shows the diskusage of all the folders in <DIRECTORY>.
# Sorted with smallest first.
# Needed:
# - BASH functions
#   - fatal
function sizeOfFolder {
    declare FOLDER
    declare FORMAT=1M

    if [[ ${#} -ne 0 ]]; then
        case ${1} in
            '-G')
                FORMAT=1G; shift
                ;;
            '-K')
                FORMAT=1K; shift
                ;;
            '-M')
                FORMAT=1M; shift
                ;;
        esac
    fi
    if [[ ${#} -ne 0 ]]; then
        FOLDER=${1}; shift
    else
        FOLDER=.
    fi
    if [[ ${#} -ne 0 ]] ; then
        fatal "${FUNCNAME} [-G|-K|-M] [FOLDER]"
        return
    fi

    pushd ${FOLDER} >/dev/null || fatal "Could not go to folder ${FOLDER}" || return 1
    du --block-size=${FORMAT} --max-depth=1 | sort -g
    popd >/dev/null
}
