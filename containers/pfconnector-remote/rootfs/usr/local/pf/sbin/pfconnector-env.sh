#!/bin/bash
# Source this from the s6 oneshot scripts: they run without the container
# environment (no with-contenv), so load the connector settings from the
# bind-mounted env file for every variable not already exported.
PFCONNECTOR_ENV_FILE="${PFCONNECTOR_ENV_FILE:-/usr/local/pf/conf/pfconnector-client.env}"
if [ -r "$PFCONNECTOR_ENV_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|'#'*) continue ;;
        esac
        key="${line%%=*}"
        value="${line#*=}"
        [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
        if [ -z "${!key+x}" ]; then
            export "$key=$value"
        fi
    done < "$PFCONNECTOR_ENV_FILE"
fi

# High availability settings: the env file (host-side override) wins, else the
# ha block of the cached site-network payload, which the pfconnector-client
# writes from the connector configuration made in the admin UI.
PFCONNECTOR_SITE_NETWORK_CACHE="${PFCONNECTOR_SITE_NETWORK_CACHE:-/usr/local/pf/var/conf/site-network.json}"
if [ -z "${PFCONNECTOR_HA_VIP:-}" ] && [ -s "$PFCONNECTOR_SITE_NETWORK_CACHE" ] && command -v jq >/dev/null 2>&1; then
    _ha_vip=$(jq -r '.ha.vip // empty' "$PFCONNECTOR_SITE_NETWORK_CACHE" 2>/dev/null || true)
    if [ -n "$_ha_vip" ]; then
        export PFCONNECTOR_HA_VIP="$_ha_vip"
        if [ -z "${PFCONNECTOR_HA_VRID:-}" ]; then
            _ha_vrid=$(jq -r '.ha.vrid // empty' "$PFCONNECTOR_SITE_NETWORK_CACHE" 2>/dev/null || true)
            [ -n "$_ha_vrid" ] && export PFCONNECTOR_HA_VRID="$_ha_vrid"
        fi
        if [ -z "${PFCONNECTOR_HA_INTERFACE:-}" ]; then
            _ha_iface=$(jq -r '.ha.interface // empty' "$PFCONNECTOR_SITE_NETWORK_CACHE" 2>/dev/null || true)
            [ -n "$_ha_iface" ] && export PFCONNECTOR_HA_INTERFACE="$_ha_iface"
        fi
    fi
    unset _ha_vip _ha_vrid _ha_iface
fi
