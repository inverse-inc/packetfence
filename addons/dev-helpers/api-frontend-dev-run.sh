#!/bin/bash
PIDFILE=/usr/local/pf/var/run/api-frontend-dev.pid
set -e
cd /usr/local/pf/go
systemctl stop packetfence-api-frontend
make pfhttpd

if [-e "$PIDFILE"];then
    kill $(cat "$PIDFILE")
fi

./pfhttpd run --pidfile "$PIDFILE" --envfile /usr/local/pf/var/conf/api-frontend.env -a caddyfile --config /usr/local/pf/conf/caddy-services/api.conf
rm -f "$PIDFILE"
