#!/bin/bash

set -Eeuo pipefail

trap 'status=$?; echo "ERROR: UID/GID migration failed at line $LINENO (exit $status). Correct the error and rerun this script; services may remain stopped." >&2; exit "$status"' ERR

PACKETFENCE=/usr/local/pf
MIGRATION_PENDING="$PACKETFENCE/var/uid-gid-migration.pending"
USE_F_MODE=false
PF_ID=2025
FB_ID=2026
PF_NEEDED=false
FB_NEEDED=false

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

wait_for_service() {
    local service=$1
    local max_attempts=10
    for i in $(seq 1 $max_attempts); do
        if systemctl is-active --quiet "$service"; then
            return 0
        fi
        sleep 1
    done
    return 1
}

user_has_processes() {
    local uid="$1" selector status
    # usermod checks real UIDs; also stop processes with this effective UID.
    for selector in -U -u; do
        if pgrep "$selector" "$uid" >/dev/null; then
            return 0
        else
            status=$?
            [ "$status" -eq 1 ] || fail "Could not check processes for UID $uid (pgrep exit $status)."
        fi
    done
    return 1
}

signal_user_processes() {
    local signal="$1" uid="$2" selector status
    for selector in -U -u; do
        if pkill "-$signal" "$selector" "$uid"; then
            continue
        else
            status=$?
            # A process may exit between pgrep and pkill.
            [ "$status" -eq 1 ] || fail "Could not signal processes for UID $uid (pkill exit $status)."
        fi
    done
}

stop_user_processes() {
    local username="$1" uid
    uid=$(id -u "$username")
    [ "$uid" -ne 0 ] || fail "Refusing to stop processes for $username with UID 0."

    if user_has_processes "$uid"; then
        echo "Stopping processes for $username (UID $uid)..."
        signal_user_processes TERM "$uid"
        sleep 10
        if user_has_processes "$uid"; then
            echo "Force stopping remaining processes for $username..."
            signal_user_processes KILL "$uid"
            sleep 5
        fi
        if user_has_processes "$uid"; then
            ps -u "$uid" -U "$uid" -o pid,ruid,euid,rgid,egid,args >&2 || true
            fail "Processes for $username remain or are restarting. Stop their supervising services before rerunning this script."
        fi
    fi
    echo "No processes remain for $username."
}

set_uid_gid() {
    local username="$1"
    local pgid="$2"
    stop_user_processes "$username"
    usermod -u "$pgid" "$username"
    groupmod -g "$pgid" "$username"
    usermod -g "$pgid" "$username"
    if check_uid_gid "$username" "$pgid"; then
        fail "UID/GID verification failed for $username; expected $pgid:$pgid."
    fi
}

check_uid_gid() {
    local username="$1"
    local pgid="$2"
    local user_uid user_gid group_entry group_name group_password group_gid group_members
    user_uid=$(id -u "$username") || fail "Could not look up UID for $username."
    user_gid=$(id -g "$username") || fail "Could not look up primary GID for $username."
    group_entry=$(getent group "$username") || fail "Could not look up group $username."
    IFS=: read -r group_name group_password group_gid group_members <<< "$group_entry"

    if [ "$user_uid" -eq "$pgid" ] && [ "$user_gid" -eq "$pgid" ] && [ "$group_gid" -eq "$pgid" ]; then
        echo "User '$username' has both UID and GID equal to $pgid"
        return 1
    else
        echo "User '$username' does not have the good uid/gid, it will be modified."
        return 0
    fi
}

if check_uid_gid "pf" $PF_ID; then
    PF_NEEDED=true
fi

if check_uid_gid "fingerbank" $FB_ID; then
    FB_NEEDED=true
fi

if [ "$PF_NEEDED" = true ] || [ "$FB_NEEDED" = true ]; then
    if [[ " $* " == *" -w "* ]]; then
        echo "The -w argument requests confirmation before changing UID/GID."
        echo -e "Script steps will be:\n\t1) stopping services\n\t2) apply new uid and gid\n\t3) restart services."
        read -p "Do you want to continue the script? (yes/no):" user_response

        case $(echo "$user_response" | tr '[:upper:]' '[:lower:]') in
            yes|y)
                USE_F_MODE=true
                ;;
            *)
                echo "Operation cancelled. Nothing will change."
                exit 0
                ;;
        esac
    else
        echo "No -w (wait) argument provided. Automated script."
        USE_F_MODE=true
    fi
fi

if [ "$USE_F_MODE" = false ]; then
    if [ -f "$MIGRATION_PENDING" ]; then
        echo "Resuming permission repairs from an incomplete UID/GID migration."
    else
        echo "Nothing to do."
        exit 0
    fi
fi

MONIT_RUNNING=false
if systemctl is-active --quiet monit; then
    MONIT_RUNNING=true
fi

if [ "$MONIT_RUNNING" = true ]; then
    systemctl stop monit
    systemctl disable monit
    echo "Monit is stopped and disabled."
fi

/usr/local/pf/bin/pfcmd service pf stop
systemctl stop packetfence-config
systemctl stop packetfence-redis_queue.service
echo "PacketFence's Services are stopped."

# Keep a marker until ownership repairs and service startup succeed. A retry
# must repair permissions even if the account IDs were already changed.
touch "$MIGRATION_PENDING"

if [ "$PF_NEEDED" = true ]; then
    set_uid_gid "pf" $PF_ID
    echo "uid and gid for pf have been applied."
fi
if [ "$FB_NEEDED" = true ]; then
    set_uid_gid "fingerbank" $FB_ID
    echo "uid and gid for fingerbank have been applied."
fi

find "$PACKETFENCE/" -path "$PACKETFENCE/logs" -prune -o '(' -type d -or -type f ')' -not -name pfcmd -print0 | xargs -0 -r chown pf:pf
find "$PACKETFENCE/logs/" -print0 | xargs -0 -r chown root:pf
chown root:root /usr/local/pf/bin/pfcmd
chmod ug+s /usr/local/pf/bin/pfcmd
chown root:root /usr/local/pf/bin/pfcrypt
chown root:root /usr/local/pf/bin/pfkafka
/usr/local/pf/bin/pfcmd fixpermissions strict
echo "Permissions with new uid and gid are fixed"

systemctl start packetfence-config
if wait_for_service "packetfence-config" ; then
    echo "Service packetfence-config have been restarted"
else
    echo "Service packetfence-config is not active."
    echo "A manual restart and perhaps fix is needed."
    exit 1
fi

rm -f "$MIGRATION_PENDING"
echo "Script is ending."
exit 0
