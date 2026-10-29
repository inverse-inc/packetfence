#!/bin/bash

# HAProxy 3.0 (Debian 13) refuses "process 1" on the stats socket: multi-process
# mode is gone. The templates no longer have it; this fixes copies an admin
# customized, which a package upgrade keeps.
for conf in /usr/local/pf/conf/haproxy-admin.conf /usr/local/pf/conf/haproxy-portal.conf /usr/local/pf/conf/haproxy-db.conf; do
    [ -f "$conf" ] || continue
    if grep -q '^\s*stats socket .* process 1\s*$' "$conf"; then
        sed -i.bak -e 's/^\(\s*stats socket .*\) process 1\s*$/\1/' "$conf"
        echo "Removed 'process 1' from the stats socket in $conf"
    fi
done
