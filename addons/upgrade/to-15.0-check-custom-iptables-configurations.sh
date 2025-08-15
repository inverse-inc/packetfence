#!/bin/bash

PF_DEFAULT="14.1"
GET_VERSION=0
if [ -z "$1" ]; then
    GET_VERSION=1
fi
PF_RAW="${1:-$PF_DEFAULT}"

LOCAL_DIR="/usr/local/pf/conf"
FILES_TO_PROCESS=("iptables.conf" "ip6tables.conf")

download_from_github() {
    local url="$1"
    local output_file="$2"
    local version="$3"

    if command -v wget &>/dev/null; then
        if ! wget -q "$url" -O "$output_file"; then
            echo "Error: Failed to download file using wget." >&2
            return 1
        fi
    elif command -v curl &>/dev/null; then
        if ! curl -s -o "$output_file" "$url"; then
            echo "Error: Failed to download file using curl." >&2
            return 1
        fi
    else
        echo "Error: Neither wget nor curl is available for downloading." >&2
        return 1
    fi

    echo "Successfully downloaded $FILE_NAME from branch maintenance/$version."
    return 0
}

process_file() {
    local FILE_NAME="$1"
    local LOCAL_FILE="$LOCAL_DIR/$FILE_NAME"
    local BK_FILE="$LOCAL_FILE.backup"
    local TEMP_FILE="/tmp/$FILE_NAME.github"

    if [[ -f "$LOCAL_FILE" ]]; then
        if [ $GET_VERSION == 1 ]; then
            echo "Note: No version provided, using default version '$PF_DEFAULT'"
        fi
        PF_VERSION=$(echo "$PF_RAW" | sed -E 's/([0-9]{1,2}\.[0-9]).*/\1/')
        if [[ "$PF_RAW" != "$PF_VERSION" ]]; then
            echo "Transformed version from '$PF_RAW' to '$PF_VERSION'"
        fi

        GITHUB_RAW_URL="https://raw.githubusercontent.com/inverse-inc/packetfence/refs/heads/maintenance/$PF_VERSION/conf/$FILE_NAME.example"
        if ! download_from_github "$GITHUB_RAW_URL" "$TEMP_FILE" "$PF_VERSION"; then
            exit 1
        fi

        if cmp -s "$TEMP_FILE" "$LOCAL_FILE"; then
            echo "Files are identical. Removing both files."
            rm -f "$LOCAL_FILE" || echo "Warning: Could not delete $LOCAL_FILE" >&2
        else
            echo "Files are different due to version or custom modifications."
            echo "If needed, please follow the documentation to import it."
            echo "$LOCAL_FILE renamed in $BK_FILE."
            mv "$LOCAL_FILE" "$BK_FILE" || echo "Warning: Could not rename $LOCAL_FILE to $BK_FILE" >&2
        fi
        rm -f "$TEMP_FILE" || echo "Warning: Could not delete $TEMP_FILE" >&2
    else
        echo "Local file $LOCAL_FILE does not exist. Nothing to do."
    fi
}

for file in "${FILES_TO_PROCESS[@]}"; do
    echo -e "\n=== Processing $file ==="
    process_file "$file"
done

echo -e "\nAll files processed"
exit 0
