#!/bin/bash
set -o nounset -o pipefail -o errexit

echo "Flushing all iptables rules and switch policies to ACCEPT..."
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
