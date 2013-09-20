# Functions:
# - diskUsage
# - doUnzip
# - isReadableFile
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
#  - fatal
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

# Usage: diskUsage [-G|-K|-M] <DIRECTORY>
# Shows the diskusage of <DIRECTORY>.
# Default in GB, but can also be done in KB and MB.
# Needed:
# - BASH functions
#  - fatal
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
#  - fatal
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

# Usage: isReadableFile <FILENAME>
# Is <FILENAME> readable
# Needed:
# - BASH functions
#  - fatal
function isReadableFile {
    if [[ ${#} -ne 1 ]] ; then
        fatal "${FUNCNAME} <FILENAME>"
        return
    fi

    [ -s ${1} -a -f ${1} -a -r ${1} ]
}

# removeSpacesFromFileNames
# In the current directory change all spaces in filenames to underscores.
# Needed:
# - BASH functions
#  - fatal
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
#  - fatal
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
#  - fatal
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
