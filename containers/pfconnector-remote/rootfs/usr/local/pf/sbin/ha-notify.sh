#!/bin/bash
# keepalived notify script: $1 = "INSTANCE", $2 = instance name, $3 = state
# (MASTER|BACKUP|FAULT|STOP), $4 = priority.
# Records the state for the admin UI/logs and, on MASTER, finishes bringing
# the service stack up: a backup host that never held the VIP could not fetch
# the RADIUS secret, certificates, NAS list or collector config from the cloud
# at boot (no tunnel), so their oneshots may have failed. Once the tunnel is
# up, `s6-rc -u change user` retries them and starts what depends on them.
STATE="${3:-UNKNOWN}"
STATE_FILE=/usr/local/pfconnector-remote/var/run/ha_state

mkdir -p "$(dirname "$STATE_FILE")"
echo "$STATE" > "$STATE_FILE"
echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: VRRP state $STATE (priority ${4:-?})"

if [ "$STATE" = "MASTER" ]; then
    (
        for _ in $(seq 1 90); do
            if curl -sf --max-time 2 http://127.0.0.1:22226/api/v1/pfconnector/remote-radius-conf >/dev/null 2>&1; then
                echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: tunnel up, completing service start-up"
                /command/s6-rc -u change user || true
                exit 0
            fi
            sleep 1
        done
        echo "$(date '+%Y/%m/%d %H:%M:%S') ha-notify: tunnel not up after 90s, services not re-checked"
    ) &
fi
exit 0
