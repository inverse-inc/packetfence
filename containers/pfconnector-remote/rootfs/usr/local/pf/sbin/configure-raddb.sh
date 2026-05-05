#!/bin/bash

set -e

RADDB_TEMPLATE="/usr/local/pf/raddb/sites-available/packetfence"
RADDB_PACKETFENCE="/usr/local/pf/raddb/sites-enabled/packetfence"
PFCONNECTOR_CONF="/usr/local/pf/conf/pfconnector-client.env"

# Fetch the local secret from the pfconnector server API
LOCAL_SECRET=$(curl -s http://localhost:22226/api/v1/pfconnector/local-secret)

if [ -z "$LOCAL_SECRET" ]; then
    echo "ERROR: Could not fetch local secret from pfconnector API" >&2
    exit 1
fi

# Detect the IP address used for the default route
MGMT_IP=$(ip route get 1.1.1.1 | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')

if [ -z "$MGMT_IP" ]; then
    echo "ERROR: Could not detect management IP address" >&2
    exit 1
fi

# Resolve connector_id: prefer $AUTH (provided via --env-file in the
# combined wrapper), fall back to the on-disk env file for installs that
# bind-mount it but don't load it as env.
if [ -n "$AUTH" ]; then
    CONNECTOR_ID="${AUTH%%:*}"
elif [ -f "$PFCONNECTOR_CONF" ]; then
    CONNECTOR_ID=$(grep -E '^AUTH=' "$PFCONNECTOR_CONF" | head -n1 | cut -d= -f2- | cut -d: -f1)
fi

if [ -z "$CONNECTOR_ID" ]; then
    echo "ERROR: Could not resolve connector_id from \$AUTH or $PFCONNECTOR_CONF" >&2
    exit 1
fi

# Generate raddb config from template
if [ -f "$RADDB_TEMPLATE" ]; then
    sed -e "s/%password%/$LOCAL_SECRET/g" \
        -e "s/%mgmt_ip%/$MGMT_IP/g" \
        -e "s/%connector_id%/$CONNECTOR_ID/g" \
        "$RADDB_TEMPLATE" > "$RADDB_PACKETFENCE"
    echo "Configured raddb: local_secret=***, mgmt_ip=$MGMT_IP, connector_id=$CONNECTOR_ID"
else
    echo "ERROR: $RADDB_TEMPLATE not found" >&2
    exit 1
fi
