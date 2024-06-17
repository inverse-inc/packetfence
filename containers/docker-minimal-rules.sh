#!/bin/bash

function msg { out "$*" >&1 ;}
function out { printf '%s\n' "$*" ;}

while iptables -L DOCKER ; [ $? -ne 0 ];do
  msg "Waiting for iptables to be ready"
  eval "iptables -t filter -N DOCKER"
  eval "iptables -t nat -N DOCKER"
  eval "iptables -t nat -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER"
  eval "iptables -t nat -A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER"
  eval "iptables -t nat -A POSTROUTING -s 100.64.0.0/10 ! -o docker0 -j MASQUERADE"
  eval "iptables -t nat -A DOCKER -i docker0 -j RETURN"
  sleep 1;
done
