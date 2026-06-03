#!/bin/bash

set -e

CLIENTS_DIR=/usr/local/pf/raddb/dynamic-clients
ENV_FILE="/usr/local/pf/conf/pfconnector-client.env"

# Extract connector_id
CONNECTOR_ID=$(grep '^AUTH=' "$ENV_FILE" | cut -d'=' -f2 | cut -d':' -f1)

if [ -z "$CONNECTOR_ID" ]; then
    echo "Error: no CONNECTOR_ID found in $ENV_FILE"
    exit 1
fi

PFCONNECTOR_API="http://localhost:22226/api/v1/pfconnector/remote-radius-nas?CONNECTOR_ID=$CONNECTOR_ID"

mkdir -p "$CLIENTS_DIR"

# Fetch NAS entries from pfconnector API
NAS_JSON=$(curl -sf "$PFCONNECTOR_API")
if [ -z "$NAS_JSON" ]; then
    echo "No NAS entries received"
    exit 0
fi

# Validate the JSON up-front so a malformed payload aborts the unit (a bare
# pipe into `while` would hide jq's failure under set -e).
if ! ENTRIES=$(echo "$NAS_JSON" | jq -c '.[]'); then
    echo "Error: malformed NAS JSON received from pfconnector API"
    exit 1
fi

# Clear existing client files
rm -f "$CLIENTS_DIR"/*

# Escape a value for inclusion inside a FreeRADIUS double-quoted string.
radius_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# Read in the main shell (process substitution, not a pipe) so set -e and any
# write failure actually abort the script.
while read -r entry; do
    [ -n "$entry" ] || continue
    nasname=$(echo "$entry" | jq -r '.nasname')
    secret=$(echo "$entry" | jq -r '.secret')
    nastype=$(echo "$entry" | jq -r '.type // "other"')

    # nasname is used both as the client IP and as the output filename, so it
    # must be a bare IPv4 address. Reject anything else to prevent a malformed
    # entry from corrupting the config or escaping CLIENTS_DIR via path chars.
    if ! [[ "$nasname" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        echo "Skipping NAS entry with invalid nasname: '$nasname'"
        continue
    fi
    # A newline in the secret cannot be represented in a client{} block; skip it.
    if [ -z "$secret" ] || [[ "$secret" == *$'\n'* ]]; then
        echo "Skipping NAS client $nasname: missing or multi-line secret"
        continue
    fi
    # nas_type goes into the config unquoted, so constrain it to a safe token.
    if ! [[ "$nastype" =~ ^[A-Za-z0-9_-]+$ ]]; then
        nastype="other"
    fi

    cat > "$CLIENTS_DIR/$nasname" <<EOF
client $nasname {
    ipaddr = $nasname/32
    secret = "$(radius_escape "$secret")"
    shortname = $nasname
    nas_type = $nastype
}
EOF
    echo "Added NAS client: $nasname"
done < <(printf '%s\n' "$ENTRIES")

echo "Radius NAS sync completed"
