#!/bin/bash

set -o nounset -o pipefail -o errexit

# Extract connector_id
CONNECTOR_ID=$(grep '^AUTH=' /usr/local/pfconnector-remote/conf/pfconnector-client.env | cut -d'=' -f2 | cut -d':' -f1)

if [ -z "$CONNECTOR_ID" ]; then
    echo "Error: no CONNECTOR_ID found in /usr/local/pfconnector-remote/conf/pfconnector-client.env"
    exit 0
fi

curl --fail "localhost:22226/api/v1/pfconnector/remote-ntlm-auth-api-env?CONNECTOR_ID=$CONNECTOR_ID" > /usr/local/ntlm-auth-api/conf/ntlm_auth_api.env
