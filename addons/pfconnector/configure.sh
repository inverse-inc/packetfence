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

# High availability: two hosts share this connector id; a VRRP virtual IP
# moves between them and only the VIP owner holds the tunnel. Switches, the
# captive portal redirection and DHCP relays must point at the VIP.
# See docs/design/pfconnector-remote-ha.md.
if prompt "Is this host part of a high-availability pair (VRRP virtual IP)?"; then
  echo -n "Virtual IP with prefix length (e.g. 10.0.0.250/24): "
  read ha_vip
  echo "PFCONNECTOR_HA_VIP=$ha_vip" >> /usr/local/pfconnector-remote/conf/pfconnector-client.env
  default_iface=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
  echo -n "Interface carrying the VIP [${default_iface:-eth0}]: "
  read ha_iface
  echo "PFCONNECTOR_HA_INTERFACE=${ha_iface:-${default_iface:-eth0}}" >> /usr/local/pfconnector-remote/conf/pfconnector-client.env
  echo -n "VRRP priority, use 100 on the first host and 90 on the second [100]: "
  read ha_priority
  echo "PFCONNECTOR_HA_PRIORITY=${ha_priority:-100}" >> /usr/local/pfconnector-remote/conf/pfconnector-client.env
  echo -n "Peer host IP for unicast VRRP (leave empty for multicast): "
  read ha_peer
  if [ -n "$ha_peer" ]; then
    echo "PFCONNECTOR_HA_PEER=$ha_peer" >> /usr/local/pfconnector-remote/conf/pfconnector-client.env
  fi
  echo "Copy conf/terminal_totp from the first host to the second so one terminal enrollment works for both."
fi

# The TOTP seed gating remote terminal access (conf/terminal_totp) is
# generated and displayed as a QR code by the package postinst; the
# pfconnector-client generates it on first start if it is missing. Run
# bin/pfconnector-totp-qrcode to display the enrollment QR code again.

# Create a dummy system_init_key file to prevent Docker from creating it as a directory
if [ ! -f /usr/local/pfconnector-remote/conf/system_init_key ]; then
  rm -rf /usr/local/pfconnector-remote/conf/system_init_key
  head -c 32 /dev/urandom | base64 > /usr/local/pfconnector-remote/conf/system_init_key
fi
