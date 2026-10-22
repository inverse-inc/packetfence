#!/bin/bash

set -o nounset -o pipefail -o errexit

# Inside the container, the env file is mounted at /usr/local/pf/conf/
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

curl --fail "http://localhost:22226/api/v1/pfconnector/remote-fingerbank-collector-nba-conf" > /usr/local/collector-remote/conf/network_behavior_policies.conf

curl --fail "http://localhost:22226/api/v1/pfconnector/remote-fingerbank-collector-env?CONNECTOR_ID=$CONNECTOR_ID" > /usr/local/collector-remote/conf/collector.env
