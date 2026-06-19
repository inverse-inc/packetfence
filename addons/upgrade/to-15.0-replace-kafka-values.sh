#!/bin/bash

KAFKA_CONF="/usr/local/pf/conf/kafka.conf"

# Check to see if the file exists
if [ ! -f "$KAFKA_CONF" ]; then
    echo "Error: kafka.conf doesn't exist." >&2
    exit 1
fi

# Generate a UUID
NEW_UUID=$(uuidgen | tr -d '-' | base64 | cut -b 1-22)

# Generate password
NEW_ADMIN_PASSWORD=$(openssl rand -hex 16)
NEW_CLIENT_PASSWORD=$(openssl rand -hex 16)
NEW_KEYSTORE_PASSWORD=$(openssl rand -hex 16)
NEW_TRUSTSTORE_PASSWORD=$(openssl rand -hex 16)

# Append the [ssl] section (mTLS on the external listener) for nodes upgraded
# from a kafka.conf that predates it. The %placeholder% passwords are filled in
# by the sed below, like the admin/client passwords. Skipped when [ssl] already
# exists so re-running this is idempotent.
if ! grep -q '^\[ssl\]' "$KAFKA_CONF"; then
    cat >> "$KAFKA_CONF" <<'EOF'

# mTLS configuration for the external Kafka listener
[ssl]
# Enable mTLS on the external listener (enabled|disabled)
enabled=disabled
# The pfpki Certificate Authority id used to sign the broker certificate
ca_id=
# The pfpki profile id used to issue the broker certificate (auto-managed)
profile_id=
# The Common Name of the broker certificate
cn=
# Comma-separated DNS Subject Alternative Names for the broker certificate
dns_names=
# Comma-separated IP Subject Alternative Names for the broker certificate
ip_addresses=
# Password protecting the generated keystore (auto-generated)
keystore_password=%keystore_password%
# Password protecting the generated truststore (auto-generated)
truststore_password=%truststore_password%
# PEM of the peer's CA certificate used to validate the peer (truststore)
peer_ca=
# The name of the listener to secure with mTLS (the external listener on 9092)
listener=EXTERNAL
EOF
fi

# Update kafka.conf
sed -i.bak \
    -e "s/%uuid%/$NEW_UUID/g" \
    -e "s/%admin_password%/$NEW_ADMIN_PASSWORD/g" \
    -e "s/%client_password%/$NEW_CLIENT_PASSWORD/g" \
    -e "s/%keystore_password%/$NEW_KEYSTORE_PASSWORD/g" \
    -e "s/%truststore_password%/$NEW_TRUSTSTORE_PASSWORD/g" \
    "$KAFKA_CONF"
