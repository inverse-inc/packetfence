#!/bin/bash

function msg { out "$*" >&1 ;}
function out { printf '%s\n' "$*" ;}

while iptables -L DOCKER ; [ $? -ne 0 ];do
  msg "Waiting for iptables to be ready"
  eval "iptables -t filter -N DOCKER"
  eval "iptables -t nat -N DOCKER"
  sleep 1;
done
