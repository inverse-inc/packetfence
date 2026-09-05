#!/bin/bash

set -e

# Oneshots run without the container env: load pfconnector-client.env.
. /usr/local/pf/sbin/pfconnector-env.sh

RADDB_TEMPLATE="/usr/local/pf/raddb/sites-available/packetfence"
RADDB_PACKETFENCE="/usr/local/pf/raddb/sites-enabled/packetfence"
PFCONNECTOR_CONF="/usr/local/pf/conf/pfconnector-client.env"

# Fetch the shared pfconnector RADIUS secret (unified_api_system_user.pass) from the pfconnector server API
RADIUS_SECRET=$(curl -s http://localhost:22226/api/v1/pfconnector/radius-secret)

if [ -z "$RADIUS_SECRET" ]; then
    # HA backup host (docs/design/pfconnector-remote-ha.md): no tunnel until
    # it takes the VIP. Keep the config rendered by a previous run; the
    # secret and the connector id do not change.
    if [ -n "${PFCONNECTOR_HA_VIP:-}" ] && [ -s "$RADDB_PACKETFENCE" ]; then
        echo "WARNING: pfconnector API unreachable, keeping the previously rendered $RADDB_PACKETFENCE"
        exit 0
    fi
    echo "ERROR: Could not fetch radius secret from pfconnector API" >&2
    exit 1
fi

# A newline in the secret cannot be expressed in a single sed s/// command and
# would also break the generated config; refuse it rather than emit garbage.
if [[ "$RADIUS_SECRET" == *$'\n'* ]]; then
    echo "ERROR: radius secret contains a newline; refusing to write config" >&2
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

# Escape characters that are special in a sed replacement (\, /, &) so a
# secret containing them doesn't corrupt the generated config.
sed_escape() {
    printf '%s' "$1" | sed -e 's/[&/\]/\\&/g'
}

# Generate raddb config from template
if [ -f "$RADDB_TEMPLATE" ]; then
    # All substitution values go through sed_escape so a connector_id (named in
    # the admin UI) containing / or & can't corrupt the config or break sed.
    RADIUS_SECRET_ESC=$(sed_escape "$RADIUS_SECRET")
    MGMT_IP_ESC=$(sed_escape "$MGMT_IP")
    CONNECTOR_ID_ESC=$(sed_escape "$CONNECTOR_ID")
    sed -e "s/%password%/$RADIUS_SECRET_ESC/g" \
        -e "s/%mgmt_ip%/$MGMT_IP_ESC/g" \
        -e "s/%connector_id%/$CONNECTOR_ID_ESC/g" \
        "$RADDB_TEMPLATE" > "$RADDB_PACKETFENCE"
    echo "Configured raddb: radius_secret=***, mgmt_ip=$MGMT_IP, connector_id=$CONNECTOR_ID"
else
    echo "ERROR: $RADDB_TEMPLATE not found" >&2
    exit 1
fi
