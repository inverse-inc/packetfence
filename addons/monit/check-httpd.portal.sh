#!/bin/bash

script_name=check-httpd.portal.sh

tmpfile=$(mktemp /tmp/check-httpd.portal.XXXXXX)

master_pid=`ps -edf | grep httpd.portal | grep -P 'root\s+[0-9]+\s+1 ' | awk '{ print $2 }'`

if [ -z "$master_pid" ]; then
  logger "$script_name Unable to find master Apache PID"
  rm $tmpfile
  exit 1
fi

netstat -nlp | grep $master_pid | grep :80 | awk '{ print $4 }' > $tmpfile

while read host; do
  if ! curl -m 10 -I "$host/captive-portal" | head -n 1 | grep "HTTP/1.1 200 OK" ; then
    logger "$script_name Wrong return code for captive-portal on host $host"
    rm $tmpfile
    exit 1
  fi
done < $tmpfile

rm $tmpfile
