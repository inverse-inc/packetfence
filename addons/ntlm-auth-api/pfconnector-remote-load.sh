#!/bin/bash

set -o nounset -o pipefail -o errexit

INPUT_FILE="/usr/local/ntlm-auth-api/conf/ntlm_auth_api.env"
TEMP_ENV_FILE=$(mktemp)

# Identify ourselves so the server hands us the real machine_account_password
# only for the domains whose AD this connector is next to; secrets for every
# other domain come back masked. AUTH=<connector_id>:<secret> in the
# pfconnector-client.env, same idiom as ntlm-auth-api-domain / sync-radius-nas.sh.
PFCONNECTOR_CONF="/usr/local/pfconnector-remote/conf/pfconnector-client.env"
CONNECTOR_ID=""
if [ -f "$PFCONNECTOR_CONF" ]; then
    CONNECTOR_ID=$(grep -E '^AUTH=' "$PFCONNECTOR_CONF" | head -n1 | cut -d= -f2- | cut -d: -f1 || true)
fi
if [ -z "$CONNECTOR_ID" ]; then
    echo "Warning: no CONNECTOR_ID in $PFCONNECTOR_CONF; requesting config with masked secrets"
fi

if curl --fail --silent --show-error "localhost:22226/api/v1/pfconnector/remote-ntlm-auth-api-env?CONNECTOR_ID=${CONNECTOR_ID}" -o "$TEMP_ENV_FILE"; then
    if [ ! -s "$TEMP_ENV_FILE" ]; then
        echo "Warning: Fetched ntlm_auth_api.env is empty, falling back to existing file"
        rm -f "$TEMP_ENV_FILE"
    elif ! jq empty "$TEMP_ENV_FILE" 2>/dev/null; then
        echo "Warning: Fetched ntlm_auth_api.env contains invalid JSON, falling back to existing file"
        rm -f "$TEMP_ENV_FILE"
    else
        mv "$TEMP_ENV_FILE" "$INPUT_FILE"
    fi
else
    echo "Warning: Failed to fetch ntlm_auth_api.env from API, falling back to existing file"
    rm -f "$TEMP_ENV_FILE"
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
TEMP_DB_FILE=$(mktemp)

if curl --fail --silent --show-error "localhost:22226/api/v1/pfconnector/remote-ntlm-auth-api-db" -o "$TEMP_DB_FILE"; then
    if [ ! -s "$TEMP_DB_FILE" ]; then
        echo "Warning: Fetched db.env is empty, falling back to existing file"
        rm -f "$TEMP_DB_FILE"
    elif ! jq empty "$TEMP_DB_FILE" 2>/dev/null; then
        echo "Warning: Fetched db.env contains invalid JSON, falling back to existing file"
        rm -f "$TEMP_DB_FILE"
    else
        mv "$TEMP_DB_FILE" "$DB_FILE"
    fi
else
    echo "Warning: Failed to fetch db.env from API, falling back to existing file"
    rm -f "$TEMP_DB_FILE"
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

