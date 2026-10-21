#!/usr/bin/env bash

IFACE=$(route | grep '^default' | grep -o '[^ ]*$')
IP=$(ip -f inet addr show $IFACE | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')
VUE_APP_API_SOCKET_ADDRESS=$IP:1443 npm run serve

