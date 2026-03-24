#!/bin/bash

set -e

RADIUS_SSL=/usr/local/pfconnector-remote/conf/ssl
CRT_FILE="$RADIUS_SSL"/radius_default_tls-common.crt
CA_FILE="$RADIUS_SSL"/radius_default_tls-common.pem
KEY_FILE="$RADIUS_SSL"/radius_default_tls-common.key

RET=$(curl -s -f "localhost:22226/api/v1/pfconnector/remote-radius-conf")

CA=$(echo "$RET" | jq -r '.ca')
KEY=$(echo "$RET" | jq -r '.private_key')
CERT=$(echo "$RET" | jq -r '.certificate')

# Create dir + truncate file if needed
mkdir -p "$RADIUS_SSL"
>"$CRT_FILE"
>"$CA_FILE"
>"$KEY_FILE"

echo -e "$CERT" >>"$CRT_FILE"
echo -e "$CA" >>"$CA_FILE"
echo -e "$KEY" >>"$KEY_FILE"

echo "Radius certs updated"
