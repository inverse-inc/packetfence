#!/bin/bash

set -o nounset -o pipefail -o errexit

# Extract connector_id
CONNECTOR_ID=$(grep '^AUTH=' /usr/local/pfconnector-remote/conf/pfconnector-client.env | cut -d'=' -f2 | cut -d':' -f1)

if [ -z "$CONNECTOR_ID" ]; then
    echo "Error: no CONNECTOR_ID found in /usr/local/pfconnector-remote/conf/pfconnector-client.env"
    exit 0
fi

curl --fail "localhost:22226/api/v1/pfconnector/remote-ntlm-auth-api-env?CONNECTOR_ID=$CONNECTOR_ID" > /usr/local/ntlm-auth-api/conf/ntlm_auth_api.env


# JSON File
INPUT_FILE="/usr/local/ntlm-auth-api/conf/ntlm_auth_api.env"
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File $INPUT_FILE doesn't exists"
    exit 1
fi

# Generate $domain.env files
domains=$(jq -r 'keys[]' "$INPUT_FILE")

for domain in $domains; do
    output_file="/usr/local/ntlm-auth-api/var/conf/${domain}.env"

    host=$(jq -r ".\"$domain\".ntlm_auth_host" "$INPUT_FILE")
    port=$(jq -r ".\"$domain\".ntlm_auth_port" "$INPUT_FILE")

    echo "HOST=$host" > "$output_file"
    echo "LISTEN=$port" >> "$output_file"
    echo "IDENTIFIER=$domain" >> "$output_file"
done

# Generate domain.conf

output_ini="/usr/local/ntlm-auth-api/conf/domain.conf"

> "output_ini"

jq -r 'to_entries[] |
       "[\(.key)]",
       (.value | to_entries[] | "\(.key)=\(.value)"),
       ""' "$INPUT_FILE" >> "$output_ini"
