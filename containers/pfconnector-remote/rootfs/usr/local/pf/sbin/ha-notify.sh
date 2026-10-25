#!/bin/bash
# keepalived notify script: $1 = "INSTANCE", $2 = instance name, $3 = state
# (MASTER|BACKUP|FAULT|STOP), $4 = priority.
# Records the state for the admin UI/logs and, on MASTER, finishes bringing
# the service stack up: a backup host that never held the VIP could not fetch
# the RADIUS secret, certificates, NAS list or collector config from the cloud
# at boot (no tunnel), so their oneshots may have failed. Once the tunnel is
# up, `s6-rc -u change user` retries them and starts what depends on them.
# A host that booted from its cached copies had those oneshots succeed with
# possibly stale data (certificates or NAS list rotated while it stood by),
# so the sync scripts are then re-run and the services restarted if their
# configuration changed.
STATE="${3:-UNKNOWN}"
STATE_FILE=/usr/local/pfconnector-remote/var/run/ha_state

mkdir -p "$(dirname "$STATE_FILE")"
echo "$STATE" > "$STATE_FILE"
echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: VRRP state $STATE (priority ${4:-?})"

# Not master: the site-network addresses belong to the master. keepalived
# removes the ones it knows as virtual IPs; also drop any address left behind
# that keepalived does not know, e.g. assigned before HA was enabled or while
# this host had no config cache: every IPv4 address of a connector-owned VLAN
# link (alias pf-connector), and on the other links only the addresses
# recorded in the connector's site-network-addresses file (the ones it assigns
# to a plain host interface; the operator's addresses stay).
OWNED_ADDRESSES="${PFCONNECTOR_SITE_NETWORK_ADDRESSES:-/usr/local/pf/var/conf/site-network-addresses}"
if [ "$STATE" != "MASTER" ]; then
    for link in $(ip -o link show type vlan 2>/dev/null | awk -F': ' '{print $2}' | cut -d@ -f1); do
        ip -d link show "$link" 2>/dev/null | grep -qw "alias pf-connector" || continue
        if [ -n "$(ip -4 -o addr show dev "$link" 2>/dev/null)" ]; then
            ip -4 addr flush dev "$link" && echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: released the IPv4 address(es) of $link (not master)"
        fi
    done
    if [ -s "$OWNED_ADDRESSES" ]; then
        while read -r link cidr; do
            case "$link" in ''|'#'*) continue ;; esac
            [ -n "$cidr" ] || continue
            if ip -4 -o addr show dev "$link" 2>/dev/null | awk '{print $4}' | grep -qxF "$cidr"; then
                ip -4 addr del "$cidr" dev "$link" && echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: released the connector address $cidr of $link (not master)"
            fi
        done < "$OWNED_ADDRESSES"
    fi
fi

if [ "$STATE" = "MASTER" ]; then
    (
        for _ in $(seq 1 90); do
            if curl -sf --max-time 2 http://127.0.0.1:22226/api/v1/pfconnector/remote-radius-conf >/dev/null 2>&1; then
                echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: tunnel up, completing service start-up"
                /command/s6-rc -u change user || true
                /usr/local/pf/sbin/ha-refresh-config.sh || true
                exit 0
            fi
            sleep 1
        done
        echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: tunnel not up after 90s, services not re-checked"
    ) &
fi
exit 0
