#!/bin/bash

stop_service_if_exists() {
    SERVICE=$1
    if [ $(set +e;invoke-rc.d --quiet --query packetfence stop; echo $?) = 104  ];then
        invoke-rc.d packetfence stop
    fi
}

stop_user_processes() {
    local username="$1"
    local running_processes=$(pgrep -u "$username" 2>/dev/null)

    if [ -z "$running_processes" ]; then
        echo "No processes found running as user '$username'"
        return 0
    fi

    ps -u "$username" -o pid,comm,args
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

    local user_uid=$(id -u "$username")
    local user_gid=$(id -g "$username")

    if [ "$user_uid" -eq $pgid ] && [ "$user_gid" -eq $pgid ]; then
        echo "User '$username' has both UID and GID equal to $pgid"
        return 0
    else
        usermod  -u $pgid $username
        groupmod -g $pgid $username
        return 1
    fi
}

# Check if -f argument was provided
if [[ " $@ " =~ " -f " ]]; then
    use_f_mode=true
else
    echo "No -f argument provided."
    read -p "Do you want to continue with -f mode? (yes/no): " user_response

    case $(echo "$user_response" | tr '[:upper:]' '[:lower:]') in
        yes|y)
            use_f_mode=true
            ;;
        *)
            echo "Operation cancelled. Nothing will change."
            exit 0
            ;;
    esac
fi

# Continue with your script
if [ "$use_f_mode" = true ]; then
    echo "Services will be stopped and Packetfence will not work for few minutes."
    systemctl stop monit
    systemctl disable monit
    /usr/local/pf/bin/pfcmd service pf stop
    systemctl stop packetfence-config
    set_uid_gid "fingerbank" 2026
    set_uid_gid "pf" 2025
    systemctl start packetfence-config
    /usr/local/pf/bin/pfcmd fixpermissions
    chown pf:pf /usr/local/pf/logs/*
    /usr/local/pf/bin/pfcmd service pf restart
    return 0
fi
