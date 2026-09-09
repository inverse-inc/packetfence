#!/bin/bash

function prompt() {
  msg="$1"
  answer=""
  while [ "$answer" != "y" ] && [ "$answer" != "n" ]; do
    echo -n "$msg (y/n): "
    read answer
  done
  
  if [ "$answer" == "y" ]; then
    return 0
  else
    return 1
  fi
}

connector_id=$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-40} | head -n 1)

echo "Connector ID: $connector_id"
echo "=================================================================="

echo -n "Please configure the connector in PacketFence and input the secret here: "
read secret

echo "=================================================================="

echo "Configuring connector with ID '$connector_id' and secret '$secret'"

echo "AUTH=$connector_id:$secret" > /usr/local/pfconnector-remote/conf/pfconnector-client.env

echo "Please enter the URL of the pfconnector server"
echo "Usually looks like: https://packetfence.example:1443/api/v1/pfconnector/tunnel"
echo -n "Enter URL: "
read connector_server

echo "HOST=$connector_server" >> /usr/local/pfconnector-remote/conf/pfconnector-client.env

if ! prompt "Should the pfconnector server TLS certificate be validated?"; then
  echo "TLS_SKIP_VERIFY=true" >> /usr/local/pfconnector-remote/conf/pfconnector-client.env
fi

echo "FETCH_REMOTES_VIA_API=true" >> /usr/local/pfconnector-remote/conf/pfconnector-client.env
echo "PFCONNECTOR_REMOTE=true" >> /usr/local/pfconnector-remote/conf/pfconnector-client.env
echo "PFCONNECTOR_TERMINAL=true" >> /usr/local/pfconnector-remote/conf/pfconnector-client.env
# TOTP second factor gating remote terminal activation. Set to false to
# allow the terminal with only the admin-initiated one-time session.
echo "PFCONNECTOR_TERMINAL_TOTP=true" >> /usr/local/pfconnector-remote/conf/pfconnector-client.env
# Terminal sessions are recorded (asciicast v2) under logs/terminal/ by
# default. Overrides: PFCONNECTOR_TERMINAL_RECORD=false to disable,
# PFCONNECTOR_TERMINAL_RECORD_INPUT=true to also record keystrokes,
# PFCONNECTOR_TERMINAL_RECORDINGS_DIR for another (persisted) directory.

# High availability: install this connector on two (or more) hosts with the
# same ID, secret and URL, then set the virtual IP on the connector in the
# PacketFence admin interface (Networking tab). The hosts learn it through the
# tunnel and cache it; nothing HA-specific is needed here. Host-side
# overrides remain available in this file: PFCONNECTOR_HA_VIP (also
# PFCONNECTOR_HA_VRID, PFCONNECTOR_HA_INTERFACE), PFCONNECTOR_HA_PRIORITY and
# PFCONNECTOR_HA_PEER (comma-separated peer IPs for unicast VRRP).
# See docs/design/pfconnector-remote-ha.md.

# The TOTP seed gating remote terminal access (conf/terminal_totp) is
# generated and displayed as a QR code by the package postinst; the
# pfconnector-client generates it on first start if it is missing. Run
# bin/pfconnector-totp-qrcode to display the enrollment QR code again.

# Create a dummy system_init_key file to prevent Docker from creating it as a directory
if [ ! -f /usr/local/pfconnector-remote/conf/system_init_key ]; then
  rm -rf /usr/local/pfconnector-remote/conf/system_init_key
  head -c 32 /dev/urandom | base64 > /usr/local/pfconnector-remote/conf/system_init_key
fi
