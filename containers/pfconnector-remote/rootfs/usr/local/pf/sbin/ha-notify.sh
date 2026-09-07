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

# Not master: the site-network VLAN addresses belong to the master. keepalived
# removes the ones it knows as virtual IPs; also drop any address left on a
# connector-owned VLAN link (alias pf-connector) that keepalived does not know,
# e.g. assigned before HA was enabled or while this host had no config cache.
if [ "$STATE" != "MASTER" ]; then
    for link in $(ip -o link show type vlan 2>/dev/null | awk -F': ' '{print $2}' | cut -d@ -f1); do
        ip -d link show "$link" 2>/dev/null | grep -qw "alias pf-connector" || continue
        if [ -n "$(ip -4 -o addr show dev "$link" 2>/dev/null)" ]; then
            ip -4 addr flush dev "$link" && echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: released the IPv4 address(es) of $link (not master)"
        fi
    done
fi

# Checksum of the files a set of oneshots renders, to tell whether a re-run
# changed anything worth a service restart.
fingerprint() {
    cat "$@" 2>/dev/null | md5sum | cut -d' ' -f1
}

# Re-run the cloud sync scripts and restart what consumed changed files.
refresh_from_cloud() {
    local sbin=/usr/local/pf/sbin
    local radius_files=(/usr/local/pf/raddb/sites-enabled/packetfence /usr/local/pf/conf/ssl/radius_default_tls-common.crt /usr/local/pf/conf/ssl/radius_default_tls-common.key /usr/local/pf/conf/ssl/radius_default_tls-common.pem /usr/local/pf/raddb/dynamic-clients/*)
    local collector_files=(/usr/local/collector-remote/conf/collector.env /usr/local/collector-remote/conf/network_behavior_policies.conf)
    local radius_before collector_before
    radius_before=$(fingerprint "${radius_files[@]}")
    collector_before=$(fingerprint "${collector_files[@]}")
    for script in configure-raddb sync-radius-certs sync-radius-nas load-fingerbank-config; do
        "$sbin/$script.sh" >/dev/null 2>&1 || echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: $script.sh failed, keeping the current files"
    done
    radius_files=(/usr/local/pf/raddb/sites-enabled/packetfence /usr/local/pf/conf/ssl/radius_default_tls-common.crt /usr/local/pf/conf/ssl/radius_default_tls-common.key /usr/local/pf/conf/ssl/radius_default_tls-common.pem /usr/local/pf/raddb/dynamic-clients/*)
    if [ "$(fingerprint "${radius_files[@]}")" != "$radius_before" ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: RADIUS configuration changed while standing by, restarting radiusd-auth"
        /command/s6-svc -r /run/service/radiusd-auth || true
    fi
    if [ "$(fingerprint "${collector_files[@]}")" != "$collector_before" ]; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: collector configuration changed while standing by, restarting fingerbank-collector"
        /command/s6-svc -r /run/service/fingerbank-collector || true
    fi
}

if [ "$STATE" = "MASTER" ]; then
    (
        for _ in $(seq 1 90); do
            if curl -sf --max-time 2 http://127.0.0.1:22226/api/v1/pfconnector/remote-radius-conf >/dev/null 2>&1; then
                echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: tunnel up, completing service start-up"
                /command/s6-rc -u change user || true
                refresh_from_cloud
                exit 0
            fi
            sleep 1
        done
        echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: tunnel not up after 90s, services not re-checked"
    ) &
fi
exit 0
