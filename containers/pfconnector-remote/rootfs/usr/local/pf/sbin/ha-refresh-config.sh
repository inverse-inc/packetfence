#!/bin/bash
# Re-run the cloud sync oneshots and restart the services whose configuration
# changed (docs/design/pfconnector-remote-ha.md, 3.2.1 and 3.2.2).
#
# - ha-notify.sh runs it when this host becomes master, once the tunnel is up:
#   a host that booted from its cached copies may hold stale data
#   (certificates or NAS list rotated while it stood by).
# - The pfconnector client runs it periodically while this host is a backup,
#   with PFCONNECTOR_API pointing at the loopback relay to the master (a
#   backup has no tunnel), so the backup stays current and a host that never
#   held the VIP gets its configuration before it has to take over. --start
#   then also brings up what the failed boot-time oneshots kept down.
#
# Prints a line for each change; silent when nothing changed.
SBIN=/usr/local/pf/sbin

# Checksum of the files a set of oneshots renders, to tell whether a re-run
# changed anything worth a service restart.
fingerprint() {
    cat "$@" 2>/dev/null | md5sum | cut -d' ' -f1
}
# Same, ignoring the line order: an older pfconnector server renders
# collector.env from a map, in a different order on every fetch.
fingerprint_unordered() {
    cat "$@" 2>/dev/null | sort | md5sum | cut -d' ' -f1
}
radius_files() {
    echo /usr/local/pf/raddb/sites-enabled/packetfence /usr/local/pf/conf/ssl/radius_default_tls-common.crt /usr/local/pf/conf/ssl/radius_default_tls-common.key /usr/local/pf/conf/ssl/radius_default_tls-common.pem /usr/local/pf/raddb/dynamic-clients/*
}
COLLECTOR_FILES=(/usr/local/collector-remote/conf/collector.env /usr/local/collector-remote/conf/network_behavior_policies.conf)

# shellcheck disable=SC2046
radius_before=$(fingerprint $(radius_files))
collector_before=$(fingerprint_unordered "${COLLECTOR_FILES[@]}")
failed=0
for script in configure-raddb sync-radius-certs sync-radius-nas load-fingerbank-config; do
    if ! "$SBIN/$script.sh" >/dev/null 2>&1; then
        echo "$(date '+%Y/%m/%d %H:%M:%S') ha-refresh-config: $script.sh failed, keeping the current files"
        failed=1
    fi
done
if [ "${1:-}" = "--start" ]; then
    # Retries the oneshots that failed at boot (they now find the files) and
    # starts what depends on them; no-op when everything is up.
    /command/s6-rc -u change user >/dev/null 2>&1 || true
fi
# shellcheck disable=SC2046
if [ "$(fingerprint $(radius_files))" != "$radius_before" ]; then
    echo "$(date '+%Y/%m/%d %H:%M:%S') ha-refresh-config: RADIUS configuration changed, restarting radiusd-auth"
    /command/s6-svc -r /run/service/radiusd-auth || true
fi
if [ "$(fingerprint_unordered "${COLLECTOR_FILES[@]}")" != "$collector_before" ]; then
    echo "$(date '+%Y/%m/%d %H:%M:%S') ha-refresh-config: collector configuration changed, restarting fingerbank-collector"
    /command/s6-svc -r /run/service/fingerbank-collector || true
fi
exit $failed
