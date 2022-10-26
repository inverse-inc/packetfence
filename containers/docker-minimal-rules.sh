#!/bin/bash -x

function msg { out "$*" >&1 ;}
function out { printf '%s\n' "$*" ;}

while iptables -L DOCKER ; [ $? -ne 0 ];do
  msg "Waiting for iptables to be ready"
  eval "iptables -t filter -N DOCKER"
  iptables -S -t filter
  eval "iptables -t nat -N DOCKER"
  iptables -S -t nat
  sleep 1;
done
echo "end of $0"
