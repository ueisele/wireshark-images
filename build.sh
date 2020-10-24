#!/usr/bin/env bash
set -e
pushd . > /dev/null
cd $(dirname ${BASH_SOURCE[0]})
SCRIPT_DIR=$(pwd)
popd > /dev/null

PUSH=false
BUILD=false

DOCKERREGISTRY_USER="ueisele"

DEBIAN_RELEASE="bullseye"
TERMSHARK_VERSION="2.1.1"

function usage () {
    echo "$0: $1" >&2
    echo
    echo "Usage: $0 [--build] [--push] [--user <name, e.g. ueisele>] --version <wireshark-version, e.g. 3.3.1>"
    echo "Usage: $0 [--build] [--push] [--user <name, e.g. ueisele>] --branch <wireshark-branch, e.g. master>"
    echo
    return 1
}

function build () {  
    docker build --target wireshark-build \
        -t "${DOCKERREGISTRY_USER}/wireshark-build:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}" \
        --build-arg DEBIAN_RELEASE=${DEBIAN_RELEASE} \
        --build-arg WIRESHARK_VERSION=${WIRESHARK_VERSION} \
        --build-arg WIRESHARK_BRANCH=${WIRESHARK_BRANCH} \
        ${SCRIPT_DIR}

    docker build --target net-tools \
        -t "${DOCKERREGISTRY_USER}/net-tools:${DEBIAN_RELEASE}" \
        --build-arg DEBIAN_RELEASE=${DEBIAN_RELEASE} \
        ${SCRIPT_DIR}
    docker tag "${DOCKERREGISTRY_USER}/net-tools:${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/net-tools:${DEBIAN_RELEASE}-$(resolveBuildTimestamp ${DOCKERREGISTRY_USER}/net-tools:${DEBIAN_RELEASE})"
    docker tag "${DOCKERREGISTRY_USER}/net-tools:${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/net-tools:latest"

    docker build --target tshark \
        -t "${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}" \
        --build-arg DEBIAN_RELEASE=${DEBIAN_RELEASE} \
        --build-arg WIRESHARK_VERSION=${WIRESHARK_VERSION} \
        --build-arg WIRESHARK_BRANCH=${WIRESHARK_BRANCH} \
        ${SCRIPT_DIR}
    docker tag "${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}-$(resolveBuildTimestamp ${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE})"
    docker tag "${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}"
    if [[ "${IS_WIRESHARK_RELEASE}" == "true" ]]; then
        docker tag "${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/tshark:latest"
    fi

    docker build --target termshark \
        -t "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}-${DEBIAN_RELEASE}" \
        --build-arg DEBIAN_RELEASE=${DEBIAN_RELEASE} \
        --build-arg WIRESHARK_VERSION=${WIRESHARK_VERSION} \
        --build-arg WIRESHARK_BRANCH=${WIRESHARK_BRANCH} \
        --build-arg TERMSHARK_VERSION=${TERMSHARK_VERSION} \
        ${SCRIPT_DIR}
    docker tag "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}-${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}-${DEBIAN_RELEASE}-$(resolveBuildTimestamp ${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}-${DEBIAN_RELEASE})"
    docker tag "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}-${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}"
    docker tag "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}-${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}"
    if [[ "${IS_WIRESHARK_RELEASE}" == "true" ]]; then
        docker tag "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}-${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/tshark-termshark:latest"
    fi

    docker build --target net-tools-xpra \
        -t "${DOCKERREGISTRY_USER}/net-tools-xpra:${DEBIAN_RELEASE}" \
        --build-arg DEBIAN_RELEASE=${DEBIAN_RELEASE} \
        ${SCRIPT_DIR}
    docker tag "${DOCKERREGISTRY_USER}/net-tools-xpra:${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/net-tools-xpra:${DEBIAN_RELEASE}-$(resolveBuildTimestamp ${DOCKERREGISTRY_USER}/net-tools-xpra:${DEBIAN_RELEASE})"
    docker tag "${DOCKERREGISTRY_USER}/net-tools-xpra:${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/net-tools-xpra:latest"

    docker build --target wireshark \
        -t "${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}" \
        --build-arg DEBIAN_RELEASE=${DEBIAN_RELEASE} \
        --build-arg WIRESHARK_VERSION=${WIRESHARK_VERSION} \
        --build-arg WIRESHARK_BRANCH=${WIRESHARK_BRANCH} \
        ${SCRIPT_DIR}
    docker tag "${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}-$(resolveBuildTimestamp ${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE})"
    docker tag "${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}"
    if [[ "${IS_WIRESHARK_RELEASE}" == "true" ]]; then
        docker tag "${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}" "${DOCKERREGISTRY_USER}/wireshark:latest"
    fi
}

function push () {
    docker push "${DOCKERREGISTRY_USER}/net-tools:${DEBIAN_RELEASE}-$(resolveBuildTimestamp ${DOCKERREGISTRY_USER}/net-tools:${DEBIAN_RELEASE})"
    docker push "${DOCKERREGISTRY_USER}/net-tools:${DEBIAN_RELEASE}"
    docker push "${DOCKERREGISTRY_USER}/net-tools:latest"

    docker push "${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}-$(resolveBuildTimestamp ${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE})"
    docker push "${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}"
    docker push "${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}"
    if [[ "${IS_WIRESHARK_RELEASE}" == "true" ]]; then
        docker push "${DOCKERREGISTRY_USER}/tshark:latest"
    fi

    docker push "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}-${DEBIAN_RELEASE}-$(resolveBuildTimestamp ${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}-${DEBIAN_RELEASE})"
    docker push "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}-${DEBIAN_RELEASE}" 
    docker push "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}"
    docker push "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}"
    if [[ "${IS_WIRESHARK_RELEASE}" == "true" ]]; then
        docker push "${DOCKERREGISTRY_USER}/tshark-termshark:latest"
    fi

    docker push "${DOCKERREGISTRY_USER}/net-tools-xpra:${DEBIAN_RELEASE}-$(resolveBuildTimestamp ${DOCKERREGISTRY_USER}/net-tools-xpra:${DEBIAN_RELEASE})"
    docker push "${DOCKERREGISTRY_USER}/net-tools-xpra:${DEBIAN_RELEASE}"
    docker push "${DOCKERREGISTRY_USER}/net-tools-xpra:latest"

    docker push "${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}-$(resolveBuildTimestamp ${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE})"
    docker push "${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}"
    docker push "${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}"
    if [[ "${IS_WIRESHARK_RELEASE}" == "true" ]]; then
        docker push "${DOCKERREGISTRY_USER}/wireshark:latest"
    fi
}

function resolveBuildTimestamp() {
    local imageName=${1:?"Missing image name as first parameter!"}
    local created=$(docker inspect --format "{{ index .Created }}" "${imageName}")
    date --utc -d "${created}" +'%Y%m%dT%H%M%Z'
}

function parseCmd () {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --build)
                BUILD=true
                shift
                ;;
            --push)
                PUSH=true
                shift
                ;;
            --user)
                shift
                case "$1" in
                    ""|--*)
                        usage "Requires Docker registry user name"
                        return 1
                        ;;
                    *)
                        DOCKERREGISTRY_USER="$1"
                        shift
                        ;;
                esac
                ;;
            --debian-release)
                shift
                case "$1" in
                    ""|--*)
                        usage "Requires debian release"
                        return 1
                        ;;
                    *)
                        DEBIAN_RELEASE="$1"
                        shift
                        ;;
                esac
                ;;
            --version)
                shift
                case "$1" in
                    ""|--*)
                        usage "Requires wireshark version"
                        return 1
                        ;;
                    *)
                        WIRESHARK_VERSION="$1"
                        if [ $(curl -s -L -o /dev/null -w "%{http_code}" https://raw.githubusercontent.com/wireshark/wireshark/v${WIRESHARK_VERSION}/debian/changelog) = "200" ]; then
                            WIRESHARK_BRANCH=v${WIRESHARK_VERSION}
                        elif [ $(curl -s -L -o /dev/null -w "%{http_code}" https://raw.githubusercontent.com/wireshark/wireshark/wireshark-${WIRESHARK_VERSION}/debian/changelog) = "200" ]; then
                            WIRESHARK_BRANCH=wireshark-${WIRESHARK_VERSION}
                        else
                            usage "Invalid version: ${WIRESHARK_VERSION}"
                            return 1
                        fi
                        shift
                        ;;
                esac
                ;;
            --branch)
                shift
                case "$1" in
                    ""|--*)
                        usage "Requires wireshark branch"
                        return 1
                        ;;
                    *)
                        WIRESHARK_BRANCH="$1"
                        WIRESHARK_VERSION="$(curl -s -L https://raw.githubusercontent.com/wireshark/wireshark/${WIRESHARK_BRANCH}/debian/changelog | grep 'wireshark (' | sed 's/^wireshark (\([[:digit:]]\+.[[:digit:]]\+.[[:digit:]]\+\)).*$/\1/')"
                        shift
                        ;;
                esac
                ;;
            *)
                usage "Unknown option: $1"
                return $?
                ;;
        esac
    done
    if [ -z "${WIRESHARK_VERSION}" ]; then
        usage "Requires Wireshark version"
        return $?
    fi
    if [ -z "${WIRESHARK_BRANCH}" ]; then
        usage "Requires Wireshark branch"
        return $?
    fi
    IS_WIRESHARK_RELEASE=$(([[ "${WIRESHARK_BRANCH}" == "wireshark-"* ]] || [[ "${WIRESHARK_BRANCH}" == "v"* ]]) && echo "true" || echo "false")
    VERSION_SUFFIX=$([[ "${IS_WIRESHARK_RELEASE}" == "true" ]] && echo "" || echo "-dev")
    echo "Building Docker image with Wireshark version ${WIRESHARK_VERSION} using branch ${WIRESHARK_BRANCH}"
    return 0
}

function main () {
    parseCmd "$@"
    local retval=$?
    if [ $retval != 0 ]; then
        exit $retval
    fi

    if [ "$BUILD" = true ]; then
        build
    fi
    if [ "$PUSH" = true ]; then
        push
    fi
}

main "$@"