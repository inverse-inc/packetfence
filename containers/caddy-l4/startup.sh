#! /bin/sh

/usr/bin/python3 /srv/dns_register_alert.py &
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
