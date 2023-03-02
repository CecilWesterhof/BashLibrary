#!/usr/bin/env bash

# Script to install the library and scripts into /usr/local/bash
# Should be made a little more intelligently, for example most of the time
# installGuestAdditions.sh is not necessary. Also clojure is not always
# needed.


# An error should terminate the script
set -o errexit
set -o nounset


# Always define all used variables
# I use uppercase for readonly variables
declare -r INSTALL_DIR=/usr/local/bash
declare -r LINK_FILES=(
    alias
    BASHInitialisation.sh
    bin
    disk.sh
    network.sh
    random.sh
    system.sh
    systemd.sh
    time.sh
)
declare -r SOURCE_DIR="$(readlink -f ${0%/*})"

declare file


# main code
mkdir --parents "${INSTALL_DIR}"
for file in "${LINK_FILES[@]}" ; do
    ln -fs "${SOURCE_DIR}/${file}" "${INSTALL_DIR}"
    printf "Created a link for %s\n" "${file}"
done
printf "Done\n"
printf "Add ${INSTALL_DIR}/bin to your PATH\n"
printf "Use 'source ${INSTALL_DIR}/BASHInitialisation.sh' to initialise the library\n"
