#!/usr/bin/env bash
set -e
pushd . > /dev/null
cd $(dirname ${BASH_SOURCE[0]})
SCRIPT_DIR=$(pwd)
popd > /dev/null


PLATFORM="linux/amd64"
DOCKERREGISTRY_USER="ueisele"
PUSH="--load"

DEBIAN_RELEASE="bullseye"
TERMSHARK_VERSION="2.3.0"

function usage () {
    echo "$0: $1" >&2
    echo
    echo "Usage: $0 [--push] [--user <name, e.g. ueisele>] [--version <wireshark-version, e.g. 3.6.1>] [--branch <wireshark-branch, e.g. master>] [--platform <list of platforms, e.g. linux/amd64 or linux/arm64>]"
    echo
    return 1
}

function build () {  
    docker buildx build --pull --platform ${PLATFORM} --target wireshark-build \
        --build-arg DEBIAN_RELEASE=${DEBIAN_RELEASE} \
        --build-arg WIRESHARK_VERSION=${WIRESHARK_VERSION} \
        --build-arg WIRESHARK_BRANCH=${WIRESHARK_BRANCH} \
        -t "${DOCKERREGISTRY_USER}/wireshark-build:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}" \
        ${SCRIPT_DIR}

    docker buildx build --pull --platform ${PLATFORM} --target net-tools ${PUSH} \
        --build-arg DEBIAN_RELEASE=${DEBIAN_RELEASE} \
        -t "${DOCKERREGISTRY_USER}/net-tools:${DEBIAN_RELEASE}-$(date --utc +'%Y%m%dT%H%M%Z')" \
        -t "${DOCKERREGISTRY_USER}/net-tools:${DEBIAN_RELEASE}" \
        -t "${DOCKERREGISTRY_USER}/net-tools:latest" \
        ${SCRIPT_DIR}

    docker buildx build --platform ${PLATFORM} --target tshark ${PUSH} \
        --build-arg DEBIAN_RELEASE=${DEBIAN_RELEASE} \
        --build-arg WIRESHARK_VERSION=${WIRESHARK_VERSION} \
        --build-arg WIRESHARK_BRANCH=${WIRESHARK_BRANCH} \
        -t "${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}-$(date --utc +'%Y%m%dT%H%M%Z')" \
        -t "${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}" \
        -t "${DOCKERREGISTRY_USER}/tshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}" \
        $([[ "${IS_WIRESHARK_RELEASE}" == "true" ]] && echo "-t ${DOCKERREGISTRY_USER}/tshark:latest") \
        ${SCRIPT_DIR}

    docker buildx build --platform ${PLATFORM} --target termshark ${PUSH} \
        --build-arg DEBIAN_RELEASE=${DEBIAN_RELEASE} \
        --build-arg WIRESHARK_VERSION=${WIRESHARK_VERSION} \
        --build-arg WIRESHARK_BRANCH=${WIRESHARK_BRANCH} \
        --build-arg TERMSHARK_VERSION=${TERMSHARK_VERSION} \
        -t "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}-${DEBIAN_RELEASE}-$(date --utc +'%Y%m%dT%H%M%Z')" \
        -t "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}-${DEBIAN_RELEASE}" \
        -t "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${TERMSHARK_VERSION}" \
        -t "${DOCKERREGISTRY_USER}/tshark-termshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}" \
        $([[ "${IS_WIRESHARK_RELEASE}" == "true" ]] && echo "-t ${DOCKERREGISTRY_USER}/tshark-termshark:latest") \
        ${SCRIPT_DIR}

    docker buildx build --platform ${PLATFORM} --target net-tools-xpra ${PUSH} \
        --build-arg DEBIAN_RELEASE=${DEBIAN_RELEASE} \
        -t "${DOCKERREGISTRY_USER}/net-tools-xpra:${DEBIAN_RELEASE}-$(date --utc +'%Y%m%dT%H%M%Z')" \
        -t "${DOCKERREGISTRY_USER}/net-tools-xpra:${DEBIAN_RELEASE}" \
        -t "${DOCKERREGISTRY_USER}/net-tools-xpra:latest" \
        ${SCRIPT_DIR}

    docker buildx build --platform ${PLATFORM} --target wireshark ${PUSH} \
        --build-arg DEBIAN_RELEASE=${DEBIAN_RELEASE} \
        --build-arg WIRESHARK_VERSION=${WIRESHARK_VERSION} \
        --build-arg WIRESHARK_BRANCH=${WIRESHARK_BRANCH} \
        -t "${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}-$(date --utc +'%Y%m%dT%H%M%Z')" \
        -t "${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}-${DEBIAN_RELEASE}" \
        -t "${DOCKERREGISTRY_USER}/wireshark:${WIRESHARK_VERSION}${VERSION_SUFFIX}" \
        $([[ "${IS_WIRESHARK_RELEASE}" == "true" ]] && echo "-t ${DOCKERREGISTRY_USER}/wireshark:latest") \
        ${SCRIPT_DIR}
}

function parseCmd () {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --push)
                PUSH="--push"
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
                        if [ $(curl -s -L -o /dev/null -w "%{http_code}" https://gitlab.com/wireshark/wireshark/-/raw/v${WIRESHARK_VERSION}/debian/changelog) = "200" ]; then
                            WIRESHARK_BRANCH=v${WIRESHARK_VERSION}
                        elif [ $(curl -s -L -o /dev/null -w "%{http_code}" https://gitlab.com/wireshark/wireshark/-/raw/wireshark-${WIRESHARK_VERSION}/debian/changelog) = "200" ]; then
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
                        WIRESHARK_VERSION="$(curl -s -L https://gitlab.com/wireshark/wireshark/-/raw/${WIRESHARK_BRANCH}/debian/changelog | grep 'wireshark (' | sed 's/^wireshark (\([[:digit:]]\+.[[:digit:]]\+.[[:digit:]]\+\)).*$/\1/')"
                        shift
                        ;;
                esac
                ;;
            --platform)
                shift
                case "$1" in
                    ""|--*)
                        usage "List of platforms required, e.g. linux/amd64 or linux/arm64"
                        return 1
                        ;;
                    *)
                        PLATFORM="$1"
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

    build
}

main "$@"