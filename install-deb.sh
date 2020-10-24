#!/usr/bin/env bash
set -e
shopt -s extglob
pushd . > /dev/null
cd $(dirname ${BASH_SOURCE[0]})
SCRIPT_DIR=$(pwd)
popd > /dev/null

DEB_FILE=${SCRIPT_DIR}

function usage () {
    echo "$0: $1" >&2
    echo
    echo "Usage: $0 [--deb-dir <dir with deb files>] <deb file to install>"
    echo
    return 1
}

function install_deb() {
    local debfile=${1:?"Missing deb file as first parameter!"}
    local debdir=${2:-${SCRIPT_DIR}}
    local dependencies=($(dpkg --info ${debfile} | grep "Depends:" | sed 's/^ \+Depends: \+\(.*\)$/\1/' | sed 's/ //g' | sed 's/([^)]\+)//g' | sed 's/,/ /g'))
    for dep in ${dependencies[@]}; do
        install_dependency_if_missing "${dep}" "${debdir}"
    done
    echo "Install local dependency: ${debfile}"
    dpkg -i "${debfile}"
}

function install_dependency_if_missing() {
    local dependency=${1:?"Missing required dependency as first parameter!"}
    local debdir=${2:?"Missing deb dir as second parameter!"}
    local depset=($(echo "${dependency}" | sed 's/|/ /g'))
    if [[ "$(is_at_least_one_installed ${depset[@]})" != "yes" ]]; then
        install_dependency "${depset[0]}" "${debdir}"
    fi
}

function is_at_least_one_installed() {
    local dependencies=($@)
    for dep in ${dependencies[@]}; do
        if [[ "$(dpkg-query --show --showformat='${db:Status-Status}\n' ${dep} 2>/dev/null)" == "installed" ]]; then
            echo "yes"
            return
        fi
    done
    echo "no"
}

function install_dependency() {
    local dependency=${1:?"Missing required dependency as first parameter!"}
    local debdir=${2:?"Missing deb dir as second parameter!"}
    local file=$(readlink -fe ${debdir}/${dependency}_*.deb)
    if [[ -n $file ]]; then
        install_deb "${file}" "${debdir}"
    else
        echo "Install remote dependency: ${dependency}"
        apt-get install -y "${dependency}"
    fi
}

function parseCmd () {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --deb-dir)
                shift
                case "$1" in
                    ""|--*)
                        usage "Requires directory with dependencies"
                        return 1
                        ;;
                    *)
                        DEB_DIR="$(readlink -fe $1)"
                        shift
                        ;;
                esac
                ;;
            -*)
                usage "Unknown option: $1"
                return $?
                ;;
            *)
                DEB_FILE="$(readlink -fe $1)"
                shift
                ;;
        esac
    done
    if [ -z "${DEB_FILE}" ]; then
        usage "Requires deb file which should be installed"
        return $?
    fi
    return 0
}


function main () {
    parseCmd "$@"
    local retval=$?
    if [ $retval != 0 ]; then
        exit $retval
    fi
    install_deb "${DEB_FILE}" "${DEB_DIR}"
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
    main "$@"
fi
