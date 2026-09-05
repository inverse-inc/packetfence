#!/bin/bash

set -e

# Oneshots run without the container env: load pfconnector-client.env.
. /usr/local/pf/sbin/pfconnector-env.sh

RADIUS_SSL=/usr/local/pf/conf/ssl
CRT_FILE="$RADIUS_SSL"/radius_default_tls-common.crt
CA_FILE="$RADIUS_SSL"/radius_default_tls-common.pem
KEY_FILE="$RADIUS_SSL"/radius_default_tls-common.key

if ! RET=$(curl -s -f "http://localhost:22226/api/v1/pfconnector/remote-radius-conf"); then
    # HA backup host: no tunnel until it takes the VIP; the certs synced by a
    # previous run (or copied from the peer) stay valid.
    if [ -n "${PFCONNECTOR_HA_VIP:-}" ] && [ -s "$CRT_FILE" ] && [ -s "$KEY_FILE" ] && [ -s "$CA_FILE" ]; then
        echo "WARNING: pfconnector API unreachable, keeping the existing RADIUS certs"
        exit 0
    fi
    echo "Error: unable to fetch the RADIUS certs from the pfconnector API" >&2
    exit 1
fi

CA=$(echo "$RET" | jq -r '.ca')
KEY=$(echo "$RET" | jq -r '.private_key')
CERT=$(echo "$RET" | jq -r '.certificate')

# Validate every field is present and PEM-shaped before touching the existing,
# working certs. A transient bad/partial response must not overwrite them
# (jq -r yields the literal "null" for a missing field).
valid_pem() {
    case "$1" in
        ""|"null") return 1 ;;
        *"-----BEGIN "*) return 0 ;;
        *) return 1 ;;
    esac
}

for pair in "CA:$CA" "KEY:$KEY" "CERT:$CERT"; do
    name=${pair%%:*}
    if ! valid_pem "${pair#*:}"; then
        echo "Error: $name is missing or not PEM-formatted; keeping existing certs"
        exit 1
    fi
done

# Create dir + truncate file if needed
mkdir -p "$RADIUS_SSL"

# printf, not echo -e: PEM is base64 so it has no escapes to interpret, and
# echo -e would mangle any payload that happened to contain backslashes.
printf '%s\n' "$CERT" >"$CRT_FILE"
printf '%s\n' "$CA" >"$CA_FILE"
printf '%s\n' "$KEY" >"$KEY_FILE"

echo "Radius certs updated"
