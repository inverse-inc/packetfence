#!/bin/bash

USE_F_MODE=false
PF_ID=2025
FB_ID=2026
PF_NEEDED=false
FB_NEEDED=false

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

stop_user_processes() {
    local username="$1"
    local running_processes=$(pgrep -u "$username" 2>/dev/null)

    if [ -z "$running_processes" ]; then
        echo "No processes found running as user '$username'"
        return 0
    fi

    echo "Stopping processes gracefully..."
    pkill -TERM -u "$username" 2>/dev/null
    sleep 2

    remaining_processes=$(pgrep -u "$username" 2>/dev/null)
    if [ -n "$remaining_processes" ]; then
        echo "Force stopping remaining processes..."
        pkill -KILL -u "$username" 2>/dev/null
        sleep 2
    fi

    if pgrep -u "$username" &>/dev/null; then
        echo "Error: Could not stop all processes for user '$username'"
        return 1
    fi

    echo "All processes for user '$username' have been stopped"
    return 0
}

set_uid_gid() {
    local username="$1"
    local pgid="$2"
    stop_user_processes "$username"
    usermod  -u $pgid $username
    groupmod -g $pgid $username
    return 0
}

check_uid_gid() {
    local username="$1"
    local pgid="$2"
    local user_uid=$(id -u "$username")
    local user_gid=$(id -g "$username")

    if [ "$user_uid" -eq "$pgid" ] && [ "$user_gid" -eq "$pgid" ]; then
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
    if [[ " $@ " =~ " -y " ]]; then
        USE_F_MODE=true
    else
        echo "No -y argument provided. The -y argument will bypass that question."
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
    fi
fi

if [ "$USE_F_MODE" = false ]; then
    echo "Nothing to do."
    exit 0
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
echo "PacketFence's Services are stopped and Packetfence will not work for few minutes."

if [ "$PF_NEEDED" = true ]; then
    set_uid_gid "pf" $PF_ID
    echo "uid and gid for pf have been applied."
fi
if [ "$FB_NEEDED" = true ]; then
    set_uid_gid "fingerbank" $FB_ID
    echo "uid and gid for fingerbank have been applied."
fi

/usr/local/pf/bin/pfcmd fixpermissions
chown pf:pf /usr/local/pf/logs/*
echo "Permissions with new uid and gid are fixed"

systemctl start packetfence-config
if wait_for_service "packetfence-config" ; then
    echo "Service packetfence-config have been restarted"
else
    echo "Service packetfence-config is not active."
    echo "A manual restart and perhaps fix is needed."
    exit 1
fi

/usr/local/pf/bin/pfcmd service pf restart
echo "Services have been restarted. Packetfence should be back online."

if [ "$MONIT_RUNNING" = true ]; then
    systemctl start monit
    systemctl enable monit
    echo "Monit has been restarted."
fi
echo "Script is ending."
exit 0
