#!/usr/bin/env bash
set -e

export ENTRYPOINT_EXEC_CMD=${ENTRYPOINT_EXEC_CMD:-exec}
export ENTRYPOINT_DEFAULT_CMD=${ENTRYPOINT_DEFAULT_CMD:-/bin/bash}

# first arg starts with `-`
if [ "${1:0:1}" = '-' ]; then
	set -- ${ENTRYPOINT_DEFAULT_CMD} "$@"
fi

"${ENTRYPOINT_EXEC_CMD}" "$@"