#!/bin/bash

set -o nounset -o pipefail -o errexit

# Inside the container, the env file is mounted at /usr/local/pf/conf/
# Oneshots run without the container env: load pfconnector-client.env.
. /usr/local/pf/sbin/pfconnector-env.sh

ENV_FILE="/usr/local/pf/conf/pfconnector-client.env"

if [ ! -e "$ENV_FILE" ]; then
    echo "$ENV_FILE not found"
    exit 1
fi

# Extract connector_id
CONNECTOR_ID=$(grep '^AUTH=' "$ENV_FILE" | cut -d'=' -f2 | cut -d':' -f1)

if [ -z "$CONNECTOR_ID" ]; then
    echo "Error: no CONNECTOR_ID found in $ENV_FILE"
    exit 1
fi

CONF_DIR=/usr/local/collector-remote/conf

# Download to a temporary file so a failed fetch never truncates a working
# config (an HA backup host has no tunnel until it takes the VIP).
fetch() {
    local url="$1" dest="$2" tmp
    tmp=$(mktemp "$dest.XXXXXX")
    if curl --fail -s "$url" > "$tmp"; then
        mv "$tmp" "$dest"
        return 0
    fi
    rm -f "$tmp"
    if [ -n "${PFCONNECTOR_HA_VIP:-}" ] && [ -s "$dest" ]; then
        echo "WARNING: pfconnector API unreachable, keeping the existing $dest"
        return 0
    fi
    echo "Error: unable to fetch $url" >&2
    return 1
}

fetch "http://localhost:22226/api/v1/pfconnector/remote-fingerbank-collector-nba-conf" "$CONF_DIR/network_behavior_policies.conf"
fetch "http://localhost:22226/api/v1/pfconnector/remote-fingerbank-collector-env?CONNECTOR_ID=$CONNECTOR_ID" "$CONF_DIR/collector.env"
