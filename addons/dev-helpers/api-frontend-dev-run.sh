#!/bin/bash

set -e
cd /usr/local/pf/go
systemctl stop packetfence-api-frontend
make pfhttpd

./pfhttpd run --envfile /usr/local/pf/var/conf/api-frontend.env -a caddyfile --config /usr/local/pf/conf/caddy-services/api.conf
