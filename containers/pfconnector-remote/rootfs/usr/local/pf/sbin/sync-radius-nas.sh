#!/bin/bash

set -e

CLIENTS_DIR=/usr/local/pf/raddb/dynamic-clients
PFCONNECTOR_API="localhost:22226/api/v1/pfconnector/remote-radius-nas"

mkdir -p "$CLIENTS_DIR"

# Fetch NAS entries from pfconnector API
NAS_JSON=$(curl -sf "$PFCONNECTOR_API")
if [ -z "$NAS_JSON" ]; then
    echo "No NAS entries received"
    exit 0
fi

# Clear existing client files
rm -f "$CLIENTS_DIR"/*

# Write each NAS entry as a FreeRADIUS client file
echo "$NAS_JSON" | jq -c '.[]' | while read -r entry; do
    nasname=$(echo "$entry" | jq -r '.nasname')
    secret=$(echo "$entry" | jq -r '.secret')
    nastype=$(echo "$entry" | jq -r '.type // "other"')

    if [ -n "$nasname" ] && [ -n "$secret" ]; then
        cat > "$CLIENTS_DIR/$nasname" <<EOF
client $nasname {
    secret = $secret
    shortname = $nasname
    nastype = $nastype
}
EOF
        echo "Added NAS client: $nasname"
    fi
done

echo "Radius NAS sync completed"
