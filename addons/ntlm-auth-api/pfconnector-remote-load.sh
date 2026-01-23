#!/bin/bash

set -o nounset -o pipefail -o errexit

# Extract connector_id
CONNECTOR_ID=$(grep '^AUTH=' /usr/local/pfconnector-remote/conf/pfconnector-client.env | cut -d'=' -f2 | cut -d':' -f1)

if [ -z "$CONNECTOR_ID" ]; then
    echo "Error: no CONNECTOR_ID found in /usr/local/pfconnector-remote/conf/pfconnector-client.env"
    exit 0
fi

INPUT_FILE="/usr/local/ntlm-auth-api/conf/ntlm_auth_api.env"

if ! curl --fail --silent --show-error "localhost:22226/api/v1/pfconnector/remote-ntlm-auth-api-env?CONNECTOR_ID=$CONNECTOR_ID" -o "$INPUT_FILE"; then
    echo "Error: Failed to fetch ntlm_auth_api.env from API"
    exit 1
fi

if [ ! -s "$INPUT_FILE" ]; then
    echo "Error: File $INPUT_FILE is empty or doesn't exist"
    exit 1
fi

if ! jq empty "$INPUT_FILE" 2>/dev/null; then
    echo "Error: File $INPUT_FILE contains invalid JSON"
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

hostname=`hostname`

> $output_ini

jq -r --arg hostname "$hostname"  'to_entries[] |
        "[\($hostname) \(.key)]",
       (.value | to_entries[] | "\(.key)=\(.value)"),
       ""' "$INPUT_FILE" >> "$output_ini"

# Generate db.ini

DB_FILE="/usr/local/ntlm-auth-api/conf/db.env"

if ! curl --fail --silent --show-error "localhost:22226/api/v1/pfconnector/remote-ntlm-auth-api-db" -o "$DB_FILE"; then
    echo "Error: Failed to fetch db.env from API"
    exit 1
fi

if [ ! -s "$DB_FILE" ]; then
    echo "Error: File $DB_FILE is empty or doesn't exist"
    exit 1
fi

if ! jq empty "$DB_FILE" 2>/dev/null; then
    echo "Error: File $DB_FILE contains invalid JSON"
    exit 1
fi

db_ini="/usr/local/ntlm-auth-api/var/conf/ntlm-auth-api.d/db.ini"


> $db_ini

jq -r 'to_entries[] |
        "[\(.key)]",
       (.value | to_entries[] | "\(.key)=\(.value)"),
       ""' "$DB_FILE" >> "$db_ini"

