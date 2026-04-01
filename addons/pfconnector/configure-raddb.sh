#!/bin/bash

PFCONNECTOR_CONF="/usr/local/pfconnector-remote/conf/pfconnector-client.env"
RADDB_PACKETFENCE="/usr/local/pfconnector-remote/raddb/sites-enabled/packetfence"

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

# Replace placeholders in the raddb config
if [ -f "$RADDB_PACKETFENCE" ]; then
    sed -i "s/%password%/$LOCAL_SECRET/g" "$RADDB_PACKETFENCE"
    sed -i "s/%mgmt_ip%/$MGMT_IP/g" "$RADDB_PACKETFENCE"
    echo "Configured raddb: local_secret=***, mgmt_ip=$MGMT_IP"
else
    echo "ERROR: $RADDB_PACKETFENCE not found" >&2
    exit 1
fi
