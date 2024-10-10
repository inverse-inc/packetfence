#!/bin/sh

# turn on bash's job control
set -m

# Start the primary process and put it in the background
/srv/caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &

# Start the helper process
/usr/bin/python3 /srv/dns_register_alert.py

# the my_helper_process might need to know how to wait on the
# primary process to start before it does its work and returns


# now we bring the primary process back into the foreground
# and leave it there
fg %1
