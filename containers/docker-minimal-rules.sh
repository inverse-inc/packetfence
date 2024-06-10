#!/bin/bash

function msg { out "$*" >&1 ;}
function out { printf '%s\n' "$*" ;}
local binary="iptables"

while iptables -L DOCKER ; [ $? -ne 0 ];do
  msg "Waiting for iptables to be ready"
  eval "${binary} -A INPUT --in-interface lo --jump ACCEPT"
  eval "${binary} -A INPUT --in-interface docker0 --jump ACCEPT"
  eval "${binary} -A INPUT --match state --state ESTABLISHED,RELATED --jump ACCEPT"
  eval "${binary} -A INPUT --protocol icmp --icmp-type echo-request --jump ACCEPT"

  eval "${binary} -N DOCKER"
  eval "${binary} -N DOCKER-ISOLATION-STAGE-1"
  eval "${binary} -N DOCKER-ISOLATION-STAGE-2"
  eval "${binary} -N DOCKER-USER"
  eval "${binary} -A FORWARD -j DOCKER-USER"
  eval "${binary} -A FORWARD -j DOCKER-ISOLATION-STAGE-1"
  eval "${binary} -A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT"
  eval "${binary} -A FORWARD -o docker0 -j DOCKER"
  eval "${binary} -A FORWARD -i docker0 ! -o docker0 -j ACCEPT"
  eval "${binary} -A FORWARD -i docker0 -o docker0 -j ACCEPT"

  eval "${binary} -A DOCKER-ISOLATION-STAGE-1 -i docker0 ! -o docker0 -j DOCKER-ISOLATION-STAGE-2"
  eval "${binary} -A DOCKER-ISOLATION-STAGE-1 -j RETURN"
  eval "${binary} -A DOCKER-ISOLATION-STAGE-2 -o docker0 -j DROP"
  eval "${binary} -A DOCKER-ISOLATION-STAGE-2 -j RETURN"
  eval "${binary} -A DOCKER-USER -j RETURN"

  eval "${binary} -t nat -N DOCKER"
  eval "${binary} -t nat -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER"
  eval "${binary} -t nat -A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER"
  eval "${binary} -t nat -A POSTROUTING -s 100.64.0.0/10 ! -o docker0 -j MASQUERADE"
  eval "${binary} -t nat -A DOCKER -i docker0 -j RETURN"

  sleep 1;
done
