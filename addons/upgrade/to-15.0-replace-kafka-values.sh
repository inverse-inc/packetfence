#!/bin/bash

# Check to see if the file exists
if [ ! -f "/usr/local/pf/conf/kafka.conf" ]; then
    echo "Error: kafka.conf doesn't exist." >&2
    exit 1
fi

# Generate a UUID
NEW_UUID=$(uuidgen | tr -d '-' | base64 | cut -b 1-22)

# Generate password
NEW_ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)
NEW_CLIENT_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)

# Update kafka.conf
sed -i.bak \
    -e "s/%uuid%/$NEW_UUID/g" \
    -e "s/%admin_password%/$NEW_ADMIN_PASSWORD/g" \
    -e "s/%client_password%/$NEW_CLIENT_PASSWORD/g" \
    /usr/local/pf/conf/kafka.conf

