#!/bin/bash
# Source this from the s6 oneshot scripts: they run without the container
# environment (no with-contenv), so load the connector settings from the
# bind-mounted env file for every variable not already exported.
PFCONNECTOR_ENV_FILE="${PFCONNECTOR_ENV_FILE:-/usr/local/pf/conf/pfconnector-client.env}"
if [ -r "$PFCONNECTOR_ENV_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|'#'*) continue ;;
        esac
        key="${line%%=*}"
        value="${line#*=}"
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
        if [ -z "${!key+x}" ]; then
            export "$key=$value"
        fi
    done < "$PFCONNECTOR_ENV_FILE"
fi
