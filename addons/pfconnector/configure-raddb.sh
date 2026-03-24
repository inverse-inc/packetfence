#!/bin/bash

PFCONNECTOR_CONF="/usr/local/pfconnector-remote/conf/pfconnector-client.env"
RADDB_PACKETFENCE="/usr/local/pfconnector-remote/raddb/sites-enabled/packetfence"

# Extract the connector ID from AUTH=<id>:<secret>
if [ -f "$PFCONNECTOR_CONF" ]; then
    AUTH_LINE=$(grep '^AUTH=' "$PFCONNECTOR_CONF")
    CONNECTOR_ID=$(echo "$AUTH_LINE" | sed 's/^AUTH=\([^:]*\):.*/\1/')
else
    echo "ERROR: $PFCONNECTOR_CONF not found" >&2
    exit 1
fi

if [ -z "$CONNECTOR_ID" ]; then
    echo "ERROR: Could not extract connector ID from $PFCONNECTOR_CONF" >&2
    exit 1
fi

# Detect the IP address used for the default route
MGMT_IP=$(ip route get 1.1.1.1 | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')

if [ -z "$MGMT_IP" ]; then
    echo "ERROR: Could not detect management IP address" >&2
    exit 1
fi

# Replace placeholders in the raddb config
if [ -f "$RADDB_PACKETFENCE" ]; then
    sed -i "s/%password%/$CONNECTOR_ID/g" "$RADDB_PACKETFENCE"
    sed -i "s/%mgmt_ip%/$MGMT_IP/g" "$RADDB_PACKETFENCE"
    echo "Configured raddb: connector_id=$CONNECTOR_ID, mgmt_ip=$MGMT_IP"
else
    echo "ERROR: $RADDB_PACKETFENCE not found" >&2
    exit 1
fi
